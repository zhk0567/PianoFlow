import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/practice/score_audio_player.dart';
import 'router/app_router.dart';
import 'shared/theme/app_theme.dart';

class PianoFlowApp extends ConsumerWidget {
  const PianoFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mount-time prewarm: bind 88 tones + silent pipeline warm before play.
    ref.read(scoreAudioProvider);
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'PianoFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
