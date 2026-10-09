"""Standalone Python model for the proposed any-path gesture rule."""
from __future__ import annotations

from dataclasses import dataclass

from .validator import ADJ


@dataclass(frozen=True)
class GestureResult:
    text: str
    valid_gesture: bool
    is_target: bool
    already_found: bool
    canonical_path: tuple[int, ...] | None
    completed: bool
    reason: str


class Game:
    def __init__(self, level: dict):
        self.level = level
        self.flat = "".join(level["grid"])
        if len(self.flat) != 100:
            raise ValueError("grid must contain 100 letters")
        self.targets = {item["text"]: tuple(r * 10 + c for r, c in item["path"])
                        for item in level["words"]}
        if len(self.targets) != len(level["words"]):
            raise ValueError("target words must be unique")
        self.found: set[str] = set()

    @property
    def completed(self) -> bool:
        return len(self.found) == len(self.targets)

    def submit(self, cells: list[int]) -> GestureResult:
        if not cells or any(type(cell) is not int or cell < 0 or cell >= 100 for cell in cells):
            return GestureResult("", False, False, False, None, self.completed,
                                 "empty gesture or cell outside grid")
        text = "".join(self.flat[cell] for cell in cells)
        if len(cells) != len(set(cells)):
            return GestureResult(text, False, False, False, None, self.completed,
                                 "repeated cell")
        if any(b not in ADJ[a] for a, b in zip(cells, cells[1:])):
            return GestureResult(text, False, False, False, None, self.completed,
                                 "nonadjacent step")
        canonical = self.targets.get(text)
        if canonical is None:
            return GestureResult(text, True, False, False, None, self.completed,
                                 "not a target word")
        if text in self.found:
            return GestureResult(text, True, True, True, canonical, self.completed,
                                 "already found")
        self.found.add(text)
        return GestureResult(text, True, True, False, canonical, self.completed,
                             "accepted")
