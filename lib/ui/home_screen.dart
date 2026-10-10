import 'package:flutter/material.dart';

import '../game_session.dart';
import '../progress_store.dart';
import 'menu_screen.dart';
import 'world_carousel.dart';

class HomeScreen extends StatefulWidget {
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
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class DesignHomeScreen extends HomeScreen {
  const DesignHomeScreen({
    super.key,
    required super.levels,
    required super.progress,
    required super.onOpenGame,
    required super.onThemeChanged,
  });
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedWorld = 0;

  void play() {
    final world = worldCards.keys.elementAt(selectedWorld);
    final group =
        widget.levels.where((level) => level.worldId == world).toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    if (group.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Тестовые уровни этого мира пока не готовы'),
        ),
      );
      return;
    }
    widget.onOpenGame(context, group, widget.progress.currentIndex(group));
  }

  @override
  Widget build(BuildContext context) {
    final accent = worldCards.values.elementAt(selectedWorld).$3;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/home_background_main2.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x22040820),
                  Color(0x00040820),
                  Color(0xb9080e24),
                ],
                stops: [0, .38, 1],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final compact = box.maxHeight < 770;
                    final logoWidth = (box.maxWidth - 64).clamp(260.0, 390.0);
                    final cardHeight = (box.maxHeight * .255).clamp(
                      188.0,
                      225.0,
                    );
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              MenuButton(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => MenuScreen(
                                      levels: widget.levels,
                                      progress: widget.progress,
                                      onThemeChanged: widget.onThemeChanged,
                                    ),
                                  ),
                                ),
                              ),
                              ListenableBuilder(
                                listenable: widget.progress,
                                builder: (context, _) => Semantics(
                                  label:
                                      'Кристаллы: ${widget.progress.crystalBalance}',
                                  child: Container(
                                    key: const Key('home-crystals'),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 9,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xcc0b1b38),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0xffffd166),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.diamond_outlined,
                                          color: Color(0xffffd166),
                                          size: 22,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${widget.progress.crystalBalance}',
                                          style: const TextStyle(
                                            color: Color(0xffffe3a1),
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: compact ? 2 : 10),
                        GameLogo(width: logoWidth),
                        const Spacer(),
                        const Text(
                          'ВЫБЕРИ МИР',
                          style: TextStyle(
                            color: Color(0xffe7f8ff),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                            shadows: [
                              Shadow(color: Color(0xff3bcaff), blurRadius: 16),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: cardHeight,
                          child: WorldCarousel(
                            levels: widget.levels,
                            progress: widget.progress,
                            onOpenGame: widget.onOpenGame,
                            onWorldChanged: (index) =>
                                setState(() => selectedWorld = index),
                          ),
                        ),
                        SizedBox(height: compact ? 7 : 13),
                        PlayButton(color: accent, onPressed: play),
                        SizedBox(height: compact ? 12 : 18),
                        WorldIndicator(active: selectedWorld),
                        SizedBox(height: compact ? 12 : 20),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GameLogo extends StatelessWidget {
  const GameLogo({super.key, required this.width});
  final double width;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'ПоискСлов. Слова ждут тебя',
    header: true,
    child: Image.asset(
      'assets/images/home_logo_stage10.png',
      key: const Key('home-logo'),
      width: width,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    ),
  );
}

class MenuButton extends StatelessWidget {
  const MenuButton({super.key, required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Container(
    width: 54,
    height: 54,
    decoration: BoxDecoration(
      color: const Color(0xcc0b1b38),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xff4edfff), width: 2),
      boxShadow: const [BoxShadow(color: Color(0x8833cfff), blurRadius: 14)],
    ),
    child: IconButton(
      key: const Key('open-menu'),
      tooltip: 'Меню',
      onPressed: onPressed,
      icon: SizedBox(
        width: 25,
        height: 20,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                key: Key('hamburger-line-$i'),
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xffd5f8ff),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class PlayButton extends StatelessWidget {
  const PlayButton({super.key, required this.color, required this.onPressed});
  final Color color;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 44),
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: .72),
            color,
            color.withValues(alpha: .68),
          ],
        ),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: .72), blurRadius: 20),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: Color.lerp(const Color(0xff0a1030), color, .36),
          borderRadius: BorderRadius.circular(30),
          child: InkWell(
            key: const Key('play-world'),
            onTap: onPressed,
            borderRadius: BorderRadius.circular(30),
            child: SizedBox(
              height: 55,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'ИГРАТЬ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Icon(Icons.arrow_forward_ios_rounded, color: color, size: 23),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class WorldIndicator extends StatelessWidget {
  const WorldIndicator({super.key, required this.active});
  final int active;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < worldCards.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          child: AnimatedContainer(
            key: Key('world-dot-$i'),
            duration: const Duration(milliseconds: 240),
            width: active == i ? 13 : 10,
            height: active == i ? 13 : 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active == i
                  ? worldCards.values.elementAt(i).$3
                  : const Color(0xff439bd3),
              boxShadow: active == i
                  ? [
                      BoxShadow(
                        color: worldCards.values.elementAt(i).$3,
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
    ],
  );
}
