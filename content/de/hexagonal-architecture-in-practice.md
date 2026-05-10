---
title: "Hexagonal Architecture in der Praxis: Warum sich weniger ändert, als man denkt"
description: "Nach 15 Jahren Softwareentwicklung eine überraschende Erkenntnis: Moderne Architekturkonzepte wie Hexagonal Architecture, Clean Architecture oder Ports & Adapters sind keine Revolution – sie benennen nur altbewährte Prinzipien neu."
date: "2025-10-22"
image: "hexagonalArchitecture.jpeg"
tags: [Softwareentwicklung, Architektur, Hexagonal Architecture, Clean Architecture]
---

# Hexagonal Architecture in der Praxis: Warum sich weniger ändert, als man denkt


Nach 15 Jahren in der Softwareentwicklung hatte ich letzte Woche einen Aha-Moment. Ich las über Hexagonal Architecture, Ports & Adapters, Clean Architecture – und plötzlich wurde mir klar: **Das haben wir vor 15 Jahren auch schon gemacht. Nur mit anderen Namen.**

Die Frameworks haben sich geändert. Die Buzzwords sind neu. Aber die Prinzipien? Die sind die gleichen geblieben.

Diese Erkenntnis hat meine Perspektive auf moderne Software-Architektur grundlegend verändert – und sie zeigt etwas Wichtiges: **Technology keeps changing, but the principles barely move.**

## Der Kontext: Wo kam ich her?

## Vor 15 Jahren: Die "alte" Java-Welt

Als ich anfing zu programmieren, war der Java-Enterprise-Stack noch ganz anders:

- Struts als Web-Framework
- Spring für Dependency Injection (aber noch mit XML-Konfiguration)
- iBatis (später MyBatis) für Datenbank-Zugriff
- JSP für Views
- Deployment als WAR-Files auf Tomcat oder JBoss

Das war der Standard. Das haben wir gelernt. Das galt als "professionell".

## Wie wir damals Architekturen gebaut haben

Wir haben in Schichten gedacht:

```
Presentation Layer
  (Struts Actions, JSPs)
        ↓
Business Logic Layer
  (Service Classes)
        ↓
Data Access Layer
  (DAO Interfaces, iBatis)
        ↓
Database
```

**Unsere Prinzipien waren klar:**

- **Separation of Concerns:** Jede Schicht hat eine Aufgabe
- **Interfaces überall:** DAOs waren immer Interfaces
- **Business Logic unabhängig:** Service-Layer kannte keine HTTP-Details
- **Testbar:** Unit Tests für Services, Mock-DAOs für Tests

Das war unsere "Best Practice" – lange bevor jemand von Hexagonal Architecture sprach.

## Das Problem: Der Wandel der Technologie

## Die Jahre vergingen, neue Frameworks kamen

Über die Jahre hat sich der Stack dramatisch verändert:

**2010er Jahre:**

- Struts → Spring MVC
- XML → Annotations
- WAR → Embedded Tomcat

**2020er Jahre:**

- Spring Boot als Standard
- Microservices-Architekturen
- Container (Docker, Kubernetes)
- REST APIs statt JSPs

**Und plötzlich neue Buzzwords:**

- Hexagonal Architecture
- Ports & Adapters
- Clean Architecture
- Domain-Driven Design

## Die Verunsicherung

Als ich diese neuen Begriffe hörte, dachte ich zunächst:

"Ist unsere alte Architektur veraltet? Haben wir es falsch gemacht? Müssen wir alles neu lernen?"

Konferenzen voller Talks über "moderne Architektur". Bücher über Clean Code und Domain-Driven Design. YouTube-Videos über Hexagonal Architecture.

**Die implizite Botschaft:** "Das Alte ist schlecht, das Neue ist besser."

## Die Lösung: Der Blick hinter die Buzzwords

## Der Aha-Moment

Letzte Woche saß ich mit einem Kollegen zusammen und wir diskutierten über Hexagonal Architecture. Er zeigte mir ein Diagramm:

```
REST Controller (Adapter)
        ↓
Application Service (Port)
        ↓
Domain Logic (Core)
        ↓
Repository Interface (Port)
        ↓
Repository Impl (Adapter)
```

Ich schaute es an – und mir fiel die Kinnlade runter.

**Das ist exakt das, was wir vor 15 Jahren auch gemacht haben!**

## Der Vergleich: Damals vs. Heute

| Damals (2010) | Heute (2025) | Das Prinzip |
|---|---|---|
| Struts Action | REST Controller (Adapter) | Eingangs-Schnittstelle zur Außenwelt |
| Service Interface + Impl | Application Service (Port) | Business-Logik-Abstraktion |
| Service-Methoden | Use Cases | Konkrete Business-Operationen |
| DAO Interface | Repository Port | Persistenz-Abstraktion |
| iBatis Mapper | Repository Adapter | Konkrete Datenbankanbindung |

**Es ist das Gleiche. Nur die Namen haben sich geändert.**

## Was wirklich neu ist (und was nicht)

**Wirklich neu:**

- ✅ Syntax: @RestController statt XML-Konfiguration
- ✅ Tools: Spring Boot vs. Struts + XML
- ✅ Deployment: Container vs. WAR-Files
- ✅ Terminologie: "Ports & Adapters" vs. "DAOs"

**NICHT neu:**

- ❌ Separation of Concerns
- ❌ Dependency Inversion
- ❌ Abstraktion über Interfaces
- ❌ Testability durch Mocking
- ❌ Lose Kopplung zwischen Schichten

**Die Prinzipien sind identisch. Nur die Verpackung ist moderner.**

## 1. Separation of Concerns funktioniert seit Jahrzehnten

**Damals:**



```
// Struts Action (2010)
public class UserAction extends Action {
    private UserService userService; // injected
    public ActionForward execute(...) {
        User user = userService.findById(id);
        request.setAttribute("user", user);
        return mapping.findForward("success");
    }
}
```

**Heute:**



```
// REST Controller (2025)
@RestController
public class UserController {
    private final UserService userService;
    @GetMapping("/users/{id}")
    public User getUser(@PathVariable Long id) {
        return userService.findById(id);
    }
}
```

**Unterschied:** Syntax. Prinzip: Das Gleiche – Controller delegiert an Service.

## 2. Dependency Inversion war schon immer klug

**Damals:**



```
// Service Layer (2010)
public class UserServiceImpl implements UserService {
    private UserDAO userDAO; // Interface!
    public User findById(Long id) {
        return userDAO.findById(id);
    }
}
```

**Heute:**



```
// Application Service (2025)
@Service
public class UserService {
    private final UserRepository userRepository; // Interface!
    public User findById(Long id) {
        return userRepository.findById(id);
    }
}
```

**Unterschied:** Annotation. **Prinzip:** Das Gleiche – abhängig von Abstraktion, nicht Implementierung.

## 3. Testability durch Interfaces war immer wichtig

**Damals:**



```
// Unit Test (2010)
public class UserServiceTest {
    @Test
    public void testFindById() {
        UserDAO mockDAO = mock(UserDAO.class);
        when(mockDAO.findById(1L)).thenReturn(testUser);
        UserService service = new UserServiceImpl(mockDAO);
        User result = service.findById(1L);
        assertEquals("John", result.getName());
    }
}
```

**Heute:**



```
// Unit Test (2025)
@Test
public void testFindById() {
    UserRepository mockRepo = mock(UserRepository.class);
    when(mockRepo.findById(1L)).thenReturn(Optional.of(testUser));
    UserService service = new UserService(mockRepo);
    User result = service.findById(1L);
    assertEquals("John", result.getName());
}
```

**Unterschied:** Minimal. **Prinzip:** Exakt das Gleiche – Mock die Abhängigkeit, teste die Logik.

## Die Erkenntnis

**Wir haben keine schlechte Architektur gebaut.**

Wir haben **solide Prinzipien** angewendet:

- Loose Coupling
- Dependency Inversion
- Separation of Concerns
- Testability

Die Industrie hat diese Prinzipien nur **neu verpackt und umbenannt:**

- "DAO" → "Repository"
- "Service Layer" → "Application Service" / "Use Case"
- "Layered Architecture" → "Hexagonal Architecture" / "Clean Architecture"

**Die Prinzipien waren immer da. Wir haben nur neue Worte dafür gefunden.**

## 2. Prinzipien wichtiger als Namen

**Der Fehler:** Stunden damit verbringen, zu diskutieren: "Ist das jetzt ein Port oder ein Adapter?"

**Die Realität:** Die Frage sollte sein: "Ist diese Komponente testbar? Ist sie entkoppelt? Ist sie wartbar?"

**Namen sind Kommunikationsmittel, keine Dogmen.**

## 3. Hype vs. Substanz unterscheiden

**Frameworks kommen und gehen:**

- Struts (tot)
- JSF (fast tot)
- Spring MVC (Standard, aber wird weniger)
- React (aktuell Hype)
- Next.js (noch neuerer Hype)

Prinzipien bleiben:

- SOLID (seit 2000, immer noch gültig)
- Separation of Concerns (seit 1970er)
- Dependency Inversion (seit immer)
- Testability (seit immer)

**Investiere in Prinzipien, nicht in Hype.**

## 4. Alte Code-Basen sind nicht automatisch schlecht

**Der Fehler:** "Dieser Code ist 10 Jahre alt, der muss schlecht sein!"



**Die Realität:** Wenn der Code sauber strukturiert ist, testbar ist und funktioniert – dann ist er **gut**, egal wie alt.



**Alter ≠ Qualität. Struktur = Qualität.**

## Learnings: Was ich wirklich mitgenommen habe

## 1. Frameworks sind Werkzeuge, Prinzipien sind Fundamente

**Als Junior (vor 15 Jahren):** Ich dachte: "Struts ist DIE Art, Web-Anwendungen zu bauen."



**Als Senior (heute):** Ich weiß: "Struts war EIN Werkzeug, das mir half, gute Prinzipien anzuwenden."



**Die Lektion:** Wenn du die Prinzipien verstehst (Separation, Decoupling, Testability), kannst du **jedes Framework lernen.**

Wenn du nur Frameworks auswendig lernst, bist du verloren, sobald ein neues kommt.

## 2. "Modern" ist relativ

**Heute modern:**



- Hexagonal Architecture
- Domain-Driven Design
- Microservices
- Serverless

**In 10 Jahren:**



- Werden neue Buzzwords existieren
- Werden heutige "moderne" Frameworks Legacy sein
- Werden die gleichen Prinzipien immer noch gelten

**Die Lektion:** Jage nicht Trends. Verstehe Prinzipien.

## 3. Erfahrung bedeutet Muster erkennen

**Das ist der Unterschied zwischen Junior und Senior:**

**Junior:** "Hexagonal Architecture ist neu, ich muss es lernen!"

**Senior:** "Hexagonal Architecture? Das ist wie DAO-Pattern mit neuem Namen."

**Die Lektion:** Mit Erfahrung siehst du, dass sich vieles wiederholt – nur mit anderen Worten.



## 4. Gute Architektur ist zeitlos

**Kriterien für gute Architektur (2010):**



- Testbar
- Wartbar
- Erweiterbar
- Entkoppelt

**Kriterien für gute Architektur (2025):**



- Testbar
- Wartbar
- Erweiterbar
- Entkoppelt

**Die Lektion:** Diese Kriterien haben sich **nicht geändert.** Und sie werden sich auch in 10 Jahren nicht ändern.



## 5. Bescheidenheit gegenüber der Vergangenheit

**Früher dachte ich:** "Die alten Entwickler haben es nicht verstanden. Wir machen es heute besser."

**Heute weiß ich:** "Die alten Entwickler haben die gleichen Prinzipien verstanden. Sie hatten nur andere Tools."

**Die Lektion:** Respekt vor der Arbeit früherer Entwickler. Sie haben oft **sehr gut** gearbeitet – nur mit anderen Mitteln.



## Der Blick nach vorne

## Was bedeutet das für meine Arbeit?

Diese Erkenntnis hat meine Perspektive fundamental verändert:

**Ich frage nicht mehr:** "Ist dieses Framework modern?"
**Ich frage:** "Hilft mir dieses Framework, gute Prinzipien umzusetzen?"

**Ich frage nicht mehr:** "Müssen wir zu Hexagonal Architecture migrieren?"
**Ich frage:** "Ist unsere Architektur testbar, wartbar und entkoppelt?"

**Ich falle nicht mehr auf Hype rein.**
**Ich fokussiere mich auf zeitlose Prinzipien.**



## Was empfehle ich anderen?

**Für Junior-Entwickler:**



- ❌ **Nicht:** "Lerne Hexagonal Architecture auswendig"
- ✅ **Besser:** "Verstehe, WARUM wir Schichten trennen und Abhängigkeiten umkehren"
- ❌ **Nicht:** "Spring Boot ist DIE Lösung"
- ✅ **Besser:** "Spring Boot ist EIN Werkzeug, das Prinzipien umsetzt"

**Wenn du die Prinzipien verstehst:**



- Kannst du jedes Framework lernen
- Erkennst du gute vs. schlechte Architektur
- Bist du nicht abhängig von Trends

**Für Senior-Entwickler:**



- ❌ **Nicht:** "Unsere alte Architektur ist veraltet"
- ✅ **Besser:** "Unsere Architektur folgt soliden Prinzipien – das zählt"
- ❌ **Nicht:** "Wir müssen auf Hexagonal refactoren"
- ✅ **Besser:** "Haben wir ein Problem, das Hexagonal lösen würde?"

**Refactore nur mit klarem Grund, nicht wegen Buzzwords.**



## In 15 Jahren

**Was wird anders sein:**



- Spring Boot wird vielleicht Legacy sein
- Neue Frameworks werden existieren
- Neue Buzzwords werden Konferenzen füllen
- Neue Annotations werden erfunden

**Was gleich bleiben wird:**



- Separation of Concerns wird wichtig sein
- Testability wird zählen
- Loose Coupling wird gelten
- Dependency Inversion wird funktionieren

**Denn wie ein kluger Entwickler mal sagte:**

"Technology keeps changing, but the principles barely move."

**Oder noch prägnanter:**

"Nothing's really new. It just gets a new name, a new annotation, and a new conference talk."

## Fazit: Prinzipien über Frameworks

Nach 15 Jahren in der Softwareentwicklung ist das meine wichtigste Erkenntnis:

**Frameworks sind temporär. Prinzipien sind ewig.**

Struts ist tot. iBatis ist umbenannt. XML-Konfiguration ist out.

Aber Separation of Concerns? Dependency Inversion? Testability?

**Die werden noch in 50 Jahren gelten.**

Das ist nicht Nostalgie. Das ist nicht Widerstand gegen Neues.

**Es ist Weisheit aus Erfahrung:**

Die besten Entwickler sind nicht die, die jeden neuen Trend mitgehen.
Die besten Entwickler sind die, die verstehen, **was unter der Oberfläche wirklich zählt.**

Und das sind nicht Frameworks.
**Das sind Prinzipien.**
