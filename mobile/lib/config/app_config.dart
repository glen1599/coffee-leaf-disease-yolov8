/// Build-time configuration.
///
/// Detection runs on the phone and needs none of this. The API is only used
/// to refresh the knowledge base when a connection happens to be available.
/// The default is the public server (docs/DEPLOY_PYTHONANYWHERE.md); point the
/// app elsewhere, or switch the refresh off with an empty value:
///
///     flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
///     flutter run --dart-define=API_BASE_URL=
abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://glendevit.pythonanywhere.com',
  );

  static bool get hasApi => apiBaseUrl.isNotEmpty;

  static const String modelAsset = 'assets/models/best.onnx';
  static const String contentAsset = 'assets/content/diseases.json';

  /// Example photo of every condition, shown on the Info Penyakit screens.
  static const Map<String, String> sampleAssets = {
    'bercak_phoma': 'assets/images/samples/phoma_leaf_spot.jpg',
    'karat_daun': 'assets/images/samples/coffee_leaf_rust.jpg',
    'pengorok_daun': 'assets/images/samples/leaf_miner.jpg',
    'sehat': 'assets/images/samples/healthy_leaf.jpg',
  };
}
