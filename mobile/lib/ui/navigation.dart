import 'package:material_ui/material_ui.dart';

import '../data/services/photo_picker.dart';
import '../domain/models/disease.dart';
import 'features/guide/views/photo_guide_screen.dart';
import 'features/info/views/disease_screen.dart';
import 'features/result/views/result_screen.dart';
import 'features/scan/views/scan_screen.dart';

/// Where each screen leads. Kept in one place so the flow of the app can be
/// read top to bottom.

Route<T> _route<T>(Widget screen) =>
    MaterialPageRoute<T>(builder: (_) => screen);

Future<void> _go(BuildContext context, Widget screen, {required bool replace}) {
  final navigator = Navigator.of(context);
  return replace
      ? navigator.pushReplacement<void, void>(_route(screen))
      : navigator.push<void>(_route(screen));
}

/// Open the camera or the gallery and check the chosen photo.
Future<void> openScan(
  BuildContext context,
  PhotoSource source, {
  bool replace = false,
}) => _go(context, ScanScreen(source: source), replace: replace);

/// Show a saved check. [justSaved] adds the "saved to history" reassurance.
Future<void> openResult(
  BuildContext context,
  String entryId, {
  bool justSaved = false,
  bool replace = false,
}) => _go(
  context,
  ResultScreen(entryId: entryId, justSaved: justSaved),
  replace: replace,
);

Future<void> openPhotoGuide(BuildContext context, {bool replace = false}) =>
    _go(context, const PhotoGuideScreen(), replace: replace);

Future<void> openDisease(BuildContext context, Disease disease) =>
    _go(context, DiseaseScreen(disease: disease), replace: false);
