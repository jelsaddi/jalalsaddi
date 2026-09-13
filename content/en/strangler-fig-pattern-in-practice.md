---
title: "The Strangler Fig Pattern in Practice: Retiring a Legacy Pricing Engine Without a Big-Bang Rewrite"
date: "2026-06-22"
description: "How a facade-and-redirect strategy let a 12-year-old pricing monolith get replaced piece by piece, with checkout never going dark."
tags: ["Architecture", "Microservices", "Java", "Quarkus", "Legacy Migration"]
image: "/stranglerFig.jpeg"
featured: true
---

## The problem with "let's just rewrite it"

Every platform eventually accumulates one of these: a service that's too important to touch and too old to trust. In this case, picture a B2B marketplace's pricing and offer engine — a single Java monolith that had been growing for over a decade. It calculated prices, applied discount rules, checked stock, and fed every product page and checkout flow on the platform. Nobody fully understood all of it anymore. Everybody depended on it.

The instinct in that situation is always the same: freeze feature work, spend six months rewriting it properly, then cut over on a Friday night. It almost never works out that way. Big-bang rewrites have a predictable failure pattern — the old system keeps evolving while you rebuild, the cutover date slips, and the night you finally flip the switch is the night everything breaks at once, with no safe way back.

Martin Fowler named a better way out of this years ago: the **Strangler Fig** pattern, after the vine that grows around a host tree, gradually taking over its structure until the original is no longer needed. Applied to software, the idea is simple — you don't replace the legacy system in one move. You build the replacement *around* it, route traffic to the new pieces as they prove themselves, and let the old system shrink until there's nothing left to retire.

## Building the facade first

The first piece of work wasn't a single line of new business logic. It was a routing layer — a thin facade sitting in front of the monolith that every caller would now go through, even though, on day one, it forwarded 100% of traffic straight to the old system unchanged.

This sounds like wasted effort, but it's the whole point. Once that facade exists, you've created a seam: a single place where you control which implementation answers a given request. Nothing downstream needs to know or care.

```
Client → Facade (routing rules) → Legacy Pricing Monolith
                ↓ (toggle per route, per merchant, per %)
         New Quarkus Pricing Service
```

The facade made routing decisions on three axes: by endpoint (start with read-only price lookups, leave checkout alone until confidence was high), by merchant segment (a handful of low-risk pilot merchants first), and by percentage (a simple canary split that could be dialed from 1% to 100%).

## Migrating one slice at a time

With the seam in place, the actual migration became a sequence of small, reversible steps instead of one irreversible leap:

1. **Read-only price lookups** moved first. Low risk — if the new service got a price wrong, nothing was written anywhere, and the blast radius was a wrong number on a page, not a broken order.
2. **Discount rule evaluation** moved next, behind a shadow-traffic phase: the new service computed an answer in parallel with the old one, and the two were diffed and logged without the new result ever being served. Weeks of silent comparison surfaced edge cases — currency rounding, expired promotion codes, stacked discounts — before a single real customer ever saw the new code path.
3. **Stock-aware pricing**, the riskiest piece because it touched writes, moved last, and only after the first two slices had been running at 100% on the new service for a full sales cycle.

Each slice followed the same rhythm: build it standalone in the new Quarkus service, shadow it against the monolith, dial the canary percentage up gradually, and only then update the facade's default route.

## What made rollback cheap

The entire strategy only works if going backward is as easy as going forward. Two things made that true here:

- **The facade's routing table was config, not code.** Flipping a route back to the legacy monolith was a config change and a redeploy of the facade alone — never a redeploy of the business logic on either side.
- **The legacy monolith was never touched.** No code froze, no half-finished refactor sat half-migrated inside it. It kept doing exactly what it had always done, for exactly the traffic still pointed at it. That meant there was always a known-good fallback, right up until the day it was finally decommissioned.

## The part nobody mentions: the monolith doesn't die quietly

The hardest part of this kind of migration usually isn't the new code — it's confirming when the old code is actually, truly unused. Dead-looking call paths in a decade-old monolith are rarely dead; they're often triggered by a quarterly job, an edge-case merchant configuration, or an integration nobody remembers documenting.

The practical answer was boring but effective: instrument the monolith's remaining entry points with logging before removing anything, leave that logging running for at least one full business cycle (to catch quarterly and seasonal jobs), and only delete code that produced zero hits across that whole window. Several "obviously unused" code paths turned out to be very much alive.

## Why this is worth doing even when it's slower

A Strangler Fig migration takes longer end to end than a rewrite-and-cutover plan looks like it should take on a slide. What it buys in return:

- The system in production is *always* shippable — there's no multi-month state where neither the old nor new system is fully trustworthy.
- Each slice is small enough to reason about, test, and roll back independently.
- Confidence is earned in production, with real traffic, before the safety net is removed — not assumed in a staging environment the week before cutover.

The pattern doesn't remove risk from a migration. It just refuses to take all of it in one sitting.
