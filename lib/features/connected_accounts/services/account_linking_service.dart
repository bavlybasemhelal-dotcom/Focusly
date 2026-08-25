import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Result type for account linking operations.
enum LinkingStatus {
  success,
  cancelled,
  credentialAlreadyInUse,
  providerAlreadyLinked,
  error,
}

class AccountLinkingResult {
  final LinkingStatus status;
  final String? errorMessage;
  final User? user;

  const AccountLinkingResult({
    required this.status,
    this.errorMessage,
    this.user,
  });

  bool get isSuccess => status == LinkingStatus.success;
  bool get isCancelled => status == LinkingStatus.cancelled;
  bool get isAlreadyInUse => status == LinkingStatus.credentialAlreadyInUse;
}

/// Service managing third-party authentication linking (Google Account)
/// to the user's primary Firebase Auth account.
///
/// NOTE FOR MAINTAINERS:
/// Focusly accounts are authenticated via Email/Password as the primary identity.
/// Linking a Google account attaches a 'google.com' provider to `user.providerData`.
/// This enables future Google sign-ins to resolve to the same user and facilitates
/// seamless group invite sharing via Google's ecosystem (Gmail/Contacts in native share sheet).
class AccountLinkingService {
  final FirebaseAuth? _auth;
  final GoogleSignIn? _googleSignIn;

  AccountLinkingService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth,
        _googleSignIn = googleSignIn;

  FirebaseAuth get _firebaseAuth => _auth ?? FirebaseAuth.instance;
  GoogleSignIn get _googleSignInClient =>
      _googleSignIn ??
      GoogleSignIn(
        scopes: const ['email', 'profile'],
      );

  /// Checks whether a Google account is currently linked in [user.providerData].
  bool isGoogleLinked(User? user) {
    if (user == null) return false;
    return user.providerData.any((info) => info.providerId == 'google.com');
  }

  /// Extracts the linked Google account email from [user.providerData], if present.
  String? getLinkedGoogleEmail(User? user) {
    if (user == null) return null;
    for (final info in user.providerData) {
      if (info.providerId == 'google.com') {
        return info.email;
      }
    }
    return null;
  }

  /// Initiates the Google Sign-In interactive popup/flow and links the returned
  /// credential to the current logged-in user.
  Future<AccountLinkingResult> linkGoogleAccount() async {
    try {
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser == null) {
        return const AccountLinkingResult(
          status: LinkingStatus.error,
          errorMessage: 'No active user found to link account to.',
        );
      }

      // 1. Trigger Google interactive sign-in flow
      final googleUser = await _googleSignInClient.signIn();
      if (googleUser == null) {
        // User dismissed the Google sign-in dialog
        return const AccountLinkingResult(status: LinkingStatus.cancelled);
      }

      // 2. Obtain auth details (access & id tokens)
      final googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 3. Link credential with existing user
      final userCredential = await currentUser.linkWithCredential(credential);
      return AccountLinkingResult(
        status: LinkingStatus.success,
        user: userCredential.user,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        return AccountLinkingResult(
          status: LinkingStatus.credentialAlreadyInUse,
          errorMessage: e.message,
        );
      } else if (e.code == 'provider-already-linked') {
        return AccountLinkingResult(
          status: LinkingStatus.providerAlreadyLinked,
          errorMessage: e.message,
        );
      }
      return AccountLinkingResult(
        status: LinkingStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      return AccountLinkingResult(
        status: LinkingStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Unlinks the Google provider ('google.com') from the current user account.
  Future<AccountLinkingResult> unlinkGoogleAccount() async {
    try {
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser == null) {
        return const AccountLinkingResult(
          status: LinkingStatus.error,
          errorMessage: 'No active user found to unlink.',
        );
      }

      // 1. Unlink Google provider from Firebase Auth
      final updatedUser = await currentUser.unlink('google.com');

      // 2. Sign out of GoogleSignIn client so next connect prompts fresh account selection
      try {
        await _googleSignInClient.signOut();
      } catch (_) {}

      return AccountLinkingResult(
        status: LinkingStatus.success,
        user: updatedUser,
      );
    } on FirebaseAuthException catch (e) {
      return AccountLinkingResult(
        status: LinkingStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      return AccountLinkingResult(
        status: LinkingStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
}
