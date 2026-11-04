import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/onset_flux.dart';
import 'package:piano_flow/features/practice/practice_attack_latch.dart';

void main() {
  test('highFreqEnergy rises with noisy attack vs soft signal', () {
    final soft = Float64List(2048);
    for (var i = 0; i < soft.length; i++) {
      soft[i] = 0.004 * math.sin(2 * math.pi * i / 64);
    }
    final attack = Float64List(2048);
    for (var i = 0; i < 1024; i++) {
      attack[i] = 0.05 * math.sin(2 * math.pi * i / 80);
    }
    for (var i = 1024; i < attack.length; i++) {
      attack[i] = ((i * 17) % 100) / 100.0 - 0.5;
    }
    expect(
      OnsetFluxDetector.highFreqEnergy(attack),
      greaterThan(OnsetFluxDetector.highFreqEnergy(soft)),
    );
  });

  test('detector fires once then respects cooldown', () {
    final d = OnsetFluxDetector(
      fluxThresh: 0.02,
      ratioThresh: 1.3,
      minRms: 0.01,
      cooldownHops: 3,
    );
    expect(d.push(Float64List(1024)), isFalse);

    final burst = Float64List(1024);
    for (var i = 0; i < burst.length; i++) {
      burst[i] = ((i * 31) % 97) / 97.0 - 0.5;
    }
    expect(d.push(burst), isTrue);
    // Cooldown window
    expect(d.push(burst), isFalse);
    expect(d.push(burst), isFalse);
    expect(d.push(burst), isFalse);
    // Decay baseline, then re-attack
    final quiet = Float64List(1024);
    for (var i = 0; i < 6; i++) {
      d.push(quiet);
    }
    expect(d.push(burst), isTrue);
  });

  test('attack latch releaseOnOnset clears spent after refractory', () {
    final latch = PracticeAttackLatch(
      releaseFrames: 2,
      postHitReleaseFrames: 5,
      onsetRefractoryFrames: 2,
    );
    latch.markConsumed(60);
    expect(latch.blocks(60), isTrue);
    latch.onHeard({60});
    latch.releaseOnOnset({60});
    expect(latch.blocks(60), isTrue); // still refractory
    latch.onHeard({60});
    latch.releaseOnOnset({60});
    expect(latch.blocks(60), isFalse);
  });

  test('releaseOnOnset ignores pitches not heard', () {
    final latch = PracticeAttackLatch(onsetRefractoryFrames: 0);
    latch.markConsumed(60);
    latch.releaseOnOnset({64});
    expect(latch.blocks(60), isTrue);
  });
}
