import json
import random
import unittest
from pathlib import Path

from tools.rebuild_orthogonal import orthogonal_cover, re_layout
from tools.validator_orthogonal import adjacent, validate_collection, validate_level

ROOT = Path(__file__).resolve().parents[1]


class OrthogonalLevelsTests(unittest.TestCase):
    def test_current_80_levels_preserve_every_word(self):
        levels = json.loads((ROOT / "assets/levels.json").read_text(encoding="utf-8"))
        old = json.loads((ROOT / "output_stage13/pre_orthogonal_levels.json")
                         .read_text(encoding="utf-8"))
        result = validate_collection(levels, old)
        self.assertEqual(result["accepted_count"], 80)
        self.assertEqual(result["rejected_count"], 0)

    def test_backbite_cover_is_reproducible_and_has_no_diagonals(self):
        for size in (7, 8, 9, 10):
            path = orthogonal_cover(size, random.Random(42), 400)
            self.assertEqual(path, orthogonal_cover(size, random.Random(42), 400))
            self.assertEqual(set(path), set(range(size * size)))
            self.assertTrue(all(adjacent(a, b, size) for a, b in zip(path, path[1:])))
            self.assertFalse(adjacent(0, size + 1, size))

    def test_validator_rejects_diagonal_and_wrong_letter(self):
        level = json.loads((ROOT / "assets/levels.json").read_text(encoding="utf-8"))[0]
        copy = json.loads(json.dumps(level))
        size = copy["gridSize"]
        start = copy["words"][0]["path"][0]
        diagonal = [start[0] + (1 if start[0] < size - 1 else -1),
                    start[1] + (1 if start[1] < size - 1 else -1)]
        copy["words"][0]["path"][1] = diagonal
        self.assertTrue(any("diagonal" in error for error in validate_level(copy)))
        copy = json.loads(json.dumps(level))
        row = copy["words"][0]["path"][0][0]
        col = copy["words"][0]["path"][0][1]
        letters = list(copy["grid"][row])
        letters[col] = "Я" if letters[col] != "Я" else "А"
        copy["grid"][row] = "".join(letters)
        self.assertTrue(any("wrong word" in error for error in validate_level(copy)))

    def test_relayout_preserves_words_and_full_coverage(self):
        old = json.loads((ROOT / "output_stage13/pre_orthogonal_levels.json")
                         .read_text(encoding="utf-8"))[0]
        path = orthogonal_cover(old["gridSize"], random.Random(7), 300)
        level, _, _ = re_layout(old, path)
        self.assertEqual(validate_level(level), [])
        self.assertEqual([w["text"] for w in level["words"]],
                         [w["text"] for w in old["words"]])


if __name__ == "__main__":
    unittest.main()
