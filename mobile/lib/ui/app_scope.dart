import 'package:material_ui/material_ui.dart';

import '../data/repositories/detection_repository.dart';
import '../data/repositories/history_repository.dart';
import '../data/services/photo_picker.dart';
import '../data/services/reminder_scheduler.dart';
import '../data/services/result_sharer.dart';
import '../data/services/settings_opener.dart';
import '../domain/models/content_bundle.dart';

/// Everything the screens depend on, built once in `main`.
///
/// Passing these in (instead of reaching for singletons) is what lets the
/// tests swap the camera, the model and the clock for fakes.
class AppDependencies {
  const AppDependencies({
    required this.content,
    required this.detection,
    required this.history,
    required this.photos,
    required this.reminders,
    required this.sharer,
    required this.settings,
    this.clock = DateTime.now,
  });

  final ContentBundle content;
  final DetectionRepository detection;
  final HistoryRepository history;
  final PhotoPicker photos;
  final ReminderScheduler reminders;
  final ResultSharer sharer;
  final SettingsOpener settings;
  final DateTime Function() clock;
}

/// Makes [AppDependencies] reachable from any screen.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.dependencies, required super.child});

  final AppDependencies dependencies;

  static AppDependencies of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope above this widget');
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      dependencies != oldWidget.dependencies;
}
