"""Independent Stage 3 acceptance gate: geometry and pool, alternatives warn."""
from __future__ import annotations

from collections import Counter
from pathlib import Path
import argparse
import json

from .lexicon import THEMES
from .lexicon_stage3 import build as build_pools
from .validator import alternate_paths, fingerprint, validate_level


def validate_collection_stage3(levels: list[dict], thematic: dict[str, set[str]],
                               general: set[str], reuse_limit: int = 2) -> dict:
    seen_layouts: dict[str, int] = {}
    seen_ids: set[int] = set()
    usage = Counter()
    results = {}
    ranges = {world: (i * 100 + 1, i * 100 + 100) for i, world in enumerate(THEMES)}
    for level in levels:
        ident = level.get("id", "?")
        world = level.get("worldId")
        allowed = thematic.get(world, set()) | general
        core = validate_level(level, allowed, check_alternatives=False)
        errors = core["defects"][:]
        warnings = []
        if world not in thematic:
            errors.append(f"unknown world: {world}")
        if ident in seen_ids:
            errors.append(f"duplicate ID: {ident}")
        seen_ids.add(ident)
        if world in ranges and not (isinstance(ident, int) and
                                    ranges[world][0] <= ident <= ranges[world][1]):
            errors.append(f"ID outside world range: {ident}")
        fp = fingerprint(level)
        if fp in seen_layouts:
            errors.append(f"duplicate layout of level {seen_layouts[fp]}")
        seen_layouts[fp] = ident
        anchors = sum(w.get("text") in thematic.get(world, set())
                      for w in level.get("words", []) if isinstance(w, dict))
        if anchors < 3:
            errors.append(f"only {anchors} thematic anchors; need 3")
        alternatives = 0
        capped = False
        if not core["defects"]:
            for item in level["words"]:
                canonical = [r * 10 + c for r, c in item["path"]]
                count, hit_cap = alternate_paths(level["grid"], item["text"], canonical, cap=20)
                alternatives += count
                capped |= hit_cap
            if alternatives:
                warnings.append(f"{alternatives}{'+' if capped else ''} alternative target paths")
        for item in level.get("words", []):
            if isinstance(item, dict) and isinstance(item.get("text"), str):
                word = item["text"]
                usage[word] += 1
                if usage[word] > reuse_limit:
                    errors.append(f"word {word} used {usage[word]} times; limit {reuse_limit}")
        results[str(ident)] = {"errors": errors, "warnings": warnings,
                               "alternative_paths": alternatives,
                               "alternatives_capped": capped, "coverage": core.get("coverage", 0),
                               "theme_anchors": anchors}
    return {"level_count": len(levels),
            "accepted_count": sum(not x["errors"] for x in results.values()),
            "rejected_count": sum(bool(x["errors"]) for x in results.values()),
            "warning_count": sum(bool(x["warnings"]) for x in results.values()),
            "global_unique_words": len(usage),
            "max_word_uses": max(usage.values(), default=0),
            "levels": results}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("levels", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    thematic, general, _ = build_pools()
    levels = json.loads(args.levels.read_text(encoding="utf-8"))
    result = validate_collection_stage3(levels, thematic, general)
    if args.output:
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n",
                               encoding="utf-8")
    print(json.dumps({k: result[k] for k in ("level_count", "accepted_count",
                                              "rejected_count", "warning_count")}))
