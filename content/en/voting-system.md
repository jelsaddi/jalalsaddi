---
title: "Voting System"
description: "A full-stack voting app built with Vue.js and Spring Boot."
date: "2025-08-30"
image: "voting.jpeg"
tags: [Vue.js, Spring Boot, Full-Stack]
---

# Planning and Development of the "Voting System" App

## Introduction

The Voting System app is a full-stack application for transparent, secure, and user-friendly online decision-making. Built with Vue.js and Spring Boot, it allows users to vote on projects or initiatives and displays results reliably in real time.

## Concept & Planning

The goal was a clean voting platform focused on usability, transparency, and scalability. Key requirements: easy registration, secure vote handling, transparent result display, and an admin area for managing polls.

## Target Audience

Organizations, communities, and educational institutions that need secure, fair online voting.

## Core Features

- User authentication and secure login
- Creation and management of polls
- Real-time voting and live result updates
- Transparent display of outcomes
- Admin panel for poll and user management

## Technical Stack & Tools

- **Frontend:** Vue.js — modern, responsive UI with component-based architecture
- **Backend:** Spring Boot — RESTful API with clean layered structure
- **Database:** PostgreSQL — structured schemas for users, polls, and results
- **Authentication:** JWT (Bearer Token) via Keycloak for role-based access control
- **Version Control:** GitHub

## App Architecture

```
Vue.js SPA (Frontend)
      ↓ HTTP/REST
Spring Boot API (Backend)
      ↓ JPA
PostgreSQL (Database)
      ↑
Keycloak (Auth / Role Management)
```

The architecture follows a clean separation of concerns: the Vue.js frontend communicates exclusively through REST endpoints, the Spring Boot backend contains all business logic, and Keycloak handles authentication and authorization independently.

## Development Process

- Designed PostgreSQL schema for users, polls, and votes
- Implemented RESTful endpoints in Spring Boot with JWT validation
- Built Vue.js components for poll creation, voting, and result visualization
- Integrated Keycloak for role-based access (voter vs. admin)
- Wrote unit and integration tests for vote handling and data consistency

## Testing & Feedback

Unit and integration tests covered vote handling correctness and data consistency. Beta testers found the app intuitive and reliable — feedback led to UI improvements in result visualization and clearer poll status indicators.

## Lessons Learned

Building this project reinforced a key principle: **security boundaries must be defined at the API layer, not the frontend.** JWT validation and role checks live in Spring Boot — the Vue.js client only renders what the API allows.

## Conclusion

The Voting System demonstrates how Vue.js and Spring Boot work well together for secure, real-time web applications. The project deepened my experience in full-stack architecture, API security, and the practical tradeoffs of JWT vs. session-based authentication.
