"use strict";

const dataset = JSON.parse(document.getElementById("level-data").textContent);
const levels = new Map(dataset.levels.map(level => [String(level.id), level]));
const examples = dataset.examples;
const colors = ["#d64c58", "#427fa2", "#239d91", "#da8541", "#8c5ed1",
  "#d66b5c", "#129ca4", "#a974e8", "#c99412", "#729b43",
  "#bc3d83", "#536fcf", "#ad7187", "#348a91", "#8c6c3e", "#6768ad"];

const board = document.getElementById("board");
const wordList = document.getElementById("word-list");
const status = document.getElementById("status");
const progress = document.getElementById("progress");
const selector = document.getElementById("level-select");
let level;
let found = new Set();
let gesture = [];
let lastGesture = [];
let dragActive = false;
let gestureInvalid = false;
let showLast = false;
let flashTimer = null;

function canonicalIds(word) {
  return word.path.map(([row, col]) => row * 10 + col);
}

function adjacent(a, b) {
  const ar = Math.floor(a / 10), ac = a % 10;
  const br = Math.floor(b / 10), bc = b % 10;
  return Math.max(Math.abs(ar - br), Math.abs(ac - bc)) === 1;
}

function setStatus(message, kind = "normal") {
  status.textContent = message;
  status.className = "status" + (kind === "normal" ? "" : " " + kind);
}

function paint() {
  const cells = board.querySelectorAll(".cell");
  cells.forEach(cell => {
    cell.className = "cell";
    cell.style.removeProperty("--found");
  });
  level.words.forEach((word, index) => {
    if (!found.has(word.text)) return;
    canonicalIds(word).forEach(id => {
      cells[id].classList.add("found");
      cells[id].style.setProperty("--found", colors[index % colors.length]);
    });
  });
  gesture.forEach(id => cells[id].classList.add("gesture"));
  if (showLast) lastGesture.forEach(id => cells[id].classList.add("last"));
  wordList.querySelectorAll("li").forEach(item => {
    item.classList.toggle("done", found.has(item.dataset.word));
  });
  progress.textContent = `Найдено ${found.size}/${level.words.length}` +
    (found.size === level.words.length ? " · Уровень пройден" : "");
}

function loadLevel(id) {
  level = levels.get(String(id));
  if (!level) return;
  selector.value = String(id);
  found = new Set();
  gesture = [];
  lastGesture = [];
  dragActive = false;
  gestureInvalid = false;
  showLast = false;
  if (flashTimer) clearTimeout(flashTimer);
  board.replaceChildren();
  for (let index = 0; index < 100; index++) {
    const cell = document.createElement("div");
    cell.className = "cell";
    cell.dataset.index = String(index);
    cell.textContent = level.grid[Math.floor(index / 10)][index % 10];
    board.appendChild(cell);
  }
  wordList.replaceChildren();
  level.words.forEach(word => {
    const item = document.createElement("li");
    item.dataset.word = word.text;
    item.textContent = `${word.text} (${word.text.length})`;
    wordList.appendChild(item);
  });
  setStatus("Проведите по буквам. Альтернативный путь к целевому слову засчитывается.");
  paint();
  document.querySelectorAll(".card").forEach(card => {
    card.style.outline = card.dataset.level === String(id) ? "2px solid #4594c6" : "none";
  });
}

function appendCell(index) {
  if (!Number.isInteger(index) || index < 0 || index > 99) return;
  if (gesture.length > 0) {
    if (gesture.includes(index)) {
      if (index !== gesture[gesture.length - 1]) gestureInvalid = true;
      return;
    }
    if (!adjacent(gesture[gesture.length - 1], index)) {
      gestureInvalid = true;
      return;
    }
  }
  gesture.push(index);
  paint();
}

function submitPath(path, forcedInvalid = false) {
  if (!path.length || forcedInvalid || new Set(path).size !== path.length ||
      path.some((value, index) => index && !adjacent(path[index - 1], value))) {
    setStatus("Жест отклонён: повтор клетки или переход не к соседней клетке.", "bad");
    gesture = [];
    paint();
    return;
  }
  const text = path.map(index => level.grid[Math.floor(index / 10)][index % 10]).join("");
  const target = level.words.find(word => word.text === text);
  if (!target) {
    setStatus(`«${text}» не входит в список целевых слов.`, "bad");
    gesture = [];
    paint();
    return;
  }
  if (found.has(text)) {
    setStatus(`«${text}» уже найдено. Повтор не засчитан.`, "bad");
    gesture = [];
    paint();
    return;
  }
  found.add(text);
  lastGesture = path.slice();
  gesture = [];
  showLast = true;
  const canonical = canonicalIds(target);
  const different = canonical.some((id, index) => id !== path[index]);
  setStatus(different
    ? `«${text}» принято по вашему пути. Голубой контур — ваш жест; цветная заливка — другой, записанный в уровне путь.`
    : `«${text}» найдено. Выбранный и записанный пути совпали.`, "ok");
  paint();
  if (flashTimer) clearTimeout(flashTimer);
  flashTimer = setTimeout(() => { showLast = false; paint(); }, 3000);
}

board.addEventListener("pointerdown", event => {
  const cell = event.target.closest(".cell");
  if (!cell) return;
  event.preventDefault();
  board.setPointerCapture(event.pointerId);
  dragActive = true;
  gestureInvalid = false;
  gesture = [];
  appendCell(Number(cell.dataset.index));
});

board.addEventListener("pointermove", event => {
  if (!dragActive) return;
  const target = document.elementFromPoint(event.clientX, event.clientY);
  const cell = target && target.closest(".cell");
  if (cell && board.contains(cell)) appendCell(Number(cell.dataset.index));
});

board.addEventListener("pointerup", event => {
  if (!dragActive) return;
  dragActive = false;
  const target = document.elementFromPoint(event.clientX, event.clientY);
  const cell = target && target.closest(".cell");
  if (cell && board.contains(cell)) appendCell(Number(cell.dataset.index));
  submitPath(gesture.slice(), gestureInvalid);
});

board.addEventListener("pointercancel", () => {
  dragActive = false;
  gesture = [];
  paint();
});

selector.addEventListener("change", () => loadLevel(selector.value));
document.getElementById("reset").addEventListener("click", () => loadLevel(level.id));
document.getElementById("demo").addEventListener("click", () => {
  const example = examples[String(level.id)];
  if (!example) {
    setStatus("Для этого уровня пример альтернативы не найден.");
    return;
  }
  submitPath(example.path);
});
document.getElementById("last").addEventListener("click", () => {
  if (!lastGesture.length) {
    setStatus("Сначала найдите слово или запустите демонстрацию.");
    return;
  }
  showLast = !showLast;
  paint();
});
document.querySelectorAll(".open-level").forEach(button => {
  button.addEventListener("click", () => {
    loadLevel(button.dataset.id);
    document.querySelector(".play").scrollIntoView({behavior: "smooth"});
  });
});

loadLevel(dataset.levels[0].id);
