import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_pages.dart';
import 'game_screen.dart';
import 'game_session.dart';
import 'progress_store.dart';
import 'visual_home.dart';

void main() => runApp(const FilwordApp());

class FilwordApp extends StatefulWidget {
  const FilwordApp({super.key, this.testLevels, this.testProgress});
  final List<FilwordLevel>? testLevels;
  final ProgressStore? testProgress;

  @override
  State<FilwordApp> createState() => _FilwordAppState();
}

class _FilwordAppState extends State<FilwordApp> {
  List<FilwordLevel>? levels;
  ProgressStore? progress;

  @override
  void initState() {
    super.initState();
    if (widget.testLevels != null && widget.testProgress != null) {
      levels = widget.testLevels;
      progress = widget.testProgress;
    } else {
      load();
    }
  }

  Future<void> load() async {
    final raw = await rootBundle.loadString('assets/levels.json');
    final parsed = (jsonDecode(raw) as List)
        .map((value) => FilwordLevel.fromJson(value as Map<String, dynamic>))
        .toList();
    final saved = await ProgressStore.load();
    if (!mounted) return;
    setState(() {
      levels = parsed;
      progress = saved;
    });
  }

  void setTheme(bool light) {
    setState(() => progress!.lightTheme = light);
    unawaited(progress!.setLightTheme(light));
  }

  Widget gamePage(List<FilwordLevel> worldLevels, int index) => GameScreen(
    levels: worldLevels,
    initialIndex: index,
    onCompleted: (gameContext, level, seconds) async {
      final navigator = Navigator.of(gameContext);
      await progress!.recordCompletion(level, seconds);
      if (!mounted || !navigator.mounted) return;
      setState(() {});
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (victoryContext) => VictoryScreen(
            level: level,
            seconds: seconds,
            nextLevel: index + 1 < worldLevels.length
                ? worldLevels[index + 1]
                : null,
            onNext: index + 1 < worldLevels.length
                ? () => Navigator.of(victoryContext).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => gamePage(worldLevels, index + 1),
                    ),
                  )
                : null,
          ),
        ),
      );
    },
  );

  void openGame(
    BuildContext context,
    List<FilwordLevel> worldLevels,
    int index,
  ) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => gamePage(worldLevels, index)));
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ПоискСлов',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff487acc),
        brightness: Brightness.light,
      ),
    ),
    darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color(0xff101727),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff58d5e9),
        brightness: Brightness.dark,
      ),
    ),
    themeMode: progress?.lightTheme == true ? ThemeMode.light : ThemeMode.dark,
    home: levels == null || progress == null
        ? const SplashScreen()
        : DesignHomeScreen(
            levels: levels!,
            progress: progress!,
            onOpenGame: openGame,
            onThemeChanged: setTheme,
          ),
  );
}
