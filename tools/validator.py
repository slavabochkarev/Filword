"""Independent validation of JSON levels, including alternate target paths."""
from __future__ import annotations

from collections import Counter
from hashlib import sha256
from pathlib import Path
import argparse
import json
import re

RUSSIAN = re.compile(r"^[А-Я]+$")


def neighbors(cell: int) -> list[int]:
    r, c = divmod(cell, 10)
    return [nr * 10 + nc for nr in range(max(0, r-1), min(9, r+1)+1)
            for nc in range(max(0, c-1), min(9, c+1)+1) if (nr, nc) != (r, c)]


ADJ = [neighbors(i) for i in range(100)]


def path_ids(path: list) -> list[int]:
    if not isinstance(path, list):
        raise ValueError("path is not a list")
    result = []
    for point in path:
        if not (isinstance(point, list) and len(point) == 2 and
                all(isinstance(v, int) and not isinstance(v, bool) for v in point) and
                all(0 <= v < 10 for v in point)):
            raise ValueError(f"invalid coordinate: {point!r}")
        result.append(point[0] * 10 + point[1])
    return result


def alternate_paths(grid: list[str], word: str, canonical: list[int], cap: int = 20) -> tuple[int, bool]:
    """Count paths other than canonical, stopping at cap. Return (count, truncated)."""
    flat = "".join(grid)
    if len(flat) != 100 or not word:
        return 0, False
    count = 0
    def walk(cell: int, index: int, used: int, path: list[int]) -> None:
        nonlocal count
        if count >= cap:
            return
        if index == len(word) - 1:
            if path != canonical:
                count += 1
            return
        target = word[index + 1]
        for nxt in ADJ[cell]:
            bit = 1 << nxt
            if not used & bit and flat[nxt] == target:
                walk(nxt, index + 1, used | bit, path + [nxt])
                if count >= cap:
                    return
    for start, letter in enumerate(flat):
        if letter == word[0]:
            walk(start, 0, 1 << start, [start])
            if count >= cap:
                break
    return count, count >= cap


def validate_level(level: dict, allowed: set[str] | None = None,
                   check_alternatives: bool = True) -> dict:
    defects: list[str] = []
    grid = level.get("grid")
    if not isinstance(grid, list) or len(grid) != 10 or any(
            not isinstance(row, str) or len(row) != 10 or not RUSSIAN.fullmatch(row)
            for row in grid):
        return {"defects": ["grid must be 10 rows of 10 Russian uppercase letters"],
                "alternative_paths": 0, "alternative_paths_capped": False}
    flat = "".join(grid)
    words = level.get("words")
    if not isinstance(words, list) or not words:
        return {"defects": ["words must be a nonempty list"],
                "alternative_paths": 0, "alternative_paths_capped": False}
    occupied: set[int] = set()
    text_seen: set[str] = set()
    alternatives = 0
    capped = False
    for index, item in enumerate(words):
        prefix = f"word[{index}]"
        if not isinstance(item, dict):
            defects.append(f"{prefix}: not an object")
            continue
        word = item.get("text")
        if not isinstance(word, str) or not RUSSIAN.fullmatch(word) or not 3 <= len(word) <= 12:
            defects.append(f"{prefix}: invalid text")
            continue
        if word in text_seen:
            defects.append(f"{prefix}: duplicate target text {word}")
        text_seen.add(word)
        if allowed is not None and word not in allowed:
            defects.append(f"{prefix}: off-theme or unapproved word {word}")
        try:
            path = path_ids(item.get("path"))
        except ValueError as exc:
            defects.append(f"{prefix}: {exc}")
            continue
        if len(path) != len(word):
            defects.append(f"{prefix}: path length differs from text")
            continue
        if len(set(path)) != len(path):
            defects.append(f"{prefix}: repeated cell")
        if any(b not in ADJ[a] for a, b in zip(path, path[1:])):
            defects.append(f"{prefix}: discontinuous path")
        overlap = occupied.intersection(path)
        if overlap:
            defects.append(f"{prefix}: overlap at {sorted(overlap)}")
        occupied.update(path)
        spelled = "".join(flat[cell] for cell in path)
        if spelled != word:
            defects.append(f"{prefix}: grid spells {spelled}, expected {word}")
        if check_alternatives and spelled == word and len(set(path)) == len(path):
            count, hit_cap = alternate_paths(grid, word, path)
            alternatives += count
            capped |= hit_cap
            if count:
                defects.append(f"{prefix}: {count}+ alternative path(s)" if hit_cap else
                               f"{prefix}: {count} alternative path(s)")
    if occupied != set(range(100)):
        defects.append(f"coverage: {len(occupied)}/100 unique cells")
    return {"defects": defects, "alternative_paths": alternatives,
            "alternative_paths_capped": capped, "coverage": len(occupied)}


def fingerprint(level: dict) -> str:
    """Layout identity ignoring level ID and ordering of the word list."""
    value = {"grid": level.get("grid"), "words": sorted(
        [(w.get("text"), w.get("path")) for w in level.get("words", [])],
        key=lambda item: (str(item[0]), str(item[1])))}
    return sha256(json.dumps(value, ensure_ascii=False, sort_keys=True).encode()).hexdigest()


def validate_collection(levels: list[dict], lexicon: dict[str, set[str]]) -> dict:
    defects = {}
    seen = {}
    seen_ids = set()
    ranges = {"neon_city": (1, 100), "cosmos": (101, 200),
              "biosphere": (201, 300), "cybercore": (301, 400)}
    for level in levels:
        ident = level.get("id", "?")
        world = level.get("worldId")
        result = validate_level(level, lexicon.get(world, set()))
        if world not in lexicon:
            result["defects"].append(f"unknown world: {world}")
        if ident in seen_ids:
            result["defects"].append(f"duplicate level ID: {ident}")
        seen_ids.add(ident)
        if world in ranges and not (isinstance(ident, int) and
                                    ranges[world][0] <= ident <= ranges[world][1]):
            result["defects"].append(f"level ID {ident} outside {world} range")
        fp = fingerprint(level)
        if fp in seen:
            result["defects"].append(f"duplicate layout of level {seen[fp]}")
        seen[fp] = ident
        if result["defects"]:
            defects[str(ident)] = result
    return {"level_count": len(levels), "defective_count": len(defects), "levels": defects}


if __name__ == "__main__":
    from .lexicon import load
    parser = argparse.ArgumentParser()
    parser.add_argument("levels", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    levels = json.loads(args.levels.read_text(encoding="utf-8"))
    result = validate_collection(levels, load())
    encoded = json.dumps(result, ensure_ascii=False, indent=2)
    if args.output:
        args.output.write_text(encoded + "\n", encoding="utf-8")
    print(json.dumps({"level_count": result["level_count"],
                      "defective_count": result["defective_count"]}))
