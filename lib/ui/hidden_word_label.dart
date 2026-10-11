/// Shows one letter as a clue without exposing the remaining answer.
String hiddenWordLabel(String word) =>
    '${word[0]}${List.filled(word.length - 1, '?').join()} — ${word.length} букв';
