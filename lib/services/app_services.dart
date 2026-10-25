import '../providers/app_data_provider.dart';
import '../providers/timer_provider.dart';
import '../providers/settings_provider.dart';

/// Lightweight static locator for the app's long-lived provider instances.
/// Exists so code with no BuildContext (like a notification-action
/// callback, which fires outside any widget tree) can still reach them.
/// Populated once, in main.dart's MultiProvider `create` callbacks, and
/// stays valid for as long as the app process is alive.
class AppServices {
  static TimerProvider? timerProvider;
  static AppDataProvider? appDataProvider;
  static SettingsProvider? settingsProvider;
}
