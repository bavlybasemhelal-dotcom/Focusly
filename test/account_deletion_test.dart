import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/account_deletion/user_data_collections.dart';
import 'package:focusly/core/account_deletion/account_deletion_service.dart';
import 'package:focusly/core/localization/app_localizations.dart';

void main() {
  group('Account Deletion Collections Registry', () {
    test('contains all source and productivity collections', () {
      expect(kUserDataSubcollections.length, greaterThanOrEqualTo(43));
      expect(
        kUserDataSubcollections,
        containsAll([
          'habitLogs',
          'completionEvents',
          'trash',
          'taskTemplates',
          'taskRecurrences',
          'recurrenceSkips',
          'templateRuns',
          'dailyPlans',
          'productivity',
          'goalAudit',
        ]),
      );
    });

    test('has no duplicate subcollection names', () {
      final uniqueSet = Set<String>.from(kUserDataSubcollections);
      expect(uniqueSet.length, equals(kUserDataSubcollections.length));
    });

    test('contains all core project collections mentioned in requirements', () {
      final requiredCollections = [
        'tasks',
        'events',
        'habits',
        'pomodoroLogs',
        'checkins',
        'contacts',
        'goals',
        'timeAuditLogs',
        'rituals',
        'gratitude',
        'weeklyReviews',
        'inbox',
        'paraAreas',
        'paraProjects',
        'paraResources',
        'xpLog',
        'notificationLog',
        'decisions',
        'retrospectives',
        'books',
        'skills',
        'learningPaths',
        'knowledge',
        'courses',
        'flashcards',
        'relationshipLogs',
        'socialBattery',
        'bodyMetrics',
        'mentalLog',
        'budgetTransactions',
        'budgetConfig',
        'lifeScoreLog',
        'bucketList',
        'legacyJournal',
        'annualReviews',
        'lifeAreas',
      ];

      for (final collection in requiredCollections) {
        expect(
          kUserDataSubcollections.contains(collection),
          isTrue,
          reason: 'Missing required collection: $collection',
        );
      }
    });

    test('contains additional discovered subcollections', () {
      final additional = [
        'categories',
        'event_types',
        'meta',
        'nutritionLog',
        'readingLogs',
        'stats',
        'workouts',
      ];

      for (final collection in additional) {
        expect(
          kUserDataSubcollections.contains(collection),
          isTrue,
          reason: 'Missing additional discovered collection: $collection',
        );
      }
    });
  });

  group('ReauthenticationRequiredException', () {
    test('correctly identifies password and google providers', () {
      const ex1 = ReauthenticationRequiredException(
        providerIds: ['password'],
        email: 'test@example.com',
      );
      expect(ex1.hasPasswordProvider, isTrue);
      expect(ex1.hasGoogleProvider, isFalse);

      const ex2 = ReauthenticationRequiredException(
        providerIds: ['google.com'],
        email: 'test@example.com',
      );
      expect(ex2.hasPasswordProvider, isFalse);
      expect(ex2.hasGoogleProvider, isTrue);

      const ex3 = ReauthenticationRequiredException(
        providerIds: ['password', 'google.com'],
        email: 'test@example.com',
      );
      expect(ex3.hasPasswordProvider, isTrue);
      expect(ex3.hasGoogleProvider, isTrue);
    });
  });

  group('Localization for Account Deletion', () {
    test('all account deletion keys are defined in English and Arabic', () {
      final enLoc = AppLocalizations(const Locale('en'));
      final arLoc = AppLocalizations(const Locale('ar'));

      final testKeys = [
        'delete_account',
        'delete_account_confirm_title',
        'delete_account_confirm_message',
        'delete_permanently',
        'deleting_account_progress',
        'account_deleted_success',
        'delete_account_error',
        'reauth_required_title',
        'reauth_required_message',
        'reauth_password_hint',
        'reauth_verify_btn',
        'reauth_google_btn',
        'reauth_failed',
      ];

      for (final key in testKeys) {
        final enVal = enLoc.tr(key);
        final arVal = arLoc.tr(key);

        expect(
          enVal,
          isNot(equals(key)),
          reason: 'English translation missing for $key',
        );
        expect(
          arVal,
          isNot(equals(key)),
          reason: 'Arabic translation missing for $key',
        );
        expect(enVal, isNotEmpty);
        expect(arVal, isNotEmpty);
        expect(
          enVal,
          isNot(equals(arVal)),
          reason: 'Arabic should differ from English for $key',
        );
      }
    });
  });
}
