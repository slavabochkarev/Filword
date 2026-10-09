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

  test(
    'completed level and theme survive reload; replay is not counted twice',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = await ProgressStore.load();
      final world = levels
          .where((level) => level.worldId == 'neon_city')
          .toList();
      expect(store.currentIndex(world), 0);
      expect(await store.recordCompletion(world.first, 42), isTrue);
      expect(await store.recordCompletion(world.first, 9), isFalse);
      await store.setLightTheme(true);
      final reloaded = await ProgressStore.load();
      expect(reloaded.completedIds, {world.first.id});
      expect(reloaded.currentIndex(world), 1);
      expect(reloaded.wordsFound, world.first.words.length);
      expect(reloaded.totalSeconds, 42);
      expect(reloaded.bestSeconds, 42);
      expect(reloaded.lightTheme, isTrue);
    },
  );

  test(
    'next level stays within its world and completed counts are independent',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = await ProgressStore.load();
      final neon = levels
          .where((level) => level.worldId == 'neon_city')
          .toList();
      final cosmos = levels
          .where((level) => level.worldId == 'cosmos')
          .toList();
      await store.recordCompletion(neon.first, 20);
      await store.recordCompletion(cosmos.first, 15);
      expect(store.completedInWorld(neon), 1);
      expect(store.completedInWorld(cosmos), 1);
      expect(store.currentIndex(neon), 1);
      expect(store.currentIndex(cosmos), 1);
      expect(store.bestSeconds, 15);
    },
  );
}
