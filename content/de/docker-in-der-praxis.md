---
title: "Docker-Container — Entwicklung und Bereitstellung vereinfachen"
description: "Nach vielen Jahren Softwareentwicklung habe ich gelernt: Die interessantesten Projekte sind nicht die perfekten, sondern die, wo man mit der Realität umgehen muss. Docker zeigt seine wahre Stärke nicht in idealen Microservices-Welten, sondern beim Verbinden von Legacy-Systemen mit modernen Architekturen – genau wie Amazon es gemacht hat."
date: "2025-10-14"
image: "dockerContainers.jpeg"
tags: [Docker, DevOps, Microservices]
---

# Docker in der Praxis: Von Legacy zu modernen Microservices


Nach vielen Jahren in der Softwareentwicklung habe ich gelernt: Die interessantesten Projekte sind nicht die, wo alles perfekt und modern ist. Es sind die, wo man mit der Realität umgehen muss – mit gewachsenen Systemen, Legacy-Code und der Herausforderung, Altes und Neues miteinander zu verbinden.

Genau in so einer Welt arbeite ich seit Jahren. Und genau hier zeigt Docker seine wahre Stärke.

## Der Ausgangspunkt: Eine gewachsene Infrastruktur

Vor einigen Jahren sah unsere Entwicklungslandschaft noch klassisch aus:

- **Jenkins** als Build- und Deployment-Tool
- Manuelle Setups für Entwicklungsumgebungen
- Oracle-Datenbanken, die auf jedem Entwicklerrechner anders konfiguriert waren
- Deployments, die funktionierten – aber oft nur nach mehreren Versuchen

Das war nicht schlecht. Es hat funktioniert. Aber es war aufwändig.

## Das erste Docker-Experiment: Oracle DB

Unser erster Berührungspunkt mit Docker war pragmatisch: **Oracle-Datenbank für die Entwicklung.**

Vorher bedeutete Oracle-Setup:

- 2-3 Stunden Installation und Konfiguration
- Unterschiedliche Versionen auf verschiedenen Rechnern
- "Bei mir läuft's" – beim Kollegen nicht

Mit Docker:

```
docker run oracle-db
```

10 Minuten. Gleiche Version überall. Reproduzierbar.

**Das war der Moment, wo ich verstanden habe: Docker löst nicht primär technische Probleme. Es löst menschliche Probleme.**

Neue Entwickler waren produktiv, statt frustriert. Seniors verloren keine Zeit mehr mit Setup-Support. Das allein rechtfertigte den Aufwand.

## Der Wendepunkt: Azure CI/CD und eine komplexe E-Commerce-Architektur

Dann kam der große Schritt: Migration zu Azure DevOps mit einer vollständig containerbasierten CI/CD-Pipeline – und gleichzeitig die Integration einer etablierten E-Commerce-Plattform durch einen Entwicklungspartner.

## Die Herausforderung: Hybrid-Architektur

Große E-Commerce-Plattformen sind über Jahre gewachsen. Das bedeutet auch: **Legacy ist Realität.**

Unsere Architektur heute:

- **Eine etablierte Commerce-Plattform** – bewährt, aber mit älteren Technologien
- **PWA Storefront** – moderne Angular-basierte Progressive Web App
- **Moderne Microservices** – Angebots-Service, Händler-Service, Produkt-Service
- **SPA-basiertes Admin-Portal** – komplett modern entwickelt

Das Interessante: Die PWA sieht modern aus, läuft auf modernem Stack – aber arbeitet im Hintergrund teilweise noch mit der Legacy-Plattform zusammen. Bestimmte Funktionen wie Checkout oder komplexe Account-Verwaltung werden an das etablierte System delegiert.

**Das ist Enterprise-Realität:** Nicht alles kann über Nacht neu geschrieben werden. Man muss mit dem arbeiten, was da ist.

## Was Docker hier konkret löst

## 1. Service-Isolation trotz heterogener Technologien

Wir haben Services auf unterschiedlichen Tech-Stacks:

- Legacy-Plattform (Java-basiert, ältere Frameworks)
- Moderne Backend-Services (aktuelle Java-Versionen, moderne Architekturen)
- Frontend (Angular PWA, Node.js-basiert)

Ohne Docker müsste jeder Entwickler alle diese Umgebungen lokal installieren und pflegen. Mit Docker läuft jeder Service in seinem eigenen Container mit genau den Dependencies, die er braucht.

**Ergebnis:** Ein Entwickler kann am Frontend arbeiten, ohne Java installiert zu haben. Ein Backend-Entwickler kann verschiedene Service-Versionen parallel testen.

## 2. CI/CD-Pipeline wird konsistent und schnell

Der Wechsel von Jenkins zu Azure DevOps mit Docker brachte messbare Verbesserungen.

**Vorher (Jenkins):**

- Build-Zeit: 15-25 Minuten (je nach Service)
- Deployment: manuell, fehleranfällig
- Unterschiede zwischen Build-Umgebung und Production

**Jetzt (Azure + Docker + Helm):**

- Build-Zeit: 8-12 Minuten für die meisten Services
- Deployment: automatisiert via Helm Charts
- Identische Container von Dev bis Production

Die modernen Services – Angebots-Service, Händler-Service, Produkt-Service – laufen besonders gut. Sie wurden von Anfang an für Container designed. Kurze Build-Zeiten, klare Dependencies, saubere Isolation.

## 3. Helm Charts: Deployment wird deklarativ

Helm Charts haben das Deployment revolutioniert. Statt manueller Konfiguration beschreibt eine YAML-Datei das gesamte Deployment:

```yaml
service: offer-service
version: 1.2.3
replicas: 3
resources: ...
```

Ein Deployment über mehrere Umgebungen (Dev, Staging, Production) wird dadurch:

- Nachvollziehbar (alles ist in Git versioniert)
- Wiederholbar (gleicher Befehl, gleiches Ergebnis)
- Sicher (Rollback mit einem Befehl möglich)

## 4. Die Legacy-Bridge: Alt und Neu koexistieren

Hier zeigt sich die wahre Stärke von Docker: **Es ermöglicht Koexistenz.**

Die Legacy-Plattform läuft in ihren Containern mit ihren spezifischen Anforderungen. Die modernen Services laufen in ihren Containern mit modernen Stacks. Die PWA kommuniziert mit beiden – transparent durch Docker-Networking.

Wir müssen die alte Plattform nicht neu schreiben. Wir können sie schrittweise durch moderne Services ersetzen – Service für Service. Docker macht diesen evolutionären Ansatz praktikabel.

## Was man dabei lernen muss (die kritischen Punkte)

Nach Jahren mit Docker in dieser komplexen Umgebung habe ich auch gelernt: **Es ist kein Allheilmittel.**

## 1. Performance-Unterschiede sind real

Die modernen Services bauen schnell und laufen performant. Aber manche ältere Services oder Komponenten sind langsamer.

**Warum?**

- Große Images (manchmal 1-2 GB)
- Komplexe Build-Prozesse
- Viele Dependencies

**Lektion:** Docker macht langsame Software nicht schnell. Es macht sie nur reproduzierbar langsam.

## 2. Debugging wird komplexer

Wenn ein Service im Container nicht funktioniert, ist Debugging schwieriger:

- Logs sind über mehrere Container verteilt
- Netzwerk-Probleme zwischen Containern sind subtil
- Der Zugriff auf laufende Container erfordert zusätzliche Schritte

**Lösung:** Gutes Logging und Monitoring sind nicht optional. Sie sind kritisch.

## 3. Image-Management braucht Disziplin

Mit Azure Container Registry und vielen Services haben wir hunderte Images. Ohne klare Versionierung und Cleanup-Strategie wird es schnell unübersichtlich.

<b>Learnings:<b>

- Semantic Versioning konsequent nutzen
- Alte Images regelmäßig löschen
- Security-Scans automatisieren

## 4. Nicht alles gehört in Container

Ich habe auch gelernt: Manche Komponenten laufen besser außerhalb von Containern. Besonders bei I/O-intensiven Operationen oder wenn externe Tools integriert werden müssen.

**Die Frage ist nicht:** "Kann ich das dockern?"
**Die Frage ist:** "Sollte ich das dockern?"

## Was ich wirklich gelernt habe

Nach Jahren in dieser Hybrid-Welt zwischen Legacy und modernen Microservices ist meine wichtigste Erkenntnis:

**Docker ist ein Enabler für schrittweise Transformation.**

Es erlaubt uns:

- Alte Systeme am Leben zu halten, während wir neue bauen
- Verschiedene Technologien parallel zu betreiben
- Services unabhängig voneinander zu entwickeln und zu deployen
- Teams autonom arbeiten zu lassen

Aber es ersetzt nicht:

- Gute Architektur-Entscheidungen
- Klare Dokumentation
- Verständnis der eigenen Systeme
- Disziplinierte Entwicklungsprozesse

Die Teams, die mit Docker erfolgreich sind, haben verstanden: **Docker ist ein Werkzeug, kein Selbstzweck.**

## Wann macht Docker Sinn?

Nach dieser Erfahrung würde ich Docker empfehlen für:

- ✓ Microservices-Architekturen – Jeder Service in seinem Container, klare Grenzen, unabhängige Deployments.
- ✓ Hybrid-Umgebungen (Legacy + Modern) – Ermöglicht schrittweise Migration ohne Big-Bang-Rewrite.
- ✓ Teams mit mehreren Entwicklern – Einheitliche Entwicklungsumgebungen sparen enorm viel Zeit.
- ✓ CI/CD-Pipelines – Build once, run anywhere – vom lokalen Test bis Production.
- ✓ Cloud-Deployments – Fast alle Cloud-Plattformen unterstützen Container nativ.

Aber Vorsicht bei:

- ✗ Sehr einfachen Projekten – Eine statische Website braucht keinen Container-Overhead.
- ✗ Teams ohne Docker-Erfahrung unter Zeitdruck – Die Lernkurve ist real. Lieber Zeit nehmen oder erstmal klassisch arbeiten.
- ✗ Legacy-Monolithen ohne klare Modularisierung – Einen Monolithen in einen Container zu packen löst keine Architektur-Probleme.
- ✗ Performance-kritische Anwendungen mit hohem I/O – Der Container-Overhead kann hier spürbar sein.

## Der Blick nach vorne

Diese Jahre mit Docker in einer komplexen Enterprise-Umgebung haben meine Perspektive auf Softwareentwicklung geprägt.

Ich habe gelernt:

**Technologie muss Probleme lösen, nicht schaffen.**  
Docker löst echte Probleme – wenn man es richtig einsetzt.

**Pragmatismus schlägt Purismus.**  
Die perfekte Architektur auf dem Papier nützt nichts. Die Hybrid-Lösung, die funktioniert, ist besser.

**Evolution schlägt Revolution.**  
Komplette Neuentwicklungen sind oft nicht möglich. Aber schrittweiser Ersatz funktioniert.

**Teams sind wichtiger als Tools.**  
Docker ist nur so gut wie das Team, das es einsetzt. Ohne gemeinsames Verständnis, klare Standards und Disziplin wird auch Docker zum Problem.

## Was das für mich bedeutet

Diese Erfahrung – zwischen Legacy und modernen Microservices, zwischen alten und neuen Technologien – hat mir gezeigt, worum es in der Softwareentwicklung wirklich geht:

**Nicht die coolste Technologie zu verwenden, sondern die richtige.**

Nicht alles neu zu bauen, sondern **smart mit dem zu arbeiten, was da ist.**

Nicht Perfektion anzustreben, sondern **kontinuierliche Verbesserung.**

Das ist die Denkweise, die ich in zukünftige Projekte mitbringe.

Denn am Ende geht es nicht um Container, Microservices oder CI/CD-Pipelines.

**Es geht darum, Software zu bauen, die echte Probleme löst – pragmatisch, nachhaltig und mit Mehrwert für die Menschen, die damit arbeiten.**
