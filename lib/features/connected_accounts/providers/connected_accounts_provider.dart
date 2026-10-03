import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../services/account_linking_service.dart';

/// Provider for the [AccountLinkingService] singleton.
final accountLinkingServiceProvider = Provider<AccountLinkingService>((ref) {
  return AccountLinkingService();
});

/// Stream provider that listens to user changes (including providerData updates).
final currentUserStreamProvider = StreamProvider<User?>((ref) {
  try {
    return FirebaseAuth.instance.userChanges();
  } catch (_) {
    return Stream.value(null);
  }
});

/// Notifier tracking whether an account linking/unlinking operation is currently in-flight.
class AccountLinkingLoadingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setLoading(bool value) {
    state = value;
  }
}

final isAccountLinkingLoadingProvider =
    NotifierProvider<AccountLinkingLoadingNotifier, bool>(
      AccountLinkingLoadingNotifier.new,
    );

/// Controller managing connect and disconnect operations with friendly UI feedback.
final connectedAccountsControllerProvider =
    Provider<ConnectedAccountsController>((ref) {
      return ConnectedAccountsController(ref);
    });

class ConnectedAccountsController {
  final Ref ref;

  ConnectedAccountsController(this.ref);

  AccountLinkingService get _service => ref.read(accountLinkingServiceProvider);

  /// Connects the Google account and displays a toast message reflecting the outcome.
  Future<bool> connectGoogle(BuildContext context) async {
    ref.read(isAccountLinkingLoadingProvider.notifier).setLoading(true);
    try {
      final result = await _service.linkGoogleAccount();
      if (!context.mounted) return result.isSuccess;

      switch (result.status) {
        case LinkingStatus.success:
          _showToast(
            context,
            context.tr('google_linked_success'),
            isError: false,
          );
          return true;

        case LinkingStatus.cancelled:
          // User dismissed picker — no error banner needed
          return false;

        case LinkingStatus.credentialAlreadyInUse:
          _showToast(
            context,
            context.tr('google_already_in_use_error'),
            isError: true,
          );
          return false;

        case LinkingStatus.providerAlreadyLinked:
          _showToast(
            context,
            context.tr('google_already_in_use_error'),
            isError: true,
          );
          return false;

        case LinkingStatus.error:
          _showToast(
            context,
            result.errorMessage ?? context.tr('google_link_generic_error'),
            isError: true,
          );
          return false;
      }
    } finally {
      ref.read(isAccountLinkingLoadingProvider.notifier).setLoading(false);
    }
  }

  /// Disconnects the Google account after confirmation.
  Future<bool> disconnectGoogle(BuildContext context) async {
    ref.read(isAccountLinkingLoadingProvider.notifier).setLoading(true);
    try {
      final result = await _service.unlinkGoogleAccount();
      if (!context.mounted) return result.isSuccess;

      if (result.isSuccess) {
        _showToast(
          context,
          context.tr('google_unlinked_success'),
          isError: false,
        );
        return true;
      } else {
        _showToast(
          context,
          result.errorMessage ?? context.tr('google_link_generic_error'),
          isError: true,
        );
        return false;
      }
    } finally {
      ref.read(isAccountLinkingLoadingProvider.notifier).setLoading(false);
    }
  }

  void _showToast(
    BuildContext context,
    String message, {
    required bool isError,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: isError
            ? const Color(0xFFEF4444)
            : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
