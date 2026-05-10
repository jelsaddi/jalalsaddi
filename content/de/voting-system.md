---
title: "Voting-System"
description: "Eine Full-Stack-Voting-App, entwickelt mit Vue.js und Spring Boot."
date: "2025-08-30"
image: "voting.jpeg"
tags: [Vue.js, Spring Boot, Full-Stack]
---

# Planung und Entwicklung der "Voting System" App

## Einleitung

Das Voting System ist eine Full-Stack-Anwendung für transparente, sichere und benutzerfreundliche Online-Abstimmungen. Entwickelt mit Vue.js und Spring Boot, ermöglicht es Nutzern, über Projekte oder Initiativen abzustimmen — mit zuverlässiger Echtzeit-Ergebnisanzeige.

## Konzept & Planung

Ziel war eine übersichtliche Abstimmungsplattform mit Fokus auf Benutzerfreundlichkeit, Transparenz und Skalierbarkeit. Definierte Anforderungen: einfache Registrierung, sichere Stimmabgabe, transparente Ergebnisdarstellung und ein Adminbereich zur Umfrageverwaltung.

## Zielgruppe

Organisationen, Gemeinschaften und Bildungseinrichtungen, die sichere und faire Online-Abstimmungen benötigen.

## Kernfunktionen

- Benutzerauthentifizierung und sicherer Login
- Erstellung und Verwaltung von Umfragen
- Echtzeit-Abstimmung und Live-Ergebnisaktualisierung
- Transparente Darstellung der Ergebnisse
- Admin-Panel für Umfragen- und Benutzerverwaltung

## Technischer Stack & Tools

- **Frontend:** Vue.js — moderne, responsive UI mit komponentenbasierter Architektur
- **Backend:** Spring Boot — RESTful API mit sauberer Schichtenstruktur
- **Datenbank:** PostgreSQL — strukturierte Schemata für Nutzer, Umfragen und Ergebnisse
- **Authentifizierung:** JWT (Bearer Token) via Keycloak für rollenbasierte Zugriffskontrolle
- **Versionskontrolle:** GitHub

## App-Architektur

```
Vue.js SPA (Frontend)
      ↓ HTTP/REST
Spring Boot API (Backend)
      ↓ JPA
PostgreSQL (Datenbank)
      ↑
Keycloak (Auth / Rollenverwaltung)
```

Die Architektur folgt einer klaren Trennung der Zuständigkeiten: Das Vue.js-Frontend kommuniziert ausschließlich über REST-Endpunkte, der Spring Boot-Backend enthält die gesamte Geschäftslogik, und Keycloak übernimmt Authentifizierung und Autorisierung unabhängig davon.

## Entwicklungsprozess

- PostgreSQL-Schema für Nutzer, Umfragen und Stimmen entworfen
- RESTful Endpunkte in Spring Boot mit JWT-Validierung implementiert
- Vue.js-Komponenten für Umfrageerstellung, Abstimmung und Ergebnisvisualisierung erstellt
- Keycloak für rollenbasierte Zugriffskontrolle (Wähler vs. Admin) integriert
- Unit- und Integrationstests für Stimmenverarbeitung und Datenkonsistenz geschrieben

## Tests & Feedback

Unit- und Integrationstests deckten die korrekte Stimmenverarbeitung und Datenkonsistenz ab. Beta-Tester fanden die App intuitiv und zuverlässig — das Feedback führte zu UI-Verbesserungen in der Ergebnisvisualisierung und klareren Umfragestatusanzeigen.

## Erkenntnisse

Dieses Projekt hat ein wichtiges Prinzip gefestigt: **Sicherheitsgrenzen müssen auf API-Ebene definiert werden, nicht im Frontend.** JWT-Validierung und Rollenprüfungen leben im Spring Boot-Backend — der Vue.js-Client rendert nur, was die API erlaubt.

## Fazit

Das Voting System zeigt, wie Vue.js und Spring Boot für sichere, Echtzeit-Webanwendungen zusammenarbeiten. Das Projekt hat meine Erfahrung in Full-Stack-Architektur, API-Sicherheit und den praktischen Kompromissen zwischen JWT- und sitzungsbasierter Authentifizierung vertieft.
