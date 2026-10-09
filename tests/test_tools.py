import random
import unittest

from tools.generate import choose_words, randomized_cover
from tools.lexicon import normalize
from tools.validator import ADJ, alternate_paths, validate_collection, validate_level


def fixture(words=None):
    # Ten horizontal ten-letter paths cover the field exactly.
    rows = ["АБВГДЕЖЗИЙ"] * 10
    items = [{"id": f"w{r}", "text": row,
              "path": [[r, c] for c in range(10)]} for r, row in enumerate(rows)]
    return {"id": 1, "worldId": "cosmos", "grid": rows,
            "words": items if words is None else words}


class LexiconTests(unittest.TestCase):
    def test_normalize_yo_and_preserve_y_short(self):
        self.assertEqual(normalize(" ёжик "), "ЕЖИК")
        self.assertEqual(normalize("йод"), "ЙОД")

    def test_reject_symbols(self):
        self.assertIsNone(normalize("NASA"))
        self.assertIsNone(normalize("А-Б"))
        self.assertIsNone(normalize("А1Б"))


class GeneratorTests(unittest.TestCase):
    def test_cover_is_reproducible_and_complete(self):
        a = randomized_cover(random.Random(42))
        self.assertEqual(a, randomized_cover(random.Random(42)))
        self.assertEqual(set(a), set(range(100)))
        self.assertTrue(all(b in ADJ[x] for x, b in zip(a, a[1:])))

    def test_empty_dictionary_and_impossible_cover(self):
        from collections import Counter
        self.assertIsNone(choose_words(set(), random.Random(1), Counter()))
        self.assertIsNone(choose_words({"КОТ"}, random.Random(1), Counter()))


class ValidatorTests(unittest.TestCase):
    def test_complete_geometry(self):
        data = fixture()
        # Repeated target text is a separate defect; geometry itself covers 100.
        result = validate_level(data, {"АБВГДЕЖЗИЙ"}, check_alternatives=False)
        self.assertEqual(result["coverage"], 100)
        self.assertFalse(any("coverage" in x or "overlap" in x for x in result["defects"]))

    def test_bad_grid(self):
        data = fixture()
        data["grid"][0] = "ABC"
        self.assertIn("grid", validate_level(data)["defects"][0])

    def test_repeated_cell(self):
        data = fixture()
        data["words"][0]["path"][1] = [0, 0]
        result = validate_level(data, check_alternatives=False)
        self.assertTrue(any("repeated cell" in x for x in result["defects"]))

    def test_overlap(self):
        data = fixture()
        data["words"][1]["path"][0] = [0, 0]
        result = validate_level(data, check_alternatives=False)
        self.assertTrue(any("overlap" in x for x in result["defects"]))

    def test_wrong_letter_and_discontinuity(self):
        data = fixture()
        data["words"][0]["text"] = "ББВГДЕЖЗИЙ"
        data["words"][0]["path"][1] = [9, 9]
        result = validate_level(data, check_alternatives=False)
        self.assertTrue(any("grid spells" in x for x in result["defects"]))
        self.assertTrue(any("discontinuous" in x for x in result["defects"]))

    def test_alternative_path(self):
        grid = ["А" * 10] * 10
        count, capped = alternate_paths(grid, "ААА", [0, 1, 2], cap=2)
        self.assertEqual(count, 2)
        self.assertTrue(capped)

    def test_duplicate_level_and_theme(self):
        one = fixture()
        two = fixture()
        two["id"] = 2
        result = validate_collection([one, two], {"cosmos": {"КОСМОС"}})
        self.assertTrue(any("duplicate layout" in x for x in result["levels"]["2"]["defects"]))
        self.assertTrue(any("off-theme" in x for x in result["levels"]["1"]["defects"]))


if __name__ == "__main__":
    unittest.main()
