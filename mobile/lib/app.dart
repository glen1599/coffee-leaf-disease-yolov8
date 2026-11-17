import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'ui/app_scope.dart';
import 'ui/core/theme/app_colors.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/features/shell/views/home_shell.dart';

/// The application: theme, dependencies and the first screen.
class CekDaunKopiApp extends StatelessWidget {
  const CekDaunKopiApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) => AppScope(
    dependencies: dependencies,
    child: MaterialApp(
      title: 'Cek Daun Kopi',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        // Dark status-bar icons on the white background.
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: AppColors.white,
          systemNavigationBarColor: AppColors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        // Respect a larger system font, up to the point the layout holds.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: child!,
        ),
      ),
      home: const HomeShell(),
    ),
  );
}
