import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game_session.dart';
import 'progress_store.dart';
import 'ui/level_display.dart';
import 'ui/hidden_word_label.dart';
import 'ui/world_game_background.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    this.levels,
    this.initialIndex = 0,
    this.worldId,
    this.progress,
    this.onCompleted,
  });
  final List<FilwordLevel>? levels;
  final int initialIndex;
  final String? worldId;
  final ProgressStore? progress;
  final void Function(BuildContext context, FilwordLevel level, int seconds)?
  onCompleted;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  List<FilwordLevel>? levels;
  GameSession? session;
  int levelIndex = 0;
  final List<int> gesture = [];
  Offset? lastPointer;
  Offset? pointerStart;
  int? activePointer;
  bool dragging = false;
  bool dragConsumed = false;
  bool victoryShown = false;
  final Stopwatch stopwatch = Stopwatch();
  Timer? clockTimer;
  int chargedSeconds = 0;
  String? selectedHintWord;
  bool pausedByDialog = false;
  String? message;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => flushClock(),
    );
    levelIndex = widget.initialIndex;
    if (widget.levels != null) {
      levels = widget.levels;
      session = GameSession(levels![levelIndex]);
      restoreFound();
      stopwatch.start();
    } else {
      load();
    }
  }

  @override
  void dispose() {
    flushClock();
    stopwatch.stop();
    clockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !victoryShown &&
        !pausedByDialog) {
      stopwatch.start();
    } else {
      flushClock();
      stopwatch.stop();
    }
  }

  void flushClock() {
    if (widget.progress == null || session == null || victoryShown) return;
    final elapsed = stopwatch.elapsed.inSeconds;
    final delta = elapsed - chargedSeconds;
    if (delta <= 0) return;
    chargedSeconds = elapsed;
    unawaited(widget.progress!.addActiveSeconds(session!.level.worldId, delta));
  }

  void restoreFound() {
    if (session == null || widget.progress == null) return;
    for (final found in widget.progress!.restoredPaths(session!.level)) {
      session!.submit(found.path);
    }
  }

  Future<void> load() async {
    final raw = await rootBundle.loadString('assets/levels.json');
    final parsed = (jsonDecode(raw) as List)
        .map((item) => FilwordLevel.fromJson(item as Map<String, dynamic>))
        .toList();
    if (!mounted) return;
    setState(() {
      levels = parsed;
      session = GameSession(parsed[levelIndex]);
      restoreFound();
      stopwatch.start();
    });
  }

  void switchLevel(int index) {
    flushClock();
    setState(() {
      levelIndex = index % levels!.length;
      session = GameSession(levels![levelIndex]);
      if (widget.progress != null) {
        unawaited(widget.progress!.clearFound(session!.level));
      }
      gesture.clear();
      lastPointer = null;
      pointerStart = null;
      activePointer = null;
      dragging = false;
      dragConsumed = false;
      victoryShown = false;
      stopwatch.reset();
      chargedSeconds = 0;
      stopwatch.start();
      selectedHintWord = null;
      message = null;
    });
  }

  int? cellAt(Offset p, double size, int gridSize) {
    if (p.dx < 0 || p.dy < 0 || p.dx >= size || p.dy >= size) return null;
    final unit = size / gridSize;
    return (p.dy ~/ unit) * gridSize + p.dx ~/ unit;
  }

  bool visit(int? cell) {
    if (cell == null) return false;
    if (gesture.isEmpty) {
      gesture.add(cell);
      return true;
    }
    if (cell == gesture.last) return false;
    if (gesture.length > 1 && cell == gesture[gesture.length - 2]) {
      gesture.removeLast();
      return true;
    }
    if (gesture.contains(cell)) return false;
    if (GameSession.adjacent(gesture.last, cell, session!.level.gridSize)) {
      gesture.add(cell);
      return true;
    }
    return false;
  }

  bool maybeAccept() {
    if (gesture.isEmpty) return false;
    final text = session!.level.spell(gesture);
    if (!session!.level.words.any((word) => word.text == text)) return false;
    // A longer target with this prefix must remain traceable.
    if (session!.hasLongerUnfoundTarget(text)) return false;
    finish();
    return true;
  }

  bool get ambiguousShortWord =>
      gesture.isNotEmpty &&
      session!.isUnfoundTarget(session!.level.spell(gesture)) &&
      session!.hasLongerUnfoundTarget(session!.level.spell(gesture));

  void pointerDown(PointerDownEvent event) {
    if (activePointer != null) return;
    activePointer = event.pointer;
    pointerStart = event.localPosition;
    lastPointer = event.localPosition;
    dragging = false;
    dragConsumed = false;
  }

  void pointerMove(PointerMoveEvent event, double size) {
    if (activePointer != event.pointer ||
        pointerStart == null ||
        dragConsumed) {
      return;
    }
    final p = event.localPosition;
    if (!dragging &&
        ((p - pointerStart!).distance < 6 ||
            cellAt(p, size, session!.level.gridSize) ==
                cellAt(pointerStart!, size, session!.level.gridSize))) {
      return;
    }
    if (!dragging) {
      dragging = true;
      gesture.clear();
      visit(cellAt(pointerStart!, size, session!.level.gridSize));
    }
    final from = lastPointer;
    setState(() {
      if (from != null) {
        // Interpolate fast pointer events so narrow cells are not skipped.
        final unit = size / session!.level.gridSize;
        final steps = math.max(1, ((p - from).distance / (unit / 3)).ceil());
        for (var i = 1; i <= steps; i++) {
          final changed = visit(
            cellAt(
              Offset.lerp(from, p, i / steps)!,
              size,
              session!.level.gridSize,
            ),
          );
          if (changed && maybeAccept()) {
            dragConsumed = true;
            break;
          }
        }
      }
      lastPointer = p;
      if (!dragConsumed) {
        message = gesture.isEmpty
            ? null
            : 'Выбор: ${session!.level.spell(gesture)}';
      }
    });
  }

  void pointerUp(PointerUpEvent event, double size) {
    if (activePointer != event.pointer) return;
    if (dragging) {
      if (!dragConsumed) finish();
    } else {
      setState(() {
        final changed = visit(
          cellAt(pointerStart!, size, session!.level.gridSize),
        );
        if (changed && !maybeAccept()) {
          message = 'Выбор: ${session!.level.spell(gesture)}';
        }
      });
    }
    activePointer = null;
    pointerStart = null;
    lastPointer = null;
    dragging = false;
    dragConsumed = false;
  }

  void pointerCancel(PointerCancelEvent event) {
    if (activePointer != event.pointer) return;
    setState(() {
      if (dragging) gesture.clear();
      activePointer = null;
      pointerStart = null;
      lastPointer = null;
      dragging = false;
      dragConsumed = false;
      message = 'Жест отменён';
    });
  }

  void clearSelection() => setState(() {
    gesture.clear();
    message = 'Выбор очищен';
  });

  Future<void> pauseGame() async {
    flushClock();
    stopwatch.stop();
    pausedByDialog = true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Пауза'),
        content: const Text('Игровое время остановлено.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              switchLevel(levelIndex);
            },
            child: const Text('Начать уровень заново'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
    pausedByDialog = false;
    if (mounted && !victoryShown) stopwatch.start();
  }

  Future<void> showHints() async {
    final level = session!.level;
    final word = selectedHintWord;
    if (widget.progress == null || word == null || session!.isFound(word)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала выберите скрытое слово в списке'),
        ),
      );
      return;
    }
    final target = level.words.firstWhere((item) => item.text == word);
    final data = widget.progress!.world(level.worldId);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Подсказка для слова из ${word.length} букв',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.diamond_outlined, size: 20),
                  const SizedBox(width: 6),
                  Text('Баланс: ${widget.progress!.crystalBalance}'),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () async => purchaseHint(
                  sheetContext,
                  level,
                  target.text,
                  HintKind.start,
                ),
                icon: const Icon(Icons.place_outlined),
                label: Text(
                  data.hintStarts.contains(word)
                      ? 'Показать начало снова · бесплатно'
                      : 'Показать начало пути · 20 кристаллов',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () async => purchaseHint(
                  sheetContext,
                  level,
                  target.text,
                  HintKind.answer,
                ),
                icon: const Icon(Icons.visibility_outlined),
                label: Text(
                  data.hintAnswers.contains(word)
                      ? 'Показать слово снова · бесплатно'
                      : 'Открыть слово · 30 кристаллов',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> purchaseHint(
    BuildContext sheetContext,
    FilwordLevel level,
    String word,
    HintKind kind,
  ) async {
    final purchase = await widget.progress!.buyHint(level, word, kind);
    if (!mounted) return;
    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
    setState(() {});
    final text = purchase.insufficientFunds
        ? 'Недостаточно кристаллов'
        : purchase.applied
        ? (kind == HintKind.start
              ? 'Начало пути подсвечено'
              : 'Слово открыто в списке')
        : 'Подсказка недоступна';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void finish() {
    if (gesture.isEmpty) return;
    final result = session!.submit(List.of(gesture));
    if (result.status == SelectionStatus.found &&
        result.text == selectedHintWord) {
      selectedHintWord = null;
    }
    if (result.status == SelectionStatus.found &&
        !session!.completed &&
        widget.progress != null) {
      unawaited(
        widget.progress!.recordFound(
          session!.level,
          FoundPath(result.text, result.selectedPath),
        ),
      );
    }
    setState(() {
      gesture.clear();
      message = switch (result.status) {
        SelectionStatus.found =>
          session!.completed ? 'Уровень завершён!' : 'Найдено: ${result.text}',
        SelectionStatus.alreadyFound => 'Слово уже найдено',
        SelectionStatus.notTarget => 'Нет в списке: ${result.text}',
        SelectionStatus.invalid => 'Некорректный путь',
      };
    });
    if (session!.completed && !victoryShown) {
      flushClock();
      victoryShown = true;
      stopwatch.stop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onCompleted?.call(
            context,
            session!.level,
            math.max(
              1,
              widget.progress?.world(session!.level.worldId).levelSeconds ??
                  stopwatch.elapsed.inSeconds,
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (session == null || levels == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final level = session!.level;
    final light = Theme.of(context).brightness == Brightness.light;
    final controlBackdrop = light
        ? const Color(0xeaf3f9ff)
        : const Color(0xc20d1930);
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xff080e24)
          : const Color(0xffe7f2ff),
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        title: Text(compactChapterLevelLabel(level)),
        centerTitle: true,
        actions: [
          if (widget.progress != null)
            Tooltip(
              message: 'Подсказки',
              child: TextButton.icon(
                key: const Key('game-crystals'),
                onPressed: showHints,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xffffd166),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                icon: const Icon(Icons.diamond_outlined, size: 22),
                label: Text(
                  '${widget.progress!.crystalBalance}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Пауза',
            onPressed: pauseGame,
            icon: const Icon(Icons.pause_circle_outline),
          ),
        ],
      ),
      body: WorldGameBackground(
        worldId: widget.worldId ?? level.worldId,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final size = math.min(
                math.min(box.maxWidth - 16, 480.0),
                math.max(0.0, box.maxHeight - 200.0),
              );
              return Center(
                child: SizedBox(
                  width: math.min(box.maxWidth, 500),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          margin: const EdgeInsets.fromLTRB(4, 2, 4, 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: controlBackdrop,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Найдено ${session!.foundCount} из ${level.words.length}',
                            style: TextStyle(
                              fontSize: 15,
                              color: light
                                  ? const Color(0xff152c45)
                                  : Colors.white,
                            ),
                          ),
                        ),
                        Center(
                          child: SizedBox(
                            width: size,
                            height: size,
                            child: Listener(
                              behavior: HitTestBehavior.opaque,
                              onPointerDown: pointerDown,
                              onPointerMove: (e) => pointerMove(e, size),
                              onPointerUp: (e) => pointerUp(e, size),
                              onPointerCancel: pointerCancel,
                              child: RepaintBoundary(
                                key: const Key('game-board'),
                                child: CustomPaint(
                                  painter: BoardPainter(
                                    level: level,
                                    found: session!.foundPaths,
                                    active: gesture,
                                    hintStartCells: [
                                      if (widget.progress != null)
                                        for (final target in level.words)
                                          if (widget.progress!
                                                  .world(level.worldId)
                                                  .hintStarts
                                                  .contains(target.text) &&
                                              !session!.isFound(target.text))
                                            target.canonicalPath.first,
                                    ],
                                    light:
                                        Theme.of(context).brightness ==
                                        Brightness.light,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: controlBackdrop,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            message ??
                                'Проведите или нажимайте на соседние буквы',
                            key: const Key('status-message'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: session!.completed
                                  ? (light
                                        ? const Color(0xff146d48)
                                        : const Color(0xff69e5a2))
                                  : (light
                                        ? const Color(0xff152c45)
                                        : Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: SingleChildScrollView(
                            key: const Key('word-list-scroll'),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final word in [
                                    ...level.words.where(
                                      (word) => !session!.isFound(word.text),
                                    ),
                                    ...session!.foundPaths.map(
                                      (found) => level.words.firstWhere(
                                        (word) => word.text == found.word,
                                      ),
                                    ),
                                  ])
                                    InputChip(
                                      showCheckmark: false,
                                      avatar: session!.isFound(word.text)
                                          ? const Icon(Icons.check, size: 16)
                                          : null,
                                      onPressed: session!.isFound(word.text)
                                          ? null
                                          : () => setState(
                                              () =>
                                                  selectedHintWord = word.text,
                                            ),
                                      selected:
                                          selectedHintWord == word.text &&
                                          !session!.isFound(word.text),
                                      label: Text(
                                        session!.isFound(word.text) ||
                                                (widget.progress
                                                        ?.world(level.worldId)
                                                        .hintAnswers
                                                        .contains(word.text) ??
                                                    false)
                                            ? word.text
                                            : hiddenWordLabel(word.text),
                                        style: TextStyle(
                                          fontSize: 13,
                                          decoration:
                                              session!.isFound(word.text)
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                      backgroundColor:
                                          session!.isFound(word.text)
                                          ? (Theme.of(context).brightness ==
                                                    Brightness.light
                                                ? const Color(0xffbce8df)
                                                : const Color(0xff234750))
                                          : (Theme.of(context).brightness ==
                                                    Brightness.light
                                                ? const Color(0xffdbe8f7)
                                                : const Color(0xff252d41)),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (ambiguousShortWord) ...[
                          FilledButton(
                            onPressed: finish,
                            child: const Text('Завершить короткое слово'),
                          ),
                          const SizedBox(height: 4),
                        ],
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.level,
    required this.found,
    required this.active,
    required this.light,
    this.hintStartCells = const [],
  });
  final FilwordLevel level;
  final List<FoundPath> found;
  final List<int> active;
  final bool light;
  final List<int> hintStartCells;
  static const colors = [
    Color(0xff49d6e5),
    Color(0xffff9f68),
    Color(0xffa78bfa),
    Color(0xff73d99f),
    Color(0xffff75b5),
    Color(0xffffd166),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / level.gridSize;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = light ? const Color(0xffe6f0fb) : const Color(0xff1a2438),
    );
    final gridPaint = Paint()
      ..color = (light ? const Color(0xff7289a6) : const Color(0xff64728c))
          .withValues(alpha: .42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7;
    for (var row = 0; row < level.gridSize; row++) {
      for (var col = 0; col < level.gridSize; col++) {
        canvas.drawRect(
          Rect.fromLTWH(col * unit, row * unit, unit, unit),
          gridPaint,
        );
      }
    }
    for (var i = 0; i < found.length; i++) {
      drawPath(
        canvas,
        found[i].path,
        unit,
        colors[i % colors.length].withValues(alpha: .74),
      );
    }
    drawPath(
      canvas,
      active,
      unit,
      (light ? const Color(0xff3c61b8) : const Color(0xff70e4ff)).withValues(
        alpha: .78,
      ),
    );
    for (var row = 0; row < level.gridSize; row++) {
      for (var col = 0; col < level.gridSize; col++) {
        final painter = TextPainter(
          text: TextSpan(
            text: level.grid[row][col],
            style: TextStyle(
              color: light ? const Color(0xff172440) : Colors.white,
              fontFamily: 'Roboto',
              fontSize: unit * .52,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(
                  color: light ? Colors.white70 : Colors.black87,
                  blurRadius: 3,
                ),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(
          canvas,
          Offset(
            (col + .5) * unit - painter.width / 2,
            (row + .5) * unit - painter.height / 2,
          ),
        );
      }
    }
    for (final cell in hintStartCells) {
      canvas.drawCircle(
        Offset(
          (cell % level.gridSize + .5) * unit,
          (cell ~/ level.gridSize + .5) * unit,
        ),
        unit * .38,
        Paint()
          ..color = const Color(0xffffd166)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      Paint()
        ..color = (light ? const Color(0xff4b77b1) : const Color(0xff56d5f9))
            .withValues(alpha: .8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7,
    );
  }

  void drawPath(Canvas canvas, List<int> path, double unit, Color color) {
    if (path.isEmpty) return;
    Offset center(int cell) => Offset(
      (cell % level.gridSize + .5) * unit,
      (cell ~/ level.gridSize + .5) * unit,
    );
    if (path.length == 1) {
      canvas.drawCircle(center(path.first), unit * .41, Paint()..color = color);
      return;
    }
    final stroke = Paint()
      ..color = color
      ..strokeWidth = unit * .82
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final line = Path()..moveTo(center(path.first).dx, center(path.first).dy);
    for (final cell in path.skip(1)) {
      line.lineTo(center(cell).dx, center(cell).dy);
    }
    canvas.drawPath(line, stroke);
  }

  @override
  bool shouldRepaint(covariant BoardPainter old) => true;
}
