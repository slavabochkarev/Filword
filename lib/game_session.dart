class WordTarget {
  WordTarget(this.text, this.canonicalPath);
  final String text;
  final List<int> canonicalPath;

  factory WordTarget.fromJson(Map<String, dynamic> json, int size) =>
      WordTarget(
        json['text'] as String,
        (json['path'] as List).map((point) {
          final pair = point as List;
          return (pair[0] as int) * size + (pair[1] as int);
        }).toList(),
      );
}

class FilwordLevel {
  FilwordLevel({
    required this.id,
    required this.worldId,
    required this.gridSize,
    required this.grid,
    required this.words,
  });
  final int id;
  final String worldId;
  final int gridSize;
  final List<String> grid;
  final List<WordTarget> words;

  factory FilwordLevel.fromJson(Map<String, dynamic> json) {
    // Stage 4 levels had no gridSize field and were all 10×10.
    final size = (json['gridSize'] as int?) ?? (json['grid'] as List).length;
    if (![7, 8, 9, 10].contains(size)) {
      throw FormatException('Unsupported gridSize: $size');
    }
    final grid = (json['grid'] as List).cast<String>();
    if (grid.length != size || grid.any((row) => row.length != size)) {
      throw const FormatException('Grid dimensions differ from gridSize');
    }
    return FilwordLevel(
      id: json['id'] as int,
      worldId: json['worldId'] as String,
      gridSize: size,
      grid: grid,
      words: (json['words'] as List)
          .map(
            (item) => WordTarget.fromJson(item as Map<String, dynamic>, size),
          )
          .toList(),
    );
  }

  String spell(List<int> path) =>
      path.map((cell) => grid[cell ~/ gridSize][cell % gridSize]).join();
}

class FoundPath {
  FoundPath(this.word, this.path);
  final String word;
  final List<int> path;
}

enum SelectionStatus { invalid, notTarget, alreadyFound, found }

class SelectionOutcome {
  SelectionOutcome(this.text, this.status, this.selectedPath);
  final String text;
  final SelectionStatus status;
  final List<int> selectedPath;
}

class GameSession {
  GameSession(this.level);
  final FilwordLevel level;
  final List<FoundPath> foundPaths = [];

  int get foundCount => foundPaths.length;
  bool get completed => foundCount == level.words.length;
  bool isFound(String text) => foundPaths.any((found) => found.word == text);

  bool isUnfoundTarget(String text) =>
      level.words.any((word) => word.text == text) && !isFound(text);

  bool hasLongerUnfoundTarget(String prefix) => level.words.any(
    (word) =>
        word.text.length > prefix.length &&
        word.text.startsWith(prefix) &&
        !isFound(word.text),
  );

  static bool adjacent(int first, int second, [int size = 10]) {
    final count = size * size;
    if (first < 0 ||
        first >= count ||
        second < 0 ||
        second >= count ||
        first == second) {
      return false;
    }
    final row = (first ~/ size - second ~/ size).abs();
    final col = (first % size - second % size).abs();
    return row + col == 1;
  }

  SelectionOutcome submit(List<int> path) {
    if (path.isEmpty ||
        path.any(
          (cell) => cell < 0 || cell >= level.gridSize * level.gridSize,
        ) ||
        path.toSet().length != path.length ||
        [
          for (var i = 1; i < path.length; i++)
            adjacent(path[i - 1], path[i], level.gridSize),
        ].contains(false)) {
      return SelectionOutcome('', SelectionStatus.invalid, List.of(path));
    }
    final text = level.spell(path);
    if (!level.words.any((word) => word.text == text)) {
      return SelectionOutcome(text, SelectionStatus.notTarget, List.of(path));
    }
    if (isFound(text)) {
      return SelectionOutcome(
        text,
        SelectionStatus.alreadyFound,
        List.of(path),
      );
    }
    foundPaths.add(FoundPath(text, List.of(path)));
    return SelectionOutcome(text, SelectionStatus.found, List.of(path));
  }
}
