import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with the configured platform options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set clean dark status bar and system navigation bar styles
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: kBgDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const FocuslyApp());
}

class FocuslyApp extends StatelessWidget {
  const FocuslyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Focusly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBgDark,
        colorScheme: const ColorScheme.dark(
          primary: kCyanElectric,
          secondary: kGreenNeon,
          surface: kBgMidnight,
        ),
      ),
      home: const SplashScreen(
        // Set isFirstLaunch: true to direct to Onboarding, or false to Home
        isFirstLaunch: true,
      ),
    );
  }
}
