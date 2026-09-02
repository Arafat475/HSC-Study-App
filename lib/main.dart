import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/app_data_provider.dart';
import 'providers/timer_provider.dart';
import 'providers/routine_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/timer_screen.dart';
import 'screens/subjects_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/routine_screen.dart';
import 'screens/class_selection_screen.dart';
import 'screens/profile_screen.dart';
import 'services/notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Fire-and-forget -- permissions/timezone setup can finish while the UI
  // is already rendering; individual notification calls are harmless no-ops
  // until this completes.
  NotificationService.instance.init();
  runApp(const HscStudyApp());
}

// Sleek dark palette: near-black canvas, dark slate cards, a violet/teal
// accent pair for a modern, focused "late-night study" feel.
const kBackgroundColor = Color(0xFF0E1013);
const kSurfaceColor = Color(0xFF181B21);
const kSurfaceColorAlt = Color(0xFF20242C);
const kPrimaryColor = Color(0xFF8B7CF6);
const kAccentColor = Color(0xFF2DD4BF);
const kBorderColor = Color(0xFF2A2E38);
const kTextPrimary = Color(0xFFF2F3F5);
const kTextSecondary = Color(0xFF9AA0AC);
const kTextMuted = Color(0xFF666C78);

class HscStudyApp extends StatelessWidget {
  const HscStudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..init()),
        ChangeNotifierProvider(create: (_) => AppDataProvider()..loadAll()),
        ChangeNotifierProvider(create: (_) => TimerProvider()),
        ChangeNotifierProvider(create: (_) => RoutineProvider()..init()),
      ],
      child: MaterialApp(
        title: 'Study Planner',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: kBackgroundColor,
          colorScheme: ColorScheme.fromSeed(
            seedColor: kPrimaryColor,
            brightness: Brightness.dark,
            primary: kPrimaryColor,
            secondary: kAccentColor,
            surface: kSurfaceColor,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: kBackgroundColor,
            foregroundColor: kTextPrimary,
            elevation: 0,
            centerTitle: false,
            titleTextStyle: TextStyle(
              color: kTextPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
          textTheme: Typography.whiteMountainView.apply(
            bodyColor: kTextPrimary,
            displayColor: kTextPrimary,
          ),
          dividerColor: kBorderColor,
          fontFamily: 'Roboto',
        ),
        home: const RootShell(),
      ),
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
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    if (!settings.loaded) {
      return const Scaffold(
        backgroundColor: kBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: kPrimaryColor)),
      );
    }
    if (settings.needsClassSelection) {
      return const ClassSelectionScreen();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPress == null || now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: kSurfaceColorAlt,
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
              color: selected ? kPrimaryColor : kTextMuted,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          backgroundColor: kSurfaceColor,
          indicatorColor: kPrimaryColor.withOpacity(0.18),
          surfaceTintColor: Colors.transparent,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.timer_outlined, color: kTextMuted),
              selectedIcon: const Icon(Icons.timer, color: kPrimaryColor),
              label: settings.t('nav_timer'),
            ),
            NavigationDestination(
              icon: Icon(Icons.checklist_outlined, color: kTextMuted),
              selectedIcon: const Icon(Icons.checklist, color: kPrimaryColor),
              label: settings.t('nav_routine'),
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined, color: kTextMuted),
              selectedIcon: const Icon(Icons.menu_book, color: kPrimaryColor),
              label: settings.t('nav_progress'),
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined, color: kTextMuted),
              selectedIcon: const Icon(Icons.bar_chart, color: kPrimaryColor),
              label: settings.t('nav_analytics'),
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline, color: kTextMuted),
              selectedIcon: Icon(Icons.person, color: kPrimaryColor),
              label: 'Profile',
            ),
          ],
        ),
      ),
    ),
    );
  }
}
