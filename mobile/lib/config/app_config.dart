/// Build-time configuration.
///
/// Detection runs on the phone and needs none of this. The API is only used
/// to refresh the knowledge base when a connection happens to be available.
/// Point the app at a server with:
///
///     flutter run --dart-define=API_BASE_URL=https://example.hf.space
abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

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
