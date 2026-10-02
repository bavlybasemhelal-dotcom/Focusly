import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'user_profile_service.dart';

/// Status outcomes for Google Authentication operations.
enum GoogleAuthStatus {
  /// User successfully authenticated with Google and Firebase Auth.
  success,

  /// User dismissed or cancelled the Google Account picker dialog or closed popup.
  cancelled,

  /// Browser blocked the authentication popup window (Web only).
  popupBlocked,

  /// An existing account was created with email/password; user must log in
  /// with password first and then link Google from Settings.
  accountExistsWithDifferentCredential,

  /// A network, configuration, or authentication error occurred.
  error,
}

/// Result object returned by [GoogleAuthService.signInWithGoogle].
class GoogleAuthResult {
  final GoogleAuthStatus status;
  final User? user;
  final bool isNewUser;
  final String? errorMessage;

  const GoogleAuthResult({
    required this.status,
    this.user,
    this.isNewUser = false,
    this.errorMessage,
  });

  const GoogleAuthResult.success({
    required User user,
    bool isNewUser = false,
  }) : this(
          status: GoogleAuthStatus.success,
          user: user,
          isNewUser: isNewUser,
        );

  const GoogleAuthResult.cancelled()
      : this(status: GoogleAuthStatus.cancelled);

  const GoogleAuthResult.popupBlocked()
      : this(
          status: GoogleAuthStatus.popupBlocked,
          errorMessage: 'Popup was blocked by the browser.',
        );

  const GoogleAuthResult.accountExistsWithDifferentCredential({
    String? message,
  }) : this(
          status: GoogleAuthStatus.accountExistsWithDifferentCredential,
          errorMessage: message,
        );

  const GoogleAuthResult.error(String message)
      : this(
          status: GoogleAuthStatus.error,
          errorMessage: message,
        );

  bool get isSuccess => status == GoogleAuthStatus.success;
  bool get isCancelled => status == GoogleAuthStatus.cancelled;
  bool get isPopupBlocked => status == GoogleAuthStatus.popupBlocked;
  bool get isAccountExistsWithDifferentCredential =>
      status == GoogleAuthStatus.accountExistsWithDifferentCredential;
  bool get isError => status == GoogleAuthStatus.error;
}

/// Service managing initial sign-in and sign-up with Google for Focusly.
///
/// ==============================================================================
/// IMPORTANT ARCHITECTURAL DISTINCTION:
/// ==============================================================================
/// 1. "SIGN IN WITH GOOGLE" (This Service):
///    - Invoked from LoginScreen and SignupScreen when NO user is signed in yet.
///    - Uses [FirebaseAuth.signInWithCredential] (mobile), [FirebaseAuth.signInWithPopup] (web),
///      or an authorized system-browser loopback bridge (Windows Desktop).
///    - Automatically provisions a new `users/{uid}` profile if this is a first-time user.
///
/// 2. "LINK GOOGLE ACCOUNT" (Connected Accounts in Settings):
///    - Invoked when the user is ALREADY signed in with Email/Password.
///    - Uses [User.linkWithCredential] to attach Google identity to the existing account.
///
/// 3. PLATFORM BRANCHING:
///    - WEB (kIsWeb): Uses [FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider())].
///    - WINDOWS DESKTOP (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows):
///      The native mobile [google_sign_in] plugin does not support Windows Desktop.
///      Instead, a local loopback server is started and the system browser is launched
///      to complete the OAuth authentication via Firebase Web SDK.
///    - MOBILE (!kIsWeb && Android/iOS): Uses the native [GoogleSignIn] account picker.
/// ==============================================================================
class GoogleAuthService {
  /// The Web OAuth Client ID from Google Cloud Console / Firebase.
  /// Required by Google Play Services on Android to issue an ID Token for Firebase Auth.
  static const String webClientId =
      '1069563055495-7vtqi7v2k094gqlvu2ugifvpo14kii9l.apps.googleusercontent.com';

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final UserProfileService _userProfileService;

  GoogleAuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    UserProfileService? userProfileService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: const ['email', 'profile'],
              serverClientId: webClientId,
            ),
        _userProfileService =
            userProfileService ?? UserProfileService();

  /// Prompts the user with the interactive Google Account picker on mobile
  /// and returns the corresponding Firebase [AuthCredential].
  ///
  /// Returns `null` if the user dismisses or cancels the account picker dialog
  /// or on platforms where [GoogleSignIn] is not natively supported.
  Future<AuthCredential?> getGoogleCredential() async {
    if (kIsWeb || (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows)) {
      return null;
    }

    try {
      debugPrint('[GoogleAuthService] Initiating Google Sign-In interactive flow...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('[GoogleAuthService] User cancelled the Google Account picker dialog.');
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      debugPrint('[GoogleAuthService] Successfully retrieved Google credentials.');
      return GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
    } catch (e, stack) {
      debugPrint('[GoogleAuthService] Error obtaining Google credentials: $e\n$stack');
      rethrow;
    }
  }

  /// Executes full sign-in or sign-up with Google:
  /// - On Web: uses [FirebaseAuth.signInWithPopup]
  /// - On Windows Desktop: uses local loopback server + system browser
  /// - On Mobile: uses [GoogleSignIn.signIn] + [FirebaseAuth.signInWithCredential]
  ///
  /// All paths converge on [UserProfileService.ensureUserProfileDocument] to ensure
  /// identical Firestore profile provisioning.
  Future<GoogleAuthResult> signInWithGoogle() async {
    if (kIsWeb) {
      return _signInWithGoogleWeb();
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return _signInWithGoogleWindows();
    } else {
      return _signInWithGoogleMobile();
    }
  }

  /// Web-specific sign-in implementation using Firebase Auth's popup flow.
  Future<GoogleAuthResult> _signInWithGoogleWeb() async {
    try {
      debugPrint('[GoogleAuthService] [Web] Initiating FirebaseAuth.signInWithPopup with GoogleAuthProvider...');
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');

      final UserCredential userCredential =
          await _auth.signInWithPopup(googleProvider);

      final User? user = userCredential.user;
      if (user == null) {
        return const GoogleAuthResult.error('Failed to obtain user session from Google web sign-in.');
      }

      debugPrint('[GoogleAuthService] [Web] Successfully authenticated user: ${user.uid} (${user.email})');

      // Shared user document provisioning logic
      final bool isNew = await _userProfileService.ensureUserProfileDocument(
        user: user,
      );

      return GoogleAuthResult.success(
        user: user,
        isNewUser: isNew,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('[GoogleAuthService] [Web] FirebaseAuthException: [${e.code}] ${e.message}');
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled') {
        debugPrint('[GoogleAuthService] [Web] User closed or cancelled the sign-in popup.');
        return const GoogleAuthResult.cancelled();
      }
      if (e.code == 'popup-blocked') {
        debugPrint('[GoogleAuthService] [Web] Sign-in popup was blocked by browser.');
        return const GoogleAuthResult.popupBlocked();
      }
      if (e.code == 'account-exists-with-different-credential') {
        return GoogleAuthResult.accountExistsWithDifferentCredential(
          message: e.message,
        );
      }
      return GoogleAuthResult.error(e.message ?? e.code);
    } catch (e, stack) {
      debugPrint('[GoogleAuthService] [Web] Unexpected error during Google sign-in: $e\n$stack');
      return GoogleAuthResult.error(e.toString());
    }
  }

  /// Windows desktop-specific sign-in implementation using a local loopback server.
  Future<GoogleAuthResult> _signInWithGoogleWindows() async {
    HttpServer? server;
    try {
      debugPrint('[GoogleAuthService] [Windows] Starting local loopback server for Google OAuth...');
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final int port = server.port;
      final authUrl = 'http://localhost:$port/auth';

      final completer = Completer<GoogleAuthResult>();

      server.listen((HttpRequest request) async {
        final path = request.uri.path;
        request.response.headers.add('Access-Control-Allow-Origin', '*');
        request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
        request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

        if (request.method == 'OPTIONS') {
          request.response.statusCode = HttpStatus.ok;
          await request.response.close();
          return;
        }

        if (path == '/auth' && request.method == 'GET') {
          request.response.headers.contentType = ContentType.html;
          request.response.write(_buildWindowsAuthHtml(port));
          await request.response.close();
        } else if (path == '/callback' && request.method == 'POST') {
          try {
            final content = await utf8.decoder.bind(request).join();
            final data = jsonDecode(content) as Map<String, dynamic>;
            final String? idToken = data['idToken'] as String?;
            final String? accessToken = data['accessToken'] as String?;

            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode({'status': 'ok'}));
            await request.response.close();

            if (idToken != null || accessToken != null) {
              final credential = GoogleAuthProvider.credential(
                idToken: idToken,
                accessToken: accessToken,
              );

              final userCredential = await _auth.signInWithCredential(credential);
              final user = userCredential.user;
              if (user != null) {
                final isNew = await _userProfileService.ensureUserProfileDocument(user: user);
                if (!completer.isCompleted) {
                  completer.complete(GoogleAuthResult.success(user: user, isNewUser: isNew));
                }
              } else {
                if (!completer.isCompleted) {
                  completer.complete(const GoogleAuthResult.error('Failed to obtain user session.'));
                }
              }
            } else {
              if (!completer.isCompleted) {
                completer.complete(const GoogleAuthResult.error('Invalid credentials returned from Google.'));
              }
            }
          } catch (err) {
            if (!completer.isCompleted) {
              completer.complete(GoogleAuthResult.error(err.toString()));
            }
          }
        } else if (path == '/cancelled') {
          request.response.statusCode = HttpStatus.ok;
          await request.response.close();
          if (!completer.isCompleted) {
            completer.complete(const GoogleAuthResult.cancelled());
          }
        } else if (path == '/error') {
          try {
            final content = await utf8.decoder.bind(request).join();
            final data = jsonDecode(content) as Map<String, dynamic>;
            final errCode = data['code'] as String?;
            final errMsg = data['error'] as String?;
            request.response.statusCode = HttpStatus.ok;
            await request.response.close();

            if (!completer.isCompleted) {
              if (errCode == 'auth/account-exists-with-different-credential') {
                completer.complete(GoogleAuthResult.accountExistsWithDifferentCredential(message: errMsg));
              } else {
                completer.complete(GoogleAuthResult.error(errMsg ?? 'Authentication failed'));
              }
            }
          } catch (_) {
            if (!completer.isCompleted) {
              completer.complete(const GoogleAuthResult.error('Authentication failed'));
            }
          }
        } else {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        }
      });

      // Launch the browser with the local auth URL
      final uri = Uri.parse(authUrl);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await server.close(force: true);
        return const GoogleAuthResult.error('Could not open default browser for Google Sign-In.');
      }

      // 2-minute safety timeout
      final result = await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          return const GoogleAuthResult.cancelled();
        },
      );

      return result;
    } catch (e, stack) {
      debugPrint('[GoogleAuthService] [Windows] Error during loopback auth: $e\n$stack');
      return GoogleAuthResult.error(e.toString());
    } finally {
      await server?.close(force: true);
    }
  }

  /// Builds the HTML page served on localhost for Windows desktop Google sign-in.
  String _buildWindowsAuthHtml(int port) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Focusly - Sign in with Google</title>
  <script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js"></script>
  <script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-auth-compat.js"></script>
  <style>
    body {
      margin: 0;
      padding: 0;
      background: #090e1a;
      color: #f8fafc;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
    }
    .card {
      background: #0f172a;
      border: 1px solid rgba(255, 255, 255, 0.1);
      border-radius: 20px;
      padding: 40px;
      text-align: center;
      max-width: 420px;
      width: 90%;
      box-shadow: 0 20px 40px rgba(0, 0, 0, 0.5);
    }
    .logo {
      font-size: 28px;
      font-weight: 800;
      background: linear-gradient(135deg, #38bdf8, #818cf8);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      margin-bottom: 16px;
    }
    .status {
      font-size: 15px;
      color: #94a3b8;
      line-height: 1.6;
      margin-bottom: 24px;
    }
    .spinner {
      width: 36px;
      height: 36px;
      border: 3px solid rgba(56, 189, 248, 0.2);
      border-top-color: #38bdf8;
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
      margin: 0 auto 20px;
    }
    @keyframes spin {
      to { transform: rotate(360deg); }
    }
    .btn {
      display: none;
      background: #2563eb;
      color: #fff;
      font-weight: 600;
      font-size: 15px;
      padding: 12px 24px;
      border-radius: 10px;
      border: none;
      cursor: pointer;
      transition: background 0.2s;
    }
    .btn:hover {
      background: #1d4ed8;
    }
    .success-icon {
      display: none;
      font-size: 48px;
      color: #22c55e;
      margin-bottom: 16px;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="logo">Focusly</div>
    <div class="success-icon" id="successIcon">✓</div>
    <div class="spinner" id="spinner"></div>
    <div class="status" id="status">Connecting to Google Sign-In...</div>
    <button class="btn" id="actionBtn" onclick="initiateAuth()">Click to Sign In with Google</button>
  </div>

  <script>
    const firebaseConfig = {
      apiKey: "AIzaSyDpn4TaFMPwK-R_x4qalEQcWGMd1CB9XKs",
      authDomain: "focusly-87187.firebaseapp.com",
      projectId: "focusly-87187"
    };

    try {
      firebase.initializeApp(firebaseConfig);
    } catch(e) {}

    const provider = new firebase.auth.GoogleAuthProvider();
    provider.addScope('email');
    provider.addScope('profile');

    async function initiateAuth() {
      const spinner = document.getElementById('spinner');
      const status = document.getElementById('status');
      const btn = document.getElementById('actionBtn');
      const successIcon = document.getElementById('successIcon');

      spinner.style.display = 'block';
      btn.style.display = 'none';
      status.innerText = 'Please complete sign-in in the Google window...';

      try {
        const result = await firebase.auth().signInWithPopup(provider);
        const credential = result.credential;
        const idToken = credential.idToken;
        const accessToken = credential.accessToken;

        status.innerText = 'Signing you in to Focusly on your desktop...';

        await fetch('http://localhost:$port/callback', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ idToken: idToken, accessToken: accessToken })
        });

        spinner.style.display = 'none';
        successIcon.style.display = 'block';
        status.innerHTML = '<b style="color:#22c55e;">Success!</b><br>You are now signed in. You can close this tab and return to the Focusly app.';
      } catch (err) {
        console.error(err);
        spinner.style.display = 'none';

        if (err.code === 'auth/popup-closed-by-user' || err.code === 'auth/cancelled-popup-request') {
          status.innerText = 'Sign-in window was closed.';
          btn.style.display = 'inline-block';
          btn.innerText = 'Try Again';
          fetch('http://localhost:$port/cancelled', { method: 'POST' });
        } else if (err.code === 'auth/popup-blocked') {
          status.innerText = 'Your browser blocked the popup. Click the button below to open Google Sign-In:';
          btn.style.display = 'inline-block';
          btn.innerText = 'Open Google Sign-In';
        } else {
          status.innerText = 'Authentication error: ' + (err.message || err.code);
          fetch('http://localhost:$port/error', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ error: err.message || err.code, code: err.code })
          });
        }
      }
    }

    window.onload = () => {
      setTimeout(initiateAuth, 300);
    };
  </script>
</body>
</html>
''';
  }

  /// Mobile-specific sign-in implementation using [GoogleSignIn] native picker.
  Future<GoogleAuthResult> _signInWithGoogleMobile() async {
    try {
      // 1. Obtain Google credential
      final AuthCredential? credential = await getGoogleCredential();
      if (credential == null) {
        return const GoogleAuthResult.cancelled();
      }

      // 2. Sign in to Firebase Auth
      debugPrint('[GoogleAuthService] Authenticating with Firebase Auth via credential...');
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      final User? user = userCredential.user;
      if (user == null) {
        return const GoogleAuthResult.error('Failed to obtain user session.');
      }

      debugPrint('[GoogleAuthService] Successfully signed in user: ${user.uid} (${user.email})');

      // 3. Ensure Firestore user document exists (provisions if new user)
      final bool isNew = await _userProfileService.ensureUserProfileDocument(
        user: user,
      );

      return GoogleAuthResult.success(
        user: user,
        isNewUser: isNew,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('[GoogleAuthService] FirebaseAuthException: [${e.code}] ${e.message}');
      if (e.code == 'account-exists-with-different-credential') {
        return GoogleAuthResult.accountExistsWithDifferentCredential(
          message: e.message,
        );
      }
      return GoogleAuthResult.error(e.message ?? e.code);
    } catch (e, stack) {
      debugPrint('[GoogleAuthService] Unexpected error during Google sign-in: $e\n$stack');
      return GoogleAuthResult.error(e.toString());
    }
  }
}
