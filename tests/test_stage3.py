import random
import unittest
from collections import Counter
from pathlib import Path
import json

from tools.gameplay import Game
from tools.generate_stage3 import choose_mixed_words
from tools.validator_stage3 import validate_collection_stage3


def level_for_gestures():
    grid = ["А" * 10 for _ in range(10)]
    grid[0] = "КОТААААААА"
    grid[1] = "КОТААААААА"
    grid[2] = "ДАМААААААА"
    return {"id": 1, "worldId": "neon_city", "grid": grid,
            "words": [
                {"id": "w1", "text": "КОТ", "path": [[0, 0], [0, 1], [0, 2]]},
                {"id": "w2", "text": "ДАМА", "path": [[2, 0], [2, 1], [2, 2], [2, 3]]},
            ]}


class GameplayTests(unittest.TestCase):
    def test_alternative_path_accepted_canonical_highlight(self):
        game = Game(level_for_gestures())
        result = game.submit([10, 11, 12])
        self.assertEqual(result.text, "КОТ")
        self.assertTrue(result.valid_gesture)
        self.assertTrue(result.is_target)
        self.assertFalse(result.already_found)
        self.assertEqual(result.canonical_path, (0, 1, 2))
        self.assertFalse(result.completed)

    def test_diagonal_and_turn(self):
        game = Game(level_for_gestures())
        # К(0,0) → О(1,1) → Т(0,2): two diagonal steps and a turn.
        result = game.submit([0, 11, 2])
        self.assertTrue(result.is_target)
        self.assertEqual(result.canonical_path, (0, 1, 2))

    def test_repeated_cell_rejected(self):
        game = Game(level_for_gestures())
        result = game.submit([0, 1, 0])
        self.assertFalse(result.valid_gesture)
        self.assertEqual(result.reason, "repeated cell")
        self.assertFalse(game.found)

    def test_nonadjacent_rejected(self):
        game = Game(level_for_gestures())
        self.assertFalse(game.submit([0, 22]).valid_gesture)

    def test_repeated_word_and_completion(self):
        game = Game(level_for_gestures())
        game.submit([10, 11, 12])
        duplicate = game.submit([0, 1, 2])
        self.assertTrue(duplicate.already_found)
        self.assertEqual(len(game.found), 1)
        final = game.submit([20, 21, 22, 23])
        self.assertTrue(final.completed)

    def test_valid_nontarget(self):
        result = Game(level_for_gestures()).submit([3, 4, 5])
        self.assertTrue(result.valid_gesture)
        self.assertFalse(result.is_target)
        self.assertEqual(result.text, "ААА")

    def test_out_of_range_and_empty(self):
        game = Game(level_for_gestures())
        self.assertFalse(game.submit([]).valid_gesture)
        self.assertFalse(game.submit([100]).valid_gesture)


class Stage3GeneratorTests(unittest.TestCase):
    def test_mixed_words_cover_100_with_three_anchors(self):
        theme = {"А" * 8 + chr(1040 + i) for i in range(12)}
        general = {"Б" * 5 + chr(1040 + i) for i in range(25)} | {
            "В" * 6 + chr(1040 + i) for i in range(25)}
        words = choose_mixed_words(theme, general, Counter(), random.Random(7))
        self.assertIsNotNone(words)
        self.assertEqual(sum(map(len, words)), 100)
        self.assertEqual(sum(w in theme for w in words), 3)
        self.assertEqual(len(words), len(set(words)))

    def test_reuse_limit_blocks_pool(self):
        theme = {"АБВГДЕЖЗ", "БВГДЕЖЗИ", "ВГДЕЖЗИЙ"}
        usage = Counter({word: 2 for word in theme})
        self.assertIsNone(choose_mixed_words(theme, set(), usage, random.Random(1)))

    def test_stage3_validator_reports_alternatives_as_warning(self):
        # This partial fixture lacks full coverage, so geometry fails. The
        # validator must never turn alternative paths into acceptance errors.
        level = level_for_gestures()
        result = validate_collection_stage3([level], {"neon_city": {"КОТ", "ДАМА"}}, set())
        self.assertEqual(result["rejected_count"], 1)
        self.assertFalse(any("alternative" in x for x in result["levels"]["1"]["errors"]))

    def test_saved_alternative_uses_canonical_highlight(self):
        root = Path(__file__).resolve().parents[1]
        levels = json.loads((root / "output_stage3/candidates.json").read_text(encoding="utf-8"))
        examples = json.loads((root / "output_stage3/alternative_examples.json").read_text(encoding="utf-8"))
        level = levels[0]
        example = examples[str(level["id"])]
        result = Game(level).submit(example["path"])
        self.assertTrue(result.valid_gesture and result.is_target)
        self.assertEqual(result.text, example["word"])
        self.assertEqual(result.canonical_path, tuple(example["canonical"]))
        self.assertNotEqual(tuple(example["path"]), result.canonical_path)

    def test_saved_collection_passes_stage3_gate(self):
        from tools.lexicon_stage3 import build
        root = Path(__file__).resolve().parents[1]
        levels = json.loads((root / "output_stage3/candidates.json").read_text(encoding="utf-8"))
        thematic, general, _ = build()
        result = validate_collection_stage3(levels, thematic, general)
        self.assertEqual(result["accepted_count"], 80)
        self.assertEqual(result["rejected_count"], 0)


if __name__ == "__main__":
    unittest.main()
