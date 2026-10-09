"""Stage 3 experiment, reusing Stage 2's full-cover path construction."""
from __future__ import annotations

from collections import Counter
from pathlib import Path
import argparse
import json
import random
import statistics
import time

from .generate import make_level, quick_metrics, randomized_cover
from .lexicon import THEMES
from .lexicon_stage3 import build as build_pools
from .validator import alternate_paths, fingerprint, validate_level
from .validator_stage3 import validate_collection_stage3

ROOT = Path(__file__).resolve().parents[1]


def _pick(options: list[str], usage: Counter, rng: random.Random) -> str:
    weights = [4 if usage[word] == 0 else 1 for word in options]
    return rng.choices(options, weights=weights)[0]


def choose_mixed_words(theme: set[str], general: set[str], usage: Counter,
                       rng: random.Random, reuse_limit: int = 2) -> list[str] | None:
    anchors = []
    eligible_theme = sorted(w for w in theme if usage[w] < reuse_limit)
    if len(eligible_theme) < 3:
        return None
    for _ in range(3):
        word = _pick([w for w in eligible_theme if w not in anchors], usage, rng)
        anchors.append(word)
    remainder = 100 - sum(map(len, anchors))
    choices = [(six, seven) for six in range(17) for seven in range(17)
               if 6 * six + 7 * seven == remainder and
               11 <= 3 + six + seven <= 16]
    rng.shuffle(choices)
    for six, seven in choices:
        by_length = {n: sorted(w for w in general if len(w) == n and
                               usage[w] < reuse_limit and w not in anchors)
                     for n in (6, 7)}
        if len(by_length[6]) < six or len(by_length[7]) < seven:
            continue
        selected = anchors.copy()
        for n, count in ((6, six), (7, seven)):
            for _ in range(count):
                word = _pick([w for w in by_length[n] if w not in selected], usage, rng)
                selected.append(word)
        rng.shuffle(selected)
        return selected
    return None


def _full_alternatives(level: dict) -> tuple[int, int, bool]:
    total = 0
    ambiguous = 0
    capped = False
    for item in level["words"]:
        canonical = [r * 10 + c for r, c in item["path"]]
        count, hit_cap = alternate_paths(level["grid"], item["text"], canonical, cap=20)
        total += count
        ambiguous += int(count > 0)
        capped |= hit_cap
    return total, ambiguous, capped


def _score(metrics: dict, usage: Counter, words: list[str]) -> float:
    repeats = sum(usage[word] > 0 for word in words)
    # Longer, heavily turning paths are harder to trace on a phone. Alternatives
    # remain diagnostic but a mild penalty avoids the most confusing boards.
    return (8 * repeats + 2 * max(0, metrics["turns"] - 38) +
            1.5 * max(0, metrics["word_count"] - 14) +
            .3 * metrics["alternative_paths_lower_bound"])


def run(seed: int, per_world: int, attempts_per_level: int,
        seconds_per_world: float, output: Path) -> dict:
    thematic, general, pool_report = build_pools()
    output.mkdir(parents=True, exist_ok=True)
    levels = []
    usage = Counter()
    seen = set()
    report = {"seed": seed, "per_world_requested": per_world,
              "attempts_per_level_limit": attempts_per_level,
              "seconds_per_world_limit": seconds_per_world,
              "policy": "any adjacent path spelling an unfound target is accepted; canonical path is highlighted",
              "pool": pool_report, "worlds": {}}
    for world_index, world in enumerate(THEMES):
        rng = random.Random(seed + 1000003 * world_index)
        started = time.monotonic()
        attempts = 0
        structurally_valid = 0
        rejected = Counter()
        times = []
        world_levels = []
        for slot in range(per_world):
            if time.monotonic() - started >= seconds_per_world:
                rejected["time_limit"] += 1
                break
            best = None
            best_metrics = None
            best_score = float("inf")
            for _ in range(attempts_per_level):
                if time.monotonic() - started >= seconds_per_world:
                    rejected["time_limit"] += 1
                    break
                tick = time.monotonic()
                attempts += 1
                words = choose_mixed_words(thematic[world], general, usage, rng)
                if words is None:
                    rejected["word_pool_or_exact_sum"] += 1
                    continue
                level = make_level(words, world, randomized_cover(rng, moves=600), rng)
                structural = validate_level(level, thematic[world] | general,
                                            check_alternatives=False)
                if structural["defects"]:
                    rejected["structural"] += 1
                    continue
                structurally_valid += 1
                if fingerprint(level) in seen:
                    rejected["duplicate"] += 1
                    continue
                metrics = quick_metrics(level)
                times.append(time.monotonic() - tick)
                score = _score(metrics, usage, words)
                if score < best_score:
                    best, best_metrics, best_score = level, metrics, score
            if best is None:
                rejected["no_candidate_for_slot"] += 1
                break
            best["id"] = world_index * 100 + slot + 1
            alternatives, ambiguous_words, capped = _full_alternatives(best)
            repeats = sum(usage[w["text"]] > 0 for w in best["words"])
            best_metrics.update({
                "alternative_paths": alternatives,
                "ambiguous_words": ambiguous_words,
                "alternatives_capped": capped,
                "theme_anchor_count": sum(w["text"] in thematic[world] for w in best["words"]),
                "repeated_words_from_prior_levels": repeats,
                "candidateStatus": "structural_pass_editorial_pending",
                "warnings": (["alternative target paths"] if alternatives else []),
                "defects": [],
            })
            best["difficulty"] = round(min(1.0, .25 * slot / max(1, per_world - 1) +
                                            .5 * best_metrics["turns"] / 70 +
                                            .25 * (best_metrics["word_count"] - 10) / 6), 3)
            best["diagnostics"] = best_metrics
            levels.append(best)
            world_levels.append(best)
            seen.add(fingerprint(best))
            usage.update(w["text"] for w in best["words"])
        world_words = [w["text"] for level in world_levels for w in level["words"]]
        counts = Counter(world_words)
        report["worlds"][world] = {
            "attempts": attempts, "structurally_valid_attempts": structurally_valid,
            "selected": len(world_levels), "rejections": dict(rejected),
            "elapsed_seconds": round(time.monotonic() - started, 3),
            "mean_attempt_seconds": round(statistics.mean(times), 4) if times else None,
            "mean_word_length": round(statistics.mean(map(len, world_words)), 3) if world_words else None,
            "mean_word_count": round(statistics.mean(len(x["words"]) for x in world_levels), 2)
                               if world_levels else None,
            "mean_turns": round(statistics.mean(x["diagnostics"]["turns"] for x in world_levels), 2)
                          if world_levels else None,
            "alternative_paths": sum(x["diagnostics"]["alternative_paths"] for x in world_levels),
            "ambiguous_words": sum(x["diagnostics"]["ambiguous_words"] for x in world_levels),
            "total_word_placements": len(world_words), "unique_words": len(counts),
            "repeated_placements": len(world_words) - len(counts),
            "max_word_uses": max(counts.values(), default=0),
            "word_lengths": dict(sorted(Counter(map(len, world_words)).items())),
            "difficulty_range": [min((x["difficulty"] for x in world_levels), default=None),
                                 max((x["difficulty"] for x in world_levels), default=None)],
            "theme_anchors_per_level": [x["diagnostics"]["theme_anchor_count"]
                                         for x in world_levels],
        }
    validation = validate_collection_stage3(levels, thematic, general)
    report["validation"] = validation
    report["total_attempts"] = sum(x["attempts"] for x in report["worlds"].values())
    report["total_selected"] = len(levels)
    report["global_unique_words"] = len(usage)
    report["global_max_word_uses"] = max(usage.values(), default=0)
    (output / "candidates.json").write_text(json.dumps(levels, ensure_ascii=False, indent=2)+"\n",
                                             encoding="utf-8")
    (output / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n",
                                        encoding="utf-8")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=20261009)
    parser.add_argument("--per-world", type=int, default=20)
    parser.add_argument("--attempts-per-level", type=int, default=30)
    parser.add_argument("--seconds-per-world", type=float, default=45)
    parser.add_argument("--output", type=Path, default=ROOT / "output_stage3")
    args = parser.parse_args()
    data = run(args.seed, args.per_world, args.attempts_per_level,
               args.seconds_per_world, args.output)
    print(json.dumps({world: {"attempts": info["attempts"],
                              "selected": info["selected"]}
                      for world, info in data["worlds"].items()}, ensure_ascii=False))
