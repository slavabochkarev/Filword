import '../game_session.dart';

const worldChapters = <String, int>{
  'neon_city': 1,
  'cosmos': 2,
  'biosphere': 3,
  'cybercore': 4,
};

/// Only the player-facing numbering changes; saved and JSON IDs stay global.
String chapterLevelLabel(FilwordLevel level) {
  return chapterLevelLabelFor(level.worldId, level.id);
}

String compactChapterLevelLabel(FilwordLevel level) {
  final chapter = worldChapters[level.worldId];
  if (chapter == null) return 'Уровень ${level.id}';
  final number = level.id - (chapter - 1) * 100;
  return 'Глава $chapter/$number';
}

String chapterLevelLabelFor(String worldId, int id) {
  final chapter = worldChapters[worldId];
  if (chapter == null) return 'Уровень $id';
  final number = id - (chapter - 1) * 100;
  return 'Глава $chapter · уровень $number';
}
