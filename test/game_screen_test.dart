import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:filword/app_pages.dart';
import 'package:filword/game_screen.dart';
import 'package:filword/game_session.dart';
import 'package:filword/main.dart';
import 'package:filword/progress_store.dart';
import 'package:filword/visual_home.dart';
import 'package:filword/ui/menu_screen.dart';
import 'package:filword/ui/info_content.dart';
import 'package:filword/ui/info_screen.dart';
import 'package:filword/ui/level_display.dart';
import 'package:filword/ui/neon_theme.dart';
import 'package:filword/ui/world_game_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    final bytes = File('C:/Windows/Fonts/arial.ttf').readAsBytesSync();
    await (FontLoader(
      'Roboto',
    )..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
    final icons = File(
      'C:/Tools/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ).readAsBytesSync();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.view(icons.buffer)))).load();
  });
  final levels =
      (jsonDecode(File('assets/levels.json').readAsStringSync()) as List)
          .map((value) => FilwordLevel.fromJson(value as Map<String, dynamic>))
          .toList();
  final legacy =
      (jsonDecode(File('assets/levels_stage4.json').readAsStringSync()) as List)
          .map((value) => FilwordLevel.fromJson(value as Map<String, dynamic>))
          .toList();
  final alternatives = jsonDecode(
    File('test/fixtures/alternative_examples.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('each chapter displays local levels 1 through 100', () {
    expect(chapterLevelLabelFor('neon_city', 1), 'Глава 1 · уровень 1');
    expect(chapterLevelLabelFor('neon_city', 100), 'Глава 1 · уровень 100');
    expect(chapterLevelLabelFor('cosmos', 101), 'Глава 2 · уровень 1');
    expect(chapterLevelLabelFor('cosmos', 200), 'Глава 2 · уровень 100');
    expect(chapterLevelLabelFor('biosphere', 201), 'Глава 3 · уровень 1');
    expect(chapterLevelLabelFor('biosphere', 300), 'Глава 3 · уровень 100');
    expect(chapterLevelLabelFor('cybercore', 301), 'Глава 4 · уровень 1');
    expect(chapterLevelLabelFor('cybercore', 400), 'Глава 4 · уровень 100');
    expect(compactChapterLevelLabel(levels.first), 'Глава 1/1');
    expect(
      compactChapterLevelLabel(levels.firstWhere((item) => item.id == 106)),
      'Глава 2/6',
    );
  });

  Future<void> pumpGame(
    WidgetTester tester,
    List<FilwordLevel> chosen, {
    double width = 390,
    double height = 850,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: neonTheme(Brightness.dark),
        home: GameScreen(levels: chosen),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> prepareHomeImages(WidgetTester tester) async {
    final context = tester.element(find.byType(DesignHomeScreen));
    await tester.runAsync(() async {
      for (final name in [
        'home_background',
        'home_background_main2',
        'home_background_stage10',
        'home_logo_stage10',
        'city',
        'space',
        'nature',
        'science',
      ]) {
        await precacheImage(AssetImage('assets/images/$name.png'), context);
      }
    });
    await tester.pumpAndSettle();
  }

  Offset center(WidgetTester tester, int cell, int size) {
    final rect = tester.getRect(find.byKey(const Key('game-board')));
    return Offset(
      rect.left + (cell % size + .5) * rect.width / size,
      rect.top + (cell ~/ size + .5) * rect.height / size,
    );
  }

  BoardPainter board(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.descendant(
                  of: find.byKey(const Key('game-board')),
                  matching: find.byType(CustomPaint),
                ),
              )
              .painter
          as BoardPainter;

  Future<void> tapPath(WidgetTester tester, List<int> path, int size) async {
    for (final cell in path) {
      await tester.tapAt(center(tester, cell, size));
      await tester.pump();
    }
  }

  Future<void> waitForVictory(WidgetTester tester) async {
    for (
      var i = 0;
      i < 20 && find.byType(VictoryScreen).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
  }

  Future<void> dragPath(
    WidgetTester tester,
    List<int> path,
    int size, {
    ui.PointerDeviceKind kind = ui.PointerDeviceKind.touch,
  }) async {
    final pointer = await tester.startGesture(
      center(tester, path.first, size),
      kind: kind,
    );
    for (final cell in path.skip(1)) {
      await pointer.moveTo(center(tester, cell, size));
    }
    await pointer.up();
    await tester.pump();
  }

  testWidgets(
    'same-cell tap does nothing; backtrack, auto accept and list order',
    (tester) async {
      final level = levels.first;
      await pumpGame(tester, [level]);
      final path = level.words.first.canonicalPath;
      await tapPath(tester, [path[0], path[0], path[1], path[1], path[2]], 7);
      expect(board(tester).active, path.take(3).toList());
      await tapPath(tester, [path[1]], 7);
      expect(board(tester).active, path.take(2).toList());
      expect(find.text('Сбросить выбор'), findsNothing);
      await dragPath(tester, path, 7);
      expect(board(tester).found.single.word, level.words.first.text);
      expect(board(tester).active, isEmpty);
      final chips = tester
          .widgetList<InputChip>(find.byType(InputChip))
          .toList();
      expect((chips.last.label as Text).data, level.words.first.text);
      await tapPath(tester, path, 7);
      expect(find.text('Слово уже найдено'), findsOneWidget);
      expect(board(tester).found.length, 1);
    },
  );

  testWidgets('touch drag accepts word without a second tap and stays fixed', (
    tester,
  ) async {
    await pumpGame(tester, [levels.first], width: 360, height: 640);
    final before = tester.getRect(find.byKey(const Key('game-board')));
    await dragPath(tester, levels.first.words.first.canonicalPath, 7);
    expect(board(tester).found.length, 1);
    expect(board(tester).active, isEmpty);
    await tester.drag(
      find.byKey(const Key('word-list-scroll')),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const Key('game-board'))), before);
  });

  testWidgets('mouse alternative path crosses prior tap highlight', (
    tester,
  ) async {
    final level = legacy.firstWhere((item) => item.id == 1);
    await pumpGame(tester, [level]);
    final example = alternatives['1'] as Map<String, dynamic>;
    final alternate = (example['path'] as List).cast<int>();
    final other = level.words.firstWhere(
      (word) =>
          word.text != example['word'] &&
          word.canonicalPath.any(alternate.contains),
    );
    await tapPath(tester, other.canonicalPath, 10);
    await dragPath(tester, alternate, 10, kind: ui.PointerDeviceKind.mouse);
    expect(board(tester).found.length, 2);
    expect(board(tester).found.last.path, alternate);
    expect(
      board(tester).found.first.path.toSet().intersection(alternate.toSet()),
      isNotEmpty,
    );
  });

  testWidgets('prefix collision keeps longer word available', (tester) async {
    final level = FilwordLevel(
      id: 1,
      worldId: 'neon_city',
      gridSize: 7,
      grid: ['КОТИКАА', ...List.filled(6, 'ААААААА')],
      words: [
        WordTarget('КОТ', [0, 1, 2]),
        WordTarget('КОТИК', [0, 1, 2, 3, 4]),
      ],
    );
    await pumpGame(tester, [level]);
    await tapPath(tester, [0, 1, 2], 7);
    expect(board(tester).found, isEmpty);
    expect(find.text('Завершить короткое слово'), findsOneWidget);
    await tapPath(tester, [3, 4], 7);
    expect(board(tester).found.single.word, 'КОТИК');
    await tapPath(tester, [0, 1, 2], 7);
    expect(board(tester).found.length, 2);
  });

  testWidgets('home, completion, next level and persisted progress', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 850);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final saved = await tester.runAsync(() => ProgressStore.load());
    await tester.pumpWidget(
      FilwordApp(testLevels: levels, testProgress: saved),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DesignHomeScreen), findsOneWidget);
    await prepareHomeImages(tester);
    await expectLater(
      find.byType(DesignHomeScreen),
      matchesGoldenFile('../screenshots/stage12_home_progress_390.png'),
    );
    await tester.tap(find.byKey(const Key('play-world')));
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsOneWidget);
    final level = levels.first;
    for (final word in level.words) {
      await tapPath(tester, word.canonicalPath, 7);
    }
    expect(board(tester).found.length, level.words.length);
    await waitForVictory(tester);
    expect(saved!.world('neon_city').currentIndex, 1);
    expect(find.byType(VictoryScreen), findsOneWidget);
    expect(find.text('Поздравляем!'), findsOneWidget);
    await expectLater(
      find.byType(VictoryScreen),
      matchesGoldenFile('../screenshots/stage12_victory_390.png'),
    );
    await tester.tap(find.text('Следующий уровень'));
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsOneWidget);
    expect(board(tester).level.id, levels[1].id);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(DesignHomeScreen), findsOneWidget);
    expect(find.text('Пройдено 1/20'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    final reloaded = await tester.runAsync(() => ProgressStore.load());
    await tester.pumpWidget(
      FilwordApp(testLevels: levels, testProgress: reloaded),
    );
    await tester.pumpAndSettle();
    expect(find.text('Пройдено 1/20'), findsOneWidget);
  });

  testWidgets('theme, stats, achievements and info open from home', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 850);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final saved = await tester.runAsync(() => ProgressStore.load());
    await tester.pumpWidget(
      FilwordApp(testLevels: levels, testProgress: saved),
    );
    await tester.pumpAndSettle();
    for (final title in ['Тема', 'Статистика', 'Достижения', 'Об игре']) {
      await tester.tap(find.byKey(const Key('open-menu')));
      await tester.pumpAndSettle();
      if (title == 'Тема') {
        await expectLater(
          find.byType(MenuScreen),
          matchesGoldenFile('../screenshots/stage10_menu_390.png'),
        );
      }
      if (title == 'Об игре') {
        await tester.tap(find.text('ИНФО'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(title).first);
      await tester.pumpAndSettle();
      expect(find.text(title), findsWidgets);
      if (title == 'Тема') {
        await tester.tap(find.text('Светлая'));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.check), findsOneWidget);
      }
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(MenuScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(DesignHomeScreen), findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('play-world')));
    await tester.pumpAndSettle();
    expect(board(tester).light, isTrue);
  });

  testWidgets('feedback and developer contacts open from menu', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final saved = await tester.runAsync(() => ProgressStore.load());
    await tester.pumpWidget(
      FilwordApp(testLevels: levels, testProgress: saved),
    );
    await tester.pumpAndSettle();
    await prepareHomeImages(tester);
    await tester.tap(find.byKey(const Key('open-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ИНФО'));
    await tester.pumpAndSettle();

    for (final document in [feedbackDocument]) {
      await tester.tap(find.text(document.title).first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<InfoScreen>(find.byType(InfoScreen)).document,
        same(document),
      );
      expect(find.text(document.sections.first.text), findsOneWidget);
      expect(
        find.text('Документ будет добавлен перед публикацией.'),
        findsNothing,
      );
      final name = document == privacyDocument
          ? 'privacy'
          : document == termsDocument
          ? 'terms'
          : 'feedback';
      await expectLater(
        find.byType(InfoScreen),
        matchesGoldenFile('../screenshots/info_${name}_390.png'),
      );
      if (document == feedbackDocument) {
        String? copied;
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
        final copy = find.byTooltip('Скопировать $developerEmail');
        await tester.ensureVisible(copy);
        await tester.tap(copy);
        await tester.pump();
        expect(copied, developerEmail);
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      }
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('last test level announces end of available content', (
    tester,
  ) async {
    final level = levels.where((item) => item.worldId == 'neon_city').last;
    await tester.pumpWidget(
      MaterialApp(home: VictoryScreen(level: level, seconds: 12)),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Новых тестовых уровней в этом мире пока нет.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Следующий уровень'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('production app loads bundled levels and local storage', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const FilwordApp());
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1999));
    expect(find.byType(SplashScreen), findsOneWidget);
    for (
      var i = 0;
      i < 30 && find.byType(DesignHomeScreen).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(DesignHomeScreen), findsOneWidget);
    expect(find.byKey(const Key('world-carousel')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const FilwordApp());
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
  ]) {
    testWidgets(
      'splash artwork fits ${size.width.toInt()}×${size.height.toInt()}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
        final context = tester.element(find.byType(SplashScreen));
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/images/splash_screen.png'),
            context,
          ),
        );
        await tester.pumpAndSettle();
        final artwork = tester.widget<Image>(find.byType(Image));
        expect(artwork.fit, BoxFit.cover);
        await expectLater(
          find.byType(SplashScreen),
          matchesGoldenFile(
            '../screenshots/stage9_splash_${size.width.toInt()}.png',
          ),
        );
      },
    );
  }

  testWidgets('every world uses its stable identifier for the backdrop', (
    tester,
  ) async {
    for (final world in worldBackgroundAssets.keys) {
      final level = levels.firstWhere((item) => item.worldId == world);
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpGame(tester, [level]);
      final image = tester.widget<Image>(
        find.byKey(const Key('game-world-background-image')),
      );
      expect(
        (image.image as AssetImage).assetName,
        worldBackgroundAssets[world],
      );
      expect(image.fit, BoxFit.cover);
      expect(find.byType(WorldGameBackground), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('carousel navigation keeps the selected background', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final saved = await tester.runAsync(() => ProgressStore.load());
    await tester.pumpWidget(
      FilwordApp(testLevels: levels, testProgress: saved),
    );
    await tester.pumpAndSettle();
    final worlds = worldBackgroundAssets.keys.toList();
    for (var i = 0; i < worlds.length; i++) {
      if (i > 0) {
        await tester.tap(find.byKey(const Key('next-world')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('play-world')));
      await tester.pumpAndSettle();
      expect(find.byType(GameScreen), findsOneWidget);
      expect(
        tester
            .widget<WorldGameBackground>(find.byType(WorldGameBackground))
            .worldId,
        worlds[i],
      );
      expect(board(tester).level.worldId, worlds[i]);
      if (i == 0) {
        final first = board(tester).level;
        for (final word in first.words) {
          await tapPath(tester, word.canonicalPath, first.gridSize);
        }
        await waitForVictory(tester);
        expect(find.byType(VictoryScreen), findsOneWidget);
        await tester.tap(find.text('Следующий уровень'));
        await tester.pumpAndSettle();
        expect(board(tester).level.worldId, worlds[i]);
        expect(
          tester
              .widget<WorldGameBackground>(find.byType(WorldGameBackground))
              .worldId,
          worlds[i],
        );
      }
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(SplashScreen), findsNothing);
    }
  });

  testWidgets('world image remains visible in both themes', (tester) async {
    final level = levels.firstWhere((item) => item.worldId == 'biosphere');
    for (final brightness in [Brightness.dark, Brightness.light]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          theme: neonTheme(brightness),
          home: GameScreen(levels: [level], worldId: level.worldId),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WorldGameBackground>(find.byType(WorldGameBackground))
            .worldId,
        'biosphere',
      );
      expect(
        (tester
                    .widget<Image>(
                      find.byKey(const Key('game-world-background-image')),
                    )
                    .image
                as AssetImage)
            .assetName,
        'assets/images/nature.png',
      );
      expect(board(tester).light, brightness == Brightness.light);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'carousel accepts touch and mouse drags, then opens the active world',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final saved = await tester.runAsync(() => ProgressStore.load());
      await tester.pumpWidget(
        FilwordApp(testLevels: levels, testProgress: saved),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        expect(find.byKey(Key('hamburger-line-$i')), findsOneWidget);
      }
      expect(
        (tester.widget<Image>(find.byKey(const Key('home-logo'))).image
                as AssetImage)
            .assetName,
        'assets/images/home_logo_stage10.png',
      );
      final carousel = find.byKey(const Key('world-carousel'));
      final origin = tester.getCenter(carousel);
      for (final kind in [
        ui.PointerDeviceKind.touch,
        ui.PointerDeviceKind.mouse,
      ]) {
        final pointer = await tester.startGesture(origin, kind: kind);
        await pointer.moveBy(const Offset(-30, 0));
        await tester.pump(const Duration(milliseconds: 16));
        await pointer.moveBy(const Offset(-200, 0));
        await tester.pump(const Duration(milliseconds: 16));
        await pointer.up();
        await tester.pumpAndSettle();
      }
      final page = tester.widget<PageView>(carousel).controller!.page;
      expect(page, closeTo(2, .01));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        tester.widget<PageView>(carousel).controller!.page,
        closeTo(3, .01),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(
        tester.widget<PageView>(carousel).controller!.page,
        closeTo(2, .01),
      );
      final centerCard = tester.getRect(
        find.byKey(const Key('world-biosphere')),
      );
      final neighbor = tester.getRect(find.byKey(const Key('world-cybercore')));
      expect(centerCard.width, greaterThan(neighbor.width));
      await tester.tap(find.byKey(const Key('play-world')));
      await tester.pumpAndSettle();
      expect(board(tester).level.gridSize, 9);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(SplashScreen), findsNothing);
      expect(
        tester.widget<PageView>(carousel).controller!.page,
        closeTo(2, .01),
      );
    },
  );

  testWidgets('settings persist effect preference and light theme', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final saved = (await tester.runAsync(() => ProgressStore.load()))!;
    await tester.pumpWidget(
      FilwordApp(testLevels: levels, testProgress: saved),
    );
    await tester.pumpAndSettle();
    await prepareHomeImages(tester);
    await tester.tap(find.byKey(const Key('open-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('../screenshots/stage8_settings_390.png'),
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(saved.effectsEnabled, isFalse);
    await tester.tap(find.text('Светлая'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('../screenshots/stage8_settings_light_390.png'),
    );
    final reloaded = (await tester.runAsync(() => ProgressStore.load()))!;
    expect(reloaded.effectsEnabled, isFalse);
    expect(reloaded.lightTheme, isTrue);
  });

  testWidgets(
    'missing world shows lock and a clear message without opening game',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final saved = await tester.runAsync(() => ProgressStore.load());
      await tester.pumpWidget(
        FilwordApp(testLevels: const [], testProgress: saved),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.lock_outline), findsWidgets);
      await tester.tap(find.byKey(const Key('world-neon_city')));
      await tester.pump();
      expect(
        find.text('Тестовые уровни этого мира пока не готовы'),
        findsOneWidget,
      );
      expect(find.byType(GameScreen), findsNothing);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'victory effect is finite and lets the next button receive input',
    (tester) async {
      var nextCalls = 0;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: neonTheme(Brightness.dark),
          home: VictoryScreen(
            level: levels.first,
            seconds: 42,
            nextLevel: levels[1],
            onNext: () => nextCalls++,
          ),
        ),
      );
      final context = tester.element(find.byType(VictoryScreen));
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/images/home_background.png'),
          context,
        ),
      );
      await tester.pump(const Duration(milliseconds: 650));
      expect(find.byKey(const Key('victory-effect')), findsOneWidget);
      await expectLater(
        find.byType(VictoryScreen),
        matchesGoldenFile('../screenshots/stage12_victory_effect_390.png'),
      );
      await tester.tap(find.text('Следующий уровень'));
      expect(nextCalls, 1);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    },
  );

  for (final width in [360.0, 390.0, 412.0]) {
    for (final size in [7, 8, 9, 10]) {
      testWidgets('fixed $size×$size game layout at ${width.toInt()} px', (
        tester,
      ) async {
        final level = levels.firstWhere((item) => item.gridSize == size);
        await pumpGame(
          tester,
          [level],
          width: width,
          height: switch (width) {
            360 => 800,
            390 => 844,
            _ => 915,
          },
        );
        final rect = tester.getRect(find.byKey(const Key('game-board')));
        expect(find.text(compactChapterLevelLabel(level)), findsOneWidget);
        expect(find.text('Сбросить выбор'), findsNothing);
        expect(find.text('На главную'), findsNothing);
        expect(find.textContaining('Тест '), findsNothing);
        expect(rect.width, width - 16);
        expect(rect.height, rect.width);
        expect(tester.takeException(), isNull);
        if (width == 390) {
          await expectLater(
            find.byType(GameScreen),
            matchesGoldenFile('../screenshots/stage12_game_${size}_390.png'),
          );
        } else if (size == 10) {
          await expectLater(
            find.byType(GameScreen),
            matchesGoldenFile(
              '../screenshots/stage12_game_10_${width.toInt()}.png',
            ),
          );
        }
      });
    }
  }

  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
  ]) {
    testWidgets('home and world cards fit ${size.width.toInt()} px', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final saved = await tester.runAsync(() => ProgressStore.load());
      await tester.pumpWidget(
        FilwordApp(testLevels: levels, testProgress: saved),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DesignHomeScreen), findsOneWidget);
      await prepareHomeImages(tester);
      await expectLater(
        find.byType(DesignHomeScreen),
        matchesGoldenFile(
          '../screenshots/stage12_home_${size.width.toInt()}.png',
        ),
      );
      for (final world in ['neon_city', 'cosmos', 'biosphere', 'cybercore']) {
        final card = find.byKey(Key('world-$world'));
        await tester.pumpAndSettle();
        expect(tester.getRect(card).width, greaterThan(100));
        if (size.width == 390) {
          await expectLater(
            find.byType(DesignHomeScreen),
            matchesGoldenFile('../screenshots/stage12_selected_$world.png'),
          );
        }
        if (world != 'cybercore') {
          await tester.tap(find.byKey(const Key('next-world')));
          await tester.pumpAndSettle();
        }
      }
      expect(tester.takeException(), isNull);
    });
  }
}
