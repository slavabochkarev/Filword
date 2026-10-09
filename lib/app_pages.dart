import 'package:flutter/material.dart';

import 'game_session.dart';
import 'progress_store.dart';

const worldNames = {
  'neon_city': 'Город',
  'cosmos': 'Космос',
  'biosphere': 'Природа',
  'cybercore': 'Наука',
};

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.levels,
    required this.progress,
    required this.onOpenGame,
    required this.onThemeChanged,
  });

  final List<FilwordLevel> levels;
  final ProgressStore progress;
  final void Function(BuildContext, List<FilwordLevel>, int) onOpenGame;
  final ValueChanged<bool> onThemeChanged;

  void openPage(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Филворд'), centerTitle: true),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Игра', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          const Text('Выберите мир и размер поля'),
          const SizedBox(height: 12),
          for (final entry in worldNames.entries)
            Builder(
              builder: (context) {
                final worldLevels =
                    levels.where((level) => level.worldId == entry.key).toList()
                      ..sort((a, b) => a.id.compareTo(b.id));
                final index = progress.currentIndex(worldLevels);
                final completed = progress.completedInWorld(worldLevels);
                return Card(
                  child: ListTile(
                    key: Key('world-${entry.key}'),
                    leading: CircleAvatar(
                      child: Text('${worldLevels.first.gridSize}'),
                    ),
                    title: Text(
                      '${entry.value} · ${worldLevels.first.gridSize}×${worldLevels.first.gridSize}',
                    ),
                    subtitle: Text(
                      completed == worldLevels.length
                          ? 'Все ${worldLevels.length} тестовых уровней пройдены · повторить'
                          : 'Уровень ${index + 1} из ${worldLevels.length} · пройдено $completed',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onOpenGame(context, worldLevels, index),
                  ),
                );
              },
            ),
          const SizedBox(height: 18),
          Text('Меню', style: Theme.of(context).textTheme.titleLarge),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Тема'),
            onTap: () => openPage(
              context,
              ThemePage(light: progress.lightTheme, onChanged: onThemeChanged),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart_outlined),
            title: const Text('Статистика'),
            onTap: () => openPage(
              context,
              StatsPage(progress: progress, levels: levels),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.emoji_events_outlined),
            title: const Text('Достижения'),
            onTap: () => openPage(
              context,
              AchievementsPage(progress: progress, levels: levels),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Инфо'),
            onTap: () => openPage(context, const InfoPage()),
          ),
        ],
      ),
    ),
  );
}

class ThemePage extends StatefulWidget {
  const ThemePage({super.key, required this.light, required this.onChanged});
  final bool light;
  final ValueChanged<bool> onChanged;
  @override
  State<ThemePage> createState() => _ThemePageState();
}

class _ThemePageState extends State<ThemePage> {
  late bool light = widget.light;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Тема')),
    body: ListView(
      children: [
        ListTile(
          title: const Text('Тёмная'),
          trailing: !light ? const Icon(Icons.check) : null,
          onTap: () {
            setState(() => light = false);
            widget.onChanged(false);
          },
        ),
        ListTile(
          title: const Text('Светлая'),
          trailing: light ? const Icon(Icons.check) : null,
          onTap: () {
            setState(() => light = true);
            widget.onChanged(true);
          },
        ),
      ],
    ),
  );
}

class StatsPage extends StatelessWidget {
  const StatsPage({super.key, required this.progress, required this.levels});
  final ProgressStore progress;
  final List<FilwordLevel> levels;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Статистика')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          title: const Text('Пройдено уровней'),
          trailing: Text('${progress.completedIds.length}'),
        ),
        ListTile(
          title: const Text('Слов в пройденных уровнях'),
          trailing: Text('${progress.wordsFound}'),
        ),
        ListTile(
          title: const Text('Время завершённых уровней'),
          trailing: Text('${progress.totalSeconds} с'),
        ),
        ListTile(
          title: const Text('Лучшее время'),
          trailing: Text(
            progress.bestSeconds == null ? '—' : '${progress.bestSeconds} с',
          ),
        ),
        const Divider(),
        for (final entry in worldNames.entries)
          ListTile(
            title: Text(entry.value),
            trailing: Text(
              '${progress.completedInWorld(levels.where((level) => level.worldId == entry.key).toList())}/5',
            ),
          ),
      ],
    ),
  );
}

class AchievementsPage extends StatelessWidget {
  const AchievementsPage({
    super.key,
    required this.progress,
    required this.levels,
  });
  final ProgressStore progress;
  final List<FilwordLevel> levels;
  @override
  Widget build(BuildContext context) {
    final completed = progress.completedIds.length;
    final onePerWorld = worldNames.keys.every(
      (world) => levels.any(
        (level) =>
            level.worldId == world && progress.completedIds.contains(level.id),
      ),
    );
    final achievements = <(String, String, bool)>[
      ('Первый шаг', 'Пройти один уровень', completed >= 1),
      ('Пять побед', 'Пройти пять уровней', completed >= 5),
      ('Все миры', 'Пройти хотя бы один уровень в каждом мире', onePerWorld),
      (
        'Исследователь',
        'Пройти все 20 тестовых уровней',
        completed >= levels.length,
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Достижения')),
      body: ListView(
        children: [
          for (final item in achievements)
            ListTile(
              leading: Icon(item.$3 ? Icons.emoji_events : Icons.lock_outline),
              title: Text(item.$1),
              subtitle: Text(item.$2),
              trailing: Text(item.$3 ? 'Получено' : 'Не получено'),
            ),
        ],
      ),
    );
  }
}

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Инфо')),
    body: ListView(
      padding: EdgeInsets.all(20),
      children: [
        Text(
          'Филворд',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        Text(
          'Экспериментальный прототип. В каждом мире пять тестовых уровней.',
        ),
        SizedBox(height: 12),
        Text(
          'Проводите пальцем или мышью по соседним буквам либо нажимайте на них по очереди. Диагонали и повороты разрешены. Возврат на предыдущую клетку отменяет последний шаг. Слово засчитывается автоматически.',
        ),
        SizedBox(height: 12),
        Text('Прогресс хранится только на этом устройстве.'),
      ],
    ),
  );
}

class VictoryScreen extends StatelessWidget {
  const VictoryScreen({
    super.key,
    required this.level,
    required this.seconds,
    this.nextLevel,
    this.onNext,
  });
  final FilwordLevel level;
  final int seconds;
  final FilwordLevel? nextLevel;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Уровень пройден')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.emoji_events,
                  size: 64,
                  color: Color(0xffffd166),
                ),
                const SizedBox(height: 16),
                Text(
                  'Поздравляем!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  '${worldNames[level.worldId]} · уровень ${level.id}',
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Найдено слов: ${level.words.length}',
                  textAlign: TextAlign.center,
                ),
                Text('Время: $seconds с', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                if (nextLevel == null) ...[
                  const Text(
                    'Новых тестовых уровней в этом мире пока нет.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: onNext,
                  child: const Text('Следующий уровень'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text('На главную'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
