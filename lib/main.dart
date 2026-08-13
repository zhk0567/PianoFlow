import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/practice/verovio_runtime.dart';
import 'features/workshop/workshop_audio_draft_worker.dart';
import 'shared/piano_flow_log.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: PianoFlowApp()));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Background-prewarm Verovio WASM so practice staff is near-instant.
    if (Platform.isWindows) {
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
