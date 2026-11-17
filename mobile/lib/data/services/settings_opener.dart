import 'package:app_settings/app_settings.dart';

/// Opens this app's page in the phone's settings, where permissions live.
abstract interface class SettingsOpener {
  Future<void> openAppSettings();
}

class SystemSettingsOpener implements SettingsOpener {
  const SystemSettingsOpener();

  @override
  Future<void> openAppSettings() => AppSettings.openAppSettings();
}
