---
title: "Chocolate for Peace — A Full-Stack Voting Platform for Charity"
description: "How I built a bilingual charity voting platform with Vue.js 3, Spring Boot 3, JWT security, and a full admin panel — turning chocolate sales into transparent community-driven donations."
date: "2025-08-30"
image: "voting.jpeg"
tags: [Vue.js, Spring Boot, Full-Stack, JWT, PostgreSQL, Pinia, Tailwind CSS]
---

# Chocolate for Peace — A Full-Stack Voting Platform for Charity

## The Idea

The concept is simple and human: a chocolate brand donates a portion of its revenue to charity. But instead of the company deciding where the money goes, the customers decide — by voting for the organizations they care about most.

**Chocolate for Peace** is the platform I built to make that possible. Customers and followers browse charity projects, vote for their favourites, and watch the results in real time. The organization with the most votes at the end of a cycle wins the donation.

It is not just a voting app. It is a trust mechanism between a brand and its community.

---

## Architecture Overview

The system is split into three independent layers:

```
Vue.js 3 SPA (Public Frontend)         — customer-facing voting interface
Vue.js 3 SPA (Admin Panel)             — internal project and user management
         ↓ REST / JSON (JWT Bearer)
Spring Boot 3 REST API (Backend)
         ↓ JPA / Hibernate
PostgreSQL (Database)
```

All three communicate exclusively through the REST API. The backend owns all business logic and security — the frontends are thin clients that render what the API permits.

---

## Backend: Spring Boot 3

### Stack
- **Spring Boot 3.4.5** with Spring Security, Spring Data JPA
- **PostgreSQL** as the primary database
- **JWT** via `jjwt 0.11.5` (HMAC SHA-256 signed tokens, 1-hour expiry)
- **Jakarta Validation** for request DTO validation
- **Hibernate Auditing** (`@CreatedDate`, `@LastModifiedDate`) on the `Project` entity

### Data Model

Four core entities: `User`, `Project`, `Vote`, `ProjectImage`, plus `ProjectComment`.

```java
// Vote — the heart of the system
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

Projects carry a lifecycle status managed through a strict state machine:

```java
public enum Status { PENDING, APPROVED, REJECTED }
```

A project submitted by a user always starts as `PENDING`. An admin must explicitly approve it before it becomes publicly voteable. Setting a project back to `PENDING` via the API is explicitly blocked:

```java
if (newStatus == Status.PENDING) {
    throw new SettingStatusToPendingNotAllowedException();
}
```

This prevents accidental or malicious state rollbacks once a project enters the approval workflow.

### Security Design

Security is configured via Spring Security's `SecurityFilterChain`:

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

Public browsing requires no login. Voting requires authentication. Admin operations require the `ADMIN` role. Role checks live at the API layer, not in the frontend.

JWT tokens are signed with HMAC SHA-256 and validated on every request by a custom `JwtTokenFilter` inserted before Spring's `UsernamePasswordAuthenticationFilter`.

### Vote Integrity: One Vote Per User Per Month

The most critical business rule is duplicate vote prevention. A user may vote for the same project only once per calendar month:

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

The monthly window keeps users engaged across cycles — they can vote again the following month — while preventing ballot stuffing within a single period.

### Exception Handling

A `@RestControllerAdvice` `GlobalExceptionHandler` maps all custom business exceptions to structured error responses:

```java
@ExceptionHandler(BusinessException.class)
public ResponseEntity<ErrorResponseDTO> handleBusinessException(BusinessException ex) {
    return ResponseEntity
        .status(ex.getStatus())
        .body(new ErrorResponseDTO(ex.getCode(), ex.getMessage()));
}
```

Custom exceptions include: `AlreadyVotedException`, `ProjectNotFoundException`, `UserNotFoundException`, `InvalidProjectStatusException`, `EmailAlreadyExistsException`. Each carries its own HTTP status and error code — the frontend reacts programmatically to `ALREADY_VOTED` without parsing message strings.

### Image Upload

Projects support multi-image uploads via `multipart/form-data`. Images are stored to disk under `uploads/projects/` with UUID-prefixed filenames to prevent collisions.

---

## Frontend: Vue.js 3 (Public)

### Stack
- **Vue.js 3** with Composition API and `<script setup>`
- **Pinia** for state management
- **Vue Router** for client-side navigation
- **Vue I18n** — fully bilingual (English / German)
- **Tailwind CSS** for styling
- **Axios** for API communication

### Auth Store (Pinia)

The auth store manages the session without ever storing the JWT token in JavaScript state — the token lives in an HttpOnly cookie managed by the backend:

```typescript
export const useAuthStore = defineStore('auth', () => {
  const email = ref<string | null>(localStorage.getItem('email') || null)
  const isLoggedIn = computed(() => !!email.value)

  async function logout() {
    await logoutApi()  // clears the HttpOnly cookie server-side
    localStorage.removeItem('email')
    localStorage.setItem('logout', Date.now().toString()) // cross-tab logout signal
  }
})
```

The cross-tab logout is a small but meaningful detail — setting a `logout` key in `localStorage` triggers a `storage` event in other open tabs, allowing them to clear their session state without a page reload.

### Vote Component

The voting UI handles the full interaction cycle — API call, optimistic counter update, duplicate vote feedback — in a single focused component:

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

### Bilingual UX

All user-facing text is externalised into locale JSON files per section: `howitworks_en.json`, `vote_en.json`, `projects_en.json`, and their German counterparts. Components reference only translation keys — no hardcoded strings anywhere in the templates.

---

## Admin Panel: Vue.js 3

A separate Vite application provides the internal admin interface with its own router and Pinia store. It is never bundled into the public site. Features include:

- **Dashboard** — overview of pending, approved, and rejected projects
- **Manage Projects** — approve or reject submissions, view uploaded images
- **Manage Users** — user listing and role management
- **Orders** — order tracking tied to chocolate sales
- **Settings** — platform configuration

---

## Project Categories

Charity organizations are categorised with a typed enum:

```java
public enum Category {
    ENVIRONMENT, EDUCATION, SOCIAL, CULTURE, HEALTH, SPORTS
}
```

The frontend filters by category, giving voters a focused browsing experience.

---

## What I Would Do Differently

Looking back with fresh eyes:

- **The JWT signing key is regenerated on every restart.** `Keys.secretKeyFor()` in `@PostConstruct` means all tokens are invalidated on redeploy. For production the key should be loaded from an environment variable or secrets manager.
- **Image storage should be cloud-based.** Storing uploads on disk works locally but does not survive container restarts or horizontal scaling. S3 or Azure Blob Storage would be the right next step.
- **No voting campaign window at the API level.** The monthly duplicate check is correct, but there is no concept of a campaign with a defined start and end date — that would be the next business feature to build.

---

## Lessons Learned

Building Chocolate for Peace clarified something I had understood in theory but not felt in practice: **a charity platform lives or dies by trust**. Every design decision — the admin approval workflow, the monthly vote limit, the structured error codes, the role-based API security — was ultimately about making the system trustworthy enough that users believe their vote counts and donors believe the result is fair.

Technical correctness and trust are not the same thing. But the technical decisions are what make trust possible.
