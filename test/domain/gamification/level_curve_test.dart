import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/gamification.dart';

/// Verifies the XP curve is strictly monotonic, has the expected boundary
/// values and that level-derived getters on [GameState] line up with
/// [GameState.xpForLevel].
///
/// Curve: each level requires `level * 100` more XP than the previous one,
/// so cumulative XP for level N is `100 * (1 + 2 + ... + (N-1)) = 50*N*(N-1)`.
void main() {
  group('GameState.xpForLevel boundaries', () {
    test('level 1 starts at 0 XP', () {
      expect(GameState.xpForLevel(1), 0);
    });

    test('levels below 1 are clamped to 0', () {
      expect(GameState.xpForLevel(0), 0);
      expect(GameState.xpForLevel(-3), 0);
    });

    test('level 2 requires 100 XP cumulative', () {
      expect(GameState.xpForLevel(2), 100);
    });

    test('level 5 requires 1000 XP cumulative', () {
      // 50 * 5 * 4 = 1000
      expect(GameState.xpForLevel(5), 1000);
    });

    test('level 10 requires 4500 XP cumulative', () {
      // 50 * 10 * 9 = 4500
      expect(GameState.xpForLevel(10), 4500);
    });

    test('level 50 requires 122500 XP cumulative', () {
      // 50 * 50 * 49 = 122500
      expect(GameState.xpForLevel(50), 122500);
    });

    test('curve is strictly increasing', () {
      int prev = -1;
      for (var level = 1; level <= 60; level++) {
        final v = GameState.xpForLevel(level);
        expect(v, greaterThan(prev),
            reason: 'XP requirement should grow at level $level');
        prev = v;
      }
    });

    test('per-level delta grows linearly', () {
      // Difference between consecutive thresholds should be 100 * (level-1)
      // for transitioning from level (level-1) to level.
      for (var level = 2; level <= 20; level++) {
        final delta = GameState.xpForLevel(level) -
            GameState.xpForLevel(level - 1);
        expect(delta, 100 * (level - 1),
            reason: 'delta should equal 100 * (level - 1) for level $level');
      }
    });
  });

  group('GameState level progress', () {
    test('progress is 0 at the start of a level', () {
      const s = GameState(xp: 0, level: 1);
      expect(s.levelProgress, 0);
      expect(s.xpInLevel, 0);
    });

    test('progress is 0.5 at the midpoint of level 1', () {
      const s = GameState(xp: 50, level: 1);
      expect(s.levelProgress, closeTo(0.5, 1e-9));
    });

    test('progress reaches 1 at the next threshold', () {
      const s = GameState(xp: 100, level: 1);
      expect(s.levelProgress, 1.0);
    });

    test('progress clamps to 1 when XP exceeds level cap', () {
      const s = GameState(xp: 9999, level: 1);
      expect(s.levelProgress, 1.0);
    });

    test('xpInLevel and xpNeededInLevel align at level 5', () {
      // Level 5 starts at 1000 (sum 1+2+3+4 = 10 → 100*10 = 1000),
      // level 6 starts at 1500. So inside level 5 we need 500 XP.
      const s = GameState(xp: 1250, level: 5);
      expect(s.xpForCurrentLevel, 1000);
      expect(s.xpForNextLevel, 1500);
      expect(s.xpInLevel, 250);
      expect(s.xpNeededInLevel, 500);
      expect(s.levelProgress, closeTo(0.5, 1e-9));
    });
  });

  group('levelKey buckets', () {
    test('beginner for 1-2', () {
      expect(levelKey(1), 'levelBeginner');
      expect(levelKey(2), 'levelBeginner');
    });

    test('explorer for 3-5', () {
      expect(levelKey(3), 'levelExplorer');
      expect(levelKey(5), 'levelExplorer');
    });

    test('champion for 6-9', () {
      expect(levelKey(6), 'levelChampion');
      expect(levelKey(9), 'levelChampion');
    });

    test('master for 10+', () {
      expect(levelKey(10), 'levelMaster');
      expect(levelKey(50), 'levelMaster');
    });
  });
}
