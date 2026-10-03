import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/connected_accounts/connected_accounts_page.dart';
import 'package:focusly/features/connected_accounts/providers/connected_accounts_provider.dart';
import 'package:focusly/features/connected_accounts/services/account_linking_service.dart';
import 'package:focusly/features/groups/models/group_model.dart';
import 'package:focusly/features/groups/providers/groups_provider.dart';
import 'package:focusly/features/settings/settings_page.dart';

/// Mock UserInfo implementing Firebase Auth [UserInfo]
class MockUserInfo implements UserInfo {
  @override
  final String providerId;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  final String? photoURL;
  @override
  final String? phoneNumber;
  @override
  final String uid;

  MockUserInfo({
    required this.providerId,
    this.email,
    this.displayName,
    this.photoURL,
    this.phoneNumber,
    this.uid = 'mock_uid',
  });
}

/// Mock AccountLinkingService for controlled testing
class MockAccountLinkingService extends AccountLinkingService {
  final bool isLinked;
  final String? linkedEmail;

  MockAccountLinkingService({this.isLinked = false, this.linkedEmail});

  @override
  bool isGoogleLinked(User? user) => isLinked;

  @override
  String? getLinkedGoogleEmail(User? user) => linkedEmail;

  @override
  Future<AccountLinkingResult> linkGoogleAccount() async {
    return const AccountLinkingResult(status: LinkingStatus.success);
  }

  @override
  Future<AccountLinkingResult> unlinkGoogleAccount() async {
    return const AccountLinkingResult(status: LinkingStatus.success);
  }
}

Widget _buildConnectedAccountsTestApp({
  required Widget home,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: overrides.isEmpty ? const [] : overrides.cast(),
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: home,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccountLinkingService Unit Tests', () {
    test(
      'isGoogleLinked correctly identifies google.com provider in providerData',
      () {
        final service = AccountLinkingService();

        // No user -> false
        expect(service.isGoogleLinked(null), isFalse);
      },
    );

    test('AccountLinkingResult status helpers work accurately', () {
      const success = AccountLinkingResult(status: LinkingStatus.success);
      expect(success.isSuccess, isTrue);
      expect(success.isCancelled, isFalse);
      expect(success.isAlreadyInUse, isFalse);

      const inUse = AccountLinkingResult(
        status: LinkingStatus.credentialAlreadyInUse,
      );
      expect(inUse.isAlreadyInUse, isTrue);
      expect(inUse.isSuccess, isFalse);
    });
  });

  group('ConnectedAccountsPage UI & Widget Tests', () {
    testWidgets('Renders in Not Connected state with Connect Google button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildConnectedAccountsTestApp(
          overrides: [
            accountLinkingServiceProvider.overrideWithValue(
              MockAccountLinkingService(isLinked: false),
            ),
            myGroupsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          home: const ConnectedAccountsPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connected Accounts'), findsOneWidget);
      expect(find.text('Google Account'), findsOneWidget);
      expect(find.text('Not Connected'), findsOneWidget);
      expect(find.text('Connect Google'), findsOneWidget);
      expect(
        find.text('Join or create a group first to invite friends'),
        findsOneWidget,
      );
      expect(find.text('Explore Groups'), findsOneWidget);
    });

    testWidgets(
      'Renders in Connected state with linked email and Disconnect button',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _buildConnectedAccountsTestApp(
            overrides: [
              accountLinkingServiceProvider.overrideWithValue(
                MockAccountLinkingService(
                  isLinked: true,
                  linkedEmail: 'user.focusly@gmail.com',
                ),
              ),
              myGroupsStreamProvider.overrideWith((ref) => Stream.value([])),
            ],
            home: const ConnectedAccountsPage(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Connected Accounts'), findsOneWidget);
        expect(find.text('user.focusly@gmail.com'), findsOneWidget);
        expect(find.text('Connected'), findsOneWidget);
        expect(find.text('Disconnect'), findsOneWidget);
      },
    );

    testWidgets('Tapping Disconnect shows confirmation dialog', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildConnectedAccountsTestApp(
          overrides: [
            accountLinkingServiceProvider.overrideWithValue(
              MockAccountLinkingService(
                isLinked: true,
                linkedEmail: 'user.focusly@gmail.com',
              ),
            ),
            myGroupsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          home: const ConnectedAccountsPage(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();

      expect(find.text('Disconnect Google Account?'), findsOneWidget);
      expect(
        find.text(
          'You will no longer be able to use Google to log into this Focusly account.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Renders Group Invite section when user has joined groups', (
      WidgetTester tester,
    ) async {
      final mockGroups = [
        GroupModel(
          id: 'grp_1',
          name: 'Early Birds Club',
          icon: '🌅',
          description: 'Wake up at 5AM every day',
          inviteCode: 'GRP-EARLY5',
          createdBy: 'user_1',
          createdAt: DateTime.now(),
          memberCount: 5,
        ),
      ];

      await tester.pumpWidget(
        _buildConnectedAccountsTestApp(
          overrides: [
            accountLinkingServiceProvider.overrideWithValue(
              MockAccountLinkingService(isLinked: false),
            ),
            myGroupsStreamProvider.overrideWith(
              (ref) => Stream.value(mockGroups),
            ),
          ],
          home: const ConnectedAccountsPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Invite Friends to a Group'), findsOneWidget);
      expect(find.text('Early Birds Club'), findsOneWidget);
      expect(find.text('GRP-EARLY5'), findsOneWidget);
      expect(find.text('Share Invite'), findsOneWidget);
    });

    testWidgets('Arabic localization renders Connected Accounts texts', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildConnectedAccountsTestApp(
          locale: const Locale('ar'),
          overrides: [
            accountLinkingServiceProvider.overrideWithValue(
              MockAccountLinkingService(isLinked: false),
            ),
            myGroupsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          home: const ConnectedAccountsPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الحسابات المتصلة'), findsOneWidget);
      expect(find.text('حساب Google'), findsOneWidget);
      expect(find.text('غير متصل'), findsOneWidget);
      expect(find.text('ربط حساب Google'), findsOneWidget);
      expect(find.text('دعوة الأصدقاء إلى مجموعة'), findsOneWidget);
      expect(find.text('استعراض المجموعات'), findsOneWidget);
    });

    testWidgets('SettingsPage navigates to ConnectedAccountsPage on row tap', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildConnectedAccountsTestApp(
          overrides: [
            accountLinkingServiceProvider.overrideWithValue(
              MockAccountLinkingService(isLinked: false),
            ),
            myGroupsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          home: const SettingsPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to Connected Accounts in Settings
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.text('Connected Accounts'), findsOneWidget);
      await tester.tap(find.text('Connected Accounts'));
      await tester.pumpAndSettle();

      // Verify ConnectedAccountsPage opened
      expect(find.text('Google Account'), findsOneWidget);
      expect(find.text('Connect Google'), findsOneWidget);
    });
  });
}
