import 'package:flutter/material.dart';

import 'neon_theme.dart';
import '../game_session.dart';
import '../progress_store.dart';
import 'world_names.dart';

String formatGameTime(int? seconds) {
  if (seconds == null) return '—';
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final rest = seconds % 60;
  if (hours > 0) return '$hours ч $minutes мин';
  if (minutes > 0) return '$minutes мин $rest с';
  return '$rest с';
}

class StatsPage extends StatelessWidget {
  const StatsPage({super.key, required this.progress, required this.levels});
  final ProgressStore progress;
  final List<FilwordLevel> levels;

  Widget item(String title, String value) => ListTile(
    title: Text(title),
    trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Статистика')),
    body: ScenicBackground(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          NeonPanel(
            child: Column(
              children: [
                const Text(
                  'ВСЯ ИГРА',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                item('Активное время', formatGameTime(progress.activeSeconds)),
                item('Найдено слов', '${progress.wordsFound}'),
                item('Завершено уровней', '${progress.totalCompletedLevels}'),
                item('Полностью пройдено миров', '${progress.completedWorlds}'),
                item('Завершено кругов', '${progress.completedRounds}'),
                item('Кристаллы заработаны', '${progress.crystalsEarned}'),
                item('Кристаллы потрачены', '${progress.crystalsSpent}'),
                item('Баланс', '${progress.crystalBalance}'),
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Активное время учитывается с этой версии. Время старых прохождений по мирам неизвестно.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final entry in worldNames.entries) ...[
            NeonPanel(
              child: Column(
                children: [
                  Text(
                    entry.value,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  item(
                    'Текущий круг',
                    '${progress.world(entry.key).completedRuns + 1}',
                  ),
                  item(
                    'Текущий уровень',
                    '${progress.world(entry.key).currentIndex + 1}/${levels.where((level) => level.worldId == entry.key).length}',
                  ),
                  item(
                    'Активное время всего',
                    formatGameTime(progress.world(entry.key).activeSeconds),
                  ),
                  item(
                    'Время текущего круга',
                    formatGameTime(progress.world(entry.key).currentRunSeconds),
                  ),
                  item(
                    'Последний полный круг',
                    formatGameTime(progress.world(entry.key).lastRunSeconds),
                  ),
                  item(
                    'Лучший полный круг',
                    formatGameTime(progress.world(entry.key).bestRunSeconds),
                  ),
                  item(
                    'Полных кругов',
                    '${progress.world(entry.key).completedRuns}',
                  ),
                  item(
                    'Завершено уровней',
                    '${progress.world(entry.key).completedLevels}',
                  ),
                  item(
                    'Найдено слов',
                    '${progress.world(entry.key).wordsFound}',
                  ),
                  item(
                    'Использовано подсказок',
                    '${progress.world(entry.key).hintsUsed}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    ),
  );
}
