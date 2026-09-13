---
title: "Eine Best-Offer-View unter Crawler-Last frisch halten: CQRS, Read-Replicas und der Blue-Green-Swap"
date: "2026-06-22"
description: "Wie das Trennen von Schreib- und Lesepfaden und ein Tabellen-Swap statt In-Place-Update Preise und Bestände auf einem stark gecrawlten Produktkatalog frisch hielten."
tags: ["Architektur", "CQRS", "Materialized Views", "PostgreSQL", "Quarkus", "Performance"]
image: "/bestOfferView.jpeg"
featured: true
---

## Die Ausgangslage

Man stelle sich eine Preisvergleichsplattform vor — nennen wir sie Compendia —, die live Preis- und Bestandsfeeds von Dutzenden Handelspartnern zusammenführt und Kunden ein einziges "Bestangebot" pro Produkt zeigt: niedrigster Preis, aktuell verfügbar, jetzt gerade.

Dieses "Beste von 40 Angeboten" bei jedem einzelnen Seitenaufruf neu zu berechnen, wäre teuer — bei einem stark frequentierten Produkt bedeutet das 40 Zeilen scannen, filtern und ranken, pro Anfrage, den ganzen Tag über. Stattdessen baut ein Hintergrundjob eine `BestOfferView`: eine materialisierte View, die das Gewinner-Angebot für jedes Produkt vorab berechnet und alle 5 bis 10 Minuten aktualisiert wird. Produktseiten lesen einfach daraus. Schnell, günstig, einfach — bis zwei Arten von Traffic anfangen, sich um dieselbe Tabelle zu streiten.

## Zwei Lastarten, eine Tabelle

Der erste Druck kommt von **Schreibzugriffen**. Partner-Feeds liefern fortlaufend Preis- und Bestandsänderungen — ein Partner senkt den Preis, ist ausverkauft, füllt wieder auf — und jede dieser Änderungen kann verändern, wer aktuell "gewinnt". Der Refresh-Job muss diese Veränderungen aufnehmen und die View neu aufbauen.

Der zweite Druck kommt von **Lesezugriffen** — und nicht von der erwarteten Art. Compendia ist SEO-getrieben, daher werden die Produktseiten aggressiv von Suchmaschinen-Bots gecrawlt. Crawler browsen nicht wie Menschen; sie treffen Tausende von Produkt-URLs in dichten Bursts, oft mit erneutem Crawling derselben Seiten innerhalb weniger Minuten. Diese Leselast landet auf genau derselben Tabelle, die der Refresh-Job gerade neu aufbaut.

Beide auf derselben Tabelle, und das Fehlerbild ist vorhersehbar: Ein Refresh, der einige Hunderttausend Zeilen betrifft, dauert ein paar Sekunden länger als gewöhnlich, weil ein Crawler-Burst mitten im Scan steckt, der nächste Refresh-Zyklus startet verspätet, echte Kunden sehen plötzlich einen Preis, der zehn bis fünfzehn Minuten statt fünf veraltet ist, und an einem schlechten Tag wird aus "ein paar Sekunden länger" durch Lock-Contention ein vollständiges Query-Timeout. Die beiden Traffic-Muster waren nie dafür gedacht, zu interagieren — aber sie teilten sich eine Ressource, die diese Interaktion unvermeidlich machte.

## Die Lösung: die Ressource nicht mehr teilen

Der erste Reflex wäre, die Crawler zu drosseln oder die Refresh-Query zu optimieren. Beides hilft ein wenig. Keines löst den eigentlichen Konstruktionsfehler: Eine einzelne Tabelle sollte gleichzeitig Schreibziel und Leseziel für zwei Workloads mit völlig unterschiedlicher Charakteristik sein.

**CQRS** — Command Query Responsibility Segregation — ist hier das relevante Konzept: das Modell, das Schreibzugriffe aufnimmt, vom Modell trennen, das Lesezugriffe bedient, sodass keines für das andere Kompromisse eingehen muss.

```
Partner-Feeds → Ingestion-Pipeline → Schreibseitige Staging-Tabellen
                                            ↓ (Refresh-Job, alle 5-10 Min)
                                     BestOfferView (Schatten-Build)
                                            ↓ (atomarer Swap)
Kunden + Crawler → Read-Replica → BestOfferView (live)
```

Konkret bedeutete das zwei Änderungen:

1. **Lesezugriffe zogen auf eine Replica um.** Crawler und Kunden lesen nicht mehr von derselben Primärinstanz, gegen die der Refresh-Job schreibt. Eine Read-Replica nimmt den unvorhersehbaren, stoßweisen Crawl-Traffic auf, und ein langsamer Crawler-Burst auf der Replica hat null Auswirkung darauf, wie schnell die Primärinstanz die View neu aufbauen kann.
2. **Der Refresh aktualisiert nicht mehr in-place.** Statt Zeilen in der lebenden `BestOfferView` per `UPDATE` zu ändern — wodurch Leser und Schreiber mitten im Rebuild um dieselben Zeilen konkurrieren —, baut der Job die *nächste* Version der View als separate Schatten-Tabelle, vollständig berechnet und indiziert, bevor sie irgendjemand sieht, und führt dann in einer einzigen Transaktion einen atomaren Swap durch (alt → Archiv, neu → live). Leser sehen entweder die vollständig alte oder die vollständig neue View. Nie eine halb fertige, und nie blockieren sie dahinter.

## Warum Swap-statt-Update der eigentlich entscheidende Teil ist

Die Replica schafft Spielraum; der Swap entfernt die Contention vollständig. Ein In-Place-Refresh und ein Live-Read stehen strukturell im Konflikt — sie wollen per Definition dieselben Row-Locks zur gleichen Zeit. Ein Schatten-Build-mit-anschließendem-Swap macht aus diesem Konflikt zwei unabhängige Vorgänge: Der Aufbau der neuen View berührt nicht, was Leser gerade nutzen, und der Swap selbst ist schnell genug (ein Rename, kein zeilenweises Update), dass selbst im Moment der Umschaltung kein nennenswertes Contention-Fenster entsteht.

Das hat dieselbe Form wie ein Blue-Green-Deployment, nur angewendet auf eine Tabelle statt auf eine Flotte von Anwendungsservern: die neue Version vollständig neben der alten aufbauen, verifizieren, dann einen einzelnen Zeiger umlegen. Sieht nach dem Swap etwas falsch aus — etwa weil ein fehlerhafter Partner-Feed offensichtlich falsche Preise erzeugt hat —, ist das Zurückspringen zur archivierten Vorgängerversion derselbe Ein-Transaktions-Vorgang, nur umgekehrt.

## Der Validierungsschritt, den man leicht überspringt

Vor jedem Swap wird die Schatten-Tabelle gegen ein paar Plausibilitätsregeln geprüft: Kein Produkt sollte sein Bestangebot komplett verlieren, außer wirklich alle Partner sind ausverkauft; kein Preis sollte sich ohne erkennbaren Grund im Quell-Feed über eine bestimmte Schwelle hinaus bewegt haben; und die Zeilenzahl sollte zwischen zwei Refreshs nicht wild schwanken. Nichts davon ist besonders raffiniert — meist reine Grenzwertprüfung —, aber genau das fängt einen fehlerhaften Upstream-Feed ab, bevor er zu einem falschen Preis auf einer Live-Produktseite wird, statt erst danach.

## Was das nicht gelöst hat, und was es gelöst hat

Das hat die Crawler nicht höflicher gemacht, und es hat die zugrunde liegende "Bestes von 40 Angeboten"-Berechnung nicht günstiger gemacht. Was es bewirkt hat: zwei voneinander unabhängige Traffic-Muster mussten sich nicht mehr einen Lock teilen. Lesezugriffe wurden schneller und konsistenter, weil sie nicht mehr auf Schreibzugriffe warteten. Refreshs wurden vorhersehbarer, weil sie nicht mehr auf Lesezugriffe warteten. Und weil der Swap atomar ist, gab es den Zustand "die View wird gerade neu aufgebaut" für Kunden oder Crawler überhaupt nicht mehr zu beobachten.

Die Lehre daraus geht über materialisierte Views hinaus: Sobald eine einzelne Tabelle gleichzeitig das Ziel von Schreibzugriffen und das Ziel des unvorhersehbarsten, lautesten Lese-Traffics sein soll, wird genau diese Tabelle der Ort, an dem eigentlich unzusammenhängende Probleme aufeinandertreffen. Die beiden Pfade zu trennen ist keine reine Performance-Optimierung — es entfernt einen Zufall, der nie tragend sein sollte.
