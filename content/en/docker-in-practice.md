---
title: "Docker Containers — Simplifying Development and Deployment"
description: "After many years in software development, I've learned: The most interesting projects aren't the perfect ones, but those where you have to deal with reality. Docker shows its true strength not in ideal microservices worlds, but in connecting legacy systems with modern architectures – just like Amazon did."
date: "2025-10-14"
image: "dockerContainers.jpeg"
tags: [Docker, DevOps, Microservices]
---

# Docker in Practice: From Legacy to Modern Microservices


After many years in software development, I've learned: The most interesting projects aren't the ones where everything is perfect and modern. They're the ones where you have to deal with reality – with evolved systems, legacy code, and the challenge of connecting old and new.

This is exactly the world I've been working in for years. And this is where Docker shows its true strength.

## The Starting Point: An Evolved Infrastructure

A few years ago, our development landscape still looked traditional:

- **Jenkins** as build and deployment tool
- Manual setups for development environments
- Oracle databases configured differently on each developer's machine
- Deployments that worked – but often only after several attempts

That wasn't bad. It worked. But it was time-consuming.

## The First Docker Experiment: Oracle DB

Our first encounter with Docker was pragmatic: **Oracle database for development.**

Previously, Oracle setup meant:

- 2-3 hours of installation and configuration
- Different versions on different machines
- "Works on my machine" – but not on my colleague's

With Docker:

```
docker run oracle-db
```

10 minutes. Same version everywhere. Reproducible.

**That was the moment I understood: Docker doesn't primarily solve technical problems. It solves human problems.**

New developers were productive instead of frustrated. Seniors no longer wasted time on setup support. That alone justified the effort.

## The Turning Point: Azure CI/CD and a Complex E-Commerce Architecture

Then came the big step: Migration to Azure DevOps with a fully container-based CI/CD pipeline – and simultaneously the integration of an established e-commerce platform through a development partner.

## The Challenge: Hybrid Architecture

Large e-commerce platforms have evolved over years. That also means: **Legacy is reality.**

Our architecture today:

- **An established commerce platform** – proven, but with older technologies
- **PWA Storefront** – modern Angular-based Progressive Web App
- **Modern Microservices** – Offer Service, Merchant Service, Product Service
- **SPA-based Admin Portal** – completely modern development

The interesting part: The PWA looks modern, runs on a modern stack – but still works with the legacy platform in the background. Certain functions like checkout or complex account management are delegated to the established system.

**This is enterprise reality:** Not everything can be rewritten overnight. You have to work with what's there.

## What Docker Solves Here Specifically

## 1. Service Isolation Despite Heterogeneous Technologies

We have services on different tech stacks:

- Legacy platform (Java-based, older frameworks)
- Modern backend services (current Java versions, modern architectures)
- Frontend (Angular PWA, Node.js-based)

Without Docker, every developer would have to install and maintain all these environments locally. With Docker, each service runs in its own container with exactly the dependencies it needs.

**Result:** A developer can work on the frontend without having Java installed. A backend developer can test different service versions in parallel.

## 2. CI/CD Pipeline Becomes Consistent and Fast

The switch from Jenkins to Azure DevOps with Docker brought measurable improvements.

**Before (Jenkins):**

- Build time: 15-25 minutes (depending on service)
- Deployment: manual, error-prone
- Differences between build environment and production

**Now (Azure + Docker + Helm):**

- Build time: 8-12 minutes for most services
- Deployment: automated via Helm Charts
- Identical containers from dev to production

The modern services – Offer Service, Merchant Service, Product Service – run particularly well. They were designed for containers from the start. Short build times, clear dependencies, clean isolation.

## 3. Helm Charts: Deployment Becomes Declarative

Helm Charts revolutionized deployment. Instead of manual configuration, a YAML file describes the entire deployment:

```yaml
service: offer-service
version: 1.2.3
replicas: 3
resources: ...
```

A deployment across multiple environments (Dev, Staging, Production) becomes:

- Traceable (everything is versioned in Git)
- Repeatable (same command, same result)
- Safe (rollback possible with one command)

## 4. The Legacy Bridge: Old and New Coexist

Here Docker's true strength shows: **It enables coexistence.**

The legacy platform runs in its containers with its specific requirements. The modern services run in their containers with modern stacks. The PWA communicates with both – transparently through Docker networking.

We don't have to rewrite the old platform. We can gradually replace it with modern services – service by service. Docker makes this evolutionary approach practical.

## What You Need to Learn (The Critical Points)

After years with Docker in this complex environment, I've also learned: **It's not a silver bullet.**

## 1. Performance Differences Are Real

The modern services build quickly and run performantly. But some older services or components are slower.

**Why?**

- Large images (sometimes 1-2 GB)
- Complex build processes
- Many dependencies

**Lesson:** Docker doesn't make slow software fast. It just makes it reproducibly slow.

## 2. Debugging Becomes More Complex

When a service doesn't work in a container, debugging is more difficult:

- Logs are distributed across multiple containers
- Network issues between containers are subtle
- Accessing running containers requires additional steps

**Solution:** Good logging and monitoring aren't optional. They're critical.

## 3. Image Management Requires Discipline

With Azure Container Registry and many services, we have hundreds of images. Without clear versioning and cleanup strategy, it quickly becomes confusing.

**Learnings:**

- Use semantic versioning consistently
- Delete old images regularly
- Automate security scans

## 4. Not Everything Belongs in Containers

I've also learned: Some components run better outside of containers. Especially with I/O-intensive operations or when external tools need to be integrated.

**The question isn't:** "Can I dockerize this?"
**The question is:** "Should I dockerize this?"

## What I Really Learned

After years in this hybrid world between legacy and modern microservices, my most important insight is:

**Docker is an enabler for gradual transformation.**

It allows us to:

- Keep old systems alive while we build new ones
- Run different technologies in parallel
- Develop and deploy services independently
- Let teams work autonomously

But it doesn't replace:

- Good architecture decisions
- Clear documentation
- Understanding of your own systems
- Disciplined development processes

The teams that succeed with Docker have understood: **Docker is a tool, not an end in itself.**

## When Does Docker Make Sense?

Based on this experience, I would recommend Docker for:

- ✓ Microservices architectures – Each service in its container, clear boundaries, independent deployments.
- ✓ Hybrid environments (Legacy + Modern) – Enables gradual migration without big-bang rewrite.
- ✓ Teams with multiple developers – Uniform development environments save enormous amounts of time.
- ✓ CI/CD pipelines – Build once, run anywhere – from local testing to production.
- ✓ Cloud deployments – Almost all cloud platforms support containers natively.

But be careful with:

- ✗ Very simple projects – A static website doesn't need container overhead.
- ✗ Teams without Docker experience under time pressure – The learning curve is real. Better take time or work classically first.
- ✗ Legacy monoliths without clear modularization – Putting a monolith in a container doesn't solve architecture problems.
- ✗ Performance-critical applications with high I/O – Container overhead can be noticeable here.

## Looking Forward

These years with Docker in a complex enterprise environment have shaped my perspective on software development.

I've learned:

**Technology must solve problems, not create them.**
Docker solves real problems – when used correctly.

**Pragmatism beats purism.**
The perfect architecture on paper is useless. The hybrid solution that works is better.

**Evolution beats revolution.**
Complete rewrites are often not possible. But gradual replacement works.

**Teams are more important than tools.**
Docker is only as good as the team using it. Without shared understanding, clear standards, and discipline, even Docker becomes a problem.

## What This Means for Me

This experience – between legacy and modern microservices, between old and new technologies – has shown me what software development is really about:

**Not using the coolest technology, but the right one.**

Not rebuilding everything, but **working smart with what's there.**

Not striving for perfection, but **continuous improvement.**

This is the mindset I bring to future projects.

Because in the end, it's not about containers, microservices, or CI/CD pipelines.

**It's about building software that solves real problems – pragmatically, sustainably, and with value for the people who work with it.**
