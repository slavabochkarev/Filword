import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game_session.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    this.levels,
    this.initialIndex = 0,
    this.onCompleted,
  });
  final List<FilwordLevel>? levels;
  final int initialIndex;
  final void Function(BuildContext context, FilwordLevel level, int seconds)?
  onCompleted;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
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
  final Stopwatch stopwatch = Stopwatch()..start();
  String? message;
  static const worldNames = {
    'neon_city': 'Город',
    'cosmos': 'Космос',
    'biosphere': 'Природа',
    'cybercore': 'Наука',
  };

  @override
  void initState() {
    super.initState();
    levelIndex = widget.initialIndex;
    if (widget.levels != null) {
      levels = widget.levels;
      session = GameSession(levels![levelIndex]);
    } else {
      load();
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
    });
  }

  void switchLevel(int index) => setState(() {
    levelIndex = index % levels!.length;
    session = GameSession(levels![levelIndex]);
    gesture.clear();
    lastPointer = null;
    pointerStart = null;
    activePointer = null;
    dragging = false;
    dragConsumed = false;
    victoryShown = false;
    stopwatch.reset();
    message = null;
  });

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

  void finish() {
    if (gesture.isEmpty) return;
    final result = session!.submit(List.of(gesture));
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
      victoryShown = true;
      stopwatch.stop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onCompleted?.call(
            context,
            session!.level,
            math.max(1, stopwatch.elapsed.inSeconds),
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
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xff080e24)
          : const Color(0xffe7f2ff),
      appBar: AppBar(
        backgroundColor: const Color(0xff121b3a),
        foregroundColor: const Color(0xffe9faff),
        title: Text('${worldNames[level.worldId]} · ${level.id}'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Начать уровень заново',
            onPressed: () => switchLevel(levelIndex),
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: SafeArea(
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
                        child: Text(
                          'Найдено ${session!.foundCount} из ${level.words.length}   ·   Тест ${levelIndex + 1} из ${levels!.length}',
                          style: const TextStyle(fontSize: 15),
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
                      Text(
                        message ?? 'Проведите или нажимайте на соседние буквы',
                        key: const Key('status-message'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: session!.completed
                              ? const Color(0xff69e5a2)
                              : Colors.white70,
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
                                  Chip(
                                    label: Text(
                                      word.text,
                                      style: TextStyle(
                                        fontSize: 13,
                                        decoration: session!.isFound(word.text)
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                    backgroundColor: session!.isFound(word.text)
                                        ? const Color(0xff234750)
                                        : const Color(0xff252d41),
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
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: gesture.isEmpty
                                  ? null
                                  : clearSelection,
                              child: const Text('Сбросить выбор'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              child: const Text('На главную'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
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
  });
  final FilwordLevel level;
  final List<FoundPath> found;
  final List<int> active;
  final bool light;
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
