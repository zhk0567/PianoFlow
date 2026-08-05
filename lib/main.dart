import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/practice/verovio_runtime.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows embedder bug: rapid UI/WebView updates spam
  // [ERROR:.../accessibility_bridge.cc] Failed to update ui::AXTree...
  // Floods the console and drowns [PianoFlow/…] logs. Desktop practice does
  // not need the AX tree; re-enable by removing this wrap if Narrator testing.
  Widget app = const ProviderScope(child: PianoFlowApp());
  if (Platform.isWindows) {
    app = ExcludeSemantics(child: app);
  }
  runApp(app);

  // Background-prewarm Verovio WASM so practice staff is near-instant.
  if (Platform.isWindows) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VerovioRuntime.instance.prewarm();
    });
  }
}
