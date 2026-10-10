import 'package:flutter/material.dart';
import 'package:sly_fl_effects_lab/effects/sly_fl_effects.dart';

import '../game_session.dart';
import 'level_display.dart';
import 'neon_theme.dart';
import 'world_carousel.dart';

class VictoryScreen extends StatefulWidget {
  const VictoryScreen({
    super.key,
    required this.level,
    required this.seconds,
    this.nextLevel,
    this.onNext,
    this.effectsEnabled = true,
    this.crystalsEarned = 0,
    this.newAchievements = const [],
    this.worldFinished = false,
  });
  final FilwordLevel level;
  final int seconds;
  final FilwordLevel? nextLevel;
  final VoidCallback? onNext;
  final bool effectsEnabled;
  final int crystalsEarned;
  final List<String> newAchievements;
  final bool worldFinished;
  @override
  State<VictoryScreen> createState() => _VictoryScreenState();
}

class _VictoryScreenState extends State<VictoryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController timeline;
  late final CurvedAnimation reveal;
  final config = const ConfettiConfig(
    particleCount: 76,
    particleWidth: 7,
    particleHeight: 12,
    startDelay: Duration(milliseconds: 80),
    emissionDuration: Duration(milliseconds: 330),
    duration: Duration(milliseconds: 1500),
    flipEnabled: true,
    colors: [
      Color(0xff4ae7ff),
      Color(0xfff27aff),
      Color(0xffffd166),
      Color(0xff6df0ba),
    ],
  );
  @override
  void initState() {
    super.initState();
    timeline = AnimationController(vsync: this, duration: config.totalDuration);
    reveal = CurvedAnimation(
      parent: timeline,
      curve: const Interval(.22, .48, curve: Curves.easeOutCubic),
    );
    if (widget.effectsEnabled) {
      timeline.forward();
    } else {
      timeline.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) timeline.value = 1;
  }

  @override
  void dispose() {
    reveal.dispose();
    timeline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Уровень пройден')),
    body: ScenicBackground(
      child: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: FadeTransition(
                    opacity: reveal,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: .94, end: 1).animate(reveal),
                      child: NeonPanel(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(
                              Icons.emoji_events,
                              size: 68,
                              color: Color(0xffffd166),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Поздравляем!',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '${worldCards[widget.level.worldId]?.$1 ?? widget.level.worldId} · ${chapterLevelLabel(widget.level)}',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Найдено слов: ${widget.level.words.length}',
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              'Время: ${widget.seconds} с',
                              textAlign: TextAlign.center,
                            ),
                            if (widget.crystalsEarned > 0)
                              Text(
                                '+${widget.crystalsEarned} кристаллов',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xffffd166),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            if (widget.worldFinished) ...[
                              const SizedBox(height: 12),
                              const Text(
                                'Мир полностью пройден! Следующий круг начнётся с первого уровня.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                            if (widget.newAchievements.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Новые достижения: ${widget.newAchievements.join(', ')}',
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: 24),
                            if (widget.nextLevel == null) ...[
                              const Text(
                                'Новых уровней в этом мире пока нет.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                            ],
                            FilledButton(
                              onPressed: widget.onNext,
                              child: Text(
                                widget.worldFinished
                                    ? 'Новый круг'
                                    : 'Следующий уровень',
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: () =>
                                  Navigator.of(context)
                                      .popUntil((route) => route.isFirst),
                              child: const Text('На главную'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.effectsEnabled && !MediaQuery.disableAnimationsOf(context))
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: EffectLayer(
                    key: const Key('victory-effect'),
                    config: config,
                    animation: timeline,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
