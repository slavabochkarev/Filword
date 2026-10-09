"""Readable PNG previews and a self-contained local HTML index."""
from __future__ import annotations

from pathlib import Path
import argparse
import html
import json

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
COLORS = ["#e63946", "#457b9d", "#2a9d8f", "#f4a261", "#9b5de5",
          "#e76f51", "#00a6a6", "#c77dff", "#ffb703", "#7a9e2d",
          "#d0006f", "#4361ee", "#b56576", "#087e8b"]


def font(size: int, bold: bool = False):
    candidates = [Path(r"C:\Windows\Fonts\arialbd.ttf" if bold else r"C:\Windows\Fonts\arial.ttf"),
                  Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")]
    for path in candidates:
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def draw_level(level: dict, output: Path, diagnostic: bool) -> None:
    image = Image.new("RGB", (1220, 900), "#ffffff")
    draw = ImageDraw.Draw(image)
    draw.text((50, 22), f"{level['worldId']}  •  Уровень {level['id']}",
              font=font(29, True), fill="#202a36")
    status = level.get("diagnostics", {}).get("candidateStatus", "candidate")
    draw.text((50, 65), f"{'Проверочная схема' if diagnostic else 'Игровое поле'}  |  {status}",
              font=font(19), fill="#56616e")
    x0, y0, step = 50, 120, 68
    if diagnostic:
        for index, item in enumerate(level["words"]):
            color = COLORS[index % len(COLORS)]
            points = [(x0 + c * step + step / 2, y0 + r * step + step / 2)
                      for r, c in item["path"]]
            for cx, cy in points:
                draw.rounded_rectangle((cx-step/2+4, cy-step/2+4,
                                        cx+step/2-4, cy+step/2-4), radius=8,
                                       fill=color)
            if len(points) > 1:
                draw.line(points, fill="#202a36", width=3, joint="curve")
    for r, row in enumerate(level["grid"]):
        for c, letter in enumerate(row):
            box = (x0+c*step, y0+r*step, x0+(c+1)*step, y0+(r+1)*step)
            if not diagnostic:
                draw.rectangle(box, fill="#f8fafc")
            draw.rectangle(box, outline="#aeb8c3", width=1)
            cx, cy = x0+c*step+step/2, y0+r*step+step/2
            draw.text((cx, cy+3), letter, anchor="mm", font=font(31, True),
                      fill="#ffffff" if diagnostic else "#17212b", stroke_width=1 if diagnostic else 0,
                      stroke_fill="#17212b")
    if diagnostic:
        for item in level["words"]:
            sr, sc = item["path"][0]
            er, ec = item["path"][-1]
            draw.text((x0+sc*step+7, y0+sr*step+4), "S", font=font(16, True),
                      fill="#ffffff", stroke_width=2, stroke_fill="#17212b")
            draw.text((x0+ec*step+step-19, y0+er*step+step-23), "E", font=font(16, True),
                      fill="#ffffff", stroke_width=2, stroke_fill="#17212b")
    draw.text((770, 118), "Искомые слова", font=font(25, True), fill="#202a36")
    for index, item in enumerate(level["words"]):
        y = 165 + index * 43
        if diagnostic:
            draw.rectangle((770, y+7, 790, y+27), fill=COLORS[index % len(COLORS)])
        label = f"{index+1:02d}. {item['text']} ({len(item['text'])})"
        draw.text((805 if diagnostic else 770, y), label, font=font(19), fill="#202a36")
    metrics = level.get("diagnostics", {})
    draw.text((50, 825), f"Слов: {len(level['words'])}   Поворотов: {metrics.get('turns', '?')}   "
              f"Альтернативных путей: {metrics.get('alternative_paths', '?')}",
              font=font(18), fill="#46515d")
    output.parent.mkdir(parents=True, exist_ok=True)
    image.save(output)


def render(output: Path) -> None:
    levels = json.loads((output / "candidates.json").read_text(encoding="utf-8"))
    cards = []
    for level in levels:
        stem = f"{level['id']:03d}_{level['worldId']}"
        game = f"png/{stem}_A.png"
        check = f"png/{stem}_B.png"
        draw_level(level, output / game, False)
        draw_level(level, output / check, True)
        metrics = level.get("diagnostics", {})
        cards.append(f"<article><h3>{level['id']:03d} · {html.escape(level['worldId'])}</h3>"
                     f"<p>{len(level['words'])} слов · {metrics.get('turns', '?')} поворотов · "
                     f"{metrics.get('alternative_paths', '?')} альтернатив · "
                     f"<strong>{html.escape(metrics.get('candidateStatus', 'candidate'))}</strong></p>"
                     f"<a href='{game}'><img src='{game}' alt='Игровое поле'></a>"
                     f"<a href='{check}'><img src='{check}' alt='Проверочная схема'></a></article>")
    page = """<!doctype html><html lang='ru'><meta charset='utf-8'><meta name='viewport' content='width=device-width'>
<title>Филворд — экспериментальная галерея</title><style>
body{font:16px system-ui,sans-serif;background:#e9edf1;color:#1e2a36;margin:24px}
header{max-width:1400px;margin:auto}main{max-width:1400px;margin:auto;display:grid;grid-template-columns:repeat(auto-fit,minmax(430px,1fr));gap:18px}
article{background:white;padding:14px;border-radius:10px;box-shadow:0 2px 9px #0002}article img{width:49%;vertical-align:top;border:1px solid #ccd5dd}
h3{margin:0}p{margin:7px 0 12px}a+a{margin-left:1%}</style>
<header><h1>Филворд — 80 экспериментальных кандидатов</h1><p>Слева поле игрока, справа проверочная схема. Цвета и метки S/E показывают сохранённые пути. Статус strict_pass означает только автоматическую проверку; редакторская оценка не проведена.</p></header><main>""" + "\n".join(cards) + "</main></html>"
    (output / "gallery.html").write_text(page, encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=ROOT / "output")
    args = parser.parse_args()
    render(args.output)
