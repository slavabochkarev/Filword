"""Stage 5 bounded generator: Stage 3 word pools and full-cover path, variable size."""
from __future__ import annotations

from collections import Counter
from itertools import combinations_with_replacement
from pathlib import Path
import argparse
import json
import random
import time

from .lexicon import DATA, THEMES, load, read_words
from .validator_stage5 import SIZES, fingerprint, neighbors, validate_collection, validate_level

ROOT = Path(__file__).resolve().parents[1]


def pools() -> tuple[dict[str, set[str]], set[str]]:
    thematic = {world: {word for word in words if 8 <= len(word) <= 12}
                for world, words in load().items()}
    crossslow = read_words(DATA / "source/crossslow_game_words.txt")
    common = read_words(DATA / "source/sk4tzr_common_nouns.txt")
    excluded = read_words(DATA / "source/crossslow_exclude.txt") | read_words(
        DATA / "source/crossslow_questionable.txt")
    general = {word for word in crossslow & common - excluded if len(word) in (6, 7)}
    return thematic, general


def choose_words(size: int, theme: set[str], general: set[str], usage: Counter,
                 rng: random.Random, reuse_limit: int = 2) -> list[str] | None:
    available = {n: sorted(word for word in theme if len(word) == n and usage[word] < reuse_limit)
                 for n in range(8, 13)}
    ordinary = {n: sorted(word for word in general if len(word) == n and usage[word] < reuse_limit)
                for n in (6, 7)}
    templates = []
    for lengths in combinations_with_replacement(range(8, 13), 3):
        if any(lengths.count(n) > len(available[n]) for n in set(lengths)):
            continue
        remainder = size * size - sum(lengths)
        for six in range(remainder // 6 + 1):
            rest = remainder - 6 * six
            if rest >= 0 and rest % 7 == 0:
                seven = rest // 7
                if six <= len(ordinary[6]) and seven <= len(ordinary[7]):
                    templates.append((lengths, six, seven))
    if not templates:
        return None
    lengths, six, seven = rng.choice(templates)
    selected = []
    for length in lengths:
        options = [word for word in available[length] if word not in selected]
        weights = [4 if usage[word] == 0 else 1 for word in options]
        selected.append(rng.choices(options, weights=weights)[0])
    for length, count in ((6, six), (7, seven)):
        for _ in range(count):
            options = [word for word in ordinary[length] if word not in selected]
            weights = [4 if usage[word] == 0 else 1 for word in options]
            selected.append(rng.choices(options, weights=weights)[0])
    rng.shuffle(selected)
    return selected


def randomized_cover(size: int, rng: random.Random, moves: int = 500) -> list[int]:
    path = [r * size + c for r in range(size)
            for c in (range(size) if r % 2 == 0 else range(size - 1, -1, -1))]
    if size * size < 4:
        return path
    adjacency = [set(neighbors(cell, size)) for cell in range(size * size)]
    for _ in range(moves):
        i = rng.randrange(1, size * size - 2)
        j = rng.randrange(i + 1, size * size - 1)
        if path[j] in adjacency[path[i - 1]] and path[i] in adjacency[path[j + 1]]:
            path[i:j + 1] = reversed(path[i:j + 1])
    if rng.randrange(2):
        path.reverse()
    return path


def make_level(size: int, world: str, words: list[str], path: list[int]) -> dict:
    flat = [""] * (size * size)
    items = []
    offset = 0
    for index, word in enumerate(words):
        segment = path[offset:offset + len(word)]
        offset += len(word)
        for cell, letter in zip(segment, word):
            flat[cell] = letter
        items.append({"id": f"w{index + 1}", "text": word,
                      "path": [[cell // size, cell % size] for cell in segment],
                      "colorId": index})
    return {"schemaVersion": 2, "gridSize": size, "id": 0, "worldId": world,
            "difficulty": 0.0, "grid": ["".join(flat[i:i + size])
                                         for i in range(0, size * size, size)],
            "words": items}


def turns(path: list[int], size: int) -> int:
    directions = [(b // size - a // size, b % size - a % size)
                  for a, b in zip(path, path[1:])]
    return sum(a != b for a, b in zip(directions, directions[1:]))


def run(seed: int = 20261009, per_world: int = 5, attempts_per_level: int = 12,
        seconds_per_world: float = 60, output: Path = ROOT / "output_stage5") -> dict:
    thematic, general = pools()
    output.mkdir(parents=True, exist_ok=True)
    levels = []
    usage = Counter()
    seen = set()
    report = {"seed": seed, "requested_per_world": per_world,
              "attempts_per_level_limit": attempts_per_level,
              "seconds_per_world_limit": seconds_per_world,
              "worlds": {}, "status": "structurally validated test levels; editorial review pending"}
    for world_index, world in enumerate(THEMES):
        size = SIZES[world]
        rng = random.Random(seed + world_index * 1000003)
        started = time.monotonic()
        attempts = 0
        rejected = Counter()
        selected = []
        for slot in range(per_world):
            best = None
            best_score = float("inf")
            for _ in range(attempts_per_level):
                if time.monotonic() - started >= seconds_per_world:
                    rejected["time_limit"] += 1
                    break
                attempts += 1
                words = choose_words(size, thematic[world], general, usage, rng)
                if words is None:
                    rejected["word_pool_or_exact_sum"] += 1
                    break
                path = randomized_cover(size, rng)
                level = make_level(size, world, words, path)
                defects = validate_level(level, thematic[world] | general)
                if defects:
                    rejected["structural"] += 1
                    continue
                if fingerprint(level) in seen:
                    rejected["duplicate"] += 1
                    continue
                bend_count = sum(turns([r * size + c for r, c in item["path"]], size)
                                 for item in level["words"])
                repeats = sum(usage[word] > 0 for word in words)
                score = repeats * 10 + bend_count / (size * size) * 3 + len(words) * .1
                if score < best_score:
                    best, best_score = level, score
                    best["diagnostics"] = {"turns": bend_count,
                                           "repeated_words_from_prior_levels": repeats,
                                           "theme_anchor_count": 3,
                                           "word_count": len(words),
                                           "word_lengths": [len(word) for word in words]}
            if best is None:
                rejected["no_candidate_for_slot"] += 1
                break
            best["id"] = world_index * 100 + slot + 1
            best["difficulty"] = round(min(1, .2 + slot * .04 +
                                            best["diagnostics"]["turns"] / (size * size) * .3), 3)
            selected.append(best)
            levels.append(best)
            seen.add(fingerprint(best))
            usage.update(item["text"] for item in best["words"])
        report["worlds"][world] = {"gridSize": size, "attempts": attempts,
                                    "selected": len(selected), "rejected": dict(rejected),
                                    "elapsed_seconds": round(time.monotonic() - started, 3)}
    report["validation"] = validate_collection(
        levels, {world: thematic[world] | general for world in THEMES})
    (output / "candidates.json").write_text(
        json.dumps(levels, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (output / "report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=20261009)
    parser.add_argument("--per-world", type=int, default=5)
    parser.add_argument("--attempts-per-level", type=int, default=12)
    parser.add_argument("--seconds-per-world", type=float, default=60)
    parser.add_argument("--output", type=Path, default=ROOT / "output_stage5")
    args = parser.parse_args()
    result = run(args.seed, args.per_world, args.attempts_per_level,
                 args.seconds_per_world, args.output)
    print(json.dumps({world: item["selected"] for world, item in result["worlds"].items()}))
    raise SystemExit(result["validation"]["rejected_count"] > 0 or
                     len(result["validation"]["levels"]) != args.per_world * 4)
