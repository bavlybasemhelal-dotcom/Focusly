import 'package:flutter/material.dart';

/// In-memory queue for holding celebratory dialogs and non-urgent banners
/// while Focus Mode is active.
///
/// ==============================================================================
/// PLATFORM ARCHITECTURAL NOTE:
/// In the desktop/web version of Focusly, Focus Mode featured a "website whitelist"
/// to restrict browser navigation to allowed productive domains.
///
/// On mobile platforms (Android/iOS), sandboxed application security models prevent
/// an app from intercepting or filtering web browser URLs or other apps directly
/// without special enterprise MDM profiles.
///
/// Therefore, on mobile we implement the platform-appropriate analog:
/// During Focus Mode, in-app distractions (e.g. level-up alerts, achievement modals,
/// streak milestone celebration snackbars) are silenced and enqueued here.
/// Once the user exits Focus Mode, the queue is flushed and celebrations are shown.
///
/// TODO: In future iterations, system-wide distraction blocking (e.g. silencing incoming
/// phone notifications via Android Do Not Disturb permission / NotificationPolicyAccess,
/// or Apple Screen Time / FamilyControls API on iOS) can be integrated with native
/// platform channels once corresponding permission flows and privacy disclosures are approved.
/// ==============================================================================
class NotificationQueue {
  static final NotificationQueue _instance = NotificationQueue._internal();
  factory NotificationQueue() => _instance;
  NotificationQueue._internal();

  final List<void Function(BuildContext context)> _queue = [];

  /// Returns true if there are queued notifications waiting to be presented
  bool get hasQueuedItems => _queue.isNotEmpty;

  /// Current number of queued celebrations
  int get queuedCount => _queue.length;

  /// Adds a notification / celebration action to the deferred queue
  void queueCelebration(void Function(BuildContext context) action) {
    _queue.add(action);
  }

  /// Flushes and executes all queued actions sequentially with a short stagger
  Future<void> flush(BuildContext context) async {
    if (_queue.isEmpty) return;

    final items = List<void Function(BuildContext context)>.from(_queue);
    _queue.clear();

    for (final action in items) {
      if (!context.mounted) break;
      action(context);
      // Brief pause between sequential celebratory alerts
      await Future.delayed(const Duration(milliseconds: 600));
    }
  }

  /// Clears any pending queued items without executing them
  void clear() {
    _queue.clear();
  }
}
