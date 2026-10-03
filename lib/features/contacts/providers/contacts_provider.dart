import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../models/contact_model.dart';
import '../services/contacts_service.dart';

/// Provider exposing the singleton ContactsService.
final contactsServiceProvider = Provider<ContactsService>((ref) {
  return ContactsService();
});

/// Real-time stream provider of all contacts for the currently logged in user.
final contactsStreamProvider = StreamProvider<List<ContactModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null || uid.isEmpty) {
    return Stream.value([]);
  }
  final service = ref.watch(contactsServiceProvider);
  return service.streamContacts(uid);
});

/// Derived provider returning all overdue contacts sorted by most overdue first.
final overdueContactsProvider = Provider<List<ContactModel>>((ref) {
  final contactsAsync = ref.watch(contactsStreamProvider);
  final contacts = contactsAsync.value ?? [];
  final overdueList = contacts.where((c) => c.isDue).toList();
  // Sort descending by number of days overdue
  overdueList.sort((a, b) => b.overdueByDays.compareTo(a.overdueByDays));
  return overdueList;
});

/// Filter toggle state for Contacts screen ('all' vs 'due').
class ContactsFilterNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  void setFilter(String filter) {
    state = filter;
  }
}

final contactsFilterProvider = NotifierProvider<ContactsFilterNotifier, String>(
  ContactsFilterNotifier.new,
);
