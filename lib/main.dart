import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'providers/app_data_provider.dart';
import 'providers/timer_provider.dart';
import 'providers/routine_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/timer_screen.dart';
import 'screens/subjects_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/routine_screen.dart';
import 'screens/class_selection_screen.dart';
import 'screens/onboarding_gate.dart';
import 'screens/profile_screen.dart';
import 'services/notification_service.dart';
import 'services/app_services.dart';
import 'services/backup_service.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // If Firebase config is missing/invalid, the app should still run fully
    // offline -- only the sign-up/backup section is affected.
  }
  // Fire-and-forget -- permissions/timezone setup can finish while the UI
  // is already rendering; individual notification calls are harmless no-ops
  // until this completes.
  NotificationService.instance.init();
  runApp(const HscStudyApp());
}

class HscStudyApp extends StatelessWidget {
  const HscStudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final p = SettingsProvider();
          AppServices.settingsProvider = p;
          p.init();
          return p;
        }),
        ChangeNotifierProvider(create: (_) {
          final p = AppDataProvider();
          AppServices.appDataProvider = p;
          p.loadAll();
          return p;
        }),
        ChangeNotifierProvider(create: (_) {
          final p = TimerProvider();
          AppServices.timerProvider = p;
          return p;
        }),
        ChangeNotifierProvider(create: (_) => RoutineProvider()..init()),
      ],
      // AppColors is derived from SettingsProvider.isDarkMode -- this proxy
      // is what makes every screen (which watches AppColors, not
      // SettingsProvider directly) rebuild the instant the theme toggles.
      child: ChangeNotifierProxyProvider<SettingsProvider, _ColorsHolder>(
        create: (_) => _ColorsHolder(AppColors.dark),
        update: (_, settings, holder) => holder!..update(AppColors.of(settings.isDarkMode)),
        child: const _ThemedApp(),
      ),
    );
  }
}

/// Wraps AppColors in a ChangeNotifier so `context.watch<AppColors>()`-style
/// access works via `context.watch<_ColorsHolder>().colors` -- see the
/// `AppColorsX` extension below for the short form used throughout the app.
class _ColorsHolder extends ChangeNotifier {
  AppColors colors;
  _ColorsHolder(this.colors);
  void update(AppColors next) {
    if (next.isDark != colors.isDark) {
      colors = next;
      notifyListeners();
    }
  }
}

/// Shorthand used everywhere: `context.colors` instead of
/// `context.watch<_ColorsHolder>().colors`.
extension AppColorsX on BuildContext {
  AppColors get colors => watch<_ColorsHolder>().colors;
  AppColors get colorsNoWatch => read<_ColorsHolder>().colors;
}

class _ThemedApp extends StatelessWidget {
  const _ThemedApp();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final settings = context.watch<SettingsProvider>();

    return MaterialApp(
      title: 'Study Planner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: c.isDark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: c.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: c.primary,
          brightness: c.isDark ? Brightness.dark : Brightness.light,
          primary: c.primary,
          secondary: c.accent,
          surface: c.surface,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: c.background,
          foregroundColor: c.textPrimary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: c.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w600,
          ),
        ),
        textTheme: (c.isDark ? Typography.whiteMountainView : Typography.blackMountainView).apply(
          bodyColor: c.textPrimary,
          displayColor: c.textPrimary,
        ),
        dividerColor: c.border,
        fontFamily: 'Roboto',
      ),
      home: !settings.loaded
          ? Scaffold(
              backgroundColor: c.background,
              body: Center(child: CircularProgressIndicator(color: c.primary)),
            )
          : (settings.needsClassSelection ? const OnboardingGate() : const RootShell()),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> with WidgetsBindingObserver {
  int _index = 0;
  DateTime? _lastBackPress;

  final _screens = const [
    TimerScreen(),
    RoutineScreen(),
    SubjectsScreen(),
    AnalyticsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<TimerProvider>().refreshAfterResume();
    }
    if (state == AppLifecycleState.paused) {
      // Best-effort: if signed in, quietly back up whenever the user
      // leaves the app -- not a substitute for the manual button, but
      // means most sessions get captured without them having to remember.
      BackupService.instance.maybeAutoBackup(
        context.read<AppDataProvider>(),
        context.read<SettingsProvider>(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final c = context.colors;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPress == null || now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Press back again to exit'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: c.surfaceAlt,
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: _screens),
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? c.primary : c.textMuted,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            backgroundColor: c.surface,
            indicatorColor: c.primary.withOpacity(0.18),
            surfaceTintColor: Colors.transparent,
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.timer_outlined, color: c.textMuted),
                selectedIcon: Icon(Icons.timer, color: c.primary),
                label: settings.t('nav_timer'),
              ),
              NavigationDestination(
                icon: Icon(Icons.checklist_outlined, color: c.textMuted),
                selectedIcon: Icon(Icons.checklist, color: c.primary),
                label: settings.t('nav_routine'),
              ),
              NavigationDestination(
                icon: Icon(Icons.menu_book_outlined, color: c.textMuted),
                selectedIcon: Icon(Icons.menu_book, color: c.primary),
                label: settings.t('nav_progress'),
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined, color: c.textMuted),
                selectedIcon: Icon(Icons.bar_chart, color: c.primary),
                label: settings.t('nav_analytics'),
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline, color: c.textMuted),
                selectedIcon: Icon(Icons.person, color: c.primary),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
