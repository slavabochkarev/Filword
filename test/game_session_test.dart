import 'dart:convert';
import 'dart:io';

import 'package:filword/game_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final data = jsonDecode(File('assets/levels_stage4.json').readAsStringSync()) as List;
  final levels = data.map((entry) => FilwordLevel.fromJson(entry as Map<String, dynamic>)).toList();
  final alternatives = jsonDecode(File('test/fixtures/alternative_examples.json').readAsStringSync()) as Map<String, dynamic>;

  test('10 source levels retain valid canonical paths and full coverage', () {
    expect(levels.length, 10);
    for (final level in levels) {
      expect(level.grid.length, 10);
      expect(level.grid.every((row) => row.length == 10), isTrue);
      final cells = <int>[];
      for (final word in level.words) {
        expect(level.spell(word.canonicalPath), word.text);
        expect(word.canonicalPath.toSet().length, word.canonicalPath.length);
        for (var i = 1; i < word.canonicalPath.length; i++) {
          expect(GameSession.adjacent(word.canonicalPath[i - 1], word.canonicalPath[i]), isTrue);
        }
        cells.addAll(word.canonicalPath);
      }
      expect(cells.length, 100);
      expect(cells.toSet().length, 100);
    }
  });

  test('alternative path is accepted and that exact path is remembered', () {
    final level = levels.firstWhere((entry) => entry.id == 16);
    final example = alternatives['16'] as Map<String, dynamic>;
    final path = (example['path'] as List).cast<int>();
    final canonical = (example['canonical'] as List).cast<int>();
    expect(path, isNot(canonical));
    final game = GameSession(level);
    final result = game.submit(path);
    expect(result.status, SelectionStatus.found);
    expect(result.text, example['word']);
    expect(game.foundPaths.single.path, path);
    expect(game.foundPaths.single.path, isNot(canonical));
    expect(game.submit(canonical).status, SelectionStatus.alreadyFound);
    expect(game.foundCount, 1);
  });

  test('diagonals, turns, repeat cell, and disconnected gesture', () {
    final level = levels.first;
    final game = GameSession(level);
    final angled = level.words.firstWhere((word) {
      final path = word.canonicalPath;
      final diagonal = List.generate(path.length - 1, (i) =>
        (path[i] ~/ 10 - path[i + 1] ~/ 10).abs() == 1 &&
        (path[i] % 10 - path[i + 1] % 10).abs() == 1).contains(true);
      final directions = <String>{};
      for (var i = 1; i < path.length; i++) {
        directions.add('${path[i] ~/ 10 - path[i - 1] ~/ 10},${path[i] % 10 - path[i - 1] % 10}');
      }
      return diagonal && directions.length > 1;
    });
    expect(game.submit(angled.canonicalPath).status, SelectionStatus.found);
    expect(game.submit([0, 0]).status, SelectionStatus.invalid);
    expect(game.submit([0, 99]).status, SelectionStatus.invalid);
    expect(game.submit([-1]).status, SelectionStatus.invalid);
  });

  test('found paths may overlap; later path is retained separately', () {
    final level = levels.first;
    final example = alternatives['1'] as Map<String, dynamic>;
    final alternative = (example['path'] as List).cast<int>();
    final other = level.words.firstWhere((word) => word.text != example['word'] &&
      word.canonicalPath.any(alternative.contains));
    final game = GameSession(level);
    expect(game.submit(other.canonicalPath).status, SelectionStatus.found);
    expect(game.submit(alternative).status, SelectionStatus.found);
    expect(game.foundPaths.length, 2);
    expect(game.foundPaths.first.path.toSet().intersection(game.foundPaths.last.path.toSet()), isNotEmpty);
    expect(game.foundPaths.last.path, alternative);
  });

  test('level completes only after all distinct target words', () {
    final level = levels.first;
    final game = GameSession(level);
    for (final word in level.words) {
      expect(game.submit(word.canonicalPath).status, SelectionStatus.found);
    }
    expect(game.completed, isTrue);
    expect(game.foundCount, level.words.length);
    expect(game.submit(level.words.first.canonicalPath).status, SelectionStatus.alreadyFound);
  });
}
