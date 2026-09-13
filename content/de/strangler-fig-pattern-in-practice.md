---
title: "Das Strangler-Fig-Pattern in der Praxis: Eine Legacy-Pricing-Engine ablösen, ohne einen Big-Bang-Rewrite"
date: "2026-06-22"
description: "Wie eine Facade-und-Redirect-Strategie eine 12 Jahre alte Pricing-Monolith schrittweise ablöste, während der Checkout durchgehend online blieb."
tags: ["Architektur", "Microservices", "Java", "Quarkus", "Legacy-Migration"]
image: "/stranglerFig.jpeg"
featured: true
---

## Das Problem mit "wir schreiben es einfach neu"

Jede gewachsene Plattform sammelt früher oder später so einen Dienst an: zu wichtig, um ihn anzufassen, und zu alt, um ihm zu vertrauen. Stellen wir uns dafür die Pricing- und Angebots-Engine eines B2B-Marktplatzes vor — eine einzelne Java-Monolith-Anwendung, die über mehr als ein Jahrzehnt gewachsen ist. Sie berechnete Preise, wendete Rabattregeln an, prüfte Lagerbestände und versorgte jede Produktseite und jeden Checkout-Flow der Plattform. Niemand verstand sie mehr vollständig. Aber alle waren von ihr abhängig.

Der erste Reflex in so einer Situation ist immer derselbe: Feature-Arbeit einfrieren, sechs Monate in einen ordentlichen Rewrite stecken, dann an einem Freitagabend umschalten. Das geht fast nie gut aus. Big-Bang-Rewrites scheitern nach einem vorhersehbaren Muster — das alte System entwickelt sich während der Neuentwicklung weiter, der Umschalttermin verschiebt sich, und in der Nacht, in der endlich umgeschaltet wird, bricht alles gleichzeitig zusammen, ohne einen sicheren Weg zurück.

Martin Fowler hat vor Jahren einen besseren Weg dafür benannt: das **Strangler-Fig**-Pattern, benannt nach der Würgefeige, die einen Wirtsbaum umwächst und nach und nach dessen Struktur übernimmt, bis der ursprüngliche Baum nicht mehr gebraucht wird. Übertragen auf Software heißt das: Man ersetzt das Altsystem nicht in einem Schritt. Man baut die Ablösung *um* es herum, leitet Traffic auf die neuen Teile, sobald sie sich bewährt haben, und lässt das alte System schrumpfen, bis nichts mehr übrig ist, das man stilllegen müsste.

## Zuerst die Facade bauen

Der erste Arbeitsschritt war keine einzige Zeile neuer Fachlogik. Es war eine Routing-Schicht — eine dünne Facade vor dem Monolithen, durch die ab sofort jeder Aufrufer ging, obwohl sie am ersten Tag 100 % des Traffics unverändert an das Altsystem weiterleitete.

Das wirkt nach verschwendeter Arbeit, ist aber der eigentliche Punkt. Mit dieser Facade entsteht eine Nahtstelle: ein einziger Ort, an dem entschieden wird, welche Implementierung eine Anfrage beantwortet. Alles, was dahinter liegt, muss das weder wissen noch sich darum kümmern.

```
Client → Facade (Routing-Regeln) → Legacy-Pricing-Monolith
                ↓ (Umschaltung je Endpunkt, je Händler, je %)
         Neuer Quarkus-Pricing-Service
```

Die Facade traf Routing-Entscheidungen entlang dreier Achsen: nach Endpunkt (zuerst nur lesende Preisabfragen, der Checkout blieb unangetastet, bis genug Vertrauen aufgebaut war), nach Händlersegment (zuerst eine Handvoll risikoarmer Pilot-Händler) und nach Prozentsatz (ein einfacher Canary-Split, der von 1 % bis 100 % hochgedreht werden konnte).

## Eine Scheibe nach der anderen migrieren

Mit dieser Nahtstelle wurde die eigentliche Migration zu einer Abfolge kleiner, reversibler Schritte statt eines einzigen, unumkehrbaren Sprungs:

1. **Lesende Preisabfragen** zogen zuerst um. Geringes Risiko — wenn der neue Service einen falschen Preis lieferte, wurde nirgendwo etwas geschrieben, und der Schaden blieb auf eine falsche Zahl auf einer Seite begrenzt, nicht auf eine kaputte Bestellung.
2. **Die Auswertung der Rabattregeln** folgte als Nächstes, abgesichert durch eine Schattenverkehr-Phase: Der neue Service berechnete eine Antwort parallel zum alten, beide Ergebnisse wurden verglichen und protokolliert, ohne dass das neue Ergebnis je tatsächlich ausgeliefert wurde. Wochenlanger stiller Vergleich brachte Randfälle ans Licht — Währungsrundung, abgelaufene Aktionscodes, gestapelte Rabatte — bevor ein einziger echter Kunde den neuen Codepfad zu sehen bekam.
3. **Lagerbestandsabhängiges Pricing**, der riskanteste Teil, weil er Schreibzugriffe betraf, zog zuletzt um, und erst nachdem die ersten beiden Scheiben einen vollen Verkaufszyklus lang bei 100 % auf dem neuen Service liefen.

Jede Scheibe folgte demselben Rhythmus: eigenständig im neuen Quarkus-Service bauen, gegen den Monolithen im Schatten laufen lassen, den Canary-Prozentsatz schrittweise erhöhen und erst danach die Standard-Route der Facade umstellen.

## Was den Rollback günstig hielt

Diese Strategie funktioniert nur, wenn der Weg zurück genauso einfach ist wie der Weg vorwärts. Zwei Dinge sorgten dafür:

- **Die Routing-Tabelle der Facade war Konfiguration, kein Code.** Eine Route zurück auf den Legacy-Monolithen umzustellen war eine Konfigurationsänderung und ein Deployment der Facade allein — nie ein Deployment der Fachlogik auf einer der beiden Seiten.
- **Der Legacy-Monolith wurde nie angefasst.** Kein Code wurde eingefroren, kein halb fertiges Refactoring lag halb migriert darin. Er tat weiterhin genau das, was er immer getan hatte, für genau den Traffic, der noch auf ihn zeigte. Das bedeutete: Bis zum Tag der endgültigen Stilllegung gab es immer einen bekannt funktionierenden Rückfallpfad.

## Der Teil, über den niemand spricht: Der Monolith stirbt nicht leise

Der schwierigste Teil dieser Art von Migration ist meist nicht der neue Code — es ist die Bestätigung, dass alter Code wirklich, tatsächlich nicht mehr genutzt wird. Vermeintlich tote Codepfade in einem zehn Jahre alten Monolithen sind selten wirklich tot; oft werden sie durch einen Quartalsjob, eine Randfall-Konfiguration eines Händlers oder eine Integration ausgelöst, die niemand mehr dokumentiert hat.

Die praktische Antwort darauf war unspektakulär, aber wirksam: die verbleibenden Einstiegspunkte des Monolithen mit Logging instrumentieren, bevor irgendetwas entfernt wird, dieses Logging mindestens einen vollen Geschäftszyklus laufen lassen (um Quartals- und Saisonjobs zu erfassen), und nur Code löschen, der über dieses gesamte Fenster null Treffer erzeugt hat. Mehrere "offensichtlich ungenutzte" Codepfade erwiesen sich dabei als ziemlich lebendig.

## Warum sich das lohnt, auch wenn es langsamer aussieht

Eine Strangler-Fig-Migration dauert insgesamt länger, als ein Rewrite-und-Umschalt-Plan auf einer Folie suggeriert. Was man dafür bekommt:

- Das System in Produktion ist *jederzeit* auslieferbar — es gibt keine monatelange Phase, in der weder das alte noch das neue System vollständig vertrauenswürdig ist.
- Jede Scheibe ist klein genug, um sie zu verstehen, zu testen und unabhängig zurückzurollen.
- Vertrauen wird in Produktion mit echtem Traffic verdient, bevor das Sicherheitsnetz entfernt wird — nicht in einer Staging-Umgebung kurz vor dem Umschalttermin angenommen.

Das Pattern nimmt einer Migration kein Risiko. Es weigert sich nur, dieses Risiko an einem einzigen Tag zu tragen.
