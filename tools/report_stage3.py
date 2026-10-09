"""Compare saved Stage 2 and Stage 3 experiments without altering either run."""
from __future__ import annotations

from collections import Counter
from pathlib import Path
import json
import statistics

ROOT = Path(__file__).resolve().parents[1]


def _metric(levels: list[dict], world: str) -> dict:
    selected = [level for level in levels if level["worldId"] == world]
    texts = [word["text"] for level in selected for word in level["words"]]
    counts = Counter(texts)
    return {
        "count": len(selected),
        "mean_word_length": round(statistics.mean(map(len, texts)), 2),
        "mean_turns": round(statistics.mean(level["diagnostics"]["turns"]
                                            for level in selected), 2),
        "alternatives": sum(level["diagnostics"]["alternative_paths"]
                            for level in selected),
        "repeated_placements": len(texts) - len(counts),
        "unique_words": len(counts),
        "max_uses": max(counts.values(), default=0),
        "layouts": len({tuple(level["grid"]) for level in selected}),
    }


def write(output: Path) -> dict:
    old_levels = json.loads((ROOT / "output/candidates.json").read_text(encoding="utf-8"))
    old_report = json.loads((ROOT / "output/report.json").read_text(encoding="utf-8"))
    new_levels = json.loads((output / "candidates.json").read_text(encoding="utf-8"))
    new_report = json.loads((output / "report.json").read_text(encoding="utf-8"))
    examples = json.loads((output / "alternative_examples.json").read_text(encoding="utf-8"))
    worlds = list(new_report["worlds"])
    comparison = {world: {"stage2": _metric(old_levels, world),
                          "stage3": _metric(new_levels, world)} for world in worlds}
    old_attempts = sum(x["attempts"] for x in old_report["worlds"].values())
    old_seconds = sum(x["seconds"] for x in old_report["worlds"].values())
    new_attempts = new_report["total_attempts"]
    new_seconds = sum(x["elapsed_seconds"] for x in new_report["worlds"].values())
    overlap = [value["sharedCells"] / value["length"] for value in examples.values()]
    confusion = {
        "examples": len(examples),
        "mean_canonical_cell_overlap": round(statistics.mean(overlap), 3),
        "fully_disjoint_examples": sum(value == 0 for value in overlap),
        "quarter_or_less_overlap_examples": sum(value <= .25 for value in overlap),
        "method": "For each level choose the most spatially different alternative among up to 100 paths per word. This is a stress example, not a player probability.",
    }
    result = {"worlds": comparison,
              "stage2": {"attempts": old_attempts, "seconds": round(old_seconds, 3),
                         "strict_pass": sum(x["strict_pass_selected"]
                                            for x in old_report["worlds"].values())},
              "stage3": {"attempts": new_attempts, "seconds": round(new_seconds, 3),
                         "accepted": new_report["validation"]["accepted_count"],
                         "rejected": new_report["validation"]["rejected_count"],
                         "warnings": new_report["validation"]["warning_count"],
                         "global_unique_words": new_report["global_unique_words"],
                         "global_max_word_uses": new_report["global_max_word_uses"]},
              "confusion_probe": confusion}
    (output / "comparison.json").write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n",
                                               encoding="utf-8")
    rows = []
    for world, data in comparison.items():
        a, b = data["stage2"], data["stage3"]
        rows.append(f"| {world} | {a['mean_word_length']} → {b['mean_word_length']} | "
                    f"{a['mean_turns']} → {b['mean_turns']} | "
                    f"{a['alternatives']} → {b['alternatives']} | "
                    f"{a['repeated_placements']} → {b['repeated_placements']} | "
                    f"{a['unique_words']} → {b['unique_words']} |")
    text = f"""# Филворд — сравнение этапов 2 и 3

Этап 2 сохранён в `../output/`, новый эксперимент — в этой директории. Seed `20261009`; по 20 кандидатов на мир. **Условия принятия различаются:** этап 2 отвергал любую альтернативу, этап 3 принимает её как диагностическое предупреждение. Поэтому 2/80 → 80/80 не является улучшением геометрической части генератора.

| Мир | Средняя длина слова, 2 → 3 | Среднее число поворотов, 2 → 3 | Альтернативные пути, 2 → 3 | Повторные размещения слов, 2 → 3 | Уникальные слова, 2 → 3 |
|---|---:|---:|---:|---:|---:|
{chr(10).join(rows)}

## Выпуск кандидатов

- Этап 2: {old_attempts} попыток за {old_seconds:.1f} с; 80 отобрано, 2 прошли старый строгий критерий.
- Этап 3: {new_attempts} попыток за {new_seconds:.1f} с; 80 отобрано, 80 прошли структурный валидатор, 0 отклонено. Все 80 имеют предупреждение об альтернативных путях.
- В этапе 3 использовано {new_report['global_unique_words']} разных слов, ни одно не встречается более {new_report['global_max_word_uses']} раз во всей выборке. Каждый уровень имеет 3 тематических слова и общий пул из 1140 слов длиной 6–7.
- Время зависит от числа попыток, характеристик компьютера и новой политики; прямое отношение скоростей не оценивает качество одного и того же алгоритма.

## Риск путаницы из-за подсветки

Для каждого уровня найден демонстрационный альтернативный путь. Среди этих **намеренно контрастных** примеров {confusion['fully_disjoint_examples']} из {confusion['examples']} не имеют ни одной общей клетки с каноническим путём; у {confusion['quarter_or_less_overlap_examples']} совпадает не более четверти клеток. Средняя доля совпадающих клеток — {confusion['mean_canonical_cell_overlap']:.1%}. Это не вероятность поведения игрока, но реальный риск: слово принимается в одном месте, а постоянная подсветка появляется в другом.

Галерея показывает фактический жест голубым контуром на 3 секунды, канонический путь — постоянным цветом, и сообщает о различии. Кнопка «Показать последний жест» позволяет сравнить пути повторно. Нужна ручная проверка удобства на смартфоне и короткий пользовательский тест. Если различие вызывает устойчивую путаницу, перед Flutter следует выбрать другое правило постоянной подсветки или ограничить допустимые альтернативы по пространственному расхождению.

## Вывод

Новая механика технически устраняет главный блокирующий фильтр этапа 2 и позволяет построить 80 структурно корректных кандидатов. Контент остаётся экспериментальным: тематические списки не прошли полный редакторский просмотр, случайные нецелевые слова не оценены исчерпывающе, а интерактивный UX требует проверки человеком. Полноценную разработку Flutter рекомендую начинать после короткого теста галереи и решения, приемлема ли подсветка канонического пути при сильно отличающемся жесте.
"""
    (output / "comparison.md").write_text(text, encoding="utf-8")
    return result


if __name__ == "__main__":
    write(ROOT / "output_stage3")
