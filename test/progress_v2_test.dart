import 'dart:convert';
import 'dart:io';

import 'package:filword/game_session.dart';
import 'package:filword/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final levels =
      (jsonDecode(File('assets/levels.json').readAsStringSync()) as List)
          .map((item) => FilwordLevel.fromJson(item as Map<String, dynamic>))
          .toList();
  final city = levels.where((item) => item.worldId == 'neon_city').toList();
  final cosmos = levels.where((item) => item.worldId == 'cosmos').toList();
  final oldLevels =
      (jsonDecode(
            File('output_stage13/pre_orthogonal_levels.json')
                .readAsStringSync(),
          ) as List)
          .map((item) => FilwordLevel.fromJson(item as Map<String, dynamic>))
          .toList();

  test('legacy migration keeps five levels, unknown world times and one starter grant', () async {
    SharedPreferences.setMockInitialValues({
      'completedIds': ['1', '2', '3', '4', '5'],
      'wordsFound': 44,
      'totalSeconds': 123,
      'lightTheme': true,
    });
    var store = await ProgressStore.load(levels: levels);
    expect(store.currentIndex(city), 5);
    expect(store.world('neon_city').completedRuns, 0);
    expect(store.world('neon_city').lastRunSeconds, isNull);
    expect(store.world('neon_city').bestRunSeconds, isNull);
    expect(store.activeSeconds, 0);
    expect(store.totalSeconds, 123);
    expect(store.lightTheme, isTrue);
    expect(store.crystalBalance, 100);
    expect(store.crystalsEarned, 100);
    store = await ProgressStore.load(levels: levels);
    expect(store.crystalBalance, 100);
    expect(store.currentIndex(city), 5);
  });

  test(
    'active seconds and worlds are independent and survive reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      var store = await ProgressStore.load(levels: levels);
      await store.addActiveSeconds('neon_city', 7);
      await store.addActiveSeconds('cosmos', 11);
      store = await ProgressStore.load(levels: levels);
      expect(store.activeSeconds, 18);
      expect(store.world('neon_city').activeSeconds, 7);
      expect(store.world('cosmos').activeSeconds, 11);
      expect(store.world('neon_city').currentRunSeconds, 7);
    },
  );

  test('twentieth level completes world and second round awards only replay rewards', () async {
    SharedPreferences.setMockInitialValues({});
    var store = await ProgressStore.load(levels: levels);
    for (final level in city.take(19)) {
      final result = await store.completeLevel(level, 2);
      expect(result.accepted, isTrue);
      expect(result.crystalsEarned, 10);
    }
    final end = await store.completeLevel(city.last, 2);
    expect(end.worldFinished, isTrue);
    expect(end.crystalsEarned, 60);
    expect(store.world('neon_city').completedRuns, 1);
    expect(store.world('neon_city').currentIndex, 0);
    expect(store.world('neon_city').lastRunSeconds, 40);
    expect(store.world('neon_city').bestRunSeconds, 40);
    expect(store.crystalBalance, 350);
    expect((await store.completeLevel(city.last, 2)).accepted, isFalse);
    store = await ProgressStore.load(levels: levels);
    expect(store.crystalBalance, 350);
    for (final level in city) {
      final result = await store.completeLevel(level, 3);
      expect(result.accepted, isTrue);
      expect(result.crystalsEarned, level.id == city.last.id ? 52 : 2);
    }
    expect(store.world('neon_city').completedRuns, 2);
    expect(store.world('neon_city').bestRunSeconds, 40);
    expect(store.world('neon_city').lastRunSeconds, 60);
    expect(store.world('neon_city').completedLevels, 40);
    expect(store.totalCompletedLevels, 40);
    expect(store.crystalBalance, 440);
    expect(store.completedIds.length, 20);
  });

  test('hints charge once, persist and never go below zero', () async {
    SharedPreferences.setMockInitialValues({});
    var store = await ProgressStore.load(levels: levels);
    final word = city.first.words.first;
    var result = await store.buyHint(city.first, word.text, HintKind.start);
    expect(result.applied, isTrue);
    expect(result.alreadyOwned, isFalse);
    expect(store.crystalBalance, 80);
    result = await store.buyHint(city.first, word.text, HintKind.start);
    expect(result.alreadyOwned, isTrue);
    expect(store.crystalBalance, 80);
    result = await store.buyHint(city.first, word.text, HintKind.answer);
    expect(result.applied, isTrue);
    expect(store.crystalBalance, 50);
    store = await ProgressStore.load(levels: levels);
    expect(store.world('neon_city').hintStarts, contains(word.text));
    expect(store.world('neon_city').hintAnswers, contains(word.text));
    expect(store.crystalsSpent, 50);
    for (final other in city.first.words.skip(1)) {
      await store.buyHint(city.first, other.text, HintKind.answer);
    }
    expect(store.crystalBalance, greaterThanOrEqualTo(0));
    expect(store.crystalsEarned - store.crystalsSpent, store.crystalBalance);
  });

  test('found path survives restart and is cleared after completion', () async {
    SharedPreferences.setMockInitialValues({});
    var store = await ProgressStore.load(levels: levels);
    final word = city.first.words.first;
    await store.recordFound(
      city.first,
      FoundPath(word.text, word.canonicalPath),
    );
    store = await ProgressStore.load(levels: levels);
    expect(store.restoredPaths(city.first).single.path, word.canonicalPath);
    expect(store.restoredPaths(cosmos.first), isEmpty);
    await store.completeLevel(city.first, 5);
    expect(store.restoredPaths(city.first), isEmpty);
  });

  test(
    'old diagonal save retains rewards and found words on new boards',
    () async {
      SharedPreferences.setMockInitialValues({});
      final oldCity = oldLevels
          .where((item) => item.worldId == 'neon_city')
          .toList();
      var store = await ProgressStore.load(levels: oldLevels);
      await store.completeLevel(oldCity.first, 15);
      final found = oldCity[1].words.first;
      final hint = oldCity[1].words[1];
      await store.recordFound(
        oldCity[1],
        FoundPath(found.text, found.canonicalPath),
      );
      await store.buyHint(oldCity[1], hint.text, HintKind.start);
      final originalBalance = store.crystalBalance;
      final originalWords = store.wordsFound;
      final prefs = await SharedPreferences.getInstance();
      final oldSnapshot = jsonDecode(
        prefs.getString('poiskSlov.progress.v2')!,
      ) as Map<String, dynamic>;
      oldSnapshot.remove('levelContentRevision');
      await prefs.setString('poiskSlov.progress.v2', jsonEncode(oldSnapshot));

      store = await ProgressStore.load(levels: levels);
      expect(
        store.levelContentRevision,
        ProgressStore.currentLevelContentRevision,
      );
      expect(store.currentIndex(city), 1);
      expect(store.completedIds, contains(oldCity.first.id));
      expect(store.wordsFound, originalWords);
      expect(store.crystalBalance, originalBalance);
      expect(store.world('neon_city').hintStarts, contains(hint.text));
      final restored = store.restoredPaths(city[1]).single;
      expect(restored.word, found.text);
      expect(
        GameSession(city[1]).submit(restored.path).status,
        SelectionStatus.found,
      );
      final stablePath = List.of(restored.path);
      store = await ProgressStore.load(levels: levels);
      expect(store.restoredPaths(city[1]).single.path, stablePath);
      expect(store.crystalBalance, originalBalance);
    },
  );

  test('achievements unlock once and keep their dates', () async {
    SharedPreferences.setMockInitialValues({});
    var store = await ProgressStore.load(levels: levels);
    expect(achievementDefinitions.length, 29);
    final result = await store.completeLevel(city.first, 20);
    expect(result.newAchievements, contains('Первое слово'));
    expect(result.newAchievements, contains('Первый успех'));
    expect(result.newAchievements, contains('Быстрый старт'));
    expect(result.newAchievements, contains('Молния'));
    final date = store.unlockedAt['first_level'];
    expect(date, isNotNull);
    expect(
      (await store.completeLevel(city.first, 20)).newAchievements,
      isEmpty,
    );
    store = await ProgressStore.load(levels: levels);
    expect(store.unlockedAt['first_level'], date);
  });
}
