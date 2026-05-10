---
title: "Azure Functions in der Praxis: Automatische Bildverarbeitung im E-Commerce"
description: "Eine detaillierte Fallstudie zur Nutzung von Azure Functions für die automatische Bildskalierung auf einer E-Commerce-Plattform, inklusive Architektur, Umsetzung und Erfahrungen mit Serverless Computing."
date: "2025-10-16"
image: "azureFunctionsEcommerce.jpeg"
tags: [Azure Functions, Serverless, E-Commerce, Bildverarbeitung]
---

# Azure Functions in der Praxis: Automatische Bildverarbeitung im E-Commerce


Nach vielen Jahren in der Softwareentwicklung habe ich gelernt: Die besten technischen Lösungen sind oft die unsichtbaren. Serverless Computing klang für mich lange nach Buzzword und Hype. Bis ich einen konkreten Use Case hatte, bei dem Azure Functions genau das richtige Werkzeug waren.

Dies ist die Geschichte, wie wir mit einer einfachen serverless Function ein wiederkehrendes Problem elegant gelöst haben – und was ich dabei über Serverless wirklich gelernt habe.

## Der Kontext: E-Commerce und das Bildproblem

Wir arbeiten an einem E-Commerce-Marktplatz, der auf Azure deployed ist. Wie in jedem Online-Shop sind Produktbilder zentral für die User Experience. Aber Produktbilder haben ein Problem:** Ein Bild passt nicht überall.**

## Die Realität

- Homepage-Kacheln brauchen kleine Thumbnails (schnell laden, Übersicht)
- Produktlisten brauchen mittlere Bilder (Balance zwischen Qualität und Performance)
- Produktdetailseiten brauchen große, hochauflösende Bilder (Zoom, Details)

Unsere Bilder landen zunächst als Originale im **Azure Blob Storage** – hochgeladen von Händlern, Produktmanagern oder über APIs. 

**Das Problem:** Die Originale sind oft 3-5 MB groß. Für Thumbnails völlig überdimensioniert. Für Mobile katastrophal. Für Page Speed ein Desaster.

## Das Problem: Jedes Bild in drei Größen – automatisch

Die Anforderung war klar: 

**Jedes Produktbild muss in drei Formaten verfügbar sein:**

- Thumbnail – kleine Vorschau
- Medium – Standardansicht in Listen
- Large – hochauflösend für Detailseiten

Und zwar:

- ✅ Automatisch bei jedem neuen Bild
- ✅ Bei jeder Änderung an existierenden Bildern
- ✅ Auch für alle bereits existierenden Bilder (Migration)

## Warum das nicht trivial ist

**Option 1: On-the-fly Resizing beim Abruf**

- Server muss bei jedem Request das Bild verarbeiten
- Performance-Problem bei vielen gleichzeitigen Anfragen
- Cache hilft, aber erster Request ist langsam

**Option 2: Manuell vor Upload**

- Händler müssen 3 Versionen hochladen
- Fehleranfällig, inkonsistent
- Unmöglich für bereits existierende Tausende von Bildern

**Option 3: Cronjob auf einem Server**

- Server läuft 24/7, auch wenn nichts zu tun ist
- Polling ineffizient
- Verzögerung zwischen Upload und Verfügbarkeit

**Was wir brauchten:** Eine Lösung, die automatisch reagiert, effizient läuft und nicht für Idle-Zeit kostet.

## Die Lösung: Azure Functions + Blob Storage Trigger

Ein Kollege schlug vor: **Azure Functions mit Blob Storage Trigger.**

## Das Konzept

- Neues Bild wird in Azure Blob Storage hochgeladen
- Blob Storage feuert automatisch einen Event
- Azure Function wird getriggert (ohne Polling, ohne Delay)
- Python-Skript mit ImageMagick verarbeitet das Bild
- Drei Versionen werden zurück in Blob Storage gespeichert

## Die Architektur

Mit Azure Functions:

```
Original-Bild hochladen
        ↓
Azure Blob Storage (Input)
        ↓
[Blob Trigger feuert automatisch]
        ↓
Azure Function (Python + ImageMagick)
        ↓
Verarbeitung: Thumbnail, Medium, Large
        ↓
Azure Blob Storage (Output)
        ↓
Drei Formate verfügbar
```

**Eine einfache, aber effektive Architektur – komplett automatisch und ohne manuelles Eingreifen.**

## Warum Azure Functions?

- **Event-driven:** Kein Polling nötig. Die Function startet automatisch, wenn ein Blob hinzugefügt oder geändert wird.
- **Serverless:** Keine VM, die 24/7 läuft. Die Function existiert nur während der Ausführung. Du zahlst nur für die Sekunden, in denen sie läuft.
- **Auto-Scaling:** Kommen 100 Bilder gleichzeitig? Azure startet automatisch mehrere Instanzen parallel.
- **Managed Infrastructure:** Microsoft kümmert sich um Runtime, Updates, Verfügbarkeit. Wir schreiben nur Code.

## Die technische Umsetzung

- **Python Runtime auf Azure Functions:** Python war die natürliche Wahl – einfach, gute Libraries für Bildverarbeitung, vom Team bekannt.
- **ImageMagick:** Open-Source Bildverarbeitungs-Tool. Kann Bilder skalieren, konvertieren, optimieren. Wird über Python aufgerufen.
- **Blob Trigger:** Azure Functions haben native Integration mit Blob Storage. Der Trigger-Code ist minimal – Azure macht den Rest.

## Das Corrective Script

Die Function löste neue Uploads. Aber was ist mit den **Tausenden bereits existierenden Bildern?**

Dafür haben wir ein einmaliges Corrective Script geschrieben, das alle Bilder im Storage durchläuft, für jedes die Azure Function aufruft (oder direkt verarbeitet). Einmalige Migration, danach läuft alles automatisch.

## Was funktioniert: Konkrete Erfolge

## 1. Automatisierung ist komplett unsichtbar

**Das ist das beste Zeichen:**

Niemand denkt mehr darüber nach.

- Händler laden Bilder hoch → Sekunden später sind alle drei Formate verfügbar.
- Kein manueller Schritt.
- Keine Wartezeit.
- Kein Support-Ticket.

## 2. Performance der Website verbessert

Vorher:

- Homepage lud 3-5 MB Bilder, auch wenn nur Thumbnails angezeigt wurden
- Langsame Ladezeiten, besonders auf Mobile
- Schlechter Page Speed Score

Nachher:

- Thumbnails: ~50 KB statt 3 MB
- Medium: ~200 KB
- Large: Original-Qualität nur wo nötig

**Ergebnis:.** Messbar schnellere Ladezeiten, bessere User Experience

## 3. Kosteneffizienz

Azure Functions Pricing ist nutzungsbasiert:

- Du zahlst pro Ausführung und pro Sekunde Laufzeit
- Bei moderatem Upload-Volumen (täglich neue Produkte, gelegentliche Updates) sind die Kosten minimal

Im Vergleich zu einer VM, die 24/7 läuft:

- Keine Idle-Kosten
- Keine Wartung
- Automatisches Scaling ohne Mehrkosten-Planung

## 4. Einfache Wartung

Der Code ist simpel. Ein Python-Skript, das ImageMagick aufruft. Keine komplexe Infrastruktur. Änderungen sind schnell deployed.

## Was man beachten muss: Kritische Punkte

Nach Monaten mit dieser Lösung im Einsatz habe ich auch gelernt: **Serverless ist kein Allheilmittel**

## 1. Cold Start kann spürbar sein

Wenn die Function längere Zeit nicht gelaufen ist, muss Azure eine neue Instanz starten. Das dauert ein paar Sekunden.

**Bei uns:** Meist kein Problem, weil Bilder nicht in Echtzeit vor den Augen des Users verarbeitet werden. Aber bei interaktiven Use Cases (z.B. User lädt Bild hoch und will es sofort sehen) kann Cold Start nerven.

**Lösung:** Premium Plan mit "Always On" – aber dann zahlst du wieder für Idle-Time.

## 2. Debugging ist schwieriger

Läuft etwas schief, ist Debugging komplizierter als auf einem normalen Server:

- Logs sind in Azure Application Insights verstreut.
- Lokales Testen braucht Azure Functions Core Tools.
- Fehler sind schwerer nachzuvollziehen.

**Lektion:** Gutes Logging von Anfang an einbauen. Nicht nachträglich.

## 3. Vendor Lock-in

Azure Functions sind Azure-spezifisch. Code auf AWS Lambda zu migrieren bedeutet Anpassungen. Nicht unmöglich, aber auch nicht trivial.

**Abwägung:** Für uns war die Developer Experience und native Azure-Integration wichtiger als Portabilität.

## 4. ImageMagick in Serverless ist... speziell

ImageMagick ist ein externes Tool. In Azure Functions muss es als Dependency mitgepackt werden. Das macht das Deployment-Package größer und langsamer.

**Alternative:** Managed Services wie Azure Cognitive Services für Bildverarbeitung. Teurer, aber einfacher.

**Wir haben bei ImageMagick geblieben:** Mehr Kontrolle, günstiger, Use Case ist einfach genug.

## 5. Nicht für alles geeignet

Azure Functions sind perfekt für:

- Event-driven Tasks
- Kurzlaufende Operationen (< 10 Minuten)
- Unvorhersehbare Last

Azure Functions sind NICHT gut für:

- Langläufige Prozesse (> 10 Minuten)
- Konstant hohe Last (dann ist eine VM günstiger)
- Sehr komplexes State Management

## Learnings: Was ich wirklich mitgenommen habe

Nach dieser Erfahrung mit Serverless habe ich verstanden:

## 1. Serverless heißt nicht "kein Server"

Es heißt: **Du managst den Server nicht mehr.**

Die Infrastruktur existiert noch. Du siehst sie nur nicht. Das ist Abstraktion, kein Verschwinden.

## 2. Serverless ist Architektur-Entscheidung

Man kann nicht einfach eine Anwendung "serverless machen". Serverless funktioniert für **spezifische Use Cases:**

- Event-driven Workflows
- Sporadische Tasks
- Auto-Scaling-Bedarf

Aber nicht als Ersatz für alles.

## 3. Der ROI ist real – bei richtigem Einsatz

**Für unseren Use Case:**

- Keine Wartung einer VM
- Keine Idle-Kosten
- Automatisches Scaling
- Schnelle Entwicklung

Das spart Zeit, Geld und Komplexität.

**Aber:** Für andere Use Cases wäre eine VM oder Container günstiger und einfacher gewesen.

## 4. Start simple, optimize later

Unsere erste Version war simpel: Python + ImageMagick + Blob Trigger. Fertig.

Keine Micro-Optimierungen. Keine komplexe Architektur. **Es hat funktioniert.**

Später kann man optimieren (Premium Plan, bessere Caching, alternative Libraries). Aber für den Start: **Simple is better.**

## 5. Serverless ist Commodity geworden

Vor 5 Jahren war Serverless experimentell. Heute ist es Standard. AWS Lambda, Azure Functions, Google Cloud Functions – alle großen Cloud-Anbieter haben es.

**Das bedeutet:** Es ist nicht mehr Hype. Es ist ein Werkzeug im Toolbelt. Kein Muss, aber eine valide Option.

## Wann würde ich Azure Functions empfehlen?

Nach dieser Erfahrung würde ich Azure Functions (oder generell Serverless) empfehlen für:

- **✓ Event-driven Tasks** – Etwas muss passieren, wenn ein Event eintritt (Blob hochgeladen, Queue-Message, HTTP-Request).
- **✓ Sporadische Workloads** – Nicht 24/7, sondern gelegentlich – Serverless-Kosten unschlagbar.
- **✓ Prototyping und MVPs** – Schnell eine Idee testen, ohne Infrastruktur aufzusetzen.
- **✓ Glue Code zwischen Services** – Kleine Funktionen, die verschiedene Azure-Services verbinden.
- **✓ Auto-Scaling-Bedarf** – Last ist unvorhersehbar, Serverless skaliert automatisch.

Aber Vorsicht bei:

- **✗ Langläufigen Prozessen** – Azure Functions haben Timeouts (Standard: 5 Min, max: 10 Min). Für längere Jobs: Azure Batch, Container, VMs.
- **✗ Konstant hoher Last** – Wenn Function 24/7 läuft, VM günstiger.
- **✗ Komplexem State Management** – Serverless ist stateless. Für komplexe Workflows: Durable Functions.
- **✗ Sehr niedrigen Latenz-Anforderungen** – Cold Start kann problematisch sein.

## Der Blick nach vorne

Diese Erfahrung mit Azure Functions hat mir gezeigt:

**Technologie sollte zum Problem passen, nicht umgekehrt.**

Wir hatten ein klares Problem: Bilder automatisch verarbeiten. Azure Functions waren dafür perfekt.

Aber ich würde nicht versuchen, alles in Functions zu packen. Manche Probleme brauchen VMs. Manche Container. Manche Serverless.

**Die Kunst liegt darin, das richtige Werkzeug zu wählen.**

Das ist die Denkweise, die ich aus 15 Jahren Entwicklung mitnehme: Nicht Trends folgen, sondern Probleme lösen. Nicht Hype glauben, sondern Vor- und Nachteile abwägen. Nicht Perfektion anstreben, sondern pragmatische Lösungen bauen, die funktionieren.

Denn am Ende geht es nicht um Serverless, Microservices oder Container.

**Es geht darum, Software zu bauen, die echte Probleme löst – effizient, wartbar und mit Mehrwert für die Menschen, die damit arbeiten.**
