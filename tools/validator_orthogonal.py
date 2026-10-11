"""Independent validation of the four-direction game levels.

Historical stage-2 through stage-5 validators retain their original rules.
"""
from __future__ import annotations

from collections import Counter
from hashlib import sha256
import argparse
import json
from pathlib import Path
import re

SIZES = {"neon_city": 7, "cosmos": 8, "biosphere": 9, "cybercore": 10}
LETTERS = re.compile(r"^[А-Я]+$")


def adjacent(a: int, b: int, size: int) -> bool:
    return (0 <= a < size * size and 0 <= b < size * size and
            abs(a // size - b // size) + abs(a % size - b % size) == 1)


def fingerprint(level: dict) -> str:
    payload = {"size": level.get("gridSize"), "grid": level.get("grid"),
               "words": sorted((word.get("text"), word.get("path"))
                               for word in level.get("words", [])
                               if isinstance(word, dict))}
    return sha256(json.dumps(payload, ensure_ascii=False, sort_keys=True).encode()).hexdigest()


def validate_level(level: dict) -> list[str]:
    errors: list[str] = []
    size = level.get("gridSize")
    if type(size) is not int or size not in (7, 8, 9, 10):
        return ["gridSize must be 7, 8, 9 or 10"]
    world = level.get("worldId")
    if SIZES.get(world) != size:
        errors.append("world/gridSize mismatch")
    grid = level.get("grid")
    if (not isinstance(grid, list) or len(grid) != size or
            any(not isinstance(row, str) or len(row) != size or
                not LETTERS.fullmatch(row) for row in grid)):
        return errors + ["invalid grid letters or dimensions"]
    words = level.get("words")
    if not isinstance(words, list) or not words:
        return errors + ["missing words"]
    flat = "".join(grid)
    occupied: set[int] = set()
    seen_words: set[str] = set()
    for i, item in enumerate(words):
        prefix = f"word[{i}]"
        if not isinstance(item, dict):
            errors.append(f"{prefix}: invalid item")
            continue
        word, path = item.get("text"), item.get("path")
        if not isinstance(word, str) or not LETTERS.fullmatch(word) or not 3 <= len(word) <= 12:
            errors.append(f"{prefix}: invalid word")
            continue
        if word in seen_words:
            errors.append(f"{prefix}: duplicate word")
        seen_words.add(word)
        if (not isinstance(path, list) or
                any(not isinstance(p, list) or len(p) != 2 or
                    any(type(v) is not int or not 0 <= v < size for v in p)
                    for p in path)):
            errors.append(f"{prefix}: invalid coordinates")
            continue
        cells = [row * size + col for row, col in path]
        if len(cells) != len(word):
            errors.append(f"{prefix}: word/path length mismatch")
        if len(set(cells)) != len(cells):
            errors.append(f"{prefix}: repeated cell")
        if any(not adjacent(a, b, size) for a, b in zip(cells, cells[1:])):
            errors.append(f"{prefix}: diagonal or disconnected step")
        if occupied.intersection(cells):
            errors.append(f"{prefix}: overlapping canonical paths")
        occupied.update(cells)
        if "".join(flat[cell] for cell in cells) != word:
            errors.append(f"{prefix}: path spells wrong word")
    if len(occupied) != size * size:
        errors.append(f"coverage {len(occupied)}/{size * size}")
    return errors


def validate_collection(levels: list[dict], original: list[dict] | None = None) -> dict:
    expected = {item["id"]: item for item in original} if original else {}
    seen_ids: set[int] = set()
    seen_layouts: set[str] = set()
    per_level: dict[str, list[str]] = {}
    for level in levels:
        ident = level.get("id")
        defects = validate_level(level)
        if ident in seen_ids:
            defects.append("duplicate ID")
        seen_ids.add(ident)
        signature = fingerprint(level)
        if signature in seen_layouts:
            defects.append("duplicate layout")
        seen_layouts.add(signature)
        if original is not None:
            source = expected.get(ident)
            if source is None:
                defects.append("ID absent from original")
            elif (source.get("worldId") != level.get("worldId") or
                  source.get("gridSize") != level.get("gridSize") or
                  Counter(w["text"] for w in source["words"]) !=
                  Counter(w["text"] for w in level.get("words", []))):
                defects.append("world, size or word set changed")
        per_level[str(ident)] = defects
    if original is not None and seen_ids != set(expected):
        per_level["collection"] = ["level ID set changed"]
    return {"level_count": len(levels),
            "accepted_count": sum(not defects for key, defects in per_level.items()
                                  if key != "collection"),
            "rejected_count": sum(bool(defects) for defects in per_level.values()),
            "by_world": dict(Counter(level.get("worldId") for level in levels)),
            "defects": {key: value for key, value in per_level.items() if value}}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("levels", type=Path)
    parser.add_argument("--original", type=Path)
    args = parser.parse_args()
    current = json.loads(args.levels.read_text(encoding="utf-8"))
    original = (json.loads(args.original.read_text(encoding="utf-8"))
                if args.original else None)
    result = validate_collection(current, original)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    raise SystemExit(bool(result["rejected_count"]))
