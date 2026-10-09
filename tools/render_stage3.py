"""Two PNGs per level plus an offline playable HTML gallery."""
from __future__ import annotations

from pathlib import Path
import argparse
import html
import json
import shutil

from .render import draw_level
from .validator import ADJ

ROOT = Path(__file__).resolve().parents[1]


def illustrative_alternative(level: dict, cap_per_word: int = 100) -> dict | None:
    flat = "".join(level["grid"])
    best = None
    best_divergence = -1
    for item in level["words"]:
        word = item["text"]
        canonical = [r * 10 + c for r, c in item["path"]]
        found = 0

        def walk(cell: int, index: int, used: int, path: list[int]) -> None:
            nonlocal best, best_divergence, found
            if found >= cap_per_word:
                return
            if index == len(word) - 1:
                if path != canonical:
                    found += 1
                    overlap = len(set(path) & set(canonical))
                    divergence = len(word) - overlap
                    if divergence > best_divergence:
                        best_divergence = divergence
                        best = {"word": word, "path": path[:],
                                "canonical": canonical, "sharedCells": overlap,
                                "length": len(word)}
                return
            for nxt in ADJ[cell]:
                bit = 1 << nxt
                if not used & bit and flat[nxt] == word[index + 1]:
                    walk(nxt, index + 1, used | bit, path + [nxt])
                    if found >= cap_per_word:
                        return

        for start, letter in enumerate(flat):
            if letter == word[0]:
                walk(start, 0, 1 << start, [start])
            if found >= cap_per_word:
                break
    return best


def render(output: Path) -> dict:
    levels = json.loads((output / "candidates.json").read_text(encoding="utf-8"))
    examples = {}
    cards = []
    options = []
    for level in levels:
        ident = level["id"]
        stem = f"{ident:03d}_{level['worldId']}"
        game = f"png/{stem}_A.png"
        check = f"png/{stem}_B.png"
        draw_level(level, output / game, False)
        draw_level(level, output / check, True)
        example = illustrative_alternative(level)
        if example:
            examples[str(ident)] = example
        diagnostics = level["diagnostics"]
        options.append(f"<option value='{ident}'>{ident:03d} · {html.escape(level['worldId'])}</option>")
        cards.append(f"<article class='card' data-level='{ident}'><h3>{ident:03d} · "
                     f"{html.escape(level['worldId'])}</h3><p>{len(level['words'])} слов · "
                     f"{diagnostics['turns']} поворотов · {diagnostics['alternative_paths']} альтернатив</p>"
                     f"<a href='{game}' target='_blank'><img src='{game}' alt='Игровое поле'></a>"
                     f"<a href='{check}' target='_blank'><img src='{check}' alt='Проверочная схема'></a>"
                     f"<button class='open-level' data-id='{ident}'>Играть на этом поле</button></article>")
    payload = json.dumps({"levels": levels, "examples": examples}, ensure_ascii=False).replace("</", "<\\/")
    page = """<!doctype html><html lang='ru'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width'>
<title>Филворд — интерактивная галерея этапа 3</title><style>
*{box-sizing:border-box}body{font:16px system-ui,sans-serif;margin:0;background:#eef2f5;color:#172431}
header,main{max-width:1450px;margin:auto;padding:20px}header h1{margin:0 0 8px}header p{max-width:1100px;line-height:1.4}
.play{background:white;border-radius:12px;padding:18px;box-shadow:0 2px 12px #0002;position:relative}
.toolbar{display:flex;flex-wrap:wrap;gap:10px;align-items:center;margin-bottom:12px}.toolbar select,.toolbar button,.open-level{font:inherit;padding:8px 11px;border:1px solid #8798a9;background:#fff;border-radius:7px;cursor:pointer}
.toolbar button:hover,.open-level:hover{background:#e3f1ff}.game-layout{display:flex;flex-wrap:wrap;gap:20px}.board{display:grid;grid-template-columns:repeat(10,minmax(0,1fr));width:min(100%,600px);aspect-ratio:1;touch-action:none;user-select:none;flex:none;border:1px solid #aab6c2}
.cell{display:flex;align-items:center;justify-content:center;aspect-ratio:1;border:1px solid #bdc7d0;background:#f8fafc;font-size:clamp(15px,2vw,29px);font-weight:700;position:relative}
.cell.found{background:var(--found);color:#fff;text-shadow:0 1px 2px #0009}.cell.gesture{outline:4px solid #04b9df;outline-offset:-5px;z-index:2}.cell.last{box-shadow:inset 0 0 0 4px #05afd2;z-index:1}
.side{min-width:250px;flex:1}.word-list{columns:2;list-style:none;padding:0;margin:0}.word-list li{break-inside:avoid;margin:0 0 8px}.word-list li.done{text-decoration:line-through;color:#55736b}
.status{min-height:56px;padding:10px;margin:12px 0;border-left:5px solid #5784ae;background:#eaf2f9;line-height:1.4}.status.ok{border-color:#2c9b67;background:#e9f8ef}.status.bad{border-color:#c85858;background:#fff0f0}
.legend{font-size:14px;color:#465665;line-height:1.4}.gallery{display:grid;grid-template-columns:repeat(auto-fit,minmax(365px,1fr));gap:16px;margin-top:22px}.card{background:#fff;padding:13px;border-radius:10px;box-shadow:0 2px 9px #0002}.card h3{margin:0}.card p{margin:6px 0}.card img{width:49%;border:1px solid #d1dae2}.card a+a{margin-left:1%}.open-level{display:block;margin-top:9px}
@media(max-width:690px){header,main{padding:12px}.board{width:100%}.word-list{columns:2}.gallery{grid-template-columns:1fr}.cell{font-size:clamp(12px,4.2vw,22px)}}
</style></head><body><header><h1>Филворд — эксперимент этапа 3</h1><p>Выберите поле и проведите мышью или пальцем по соседним клеткам. Допускаются диагонали и повороты. Принятое слово остаётся подсвеченным по <b>заранее записанному пути</b>. Голубой контур показывает ваш жест; сравните оба пути кнопкой «Показать последний жест».</p><p><a href='../output/gallery.html'>Галерея этапа 2</a> · Все 80 уровней экспериментальные и ожидают редакторского просмотра.</p></header>
<main><section class='play'><div class='toolbar'><label>Уровень <select id='level-select'>""" + "".join(options) + """</select></label><button id='reset'>Сбросить найденные</button><button id='demo'>Показать альтернативный жест</button><button id='last'>Показать последний жест</button><span id='progress'></span></div>
<div class='game-layout'><div id='board' class='board' aria-label='Поле 10 на 10'></div><div class='side'><h2>Искомые слова</h2><ul id='word-list' class='word-list'></ul><div id='status' class='status'>Проведите по буквам, чтобы составить слово.</div><p class='legend'>После успешного жеста голубой контур временно показывает фактически выбранные клетки, цветная заливка — канонический путь уровня. При несовпадении путей это отмечается в сообщении. Повторное слово не засчитывается.</p></div></div></section>
<section class='gallery' id='gallery'>""" + "".join(cards) + """</section></main>
<script id='level-data' type='application/json'>""" + payload + """</script><script src='gallery.js'></script></body></html>"""
    (output / "gallery.html").write_text(page, encoding="utf-8")
    shutil.copyfile(ROOT / "tools/gallery_stage3.js", output / "gallery.js")
    (output / "alternative_examples.json").write_text(
        json.dumps(examples, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return examples


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=ROOT / "output_stage3")
    args = parser.parse_args()
    examples = render(args.output)
    print(f"Rendered {len(examples)} illustrative alternatives")
