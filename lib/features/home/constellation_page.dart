import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/app_theme.dart';
import '../library/library_repository.dart';
import '../practice/practice_stats_store.dart';

class ConstellationPage extends ConsumerWidget {
  const ConstellationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    final stats = ref.watch(practiceStatsProvider);

    return catalog.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('练习星座')),
        body: Center(child: Text('曲库加载失败：$e')),
      ),
      data: (songs) {
        return Scaffold(
          backgroundColor: const Color(0xFF0B1020),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            title: const Text('练习星座'),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(
                  '练过的曲子会点亮。点一颗星进入练习。',
                  style: AppTheme.body(fontSize: 13, color: Colors.white70),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return CustomPaint(
                      painter: _ConstellationPainter(
                        songIds: [for (final s in songs) s.id],
                        lit: {
                          for (final e in stats.bySong.entries)
                            if (e.value.lit) e.key,
                        },
                      ),
                      child: Stack(
                        children: [
                          for (var i = 0; i < songs.length; i++)
                            _StarHit(
                              index: i,
                              total: songs.length,
                              size: Size(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              ),
                              lit: stats.bySong[songs[i].id]?.lit ?? false,
                              title: songs[i].title,
                              onTap: () =>
                                  context.push('/practice/${songs[i].id}'),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StarHit extends StatelessWidget {
  const _StarHit({
    required this.index,
    required this.total,
    required this.size,
    required this.lit,
    required this.title,
    required this.onTap,
  });

  final int index;
  final int total;
  final Size size;
  final bool lit;
  final String title;
  final VoidCallback onTap;

  Offset _pos() {
    final rng = math.Random(index * 97 + 13);
    final ring = 0.18 + (index % 5) * 0.12;
    final angle = (index / math.max(1, total)) * math.pi * 2 + rng.nextDouble();
    final cx = size.width * 0.5 + math.cos(angle) * size.width * ring * 0.85;
    final cy = size.height * 0.5 + math.sin(angle) * size.height * ring * 0.7;
    return Offset(
      cx.clamp(24, size.width - 24),
      cy.clamp(24, size.height - 24),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _pos();
    return Positioned(
      left: p.dx - 18,
      top: p.dy - 18,
      width: 36,
      height: 36,
      child: Tooltip(
        message: title,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Icon(
            lit ? Icons.star_rounded : Icons.star_border_rounded,
            color: lit ? const Color(0xFFFFD27A) : Colors.white24,
            size: lit ? 28 : 20,
          ),
        ),
      ),
    );
  }
}

class _ConstellationPainter extends CustomPainter {
  _ConstellationPainter({required this.songIds, required this.lit});

  final List<String> songIds;
  final Set<String> lit;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width * 0.55, size.height * 0.4),
      size.width * 0.35,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF3A4A7A).withValues(alpha: 0.35),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 0.55, size.height * 0.4),
            radius: size.width * 0.35,
          ),
        ),
    );

    final points = <Offset>[];
    for (var i = 0; i < songIds.length; i++) {
      final rng = math.Random(i * 97 + 13);
      final ring = 0.18 + (i % 5) * 0.12;
      final angle =
          (i / math.max(1, songIds.length)) * math.pi * 2 + rng.nextDouble();
      final cx = size.width * 0.5 + math.cos(angle) * size.width * ring * 0.85;
      final cy =
          size.height * 0.5 + math.sin(angle) * size.height * ring * 0.7;
      points.add(
        Offset(
          cx.clamp(24, size.width - 24),
          cy.clamp(24, size.height - 24),
        ),
      );
    }

    for (var i = 0; i < songIds.length - 1; i++) {
      if (!lit.contains(songIds[i]) || !lit.contains(songIds[i + 1])) continue;
      canvas.drawLine(
        points[i],
        points[i + 1],
        Paint()
          ..color = const Color(0xFFFFD27A).withValues(alpha: 0.28)
          ..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConstellationPainter oldDelegate) =>
      oldDelegate.lit != lit || oldDelegate.songIds != songIds;
}
