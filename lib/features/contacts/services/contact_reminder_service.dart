import '../../../core/data/calendar_clock.dart';
import '../../../core/notifications/managed_notification_sender.dart';
import '../../../core/services/notification_init_service.dart';
import '../models/contact_model.dart';

/// One local reminder per relationship, derived from its recorded interaction.
class ContactReminderService {
  static Future<void> refresh(
    String uid,
    List<ContactModel> contacts, {
    bool? enabled,
  }) async {
    if (ManagedNotificationSender.uid != uid) return;
    final sender = NotificationInitService.platformSender;
    final settings = await ManagedNotificationSender.settings(uid);
    final optedIn = enabled ?? settings['contactReminders'] == true;
    final existing = await sender.pending(account: uid);
    final liveIds = contacts.map((contact) => 'contact:${contact.id}').toSet();
    for (final intent in existing) {
      final payload = intent['payload'] as String? ?? '';
      if (payload.startsWith('contact:') &&
          (!optedIn || !liveIds.contains(payload))) {
        if (ManagedNotificationSender.uid != uid) return;
        await sender.cancelSource(payload);
      }
    }
    if (!optedIn) return;
    final now = DateTime.now();
    for (final contact in contacts) {
      if (ManagedNotificationSender.uid != uid) return;
      final baseline = contact.hasContacted
          ? contact.lastContact
          : contact.createdAt;
      final due = calendarDay(baseline, contact.remindDays);
      var date = DateTime(due.year, due.month, due.day, 10);
      if (!date.isAfter(now)) date = now.add(const Duration(minutes: 1));
      final source = 'contact:${contact.id}';
      final old = existing
          .where((intent) => intent['payload'] == source)
          .firstOrNull;
      // Do not shift an already pending overdue reminder on every rebuild.
      if (old != null &&
          old['body'] == contact.name &&
          (calendarDay(DateTime.parse(old['originalDate'] as String)) == due ||
              !date.isBefore(now) && due.isBefore(calendarDay(now)))) {
        continue;
      }
      await sender.cancelSource(source);
      if (date.isAfter(now.add(const Duration(days: 30)))) continue;
      await sender.scheduleNotification(
        id: ManagedNotificationSender.stableId(source),
        title: 'وقت التواصل • Keep in touch',
        body: contact.name,
        scheduledDate: date,
        payload: source,
        channelId: 'focusly_contacts_channel',
        channelName: 'Relationship reminders',
      );
    }
  }
}
