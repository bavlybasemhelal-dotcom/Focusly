import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'core/auth/auth_gate.dart';
import 'core/auth/terms_consent_page.dart';
import 'core/auth/auth_provider.dart';
import 'core/auth/session_preferences.dart';
import 'core/platform/desktop_bridge.dart';
import 'core/notifications/notification_navigation.dart';
import 'core/data/firestore_provider.dart';
import 'features/tasks/models/task_model.dart';
import 'features/tasks/widgets/add_edit_task_sheet.dart';
import 'features/productivity/habit_calendar_page.dart';
import 'features/schedule/schedule_screen.dart';
import 'features/contacts/contacts_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DesktopBridge.subscribe(NotificationNavigation.open);

  // Set clean system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: BootstrapApp()));
}

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});
  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  late Future<bool> _startup;
  @override
  void initState() {
    super.initState();
    _startup = _initialize();
  }

  Future<bool> _initialize() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
    final firstLaunch = await SessionPreferences.prepareStartup();
    try {
      await NotificationInitService.initializeAppNotifications();
    } catch (error) {
      debugPrint('Notification setup unavailable: $error');
    }
    return firstLaunch;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _startup,
    builder: (context, snapshot) {
      if (snapshot.hasData) return FocuslyApp(isFirstLaunch: snapshot.data!);
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: snapshot.hasError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'تعذر تشغيل Focusly. تحقق من الاتصال وإعدادات Firebase.\nFocusly could not start. Check the connection and Firebase configuration.',
                        textAlign: TextAlign.center,
                      ),
                      FilledButton.icon(
                        onPressed: () =>
                            setState(() => _startup = _initialize()),
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة / Retry'),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(),
          ),
        ),
      );
    },
  );
}

final _appNavigatorKey = GlobalKey<NavigatorState>();

class FocuslyApp extends ConsumerWidget {
  const FocuslyApp({super.key, this.isFirstLaunch = false});
  final bool isFirstLaunch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    NotificationNavigation.onOpen = (payload) async {
      final match = RegExp(r'^account=([^|]+)\|(.+)$').firstMatch(payload);
      if (match == null) return;
      final account = ref.read(currentUserIdProvider);
      if (account == null) {
        NotificationNavigation.pending = payload;
        return;
      }
      if (account != match.group(1)) return;
      try {
        if (!await ref.read(provisionedProfileProvider.future) ||
            ref.read(currentUserIdProvider) != account) {
          return;
        }
        if (!await ref.read(termsConsentProvider.future)) {
          NotificationNavigation.pending = payload;
          return;
        }
        final parts = match.group(2)!.split(':');
        final navigator = _appNavigatorKey.currentState;
        if (navigator == null || parts.length < 2) return;
        if (parts[0] == 'task') {
          final task = await ref
              .read(firestoreProvider)
              .collection('users')
              .doc(account)
              .collection('tasks')
              .doc(parts[1])
              .get();
          if (task.exists &&
              ref.read(currentUserIdProvider) == account &&
              navigator.mounted) {
            AddEditTaskSheet.show(
              navigator.context,
              taskToEdit: TaskModel.fromMap(task.data()!, task.id),
            );
          }
        } else {
          final page = switch (parts[0]) {
            'habit' => const HabitCalendarPage(),
            'event' => const ScheduleScreen(),
            'contact' => const ContactsPage(),
            _ => null,
          };
          if (page != null) {
            navigator.push(MaterialPageRoute(builder: (_) => page));
          }
        }
      } catch (_) {
        /* Deleted or unavailable reminder targets do not open a private screen. */
      }
    };
    // Watch Theme, Locale, and Font Size state from Riverpod providers
    final themeMode = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final fontSize = ref.watch(fontSizeControllerProvider);
    if (ref.watch(currentUserIdProvider) != null &&
        ref.watch(termsConsentProvider).value == true &&
        NotificationNavigation.pending != null) {
      final payload = NotificationNavigation.pending!;
      NotificationNavigation.pending = null;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => NotificationNavigation.open(payload),
      );
    }
    ref.listen<String?>(currentUserIdProvider, (previous, next) {
      if (previous != null && previous != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _appNavigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthGate()),
            (_) => false,
          );
        });
      }
    });

    return MaterialApp(
      title: 'Focusly',
      navigatorKey: _appNavigatorKey,
      debugShowCheckedModeBanner: false,

      // App-wide Theme Switching
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,

      // App-wide Localization (English & Arabic with auto-RTL)
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // App-wide Font Scaling via MediaQuery override
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(fontSize.scaleFactor)),
          child: child ?? const SizedBox.shrink(),
        );
      },

      home: SplashScreen(isFirstLaunch: isFirstLaunch),
    );
  }
}
