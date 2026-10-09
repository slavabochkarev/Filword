import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:filword/app_pages.dart';
import 'package:filword/game_screen.dart';
import 'package:filword/game_session.dart';
import 'package:filword/main.dart';
import 'package:filword/progress_store.dart';
import 'package:filword/visual_home.dart';
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
        theme: ThemeData.dark(),
        home: GameScreen(levels: chosen),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> prepareHomeImages(WidgetTester tester) async {
    final context = tester.element(find.byType(DesignHomeScreen));
    await tester.runAsync(() async {
      for (final name in ['home_hero', 'city', 'space', 'nature', 'science']) {
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
      await tester.tap(find.text('Сбросить выбор'));
      await tester.pump();
      expect(board(tester).active, isEmpty);
      await tapPath(tester, [0], 7);
      expect(board(tester).found, isEmpty);
      await tester.tap(find.text('Сбросить выбор'));
      await tester.pump();
      await tapPath(tester, path, 7);
      expect(board(tester).found.single.word, level.words.first.text);
      expect(board(tester).active, isEmpty);
      final chips = tester.widgetList<Chip>(find.byType(Chip)).toList();
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
      matchesGoldenFile('../screenshots/stage7_home_390.png'),
    );
    await tester.tap(find.byKey(const Key('world-neon_city')));
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsOneWidget);
    final level = levels.first;
    for (final word in level.words) {
      await tapPath(tester, word.canonicalPath, 7);
    }
    await tester.pumpAndSettle();
    expect(find.byType(VictoryScreen), findsOneWidget);
    expect(find.text('Поздравляем!'), findsOneWidget);
    await expectLater(
      find.byType(VictoryScreen),
      matchesGoldenFile('../screenshots/stage7_victory_390.png'),
    );
    await tester.tap(find.text('Следующий уровень'));
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsOneWidget);
    expect(board(tester).level.id, levels[1].id);
    await tester.tap(find.text('На главную'));
    await tester.pumpAndSettle();
    expect(find.byType(DesignHomeScreen), findsOneWidget);
    expect(find.text('7×7 · ур. 2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    final reloaded = await tester.runAsync(() => ProgressStore.load());
    await tester.pumpWidget(
      FilwordApp(testLevels: levels, testProgress: reloaded),
    );
    await tester.pumpAndSettle();
    expect(find.text('7×7 · ур. 2'), findsOneWidget);
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
          find.byType(Drawer),
          matchesGoldenFile('../screenshots/stage7_menu_390.png'),
        );
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
      expect(find.byType(DesignHomeScreen), findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('world-neon_city')));
    await tester.pumpAndSettle();
    expect(board(tester).light, isTrue);
  });

  testWidgets('last test level announces end of available content', (
    tester,
  ) async {
    final level = levels.where((item) => item.worldId == 'neon_city').last;
    await tester.pumpWidget(
      MaterialApp(home: VictoryScreen(level: level, seconds: 12)),
    );
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
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(find.byType(DesignHomeScreen), findsOneWidget);
    expect(find.byKey(const Key('world-cybercore')), findsOneWidget);
  });

  for (final width in [360.0, 390.0, 412.0]) {
    for (final size in [7, 8, 9, 10]) {
      testWidgets('fixed $size×$size game layout at ${width.toInt()} px', (
        tester,
      ) async {
        final level = levels.firstWhere((item) => item.gridSize == size);
        await pumpGame(tester, [level], width: width);
        final rect = tester.getRect(find.byKey(const Key('game-board')));
        expect(rect.width, width - 16);
        expect(rect.height, rect.width);
        expect(tester.takeException(), isNull);
        if (width == 390 && (size == 7 || size == 10)) {
          await expectLater(
            find.byType(GameScreen),
            matchesGoldenFile('../screenshots/stage7_game_${size}_390.png'),
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
      for (final world in ['neon_city', 'cosmos', 'biosphere', 'cybercore']) {
        final card = find.byKey(Key('world-$world'));
        await tester.ensureVisible(card);
        expect(tester.getRect(card).width, greaterThan(100));
        if (size.width == 390) {
          await expectLater(
            card,
            matchesGoldenFile('../screenshots/stage7_card_$world.png'),
          );
        }
      }
      expect(tester.takeException(), isNull);
    });
  }
}
