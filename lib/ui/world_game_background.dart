import 'package:flutter/material.dart';

/// Stable world identifiers from level JSON, independent of labels and card order.
const worldBackgroundAssets = <String, String>{
  'neon_city': 'assets/images/city.png',
  'cosmos': 'assets/images/space.png',
  'biosphere': 'assets/images/nature.png',
  'cybercore': 'assets/images/science.png',
};

class WorldGameBackground extends StatelessWidget {
  const WorldGameBackground({
    super.key,
    required this.worldId,
    required this.child,
  });

  final String worldId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final asset = worldBackgroundAssets[worldId];
    final light = Theme.of(context).brightness == Brightness.light;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (asset != null)
          IgnorePointer(
            child: Image.asset(
              asset,
              key: const Key('game-world-background-image'),
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
        // Keep the scenery visible. Dense backing belongs to the board and
        // word list, where the letters need contrast.
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: light
                    ? const [Color(0x33e7f2ff), Color(0x77e7f2ff)]
                    : const [Color(0x44070e24), Color(0x99070e24)],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
