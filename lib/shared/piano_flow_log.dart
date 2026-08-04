/// Console-visible PianoFlow log. Prefer this over UI-only hints.
///
/// Prefix: `[PianoFlow/<module>]` so `run-console.ps1` / `flutter run` 都能搜到。
/// Single sink only — pairing `print` + `debugPrint` duplicated every line.
void pianoFlowLog(String module, String message) {
  final line = '[PianoFlow/$module] $message';
  // ignore: avoid_print — Windows 控制台需要 print 才能稳定看到
  print(line);
}

/// High-frequency traces (per-note pitch, load OK chatter). Off by default.
/// Enable: `flutter run --dart-define=PIANOFLOW_VERBOSE=true`
const pianoFlowVerbose = bool.fromEnvironment(
  'PIANOFLOW_VERBOSE',
  defaultValue: false,
);

void pianoFlowLogVerbose(String module, String message) {
  if (!pianoFlowVerbose) return;
  pianoFlowLog(module, message);
}
