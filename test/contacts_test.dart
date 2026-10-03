import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/contacts/contacts_page.dart';
import 'package:focusly/features/contacts/models/contact_model.dart';
import 'package:focusly/features/contacts/providers/contacts_provider.dart';
import 'package:focusly/features/contacts/widgets/add_edit_contact_sheet.dart';
import 'package:focusly/features/contacts/widgets/home_contacts_widget.dart';

Widget createContactsTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_contacts'),
      ...overrides.cast(),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [AppLocalizations.delegate],
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('Personal CRM (Contacts) Pure Calculations & Model Tests', () {
    test('daysSinceLastContact correctly calculates day differences', () {
      final now = DateTime(2026, 8, 23, 14, 0);

      // Contacted today
      final today = DateTime(2026, 8, 23, 9, 0);
      expect(daysSinceLastContact(today, now), equals(0));

      // Contacted 10 days ago
      final past10 = DateTime(2026, 8, 13, 18, 0);
      expect(daysSinceLastContact(past10, now), equals(10));

      // Contacted 45 days ago
      final past45 = DateTime(2026, 7, 9, 10, 0);
      expect(daysSinceLastContact(past45, now), equals(45));

      // Future date clamps to 0
      final future = DateTime(2026, 8, 25);
      expect(daysSinceLastContact(future, now), equals(0));
    });

    test('isContactOverdue and overdueDaysCount work correctly', () {
      final now = DateTime(2026, 8, 23);

      // 10 days ago with remind interval 30 -> NOT overdue
      final contact1 = DateTime(2026, 8, 13);
      expect(isContactOverdue(contact1, 30, now), isFalse);
      expect(overdueDaysCount(contact1, 30, now), equals(0));

      // 30 days ago with remind interval 30 -> IS overdue (0 days beyond)
      final contact2 = DateTime(2026, 7, 24);
      expect(isContactOverdue(contact2, 30, now), isTrue);
      expect(overdueDaysCount(contact2, 30, now), equals(0));

      // 45 days ago with remind interval 30 -> IS overdue by 15 days
      final contact3 = DateTime(2026, 7, 9);
      expect(isContactOverdue(contact3, 30, now), isTrue);
      expect(overdueDaysCount(contact3, 30, now), equals(15));
    });

    test('ContactModel serialization and deserialization works correctly', () {
      final now = DateTime(2026, 8, 23, 12, 0);
      final contact = ContactModel(
        id: 'contact_123',
        name: 'Sarah Connor',
        emoji: '😎',
        role: 'Mentor',
        contactInfo: 'sarah@example.com',
        lastContact: DateTime(2026, 8, 1),
        remindDays: 14,
        notes: 'Discuss AI agent architecture',
        createdAt: now,
        updatedAt: now,
      );

      final map = contact.toMap();
      expect(map['id'], equals('contact_123'));
      expect(map['name'], equals('Sarah Connor'));
      expect(map['emoji'], equals('😎'));
      expect(map['role'], equals('Mentor'));
      expect(map['remindDays'], equals(14));

      final reconstructed = ContactModel.fromMap(map, 'contact_123');
      expect(reconstructed.id, equals('contact_123'));
      expect(reconstructed.name, equals('Sarah Connor'));
      expect(reconstructed.emoji, equals('😎'));
      expect(reconstructed.role, equals('Mentor'));
      expect(reconstructed.contactInfo, equals('sarah@example.com'));
      expect(reconstructed.remindDays, equals(14));
      expect(reconstructed.notes, equals('Discuss AI agent architecture'));

      final updated = reconstructed.copyWith(
        name: 'Sarah Connor PhD',
        remindDays: 21,
      );
      expect(updated.name, equals('Sarah Connor PhD'));
      expect(updated.remindDays, equals(21));
    });
  });

  group('Personal CRM Providers Tests', () {
    test(
      'overdueContactsProvider filters and sorts overdue contacts descending',
      () {
        final now = DateTime.now();
        final c1 = ContactModel(
          id: '1',
          name: 'Alice',
          lastContact: now.subtract(
            const Duration(days: 3),
          ), // 3 days ago, remind 30 -> not due
          remindDays: 30,
          createdAt: now,
          updatedAt: now,
        );
        final c2 = ContactModel(
          id: '2',
          name: 'Bob',
          lastContact: now.subtract(
            const Duration(days: 53),
          ), // 53 days ago, remind 30 -> 23 days overdue
          remindDays: 30,
          createdAt: now,
          updatedAt: now,
        );
        final c3 = ContactModel(
          id: '3',
          name: 'Charlie',
          lastContact: now.subtract(
            const Duration(days: 83),
          ), // 83 days ago, remind 30 -> 53 days overdue
          remindDays: 30,
          createdAt: now,
          updatedAt: now,
        );

        final container = ProviderContainer(
          overrides: [
            contactsStreamProvider.overrideWithValue(AsyncData([c1, c2, c3])),
          ],
        );
        addTearDown(container.dispose);

        final overdueList = container.read(overdueContactsProvider);
        expect(overdueList.length, equals(2));
        // Charlie (53d overdue) should come before Bob (23d overdue)
        expect(overdueList.first.name, equals('Charlie'));
        expect(overdueList.last.name, equals('Bob'));
      },
    );
  });

  group('Personal CRM UI & Widget Tests', () {
    testWidgets(
      'ContactsPage renders contacts list, avatar emojis, badges and filter chips',
      (tester) async {
        final now = DateTime.now();
        final contacts = [
          ContactModel(
            id: '1',
            name: 'Ahmed Helal',
            emoji: '🤝',
            role: 'College friend',
            contactInfo: '+201000000000',
            lastContact: now.subtract(const Duration(days: 45)),
            remindDays: 30,
            notes: 'Call to catch up on new project',
            createdAt: now,
            updatedAt: now,
          ),
          ContactModel(
            id: '2',
            name: 'Maria Garcia',
            emoji: '🌟',
            role: 'Design Lead',
            lastContact: now.subtract(const Duration(days: 5)),
            remindDays: 14,
            createdAt: now,
            updatedAt: now,
          ),
        ];

        await tester.pumpWidget(
          createContactsTestWidget(
            child: const ContactsPage(),
            overrides: [
              contactsStreamProvider.overrideWithValue(AsyncData(contacts)),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Contacts'), findsOneWidget);
        expect(find.text('All Contacts'), findsOneWidget);
        expect(find.text('Due for Contact'), findsOneWidget);
        expect(find.text('Ahmed Helal'), findsOneWidget);
        expect(find.text('College friend'), findsOneWidget);
        expect(find.text('Maria Garcia'), findsOneWidget);
        expect(find.text('Design Lead'), findsOneWidget);
        expect(find.textContaining('Call to catch up'), findsOneWidget);

        // Tap "Due for Contact" filter
        await tester.tap(find.text('Due for Contact'));
        await tester.pumpAndSettle();

        // Only Ahmed is overdue (45 days vs 30 interval)
        expect(find.text('Ahmed Helal'), findsOneWidget);
        expect(find.text('Maria Garcia'), findsNothing);
      },
    );

    testWidgets(
      'AddEditContactSheet renders fields, presets and validates required name',
      (tester) async {
        await tester.pumpWidget(
          createContactsTestWidget(child: const AddEditContactSheet()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Add Contact'), findsOneWidget);
        expect(find.text('Avatar Emoji'), findsOneWidget);
        expect(find.text('Name'), findsOneWidget);
        expect(find.text('Role / Relationship (Optional)'), findsOneWidget);

        final saveButton = find.text('Save Contact');
        expect(saveButton, findsOneWidget);
        await tester.ensureVisible(saveButton);
        await tester.pumpAndSettle();

        // Tap Save without entering name -> shows validation error
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        expect(find.text('Please enter a contact name'), findsOneWidget);
      },
    );

    testWidgets('AddEditContactSheet in edit mode renders delete button', (
      tester,
    ) async {
      final now = DateTime.now();
      final contact = ContactModel(
        id: 'contact_edit_1',
        name: 'Dr. John Watson',
        emoji: '💼',
        role: 'Mentor',
        lastContact: now,
        remindDays: 30,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        createContactsTestWidget(child: AddEditContactSheet(contact: contact)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Contact'), findsOneWidget);

      final deleteButton = find.text('Delete Contact');
      await tester.ensureVisible(deleteButton);
      await tester.pumpAndSettle();
      expect(deleteButton, findsOneWidget);
    });

    testWidgets(
      'HomeContactsWidget is visible when overdue contacts exist and hidden when none',
      (tester) async {
        final now = DateTime.now();

        // 1. When no contacts are overdue -> widget is hidden (SizedBox.shrink)
        final activeContact = ContactModel(
          id: '1',
          name: 'David',
          lastContact: now.subtract(const Duration(days: 5)),
          remindDays: 30,
          createdAt: now,
          updatedAt: now,
        );

        await tester.pumpWidget(
          createContactsTestWidget(
            child: const HomeContactsWidget(),
            overrides: [
              contactsStreamProvider.overrideWithValue(
                AsyncData([activeContact]),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('People to reach out to'), findsNothing);

        // 2. When overdue contact exists -> widget renders overdue prompt card
        final overdueContact = ContactModel(
          id: '2',
          name: 'Elena Rostova',
          emoji: '☕',
          role: 'Old Colleague',
          lastContact: now.subtract(const Duration(days: 60)),
          remindDays: 30,
          createdAt: now,
          updatedAt: now,
        );

        await tester.pumpWidget(
          createContactsTestWidget(
            child: const HomeContactsWidget(),
            overrides: [
              contactsStreamProvider.overrideWithValue(
                AsyncData([overdueContact]),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('People to reach out to'), findsOneWidget);
        expect(find.text('Elena Rostova'), findsOneWidget);
        expect(find.text('Old Colleague'), findsOneWidget);
        expect(find.text('Reach out!'), findsOneWidget);
      },
    );
  });
}
