import 'dart:convert';
import 'dart:io';

import 'package:filword/game_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final levels =
      (jsonDecode(File('assets/levels.json').readAsStringSync()) as List)
          .map((value) => FilwordLevel.fromJson(value as Map<String, dynamic>))
          .toList();

  test('all 20 levels load with correct size and exact canonical coverage', () {
    expect(levels.length, 20);
    final expected = {
      'neon_city': 7,
      'cosmos': 8,
      'biosphere': 9,
      'cybercore': 10,
    };
    for (final level in levels) {
      final size = expected[level.worldId]!;
      expect(level.gridSize, size);
      expect(level.grid.length, size);
      expect(level.grid.every((row) => row.length == size), isTrue);
      final cells = <int>[];
      for (final word in level.words) {
        expect(level.spell(word.canonicalPath), word.text);
        for (var i = 1; i < word.canonicalPath.length; i++) {
          expect(
            GameSession.adjacent(
              word.canonicalPath[i - 1],
              word.canonicalPath[i],
              size,
            ),
            isTrue,
          );
        }
        cells.addAll(word.canonicalPath);
      }
      expect(cells.length, size * size);
      expect(cells.toSet().length, size * size);
    }
  });

  test('adjacency respects row boundaries for every size', () {
    for (final size in [7, 8, 9, 10]) {
      expect(GameSession.adjacent(size - 1, size, size), isFalse);
      expect(GameSession.adjacent(0, size + 1, size), isTrue);
      expect(GameSession.adjacent(0, size * size, size), isFalse);
    }
  });

  test('wrong, repeated and complete selection use dynamic indexes', () {
    for (final size in [7, 8, 9, 10]) {
      final level = levels.firstWhere((level) => level.gridSize == size);
      final game = GameSession(level);
      expect(game.submit([size * size]).status, SelectionStatus.invalid);
      expect(game.submit([0, 0]).status, SelectionStatus.invalid);
      for (final word in level.words) {
        expect(game.submit(word.canonicalPath).status, SelectionStatus.found);
      }
      expect(game.completed, isTrue);
      expect(
        game.submit(level.words.first.canonicalPath).status,
        SelectionStatus.alreadyFound,
      );
    }
  });

  test('old 10×10 JSON without gridSize still loads', () {
    final old = (jsonDecode(
      File('assets/levels_stage4.json').readAsStringSync(),
    ) as List).first;
    final level = FilwordLevel.fromJson(old as Map<String, dynamic>);
    expect(level.gridSize, 10);
    expect(
      GameSession(level).submit(level.words.first.canonicalPath).status,
      SelectionStatus.found,
    );
  });

  test('current 20 target lists have no shorter-word prefixes', () {
    for (final level in levels) {
      for (final first in level.words) {
        for (final second in level.words) {
          if (identical(first, second)) continue;
          expect(
            second.text.startsWith(first.text),
            isFalse,
            reason: 'Level ${level.id}: ${first.text} prefixes ${second.text}',
          );
        }
      }
    }
  });
}
