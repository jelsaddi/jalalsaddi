---
title: "Artikel Meister — A Flutter App for Mastering German Articles"
description: "How I built a Flutter app with SQLite, CEFR-structured game levels, multilingual translations, a level-unlock progression system, and an official quiz mode to help learners conquer der, die, and das."
date: "2025-07-15"
image: "artikelMeister.jpeg"
tags: [Flutter, Dart, SQLite, CEFR, German Learning, Mobile]
---

# Artikel Meister — A Flutter App for Mastering German Articles

## The Problem Worth Solving

Ask any German learner what frustrates them most and the answer is almost always the same: der, die, das. Unlike English, which uses a single article "the" for everything, German assigns a grammatical gender — masculine, feminine, or neuter — to every noun. There is no reliable logic. *Der Mann* (the man) is masculine. *Die Frau* (the woman) is feminine. *Das Mädchen* (the girl) is neuter — even though it refers to a girl. The only way to learn them is through repeated exposure until they become automatic.

That is the problem Artikel Meister was built to solve.

---

## Architecture Overview

```
Flutter UI (Material Design 3)
        ↓
GameRepository (abstraction layer)
        ↓
GameContentService (JSON loading + in-memory cache)
DatabaseService (SQLite via sqflite + sqflite_common_ffi)
        ↓
Assets: master.json → A1/A2/B1_Game_Levels.json + translation files
```

The app uses a dual-storage strategy: SQLite for nouns with full declension data (reference browser and official quiz), and a JSON-based content service for the game levels (quiz gameplay). Both are queried through `GameRepository`, which abstracts the storage detail from the UI layer.

---

## Data Model

### Noun — Full German Grammar

The `Noun` model stores every grammatical form a learner needs:

```dart
class Noun {
  final String titel;
  final String artikel;           // der / die / das
  final String nominativSingular;
  final String nominativPlural;
  final String genitivSingular;
  final String genitivPlural;
  final String dativSingular;
  final String dativPlural;
  final String akkusativSingular;
  final String akkusativPlural;
  final String bedeutung;         // German definition
  final String level;             // A1, A2, B1
}
```

The model supports two serialization paths: `Noun.fromJson()` for the nested JSON format from assets, and `Noun.fromDb()` / `Noun.toDb()` for the SQLite flat-row format. This dual-path design keeps storage concerns completely out of the UI layer.

### GameWord — Lean Quiz Object

For quiz gameplay, a lighter `GameWord` is used:

```dart
// From A1_Game_Levels.json — grouped by game level
{
  "1": [
    { "word": "Januar", "article": "der", "plural": "Januare", "level": "A1" },
    { "word": "Februar", "article": "der", "plural": "Februare", "level": "A1" }
  ],
  "2": [ ... ]
}
```

Game levels within each CEFR level are deliberately sequenced — level 1 of A1 teaches months, later levels introduce body parts and household objects. Vocabulary is curated, not random.

---

## CEFR Level Structure

The app covers A1, A2, and B1. The entire structure is driven by `master.json`:

```json
{
  "A1": {
    "levelsFile": "A1_Game_Levels.json",
    "translations": {
      "en": "A1_Game_nouns_translated_en.json",
      "fr": "A1_Game_nouns_translated_fr.json",
      "ar": "A1_Game_nouns_translated_ar.json"
    }
  }
}
```

Adding a new CEFR level (B2, C1, C2) is a pure data operation — no code changes needed. Just add a new entry in `master.json` and provide the corresponding JSON files.

---

## Multilingual Translations

The app supports three translation languages: English (🇬🇧), French (🇫🇷), and Arabic (🇸🇦). Arabic is RTL, captured in `languages.json`:

```json
{ "code": "ar", "name": "العربية", "flag": "🇸🇦", "isRTL": true }
```

During a quiz session, translations are loaded on demand via `GameContentService` and cached per CEFR level and language code. Users configure which languages they want displayed in the settings screen, and the preference persists across sessions via `shared_preferences`.

---

## Level Progression and Unlock System

Progress is tracked at two levels:

**Word-level progress** — the current word index within a game level is persisted so the user resumes exactly where they left off if they close the app mid-session.

**Level unlock** — a game level unlocks the next only when the user scores 70% or higher:

```dart
final passed = correct / totalQuestions >= 0.7;

if (passed) {
  await LevelProgressStorage().unlockLevel(widget.cefrLevel, nextLevel);
}
```

`LevelProgressStorage` stores the maximum unlocked level per CEFR level as `maxUnlockedLevel_A1`, `maxUnlockedLevel_A2`, etc. The level selection screen reads this and greys out locked levels, guiding learners through the content in order.

---

## Quiz Screen Flow

The quiz presents one noun at a time. The user taps one of three article buttons — `der`, `die`, or `das`. Feedback is immediate:

- **Correct:** the tapped button turns green, `✅ Richtig!`
- **Wrong:** the tapped button turns red, the correct answer highlights green, `❌ Falsch. Richtig ist: der Januar`

A linear progress bar at the top shows completion percentage. After answering, `Nächstes Wort ➔` advances the queue.

---

## Official Quiz Mode

After completing all game levels within a CEFR level, the completion screen unlocks an **Official Quiz** — a 30-question mixed assessment drawn randomly from all nouns across A1, A2, and B1:

```dart
final levels = ['A1', 'A2', 'B1'];
final List<Noun> allNouns = [];

for (final level in levels) {
  final nouns = await gameRepository.getNounsByLevel(level);
  allNouns.addAll(nouns);
}

final filteredNouns = allNouns
  .where((n) => n.title.trim().isNotEmpty && n.artikel.trim().isNotEmpty)
  .toList()
  ..shuffle();

_quizQuestions = filteredNouns.take(30).toList();
```

The result is stored via `OfficialQuizStorage` and the score percentage shown at the end. This gives learners a genuine checkpoint experience — separate from the game progression — similar to a real language exam.

---

## Noun Detail Screen

Every noun in the reference browser has a full detail screen showing all four grammatical cases rendered as gradient cards:

```
Nominativ  → Der Januar / Die Januare
Genitiv    → Des Januars / Der Januare
Dativ      → Dem Januar / Den Januaren
Akkusativ  → Den Januar / Die Januare
```

Each case has its own card with a distinct icon and a deep-purple gradient. The article is displayed as a `CircleAvatar` at the top, making it instantly scannable.

---

## Word of the Day

The home screen shows a randomly selected A1 noun on load:

```dart
_nouns = await gameRepository.getNounsByLevel('A1');
if (_nouns.isNotEmpty) _wordOfTheDay = (_nouns..shuffle()).first;
```

This gives users a low-friction daily touchpoint with the app even outside of structured quiz sessions.

---

## Technical Decisions Worth Noting

**Dual-storage approach:** The full `Noun` model (all declension forms) is stored in SQLite for the reference browser and official quiz. Lighter `GameWord` objects for quiz mode are loaded from JSON and cached in memory — no database roundtrip needed during gameplay.

**Desktop support via `sqflite_common_ffi`:** The standard `sqflite` package does not support desktop targets. Adding `sqflite_common_ffi` with conditional initialisation via `platform/sqflite_initializer.dart` stubs allows the app to run on all Flutter targets without platform-specific code in the UI.

---

## What I Would Do Differently

- **The daily word is re-randomized on every app launch.** A deterministic selection based on the date (e.g. `Random(DateTime.now().day).nextInt(nouns.length)`) would make it a true shared "word of the day."
- **B2, C1, C2 data not yet included.** The architecture fully supports them — they just need JSON content files.
- **The official quiz draws from a fixed pool of 30.** A configurable length and the ability to filter by specific CEFR level would make it more useful for targeted revision.

---

## Lessons Learned

Building this app taught me that the hardest part of a learning tool is not the quiz logic — it is the data. Sourcing, structuring, and quality-checking hundreds of nouns across three languages and four grammatical cases per noun takes far longer than writing the Flutter code. The decision to drive everything from `master.json` was the right one: it decouples content from code entirely, meaning the app grows without touching a single Dart file.
