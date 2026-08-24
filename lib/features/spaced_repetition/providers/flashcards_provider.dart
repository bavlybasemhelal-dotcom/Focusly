import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../models/flashcard_model.dart';
import '../services/flashcards_service.dart';

/// Provider for FlashcardsService singleton.
final flashcardsServiceProvider = Provider<FlashcardsService>((ref) {
  return FlashcardsService();
});

/// Stream provider for all flashcards belonging to the authenticated user.
///
/// Strictly scoped to `users/{uid}/flashcards`.
final flashcardsStreamProvider = StreamProvider<List<FlashcardModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null || uid.isEmpty) return const Stream.empty();

  final service = ref.watch(flashcardsServiceProvider);
  return service.streamFlashcards(uid);
});

/// Derived provider: cards that are currently due for review (dueDate <= today).
final dueFlashcardsProvider = Provider<List<FlashcardModel>>((ref) {
  final allCards = ref.watch(flashcardsStreamProvider).value ?? [];
  return allCards.where((card) => card.isDue).toList();
});
