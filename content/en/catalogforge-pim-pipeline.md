---
title: "CatalogForge — Building a PIM Data Pipeline That Actually Handles Scale"
description: "How I built a Python pipeline to filter, enrich, and package large PIM variant exports — with SFTP download, Excel-driven filtering by SKU or EAN, category tree resolution, and threaded enrichment using orjson."
date: "2026-01-15"
image: "catalogForge.jpeg"
tags: [Python, PIM, Data Pipeline, orjson, SFTP, E-Commerce]
---

# CatalogForge — Building a PIM Data Pipeline That Actually Handles Scale

## The Problem

Every large e-commerce operation eventually faces the same unglamorous challenge: the product catalog is a mess. Not because nobody cared, but because data accumulates. Variants multiply. Attribute keys get added by different teams over different years. Category trees grow sideways. And when you need a clean, enriched, filtered subset of that catalog for a downstream system — a search engine, a marketplace feed, a data warehouse — you discover that the raw export is a multi-gigabyte NDJSON file that no spreadsheet will open and no naive script will process in reasonable time.

That was the situation I was working in. The PIM system exported variants as newline-delimited JSON. Hundreds of thousands of records. Labels stored separately in a lookup file. Categories in a tree structure that needed to be walked from leaf to root for every product. And the team needed to be able to say: "give me the enriched data for these 200 EANs" — from an Excel file, in minutes, reliably.

So I built CatalogForge.

> Note: all attribute keys, field names, and data shown in this article are invented for illustration. They do not reflect the actual schema of any system I have worked with.

---

## What It Does

The pipeline has four steps, each clearly separated:

```
Step 0  SFTP download + .gz decompression   (if remote source configured)
Step 1  Filter variants by SKU or GTIN/EAN  (or pass all through)
Step 2  Enrich: add labels + category tree in one single pass
Step 3  Zip output + clean up intermediates
```

Two modes cover the two real use cases:

**Full-file mode** — enrich the entire variants export as-is. No filtering. Useful for a nightly refresh of the full catalog.

**Filtered mode** — provide an Excel file with a list of GTINs or SKUs in column A. The pipeline extracts exactly those variants from the full file, enriches them, and delivers a zip. Useful for ad-hoc requests, QA, and marketplace subset feeds.

---

## Step 0 — SFTP with Smart Caching

The source files live on a remote SFTP server as gzip-compressed JSON. The download step is not simply "fetch the file" — it compares the remote file's modification time against the local cache:

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

If the local cache is current, the download is skipped entirely. On a large file this saves minutes per run. The download itself writes to a `.tmp` file first and only renames to the final path on success — so a failed or interrupted download never leaves a corrupt cache file that would silently produce wrong results on the next run.

Decompression uses a 4 MB copy buffer:

```python
with gzip.open(gz_path, "rb") as f_in, open(out_path, "wb") as f_out:
    shutil.copyfileobj(f_in, f_out, length=4 * 1024 * 1024)
```

The `.gz` is deleted immediately after decompression — no double-storage of large files.

---

## Step 1 — Filtering by SKU or GTIN

The pipeline auto-detects which type of identifier is in the Excel column:

```python
def _detect_mode(excel_file) -> str:
    df = pd.read_excel(excel_file, usecols=[0], dtype=str, nrows=20)
    for val in df.iloc[:, 0].dropna():
        val = str(val).strip()
        if val:
            mode = "sku" if val.upper().startswith("V") else "gtin"
            return mode
```

If the first value starts with "V" it is a SKU. Otherwise it is a GTIN. No configuration needed — just drop the Excel file in.

### SKU filtering

Simple and fast. Load the ID set into memory, scan every line, emit matches:

```python
ids = set(df.iloc[:, 0].dropna().astype(str).str.strip())

for raw_line in fin:
    item = orjson.loads(raw_line)
    if str(item.get("_id", "")).strip() in ids:
        buf.append(orjson.dumps(item))
```

### GTIN filtering — the interesting part

GTINs have a problem: leading zeros. `0123456789012` and `123456789012` are the same product but different strings. A naive string comparison would miss half the matches.

The solution is to normalise both sides before comparing. And because parsing every JSON line for a GTIN lookup would be slow, the GTIN is extracted with a targeted bytes search rather than a full parse:

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

The field key here — `demo-gtin-code` — is just a placeholder; the real key depends entirely on whatever schema your own PIM export uses. The byte search finds the field directly in the raw line, extracts the value without parsing the entire JSON object, normalises the leading zeros away, and checks against the normalised set from Excel. Only on a match does the line get fully parsed with `orjson`. This keeps the cost of scanning millions of non-matching lines as low as possible.

---

## Step 2 — Enrichment in a Single Pass

The raw variant data is missing two things that downstream systems need:

1. **Human-readable labels** for attribute keys (the raw data has opaque keys like `demo-color-code`; the label file maps these to `"Farbe"`)
2. **Category hierarchy** resolved from a flat category tree (the raw data has a leaf category ID; downstream systems need the full path from root)

Both enrichments happen in one pass over the data — one read, one write.

### Label lookup

Labels are loaded into a plain dict once at the start:

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

During enrichment, each attribute in a variant gets its German label injected:

```python
for attr in item.get("attributes", []):
    k = attr.get("key")
    attr["label_de"] = label_lookup.get(k, "") if k else ""
```

A dummy example of what a variant attribute looks like before and after:

```json
// Before enrichment
{ "key": "demo-color-code", "values": [{ "value": "Blau" }] }

// After enrichment
{ "key": "demo-color-code", "values": [{ "value": "Blau" }], "label_de": "Farbe" }
```

### Category tree resolution — with memoisation

The category tree is the expensive part. Each variant has a leaf category ID. To know the full path — root → department → subcategory → leaf — you have to walk the tree upwards through parent references. On a large file this could mean walking the same popular category thousands of times.

The solution is a memoised resolver built as a closure:

```python
def _build_chain_fn(lookup: dict[int, dict]):
    _cache: dict[int, list] = {}

    def _chain(leaf_id: int) -> list:
        if leaf_id in _cache:
            return _cache[leaf_id]
        chain, current, visited = [], leaf_id, set()
        while current is not None:
            if current in visited:
                break                    # cycle guard
            visited.add(current)
            cat = lookup.get(current)
            if cat is None:
                break
            chain.append(cat)
            p = cat.get("parentId")
            current = int(p) if p is not None else None
        chain.reverse()                  # root first
        _cache[leaf_id] = chain
        return chain

    return _chain
```

The first time a leaf category is resolved, the full chain is computed and cached. Every subsequent call for the same ID — and in practice the same categories appear thousands of times — returns instantly.

A dummy example of the category info injected into each variant:

```json
"categoryInfo": {
  "rootCategory":     { "id": 1, "name": "Electronics" },
  "levelOneCategory": { "id": 42, "name": "Audio" },
  "levelTwoCategory": { "id": 137, "name": "Headphones" },
  "leafCategory":     { "id": 982, "name": "Over-Ear Headphones" },
  "fullChain": [
    { "id": 1,   "name": "Electronics" },
    { "id": 42,  "name": "Audio" },
    { "id": 137, "name": "Headphones" },
    { "id": 982, "name": "Over-Ear Headphones" }
  ]
}
```

### ThreadPoolExecutor for parallel enrichment

Enrichment is CPU-bound (JSON parse + transform) and I/O-bound (reading a large file). A `ThreadPoolExecutor` overlaps the two — while one batch of lines is being processed by workers, the file reader is already loading the next batch:

```python
_MAX_WORKERS = min(4, os.cpu_count() or 2)
_CHUNK_SIZE  = 500     # lines per worker task
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
        _submit_next()   # keep threads busy as we drain
```

The `_PREFETCH` window keeps all worker threads busy rather than waiting for the main thread to feed them one chunk at a time.

### Write batching

Rather than writing one line at a time (which hammers the filesystem), lines are accumulated in a buffer and flushed every 10,000 entries:

```python
_WRITE_BATCH = 10_000

if len(buf) >= _WRITE_BATCH:
    fout.write(b"\n".join(buf) + b"\n")
    buf.clear()
```

---

## Step 3 — Zip and Clean Up

The final enriched file is zipped with `ZIP_DEFLATED` compression level 6 — a good balance between compression ratio and speed. Intermediate files (`filtered_variants.json`, `enriched_variants.json`) are deleted after zipping.

The source variants file is never deleted regardless — only files the pipeline created itself.

---

## The CLI

The pipeline is fully command-line driven with no config files:

```bash
# Filtered mode — 200 products from an Excel list
python run_pipeline.py \
  --excel my_products.xlsx \
  --sftp-host sftp.example.com \
  --sftp-user catalog-user \
  --sftp-variants variants_FULL.json.gz \
  --sftp-labels labels_FULL.json.gz \
  --sftp-categories categories_FULL.json.gz \
  --output-dir output/

# Full-file mode — enrich everything
python run_pipeline.py \
  --no-filter \
  --variants variants_FULL.json \
  --labels labels_FULL.json \
  --categories categories_FULL.json \
  --output-dir output/
```

Control flags let you skip individual steps during development:

```bash
--skip-filter      # reuse existing filtered_variants.json
--skip-enrich      # skip enrichment entirely
--skip-labels      # only do category enrichment
--skip-categories  # only do label enrichment
--max-matches 100  # stop early after N matches (testing)
```

---

## Performance Decisions

Everything in the pipeline is optimised for throughput on large files:

**orjson instead of stdlib json.** `orjson` is 3–5x faster at both parsing and serialising. On a file with hundreds of thousands of lines this is a meaningful wall-clock difference. It returns `bytes` natively which also avoids the encode/decode overhead of writing text.

**256 MB read buffer.** The variants file is read with `buffering=256*1024*1024`. This reduces the number of system calls the OS needs to make and keeps throughput high on spinning disks and network-backed storage alike.

**Byte-level GTIN extraction.** For the GTIN filter, the field value is extracted from the raw bytes without parsing the JSON. Since most lines will not match, this avoids the cost of a full `orjson.loads()` on every non-matching line.

**Memoised category chains.** Without the cache, a catalog where 80% of products belong to 20% of categories would walk the same chains hundreds of thousands of times. With the cache, each unique chain is walked exactly once.

---

## What I Would Do Differently

The pipeline works well as a local tool. For a production service there are a few things I would change:

**The GTIN key is hardcoded** (`demo-gtin-code` in this writeup — whatever the real equivalent is in your own PIM export). In a more general tool it should be a configurable parameter or discoverable from the data, not a constant buried in the code.

**No retry on enrichment failure.** If a line fails to parse during enrichment, it is silently skipped. A dead-letter queue or at minimum a count of skipped lines in the log would make data quality issues visible.

**The ThreadPoolExecutor cap at 4 workers** is conservative. On a machine with many cores and an SSD, pushing to 8 or 16 workers and increasing `_CHUNK_SIZE` would likely improve throughput further. The current values were chosen for a standard office workstation.

**No unit tests.** The filtering and enrichment logic is well-contained in pure functions — it would be straightforward to write parametrised tests for both the SKU and GTIN paths and for the category chain resolver. That should have been done from the start.

---

## Lessons Learned

The most important lesson from this project is one that sounds obvious but is easy to forget under deadline pressure: **measure before you optimise, and choose the right data structure for the access pattern**.

The initial version of the GTIN filter parsed every JSON line fully before checking the GTIN. It was correct but slow. Moving to the byte-level substring search changed the performance profile entirely — most lines never need to be parsed at all. The memoised category chain resolver had the same effect on the enrichment step: the first version re-walked every chain on every variant, which was correct but needlessly expensive.

Both improvements came from asking the same question: what does the algorithm actually need to do per line, and what can it avoid doing?

That question is worth asking at the start of every data pipeline, not after the first profiling run.
