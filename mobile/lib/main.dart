import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/repositories/content_repository.dart';
import 'data/repositories/detection_repository.dart';
import 'data/repositories/history_repository.dart';
import 'config/app_config.dart';
import 'data/services/api_client.dart';
import 'data/services/lazy_model_runner.dart';
import 'data/services/onnx_model_runner.dart';
import 'data/services/photo_picker.dart';
import 'data/services/reminder_scheduler.dart';
import 'data/services/result_sharer.dart';
import 'data/services/settings_opener.dart';
import 'ui/app_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The layouts are designed for a phone held upright in one hand.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final documents = await getApplicationDocumentsDirectory();
  final contentRepository = ContentRepository(
    cacheDirectory: Directory('${documents.path}/content'),
    api: AppConfig.hasApi ? ApiClient(baseUrl: AppConfig.apiBaseUrl) : null,
  );
  final content = await contentRepository.load();
  final model = LazyModelRunner(OnnxModelRunner.load);

  runApp(
    CekDaunKopiApp(
      dependencies: AppDependencies(
        content: content,
        detection: DetectionRepository(runner: model),
        history: HistoryRepository(Directory('${documents.path}/history')),
        photos: DevicePhotoPicker(),
        reminders: LocalNotificationScheduler(),
        sharer: const SystemResultSharer(),
        settings: const SystemSettingsOpener(),
      ),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Load the model while the user is still looking at the first screen.
    model.warmUp();
    // Fetch newer disease text if there is a connection; used next launch.
    contentRepository.refresh().ignore();
  });
}
