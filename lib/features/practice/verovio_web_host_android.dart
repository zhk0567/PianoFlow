import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'verovio_web_host.dart';

class AndroidVerovioWebHost implements VerovioWebHost {
  WebViewController? _controller;
  final _messages = StreamController<String>.broadcast();
  final _listeners = ObserverList<VoidCallback>();
  bool _initialized = false;

  @override
  bool get isInitialized => _initialized && _controller != null;

  @override
  Future<void> initialize() async {
    if (_initialized && _controller != null) return;
    final c = WebViewController();
    await c.setJavaScriptMode(JavaScriptMode.unrestricted);
    await c.setBackgroundColor(VerovioWebHost.paperColor);
    await c.addJavaScriptChannel(
      'PianoFlowHost',
      onMessageReceived: (JavaScriptMessage msg) {
        final s = msg.message;
        if (s.isNotEmpty && !_messages.isClosed) _messages.add(s);
      },
    );
    _controller = c;
    _initialized = true;
    _notify();
  }

  @override
  Future<void> loadUrl(String url) async {
    final c = _controller;
    if (c == null) throw StateError('Android Verovio WebView not initialized');
    await c.loadRequest(Uri.parse(url));
    _notify();
  }

  @override
  Future<dynamic> runJs(String script) async {
    final c = _controller;
    if (c == null) throw StateError('Android Verovio WebView not initialized');
    // ReturningResult wraps primitives; keep string compare tolerant upstream.
    return c.runJavaScriptReturningResult(script);
  }

  @override
  Stream<String> get messages => _messages.stream;

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void _notify() {
    for (final l in List<VoidCallback>.from(_listeners)) {
      l();
    }
  }

  @override
  Widget buildView({Key? key}) {
    final c = _controller;
    if (!_initialized || c == null) {
      return const ColoredBox(color: VerovioWebHost.paperColor);
    }
    return WebViewWidget(key: key, controller: c);
  }
}
