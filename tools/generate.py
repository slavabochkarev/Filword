"""Bounded reproducible experiment. All outputs remain experimental candidates."""
from __future__ import annotations

from collections import Counter
from functools import lru_cache
from itertools import combinations_with_replacement
from pathlib import Path
import argparse
import json
import random
import statistics
import time

from .lexicon import THEMES, build, load
from .validator import ADJ, alternate_paths, fingerprint, validate_collection, validate_level

ROOT = Path(__file__).resolve().parents[1]


@lru_cache(maxsize=32)
def length_templates(capacities: tuple[int, ...]) -> tuple[tuple[int, ...], ...]:
    options = []
    for count in range(10, 14):
        for lengths in combinations_with_replacement(range(7, 13), count):
            if sum(lengths) == 100 and all(lengths.count(n) <= capacities[n-7]
                                           for n in range(7, 13)):
                options.append(lengths)
    return tuple(options)


def choose_words(pool: set[str], rng: random.Random, usage: Counter,
                 desired: int | None = None) -> list[str] | None:
    by_length = {n: [w for w in sorted(pool) if len(w) == n] for n in range(7, 13)}
    templates = length_templates(tuple(len(by_length[n]) for n in range(7, 13)))
    if desired is not None:
        templates = tuple(t for t in templates if len(t) == desired)
    if not templates:
        return None
    lengths = rng.choice(templates)
    picked = []
    used = set()
    for n in lengths:
        options = [w for w in by_length[n] if w not in used]
        weights = [1.0 / (1 + usage[w])**2 for w in options]
        word = rng.choices(options, weights=weights)[0]
        picked.append(word)
        used.add(word)
    rng.shuffle(picked)
    return picked


def randomized_cover(rng: random.Random, moves: int = 1000) -> list[int]:
    path = [r * 10 + c for r in range(10)
            for c in (range(10) if r % 2 == 0 else range(9, -1, -1))]
    for _ in range(moves):
        i = rng.randrange(1, 97)
        j = rng.randrange(i + 1, 99)
        if path[j] in ADJ[path[i-1]] and path[i] in ADJ[path[j+1]]:
            path[i:j+1] = reversed(path[i:j+1])
    if rng.randrange(2):
        path.reverse()
    return path


def turns(path: list[int]) -> int:
    directions = [(b//10-a//10, b%10-a%10) for a, b in zip(path, path[1:])]
    return sum(a != b for a, b in zip(directions, directions[1:]))


def make_level(words: list[str], world: str, path: list[int], rng: random.Random) -> dict:
    flat = [""] * 100
    items = []
    offset = 0
    for index, word in enumerate(words):
        segment = path[offset:offset + len(word)]
        offset += len(word)
        for cell, letter in zip(segment, word):
            flat[cell] = letter
        items.append({"id": f"w{index + 1}", "text": word,
                      "path": [[cell // 10, cell % 10] for cell in segment],
                      "colorId": index})
    return {"schemaVersion": 1, "id": 0, "worldId": world,
            "difficulty": 0.0,
            "grid": ["".join(flat[i:i+10]) for i in range(0, 100, 10)],
            "words": items}


def quick_metrics(level: dict, alt_cap: int = 2) -> dict:
    alternatives = 0
    ambiguous_words = 0
    bend_count = 0
    for item in level["words"]:
        path = [r * 10 + c for r, c in item["path"]]
        bend_count += turns(path)
        count, _ = alternate_paths(level["grid"], item["text"], path, cap=alt_cap)
        alternatives += count
        ambiguous_words += int(count > 0)
    return {"alternative_paths_lower_bound": alternatives,
            "ambiguous_words": ambiguous_words, "turns": bend_count,
            "word_count": len(level["words"]),
            "word_lengths": [len(w["text"]) for w in level["words"]]}


def _score(level: dict, metrics: dict, usage: Counter) -> tuple:
    repeat = sum(usage[w["text"]] for w in level["words"])
    return (metrics["ambiguous_words"], metrics["alternative_paths_lower_bound"],
            repeat, -metrics["turns"])


def run(seed: int, per_world: int, attempts_per_level: int,
        seconds_per_world: float, output: Path) -> dict:
    build()
    lexicon = load()
    output.mkdir(parents=True, exist_ok=True)
    all_levels = []
    report = {"seed": seed, "per_world_requested": per_world,
              "attempts_per_level_limit": attempts_per_level,
              "seconds_per_world_limit": seconds_per_world,
              "worlds": {}, "status": "experimental candidates; no editorial approval"}
    for world_index, world in enumerate(THEMES):
        rng = random.Random(seed + 1000003 * world_index)
        usage = Counter()
        seen = set()
        world_levels = []
        reasons = Counter()
        start = time.monotonic()
        attempts = 0
        geometry_valid = 0
        strict_valid = 0
        generation_times = []
        for slot in range(per_world):
            if time.monotonic() - start >= seconds_per_world:
                reasons["time_limit"] += 1
                break
            best = None
            best_metrics = None
            best_score = None
            for _ in range(attempts_per_level):
                if time.monotonic() - start >= seconds_per_world:
                    reasons["time_limit"] += 1
                    break
                tick = time.monotonic()
                attempts += 1
                words = choose_words(lexicon[world], rng, usage)
                if words is None:
                    reasons["impossible_word_lengths"] += 1
                    continue
                candidate = make_level(words, world, randomized_cover(rng), rng)
                structural = validate_level(candidate, lexicon[world], check_alternatives=False)
                if structural["defects"]:
                    reasons["structural_defect"] += 1
                    continue
                geometry_valid += 1
                fp = fingerprint(candidate)
                if fp in seen:
                    reasons["duplicate"] += 1
                    continue
                metrics = quick_metrics(candidate)
                generation_times.append(time.monotonic() - tick)
                if metrics["ambiguous_words"] == 0:
                    strict_valid += 1
                score = _score(candidate, metrics, usage)
                if best_score is None or score < best_score:
                    best, best_metrics, best_score = candidate, metrics, score
                if metrics["ambiguous_words"] == 0 and len(generation_times) >= 5:
                    break
            if best is None:
                reasons["no_candidate_in_slot"] += 1
                break
            best["id"] = world_index * 100 + slot + 1
            full = validate_level(best, lexicon[world], check_alternatives=True)
            best_metrics.update({"alternative_paths": full["alternative_paths"],
                                 "alternatives_capped": full["alternative_paths_capped"],
                                 "defects": full["defects"],
                                 "candidateStatus": "strict_pass" if not full["defects"] else "review_rejected"})
            # A rough progression measure, stored for inspection rather than treated as calibrated difficulty.
            best["difficulty"] = round(min(1, (slot / max(1, per_world - 1)) * .5 +
                                            best_metrics["turns"] / 100 * .5), 3)
            best["diagnostics"] = best_metrics
            world_levels.append(best)
            all_levels.append(best)
            seen.add(fingerprint(best))
            usage.update(w["text"] for w in best["words"])
        report["worlds"][world] = {
            "attempts": attempts, "geometry_valid": geometry_valid,
            "strict_valid_attempts": strict_valid,
            "alternative_path_rejections": geometry_valid - strict_valid - reasons["duplicate"],
            "selected_candidates": len(world_levels),
            "strict_pass_selected": sum(not x["diagnostics"]["defects"] for x in world_levels),
            "rejected_selected": sum(bool(x["diagnostics"]["defects"]) for x in world_levels),
            "reasons": dict(reasons),
            "seconds": round(time.monotonic() - start, 3),
            "mean_attempt_seconds": round(statistics.mean(generation_times), 4) if generation_times else None,
            "alternative_paths_selected": sum(x["diagnostics"]["alternative_paths"] for x in world_levels),
            "mean_words": round(statistics.mean(x["diagnostics"]["word_count"] for x in world_levels), 2)
                          if world_levels else None,
            "mean_turns": round(statistics.mean(x["diagnostics"]["turns"] for x in world_levels), 2)
                          if world_levels else None,
            "unique_words_used": len(usage), "most_repeated_words": usage.most_common(10),
            "word_lengths": dict(sorted(Counter(n for x in world_levels for n in
                                                 x["diagnostics"]["word_lengths"]).items())),
            "difficulty_range": [min((x["difficulty"] for x in world_levels), default=None),
                                 max((x["difficulty"] for x in world_levels), default=None)],
            "difficulty_buckets": {label: sum(bounds[0] <= x["difficulty"] < bounds[1]
                                               for x in world_levels)
                                   for label, bounds in {"low": (0, .33), "medium": (.33, .66),
                                                         "high": (.66, 1.01)}.items()},
            "theme_accuracy": "shortlist membership 100%; semantic/editorial accuracy unreviewed",
        }
    collection = validate_collection(all_levels, lexicon)
    report["collection_validation"] = collection
    (output / "candidates.json").write_text(json.dumps(all_levels, ensure_ascii=False, indent=2)+"\n",
                                             encoding="utf-8")
    (output / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n",
                                        encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=20261009)
    parser.add_argument("--per-world", type=int, default=20)
    parser.add_argument("--attempts-per-level", type=int, default=25)
    parser.add_argument("--seconds-per-world", type=float, default=120)
    parser.add_argument("--output", type=Path, default=ROOT / "output")
    args = parser.parse_args()
    report = run(args.seed, args.per_world, args.attempts_per_level,
                 args.seconds_per_world, args.output)
    print(json.dumps({w: {k: v for k, v in data.items() if k in
                           ("attempts", "selected_candidates", "strict_pass_selected", "seconds")}
                      for w, data in report["worlds"].items()}, ensure_ascii=False))


if __name__ == "__main__":
    main()
