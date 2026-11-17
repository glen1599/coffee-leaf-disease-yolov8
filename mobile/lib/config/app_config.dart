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
}
