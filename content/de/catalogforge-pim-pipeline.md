---
title: "CatalogForge — Eine PIM-Datenpipeline, die echte Skalierung beherrscht"
description: "Wie ich eine Python-Pipeline entwickelt habe, um große PIM-Variantenexporte zu filtern, anzureichern und zu paketieren — mit SFTP-Download, Excel-gesteuerter Filterung nach SKU oder EAN, Kategoriebaumauflösung und Thread-basierter Anreicherung via orjson."
date: "2026-01-15"
image: "catalogForge.jpeg"
tags: [Python, PIM, Datenpipeline, orjson, SFTP, E-Commerce]
---

# CatalogForge — Eine PIM-Datenpipeline, die echte Skalierung beherrscht

## Das Problem

Jeder große E-Commerce-Betrieb steht irgendwann vor derselben unspektakulären Herausforderung: Der Produktkatalog ist ein Durcheinander. Nicht weil niemand aufgepasst hat, sondern weil Daten sich ansammeln. Varianten vermehren sich. Attributschlüssel werden von verschiedenen Teams über verschiedene Jahre hinweg hinzugefügt. Kategoriebäume wachsen in alle Richtungen. Und wenn man einen sauberen, angereicherten, gefilterten Teilbestand dieses Katalogs für ein nachgelagertes System braucht — eine Suchmaschine, einen Marktplatz-Feed, ein Data Warehouse — stellt man fest, dass der Rohexport eine mehrgigabyte große NDJSON-Datei ist, die kein Tabellenkalkulationsprogramm öffnen wird und kein naives Skript in vernünftiger Zeit verarbeitet.

Das war die Situation, in der ich arbeitete. Das PIM-System exportierte Varianten als zeilengetrennte JSON-Daten. Hunderttausende von Einträgen. Labels in einer separaten Lookup-Datei gespeichert. Kategorien in einer Baumstruktur, die für jedes Produkt vom Blatt bis zur Wurzel durchlaufen werden musste. Und das Team musste sagen können: "Gib mir die angereicherten Daten für diese 200 EANs" — aus einer Excel-Datei, in Minuten, zuverlässig.

Also habe ich CatalogForge entwickelt.

> Hinweis: Alle Attributschlüssel, Feldnamen und Daten in diesem Artikel sind zur Veranschaulichung erfunden. Sie spiegeln nicht das tatsächliche Schema eines Systems wider, mit dem ich gearbeitet habe.

---

## Was die Pipeline tut

Die Pipeline hat vier Schritte, klar voneinander getrennt:

```
Schritt 0  SFTP-Download + .gz-Dekomprimierung   (wenn Remote-Quelle konfiguriert)
Schritt 1  Varianten nach SKU oder GTIN/EAN filtern  (oder alles durchleiten)
Schritt 2  Anreicherung: Labels + Kategoriebaum in einem einzigen Durchlauf
Schritt 3  Ausgabe zippen + Zwischendateien bereinigen
```

Zwei Modi decken die beiden realen Anwendungsfälle ab:

**Vollständiger Modus** — den gesamten Variantenexport unverändert anreichern. Keine Filterung. Nützlich für eine nächtliche Auffrischung des vollständigen Katalogs.

**Gefilterter Modus** — eine Excel-Datei mit einer Liste von GTINs oder SKUs in Spalte A bereitstellen. Die Pipeline extrahiert genau diese Varianten aus der Gesamtdatei, reichert sie an und liefert ein Zip. Nützlich für Ad-hoc-Anfragen, QA und Marktplatz-Teilmengen-Feeds.

---

## Schritt 0 — SFTP mit intelligentem Caching

Die Quelldateien liegen auf einem Remote-SFTP-Server als gzip-komprimierte JSON-Dateien. Der Download-Schritt ist nicht einfach "Datei holen" — er vergleicht den Änderungszeitpunkt der Remote-Datei mit dem lokalen Cache:

```python
if os.path.exists(local_json_path):
    local_mtime  = os.path.getmtime(local_json_path)
    if local_mtime >= remote_mtime:
        log(f"  [CACHE OK]  Reusing {os.path.basename(local_json_path)}")
        continue
    else:
        log(f"  [OUTDATED]  Deleting stale cache")
        os.remove(local_json_path)
```

Wenn der lokale Cache aktuell ist, wird der Download vollständig übersprungen. Bei einer großen Datei spart das Minuten pro Lauf. Der Download selbst schreibt zunächst in eine `.tmp`-Datei und benennt diese erst bei Erfolg in den endgültigen Pfad um — ein fehlgeschlagener oder unterbrochener Download hinterlässt also nie eine beschädigte Cache-Datei, die beim nächsten Lauf still falsche Ergebnisse produzieren würde.

Die Dekomprimierung verwendet einen 4-MB-Kopierpuffer:

```python
with gzip.open(gz_path, "rb") as f_in, open(out_path, "wb") as f_out:
    shutil.copyfileobj(f_in, f_out, length=4 * 1024 * 1024)
```

Die `.gz`-Datei wird unmittelbar nach der Dekomprimierung gelöscht — keine doppelte Speicherung großer Dateien.

---

## Schritt 1 — Filterung nach SKU oder GTIN

Die Pipeline erkennt automatisch, welcher Bezeichnertyp in der Excel-Spalte steht:

```python
def _detect_mode(excel_file) -> str:
    df = pd.read_excel(excel_file, usecols=[0], dtype=str, nrows=20)
    for val in df.iloc[:, 0].dropna():
        val = str(val).strip()
        if val:
            mode = "sku" if val.upper().startswith("V") else "gtin"
            return mode
```

Beginnt der erste Wert mit "V", ist es eine SKU. Andernfalls ist es eine GTIN. Keine Konfiguration nötig — einfach die Excel-Datei einlegen.

### SKU-Filterung

Einfach und schnell. Den ID-Set in den Speicher laden, jede Zeile scannen, Treffer ausgeben:

```python
ids = set(df.iloc[:, 0].dropna().astype(str).str.strip())

for raw_line in fin:
    item = orjson.loads(raw_line)
    if str(item.get("_id", "")).strip() in ids:
        buf.append(orjson.dumps(item))
```

### GTIN-Filterung — der interessante Teil

GTINs haben ein Problem: führende Nullen. `0123456789012` und `123456789012` sind dasselbe Produkt, aber unterschiedliche Zeichenketten. Ein naiver String-Vergleich würde die Hälfte der Treffer verpassen.

Die Lösung ist die Normalisierung beider Seiten vor dem Vergleich. Und weil das vollständige Parsen jeder JSON-Zeile für eine GTIN-Suche langsam wäre, wird die GTIN mit einer gezielten Byte-Suche extrahiert statt durch vollständiges Parsen:

```python
_GTIN_KEY = b'"demo-gtin-code","values":[{"value":"'

def _extract_gtin_bytes(line: bytes) -> bytes | None:
    idx = line.find(_GTIN_KEY)
    if idx == -1:
        return None
    start = idx + len(_GTIN_KEY)
    end   = line.find(b'"', start)
    return line[start:end] if end != -1 else None

def _norm(v):
    return v.lstrip(b"0") if isinstance(v, bytes) else str(v).lstrip("0")
```

Der Feldschlüssel hier — `demo-gtin-code` — ist nur ein Platzhalter; der tatsächliche Schlüssel hängt vollständig davon ab, welches Schema der eigene PIM-Export verwendet. Die Byte-Suche findet das Feld direkt in der rohen Zeile, extrahiert den Wert ohne das gesamte JSON-Objekt zu parsen, normalisiert die führenden Nullen und prüft gegen den normalisierten Set aus Excel. Nur bei einem Treffer wird die Zeile vollständig mit `orjson` geparst. Dies hält die Kosten des Scannens von Millionen nicht-treffender Zeilen so gering wie möglich.

---

## Schritt 2 — Anreicherung in einem einzigen Durchlauf

Den rohen Variantendaten fehlen zwei Dinge, die nachgelagerte Systeme benötigen:

1. **Menschenlesbare Labels** für Attributschlüssel (die Rohdaten haben undurchsichtige Schlüssel wie `demo-color-code`; die Label-Datei bildet diese auf `"Farbe"` ab)
2. **Kategoriehierarchie** aus einem flachen Kategoriebaum aufgelöst (die Rohdaten haben eine Blattkategorie-ID; nachgelagerte Systeme brauchen den vollständigen Pfad von der Wurzel)

Beide Anreicherungen finden in einem Durchlauf über die Daten statt — ein Lesen, ein Schreiben.

### Label-Lookup

Labels werden einmalig zu Beginn in ein einfaches Dict geladen:

```python
def _load_labels(labels_file: str) -> dict[str, str]:
    lookup: dict[str, str] = {}
    for raw in f:
        obj = orjson.loads(raw)
        key = obj.get("key")
        if key:
            lookup[key] = obj.get("localizedValues", {}).get("de_DE", "")
    return lookup
```

Während der Anreicherung bekommt jedes Attribut einer Variante sein deutsches Label injiziert:

```python
for attr in item.get("attributes", []):
    k = attr.get("key")
    attr["label_de"] = label_lookup.get(k, "") if k else ""
```

Ein fiktives Beispiel, wie ein Variantenattribut vor und nach der Anreicherung aussieht:

```json
// Vor der Anreicherung
{ "key": "demo-color-code", "values": [{ "value": "Blau" }] }

// Nach der Anreicherung
{ "key": "demo-color-code", "values": [{ "value": "Blau" }], "label_de": "Farbe" }
```

### Kategoriebaumauflösung — mit Memoisierung

Der Kategoriebaum ist der aufwändige Teil. Jede Variante hat eine Blattkategorie-ID. Um den vollständigen Pfad zu kennen — Wurzel → Abteilung → Unterkategorie → Blatt — muss man den Baum aufwärts durch Elternreferenzen durchlaufen. Bei einer großen Datei könnte das bedeuten, dieselbe populäre Kategorie tausende Male zu durchlaufen.

Die Lösung ist ein memoisierter Resolver, der als Closure aufgebaut wird:

```python
def _build_chain_fn(lookup: dict[int, dict]):
    _cache: dict[int, list] = {}

    def _chain(leaf_id: int) -> list:
        if leaf_id in _cache:
            return _cache[leaf_id]
        chain, current, visited = [], leaf_id, set()
        while current is not None:
            if current in visited:
                break                    # Zyklusschutz
            visited.add(current)
            cat = lookup.get(current)
            if cat is None:
                break
            chain.append(cat)
            p = cat.get("parentId")
            current = int(p) if p is not None else None
        chain.reverse()                  # Wurzel zuerst
        _cache[leaf_id] = chain
        return chain

    return _chain
```

Beim ersten Auflösen einer Blattkategorie wird die vollständige Kette berechnet und gecacht. Jeder nachfolgende Aufruf für dieselbe ID — und in der Praxis erscheinen dieselben Kategorien tausende Male — kehrt sofort zurück.

Ein fiktives Beispiel der in jede Variante injizierten Kategorieinformation:

```json
"categoryInfo": {
  "rootCategory":     { "id": 1, "name": "Elektronik" },
  "levelOneCategory": { "id": 42, "name": "Audio" },
  "levelTwoCategory": { "id": 137, "name": "Kopfhörer" },
  "leafCategory":     { "id": 982, "name": "Over-Ear-Kopfhörer" },
  "fullChain": [
    { "id": 1,   "name": "Elektronik" },
    { "id": 42,  "name": "Audio" },
    { "id": 137, "name": "Kopfhörer" },
    { "id": 982, "name": "Over-Ear-Kopfhörer" }
  ]
}
```

### ThreadPoolExecutor für parallele Anreicherung

Die Anreicherung ist CPU-gebunden (JSON-Parse + Transformation) und I/O-gebunden (Lesen einer großen Datei). Ein `ThreadPoolExecutor` überlappet beides — während eine Charge von Zeilen von Workern verarbeitet wird, lädt der Datei-Leser bereits die nächste Charge:

```python
_MAX_WORKERS = min(4, os.cpu_count() or 2)
_CHUNK_SIZE  = 500      # Zeilen pro Worker-Task
_PREFETCH    = _MAX_WORKERS * 4

with ThreadPoolExecutor(max_workers=_MAX_WORKERS) as pool:
    for _ in range(_PREFETCH):
        if not _submit_next():
            break

    for fut in as_completed(futures):
        del futures[fut]
        lines_out, wc = fut.result()
        buf.extend(lines_out)
        if len(buf) >= _WRITE_BATCH:
            fout.write(b"\n".join(buf) + b"\n")
            buf.clear()
        _submit_next()   # Threads beschäftigt halten während wir die Queue leeren
```

Das `_PREFETCH`-Fenster hält alle Worker-Threads beschäftigt, anstatt auf den Haupt-Thread zu warten, der ihnen eine Charge nach der anderen zuführt.

### Schreib-Batching

Anstatt eine Zeile nach der anderen zu schreiben (was das Dateisystem belastet), werden Zeilen in einem Puffer gesammelt und alle 10.000 Einträge geleert:

```python
_WRITE_BATCH = 10_000

if len(buf) >= _WRITE_BATCH:
    fout.write(b"\n".join(buf) + b"\n")
    buf.clear()
```

---

## Schritt 3 — Zippen und Aufräumen

Die finale angereicherte Datei wird mit `ZIP_DEFLATED` Kompressionsstufe 6 gezippt — eine gute Balance zwischen Kompressionsverhältnis und Geschwindigkeit. Zwischendateien (`filtered_variants.json`, `enriched_variants.json`) werden nach dem Zippen gelöscht.

Die Quell-Variantendatei wird nie gelöscht — nur Dateien, die die Pipeline selbst erstellt hat.

---

## Die Kommandozeile

Die Pipeline wird vollständig über die Kommandozeile gesteuert, ohne Konfigurationsdateien:

```bash
# Gefilterter Modus — 200 Produkte aus einer Excel-Liste
python run_pipeline.py \
  --excel meine_produkte.xlsx \
  --sftp-host sftp.beispiel.de \
  --sftp-user katalog-nutzer \
  --sftp-variants variants_FULL.json.gz \
  --sftp-labels labels_FULL.json.gz \
  --sftp-categories categories_FULL.json.gz \
  --output-dir output/

# Vollständiger Modus — alles anreichern
python run_pipeline.py \
  --no-filter \
  --variants variants_FULL.json \
  --labels labels_FULL.json \
  --categories categories_FULL.json \
  --output-dir output/
```

Steuerungsflags ermöglichen das Überspringen einzelner Schritte während der Entwicklung:

```bash
--skip-filter        # bestehende filtered_variants.json wiederverwenden
--skip-enrich        # Anreicherung komplett überspringen
--skip-labels        # nur Kategorieanreicherung durchführen
--skip-categories    # nur Label-Anreicherung durchführen
--max-matches 100    # nach N Treffern früh stoppen (zum Testen)
```

---

## Performance-Entscheidungen

Alles in der Pipeline ist auf Durchsatz bei großen Dateien optimiert:

**orjson statt stdlib json.** `orjson` ist beim Parsen und Serialisieren 3–5x schneller. Bei einer Datei mit hunderttausenden von Zeilen ist das ein spürbarer Unterschied in der Wanduhrzeit. Es gibt nativ `bytes` zurück, was auch den Encode/Decode-Overhead beim Schreiben von Text vermeidet.

**256 MB Lesepuffer.** Die Variantendatei wird mit `buffering=256*1024*1024` gelesen. Das reduziert die Anzahl der System-Calls, die das Betriebssystem durchführen muss, und hält den Durchsatz sowohl auf Festplatten als auch auf netzwerkgestütztem Speicher hoch.

**Byte-Level-GTIN-Extraktion.** Für den GTIN-Filter wird der Feldwert aus den rohen Bytes extrahiert, ohne das JSON zu parsen. Da die meisten Zeilen nicht übereinstimmen werden, vermeidet das die Kosten eines vollständigen `orjson.loads()` für jede nicht-treffende Zeile.

**Memoisierte Kategorienketten.** Ohne den Cache würde ein Katalog, bei dem 80% der Produkte zu 20% der Kategorien gehören, dieselben Ketten hunderttausende Male durchlaufen. Mit dem Cache wird jede eindeutige Kette genau einmal durchlaufen.

---

## Was ich heute anders machen würde

Die Pipeline funktioniert gut als lokales Werkzeug. Für einen Produktionsdienst würde ich einige Dinge ändern:

**Der GTIN-Schlüssel ist hart kodiert** (`demo-gtin-code` in diesem Artikel — was auch immer das reale Äquivalent in Ihrem eigenen PIM-Export ist). In einem allgemeineren Werkzeug sollte er ein konfigurierbarer Parameter sein oder aus den Daten ermittelt werden, statt als Konstante im Code vergraben zu sein.

**Kein Retry bei Anreicherungsfehlern.** Wenn eine Zeile während der Anreicherung nicht geparst werden kann, wird sie still übersprungen. Eine Dead-Letter-Queue oder zumindest eine Anzahl übersprungener Zeilen im Log würde Datenqualitätsprobleme sichtbar machen.

**Die ThreadPoolExecutor-Begrenzung auf 4 Worker** ist konservativ. Auf einem Rechner mit vielen Kernen und einer SSD würde das Erhöhen auf 8 oder 16 Worker und die Vergrößerung von `_CHUNK_SIZE` den Durchsatz wahrscheinlich weiter verbessern. Die aktuellen Werte wurden für eine Standard-Büro-Workstation gewählt.

**Keine Unit-Tests.** Die Filter- und Anreicherungslogik ist in reinen Funktionen gut eingekapselt — es wäre einfach, parametrisierte Tests sowohl für den SKU- als auch den GTIN-Pfad und für den Kategorienketten-Resolver zu schreiben. Das hätte von Anfang an getan werden sollen.

---

## Lessons Learned

Die wichtigste Erkenntnis aus diesem Projekt klingt offensichtlich, ist aber unter Zeitdruck leicht zu vergessen: **Messen vor dem Optimieren, und die richtige Datenstruktur für das Zugriffsmuster wählen.**

Die erste Version des GTIN-Filters parste jede JSON-Zeile vollständig, bevor er die GTIN prüfte. Das war korrekt, aber langsam. Der Wechsel zur Byte-Level-Teilstring-Suche änderte das Performance-Profil grundlegend — die meisten Zeilen müssen überhaupt nicht geparst werden. Der memoisierte Kategorienketten-Resolver hatte denselben Effekt auf den Anreicherungsschritt: Die erste Version durchlief jede Kette für jede Variante neu, was korrekt, aber unnötig aufwändig war.

Beide Verbesserungen entstanden aus derselben Frage: Was muss der Algorithmus pro Zeile tatsächlich tun, und was kann er vermeiden?

Diese Frage lohnt es sich, zu Beginn jeder Datenpipeline zu stellen — nicht erst nach dem ersten Profiling-Lauf.
