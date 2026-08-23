import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

import 'verovio_web_host.dart';

class WindowsVerovioWebHost implements VerovioWebHost {
  final WebviewController controller = WebviewController();
  StreamSubscription<dynamic>? _sub;
  final _messages = StreamController<String>.broadcast();

  @override
  bool get isInitialized => controller.value.isInitialized;

  @override
  Future<void> initialize() async {
    if (!controller.value.isInitialized) {
      await controller.initialize();
      await controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      await controller.setBackgroundColor(VerovioWebHost.paperColor);
    }
    _sub ??= controller.webMessage.listen(
      (msg) {
        final s = msg?.toString() ?? '';
        if (s.isNotEmpty && !_messages.isClosed) _messages.add(s);
      },
      onError: (Object e) {
        if (!_messages.isClosed) _messages.add('webMessage error: $e');
      },
    );
  }

  @override
  Future<void> loadUrl(String url) => controller.loadUrl(url);

  @override
  Future<dynamic> runJs(String script) => controller.executeScript(script);

  @override
  Stream<String> get messages => _messages.stream;

  @override
  void addListener(VoidCallback listener) => controller.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      controller.removeListener(listener);

  @override
  Widget buildView({Key? key}) {
    if (!controller.value.isInitialized) {
      return ColoredBox(key: key, color: VerovioWebHost.paperColor);
    }
    return Webview(
      controller,
      permissionRequested: (url, kind, isUserInitiated) async =>
          WebviewPermissionDecision.deny,
    );
  }
}
