"""Extend the existing stage-5 candidate set without changing its first 20 levels."""
from __future__ import annotations

from collections import Counter, defaultdict
from pathlib import Path
import argparse
import json
import random
import statistics
import time

from tools.generate_stage5 import choose_words, make_level, pools, randomized_cover, turns
from tools.lexicon import THEMES
from tools.validator_stage5 import SIZES, fingerprint, validate_collection, validate_level


def bend_count(level: dict) -> int:
    size = level["gridSize"]
    return sum(turns([r * size + c for r, c in word["path"]], size)
               for word in level["words"])


def word_set(level: dict) -> frozenset[str]:
    return frozenset(word["text"] for word in level["words"])


def prefix_collision(words: list[str]) -> bool:
    return any(a != b and b.startswith(a) for a in words for b in words)


def run(project: Path, output: Path, seed: int, attempts_per_level: int,
        seconds_per_world: float, original_path: Path | None = None) -> dict:
    original_bytes = (original_path or project / "assets/levels.json").read_bytes()
    original = json.loads(original_bytes)
    thematic, general = pools()
    expected = {world: [i * 100 + n for n in range(1, 6)]
                for i, world in enumerate(THEMES)}
    actual = {world: sorted(level["id"] for level in original
                            if level["worldId"] == world) for world in THEMES}
    if len(original) != 20 or actual != expected:
        raise ValueError(f"Unexpected original levels: {actual}")
    if validate_collection(original)["rejected_count"]:
        raise ValueError("Original levels failed structural validation")

    levels = list(original)
    usage = Counter(word["text"] for level in original for word in level["words"])
    seen_layouts = {fingerprint(level) for level in original}
    seen_sets = {word_set(level) for level in original}
    report = {"seed": seed, "original_sha256": __import__("hashlib").sha256(original_bytes).hexdigest(),
              "original_count": len(original), "worlds": {}}
    for world_index, world in enumerate(THEMES):
        size = SIZES[world]
        rng = random.Random(seed + world_index * 1000003)
        started = time.monotonic()
        attempts = 0
        rejected = Counter()
        new_levels = []
        old_world = [level for level in original if level["worldId"] == world]
        base_turns = bend_count(old_world[-1])
        for local_number in range(6, 21):
            best = None
            best_score = float("inf")
            for _ in range(attempts_per_level):
                if time.monotonic() - started >= seconds_per_world:
                    rejected["time_limit"] += 1
                    break
                attempts += 1
                words = choose_words(size, thematic[world], general, usage, rng,
                                     reuse_limit=2)
                if words is None:
                    rejected["word_pool_or_exact_sum"] += 1
                    break
                if prefix_collision(words):
                    rejected["prefix_collision"] += 1
                    continue
                path = randomized_cover(size, rng, moves=100 + local_number * 40)
                candidate = make_level(size, world, words, path)
                if validate_level(candidate, thematic[world] | general):
                    rejected["structural"] += 1
                    continue
                if fingerprint(candidate) in seen_layouts:
                    rejected["duplicate_layout"] += 1
                    continue
                if word_set(candidate) in seen_sets:
                    rejected["duplicate_word_set"] += 1
                    continue
                bends = bend_count(candidate)
                repeats = sum(usage[word] > 0 for word in words)
                target = base_turns + (local_number - 5) * 1.2
                score = repeats * 2 + abs(bends - target) * .35
                if score < best_score:
                    best, best_score = candidate, score
                    best["diagnostics"] = {
                        "turns": bends,
                        "repeated_words_from_prior_levels": repeats,
                        "theme_anchor_count": sum(word in thematic[world] for word in words),
                        "word_count": len(words),
                        "word_lengths": [len(word) for word in words],
                    }
            if best is None:
                rejected["no_candidate_for_slot"] += 1
                break
            best["id"] = world_index * 100 + local_number
            best["difficulty"] = round(min(.98, .49 + (local_number - 5) * .031), 3)
            levels.append(best)
            new_levels.append(best)
            seen_layouts.add(fingerprint(best))
            seen_sets.add(word_set(best))
            usage.update(word["text"] for word in best["words"])
        report["worlds"][world] = {
            "gridSize": size, "old": len(old_world), "added": len(new_levels),
            "attempts": attempts, "rejected": dict(rejected),
            "seconds": round(time.monotonic() - started, 2),
            "mean_turns_old": round(statistics.mean(map(bend_count, old_world)), 2),
            "mean_turns_new": round(statistics.mean(map(bend_count, new_levels)), 2)
            if new_levels else None,
        }
    levels.sort(key=lambda item: item["id"])
    result = validate_collection(levels,
        {world: thematic[world] | general for world in THEMES})
    report["validation"] = result
    report["total_levels"] = len(levels)
    report["unique_words"] = len(usage)
    report["word_repetition"] = dict(sorted(Counter(usage.values()).items()))
    report["word_lengths"] = dict(sorted(Counter(len(word["text"])
        for level in levels for word in level["words"]).items()))
    report["mean_words_per_level"] = round(statistics.mean(len(level["words"])
        for level in levels), 2)
    report["theme_anchors_total"] = sum(sum(word["text"] in thematic[level["worldId"]]
        for word in level["words"]) for level in levels)
    output.mkdir(parents=True, exist_ok=True)
    (output / "levels.json").write_text(json.dumps(levels, ensure_ascii=False,
        indent=2) + "\n", encoding="utf-8")
    (output / "report.json").write_text(json.dumps(report, ensure_ascii=False,
        indent=2) + "\n", encoding="utf-8")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--original", type=Path,
                        help="Original 20-level JSON; defaults to project assets/levels.json")
    parser.add_argument("--seed", type=int, default=20261010)
    parser.add_argument("--attempts-per-level", type=int, default=40)
    parser.add_argument("--seconds-per-world", type=float, default=90)
    args = parser.parse_args()
    outcome = run(args.project, args.output, args.seed,
                  args.attempts_per_level, args.seconds_per_world, args.original)
    print(json.dumps({"count": outcome["total_levels"],
        "added": {k: v["added"] for k, v in outcome["worlds"].items()},
        "validation_rejected": outcome["validation"]["rejected_count"]},
        ensure_ascii=False))
    raise SystemExit(outcome["total_levels"] != 80 or
                     outcome["validation"]["rejected_count"] != 0)
