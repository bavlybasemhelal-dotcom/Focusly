import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/google_auth_service.dart';
import 'package:focusly/core/localization/app_localizations.dart';

void main() {
  group('GoogleAuthResult', () {
    test('cancelled result has correct status', () {
      final result = GoogleAuthResult.cancelled();
      expect(result.status, GoogleAuthStatus.cancelled);
      expect(result.isCancelled, isTrue);
      expect(result.user, isNull);
      expect(result.errorMessage, isNull);
    });

    test('popupBlocked result has correct status', () {
      final result = GoogleAuthResult.popupBlocked();
      expect(result.status, GoogleAuthStatus.popupBlocked);
      expect(result.isPopupBlocked, isTrue);
      expect(result.isCancelled, isFalse);
      expect(result.user, isNull);
      expect(result.errorMessage, isNotNull);
    });

    test(
      'accountExistsWithDifferentCredential has correct status and message',
      () {
        final result = GoogleAuthResult.accountExistsWithDifferentCredential(
          message: 'Account already registered with email and password.',
        );
        expect(
          result.status,
          GoogleAuthStatus.accountExistsWithDifferentCredential,
        );
        expect(
          result.errorMessage,
          'Account already registered with email and password.',
        );
        expect(result.isCancelled, isFalse);
      },
    );

    test('error result has correct status and message', () {
      final result = GoogleAuthResult.error('Something went wrong');
      expect(result.status, GoogleAuthStatus.error);
      expect(result.errorMessage, 'Something went wrong');
      expect(result.isCancelled, isFalse);
    });
  });

  group('Google Sign-In Localization', () {
    final enLoc = AppLocalizations(const Locale('en'));
    final arLoc = AppLocalizations(const Locale('ar'));

    test('English translations exist for Google auth keys', () {
      final failedText = enLoc.tr('google_signin_failed');
      expect(failedText, isNotEmpty);
      expect(failedText, isNot(equals('google_signin_failed')));

      final popupBlockedText = enLoc.tr('google_popup_blocked');
      expect(popupBlockedText, isNotEmpty);
      expect(popupBlockedText, isNot(equals('google_popup_blocked')));

      final existsText = enLoc.tr('account_exists_different_credential');
      expect(existsText, isNotEmpty);
      expect(existsText, isNot(equals('account_exists_different_credential')));
    });

    test('Arabic translations exist for Google auth keys', () {
      final failedText = arLoc.tr('google_signin_failed');
      expect(failedText, isNotEmpty);
      expect(failedText, isNot(equals('google_signin_failed')));

      final popupBlockedText = arLoc.tr('google_popup_blocked');
      expect(popupBlockedText, isNotEmpty);
      expect(popupBlockedText, isNot(equals('google_popup_blocked')));

      final existsText = arLoc.tr('account_exists_different_credential');
      expect(existsText, isNotEmpty);
      expect(existsText, isNot(equals('account_exists_different_credential')));
    });
  });
}
