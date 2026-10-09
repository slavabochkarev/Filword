import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_pages.dart';
import 'game_session.dart';
import 'progress_store.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Color(0xff090d25),
    body: SizedBox.expand(
      child: Image(
        image: AssetImage('assets/images/splash.png'),
        fit: BoxFit.cover,
        alignment: Alignment.center,
      ),
    ),
  );
}

class DesignHomeScreen extends StatelessWidget {
  const DesignHomeScreen({
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

  static const cards = <String, (String, String, Color, int)>{
    'neon_city': ('Город', 'assets/images/city.png', Color(0xffff9b45), 7),
    'cosmos': ('Космос', 'assets/images/space.png', Color(0xffdc84ff), 8),
    'biosphere': ('Природа', 'assets/images/nature.png', Color(0xff60efb1), 9),
    'cybercore': ('Наука', 'assets/images/science.png', Color(0xff60d8ff), 10),
  };

  void openPage(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  Widget menuItem(
    BuildContext context,
    IconData icon,
    String title,
    Widget page,
  ) => ListTile(
    leading: Icon(icon, color: const Color(0xff66d9ff)),
    title: Text(title, style: const TextStyle(color: Colors.white)),
    onTap: () {
      Navigator.of(context).pop();
      openPage(context, page);
    },
  );

  Widget worldCard(BuildContext context, String world) {
    final group = levels.where((level) => level.worldId == world).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final card = cards[world]!;
    final available = group.isNotEmpty;
    final completed = progress.completedInWorld(group);
    final index = available ? progress.currentIndex(group) : 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('world-$world'),
        borderRadius: BorderRadius.circular(17),
        onTap: () {
          if (available) {
            onOpenGame(context, group, index);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Тестовые уровни этого мира пока не готовы'),
              ),
            );
          }
        },
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: card.$3, width: 2),
            boxShadow: [
              BoxShadow(color: card.$3.withValues(alpha: .38), blurRadius: 14),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(card.$2, fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0x5505091e),
                      Color(0xee05091e),
                    ],
                    stops: [0, .5, 1],
                  ),
                ),
              ),
              if (!available)
                const Center(
                  child: Icon(Icons.lock, color: Colors.white, size: 36),
                ),
              Positioned(
                left: 9,
                right: 7,
                bottom: 8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.$1.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: card.$3,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 5),
                        ],
                      ),
                    ),
                    Text(
                      available
                          ? '${card.$4}×${card.$4} · ур. ${group[index].id}'
                          : '${card.$4}×${card.$4} · нет уровней',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Text(
                      'Пройдено $completed/${group.length}',
                      style: const TextStyle(
                        color: Color(0xffdceaff),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      backgroundColor: light
          ? const Color(0xffdceefa)
          : const Color(0xff080d25),
      drawer: Drawer(
        backgroundColor: const Color(0xff101a35),
        child: SafeArea(
          child: ListView(
            children: [
              const SizedBox(
                height: 96,
                child: DrawerHeader(
                  margin: EdgeInsets.zero,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xff14416d), Color(0xff31174a)],
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ПОИСКСЛОВ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const _MenuHeading('ИГРА'),
              menuItem(
                context,
                Icons.settings_outlined,
                'Настройки',
                const _TextPage(
                  'Настройки',
                  'Тему оформления можно выбрать в разделе «Тема». Остальные настройки появятся позже.',
                ),
              ),
              menuItem(
                context,
                Icons.palette_outlined,
                'Тема',
                ThemePage(
                  light: progress.lightTheme,
                  onChanged: onThemeChanged,
                ),
              ),
              menuItem(
                context,
                Icons.bar_chart_outlined,
                'Статистика',
                StatsPage(progress: progress, levels: levels),
              ),
              menuItem(
                context,
                Icons.emoji_events_outlined,
                'Достижения',
                AchievementsPage(progress: progress, levels: levels),
              ),
              const Divider(color: Color(0xff36506d)),
              const _MenuHeading('ИНФО'),
              menuItem(
                context,
                Icons.info_outline,
                'Об игре',
                const _TextPage(
                  'Об игре',
                  'ПоискСлов — игра с поиском слов в четырёх мирах. Пока доступны по пять тестовых уровней на мир.',
                ),
              ),
              menuItem(
                context,
                Icons.help_outline,
                'Как играть',
                const _TextPage(
                  'Как играть',
                  'Соединяйте соседние буквы пальцем, мышью или последовательными нажатиями. Диагонали и повороты разрешены. Возврат к предыдущей клетке отменяет последний шаг. Найдите все слова из списка.',
                ),
              ),
              menuItem(
                context,
                Icons.privacy_tip_outlined,
                'Политика конфиденциальности',
                const _TextPage(
                  'Политика конфиденциальности',
                  'Документ будет добавлен перед публикацией. Сейчас прогресс хранится локально на устройстве.',
                ),
              ),
              menuItem(
                context,
                Icons.description_outlined,
                'Пользовательское соглашение',
                const _TextPage(
                  'Пользовательское соглашение',
                  'Документ будет добавлен перед публикацией.',
                ),
              ),
              menuItem(
                context,
                Icons.mail_outline,
                'Обратная связь',
                const _TextPage(
                  'Обратная связь',
                  'Способ связи будет указан перед публикацией.',
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, bounds) {
            final heroHeight = math.min(
              320.0,
              math.max(220.0, bounds.maxHeight * .39),
            );
            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 48,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Builder(
                            builder: (menuContext) => IconButton.filledTonal(
                              key: const Key('open-menu'),
                              tooltip: 'Меню',
                              icon: const Icon(Icons.menu, size: 28),
                              onPressed: () =>
                                  Scaffold.of(menuContext).openDrawer(),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: heroHeight,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const Image(
                              image: AssetImage('assets/images/home_hero.png'),
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                            ),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.transparent,
                                    Color(0xff080d25),
                                  ],
                                  stops: [0, .72, 1],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(10, 2, 10, 14),
                        child: Text(
                          'ВЫБЕРИ МИР',
                          style: TextStyle(
                            color: Color(0xffe1f5ff),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                            shadows: [
                              Shadow(color: Color(0xff3bcaff), blurRadius: 14),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          childAspectRatio: 1.03,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          children: [
                            for (final world in cards.keys)
                              worldCard(context, world),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MenuHeading extends StatelessWidget {
  const _MenuHeading(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      title,
      style: const TextStyle(
        color: Color(0xffec89ff),
        fontWeight: FontWeight.w800,
        letterSpacing: 2,
      ),
    ),
  );
}

class _TextPage extends StatelessWidget {
  const _TextPage(this.title, this.body);
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(body, style: Theme.of(context).textTheme.bodyLarge),
      ),
    ),
  );
}
