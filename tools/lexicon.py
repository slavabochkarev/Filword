"""Reproducible, source-tracked experimental lexicon. No source files are edited."""
from __future__ import annotations

from collections import Counter
from hashlib import sha256
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
WORD_RE = re.compile(r"^[А-ЯЁ]+$")
THEMES = ("neon_city", "cosmos", "biosphere", "cybercore")


def normalize(raw: str) -> str | None:
    word = raw.strip().upper().replace("Ё", "Е")
    return word if WORD_RE.fullmatch(word) and 3 <= len(word) <= 12 else None


def read_words(path: Path) -> set[str]:
    return {word for line in path.read_text(encoding="utf-8-sig").splitlines()
            if not line.startswith("#") for token in line.split()
            if (word := normalize(token)) is not None}


def build() -> dict:
    sources = {
        "crossslow": DATA / "source/crossslow_game_words.txt",
        "harrix": DATA / "source/harrix_russian_nouns.txt",
        "sk4tzr": DATA / "source/sk4tzr_common_nouns.txt",
    }
    source_sets = {name: read_words(path) for name, path in sources.items()}
    forbidden = read_words(DATA / "source/crossslow_exclude.txt") | read_words(
        DATA / "source/crossslow_questionable.txt")
    entries: dict[str, dict] = {}
    theme_report = {}
    for theme in THEMES:
        path = DATA / "themes" / f"{theme}.txt"
        requested = read_words(path)
        accepted = sorted(word for word in requested if word not in forbidden and
                          (word in source_sets["crossslow"] or word in source_sets["harrix"]))
        rejected = sorted(requested - set(accepted))
        for word in accepted:
            entry = entries.setdefault(word, {"word": word, "themes": [], "sources": [],
                                             "status": "experimental"})
            entry["themes"].append(theme)
            entry["sources"] = [name for name, words in source_sets.items() if word in words]
        theme_report[theme] = {
            "listed": len(requested), "usable": len(accepted),
            "by_length": {str(n): sum(len(w) == n for w in accepted) for n in range(3, 13)},
            "rejected_from_source_or_policy": rejected,
        }
    payload = {
        "schemaVersion": 1,
        "policy": "uppercase; Ё→Е; Й retained; noun candidates; manual thematic shortlist",
        "sources": {name: {"file": str(path.relative_to(ROOT)).replace("\\", "/"),
                            "sha256": sha256(path.read_bytes()).hexdigest(),
                            "normalized_count_3_12": len(source_sets[name])}
                    for name, path in sources.items()},
        "words": [entries[word] for word in sorted(entries)],
    }
    (DATA / "experimental_lexicon.json").write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    report = {"themes": theme_report, "unique_experimental_words": len(entries),
              "status": "experimental, not editorially approved"}
    (DATA / "lexicon_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return report


def load() -> dict[str, set[str]]:
    source = DATA / "experimental_lexicon.json"
    if not source.exists():
        build()
    payload = json.loads(source.read_text(encoding="utf-8"))
    return {theme: {e["word"] for e in payload["words"] if theme in e["themes"]}
            for theme in THEMES}


if __name__ == "__main__":
    print(json.dumps(build(), ensure_ascii=False, indent=2))
