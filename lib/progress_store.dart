import 'package:shared_preferences/shared_preferences.dart';

import 'game_session.dart';

class ProgressStore {
  ProgressStore._(this._prefs)
    : completedIds = (_prefs.getStringList('completedIds') ?? [])
          .map(int.tryParse)
          .whereType<int>()
          .toSet(),
      wordsFound = _prefs.getInt('wordsFound') ?? 0,
      totalSeconds = _prefs.getInt('totalSeconds') ?? 0,
      bestSeconds = _prefs.getInt('bestSeconds'),
      lightTheme = _prefs.getBool('lightTheme') ?? false;

  final SharedPreferences _prefs;
  final Set<int> completedIds;
  int wordsFound;
  int totalSeconds;
  int? bestSeconds;
  bool lightTheme;

  static Future<ProgressStore> load() async =>
      ProgressStore._(await SharedPreferences.getInstance());

  int currentIndex(List<FilwordLevel> levels) {
    final firstIncomplete = levels.indexWhere(
      (level) => !completedIds.contains(level.id),
    );
    return firstIncomplete < 0 ? levels.length - 1 : firstIncomplete;
  }

  int completedInWorld(List<FilwordLevel> levels) =>
      levels.where((level) => completedIds.contains(level.id)).length;

  Future<bool> recordCompletion(FilwordLevel level, int seconds) async {
    if (!completedIds.add(level.id)) return false;
    wordsFound += level.words.length;
    totalSeconds += seconds;
    if (bestSeconds == null || seconds < bestSeconds!) bestSeconds = seconds;
    await Future.wait([
      _prefs.setStringList(
        'completedIds',
        completedIds.map((id) => id.toString()).toList()..sort(),
      ),
      _prefs.setInt('wordsFound', wordsFound),
      _prefs.setInt('totalSeconds', totalSeconds),
      _prefs.setInt('bestSeconds', bestSeconds!),
    ]);
    return true;
  }

  Future<void> setLightTheme(bool value) async {
    lightTheme = value;
    await _prefs.setBool('lightTheme', value);
  }
}
