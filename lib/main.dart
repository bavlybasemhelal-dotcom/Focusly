import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/localization/app_localizations.dart';
import 'core/localization/locale_controller.dart';
import 'core/services/notification_init_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/font_size_controller.dart';
import 'core/theme/theme_controller.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with the configured platform options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize timezone database and local notification plugin
  await NotificationInitService.initializeAppNotifications();

  // Set clean system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    const ProviderScope(
      child: FocuslyApp(),
    ),
  );
}

class FocuslyApp extends ConsumerWidget {
  const FocuslyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch Theme, Locale, and Font Size state from Riverpod providers
    final themeMode = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final fontSize = ref.watch(fontSizeControllerProvider);

    return MaterialApp(
      title: 'Focusly',
      debugShowCheckedModeBanner: false,

      // App-wide Theme Switching
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,

      // App-wide Localization (English & Arabic with auto-RTL)
      locale: locale,
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // App-wide Font Scaling via MediaQuery override
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(fontSize.scaleFactor),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },

      home: const SplashScreen(
        isFirstLaunch: true,
      ),
    );
  }
}
