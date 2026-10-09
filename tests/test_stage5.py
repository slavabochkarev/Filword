import json
import random
import unittest
from collections import Counter
from pathlib import Path

from tools.generate_stage5 import choose_words, make_level, pools, randomized_cover
from tools.validator_stage5 import SIZES, validate_collection, validate_level

ROOT = Path(__file__).resolve().parents[1]


class Stage5Tests(unittest.TestCase):
    def test_generated_collection_has_five_levels_per_size(self):
        levels = json.loads((ROOT / "output_stage5/candidates.json").read_text(encoding="utf-8"))
        thematic, general = pools()
        result = validate_collection(levels, {world: thematic[world] | general for world in SIZES})
        self.assertEqual(result["accepted_count"], 20)
        self.assertEqual(result["rejected_count"], 0)
        self.assertEqual(result["by_world"], {world: 5 for world in SIZES})
        for level in levels:
            self.assertEqual(level["gridSize"], SIZES[level["worldId"]])
            self.assertEqual(sum(map(len, (word["text"] for word in level["words"]))),
                             level["gridSize"] ** 2)

    def test_exact_cover_from_existing_word_pools(self):
        thematic, general = pools()
        for world, size in SIZES.items():
            rng = random.Random(size)
            words = choose_words(size, thematic[world], general, Counter(), rng)
            self.assertIsNotNone(words)
            self.assertEqual(sum(map(len, words)), size * size)
            level = make_level(size, world, words, randomized_cover(size, rng))
            self.assertEqual(validate_level(level, thematic[world] | general), [])

    def test_validator_detects_overlap_and_wrong_letters(self):
        level = json.loads((ROOT / "output_stage5/candidates.json").read_text(encoding="utf-8"))[0]
        duplicate = json.loads(json.dumps(level))
        duplicate["words"][1]["path"][0] = duplicate["words"][0]["path"][0]
        self.assertTrue(any("overlapping" in error for error in validate_level(duplicate)))
        wrong = json.loads(json.dumps(level))
        wrong["grid"][0] = "Я" + wrong["grid"][0][1:]
        self.assertTrue(any("letters do not spell" in error for error in validate_level(wrong)))

    def test_validator_requires_world_size_and_coverage(self):
        level = json.loads((ROOT / "output_stage5/candidates.json").read_text(encoding="utf-8"))[0]
        wrong = json.loads(json.dumps(level))
        wrong["gridSize"] = 8
        self.assertTrue(validate_level(wrong))
        missing = json.loads(json.dumps(level))
        missing["words"].pop()
        self.assertTrue(any("coverage" in error for error in validate_level(missing)))

    def test_duplicate_layout_rejected(self):
        level = json.loads((ROOT / "output_stage5/candidates.json").read_text(encoding="utf-8"))[0]
        copied = json.loads(json.dumps(level))
        copied["id"] = 2
        result = validate_collection([level, copied])
        self.assertEqual(result["rejected_count"], 1)
        self.assertIn("duplicate layout", result["levels"]["2"])


if __name__ == "__main__":
    unittest.main()
