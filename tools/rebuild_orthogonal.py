"""Re-layout all 80 existing levels without changing IDs or target words."""
from __future__ import annotations

from collections import Counter
from hashlib import sha256
from pathlib import Path
import argparse
import json
import random
import statistics

from tools.validator_orthogonal import adjacent, fingerprint, validate_collection


def orthogonal_cover(size: int, rng: random.Random, steps: int) -> list[int]:
    # A row snake is a Hamiltonian path. Backbite moves preserve that property
    # while producing turns and varied word geometry without DFS dead ends.
    path = [row * size + col for row in range(size)
            for col in (range(size) if row % 2 == 0 else range(size - 1, -1, -1))]
    if rng.randrange(2):
        path = [col * size + row for row in range(size)
                for col in (range(size) if row % 2 == 0 else range(size - 1, -1, -1))]
    for _ in range(steps):
        if rng.randrange(2):
            path.reverse()
        head = path[0]
        options = [index for index, cell in enumerate(path)
                   if index > 1 and adjacent(head, cell, size)]
        if options:
            cut = rng.choice(options)
            path = path[:cut][::-1] + path[cut:]
    if rng.randrange(2):
        path.reverse()
    return path


def turns(cells: list[int], size: int) -> int:
    direction = [(b // size - a // size, b % size - a % size)
                 for a, b in zip(cells, cells[1:])]
    return sum(a != b for a, b in zip(direction, direction[1:]))


def re_layout(source: dict, path: list[int]) -> tuple[dict, int, int]:
    size = source["gridSize"]
    flat = [""] * (size * size)
    words = []
    offset = total_turns = maximum_turns = 0
    for old in source["words"]:
        word = old["text"]
        cells = path[offset:offset + len(word)]
        offset += len(word)
        for cell, letter in zip(cells, word):
            flat[cell] = letter
        item = dict(old)
        item["path"] = [[cell // size, cell % size] for cell in cells]
        words.append(item)
        bend = turns(cells, size)
        total_turns += bend
        maximum_turns = max(maximum_turns, bend)
    if offset != size * size:
        raise ValueError(f"Level {source['id']}: target lengths cover {offset}/{size * size}")
    result = dict(source)
    result["grid"] = ["".join(flat[i:i + size])
                      for i in range(0, size * size, size)]
    result["words"] = words
    result["diagnostics"] = {
        **source.get("diagnostics", {}),
        "pathRule": "four-direction",
        "turns": total_turns,
        "maximumWordTurns": maximum_turns,
        "word_count": len(words),
        "word_lengths": [len(word["text"]) for word in words],
    }
    return result, total_turns, maximum_turns


def run(source_path: Path, output: Path, seed: int = 20261011,
        candidates_per_level: int = 32) -> dict:
    source_bytes = source_path.read_bytes()
    original = json.loads(source_bytes)
    if len(original) != 80:
        raise ValueError("Expected the existing 80-level collection")
    chosen = []
    seen = set()
    by_world: dict[str, list[int]] = {}
    for old in original:
        size, ident = old["gridSize"], old["id"]
        local = ident % 100
        rng = random.Random(seed + ident * 1000003)
        target_turns = size * size * (.22 + .20 * (local - 1) / 19)
        steps = size * size * (2 + local // 3)
        best = None
        best_score = float("inf")
        for _ in range(candidates_per_level):
            cover = orthogonal_cover(size, rng, steps)
            candidate, bends, max_word_bends = re_layout(old, cover)
            signature = fingerprint(candidate)
            if signature in seen or signature == fingerprint(old):
                continue
            score = abs(bends - target_turns) + max(0, max_word_bends - 6) * 2
            if score < best_score:
                best, best_score = candidate, score
        if best is None:
            raise RuntimeError(f"No unique orthogonal candidate for {ident}")
        chosen.append(best)
        seen.add(fingerprint(best))
        by_world.setdefault(old["worldId"], []).append(best["diagnostics"]["turns"])
    validation = validate_collection(chosen, original)
    if validation["rejected_count"]:
        raise ValueError(validation)
    report = {
        "seed": seed,
        "source_sha256": sha256(source_bytes).hexdigest(),
        "path_rule": "horizontal and vertical neighbors only; turns allowed",
        "candidates_per_level": candidates_per_level,
        "validation": validation,
        "unique_words": len({w["text"] for level in chosen for w in level["words"]}),
        "word_repetition": dict(sorted(Counter(Counter(
            w["text"] for level in chosen for w in level["words"]).values()).items())),
        "turns_by_world": {world: {"min": min(values), "max": max(values),
                                    "mean": round(statistics.mean(values), 2)}
                           for world, values in by_world.items()},
    }
    output.mkdir(parents=True, exist_ok=True)
    (output / "levels.json").write_text(
        json.dumps(chosen, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (output / "report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--seed", type=int, default=20261011)
    parser.add_argument("--candidates-per-level", type=int, default=32)
    args = parser.parse_args()
    result = run(args.source, args.output, args.seed, args.candidates_per_level)
    print(json.dumps({"levels": result["validation"]["level_count"],
                      "rejected": result["validation"]["rejected_count"],
                      "turns_by_world": result["turns_by_world"]},
                     ensure_ascii=False))
