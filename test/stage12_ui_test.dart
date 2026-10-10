import 'dart:convert';
import 'dart:io';

import 'package:filword/app.dart';
import 'package:filword/game_screen.dart';
import 'package:filword/game_session.dart';
import 'package:filword/progress_store.dart';
import 'package:filword/ui/achievements_page.dart';
import 'package:filword/ui/neon_theme.dart';
import 'package:filword/ui/stats_page.dart';
import 'package:filword/ui/victory_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    final font = File('C:/Windows/Fonts/arial.ttf').readAsBytesSync();
    await (FontLoader(
      'Roboto',
    )..addFont(Future.value(ByteData.view(font.buffer)))).load();
    final icons = File(
      'C:/Tools/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ).readAsBytesSync();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.view(icons.buffer)))).load();
  });
  final levels =
      (jsonDecode(File('assets/levels.json').readAsStringSync()) as List)
          .map((item) => FilwordLevel.fromJson(item as Map<String, dynamic>))
          .toList();
  final city = levels.where((item) => item.worldId == 'neon_city').toList();

  void setScreen(WidgetTester tester, double width) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('home and game place crystals in their headers', (tester) async {
    SharedPreferences.setMockInitialValues({});
    setScreen(tester, 360);
    final store = (await tester.runAsync(
      () => ProgressStore.load(levels: levels),
    ))!;
    await tester.pumpWidget(
      FilwordApp(testLevels: levels, testProgress: store),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('home-crystals')),
        matching: find.text('100'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('play-world')));
    await tester.pumpAndSettle();
    expect(find.text('Глава 1/1'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('game-crystals')),
        matching: find.text('100'),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.diamond_outlined), findsOneWidget);
    expect(find.textContaining('Найдено 0 из'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(InputChip).first);
    await tester.tap(find.byTooltip('Подсказки'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Показать начало пути'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    expect(store.crystalBalance, 80);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('home-crystals')),
        matching: find.text('80'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('hidden words, paid hints and screenshots', (tester) async {
    SharedPreferences.setMockInitialValues({});
    setScreen(tester, 390);
    final store = (await tester.runAsync(
      () => ProgressStore.load(levels: levels),
    ))!;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: neonTheme(Brightness.dark),
        home: GameScreen(levels: [city.first], progress: store),
      ),
    );
    final context = tester.element(find.byType(GameScreen));
    await tester.runAsync(
      () => precacheImage(const AssetImage('assets/images/city.png'), context),
    );
    await tester.pumpAndSettle();
    final word = city.first.words.first.text;
    expect(find.text(word), findsNothing);
    expect(find.textContaining('букв'), findsWidgets);
    await expectLater(
      find.byType(GameScreen),
      matchesGoldenFile('../screenshots/stage12_hidden_words_390.png'),
    );
    await tester.tap(find.byType(InputChip).first);
    await tester.tap(find.byTooltip('Подсказки'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Баланс: 100'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../screenshots/stage12_hint_panel_390.png'),
    );
    await tester.tap(find.textContaining('Показать начало пути'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    expect(store.crystalBalance, 80);
    ScaffoldMessenger.of(tester.element(find.byType(GameScreen)))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    expect(find.text(word), findsNothing);
    final painter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byKey(const Key('game-board')),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter
            as BoardPainter;
    expect(painter.hintStartCells, [
      city.first.words.first.canonicalPath.first,
    ]);
    await expectLater(
      find.byType(GameScreen),
      matchesGoldenFile('../screenshots/stage12_hint_start_390.png'),
    );
    await tester.tap(find.byTooltip('Подсказки'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Открыть слово'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    expect(store.crystalBalance, 50);
    ScaffoldMessenger.of(tester.element(find.byType(GameScreen)))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    expect(find.text(word), findsOneWidget);
    await expectLater(
      find.byType(GameScreen),
      matchesGoldenFile('../screenshots/stage12_hint_answer_390.png'),
    );
  });

  testWidgets('stats and achievements screenshots', (tester) async {
    SharedPreferences.setMockInitialValues({});
    setScreen(tester, 390);
    final store = (await tester.runAsync(
      () => ProgressStore.load(levels: levels),
    ))!;
    await tester.runAsync(() async {
      await store.addActiveSeconds('neon_city', 45);
      await store.completeLevel(city.first, 45);
    });
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: neonTheme(Brightness.dark),
        home: StatsPage(progress: store, levels: levels),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Активное время'), findsOneWidget);
    expect(store.world('neon_city').currentIndex, 1);
    await expectLater(
      find.byType(StatsPage),
      matchesGoldenFile('../screenshots/stage12_stats_390.png'),
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: neonTheme(Brightness.dark),
        home: AchievementsPage(progress: store, levels: levels),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Первое слово'), findsOneWidget);
    await expectLater(
      find.byType(AchievementsPage),
      matchesGoldenFile('../screenshots/stage12_achievements_390.png'),
    );
  });

  testWidgets('completed world victory screenshot', (tester) async {
    setScreen(tester, 390);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: neonTheme(Brightness.dark),
        home: VictoryScreen(
          level: city.last,
          seconds: 125,
          crystalsEarned: 60,
          newAchievements: const ['Покоритель города'],
          worldFinished: true,
          nextLevel: city.first,
          onNext: () {},
          effectsEnabled: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Мир полностью пройден! Следующий круг начнётся с первого уровня.',
      ),
      findsOneWidget,
    );
    expect(find.text('Новый круг'), findsOneWidget);
    await expectLater(
      find.byType(VictoryScreen),
      matchesGoldenFile('../screenshots/stage12_world_complete_390.png'),
    );
  });

  for (final width in [360.0, 412.0]) {
    testWidgets('hint-enabled game layout fits $width px', (tester) async {
      SharedPreferences.setMockInitialValues({});
      setScreen(tester, width);
      final store = (await tester.runAsync(
        () => ProgressStore.load(levels: levels),
      ))!;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: neonTheme(Brightness.dark),
          home: GameScreen(levels: [city.first], progress: store),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('game-board')), findsOneWidget);
      expect(find.byTooltip('Подсказки'), findsOneWidget);
    });
  }
}
