---
title: "German Word App — Substantive, Verben & Adjektive von A1 bis C2"
description: "Wie ich eine Flutter-App mit verschlüsselter SQLite-Datenbank, drei Worttypcontrollern, CEFR-strukturierten Spiellevels, Verbkonjugations-Lückentexten und einem Favoritensystem für 6.322 deutsche Wörter entwickelt habe."
date: "2025-09-01"
image: "germanWordsApp.jpeg"
tags: [Flutter, Dart, SQLite, CEFR, Deutschlernen, Mobile, sqflite_sqlcipher]
---

# German Word App — Substantive, Verben & Adjektive von A1 bis C2

## Warum diese App

Nach der Entwicklung von Artikel Meister (fokussiert auf Substantiv-Artikel) wollte ich eine Begleit-App entwickeln, die die vollständige Vokabelherausforderung des Deutschlernens abdeckt: nicht nur Substantive, sondern auch Verbkonjugationen und Adjektivdeklinationen — strukturiert über die gesamte CEFR-Skala von absoluten Anfängern (A1) bis zu nahezu muttersprachlichen Kenntnissen (C2).

Das Ergebnis ist eine App mit **6.322 deutschen Wörtern** in drei Worttypen, sechs CEFR-Niveaus und mehreren Übungsmodi pro Typ.

---

## Umfang der Daten

| Worttyp | Anzahl |
|---|---|
| Substantive | 2.399 |
| Verben | 2.277 |
| Adjektive | 1.646 |
| **Gesamt** | **6.322** |

Jeder Eintrag enthält Übersetzungen, Beispiele, Grammatikmetadaten und eine `game_level`-Ganzzahl für strukturierte Übungsprogression.

---

## Architektur

```
Flutter UI
    ↓
ExerciseController (Substantiv / Verb / Adjektiv — pro Worttyp)
    ↓
Repository-Schicht (NounRepository, VerbRepository, AdjectiveRepository)
    ↓
ImportService → DatabaseHelper (SQLite verschlüsselt via sqflite_sqlcipher)
    ↓
Assets: nouns_all_levels.json, verbs_all_levels.json, adjectives_all_levels.json
```

Repositories werden in `main()` initialisiert und per Konstruktor in den Screen-Widget-Baum injiziert. Es gibt kein globales State-Management-Paket — Abhängigkeiten fließen explizit durch den Widget-Baum, was den Datenfluss lesbar und testbar hält.

---

## Verschlüsselte Datenbank

Die Datenbank verwendet `sqflite_sqlcipher` mit AES-Verschlüsselung:

```dart
const String dbPassword = 'i_l0ve_flutter';

return await openDatabase(
  path,
  password: dbPassword,
  version: 1,
  onCreate: _onCreate,
);
```

Dies verschlüsselt die gesamte SQLite-Datei auf der Festplatte und schützt den Wortdatensatz vor einfacher Extraktion. Für ein Produktions-Release würde der Schlüssel aus einem gerätespezifischen Wert abgeleitet oder aus einem sicheren Speicher abgerufen.

---

## Datenmodelle

### NounEntry — Reichhaltige Grammatikdaten

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
  final Map<String, List<String>> translations;  // pro Sprache
  final List<String> examples;
  final List<String> tags;
}
```

Das Geschlecht wird aus den rohen JSON-Werten normalisiert: `"masculine"` → `"der"`, `"feminine"` → `"die"`, `"neutral"` → `"das"`.

### VerbEntry — Vollständige Konjugationstabelle

```dart
class VerbEntry {
  final String word;
  final String auxiliary;       // haben / sein
  final Map<String, Map<String, List<List<String>>>> conjugations;
  // Modus → Tempus → [[Person, Form], ...]
  // z.B. conjugations["Indicative"]["Present"][0] = ["ich", "gehe"]
}
```

Die Konjugationsstruktur umfasst Indikativ, Konjunktiv II und Imperativ über Präsens, Perfekt, Präteritum und Futur I.

### AdjectiveEntry — Komparationsformen

```dart
class AdjectiveEntry {
  final String word;
  final String? comparative;   // z.B. "schöner"
  final String? superlative;   // z.B. "am schönsten"
  final Map<String, String> translations;
}
```

---

## Übungsmodi pro Worttyp

Jeder Worttyp hat seine eigene versiegelte Übungsmodusenum und einen dedizierten Controller:

**Substantive** (`NounExerciseMode`):
- `bedeutungen` — Übersetzungs-Flashcards
- `flashcards` — Artikel + Wortkarte

**Verben** (`VerbExerciseMode`):
- `bedeutungen` — Übersetzungs-Flashcards
- `praesens` — alle sechs Präsens-Konjugationsformen ausfüllen
- `perfekt` — die Perfektform ausfüllen

**Adjektive** (`AdjectiveExerciseMode`):
- `bedeutungen` — Übersetzungs-Flashcards
- `comparative` — die Komparativform eintippen
- `superlative` — die Superlativform eintippen

Die versiegelte Klassenhierarchie in `exercise_mode.dart` macht das Routing erschöpfend — der Compiler erkennt jeden nicht behandelten Modus zur Build-Zeit:

```dart
sealed class ExerciseMode {}
class NounExercise extends ExerciseMode { final NounExerciseMode mode; }
class VerbExercise extends ExerciseMode { final VerbExerciseMode mode; }
class AdjectiveExercise extends ExerciseMode { final AdjectiveExerciseMode mode; }
```

---

## Verb-Lückentextübung

Die Verbkonjugationsübungen sind der technisch komplexeste Teil der App. Der `VerbExerciseController` bereitet einen `TextEditingController` pro grammatikalischer Person vor und validiert alle sechs Formen gleichzeitig:

```dart
void _prepareFillIn(VerbEntry verb) {
  final forms = verb.conjugations['Indicative']?[tenseKey];

  for (var pair in forms) {
    final pronomen = pair[0]; // "ich", "du", "er/sie/es", ...
    final form     = pair[1]; // "gehe", "gehst", ...
    controllers[pronomen] = TextEditingController();
    correctForms[pronomen] = normalize(form);
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

Der `normalize()`-Aufruf entfernt Klammern aus Formen wie `(bin) gegangen` — eine Feinheit, die verhindert, dass korrekte Antworten wegen optionaler Notation in den Daten als falsch gewertet werden.

---

## Wort-Detailbildschirme

Jeder Worttyp hat einen dedizierten Detailbildschirm, der aus der Wortliste erreichbar ist:

**Verb-Details** zeigt das Hilfsverb (`haben`/`sein`), die vollständige Konjugationstabelle über alle Modi und Tempora, flaggenpräfixierte Übersetzungen pro Sprache und Beispielsätze.

**Substantiv-Details** zeigt Geschlecht, Pluralform, Genitiv, Deklinationslink, Bedeutungen pro Sprache und Beispielsätze.

**Adjektiv-Details** zeigt Komparativ- und Superlativformen, Übersetzungen und Verwendungsbeispiele.

---

## Theme-System

Die App verwendet eine zentrale `theme.dart`, die das vollständige `ThemeData` an einer Stelle definiert:

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

Eine `gradientButton()`-Fabrikfunktion liefert einen wiederverwendbaren tieflila Verlaufsknopf, der in der gesamten App verwendet wird — Konsistenz ohne Wiederholung.

---

## Favoritensystem

Nutzer können jedes Wort als Favorit markieren. Favoriten werden in einer dedizierten `favorites`-Tabelle in der verschlüsselten Datenbank gespeichert:

```sql
CREATE TABLE favorites (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  word_id INTEGER NOT NULL,
  word_type TEXT NOT NULL,      -- 'noun', 'verb' oder 'adjective'
  added_at TEXT,
  UNIQUE(word_id, word_type)    -- verhindert Duplikate
)
```

Der `FavoritesScreen`-Tab zeigt alle gespeicherten Wörter über alle drei Typen hinweg, sortiert nach `added_at DESC`. Wörter können direkt aus der Favoritenliste angetippt werden, um ihren vollständigen Detailbildschirm zu öffnen.

---

## CEFR-Navigationsfluss

```
Home → Übungskategorie → CEFR-Niveau → Übungstyp → Spiellevel → Übung
Home → Worttyp → CEFR-Niveau → Wortliste → Wortdetails
```

Der `CEFRLevelScreen` lädt verfügbare Niveaus dynamisch aus der Datenbank für den ausgewählten Worttyp, sodass die Niveauauswahl immer die tatsächlich vorhandenen Daten widerspiegelt — keine hartkodierten Niveaulisten.

---

## Was ich heute anders machen würde

- **Das Datenbankpasswort ist hart kodiert.** Für eine veröffentlichte App sollte der Schlüssel aus einem gerätespezifischen Wert abgeleitet oder aus einem sicheren Speicher abgerufen werden.
- **Keine Fortschrittsspeicherung zwischen Sitzungen.** Exercise-Controller verfolgen den aktuellen Sitzungspunktestand im Speicher, aber Punkte werden nicht zwischen Sitzungen gespeichert. Eine `progress`-Tabelle würde Streak-Tracking und historische Charts ermöglichen.
- **Wort des Tages ist sitzungsrandom, nicht datumsdeterministisch.** `Random(DateTime.now().day)` würde ein konsistentes tägliches Wort ohne Backend liefern.
- **Noch kein Audio.** Das `audioUrl`-Feld existiert in allen drei Datenmodellen, ist aber noch nicht mit der Wiedergabe verbunden. Das Hinzufügen von `audioplayers` würde das Aussprachetraining erheblich verbessern.

---

## Lessons Learned

Die größte Erkenntnis aus diesem Projekt ist der Wert einer **sauberen Trennung zwischen Worttypen auf Architekturebene**. Substantive, Verben und Adjektive haben grundlegend unterschiedliche Grammatiken, unterschiedliche Übungstypen und unterschiedliche Datenschemas. Jedem seinen eigenen Controller, sein eigenes Repository und sein eigenes Modell zu geben — auch wenn es anfangs wie mehr Code erscheint — bedeutete, dass das Hinzufügen von Adjektiv-Unterstützung nach den Verben unkompliziert war statt ein Refactoring. Die versiegelte `ExerciseMode`-Hierarchie war die richtige Entscheidung: Sie machte den Compiler zu einem Verbündeten, der sicherstellt, dass jeder Übungstyp überall behandelt wird, wo er es muss.
