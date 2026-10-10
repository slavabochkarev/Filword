import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game_session.dart';
import '../progress_store.dart';

const worldCards = <String, (String, String, Color, int)>{
  'neon_city': ('Город', 'city', Color(0xffffa35d), 7),
  'cosmos': ('Космос', 'space', Color(0xffdc84ff), 8),
  'biosphere': ('Природа', 'nature', Color(0xff60efb1), 9),
  'cybercore': ('Наука', 'science', Color(0xff60d8ff), 10),
};

class WorldCarousel extends StatefulWidget {
  const WorldCarousel({
    super.key,
    required this.levels,
    required this.progress,
    required this.onOpenGame,
    required this.onWorldChanged,
  });
  final List<FilwordLevel> levels;
  final ProgressStore progress;
  final void Function(BuildContext, List<FilwordLevel>, int) onOpenGame;
  final ValueChanged<int> onWorldChanged;
  @override
  State<WorldCarousel> createState() => _WorldCarouselState();
}

class _WorldCarouselState extends State<WorldCarousel> {
  final controller = PageController(viewportFraction: .76);
  int active = 0;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void move(int delta) => controller.animateToPage(
    (active + delta).clamp(0, 3),
    duration: const Duration(milliseconds: 320),
    curve: Curves.easeOutCubic,
  );
  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    onKeyEvent: (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (event.logicalKey == LogicalKeyboardKey.arrowRight && active < 3) {
        move(1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft && active > 0) {
        move(-1);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: Stack(
      children: [
        Positioned.fill(
          child: ScrollConfiguration(
            behavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.stylus,
                PointerDeviceKind.trackpad,
              },
            ),
            child: PageView.builder(
              key: const Key('world-carousel'),
              controller: controller,
              itemCount: worldCards.length,
              onPageChanged: (value) {
                setState(() => active = value);
                widget.onWorldChanged(value);
              },
              itemBuilder: (context, index) => AnimatedBuilder(
                animation: controller,
                builder: (context, child) {
                  final page =
                      controller.hasClients &&
                          controller.position.hasContentDimensions
                      ? controller.page ?? 0
                      : 0.0;
                  final distance = (page - index).abs().clamp(0.0, 1.0);
                  return Transform.scale(
                    scale: 1 - .13 * distance,
                    child: Opacity(opacity: 1 - .3 * distance, child: child),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                  child: card(context, index),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Center(
            child: IconButton(
              key: const Key('previous-world'),
              tooltip: 'Предыдущий мир',
              onPressed: active > 0 ? () => move(-1) : null,
              icon: const Icon(Icons.chevron_left),
              color: Colors.white,
              disabledColor: Colors.white24,
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: Center(
            child: IconButton(
              key: const Key('next-world'),
              tooltip: 'Следующий мир',
              onPressed: active < 3 ? () => move(1) : null,
              icon: const Icon(Icons.chevron_right),
              color: Colors.white,
              disabledColor: Colors.white24,
            ),
          ),
        ),
      ],
    ),
  );

  Widget card(BuildContext context, int position) {
    final world = worldCards.keys.elementAt(position);
    final data = worldCards[world]!;
    final group =
        widget.levels.where((level) => level.worldId == world).toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    final available = group.isNotEmpty;
    final completed = widget.progress.completedInWorld(group);
    final index = available ? widget.progress.currentIndex(group) : 0;
    return Semantics(
      button: true,
      label:
          '${data.$1}, ${data.$4} на ${data.$4}, пройдено $completed из ${group.length}',
      child: WorldCard(
        color: data.$3,
        selected: active == position,
        child: Material(
          color: const Color(0xff0b152b),
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: Key('world-$world'),
            onTap: () {
              if (position != active) {
                controller.animateToPage(
                  position,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                );
                return;
              }
              if (available) {
                widget.onOpenGame(context, group, index);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Тестовые уровни этого мира пока не готовы'),
                  ),
                );
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset('assets/images/${data.$2}.png', fit: BoxFit.cover),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00050b20),
                        Color(0x66050b20),
                        Color(0xff071126),
                      ],
                      stops: [0, .48, .79],
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xdd0b152b),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: data.$3.withValues(alpha: .6)),
                    ),
                    child: Text(
                      '${data.$4}×${data.$4}',
                      style: TextStyle(
                        color: data.$3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                if (!available)
                  const Center(
                    child: Icon(
                      Icons.lock_outline,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        data.$1.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                              color: data.$3.withValues(alpha: .5),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: available ? completed / group.length : 0,
                        minHeight: 3,
                        color: data.$3,
                        backgroundColor: Colors.white12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        available
                            ? 'Пройдено $completed/${group.length}'
                            : 'Уровни скоро появятся',
                        style: const TextStyle(
                          color: Color(0xffc7d9ed),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: data.$3.withValues(
                          alpha: active == position ? 1 : .5,
                        ),
                        width: active == position ? 2 : 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WorldCard extends StatelessWidget {
  const WorldCard({
    super.key,
    required this.color,
    required this.selected,
    required this.child,
  });
  final Color color;
  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: selected ? .42 : .12),
          blurRadius: 18,
          spreadRadius: 1,
        ),
      ],
    ),
    child: child,
  );
}
