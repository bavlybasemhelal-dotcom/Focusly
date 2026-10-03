import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../helpers/sm2_algorithm.dart';
import '../models/flashcard_model.dart';
import '../services/flashcards_service.dart';

/// State model for an active flashcards review session.
class ReviewSessionState {
  final List<FlashcardModel> queue;
  final int currentIndex;
  final bool isAnswerRevealed;
  final Map<int, int> ratingCounts; // Key: 1..4, Value: count
  final int totalPoints;
  final int totalReviewed;
  final bool isCompleted;
  final bool isSaving;
  final String? uid;
  final String? sessionId;

  const ReviewSessionState({
    this.queue = const [],
    this.currentIndex = 0,
    this.isAnswerRevealed = false,
    this.ratingCounts = const {1: 0, 2: 0, 3: 0, 4: 0},
    this.totalPoints = 0,
    this.totalReviewed = 0,
    this.isCompleted = false,
    this.isSaving = false,
    this.uid,
    this.sessionId,
  });

  FlashcardModel? get currentCard =>
      (currentIndex >= 0 && currentIndex < queue.length)
      ? queue[currentIndex]
      : null;

  int get totalCards => queue.length;
  int get currentDisplayNumber => currentIndex + 1;

  ReviewSessionState copyWith({
    List<FlashcardModel>? queue,
    int? currentIndex,
    bool? isAnswerRevealed,
    Map<int, int>? ratingCounts,
    int? totalPoints,
    int? totalReviewed,
    bool? isCompleted,
    bool? isSaving,
  }) {
    return ReviewSessionState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isAnswerRevealed: isAnswerRevealed ?? this.isAnswerRevealed,
      ratingCounts: ratingCounts ?? this.ratingCounts,
      totalPoints: totalPoints ?? this.totalPoints,
      totalReviewed: totalReviewed ?? this.totalReviewed,
      isCompleted: isCompleted ?? this.isCompleted,
      isSaving: isSaving ?? this.isSaving,
      uid: uid,
      sessionId: sessionId,
    );
  }
}

/// Notifier managing active review session transitions and SM-2 persistence.
class ReviewSessionController extends Notifier<ReviewSessionState> {
  int _generation = 0;

  @override
  ReviewSessionState build() {
    ref.watch(currentUserIdProvider);
    _generation++;
    return const ReviewSessionState();
  }

  /// Starts a new review session with the provided cards, shuffled via Fisher-Yates.
  void startSession(List<FlashcardModel> cards) {
    _generation++;
    final shuffled = Sm2Algorithm.fisherYatesShuffle(cards);
    state = ReviewSessionState(
      queue: shuffled,
      currentIndex: 0,
      isAnswerRevealed: false,
      ratingCounts: const {1: 0, 2: 0, 3: 0, 4: 0},
      totalPoints: 0,
      totalReviewed: 0,
      isCompleted: shuffled.isEmpty,
      uid: ref.read(currentUserIdProvider),
      sessionId: DateTime.now().microsecondsSinceEpoch.toString(),
    );
  }

  /// Reveals the back of the current flashcard.
  void revealAnswer() {
    if (!state.isAnswerRevealed) {
      state = state.copyWith(isAnswerRevealed: true);
    }
  }

  /// Submits quality rating (1: Forgot, 2: Hard, 3: Good, 4: Easy),
  /// calculates SM-2, immediately persists to Firestore, and advances queue.
  Future<bool> submitRating({
    required int quality,
    required String uid,
    required FlashcardsService service,
  }) async {
    final current = state.currentCard;
    if (current == null ||
        state.isSaving ||
        quality < 1 ||
        quality > 4 ||
        uid.isEmpty ||
        (state.uid != null && state.uid != uid)) {
      return false;
    }
    final generation = _generation;
    final before = state;
    state = state.copyWith(isSaving: true);

    try {
      // 1. Calculate SM-2 update
      final sm2Result = Sm2Algorithm.calculate(
        currentInterval: current.interval,
        currentRepetitions: current.repetitions,
        currentEaseFactor: current.easeFactor,
        quality: quality,
      );

      final updatedCard = current.copyWith(
        interval: sm2Result.interval,
        repetitions: sm2Result.repetitions,
        easeFactor: sm2Result.easeFactor,
        dueDate: sm2Result.dueDate,
        updatedAt: DateTime.now(),
      );

      // 2. Persist immediately to Firestore
      final saved = await service.saveReviewProgress(
        uid: uid,
        updatedCard: updatedCard,
      );
      if (!saved || !ref.mounted || generation != _generation) return false;

      // 3. Update local session stats
      final newCounts = Map<int, int>.from(before.ratingCounts);
      newCounts[quality] = (newCounts[quality] ?? 0) + 1;

      final newTotalPoints = before.totalPoints + sm2Result.points;
      final newTotalReviewed = before.totalReviewed + 1;
      final nextIndex = before.currentIndex + 1;
      final isDone = nextIndex >= before.queue.length;

      state = state.copyWith(
        currentIndex: nextIndex,
        isAnswerRevealed: false,
        ratingCounts: newCounts,
        totalPoints: newTotalPoints,
        totalReviewed: newTotalReviewed,
        isCompleted: isDone,
        isSaving: false,
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      if (ref.mounted && generation == _generation && state.isSaving) {
        state = state.copyWith(isSaving: false);
      }
    }
  }
}

final reviewSessionControllerProvider =
    NotifierProvider<ReviewSessionController, ReviewSessionState>(
      ReviewSessionController.new,
    );
