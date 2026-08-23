import 'dart:io';

import 'package:flutter/widgets.dart';

import 'verovio_web_host.dart';
import 'verovio_web_host_android.dart';
import 'verovio_web_host_windows.dart';

class UnsupportedVerovioWebHost implements VerovioWebHost {
  @override
  bool get isInitialized => false;

  @override
  Future<void> initialize() async {
    throw UnsupportedError('Verovio WebView 不支持当前平台');
  }

  @override
  Future<void> loadUrl(String url) async {
    throw UnsupportedError('Verovio WebView 不支持当前平台');
  }

  @override
  Future<dynamic> runJs(String script) async {
    throw UnsupportedError('Verovio WebView 不支持当前平台');
  }

  @override
  Stream<String> get messages => const Stream.empty();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  Widget buildView({Key? key}) {
    return const ColoredBox(
      color: VerovioWebHost.paperColor,
      child: Center(
        child: Text('Verovio 谱面暂不支持此平台'),
      ),
    );
  }
}

VerovioWebHost createVerovioWebHost() {
  if (Platform.isWindows) return WindowsVerovioWebHost();
  if (Platform.isAndroid) return AndroidVerovioWebHost();
  return UnsupportedVerovioWebHost();
}

bool get verovioPlatformSupported =>
    Platform.isWindows || Platform.isAndroid;
