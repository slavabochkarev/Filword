import 'package:flutter/material.dart';

import 'neon_theme.dart';
import '../game_session.dart';
import '../progress_store.dart';

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
    final categories = achievementDefinitions
        .map((item) => item.category)
        .toSet();
    return Scaffold(
      appBar: AppBar(title: const Text('Достижения')),
      body: ScenicBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final category in categories) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 10),
                child: Text(
                  category.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              for (final achievement in achievementDefinitions.where(
                (item) => item.category == category,
              )) ...[
                _achievementCard(context, achievement),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _achievementCard(BuildContext context, AchievementDefinition item) {
    final current = item.value(progress);
    final earned = progress.unlockedAt.containsKey(item.id);
    final date = progress.unlockedAt[item.id];
    final accent = Theme.of(context).colorScheme.primary;
    return Opacity(
      opacity: earned ? 1 : .66,
      child: NeonPanel(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              earned ? Icons.emoji_events : Icons.lock_outline,
              color: earned ? const Color(0xffffd166) : accent,
              size: 32,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(item.description),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: (current / item.target).clamp(0.0, 1.0),
                    color: earned ? const Color(0xffffd166) : accent,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    earned
                        ? (date == null
                              ? 'Получено ранее · дата неизвестна'
                              : 'Получено ${date.substring(0, 10)}')
                        : '${current.clamp(0, item.target)}/${item.target}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
