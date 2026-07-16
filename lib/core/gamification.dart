import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Hive-backed gamification state.
/// Tracks XP, level, streak, last active date, unlocked badges.
@immutable
class GameState {
  final int xp;
  final int level;
  final int streakDays;

  /// Highest [streakDays] value ever reached on this device. Persisted so
  /// the user can see "longest streak" as a stat even after their current
  /// streak resets — gives a sense of personal best.
  ///
  /// Always >= [streakDays].
  final int longestStreak;
  final String? lastActiveDate; // ISO yyyy-MM-dd
  final List<String> badges;

  const GameState({
    this.xp = 0,
    this.level = 1,
    this.streakDays = 0,
    this.longestStreak = 0,
    this.lastActiveDate,
    this.badges = const [],
  });

  /// Each level requires (level * 100) XP cumulative growth.
  /// xpForLevel(1) = 0, xpForLevel(2) = 100, xpForLevel(3) = 250, ...
  static int xpForLevel(int level) {
    if (level <= 1) return 0;
    int total = 0;
    for (int i = 1; i < level; i++) {
      total += i * 100;
    }
    return total;
  }

  int get xpForCurrentLevel => xpForLevel(level);
  int get xpForNextLevel => xpForLevel(level + 1);
  int get xpInLevel => xp - xpForCurrentLevel;
  int get xpNeededInLevel => xpForNextLevel - xpForCurrentLevel;

  /// 0..1 progress through current level.
  double get levelProgress {
    final needed = xpNeededInLevel;
    if (needed <= 0) return 1;
    return (xpInLevel / needed).clamp(0.0, 1.0);
  }

  /// Pure streak calculator. Given the previous streak, the last active
  /// date string (`yyyy-MM-dd` or null) and today's date string, returns
  /// the new streak length.
  ///
  /// Rules:
  /// - same day as last → unchanged (no double-count)
  /// - never seen before → 1
  /// - exactly 1 calendar day later → previous + 1
  /// - more than 1 calendar day later → reset to 1
  /// - earlier (clock skew) → unchanged
  static int computeStreak({
    required int currentStreak,
    required String? lastActiveDate,
    required String today,
  }) {
    if (lastActiveDate == today) return currentStreak;
    if (lastActiveDate == null) return 1;
    final last = DateTime.parse(lastActiveDate);
    final now = DateTime.parse(today);
    final diff = now.difference(last).inDays;
    if (diff == 1) return currentStreak + 1;
    if (diff > 1) return 1;
    return currentStreak;
  }

  GameState copyWith({
    int? xp,
    int? level,
    int? streakDays,
    int? longestStreak,
    String? lastActiveDate,
    List<String>? badges,
  }) {
    return GameState(
      xp: xp ?? this.xp,
      level: level ?? this.level,
      streakDays: streakDays ?? this.streakDays,
      longestStreak: longestStreak ?? this.longestStreak,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      badges: badges ?? this.badges,
    );
  }

  Map<String, dynamic> toJson() => {
        'xp': xp,
        'level': level,
        'streakDays': streakDays,
        'longestStreak': longestStreak,
        'lastActiveDate': lastActiveDate,
        'badges': badges,
      };

  factory GameState.fromJson(Map json) {
    final streak = (json['streakDays'] as int?) ?? 0;
    // Backwards-compat: when reading state persisted by an older build
    // that didn't track longestStreak, fall back to the current streak so
    // the "personal best" stat starts at a sensible value instead of 0.
    final longest = (json['longestStreak'] as int?) ?? streak;
    return GameState(
      xp: (json['xp'] as int?) ?? 0,
      level: (json['level'] as int?) ?? 1,
      streakDays: streak,
      longestStreak: longest >= streak ? longest : streak,
      lastActiveDate: json['lastActiveDate'] as String?,
      badges: ((json['badges'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

/// Built-in badges. Unlocked client-side based on milestones.
class GameBadge {
  final String id;
  final String emoji;

  const GameBadge(this.id, this.emoji);

  static const firstStep = GameBadge('first_step', '👶');
  static const fiveDayStreak = GameBadge('streak_5', '🔥');
  static const tenAssessments = GameBadge('assess_10', '🎯');
  static const level5 = GameBadge('level_5', '⭐');
  static const level10 = GameBadge('level_10', '🏆');
  static const perfectScore = GameBadge('perfect', '💯');

  static const all = [
    firstStep,
    fiveDayStreak,
    tenAssessments,
    level5,
    level10,
    perfectScore,
  ];

  static String emojiOf(String id) =>
      all.firstWhere((b) => b.id == id, orElse: () => firstStep).emoji;
}

/// Type of "next badge" goal — drives which counter is shown in the UI.
enum NextBadgeGoalKind { streak, level, assessments }

/// Forward-looking hint for the achievements screen: "what should the user
/// do next to earn the next badge?"
class NextBadgeGoal {
  const NextBadgeGoal({
    required this.badgeId,
    required this.kind,
    required this.current,
    required this.target,
  });

  final String badgeId;
  final NextBadgeGoalKind kind;
  final int current;
  final int target;

  /// 0..1 progress toward the target. Always clamped.
  double get progress {
    if (target <= 0) return 1;
    final raw = current / target;
    return raw.isNaN ? 0 : raw.clamp(0.0, 1.0);
  }

  bool get isComplete => current >= target;

  /// Pure pick-the-best logic: return the badge whose remaining work is
  /// smallest (relative to its target). Skips badges already unlocked.
  /// Returns `null` if every built-in badge is already unlocked, signalling
  /// the screen to show the "you got them all" copy.
  static NextBadgeGoal? compute({
    required List<String> unlockedBadgeIds,
    required int streakDays,
    required int level,
    required int assessmentsCount,
  }) {
    final candidates = <NextBadgeGoal>[];

    if (!unlockedBadgeIds.contains(GameBadge.firstStep.id)) {
      // First step unlocks on the very first active day. Treat it as a
      // streak goal toward 1.
      candidates.add(NextBadgeGoal(
        badgeId: GameBadge.firstStep.id,
        kind: NextBadgeGoalKind.streak,
        current: streakDays,
        target: 1,
      ));
    }
    if (!unlockedBadgeIds.contains(GameBadge.fiveDayStreak.id)) {
      candidates.add(NextBadgeGoal(
        badgeId: GameBadge.fiveDayStreak.id,
        kind: NextBadgeGoalKind.streak,
        current: streakDays,
        target: 5,
      ));
    }
    if (!unlockedBadgeIds.contains(GameBadge.tenAssessments.id)) {
      candidates.add(NextBadgeGoal(
        badgeId: GameBadge.tenAssessments.id,
        kind: NextBadgeGoalKind.assessments,
        current: assessmentsCount,
        target: 10,
      ));
    }
    if (!unlockedBadgeIds.contains(GameBadge.level5.id)) {
      candidates.add(NextBadgeGoal(
        badgeId: GameBadge.level5.id,
        kind: NextBadgeGoalKind.level,
        current: level,
        target: 5,
      ));
    }
    if (!unlockedBadgeIds.contains(GameBadge.level10.id)) {
      candidates.add(NextBadgeGoal(
        badgeId: GameBadge.level10.id,
        kind: NextBadgeGoalKind.level,
        current: level,
        target: 10,
      ));
    }

    if (candidates.isEmpty) return null;

    // Pick the goal with the smallest *absolute* remaining work, so a brand-
    // new user sees `first_step` (1 step away) ahead of `level_5` (4 levels
    // away) even though level_5 starts at a non-zero progress ratio. Ties
    // are broken by smallest target so the most attainable badge wins.
    candidates.sort((a, b) {
      final remainingA = (a.target - a.current).clamp(0, a.target);
      final remainingB = (b.target - b.current).clamp(0, b.target);
      final cmp = remainingA.compareTo(remainingB);
      if (cmp != 0) return cmp;
      return a.target.compareTo(b.target);
    });
    return candidates.first;
  }
}

const _gameBoxName = 'sado_game';
const _gameKey = 'state';

class GameNotifier extends StateNotifier<GameState> {
  GameNotifier() : super(const GameState()) {
    _ready = _load();
  }

  Box? _box;

  // Future that completes once the initial load attempt has settled
  // (whether it actually loaded persisted state or fell through to the
  // default). Tests can `await notifier.ready` to avoid races between the
  // background load and assertions.
  late final Future<void> _ready;

  /// Resolves when the initial load attempt has completed.
  Future<void> get ready => _ready;

  Future<void> _load() async {
    try {
      _box = await Hive.openBox(_gameBoxName);
      final raw = _box!.get(_gameKey);
      if (raw is Map) {
        state = GameState.fromJson(raw);
      }
    } catch (_) {
      // Hive may not be initialised (e.g. under flutter_test). Keep
      // the default in-memory state; persistence is simply skipped.
    }
  }

  Future<void> _persist(GameState s) async {
    state = s;
    try {
      await _box?.put(_gameKey, s.toJson());
    } catch (_) {
      // Persistence is best-effort.
    }
  }

  /// Award XP, recompute level and unlock level badges.
  /// Returns the list of newly unlocked badge ids.
  Future<List<String>> addXp(int amount) async {
    if (amount <= 0) return const [];
    int newXp = state.xp + amount;
    int newLevel = state.level;
    while (newXp >= GameState.xpForLevel(newLevel + 1)) {
      newLevel++;
    }
    final unlocked = <String>[];
    final badges = [...state.badges];
    if (newLevel >= 5 && !badges.contains(GameBadge.level5.id)) {
      badges.add(GameBadge.level5.id);
      unlocked.add(GameBadge.level5.id);
    }
    if (newLevel >= 10 && !badges.contains(GameBadge.level10.id)) {
      badges.add(GameBadge.level10.id);
      unlocked.add(GameBadge.level10.id);
    }
    await _persist(state.copyWith(xp: newXp, level: newLevel, badges: badges));
    return unlocked;
  }

  /// Mark today as active. Updates streak. Returns badges newly unlocked.
  Future<List<String>> markActiveToday() async {
    final today = _today();
    final unlocked = <String>[];
    final streak = GameState.computeStreak(
      currentStreak: state.streakDays,
      lastActiveDate: state.lastActiveDate,
      today: today,
    );

    final badges = [...state.badges];
    if (state.lastActiveDate == null &&
        !badges.contains(GameBadge.firstStep.id)) {
      badges.add(GameBadge.firstStep.id);
      unlocked.add(GameBadge.firstStep.id);
    }
    if (streak >= 5 && !badges.contains(GameBadge.fiveDayStreak.id)) {
      badges.add(GameBadge.fiveDayStreak.id);
      unlocked.add(GameBadge.fiveDayStreak.id);
    }

    await _persist(state.copyWith(
      streakDays: streak,
      longestStreak:
          streak > state.longestStreak ? streak : state.longestStreak,
      lastActiveDate: today,
      badges: badges,
    ));
    return unlocked;
  }

  Future<List<String>> recordAssessment({
    required int totalAssessments,
    double? score,
  }) async {
    final unlocked = <String>[];
    final newlyXp = await addXp(20);
    unlocked.addAll(newlyXp);
    final activeBadges = await markActiveToday();
    unlocked.addAll(activeBadges);

    final badges = [...state.badges];
    if (totalAssessments >= 10 &&
        !badges.contains(GameBadge.tenAssessments.id)) {
      badges.add(GameBadge.tenAssessments.id);
      unlocked.add(GameBadge.tenAssessments.id);
    }
    if (score != null &&
        score >= 0.95 &&
        !badges.contains(GameBadge.perfectScore.id)) {
      badges.add(GameBadge.perfectScore.id);
      unlocked.add(GameBadge.perfectScore.id);
    }
    if (badges.length != state.badges.length) {
      await _persist(state.copyWith(badges: badges));
    }
    return unlocked;
  }

  Future<void> reset() async => _persist(const GameState());

  static String _today() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }
}

final gameProvider =
    StateNotifierProvider<GameNotifier, GameState>((ref) => GameNotifier());

/// Friendly level name (i18n keys live in arb).
String levelKey(int level) {
  if (level <= 2) return 'levelBeginner';
  if (level <= 5) return 'levelExplorer';
  if (level <= 9) return 'levelChampion';
  return 'levelMaster';
}
