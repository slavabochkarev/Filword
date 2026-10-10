import 'package:flutter/material.dart';

ThemeData neonTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xff48dfff),
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: light
        ? const Color(0xffedf5fc)
        : const Color(0xff080e24),
    appBarTheme: AppBarTheme(
      centerTitle: true,
      backgroundColor: light
          ? const Color(0xffe4f1fa)
          : const Color(0xff101a35),
      foregroundColor: light
          ? const Color(0xff142c4d)
          : const Color(0xffe9faff),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: light
            ? const Color(0xff184367)
            : const Color(0xff8deaff),
        side: BorderSide(
          color: light ? const Color(0xff6692b4) : const Color(0xff386780),
        ),
        minimumSize: const Size(48, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xff43d6ee),
        foregroundColor: const Color(0xff08172b),
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}

/// Shared scenic shell; all controls remain real Flutter widgets.
class ScenicBackground extends StatelessWidget {
  const ScenicBackground({super.key, required this.child, this.home = false});
  final Widget child;
  final bool home;
  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/home_background.png',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: home
                  ? [
                      const Color(0x33040b20),
                      const Color(0x00040b20),
                      const Color(0xe6080e24),
                    ]
                  : light
                  ? [const Color(0xe6edf5fc), const Color(0xe6dceafa)]
                  : [const Color(0xda080e24), const Color(0xe8101933)],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class NeonPanel extends StatelessWidget {
  const NeonPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(6),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: light ? const Color(0xff87b7cf) : const Color(0xff38667f),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: light
              ? [const Color(0xf5ffffff), const Color(0xf5e2edf8)]
              : [const Color(0xf51a304b), const Color(0xf5101b35)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x183bdcff), blurRadius: 16)],
      ),
      child: child,
    );
  }
}

class GameLogo extends StatelessWidget {
  const GameLogo({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'ПоискСлов',
    header: true,
    child: ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xff49eaff), Color(0xffe9faff), Color(0xfff078ff)],
            ).createShader(bounds),
            child: const FittedBox(
              child: Text(
                'ПОИСКСЛОВ',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 48,
                  letterSpacing: 1,
                  shadows: [
                    Shadow(color: Color(0xff32d7ff), blurRadius: 22),
                    Shadow(
                      color: Color(0xffbd42e7),
                      offset: Offset(2, 3),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'С Л О В А   В О К Р У Г   Н А С',
            style: TextStyle(
              color: Color(0xffc1efff),
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    ),
  );
}
