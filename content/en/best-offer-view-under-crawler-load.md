---
title: "Keeping a Best-Offer View Fresh Under Crawler Load: CQRS, Read Replicas, and the Blue-Green Swap"
date: "2026-06-22"
description: "How separating writes from reads, and swapping tables instead of updating in place, kept price and stock data fresh on a heavily-crawled product catalog."
tags: ["Architecture", "CQRS", "Materialized Views", "PostgreSQL", "Quarkus", "Performance"]
image: "/bestOfferView.jpeg"
featured: true
---

## The setup

Picture a price-comparison platform — call it Compendia — that aggregates live price and stock feeds from dozens of retail partners and shows shoppers a single "best offer" per product: lowest price, currently in stock, right now.

Computing that "best of 40 offers" answer on every single page load would be expensive — for a busy product, that's 40 rows scanned, filtered, and ranked, per request, all day. So instead, a background job builds a `BestOfferView`: a materialized view that pre-computes the winning offer for every product, refreshed every 5 to 10 minutes. Product pages just read from it. Fast, cheap, simple — until two kinds of traffic start fighting over the same table.

## Two pressures, one table

The first pressure is **writes**. Partner feeds push price and stock updates continuously — a partner drops a price, sells out, restocks — and every one of those updates is a candidate for changing who currently "wins" a product. The refresh job has to pick up that churn and rebuild the view.

The second pressure is **reads** — and not the kind you'd expect. Compendia is SEO-driven, so its product pages get crawled aggressively by search bots. Crawlers don't browse like humans; they hit thousands of product URLs in tight bursts, often re-crawling the same pages within minutes of each other. That read load lands on exactly the same table the refresh job is rebuilding.

Put those two on the same table and the failure mode is predictable: a refresh that touches a few hundred thousand rows takes a few seconds longer than usual because a crawler burst is mid-scan, the next refresh cycle starts late, real shoppers start seeing a price that's ten or fifteen minutes stale instead of five, and on a bad day, lock contention turns "a few seconds longer" into queries timing out altogether. The two traffic patterns weren't designed to interact, but they were sharing a resource that made interaction inevitable.

## The fix: stop sharing the resource

The instinct might be to throttle the crawlers or tune the refresh query. Both help a little. Neither fixes the actual design flaw, which is that one table was being asked to serve as both write target and read target for two workloads with completely different shapes.

**CQRS** — Command Query Responsibility Segregation — is the relevant idea here: separate the model that absorbs writes from the model that serves reads, so neither has to compromise for the other.

```
Partner feeds → Ingestion pipeline → Write-side staging tables
                                            ↓ (refresh job, every 5-10 min)
                                     BestOfferView (shadow build)
                                            ↓ (atomic swap)
Shoppers + Crawlers → Read replica → BestOfferView (live)
```

Concretely, that meant two changes:

1. **Read traffic moved to a replica.** Crawlers and shoppers stopped reading from the same primary that the refresh job writes against. A read replica absorbs the unpredictable, bursty crawl traffic, and a slow crawler burst on the replica has zero effect on how fast the primary can rebuild the view.
2. **The refresh stopped updating in place.** Instead of `UPDATE`-ing rows in the live `BestOfferView` — which means readers and writers contend for the same rows mid-rebuild — the job builds the *next* version of the view as a separate shadow table, fully computed and indexed before anyone sees it, then does an atomic swap (rename old → archive, new → live) in a single transaction. Readers either see the fully-old view or the fully-new view. They never see a half-built one, and they never block behind it.

## Why swap-not-update is the part that actually matters

The replica buys headroom; the swap is what removes the contention entirely. An in-place refresh and a live read are structurally in conflict — they want the same row locks at the same time, by definition. A shadow-build-then-swap turns that conflict into two independent operations: building the new view doesn't touch what readers are using, and the swap itself is fast enough (a rename, not a row-by-row update) that it doesn't create a meaningful contention window even at the moment of cutover.

This is the same shape as a blue-green deployment, just applied to a table instead of a fleet of app servers: build the new version fully alongside the old one, verify it, then flip a single pointer. If anything looks wrong post-swap — a partner feed glitch produced obviously bad prices, say — flipping back to the archived previous version is the same one-transaction operation in reverse.

## The validation step that's easy to skip

Before any swap, the shadow table gets checked against a few sanity rules: no product should have lost its best offer entirely unless every partner genuinely went out of stock, no price should have moved more than some threshold without a clear reason in the source feed, and row counts shouldn't swing wildly between refreshes. None of this is sophisticated — it's mostly bounds-checking — but it's what catches a bad upstream feed before it becomes a wrong price on a live product page instead of after.

## What this didn't fix, and what it did

This didn't make the crawlers more polite, and it didn't make the underlying "best offer across 40 partners" computation cheaper. What it did was stop two unrelated traffic patterns from being forced to share a lock. Reads got faster and more consistent because they stopped waiting on writes. Refreshes got more predictable because they stopped waiting on reads. And because the swap is atomic, "the view is being rebuilt" stopped being a state that shoppers or crawlers could ever observe at all.

The lesson generalizes past materialized views: any time a single table is asked to be both the thing you write into and the thing the busiest, least predictable traffic reads from, that table is going to be the place where unrelated problems collide. Splitting the two paths isn't just a performance optimization — it's removing a coincidence that was never supposed to be load-bearing.
