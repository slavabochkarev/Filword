import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_pages.dart';
import '../game_session.dart';
import '../progress_store.dart';
import 'info_content.dart';
import 'info_screen.dart';
import 'neon_theme.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({
    super.key,
    required this.levels,
    required this.progress,
    required this.onThemeChanged,
  });
  final List<FilwordLevel> levels;
  final ProgressStore progress;
  final ValueChanged<bool> onThemeChanged;
  void open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  Widget row(BuildContext context, IconData icon, String title, Widget page) =>
      ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => open(context, page),
      );
  Widget externalRow(
    BuildContext context,
    IconData icon,
    String title,
    String url,
  ) => ListTile(
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    trailing: const Icon(Icons.chevron_right),
    onTap: () async {
      try {
        if (await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        )) {
          return;
        }
      } catch (_) {
        // Show the same fallback when no browser is available.
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть страницу')),
        );
      }
    },
  );
  Widget section(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: 2,
        fontSize: 13,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('МЕНЮ'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'ИГРА'),
            Tab(text: 'ИНФО'),
          ],
        ),
      ),
      body: ScenicBackground(
        child: TabBarView(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    section('ОФОРМЛЕНИЕ И УПРАВЛЕНИЕ'),
                    NeonPanel(
                      child: Column(
                        children: [
                          row(
                            context,
                            Icons.settings_outlined,
                            'Настройки',
                            SettingsScreen(
                              progress: progress,
                              onThemeChanged: onThemeChanged,
                            ),
                          ),
                          const Divider(height: 1),
                          row(
                            context,
                            Icons.palette_outlined,
                            'Тема',
                            ThemePage(
                              light: progress.lightTheme,
                              onChanged: onThemeChanged,
                            ),
                          ),
                        ],
                      ),
                    ),
                    section('ПРОГРЕСС'),
                    NeonPanel(
                      child: Column(
                        children: [
                          row(
                            context,
                            Icons.bar_chart,
                            'Статистика',
                            StatsPage(progress: progress, levels: levels),
                          ),
                          const Divider(height: 1),
                          row(
                            context,
                            Icons.emoji_events_outlined,
                            'Достижения',
                            AchievementsPage(
                              progress: progress,
                              levels: levels,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'ПОИСКСЛОВ · версия 1.0.0',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    section('ОБ ИГРЕ'),
                    NeonPanel(
                      child: Column(
                        children: [
                          row(
                            context,
                            Icons.info_outline,
                            'Об игре',
                            const TextPage(
                              'Об игре',
                              'ПоискСлов — поиск слов в четырёх мирах. В этой версии доступны 20 тестовых уровней: по пять каждого размера. Прогресс сохраняется на этом устройстве.',
                            ),
                          ),
                          row(
                            context,
                            Icons.help_outline,
                            'Как играть',
                            const TextPage(
                              'Как играть',
                              'Проводите по соседним буквам или нажимайте на них по очереди. Диагонали и повороты разрешены. Возврат на предпоследнюю клетку отменяет шаг. Повторное нажатие на последнюю клетку ничего не меняет. Целевое слово засчитывается автоматически. Подсвечивается выбранный вами путь; его клетки можно использовать в других словах. Найдите все слова из списка.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    section('ДОКУМЕНТЫ И СВЯЗЬ'),
                    NeonPanel(
                      child: Column(
                        children: [
                          externalRow(
                            context,
                            Icons.privacy_tip_outlined,
                            'Политика конфиденциальности',
                            privacyPolicyUrl,
                          ),
                          externalRow(
                            context,
                            Icons.description_outlined,
                            'Пользовательское соглашение',
                            userAgreementUrl,
                          ),
                          row(
                            context,
                            Icons.mail_outline,
                            'Обратная связь',
                            const InfoScreen(document: feedbackDocument),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.progress,
    required this.onThemeChanged,
  });
  final ProgressStore progress;
  final ValueChanged<bool> onThemeChanged;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Настройки')),
    body: ScenicBackground(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 8, 4, 12),
                child: Text(
                  'ТЕМА',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ),
              NeonPanel(
                child: Column(
                  children: [
                    for (final light in [false, true])
                      ListTile(
                        leading: Icon(
                          light
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                        ),
                        title: Text(light ? 'Светлая' : 'Тёмная'),
                        trailing: Icon(
                          widget.progress.lightTheme == light
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                        ),
                        onTap: () {
                          widget.onThemeChanged(light);
                          setState(() {});
                        },
                      ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 24, 4, 12),
                child: Text(
                  'ЭФФЕКТЫ',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ),
              NeonPanel(
                child: SwitchListTile(
                  title: const Text('Эффект победы'),
                  subtitle: const Text(
                    'Неоновое конфетти после завершения уровня',
                  ),
                  value: widget.progress.effectsEnabled,
                  onChanged: (value) {
                    setState(() => widget.progress.effectsEnabled = value);
                    widget.progress.setEffectsEnabled(value);
                  },
                ),
              ),
              const SizedBox(height: 18),
              const NeonPanel(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Проведение и нажатия доступны одновременно. Прокручивается только список слов; игровое поле закреплено.',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class TextPage extends StatelessWidget {
  const TextPage(this.title, this.text, {super.key});
  final String title, text;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ScenicBackground(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          NeonPanel(
            padding: const EdgeInsets.all(22),
            child: Text(
              text,
              style: const TextStyle(fontSize: 17, height: 1.6),
            ),
          ),
        ],
      ),
    ),
  );
}
