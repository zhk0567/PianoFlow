import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/app_theme.dart';
import '../library/library_repository.dart';
import '../practice/practice_stats_store.dart';

/// 略暖的深墨夜空。
const _ink = Color(0xFF100E0B);
const _inkLift = Color(0xFF181410);
const _ivory = Color(0xFFE7DDD0);
const _ivoryQuiet = Color(0xFF8E8376);
const _candle = Color(0xFFE4C08A);
const _ember = Color(0xFFC49255);

class ConstellationPage extends ConsumerWidget {
  const ConstellationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    final stats = ref.watch(practiceStatsProvider);

    return catalog.when(
      loading: () => const Scaffold(
        backgroundColor: _ink,
        body: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 1.2,
              color: _ivoryQuiet,
            ),
          ),
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: _ink,
        appBar: _nightBar(),
        body: Center(
          child: Text(
            '曲库加载失败：$e',
            style: AppTheme.body(
              fontSize: 13,
              fontWeight: FontWeight.w300,
              color: _ivoryQuiet,
            ),
          ),
        ),
      ),
      data: (songs) {
        return Scaffold(
          backgroundColor: _ink,
          appBar: _nightBar(),
          body: Column(
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  '练习星座',
                  textAlign: TextAlign.center,
                  style: AppTheme.body(
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    color: _ivory,
                    height: 1.2,
                  ).copyWith(letterSpacing: 6),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '点一颗星，进入练习',
                textAlign: TextAlign.center,
                style: AppTheme.body(
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                  color: _ivoryQuiet,
                  height: 1.4,
                ).copyWith(letterSpacing: 1.4),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final sky = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
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
                              size: sky,
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

AppBar _nightBar() {
  return AppBar(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    foregroundColor: _ivoryQuiet,
    iconTheme: const IconThemeData(color: _ivoryQuiet, size: 20),
  );
}

Offset _starOffset(int index, int total, Size size) {
  final rng = math.Random(index * 97 + 13);
  final ring = 0.18 + (index % 5) * 0.12;
  final angle = (index / math.max(1, total)) * math.pi * 2 + rng.nextDouble();
  final cx = size.width * 0.5 + math.cos(angle) * size.width * ring * 0.85;
  final cy = size.height * 0.5 + math.sin(angle) * size.height * ring * 0.7;
  return Offset(
    cx.clamp(28, math.max(28, size.width - 28)),
    cy.clamp(28, math.max(28, size.height - 28)),
  );
}

class _StarHit extends StatelessWidget {
  const _StarHit({
    required this.index,
    required this.total,
    required this.size,
    required this.title,
    required this.onTap,
  });

  final int index;
  final int total;
  final Size size;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = _starOffset(index, total, size);
    return Positioned(
      left: p.dx - 18,
      top: p.dy - 18,
      width: 36,
      height: 36,
      child: Tooltip(
        message: title,
        child: Semantics(
          button: true,
          label: title,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              splashColor: const Color(0x14E4C08A),
              highlightColor: Colors.transparent,
              child: const SizedBox.expand(),
            ),
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
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_inkLift, _ink],
        ).createShader(Offset.zero & size),
    );

    final pool = Offset(size.width * 0.5, size.height * 0.46);
    final poolRadius = size.shortestSide * 0.46;
    canvas.drawCircle(
      pool,
      poolRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF3A2C1C).withValues(alpha: 0.28),
            const Color(0xFF3A2C1C).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: pool, radius: poolRadius)),
    );

    final points = <Offset>[
      for (var i = 0; i < songIds.length; i++)
        _starOffset(i, songIds.length, size),
    ];

    final line = Paint()
      ..color = _candle.withValues(alpha: 0.09)
      ..strokeWidth = 0.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < songIds.length - 1; i++) {
      if (!lit.contains(songIds[i]) || !lit.contains(songIds[i + 1])) continue;
      canvas.drawLine(points[i], points[i + 1], line);
    }

    for (var i = 0; i < songIds.length; i++) {
      _paintStar(canvas, points[i], lit.contains(songIds[i]));
    }
  }

  void _paintStar(Canvas canvas, Offset p, bool on) {
    if (on) {
      const glowRadius = 14.0;
      canvas.drawCircle(
        p,
        glowRadius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _candle.withValues(alpha: 0.30),
              _ember.withValues(alpha: 0.07),
              const Color(0x00E4C08A),
            ],
            stops: const [0.0, 0.38, 1.0],
          ).createShader(Rect.fromCircle(center: p, radius: glowRadius)),
      );
      canvas.drawCircle(p, 1.5, Paint()..color = const Color(0xFFF3E6CC));
      return;
    }
    canvas.drawCircle(
      p,
      1.05,
      Paint()..color = _ivory.withValues(alpha: 0.14),
    );
  }

  @override
  bool shouldRepaint(covariant _ConstellationPainter oldDelegate) =>
      oldDelegate.lit != lit || oldDelegate.songIds != songIds;
}
