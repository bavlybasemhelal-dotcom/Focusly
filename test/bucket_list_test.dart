import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/bucket_list/bucket_list_page.dart';
import 'package:focusly/features/bucket_list/models/bucket_item_model.dart';
import 'package:focusly/features/bucket_list/providers/bucket_list_provider.dart';
import 'package:focusly/features/bucket_list/widgets/bucket_item_form_modal.dart';
import 'package:focusly/features/rituals/providers/rituals_provider.dart';
import 'package:focusly/screens/home_screen.dart';

class MockDismissedNotifier extends MorningIntentionDismissedNotifier {
  @override
  bool build() => true;
}

Widget createBucketListTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_bucket_list'),
      morningIntentionPromptSettingProvider.overrideWith(
        MorningIntentionPromptSettingNotifier.new,
      ),
      morningIntentionDismissedProvider.overrideWith(MockDismissedNotifier.new),
      ...overrides.cast(),
    ],
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
      home: child,
    ),
  );
}

void main() {
  final pendingDream = BucketItemModel(
    id: 'b1',
    title: 'Visit Mount Fuji in Autumn',
    targetDate: DateTime(2026, 11, 15),
    status: 'pending',
    createdAt: DateTime(2026, 8, 25),
    updatedAt: DateTime(2026, 8, 25),
  );

  final completedDream = BucketItemModel(
    id: 'b2',
    title: 'Run a 10K Marathon',
    targetDate: DateTime(2026, 5, 10),
    status: 'completed',
    memory: 'Finished in 54 minutes! Amazing atmosphere and personal record.',
    createdAt: DateTime(2026, 1, 15),
    updatedAt: DateTime(2026, 5, 10),
  );

  group('BucketItemModel Unit Tests', () {
    test('Model serialization, status flags and date formatting', () {
      final map = pendingDream.toMap();
      expect(map['title'], equals('Visit Mount Fuji in Autumn'));
      expect(map['status'], equals('pending'));
      expect(map['memory'], isNull);

      final deserialized = BucketItemModel.fromMap(map, 'b1');
      expect(deserialized.id, equals('b1'));
      expect(deserialized.title, equals('Visit Mount Fuji in Autumn'));
      expect(deserialized.isPending, isTrue);
      expect(deserialized.isCompleted, isFalse);
      expect(deserialized.formattedTargetDate, equals('Nov 15, 2026'));

      expect(completedDream.isCompleted, isTrue);
      expect(completedDream.isPending, isFalse);
      expect(completedDream.memory, contains('Finished in 54 minutes'));
    });

    test('copyWith updates specified fields correctly', () {
      final updated = pendingDream.copyWith(
        status: 'completed',
        memory: 'Stood at the summit at dawn!',
      );
      expect(updated.status, equals('completed'));
      expect(updated.isCompleted, isTrue);
      expect(updated.memory, equals('Stood at the summit at dawn!'));
      expect(updated.title, equals(pendingDream.title));
    });
  });

  group('BucketListPage UI & Widget Tests', () {
    testWidgets('Renders overall empty state when zero bucket items exist', (tester) async {
      await tester.pumpWidget(
        createBucketListTestWidget(
          child: const BucketListPage(),
          overrides: [
            bucketListStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bucket List'), findsOneWidget);
      expect(find.text('Add your first bucket list item'), findsOneWidget);
      expect(find.text('Add Dream'), findsWidgets);
    });

    testWidgets('Renders Dreams to Achieve and Achieved Memories sections', (tester) async {
      await tester.pumpWidget(
        createBucketListTestWidget(
          child: const BucketListPage(),
          overrides: [
            bucketListStreamProvider.overrideWith(
              (ref) => Stream.value([pendingDream, completedDream]),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bucket List'), findsOneWidget);
      expect(find.text('Dreams to Achieve (1)'), findsOneWidget);
      expect(find.text('Visit Mount Fuji in Autumn'), findsOneWidget);
      expect(find.text('Target Date: Nov 15, 2026'), findsOneWidget);
      expect(find.text('🎉 Done'), findsOneWidget);

      expect(find.text('Achieved Memories (1)'), findsOneWidget);
      expect(find.text('Run a 10K Marathon'), findsOneWidget);
      expect(find.textContaining('Finished in 54 minutes'), findsOneWidget);
    });

    testWidgets('Navigation Drawer includes Bucket List under Analytics section', (tester) async {
      await tester.pumpWidget(
        createBucketListTestWidget(
          child: const HomeScreen(),
          overrides: [
            bucketListStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final menuButton = find.byTooltip('Open navigation menu');
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      expect(find.text('ANALYTICS'), findsOneWidget);
      expect(find.text('Bucket List'), findsOneWidget);
    });

    testWidgets('Arabic localization renders all Bucket List texts', (tester) async {
      await tester.pumpWidget(
        createBucketListTestWidget(
          locale: const Locale('ar'),
          child: const BucketListPage(),
          overrides: [
            bucketListStreamProvider.overrideWith(
              (ref) => Stream.value([pendingDream, completedDream]),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('قائمة الأمنيات والأهداف'), findsOneWidget);
      expect(find.text('أحلام قيد التحقيق (1)'), findsOneWidget);
      expect(find.text('ذكريات محققة (1)'), findsOneWidget);
      expect(find.text('🎉 تم التحقيق'), findsOneWidget);
    });
  });

  group('BucketItemFormModal Tests', () {
    testWidgets('Validates required title and renders form inputs', (tester) async {
      await tester.pumpWidget(
        createBucketListTestWidget(
          child: Scaffold(
            body: BucketItemFormModal(
              itemToEdit: pendingDream,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Bucket List Item'), findsOneWidget);
      expect(find.text('Visit Mount Fuji in Autumn'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Memory & Reflection'), findsOneWidget);
      expect(find.text('Save Item'), findsOneWidget);
      expect(find.text('Delete Item'), findsOneWidget);
    });

    testWidgets('Displays validation error when title is empty', (tester) async {
      await tester.pumpWidget(
        createBucketListTestWidget(
          child: const Scaffold(
            body: BucketItemFormModal(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Save with empty title
      await tester.tap(find.text('Save Item'));
      await tester.pumpAndSettle();

      expect(find.text('Title is required'), findsOneWidget);
    });
  });
}
