"""Stage 3 pools: a few thematic anchors plus CrossSlow's curated common words."""
from __future__ import annotations

from collections import Counter
from pathlib import Path
import json

from .lexicon import DATA, THEMES, build as build_stage2, load as load_stage2, read_words


def build() -> tuple[dict[str, set[str]], set[str], dict]:
    build_stage2()
    thematic = {world: {w for w in words if 8 <= len(w) <= 12}
                for world, words in load_stage2().items()}
    crossslow = read_words(DATA / "source/crossslow_game_words.txt")
    common_source = read_words(DATA / "source/sk4tzr_common_nouns.txt")
    forbidden = read_words(DATA / "source/crossslow_exclude.txt") | read_words(
        DATA / "source/crossslow_questionable.txt")
    # CrossSlow's production game words are already filtered. Require a second
    # common-word source as well; five-letter answers are not needed in this run.
    general = {w for w in crossslow & common_source - forbidden if len(w) in (6, 7)}
    report = {
        "policy": "3 thematic anchors (8-12 letters) per level; remaining words from the "
                  "CrossSlow game list intersected with sk4tzR (6-7 letters); max 2 uses per word",
        "provenance": {
            "thematic": "stage2 experimental_lexicon.json; manual theme shortlist; Harrix/CrossSlow source tags",
            "general": "copied CrossSlow game_words.txt intersected with copied sk4tzR list; exclusions applied",
        },
        "general_count": len(general),
        "general_by_length": dict(Counter(map(len, general))),
        "thematic_count": {world: len(words) for world, words in thematic.items()},
        "thematic_by_length": {world: dict(Counter(map(len, words)))
                               for world, words in thematic.items()},
        "editorial_status": "experimental; no independent manual review completed",
    }
    (DATA / "stage3_pool_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return thematic, general, report


if __name__ == "__main__":
    print(json.dumps(build()[2], ensure_ascii=False, indent=2))
