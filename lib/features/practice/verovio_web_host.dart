import 'package:flutter/widgets.dart';

/// Platform WebView bridge for Verovio (Windows WebView2 / Android System WebView).
abstract class VerovioWebHost {
  /// Background color for the embedded view (cream staff paper).
  static const paperColor = Color(0xFFFFFBF5);

  Future<void> initialize();

  bool get isInitialized;

  Future<void> loadUrl(String url);

  /// Evaluate JS; return value when the platform supports it.
  Future<dynamic> runJs(String script);

  /// Host ← JS messages (viewer `postToHost`).
  Stream<String> get messages;

  void addListener(VoidCallback listener);

  void removeListener(VoidCallback listener);

  /// Embeddable WebView widget (shared singleton — do not dispose per page).
  Widget buildView({Key? key});
}
