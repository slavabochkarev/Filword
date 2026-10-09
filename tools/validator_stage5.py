"""Independent structural validation for 7–10 square Filword levels."""
from __future__ import annotations

from collections import Counter
from hashlib import sha256
import argparse
import json
from pathlib import Path
import re

from .lexicon import THEMES

LETTERS = re.compile(r"^[А-Я]+$")
SIZES = dict(zip(THEMES, (7, 8, 9, 10)))


def neighbors(cell: int, size: int) -> list[int]:
    row, col = divmod(cell, size)
    return [r * size + c for r in range(max(0, row - 1), min(size - 1, row + 1) + 1)
            for c in range(max(0, col - 1), min(size - 1, col + 1) + 1)
            if (r, c) != (row, col)]


def fingerprint(level: dict) -> str:
    value = {"size": level.get("gridSize"), "grid": level.get("grid"),
             "words": sorted((item.get("text"), item.get("path"))
                             for item in level.get("words", []) if isinstance(item, dict))}
    return sha256(json.dumps(value, ensure_ascii=False, sort_keys=True).encode()).hexdigest()


def validate_level(level: dict, allowed: set[str] | None = None) -> list[str]:
    errors = []
    size = level.get("gridSize")
    if size not in (7, 8, 9, 10) or type(size) is not int:
        return ["gridSize must be 7, 8, 9 or 10"]
    world = level.get("worldId")
    if world not in SIZES or SIZES[world] != size:
        errors.append(f"world {world} requires gridSize {SIZES.get(world)}")
    grid = level.get("grid")
    if not isinstance(grid, list) or len(grid) != size or any(
            not isinstance(row, str) or len(row) != size or not LETTERS.fullmatch(row)
            for row in grid):
        return errors + [f"grid must contain {size} rows of {size} uppercase Russian letters"]
    words = level.get("words")
    if not isinstance(words, list) or not words:
        return errors + ["words must be nonempty"]
    flat = "".join(grid)
    occupied = set()
    seen_words = set()
    for index, item in enumerate(words):
        prefix = f"word[{index}]"
        if not isinstance(item, dict):
            errors.append(f"{prefix}: not an object")
            continue
        word, path = item.get("text"), item.get("path")
        if not isinstance(word, str) or not LETTERS.fullmatch(word) or not 3 <= len(word) <= 12:
            errors.append(f"{prefix}: invalid text")
            continue
        if word in seen_words:
            errors.append(f"{prefix}: repeated target {word}")
        seen_words.add(word)
        if allowed is not None and word not in allowed:
            errors.append(f"{prefix}: word not in approved experimental pool: {word}")
        if not isinstance(path, list) or not all(
                isinstance(p, list) and len(p) == 2 and all(type(v) is int and 0 <= v < size for v in p)
                for p in path):
            errors.append(f"{prefix}: invalid path coordinates")
            continue
        cells = [r * size + c for r, c in path]
        if len(cells) != len(word):
            errors.append(f"{prefix}: path length differs from word")
        if len(set(cells)) != len(cells):
            errors.append(f"{prefix}: repeated cell")
        if any(b not in neighbors(a, size) for a, b in zip(cells, cells[1:])):
            errors.append(f"{prefix}: discontinuous path")
        overlap = occupied.intersection(cells)
        if overlap:
            errors.append(f"{prefix}: overlapping cells {sorted(overlap)}")
        occupied.update(cells)
        if "".join(flat[cell] for cell in cells) != word:
            errors.append(f"{prefix}: letters do not spell target")
    if len(occupied) != size * size:
        errors.append(f"coverage {len(occupied)}/{size * size}")
    return errors


def validate_collection(levels: list[dict], pools: dict[str, set[str]] | None = None) -> dict:
    seen_ids, seen_fingerprints = set(), set()
    results = {}
    for level in levels:
        ident = level.get("id")
        world = level.get("worldId")
        errors = validate_level(level, None if pools is None else pools.get(world, set()))
        if ident in seen_ids:
            errors.append("duplicate ID")
        seen_ids.add(ident)
        fp = fingerprint(level)
        if fp in seen_fingerprints:
            errors.append("duplicate layout")
        seen_fingerprints.add(fp)
        if world in THEMES and not (THEMES.index(world) * 100 + 1 <= ident <=
                                    THEMES.index(world) * 100 + 100):
            errors.append("ID outside world range")
        results[str(ident)] = errors
    return {"level_count": len(levels), "accepted_count": sum(not e for e in results.values()),
            "rejected_count": sum(bool(e) for e in results.values()), "levels": results,
            "by_world": dict(Counter(level.get("worldId") for level in levels))}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("levels", type=Path)
    args = parser.parse_args()
    data = json.loads(args.levels.read_text(encoding="utf-8"))
    result = validate_collection(data)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    raise SystemExit(bool(result["rejected_count"]))
