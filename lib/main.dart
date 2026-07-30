import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/practice/verovio_runtime.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: PianoFlowApp()));
  // Background-prewarm Verovio WASM so practice staff is near-instant.
  if (Platform.isWindows) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VerovioRuntime.instance.prewarm();
    });
  }
}
