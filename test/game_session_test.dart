import 'dart:convert';
import 'dart:io';

import 'package:filword/game_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final levels =
      (jsonDecode(File('assets/levels.json').readAsStringSync()) as List)
          .map((entry) => FilwordLevel.fromJson(entry as Map<String, dynamic>))
          .toList();
  final examples = jsonDecode(
    File('test/fixtures/orthogonal_examples.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test(
    'all 80 levels use orthogonal canonical paths and cover their grids',
    () {
      expect(levels.length, 80);
      for (final level in levels) {
        final cells = <int>[];
        for (final word in level.words) {
          expect(level.spell(word.canonicalPath), word.text);
          expect(word.canonicalPath.toSet().length, word.canonicalPath.length);
          for (var i = 1; i < word.canonicalPath.length; i++) {
            expect(
              GameSession.adjacent(
                word.canonicalPath[i - 1],
                word.canonicalPath[i],
                level.gridSize,
              ),
              isTrue,
            );
          }
          cells.addAll(word.canonicalPath);
        }
        expect(cells.length, level.gridSize * level.gridSize);
        expect(cells.toSet().length, cells.length);
      }
    },
  );

  test('alternative four-direction path keeps the exact selected route', () {
    for (final entry in examples.entries) {
      final example = entry.value as Map<String, dynamic>;
      final level = levels.firstWhere(
        (level) => level.id == example['levelId'],
      );
      final path = (example['path'] as List).cast<int>();
      final canonical = (example['canonical'] as List).cast<int>();
      final target = level.words.firstWhere(
        (word) => word.canonicalPath.join(',') == canonical.join(','),
      );
      expect(level.spell(path), target.text);
      expect(path, isNot(canonical));
      final game = GameSession(level);
      expect(game.submit(path).status, SelectionStatus.found);
      expect(game.foundPaths.single.path, path);
      expect(game.submit(canonical).status, SelectionStatus.alreadyFound);
    }
  });

  test(
    'diagonal is rejected; right-angle turns and no repeated cells work',
    () {
      final level = levels.first;
      final game = GameSession(level);
      final size = level.gridSize;
      expect(GameSession.adjacent(0, size + 1, size), isFalse);
      expect(game.submit([0, size + 1]).status, SelectionStatus.invalid);
      final turned = level.words.firstWhere((word) {
        final path = word.canonicalPath;
        final directions = <int>{};
        for (var i = 1; i < path.length; i++) {
          directions.add(path[i] - path[i - 1]);
        }
        return directions.length > 1;
      });
      expect(game.submit(turned.canonicalPath).status, SelectionStatus.found);
      expect(game.submit([0, 0]).status, SelectionStatus.invalid);
      expect(game.submit([0, size * size - 1]).status, SelectionStatus.invalid);
    },
  );

  test('selected highlights may cross a previously found word', () {
    final example = examples['neon_city'] as Map<String, dynamic>;
    final level = levels.firstWhere((level) => level.id == example['levelId']);
    final path = (example['path'] as List).cast<int>();
    final canonical = (example['canonical'] as List).cast<int>();
    final target = level.words.firstWhere(
      (word) => word.canonicalPath.join(',') == canonical.join(','),
    );
    final other = level.words.firstWhere(
      (word) =>
          word.text != target.text &&
          word.canonicalPath.toSet().intersection(path.toSet()).isNotEmpty,
    );
    final game = GameSession(level);
    expect(game.submit(other.canonicalPath).status, SelectionStatus.found);
    expect(game.submit(path).status, SelectionStatus.found);
    expect(game.foundPaths.last.path, path);
  });

  test('completion requires each target once', () {
    final level = levels.first;
    final game = GameSession(level);
    for (final word in level.words) {
      expect(game.submit(word.canonicalPath).status, SelectionStatus.found);
    }
    expect(game.completed, isTrue);
    expect(
      game.submit(level.words.first.canonicalPath).status,
      SelectionStatus.alreadyFound,
    );
  });
}
