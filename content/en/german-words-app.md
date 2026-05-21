---
title: "German Word App — Nouns, Verbs & Adjectives from A1 to C2"
description: "How I built a Flutter app with an encrypted SQLite database, three word type controllers, CEFR-structured game levels, verb conjugation fill-in exercises, and a favourites system covering 6,322 German words."
date: "2025-09-01"
image: "germanWordsApp.jpeg"
tags: [Flutter, Dart, SQLite, CEFR, German Learning, Mobile, sqflite_sqlcipher]
---

# German Word App — Nouns, Verbs & Adjectives from A1 to C2

## Why Build This

After building Artikel Meister (focused on noun articles), I wanted a companion app that covers the full vocabulary challenge of learning German: not just nouns, but also verb conjugations and adjective declensions — all structured across the complete CEFR scale from absolute beginner (A1) to near-native proficiency (C2).

The result is an app with **6,322 German words** across three word types, six CEFR levels, and multiple exercise modes per type.

---

## Scale of the Data

| Word type | Count |
|---|---|
| Nouns | 2,399 |
| Verbs | 2,277 |
| Adjectives | 1,646 |
| **Total** | **6,322** |

Each entry carries translations, examples, grammar metadata, and a `game_level` integer for structured practice progression.

---

## Architecture

```
Flutter UI
    ↓
ExerciseController (noun / verb / adjective — per word type)
    ↓
Repository layer (NounRepository, VerbRepository, AdjectiveRepository)
    ↓
ImportService → DatabaseHelper (SQLite encrypted via sqflite_sqlcipher)
    ↓
Assets: nouns_all_levels.json, verbs_all_levels.json, adjectives_all_levels.json
```

Repositories are initialised in `main()` and injected via constructor into the screen widget tree. There is no global state management package — dependencies flow explicitly through the widget tree, which keeps data flow readable and testable.

---

## Encrypted Database

The database uses `sqflite_sqlcipher` with AES encryption:

```dart
const String dbPassword = 'i_l0ve_flutter';

return await openDatabase(
  path,
  password: dbPassword,
  version: 1,
  onCreate: _onCreate,
);
```

This encrypts the entire SQLite file on disk, protecting the word dataset. For a production release the key would be derived from a device-specific value or fetched from secure storage rather than hardcoded.

---

## Data Models

### NounEntry — Rich Grammar Data

```dart
class NounEntry {
  final String word;
  final String level;        // A1–C2
  final int? gameLevel;
  final String gender;       // der / die / das
  final String declension;
  final String genitive;
  final String plural;
  final List<String> meanings;
  final Map<String, List<String>> translations;  // per language
  final List<String> examples;
  final List<String> tags;
}
```

Gender is normalised from the raw JSON values: `"masculine"` → `"der"`, `"feminine"` → `"die"`, `"neutral"` → `"das"`.

### VerbEntry — Full Conjugation Table

```dart
class VerbEntry {
  final String word;
  final String auxiliary;       // haben / sein
  final Map<String, Map<String, List<List<String>>>> conjugations;
  // Mood → Tense → [[person, form], ...]
  // e.g. conjugations["Indicative"]["Present"][0] = ["ich", "gehe"]
}
```

The conjugation structure covers Indicative, Konjunktiv II, and Imperativ across Präsens, Perfekt, Präteritum, and Futur I.

### AdjectiveEntry — Comparative Forms

```dart
class AdjectiveEntry {
  final String word;
  final String? comparative;   // e.g. "schöner"
  final String? superlative;   // e.g. "am schönsten"
  final Map<String, String> translations;
}
```

---

## Exercise Modes per Word Type

Each word type has its own sealed exercise mode enum and a dedicated controller:

**Nouns** (`NounExerciseMode`):
- `bedeutungen` — translation flashcards
- `flashcards` — article + word card review

**Verbs** (`VerbExerciseMode`):
- `bedeutungen` — translation flashcards
- `praesens` — fill in all six Präsens conjugation forms
- `perfekt` — fill in the Perfekt form

**Adjectives** (`AdjectiveExerciseMode`):
- `bedeutungen` — translation flashcards
- `comparative` — type the comparative form
- `superlative` — type the superlative form

The sealed class hierarchy in `exercise_mode.dart` makes routing exhaustive — the compiler catches any unhandled mode at build time:

```dart
sealed class ExerciseMode {}
class NounExercise extends ExerciseMode { final NounExerciseMode mode; }
class VerbExercise extends ExerciseMode { final VerbExerciseMode mode; }
class AdjectiveExercise extends ExerciseMode { final AdjectiveExerciseMode mode; }
```

---

## Verb Fill-In Exercise

The verb conjugation exercises are the most technically complex part of the app. The `VerbExerciseController` prepares one `TextEditingController` per grammatical person and validates all six forms simultaneously:

```dart
void _prepareFillIn(VerbEntry verb) {
  final forms = verb.conjugations['Indicative']?[tenseKey];

  for (var pair in forms) {
    final pronoun = pair[0]; // "ich", "du", "er/sie/es", ...
    final form    = pair[1]; // "gehe", "gehst", ...
    controllers[pronoun] = TextEditingController();
    correctForms[pronoun] = normalize(form);
  }
}

void checkFillInAnswers() {
  for (final entry in controllers.entries) {
    final userInput = normalize(entry.value.text);
    if (userInput == correctForms[entry.key]) score++;
  }
}

String normalize(String input) =>
    input.replaceAll(RegExp(r'[\(\)]'), '').trim();
```

The `normalize()` call strips parentheses from forms like `(bin) gegangen` — a nuance that prevents correct answers being marked wrong due to optional notation in the data.

---

## Word Detail Screens

Each word type has a dedicated detail screen accessible from the word list:

**Verb details** shows auxiliary verb (`haben`/`sein`), full conjugation table across all moods and tenses, flag-prefixed translations per language, and example sentences. The conjugation table is rendered as a scrollable gradient card with each mood/tense section collapsed by default.

**Noun details** shows gender, plural form, genitive, declension URL, meanings per language, and example sentences.

**Adjective details** shows comparative and superlative forms, translations, and usage examples.

---

## Theme System

The app uses a centralised `theme.dart` that defines the full `ThemeData` in one place:

```dart
final ThemeData appTheme = ThemeData(
  primaryColor: Colors.deepPurple.shade400,
  cardTheme: CardThemeData(
    color: Colors.deepPurple.shade400,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  appBarTheme: AppBarTheme(backgroundColor: Colors.deepPurple.shade400),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    selectedItemColor: Colors.deepPurple,
    unselectedItemColor: Colors.deepPurple.shade200,
  ),
);
```

A `gradientButton()` factory function provides a reusable deep-purple gradient button used throughout the app — consistency without repetition.

---

## Favourites System

Users can mark any word as a favourite. Favourites are stored in a dedicated `favorites` table in the encrypted database:

```sql
CREATE TABLE favorites (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  word_id INTEGER NOT NULL,
  word_type TEXT NOT NULL,      -- 'noun', 'verb', or 'adjective'
  added_at TEXT,
  UNIQUE(word_id, word_type)    -- prevents duplicates
)
```

The `FavoritesScreen` tab shows all saved words across all three types, ordered by `added_at DESC`. Words can be tapped to open their full detail screen directly from the favourites list.

---

## CEFR Navigation Flow

```
Home → Exercise Category → CEFR Level → Exercise Type → Game Level → Exercise
Home → Word Type → CEFR Level → Word List → Word Details
```

The `CEFRLevelScreen` dynamically loads available levels from the database for the selected word type, so the level selector always reflects what data is actually present — no hardcoded level list.

---

## What I Would Do Differently

- **The database password is hardcoded.** For a published app, the key should be derived from a device-specific value or fetched from secure storage.
- **No progress persistence across sessions.** Exercise controllers track the current session score in memory but scores are not stored between sessions. A `progress` table would enable streak tracking and historical charts.
- **Word of the day is session-random, not date-deterministic.** `Random(DateTime.now().day)` would give a consistent daily word without a backend.
- **No audio yet.** The `audioUrl` field exists in all three data models but is not yet wired to playback. Adding `audioplayers` would significantly improve pronunciation learning.

---

## Lessons Learned

The biggest lesson from this project is the value of **clean separation between word types at the architecture level**. Nouns, verbs, and adjectives have genuinely different grammars, different exercise types, and different data shapes. Giving each its own controller, repository, and model — even though it feels like more code upfront — meant that adding adjective support after verbs were done was straightforward rather than a refactor. The sealed `ExerciseMode` hierarchy was the right call: it made the compiler an ally in ensuring every exercise type is handled everywhere it needs to be.
