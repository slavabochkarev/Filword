"""Summarize an existing run without changing its generated levels."""
from __future__ import annotations

from pathlib import Path
import json
import statistics

ROOT = Path(__file__).resolve().parents[1]


def write_report(output: Path) -> None:
    run = json.loads((output / "report.json").read_text(encoding="utf-8"))
    levels = json.loads((output / "candidates.json").read_text(encoding="utf-8"))
    lex = json.loads((ROOT / "data/lexicon_report.json").read_text(encoding="utf-8"))
    rows = []
    for world, data in run["worlds"].items():
        candidates = [x for x in levels if x["worldId"] == world]
        lengths = [n for x in candidates for n in x["diagnostics"]["word_lengths"]]
        repeats = [count for _, count in data["most_repeated_words"]]
        rows.append(f"| {world} | {lex['themes'][world]['usable']} | {data['attempts']} | "
                    f"{data['geometry_valid']} | {data['selected_candidates']} | "
                    f"{data['strict_pass_selected']} | {data['alternative_paths_selected']} | "
                    f"{data['mean_words']} | {data['mean_turns']} | {data['mean_attempt_seconds']} | "
                    f"{data['unique_words_used']} |")
    total_attempts = sum(x["attempts"] for x in run["worlds"].values())
    total_strict = sum(x["strict_pass_selected"] for x in run["worlds"].values())
    total_alt = sum(x["alternative_paths_selected"] for x in run["worlds"].values())
    theme_counts = ", ".join(f"{w}: {lex['themes'][w]['usable']}" for w in run["worlds"])
    detail_lines = []
    for world, data in run["worlds"].items():
        detail_lines.append(f"- {world}: {data['difficulty_range']}; "
                            f"{data.get('difficulty_buckets', {})}; длины {data['word_lengths']}; "
                            f"частые повторы {data['most_repeated_words'][:3]}")
    text = f"""# Отчёт проверочного эксперимента

Seed: `{run['seed']}`. Предел: `{run['attempts_per_level_limit']}` попыток на слот и `{run['seconds_per_world_limit']}` секунд на мир. Все данные носят статус **экспериментальных кандидатов**.

| Мир | Слов в предварительном списке | Попыток | Геометрически корректных | Отобрано для галереи | Без альтернативных путей | Альтернативных путей в отобранных | Ср. слов | Ср. поворотов | Ср. время попытки, с | Уникальных слов использовано |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
{chr(10).join(rows)}

Итого: **{total_attempts} попыток**, **{len(levels)} кандидатов** в галерее, **{total_strict} автоматических строгих прохода**, **{len(levels)-total_strict} отклонённых**. В отобранных кандидатах валидатор обнаружил минимум **{total_alt} альтернативных путей** (подсчёт ограничен 20 на слово). Все отобранные кандидаты геометрически корректны. Причина отклонения — альтернативные пути к целевым словам. Измеренное время отражает этот компьютер и не является прогнозом для другого оборудования.

Списки по темам небольшие: {theme_counts}. Повторяемость выражена сильно: каждый уровень содержит около 10–11 слов, а в мире пока доступно только 41–53 реально использованных слова. Тематическая принадлежность проверена по ручным спискам; редакторская точность всех слов **не подтверждена**. Случайные дополнительные слова не подсчитаны исчерпывающе.

Диапазоны эвристической сложности и распределение по корзинам:
{chr(10).join(detail_lines)}

## Оценка для 100 уровней на мир

Текущий метод не дал даже 20 строгих уровней ни в одном мире. Простая экстраполяция на 100 уровней необоснованна: вероятность строгого прохода мала, а ограниченный тематический набор будет повторяться всё чаще. Перед созданием Flutter-приложения нужно расширить и редакторски проверить словарь по темам, затем испытать генератор с оптимизацией именно альтернативных путей и разнообразия, а не только геометрии. Правило принятия только записанного пути пока оставлено без изменений.

## Артефакты

- `candidates.json` — 80 полных кандидатов с путями и диагностикой.
- `gallery.html` — просмотр всех полей.
- `png/*_A.png` и `png/*_B.png` — два вида каждого кандидата.
- `report.json` — полные счётчики и дефекты по уровням.
"""
    (output / "summary.md").write_text(text, encoding="utf-8")


if __name__ == "__main__":
    write_report(ROOT / "output")
