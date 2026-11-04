import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/practice/verovio_runtime.dart';
import 'features/practice/verovio_web_host_factory.dart';
import 'features/workshop/workshop_audio_draft_worker.dart';
import 'shared/piano_flow_log.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Windows Flutter engine accessibility_bridge can desync (Tooltip / WebView /
  // rapid rebuild) and flood the console with:
  //   [ERROR:.../accessibility_bridge.cc] Failed to update ui::AXTree, ...
  // Desktop practice does not need Narrator AXTree; ExcludeSemantics stops the
  // spam without changing practice behavior.
  Widget app = const ProviderScope(child: PianoFlowApp());
  if (Platform.isWindows) {
    app = ExcludeSemantics(child: app);
    pianoFlowLog('A11y', 'Windows ExcludeSemantics（压制 AXTree 引擎刷屏）');
  }
  runApp(app);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Background-prewarm Verovio WASM so practice staff is near-instant.
    if (verovioPlatformSupported) {
      VerovioRuntime.instance.prewarm();
    }
    // Warm audio-draft ORT worker (same idea — first import should not cold-start).
    unawaited(() async {
      try {
        await WorkshopAudioDraftWorker.instance.ensureStarted();
      } catch (e) {
        pianoFlowLog('Workshop', 'startup audio worker prewarm: $e');
      }
    }());
  });
}
