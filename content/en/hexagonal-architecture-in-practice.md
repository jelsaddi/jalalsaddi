---
title: "Hexagonal Architecture in Practice: Why Less Changes Than You Think"
description: "After 15 years of software development, a surprising realization: modern architecture concepts like Hexagonal Architecture, Clean Architecture, or Ports & Adapters are not a revolution—they merely rename time-tested principles."
date: "2025-10-22"
image: "hexagonalArchitecture.jpeg"
tags: [Software Development, Architecture, Hexagonal Architecture, Clean Architecture]
---

# Hexagonal Architecture in Practice: Why Less Changes Than You Think


After 15 years in software development, I had an aha moment last week. I read about Hexagonal Architecture, Ports & Adapters, Clean Architecture – and suddenly I realized: **We were already doing this 15 years ago. Just with different names.**

The frameworks have changed. The buzzwords are new. But the principles? They have stayed the same.

This insight fundamentally changed my perspective on modern software architecture – and it shows something important: **Technology keeps changing, but the principles barely move.**

## The Context: Where Did I Come From?

## 15 Years Ago: The 'Old' Java World

When I started programming, the Java enterprise stack was very different:

- Struts as web framework
- Spring for dependency injection (but still with XML configuration)
- iBatis (later MyBatis) for database access
- JSP for views
- Deployment as WAR files on Tomcat or JBoss

That was the standard. That’s what we learned. That was considered "professional".

## How We Built Architectures Back Then

We thought in layers:

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

**Our principles were clear:**

- **Separation of Concerns:** Each layer has a responsibility
- **Interfaces everywhere:** DAOs were always interfaces
- **Business logic independent:** Service layer knew nothing about HTTP details
- **Testable:** Unit tests for services, mock DAOs for tests

That was our "best practice" – long before anyone talked about Hexagonal Architecture.

## The Problem: Technology Changes

## Years Passed, New Frameworks Arrived

Over the years, the stack changed dramatically:

**2010s:**

- Struts → Spring MVC
- XML → Annotations
- WAR → Embedded Tomcat

**2020s:**

- Spring Boot as standard
- Microservices architectures
- Containers (Docker, Kubernetes)
- REST APIs instead of JSPs

**And suddenly, new buzzwords:**

- Hexagonal Architecture
- Ports & Adapters
- Clean Architecture
- Domain-Driven Design

## The Uncertainty

When I heard these new terms, I first thought:

"Is our old architecture outdated? Did we do it wrong? Do we need to relearn everything?"

Conferences full of talks about "modern architecture." Books about Clean Code and Domain-Driven Design. YouTube videos about Hexagonal Architecture.

**The implicit message:** "The old is bad, the new is better."

## The Solution: Looking Behind the Buzzwords

## The Aha Moment

Last week, I sat with a colleague and we discussed Hexagonal Architecture. He showed me a diagram:

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

I looked at it – and my jaw dropped.

**This is exactly what we were doing 15 years ago!**

## The Comparison: Then vs. Now

| Then (2010) | Now (2025) | The Principle |
|---|---|---|
| Struts Action | REST Controller (Adapter) | Input interface to the outside world |
| Service Interface + Impl | Application Service (Port) | Business logic abstraction |
| Service methods | Use Cases | Concrete business operations |
| DAO Interface | Repository Port | Persistence abstraction |
| iBatis Mapper | Repository Adapter | Concrete database connection |

**It’s the same. Only the names have changed.**

## What’s Really New (and What Isn’t)

**Really new:**

- ✅ Syntax: @RestController instead of XML configuration
- ✅ Tools: Spring Boot vs. Struts + XML
- ✅ Deployment: Containers vs. WAR files
- ✅ Terminology: "Ports & Adapters" vs. "DAOs"

**NOT new:**

- ❌ Separation of Concerns
- ❌ Dependency Inversion
- ❌ Abstraction via interfaces
- ❌ Testability through mocking
- ❌ Loose coupling between layers

**The principles are identical. Only the packaging is more modern.**

## 1. Separation of Concerns has worked for decades

**Back then:**



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

**Today:**



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

**Difference:** Syntax. Principle: The same – Controller delegates to Service.

## 2. Dependency Inversion has always been smart

**Back then:**



```
// Service Layer (2010)
public class UserServiceImpl implements UserService {
    private UserDAO userDAO; // Interface!
    public User findById(Long id) {
        return userDAO.findById(id);
    }
}
```

**Today:**



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

**Difference:** Annotation. **Principle:** The same – depends on abstraction, not implementation.

## 3. Testability through interfaces was always important

**Back then:**



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

**Today:**



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

**Difference:** Minimal. **Principle:** Exactly the same – mock the dependency, test the logic.

## The Insight

**We did not build bad architecture.**

We applied **solid principles**:

- Loose Coupling
- Dependency Inversion
- Separation of Concerns
- Testability

The industry just **repackaged and renamed** these principles:

- "DAO" → "Repository"
- "Service Layer" → "Application Service" / "Use Case"
- "Layered Architecture" → "Hexagonal Architecture" / "Clean Architecture"

**The principles were always there. We just found new words for them.**

## 2. Principles matter more than names

**The mistake:** Spend hours discussing: "Is this a Port or an Adapter?"

**The reality:** The question should be: "Is this component testable? Is it decoupled? Is it maintainable?"

**Names are communication tools, not dogmas.**

## 3. Distinguishing hype from substance

**Frameworks come and go:**

- Struts (dead)
- JSF (almost dead)
- Spring MVC (standard, but decreasing)
- React (current hype)
- Next.js (even newer hype)

Principles remain:

- SOLID (since 2000, still valid)
- Separation of Concerns (since the 1970s)
- Dependency Inversion (always)
- Testability (always)

**Invest in principles, not in hype.**

## 4. Old codebases are not automatically bad

**The mistake:** "This code is 10 years old, it must be bad!"



**The reality:** If the code is cleanly structured, testable, and works – then it is **good**, no matter its age.



**Age ≠ Quality. Structure = Quality.**

## Learnings: What I really took away

## 1. Frameworks are tools, principles are foundations

**As a junior (15 years ago):** I thought: "Struts is THE way to build web applications."



**As a senior (today):** I know: "Struts was ONE tool that helped me apply good principles."



**The lesson:** If you understand the principles (Separation, Decoupling, Testability), you can learn **any framework.**

If you only memorize frameworks, you are lost when a new one comes.

## 2. "Modern" is relative

**Modern today:**



- Hexagonal Architecture
- Domain-Driven Design
- Microservices
- Serverless

**In 10 years:**



- New buzzwords will exist
- Today’s "modern" frameworks will be legacy
- The same principles will still apply

**The lesson:** Don’t chase trends. Understand principles.

## 3. Experience means recognizing patterns

**This is the difference between junior and senior:**

**Junior:** "Hexagonal Architecture is new, I must learn it!"

**Senior:** "Hexagonal Architecture? That’s like the DAO pattern with a new name."

**The lesson:** With experience you see that much repeats – just with different words.



## 4. Good architecture is timeless

**Criteria for good architecture (2010):**



- Testable
- Maintainable
- Extensible
- Decoupled

**Criteria for good architecture (2025):**



- Testable
- Maintainable
- Extensible
- Decoupled

**The lesson:** These criteria have **not changed.** And they will not change in 10 years.



## 5. Humility towards the past

**Earlier I thought:** "The old developers didn’t understand it. We are doing it better today."

**Today I know:** "The old developers understood the same principles. They just had different tools."

**The lesson:** Respect the work of previous developers. They often did **very well** – just with different means.



## Looking forward

## What does this mean for my work?

This insight fundamentally changed my perspective:

**I no longer ask:** "Is this framework modern?"
**I ask:** "Does this framework help me implement good principles?"

**I no longer ask:** "Do we need to migrate to Hexagonal Architecture?"
**I ask:** "Is our architecture testable, maintainable, and decoupled?"

**I don’t fall for hype anymore.**
**I focus on timeless principles.**



## What do I recommend to others?

**For junior developers:**



- ❌ **Not:** "Memorize Hexagonal Architecture"
- ✅ **Better:** "Understand WHY we separate layers and invert dependencies"
- ❌ **Not:** "Spring Boot is THE solution"
- ✅ **Better:** "Spring Boot is ONE tool that implements principles"

**If you understand the principles:**



- You can learn any framework
- You can recognize good vs. bad architecture
- You are not dependent on trends

**For senior developers:**



- ❌ **Not:** "Our old architecture is outdated"
- ✅ **Better:** "Our architecture follows solid principles – that counts"
- ❌ **Not:** "We must refactor to Hexagonal"
- ✅ **Better:** "Do we have a problem that Hexagonal would solve?"

**Refactor only with a clear reason, not because of buzzwords.**



## In 15 years

**What will change:**



- Spring Boot may become legacy
- New frameworks will exist
- New buzzwords will fill conferences
- New annotations will be invented

**What will stay the same:**



- Separation of Concerns will remain important
- Testability will matter
- Loose Coupling will still apply
- Dependency Inversion will work

**As a wise developer once said:**

"Technology keeps changing, but the principles barely move."

**Or even more concisely:**

"Nothing's really new. It just gets a new name, a new annotation, and a new conference talk."

## Conclusion: Principles over frameworks

After 15 years in software development, this is my most important insight:

**Frameworks are temporary. Principles are eternal.**

Struts is dead. iBatis renamed. XML configuration is out.

But Separation of Concerns? Dependency Inversion? Testability?

**They will still matter in 50 years.**

This is not nostalgia. This is not resistance to new things.

**It is wisdom from experience:**

The best developers are not those who follow every new trend.
The best developers are those who understand **what really matters beneath the surface.**

And that is not frameworks.
**That is principles.**
