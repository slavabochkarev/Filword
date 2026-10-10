import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_session.dart';

const worldIds = ['neon_city', 'cosmos', 'biosphere', 'cybercore'];

enum HintKind { start, answer }

class HintPurchase {
  const HintPurchase(this.applied, this.alreadyOwned, this.insufficientFunds);
  final bool applied;
  final bool alreadyOwned;
  final bool insufficientFunds;
}

class CompletionResult {
  const CompletionResult({
    required this.accepted,
    required this.crystalsEarned,
    required this.worldFinished,
    required this.newAchievements,
    required this.levelSeconds,
  });
  final bool accepted;
  final int crystalsEarned;
  final bool worldFinished;
  final List<String> newAchievements;
  final int levelSeconds;
}

class WorldProgress {
  WorldProgress(this.id);
  final String id;
  int currentIndex = 0;
  int completedRuns = 0;
  int completedLevels = 0;
  int wordsFound = 0;
  int hintsUsed = 0;
  int activeSeconds = 0;
  int currentRunSeconds = 0;
  int? lastRunSeconds;
  int? bestRunSeconds;
  int levelSeconds = 0;
  int levelHintsUsed = 0;
  int? activeLevelId;
  final Map<String, List<int>> foundPaths = {};
  final Set<String> hintStarts = {};
  final Set<String> hintAnswers = {};

  factory WorldProgress.fromJson(String id, Map<String, dynamic> json) {
    final value = WorldProgress(id)
      ..currentIndex = json['currentIndex'] as int? ?? 0
      ..completedRuns = json['completedRuns'] as int? ?? 0
      ..completedLevels = json['completedLevels'] as int? ?? 0
      ..wordsFound = json['wordsFound'] as int? ?? 0
      ..hintsUsed = json['hintsUsed'] as int? ?? 0
      ..activeSeconds = json['activeSeconds'] as int? ?? 0
      ..currentRunSeconds = json['currentRunSeconds'] as int? ?? 0
      ..lastRunSeconds = json['lastRunSeconds'] as int?
      ..bestRunSeconds = json['bestRunSeconds'] as int?
      ..levelSeconds = json['levelSeconds'] as int? ?? 0
      ..levelHintsUsed = json['levelHintsUsed'] as int? ?? 0
      ..activeLevelId = json['activeLevelId'] as int?;
    for (final entry in (json['foundPaths'] as Map? ?? {}).entries) {
      value.foundPaths[entry.key as String] = (entry.value as List).cast<int>();
    }
    value.hintStarts.addAll((json['hintStarts'] as List? ?? []).cast<String>());
    value.hintAnswers.addAll(
      (json['hintAnswers'] as List? ?? []).cast<String>(),
    );
    return value;
  }

  Map<String, dynamic> toJson() => {
    'currentIndex': currentIndex,
    'completedRuns': completedRuns,
    'completedLevels': completedLevels,
    'wordsFound': wordsFound,
    'hintsUsed': hintsUsed,
    'activeSeconds': activeSeconds,
    'currentRunSeconds': currentRunSeconds,
    'lastRunSeconds': lastRunSeconds,
    'bestRunSeconds': bestRunSeconds,
    'levelSeconds': levelSeconds,
    'levelHintsUsed': levelHintsUsed,
    'activeLevelId': activeLevelId,
    'foundPaths': foundPaths,
    'hintStarts': hintStarts.toList(),
    'hintAnswers': hintAnswers.toList(),
  };

  void clearLevel() {
    foundPaths.clear();
    hintStarts.clear();
    hintAnswers.clear();
    levelSeconds = 0;
    levelHintsUsed = 0;
    activeLevelId = null;
  }
}

class AchievementDefinition {
  const AchievementDefinition(
    this.id,
    this.category,
    this.title,
    this.description,
    this.target,
    this.value,
  );
  final String id;
  final String category;
  final String title;
  final String description;
  final int target;
  final int Function(ProgressStore) value;
}

final achievementDefinitions = <AchievementDefinition>[
  for (final item in <(String, String, int)>[
    ('first_word', 'Первое слово', 1),
    ('word_finder', 'Словоискатель', 50),
    ('letter_expert', 'Знаток букв', 100),
    ('word_master', 'Мастер слов', 500),
    ('word_lord', 'Повелитель слов', 1000),
    ('word_legend', 'Легенда слов', 5000),
  ])
    AchievementDefinition(
      item.$1,
      'Слова',
      item.$2,
      'Найти ${item.$3} слов',
      item.$3,
      (p) => p.wordsFound,
    ),
  for (final item in <(String, String, int)>[
    ('first_level', 'Первый успех', 1),
    ('first_steps', 'Первые шаги', 10),
    ('explorer', 'Исследователь', 25),
    ('experienced', 'Опытный игрок', 50),
    ('level_master', 'Мастер уровней', 100),
    ('tireless', 'Неутомимый', 250),
  ])
    AchievementDefinition(
      item.$1,
      'Уровни',
      item.$2,
      'Завершить ${item.$3} уровней',
      item.$3,
      (p) => p.totalCompletedLevels,
    ),
  for (final item in <(String, String)>[
    ('city_conqueror', 'Покоритель города'),
    ('cosmos_conqueror', 'Покоритель космоса'),
    ('nature_guardian', 'Хранитель природы'),
    ('science_genius', 'Гений науки'),
  ].indexed)
    AchievementDefinition(
      item.$2.$1,
      'Миры',
      item.$2.$2,
      'Полностью пройти мир',
      1,
      (p) => p.worlds[worldIds[item.$1]]!.completedRuns,
    ),
  AchievementDefinition(
    'world_lord',
    'Миры',
    'Повелитель миров',
    'Пройти все четыре мира',
    4,
    (p) => p.completedWorlds,
  ),
  AchievementDefinition(
    'second_round',
    'Повторные прохождения',
    'Второй круг',
    'Завершить любой мир дважды',
    2,
    (p) => p.worlds.values
        .map((w) => w.completedRuns)
        .reduce((a, b) => a > b ? a : b),
  ),
  AchievementDefinition(
    'persistence',
    'Повторные прохождения',
    'Настойчивость',
    'Завершить один мир трижды',
    3,
    (p) => p.worlds.values
        .map((w) => w.completedRuns)
        .reduce((a, b) => a > b ? a : b),
  ),
  AchievementDefinition(
    'marathon',
    'Повторные прохождения',
    'Марафонец',
    'Завершить один мир пять раз',
    5,
    (p) => p.worlds.values
        .map((w) => w.completedRuns)
        .reduce((a, b) => a > b ? a : b),
  ),
  AchievementDefinition(
    'eternal_explorer',
    'Повторные прохождения',
    'Вечный исследователь',
    'Завершить 10 кругов суммарно',
    10,
    (p) => p.completedRounds,
  ),
  AchievementDefinition(
    'fast_start',
    'Скорость',
    'Быстрый старт',
    'Пройти уровень быстрее 60 секунд',
    1,
    (p) => p.fastUnder60Count,
  ),
  AchievementDefinition(
    'lightning',
    'Скорость',
    'Молния',
    'Пройти уровень быстрее 30 секунд',
    1,
    (p) => p.fastUnder30Count,
  ),
  AchievementDefinition(
    'speed_master',
    'Скорость',
    'Скоростной мастер',
    'Пройти 5 уровней быстрее 60 секунд',
    5,
    (p) => p.fastUnder60Count,
  ),
  AchievementDefinition(
    'first_crystal',
    'Кристаллы и подсказки',
    'Первый кристалл',
    'Получить кристаллы за уровень',
    1,
    (p) => p.levelRewardCount,
  ),
  AchievementDefinition(
    'collector',
    'Кристаллы и подсказки',
    'Коллекционер',
    'Заработать 500 кристаллов',
    500,
    (p) => p.crystalsEarned,
  ),
  AchievementDefinition(
    'treasury',
    'Кристаллы и подсказки',
    'Сокровищница',
    'Заработать 2000 кристаллов',
    2000,
    (p) => p.crystalsEarned,
  ),
  AchievementDefinition(
    'first_hint',
    'Кристаллы и подсказки',
    'Первая подсказка',
    'Использовать подсказку',
    1,
    (p) => p.totalHintsUsed,
  ),
  AchievementDefinition(
    'self_reliant',
    'Кристаллы и подсказки',
    'Самостоятельный',
    'Пройти 10 уровней без подсказок',
    10,
    (p) => p.noHintLevels,
  ),
];

class ProgressStore extends ChangeNotifier {
  ProgressStore._(this._prefs);
  static const _key = 'poiskSlov.progress.v2';
  final SharedPreferences _prefs;
  Future<void> _writeQueue = Future<void>.value();
  final Map<String, WorldProgress> worlds = {
    for (final id in worldIds) id: WorldProgress(id),
  };
  final Set<int> completedIds = {};
  final Set<String> operations = {};
  final Set<String> pendingAchievements = {};
  final Map<String, String?> unlockedAt = {};
  int wordsFound = 0;
  int totalSeconds = 0; // Completed-level times, including the old aggregate.
  int? bestSeconds;
  int totalCompletedLevels = 0;
  int crystalBalance = 0;
  int crystalsEarned = 0;
  int crystalsSpent = 0;
  int fastUnder60Count = 0;
  int fastUnder30Count = 0;
  int noHintLevels = 0;
  int levelRewardCount = 0;
  bool lightTheme = false;
  bool effectsEnabled = true;

  static Future<ProgressStore> load({List<FilwordLevel>? levels}) async {
    final prefs = await SharedPreferences.getInstance();
    final store = ProgressStore._(prefs);
    store.lightTheme = prefs.getBool('lightTheme') ?? false;
    store.effectsEnabled = prefs.getBool('poiskSlov.effectsEnabled.v1') ?? true;
    final saved = prefs.getString(_key);
    if (saved != null) {
      store._read(jsonDecode(saved) as Map<String, dynamic>);
    } else {
      store._migrateLegacy(levels);
      await store._persist();
    }
    return store;
  }

  void _migrateLegacy(List<FilwordLevel>? levels) {
    completedIds.addAll(
      (_prefs.getStringList('completedIds') ?? [])
          .map(int.tryParse)
          .whereType<int>(),
    );
    wordsFound = _prefs.getInt('wordsFound') ?? 0;
    totalSeconds = _prefs.getInt('totalSeconds') ?? 0;
    bestSeconds = _prefs.getInt('bestSeconds');
    totalCompletedLevels = completedIds.length;
    for (var i = 0; i < worldIds.length; i++) {
      final world = worlds[worldIds[i]]!;
      world.completedLevels = completedIds.where((id) => id ~/ 100 == i).length;
      while (completedIds.contains(i * 100 + world.currentIndex + 1) &&
          world.currentIndex < 20) {
        world.currentIndex++;
      }
      if (levels != null) {
        world.wordsFound = levels
            .where(
              (level) =>
                  level.worldId == world.id && completedIds.contains(level.id),
            )
            .fold(0, (sum, level) => sum + level.words.length);
      }
      // Five old test levels never represented a complete 20-level run.
      if (world.currentIndex >= 20) world.currentIndex = 19;
    }
    noHintLevels = completedIds.length; // Old builds had no purchasable hints.
    crystalBalance = crystalsEarned = 100;
    operations.add('starter:v2');
    _refreshAchievements(migration: true);
  }

  void _read(Map<String, dynamic> value) {
    if (value['version'] != 2) {
      throw const FormatException('Unknown progress version');
    }
    completedIds.addAll((value['completedIds'] as List? ?? []).cast<int>());
    operations.addAll((value['operations'] as List? ?? []).cast<String>());
    pendingAchievements.addAll(
      (value['pendingAchievements'] as List? ?? []).cast<String>(),
    );
    unlockedAt.addAll(
      (value['unlockedAt'] as Map? ?? {}).map(
        (key, value) => MapEntry(key as String, value as String?),
      ),
    );
    wordsFound = value['wordsFound'] as int? ?? 0;
    totalSeconds = value['totalSeconds'] as int? ?? 0;
    bestSeconds = value['bestSeconds'] as int?;
    totalCompletedLevels = value['totalCompletedLevels'] as int? ?? 0;
    crystalBalance = value['crystalBalance'] as int? ?? 0;
    crystalsEarned = value['crystalsEarned'] as int? ?? 0;
    crystalsSpent = value['crystalsSpent'] as int? ?? 0;
    fastUnder60Count = value['fastUnder60Count'] as int? ?? 0;
    fastUnder30Count = value['fastUnder30Count'] as int? ?? 0;
    noHintLevels = value['noHintLevels'] as int? ?? 0;
    levelRewardCount = value['levelRewardCount'] as int? ?? 0;
    for (final entry in (value['worlds'] as Map? ?? {}).entries) {
      if (worlds.containsKey(entry.key)) {
        worlds[entry.key as String] = WorldProgress.fromJson(
          entry.key as String,
          (entry.value as Map).cast<String, dynamic>(),
        );
      }
    }
  }

  Map<String, dynamic> _toJson() => {
    'version': 2,
    'completedIds': completedIds.toList()..sort(),
    'operations': operations.toList()..sort(),
    'pendingAchievements': pendingAchievements.toList(),
    'unlockedAt': unlockedAt,
    'wordsFound': wordsFound,
    'totalSeconds': totalSeconds,
    'bestSeconds': bestSeconds,
    'totalCompletedLevels': totalCompletedLevels,
    'crystalBalance': crystalBalance,
    'crystalsEarned': crystalsEarned,
    'crystalsSpent': crystalsSpent,
    'fastUnder60Count': fastUnder60Count,
    'fastUnder30Count': fastUnder30Count,
    'noHintLevels': noHintLevels,
    'levelRewardCount': levelRewardCount,
    'worlds': {
      for (final entry in worlds.entries) entry.key: entry.value.toJson(),
    },
  };

  Future<void> _persist() {
    final snapshot = jsonEncode(_toJson());
    _writeQueue = _writeQueue.then((_) async {
      final saved = await _prefs.setString(_key, snapshot);
      if (!saved) throw StateError('Could not save progress');
    });
    return _writeQueue;
  }

  int get activeSeconds =>
      worlds.values.fold(0, (sum, world) => sum + world.activeSeconds);
  int get completedWorlds =>
      worlds.values.where((world) => world.completedRuns > 0).length;
  int get completedRounds =>
      worlds.values.fold(0, (sum, world) => sum + world.completedRuns);
  int get totalHintsUsed =>
      worlds.values.fold(0, (sum, world) => sum + world.hintsUsed);
  WorldProgress world(String id) => worlds[id]!;

  int currentIndex(List<FilwordLevel> levels) => levels.isEmpty
      ? 0
      : world(levels.first.worldId).currentIndex.clamp(0, levels.length - 1);

  int completedInWorld(List<FilwordLevel> levels) =>
      levels.isEmpty ? 0 : world(levels.first.worldId).currentIndex;

  Future<void> addActiveSeconds(String worldId, int seconds) async {
    if (seconds <= 0) return;
    final data = world(worldId);
    data.activeSeconds += seconds;
    data.currentRunSeconds += seconds;
    data.levelSeconds += seconds;
    await _persist();
  }

  List<FoundPath> restoredPaths(FilwordLevel level) {
    final data = world(level.worldId);
    if (data.activeLevelId != level.id) return [];
    return [
      for (final entry in data.foundPaths.entries)
        FoundPath(entry.key, List.of(entry.value)),
    ];
  }

  Future<void> recordFound(FilwordLevel level, FoundPath found) async {
    final data = world(level.worldId);
    if (data.activeLevelId != level.id) {
      data.clearLevel();
      data.activeLevelId = level.id;
    }
    if (data.foundPaths.containsKey(found.word)) return;
    data.foundPaths[found.word] = List.of(found.path);
    data.wordsFound++;
    wordsFound++;
    pendingAchievements.addAll(_refreshAchievements());
    await _persist();
  }

  Future<void> clearFound(FilwordLevel level) async {
    final data = world(level.worldId);
    data.foundPaths.clear();
    data.activeLevelId = level.id;
    await _persist();
  }

  Future<HintPurchase> buyHint(
    FilwordLevel level,
    String word,
    HintKind kind,
  ) async {
    final data = world(level.worldId);
    if (!level.words.any((target) => target.text == word) ||
        data.foundPaths.containsKey(word)) {
      return const HintPurchase(false, false, false);
    }
    if (data.activeLevelId != level.id) {
      data.clearLevel();
      data.activeLevelId = level.id;
    }
    final owned = kind == HintKind.start ? data.hintStarts : data.hintAnswers;
    if (owned.contains(word)) return const HintPurchase(true, true, false);
    final cost = kind == HintKind.start ? 20 : 30;
    if (crystalBalance < cost) return const HintPurchase(false, false, true);
    final op =
        'hint:${level.worldId}:${data.completedRuns + 1}:${level.id}:$word:${kind.name}';
    if (operations.contains(op)) return const HintPurchase(true, true, false);
    operations.add(op);
    crystalBalance -= cost;
    crystalsSpent += cost;
    data.hintsUsed++;
    data.levelHintsUsed++;
    owned.add(word);
    pendingAchievements.addAll(_refreshAchievements());
    await _persist();
    notifyListeners();
    return const HintPurchase(true, false, false);
  }

  Future<CompletionResult> completeLevel(
    FilwordLevel level,
    int seconds,
  ) async {
    final data = world(level.worldId);
    final op = 'level:${level.worldId}:${data.completedRuns + 1}:${level.id}';
    if (operations.contains(op) || data.currentIndex != (level.id % 100) - 1) {
      return CompletionResult(
        accepted: false,
        crystalsEarned: 0,
        worldFinished: false,
        newAchievements: const [],
        levelSeconds: seconds,
      );
    }
    final duration = seconds > data.levelSeconds ? seconds : data.levelSeconds;
    if (duration > data.levelSeconds) {
      final difference = duration - data.levelSeconds;
      data.activeSeconds += difference;
      data.currentRunSeconds += difference;
    }
    operations.add(op);
    final firstTime = completedIds.add(level.id);
    final levelReward = firstTime ? 10 : 2;
    var reward = levelReward;
    crystalBalance += levelReward;
    crystalsEarned += levelReward;
    levelRewardCount++;
    data.completedLevels++;
    final remainingWords = level.words.length - data.foundPaths.length;
    data.wordsFound += remainingWords;
    wordsFound += remainingWords;
    totalCompletedLevels++;
    totalSeconds += duration;
    if (bestSeconds == null || duration < bestSeconds!) bestSeconds = duration;
    if (duration < 60) fastUnder60Count++;
    if (duration < 30) fastUnder30Count++;
    if (data.levelHintsUsed == 0) noHintLevels++;
    data.currentIndex++;
    final finishedWorld = data.currentIndex == 20;
    if (finishedWorld) {
      final worldOp = 'world:${level.worldId}:${data.completedRuns + 1}';
      if (operations.add(worldOp)) {
        reward += 50;
        crystalBalance += 50;
        crystalsEarned += 50;
      }
      data.lastRunSeconds = data.currentRunSeconds;
      if (data.bestRunSeconds == null ||
          data.currentRunSeconds < data.bestRunSeconds!) {
        data.bestRunSeconds = data.currentRunSeconds;
      }
      data.completedRuns++;
      data.currentIndex = 0;
      data.currentRunSeconds = 0;
    }
    data.clearLevel();
    final newlyUnlocked = [...pendingAchievements, ..._refreshAchievements()];
    pendingAchievements.clear();
    await _persist();
    notifyListeners();
    return CompletionResult(
      accepted: true,
      crystalsEarned: reward,
      worldFinished: finishedWorld,
      newAchievements: newlyUnlocked,
      levelSeconds: duration,
    );
  }

  Future<bool> recordCompletion(FilwordLevel level, int seconds) async =>
      (await completeLevel(level, seconds)).accepted;

  List<String> _refreshAchievements({bool migration = false}) {
    final added = <String>[];
    for (final definition in achievementDefinitions) {
      if (!unlockedAt.containsKey(definition.id) &&
          definition.value(this) >= definition.target) {
        unlockedAt[definition.id] = migration
            ? null
            : DateTime.now().toUtc().toIso8601String();
        added.add(definition.title);
      }
    }
    return added;
  }

  Future<void> setEffectsEnabled(bool value) async {
    effectsEnabled = value;
    await _prefs.setBool('poiskSlov.effectsEnabled.v1', value);
  }

  Future<void> setLightTheme(bool value) async {
    lightTheme = value;
    await _prefs.setBool('lightTheme', value);
  }
}
