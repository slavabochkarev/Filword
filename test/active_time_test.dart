import 'dart:convert';
import 'dart:io';

import 'package:filword/game_screen.dart';
import 'package:filword/game_session.dart';
import 'package:filword/progress_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final levels =
      (jsonDecode(File('assets/levels.json').readAsStringSync()) as List)
          .map((item) => FilwordLevel.fromJson(item as Map<String, dynamic>))
          .where((item) => item.worldId == 'neon_city')
          .toList();

  testWidgets('active clock stops on app pause and dialog pause', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final progress = (await tester.runAsync(
      () => ProgressStore.load(levels: levels),
    ))!;
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(levels: [levels.first], progress: progress),
      ),
    );
    await tester.pump();

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1600)),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final beforePause = progress.activeSeconds;
    expect(beforePause, greaterThanOrEqualTo(1));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1100)),
    );
    expect(progress.activeSeconds, beforePause);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1100)),
    );
    await tester.tap(find.byTooltip('Пауза'));
    await tester.pumpAndSettle();
    final beforeDialog = progress.activeSeconds;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1100)),
    );
    expect(progress.activeSeconds, beforeDialog);
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    expect(progress.activeSeconds, greaterThanOrEqualTo(beforeDialog));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
