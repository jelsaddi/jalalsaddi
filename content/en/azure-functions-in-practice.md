---
title: "Azure Functions in Practice: Automated Image Processing in E-Commerce"
description: "A detailed case study on using Azure Functions for automatic image resizing in an e-commerce platform, covering architecture, implementation, and lessons learned about serverless computing."
date: "2025-10-16"
image: "azureFunctionsEcommerce.jpeg"
tags: [Azure Functions, Serverless, E-Commerce, Image Processing]
---

# Azure Functions in Practice: Automated Image Processing in E-Commerce


After many years in software development, I’ve learned: The best technical solutions are often the invisible ones. Serverless computing long sounded like a buzzword to me – until I had a concrete use case where Azure Functions turned out to be exactly the right tool.

This is the story of how we solved a recurring problem elegantly with a simple serverless function – and what I really learned about serverless along the way.

## The Context: E-Commerce and the Image Problem

We’re working on an e-commerce marketplace deployed on Azure. As in any online shop, product images are central to the user experience. But product images have a problem: **one image doesn’t fit everywhere.**

## The Reality

- Homepage tiles need small thumbnails (fast loading, overview)
- Product listings need medium images (balance between quality and performance)
- Product detail pages need large, high-resolution images (zoom, detail)

Our images first land as originals in **Azure Blob Storage** – uploaded by merchants, product managers, or via APIs.

**The problem:** The originals are often 3–5 MB in size. Completely oversized for thumbnails. Disastrous for mobile. A nightmare for page speed.

## The Problem: Each image in three sizes – automatically

The requirement was clear:

**Each product image must be available in three formats:**

- Thumbnail – small preview
- Medium – standard view in listings
- Large – high-resolution for detail pages

Specifically:

- ✅ Automatically for every new image
- ✅ On every update of existing images
- ✅ Also for all existing images (migration)

## Why this isn’t trivial

**Option 1: On-the-fly resizing on request**

- Server has to process the image on every request
- Performance issue with many simultaneous requests
- Caching helps, but the first request is slow

**Option 2: Manual resizing before upload**

- Merchants must upload three versions
- Error-prone, inconsistent
- Impossible for thousands of existing images

**Option 3: Cronjob on a server**

- Server runs 24/7, even when idle
- Polling is inefficient
- Delay between upload and availability

**What we needed:** A solution that reacts automatically, runs efficiently, and doesn’t cost for idle time.

## The Solution: Azure Functions + Blob Storage Trigger

A colleague suggested: **Azure Functions with a Blob Storage Trigger.**

## The Concept

- A new image is uploaded to Azure Blob Storage
- Blob Storage automatically fires an event
- Azure Function is triggered (no polling, no delay)
- Python script with ImageMagick processes the image
- Three versions are saved back into Blob Storage

## The Architecture

With Azure Functions:

```
Upload original image
        ↓
Azure Blob Storage (Input)
        ↓
[Blob Trigger fires automatically]
        ↓
Azure Function (Python + ImageMagick)
        ↓
Processing: Thumbnail, Medium, Large
        ↓
Azure Blob Storage (Output)
        ↓
Three formats available
```

**A simple but effective architecture – fully automated and without manual intervention.**

## Why Azure Functions?

- **Event-driven:** No polling required. The function starts automatically when a blob is added or modified.
- **Serverless:** No VM running 24/7. The function exists only while executing. You only pay for the seconds it runs.
- **Auto-scaling:** 100 images uploaded at once? Azure automatically spins up multiple instances in parallel.
- **Managed infrastructure:** Microsoft handles runtime, updates, and availability. We just write code.

## The Technical Implementation

- **Python runtime on Azure Functions:** Python was the natural choice – simple, great image-processing libraries, familiar to the team.
- **ImageMagick:** Open-source image processing tool. Can resize, convert, and optimize images. Called via Python.
- **Blob Trigger:** Azure Functions have native integration with Blob Storage. Trigger code is minimal – Azure handles the rest.

## The Corrective Script

The function handled new uploads. But what about **thousands of existing images?**

We wrote a one-time corrective script that iterates over all images in storage, calls the Azure Function for each (or processes directly). One-time migration, afterwards everything runs automatically.

## What Works: Concrete Successes

## 1. Automation is completely invisible

**That’s the best sign:**

No one even thinks about it anymore.

- Merchants upload images → seconds later all three formats are available.
- No manual steps.
- No waiting time.
- No support tickets.

## 2. Website performance improved

Before:

- Homepage loaded 3–5 MB images, even when only thumbnails were shown
- Slow load times, especially on mobile
- Poor Page Speed Score

After:

- Thumbnails: ~50 KB instead of 3 MB
- Medium: ~200 KB
- Large: Original quality only where needed

**Result:** Measurably faster load times, better user experience.

## 3. Cost Efficiency

Azure Functions pricing is usage-based:

- You pay per execution and per second of runtime
- With moderate upload volume (daily new products, occasional updates), costs remain minimal

Compared to a VM running 24/7:

- No idle costs
- No maintenance
- Automatic scaling without cost planning

## 4. Easy Maintenance

The code is simple. A Python script calling ImageMagick. No complex infrastructure. Changes are quickly deployed.

## What to Watch Out For: Critical Points

After months of production use, I’ve also learned: **Serverless is not a silver bullet.**

## 1. Cold start can be noticeable

If the function hasn’t run for a while, Azure needs to spin up a new instance. That takes a few seconds.

**In our case:** Usually not an issue, since images aren’t processed in real time in front of users. But for interactive use cases (e.g. user uploads an image and wants to see it immediately), cold starts can be annoying.

**Solution:** Premium plan with “Always On” – but then you pay for idle time.

## 2. Debugging is harder

When something goes wrong, debugging is more complicated than on a normal server:

- Logs are scattered across Azure Application Insights.
- Local testing requires Azure Functions Core Tools.
- Errors are harder to trace.

**Lesson:** Build good logging from the start. Not afterwards.

## 3. Vendor Lock-in

Azure Functions are Azure-specific. Migrating code to AWS Lambda requires adjustments. Not impossible, but not trivial.

**Trade-off:** For us, developer experience and native Azure integration were more important than portability.

## 4. ImageMagick in Serverless is… special

ImageMagick is an external tool. In Azure Functions, it must be packaged as a dependency. This makes the deployment package larger and slower.

**Alternative:** Managed services like Azure Cognitive Services for image processing. More expensive, but simpler.

**We stuck with ImageMagick:** More control, cheaper, and the use case is simple enough.

## 5. Not suitable for everything

Azure Functions are perfect for:

- Event-driven tasks
- Short-running operations (< 10 minutes)
- Unpredictable load

Azure Functions are NOT good for:

- Long-running processes (> 10 minutes)
- Constant high load (a VM is cheaper)
- Very complex state management

## Learnings: What I Really Took Away

After this experience with serverless, I understood:

## 1. Serverless doesn’t mean “no server”

It means: **You no longer manage the server.**

The infrastructure still exists. You just don’t see it. That’s abstraction, not disappearance.

## 2. Serverless is an architectural decision

You can’t just make an app “serverless.” Serverless works for **specific use cases:**

- Event-driven workflows
- Sporadic tasks
- Auto-scaling requirements

But not as a replacement for everything.

## 3. The ROI is real – when used right

**For our use case:**

- No VM maintenance
- No idle costs
- Automatic scaling
- Fast development

That saves time, money, and complexity.

**But:** For other use cases, a VM or container would have been cheaper and simpler.

## 4. Start simple, optimize later

Our first version was simple: Python + ImageMagick + Blob Trigger. Done.

No micro-optimizations. No complex architecture. **It worked.**

Later, you can optimize (Premium Plan, better caching, alternative libraries). But for the start: **Simple is better.**

## 5. Serverless has become a commodity

Five years ago, serverless was experimental. Today, it’s standard. AWS Lambda, Azure Functions, Google Cloud Functions – all major cloud providers offer it.

**This means:** It’s no longer a hype. It’s a tool in the toolbox. Not a must-have, but a valid option.

## When would I recommend Azure Functions?

After this experience, I’d recommend Azure Functions (or serverless in general) for:

- **✓ Event-driven tasks** – Something needs to happen when an event occurs (blob upload, queue message, HTTP request).
- **✓ Sporadic workloads** – Not 24/7, but occasionally – unbeatable serverless cost model.
- **✓ Prototyping and MVPs** – Quickly test an idea without setting up infrastructure.
- **✓ Glue code between services** – Small functions connecting different Azure services.
- **✓ Auto-scaling needs** – Load is unpredictable, serverless scales automatically.

But be careful with:

- **✗ Long-running processes** – Azure Functions have timeouts (default: 5 min, max: 10 min). For longer jobs: Azure Batch, Containers, or VMs.
- **✗ Constant high load** – If a function runs 24/7, a VM is cheaper.
- **✗ Complex state management** – Serverless is stateless. For complex workflows: Durable Functions.
- **✗ Very low-latency requirements** – Cold start can be problematic.

## Looking Ahead

This experience with Azure Functions taught me:

**Technology should fit the problem, not the other way around.**

We had a clear problem: automatically processing images. Azure Functions were perfect for that.

But I wouldn’t try to build everything with Functions. Some problems need VMs. Some need containers. Some need serverless.

**The art lies in choosing the right tool.**

This is the mindset I’ve taken from 15 years of development: Don’t chase trends, solve problems. Don’t believe the hype, weigh pros and cons. Don’t aim for perfection – build pragmatic solutions that work.

Because in the end, it’s not about serverless, microservices, or containers.

**It’s about building software that solves real problems – efficiently, maintainably, and with value for the people who use it.**
