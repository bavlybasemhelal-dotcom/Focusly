import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier that manages whether Focus Mode full-screen overlay is currently active.
///
/// Used across the application (e.g. by [ProgressService] and notification dispatchers)
/// to suppress non-urgent celebratory popups/dialogs while the user is actively focusing.
class FocusModeActiveNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Activates focus mode state
  void enterFocusMode() {
    state = true;
  }

  /// Deactivates focus mode state
  void exitFocusMode() {
    state = false;
  }

  /// Explicitly sets focus mode state
  void setActive(bool active) {
    state = active;
  }
}

/// Global provider for checking and toggling Focus Mode active state
final focusModeActiveProvider =
    NotifierProvider<FocusModeActiveNotifier, bool>(
  FocusModeActiveNotifier.new,
);
