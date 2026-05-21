---
title: "Artikel Meister — Eine Flutter-App zum Meistern der deutschen Artikel"
description: "Wie ich eine Flutter-App mit SQLite, CEFR-strukturierten Spiellevels, mehrsprachigen Übersetzungen, einem Level-Freischaltsystem und einem offiziellen Quiz-Modus entwickelt habe."
date: "2025-07-15"
image: "artikelMeister.jpeg"
tags: [Flutter, Dart, SQLite, CEFR, Deutschlernen, Mobile]
---

# Artikel Meister — Eine Flutter-App zum Meistern der deutschen Artikel

## Das Problem, das gelöst werden musste

Fragt man Deutschlernende, was sie am meisten frustriert, lautet die Antwort fast immer dieselbe: der, die, das. Anders als im Englischen, wo "the" für alles steht, weist das Deutsche jedem Substantiv ein grammatisches Geschlecht zu — maskulin, feminin oder neutral. Eine verlässliche Logik gibt es nicht. *Der Mann* ist maskulin. *Die Frau* ist feminin. *Das Mädchen* ist neutral — obwohl es ein Mädchen bezeichnet. Der einzige Weg, sie zu lernen, ist wiederholtes Üben, bis sie automatisch werden.

Genau dieses Problem löst Artikel Meister.

---

## Architekturüberblick

```
Flutter UI (Material Design 3)
        ↓
GameRepository (Abstraktionsschicht)
        ↓
GameContentService (JSON-Laden + In-Memory-Cache)
DatabaseService (SQLite via sqflite + sqflite_common_ffi)
        ↓
Assets: master.json → A1/A2/B1_Game_Levels.json + Übersetzungsdateien
```

Die App verwendet eine duale Speicherstrategie: SQLite für Substantive mit vollständigen Deklinationsdaten (Referenzbrowser und offizielles Quiz) und einen JSON-basierten Content-Service für die Spiellevel (Quiz-Gameplay). Beide werden über `GameRepository` abgefragt, das die Speicherdetails von der UI-Schicht trennt.

---

## Datenmodell

### Noun — Vollständige deutsche Grammatik

Das `Noun`-Modell speichert alle grammatikalischen Formen, die ein Lernender braucht:

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
  final String bedeutung;
  final String level;             // A1, A2, B1
}
```

Das Modell unterstützt zwei Serialisierungspfade: `Noun.fromJson()` für das verschachtelte JSON-Format aus den Assets und `Noun.fromDb()` / `Noun.toDb()` für das flache SQLite-Zeilenformat.

### GameWord — Leichtes Quiz-Objekt

Für das Quiz-Gameplay wird ein leichteres `GameWord` verwendet:

```dart
// Aus A1_Game_Levels.json — nach Spiellevel gruppiert
{
  "1": [
    { "word": "Januar", "article": "der", "plural": "Januare", "level": "A1" }
  ],
  "2": [ ... ]
}
```

Die Spiellevel innerhalb jedes CEFR-Niveaus sind bewusst sequenziert — Level 1 von A1 lehrt Monate, spätere Level führen Körperteile und Haushaltsgegenstände ein.

---

## CEFR-Levelstruktur

Die App deckt A1, A2 und B1 ab. Die gesamte Struktur wird von `master.json` gesteuert:

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

Das Hinzufügen eines neuen CEFR-Niveaus (B2, C1, C2) ist eine reine Datenoperation — keine Code-Änderungen nötig.

---

## Mehrsprachige Übersetzungen

Die App unterstützt drei Übersetzungssprachen: Englisch (🇬🇧), Französisch (🇫🇷) und Arabisch (🇸🇦). Arabisch ist RTL, was in `languages.json` erfasst ist:

```json
{ "code": "ar", "name": "العربية", "flag": "🇸🇦", "isRTL": true }
```

Übersetzungen werden während einer Quiz-Sitzung bei Bedarf geladen und pro CEFR-Niveau und Sprachcode gecacht. Nutzer konfigurieren in den Einstellungen, welche Sprachen angezeigt werden sollen.

---

## Level-Progression und Freischaltsystem

Der Fortschritt wird auf zwei Ebenen verfolgt:

**Wort-Level-Fortschritt** — der aktuelle Wortindex innerhalb eines Spiellevels wird gespeichert, sodass der Nutzer nach dem Schließen der App genau dort weitermacht, wo er aufgehört hat.

**Level-Freischaltung** — ein Spiellevel schaltet das nächste nur frei, wenn der Nutzer 70% oder mehr erreicht:

```dart
final passed = correct / totalQuestions >= 0.7;

if (passed) {
  await LevelProgressStorage().unlockLevel(widget.cefrLevel, nextLevel);
}
```

`LevelProgressStorage` speichert das maximale freigeschaltete Level pro CEFR-Niveau als `maxUnlockedLevel_A1`, `maxUnlockedLevel_A2` usw. Der Level-Auswahlbildschirm liest dies und blendet gesperrte Level grau aus.

---

## Quiz-Bildschirmablauf

Das Quiz präsentiert jeweils ein Substantiv. Der Nutzer tippt auf einen der drei Artikelknöpfe — `der`, `die` oder `das`. Das Feedback ist sofort:

- **Richtig:** der getippte Knopf wird grün, `✅ Richtig!`
- **Falsch:** der getippte Knopf wird rot, die richtige Antwort hebt sich grün hervor, `❌ Falsch. Richtig ist: der Januar`

Ein linearer Fortschrittsbalken oben zeigt den Abschlussprozentwert. Nach der Antwort rückt `Nächstes Wort ➔` zur nächsten Frage vor.

---

## Offizieller Quiz-Modus

Nach dem Abschluss aller Spiellevel innerhalb eines CEFR-Niveaus schaltet der Abschlussbildschirm ein **offizielles Quiz** frei — eine 30-Fragen-Mischbewertung aus allen Substantiven über A1, A2 und B1 hinweg:

```dart
final levels = ['A1', 'A2', 'B1'];
final List<Noun> allNouns = [];

for (final level in levels) {
  final nouns = await gameRepository.getNounsByLevel(level);
  allNouns.addAll(nouns);
}

_quizQuestions = allNouns
  .where((n) => n.title.trim().isNotEmpty && n.artikel.trim().isNotEmpty)
  .toList()
  ..shuffle()
  ..take(30).toList();
```

Das Ergebnis wird über `OfficialQuizStorage` gespeichert. Dieser Modus gibt Lernenden eine echte Checkpoint-Erfahrung — ähnlich einer echten Sprachprüfung.

---

## Substantiv-Detailbildschirm

Jedes Substantiv im Referenzbrowser hat einen vollständigen Detailbildschirm, der alle vier grammatikalischen Fälle als Gradient-Karten zeigt:

```
Nominativ  → Der Januar / Die Januare
Genitiv    → Des Januars / Der Januare
Dativ      → Dem Januar / Den Januaren
Akkusativ  → Den Januar / Die Januare
```

Jeder Fall hat seine eigene Karte mit einem eigenen Icon und einem tieflila Verlauf. Der Artikel wird als `CircleAvatar` oben angezeigt, was ihn sofort erfassbar macht.

---

## Wort des Tages

Der Startbildschirm zeigt beim Laden ein zufällig ausgewähltes A1-Substantiv:

```dart
_nouns = await gameRepository.getNounsByLevel('A1');
if (_nouns.isNotEmpty) _wordOfTheDay = (_nouns..shuffle()).first;
```

Dies gibt Nutzern einen reibungslosen täglichen Berührungspunkt mit der App, auch außerhalb strukturierter Quiz-Sitzungen.

---

## Was ich heute anders machen würde

- **Das tägliche Wort wird bei jedem App-Start neu zufällig ausgewählt.** Eine deterministische Auswahl basierend auf dem Datum würde es zu einem echten "Wort des Tages" machen.
- **B2, C1, C2-Daten noch nicht enthalten.** Die Architektur unterstützt sie vollständig — sie brauchen nur JSON-Inhaltsdateien.
- **Das offizielle Quiz zieht aus einem festen Pool von 30.** Eine konfigurierbare Länge und die Möglichkeit, nach bestimmten CEFR-Niveaus zu filtern, würden es für gezielte Wiederholung nützlicher machen.

---

## Lessons Learned

Der Bau dieser App hat mir gezeigt, dass der schwierigste Teil eines Lernwerkzeugs nicht die Quiz-Logik ist — es sind die Daten. Das Beschaffen, Strukturieren und Qualitätsprüfen von Hunderten von Substantiven über drei Sprachen und vier grammatikalische Fälle pro Substantiv dauert viel länger als das Schreiben des Flutter-Codes. Die Entscheidung, alles von `master.json` zu steuern, war die richtige: Sie trennt Inhalt vollständig vom Code, was bedeutet, dass die App wächst, ohne eine einzige Dart-Datei zu berühren.
