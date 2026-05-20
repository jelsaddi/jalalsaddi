---
title: "Chocolate for Peace — Eine Full-Stack-Voting-Plattform für wohltätige Zwecke"
description: "Wie ich eine zweisprachige Charity-Voting-Plattform mit Vue.js 3, Spring Boot 3, JWT-Sicherheit und einem vollständigen Admin-Panel entwickelt habe — und damit Schokoladenverkäufe in transparente, gemeinschaftlich entschiedene Spendengelder verwandelt."
date: "2025-08-30"
image: "voting.jpeg"
tags: [Vue.js, Spring Boot, Full-Stack, JWT, PostgreSQL, Pinia, Tailwind CSS]
---

# Chocolate for Peace — Eine Full-Stack-Voting-Plattform für wohltätige Zwecke

## Die Idee

Das Konzept ist einfach und menschlich: Eine Schokoladenmarke spendet einen Teil ihres Umsatzes für wohltätige Zwecke. Aber statt dass das Unternehmen selbst entscheidet, wohin das Geld fließt, entscheiden die Kunden — indem sie für die Organisationen abstimmen, die ihnen am meisten am Herzen liegen.

**Chocolate for Peace** ist die Plattform, die ich dafür entwickelt habe. Kunden und Follower durchsuchen gemeinnützige Projekte, stimmen für ihre Favoriten ab und verfolgen die Ergebnisse in Echtzeit. Die Organisation mit den meisten Stimmen am Ende eines Zyklus gewinnt die Spende.

Es ist nicht nur eine Abstimmungs-App. Es ist ein Vertrauensmechanismus zwischen einer Marke und ihrer Community.

---

## Architekturüberblick

Das System ist in drei unabhängige Schichten aufgeteilt:

```
Vue.js 3 SPA (Öffentliches Frontend)    — kundenorientierte Abstimmungsoberfläche
Vue.js 3 SPA (Admin-Panel)              — interne Projekt- und Benutzerverwaltung
         ↓ REST / JSON (JWT Bearer)
Spring Boot 3 REST API (Backend)
         ↓ JPA / Hibernate
PostgreSQL (Datenbank)
```

Alle drei kommunizieren ausschließlich über die REST API. Das Backend besitzt die gesamte Geschäftslogik und Sicherheit — die Frontends sind schlanke Clients, die nur das darstellen, was die API erlaubt.

---

## Backend: Spring Boot 3

### Stack
- **Spring Boot 3.4.5** mit Spring Security, Spring Data JPA
- **PostgreSQL** als primäre Datenbank
- **JWT** via `jjwt 0.11.5` (HMAC SHA-256 signierte Tokens, 1 Stunde Gültigkeit)
- **Jakarta Validation** für Request-DTO-Validierung
- **Hibernate Auditing** (`@CreatedDate`, `@LastModifiedDate`) auf der `Project`-Entity

### Datenmodell

Vier Kern-Entities: `User`, `Project`, `Vote`, `ProjectImage`, sowie `ProjectComment`.

```java
// Vote — das Herzstück des Systems
@Entity
public class Vote {
    @Id @GeneratedValue
    private UUID id;

    @ManyToOne(optional = false)
    private User user;

    @ManyToOne(optional = false)
    private Project project;

    private LocalDateTime votedAt;
}
```

Projekte durchlaufen einen Lebenszyklus-Status, der durch eine strikte State Machine verwaltet wird:

```java
public enum Status { PENDING, APPROVED, REJECTED }
```

Ein vom Nutzer eingereichtes Projekt startet immer als `PENDING`. Ein Admin muss es explizit genehmigen, bevor es öffentlich abstimmbar wird. Das Zurücksetzen eines Projekts auf `PENDING` über die API ist bewusst blockiert:

```java
if (newStatus == Status.PENDING) {
    throw new SettingStatusToPendingNotAllowedException();
}
```

Das verhindert versehentliche oder böswillige Status-Rollbacks, sobald ein Projekt den Genehmigungsworkflow durchläuft.

### Sicherheitsdesign

Die Sicherheit wird über Spring Securitys `SecurityFilterChain` konfiguriert:

```java
.authorizeHttpRequests(auth -> auth
    .requestMatchers("/auth/**").permitAll()
    .requestMatchers(HttpMethod.GET, "/api/projects/**").permitAll()
    .requestMatchers(HttpMethod.GET, "/api/votes/count/**").permitAll()
    .requestMatchers("/api/admin/**").hasRole("ADMIN")
    .requestMatchers(HttpMethod.PUT, "/api/projects/*/approval").hasRole("ADMIN")
    .requestMatchers(HttpMethod.POST, "/api/votes/**").authenticated()
    .anyRequest().authenticated()
)
```

Öffentliches Browsen erfordert kein Login. Abstimmen erfordert Authentifizierung. Admin-Operationen erfordern die `ADMIN`-Rolle. Rollenprüfungen liegen auf der API-Schicht, nicht im Frontend.

JWT-Tokens werden mit HMAC SHA-256 signiert und bei jeder Anfrage durch einen eigenen `JwtTokenFilter` validiert, der vor Springs `UsernamePasswordAuthenticationFilter` eingehängt wird.

### Stimmenintegrität: Eine Stimme pro Nutzer pro Monat

Die wichtigste Geschäftsregel ist die Verhinderung doppelter Stimmen. Ein Nutzer darf für dasselbe Projekt nur einmal pro Kalendermonat abstimmen:

```java
private void checkIfUserHasVotedThisMonth(User user, Project project) {
    LocalDateTime startOfMonth = LocalDateTime.now()
        .withDayOfMonth(1).with(LocalTime.MIN);
    LocalDateTime endOfMonth = LocalDateTime.now()
        .withDayOfMonth(LocalDateTime.now().toLocalDate().lengthOfMonth())
        .with(LocalTime.MAX);

    if (voteRepository.existsByUserAndProjectAndVotedAtBetween(
            user, project, startOfMonth, endOfMonth)) {
        throw new AlreadyVotedException();
    }
}
```

Das monatliche Zeitfenster hält Nutzer über Zyklen hinweg engagiert — sie können im folgenden Monat erneut abstimmen — verhindert aber Stimmenmissbrauch innerhalb eines Zeitraums.

### Exception Handling

Ein `@RestControllerAdvice` `GlobalExceptionHandler` bildet alle eigenen Business-Exceptions auf strukturierte Fehlerantworten ab:

```java
@ExceptionHandler(BusinessException.class)
public ResponseEntity<ErrorResponseDTO> handleBusinessException(BusinessException ex) {
    return ResponseEntity
        .status(ex.getStatus())
        .body(new ErrorResponseDTO(ex.getCode(), ex.getMessage()));
}
```

Eigene Exceptions: `AlreadyVotedException`, `ProjectNotFoundException`, `UserNotFoundException`, `InvalidProjectStatusException`, `EmailAlreadyExistsException`. Jede trägt ihren eigenen HTTP-Status und Fehlercode — das Frontend kann auf `ALREADY_VOTED` programmatisch reagieren, ohne Fehlermeldungsstrings zu parsen.

### Bild-Upload

Projekte unterstützen Mehrfach-Bild-Uploads via `multipart/form-data`. Bilder werden unter `uploads/projects/` mit UUID-präfixierten Dateinamen gespeichert, um Kollisionen zu vermeiden.

---

## Frontend: Vue.js 3 (Öffentlich)

### Stack
- **Vue.js 3** mit Composition API und `<script setup>`
- **Pinia** für State Management
- **Vue Router** für clientseitige Navigation
- **Vue I18n** — vollständig zweisprachig (Englisch / Deutsch)
- **Tailwind CSS** für das Styling
- **Axios** für die API-Kommunikation

### Auth Store (Pinia)

Der Auth Store verwaltet die Session, ohne den JWT-Token jemals im JavaScript-State zu speichern — der Token liegt in einem HttpOnly-Cookie, das vom Backend verwaltet wird:

```typescript
export const useAuthStore = defineStore('auth', () => {
  const email = ref<string | null>(localStorage.getItem('email') || null)
  const isLoggedIn = computed(() => !!email.value)

  async function logout() {
    await logoutApi()  // löscht den HttpOnly-Cookie serverseitig
    localStorage.removeItem('email')
    localStorage.setItem('logout', Date.now().toString()) // Tab-übergreifendes Logout-Signal
  }
})
```

Das Tab-übergreifende Logout ist ein kleines, aber bedeutsames Detail — das Setzen eines `logout`-Schlüssels im `localStorage` löst ein `storage`-Event in anderen offenen Tabs aus und ermöglicht es ihnen, ihren Session-State ohne Seitenneuladen zu bereinigen.

### Vote-Komponente

Die Abstimmungs-UI verwaltet den vollständigen Interaktionszyklus — API-Aufruf, optimistisches Zähler-Update, Feedback bei Doppelstimme — in einer einzigen fokussierten Komponente:

```vue
<script setup>
const vote = async () => {
  if (hasVoted.value) return;
  try {
    await axios.post(`${API_BASE_URL}/api/projects/${props.projectId}/vote`, {},
      { headers: { Authorization: `Bearer ${token}` } });
    votes.value++;
    hasVoted.value = true;
    voteMessage.value = t('Danke für deine Stimme!');
  } catch (err) {
    if (err.response?.data?.code === 'ALREADY_VOTED') {
      voteMessage.value = t('Du hast bereits abgestimmt.');
    }
  }
};
</script>
```

### Zweisprachige UX

Alle benutzersichtbaren Texte sind in Locale-JSON-Dateien pro Abschnitt ausgelagert: `howitworks_de.json`, `vote_de.json`, `projects_de.json` und ihre englischen Pendants. Komponenten referenzieren ausschließlich Übersetzungsschlüssel — keine hartkodierten Strings in den Templates.

---

## Admin-Panel: Vue.js 3

Eine separate Vite-Applikation stellt die interne Admin-Oberfläche mit eigenem Router und Pinia Store bereit. Sie wird nie in die öffentliche Site gebündelt. Funktionen:

- **Dashboard** — Übersicht über ausstehende, genehmigte und abgelehnte Projekte
- **Projekte verwalten** — Einreichungen genehmigen oder ablehnen, hochgeladene Bilder ansehen
- **Benutzer verwalten** — Benutzerliste und Rollenverwaltung
- **Bestellungen** — Bestellverfolgung verknüpft mit Schokoladenverkäufen
- **Einstellungen** — Plattformkonfiguration

---

## Projektkategorien

Gemeinnützige Organisationen werden über ein typisiertes Enum kategorisiert:

```java
public enum Category {
    ENVIRONMENT, EDUCATION, SOCIAL, CULTURE, HEALTH, SPORTS
}
```

Das Frontend filtert nach Kategorie und gibt Wählern ein fokussiertes Browsing-Erlebnis.

---

## Was ich heute anders machen würde

Mit frischem Blick zurückgeschaut:

- **Der JWT-Signing-Key wird bei jedem Neustart neu generiert.** `Keys.secretKeyFor()` in `@PostConstruct` bedeutet, dass alle Tokens bei einem Redeploy ungültig werden. Für die Produktion sollte der Schlüssel aus einer Umgebungsvariable oder einem Secrets Manager geladen werden.
- **Bild-Storage sollte Cloud-basiert sein.** Das Speichern von Uploads auf der Festplatte funktioniert lokal, überlebt aber keinen Container-Neustart oder horizontale Skalierung. S3 oder Azure Blob Storage wäre der richtige nächste Schritt.
- **Kein Abstimmungszeitraum auf API-Ebene.** Die monatliche Duplikatprüfung ist korrekt, aber es gibt kein Konzept einer Kampagne mit definiertem Start- und Enddatum — das wäre das nächste Business-Feature.

---

## Lessons Learned

Die Arbeit an Chocolate for Peace hat mir etwas klargemacht, das ich in der Theorie verstanden, aber noch nicht gespürt hatte: **Eine Charity-Plattform steht und fällt mit Vertrauen.** Jede Designentscheidung — der Admin-Genehmigungsworkflow, das monatliche Stimmlimit, die strukturierten Fehlercodes, die rollenbasierte API-Sicherheit — diente letztlich dazu, das System so vertrauenswürdig zu machen, dass Nutzer glauben, ihre Stimme zählt, und Spender glauben, das Ergebnis ist fair.

Technische Korrektheit und Vertrauen sind nicht dasselbe. Aber die technischen Entscheidungen sind es, die Vertrauen erst möglich machen.
