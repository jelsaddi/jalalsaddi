---
title: "The Withdrawal Relay That Remembers Nothing: A Stateless Notification Endpoint, Two Identical 404s, and a Confirmation Email It Can't Take Back"
date: "2026-09-14"
description: "A statutory-withdrawal feature on a multi-merchant marketplace looked like a routine 'cancel my order' endpoint. It turned out to write nothing to a database, return the same 404 for two unrelated failures, and email a customer a confirmation it sometimes can't back up."
tags: ["REST API", "E-Commerce", "Architecture", "Java"]
image: "/withdrawalRelay.jpeg"
featured: true
---

# The Withdrawal Relay That Remembers Nothing: A Stateless Notification Endpoint, Two Identical 404s, and a Confirmation Email It Can't Take Back

The ticket read like a routine feature: let a customer submit a withdrawal notice ("Widerruf" — the statutory right of withdrawal EU and German consumer law gives private buyers, §355 BGB) against one merchant's portion of their order on a multi-merchant marketplace. I went looking for the data model first, the way I always do with anything that has "cancel" or "withdraw" in its name. There wasn't one. Not a missing migration, not a table I hadn't found yet — there is genuinely nowhere in the system where a withdrawal notice is recorded. The endpoint validates a form, sends two emails, and returns `200 OK`. That's the entire feature.

Once that sank in, the rest of the design made a lot more sense — and so did most of its rough edges.

## A relay, not a workflow

The platform doesn't execute the withdrawal. It has no authority to cancel or refund on a merchant's behalf on this kind of marketplace, so the endpoint's actual job is narrower than its name suggests: validate the request, confirm receipt to the customer by email, and forward a notification to the responsible merchant asking them to act within 24 hours. What happens after that — actually cancelling the line item, processing a return, refunding the customer — happens entirely outside this system, in the merchant's own tooling.

That framing matters for reimplementation, because it's tempting to build this as an order-state-machine feature and it categorically isn't one. No order object, line item, or fulfillment record changes as a result of calling it. It's closer to a contact form with strict validation and two templated emails than to a cancellation workflow.

```text
POST withdrawal notice
 |
 v
[verify captcha, if required]
 |
 v
Validate form fields
 |-- invalid ----------> 400
 v
Resolve order + merchant
sub-order
 |-- not found --------> 404
 v
Customer is private?
 |-- no ---------------> 403
 v
Send customer confirmation
 |-- fails ------------> 500
 v
Resolve merchant recipients
 |
 v
Send merchant notification
 |-- fails ------------> 500
 v
200 OK
```

Every step in that diagram is a validation or a notification. None of them is a write.

## The single fact that shapes everything else

I confirmed this by grepping the whole codebase for anything resembling a withdrawal entity — no persistent-object definitions, no setters called on the order or its line items from this code path, nothing. The endpoint only *reads* the order to resolve which merchant sub-order the customer means; it never writes to it.

The practical consequence is that there is no way to answer "was this order withdrawn?" after the fact from this system's own data. If a support agent needs to know, they're reading application logs, not querying a status field, because no status field exists. If you're reimplementing this feature and your context needs an answer to that question later — audit trail, reconciliation, anything — that's new scope, not something to carry over from the existing design. Don't assume a `status` column belongs on this table just because every other "process a form" endpoint you've built has one.

## One resource class doing everything, on purpose (mostly)

Most REST endpoints in this codebase route validation and orchestration through a service layer. This one doesn't — the resource class itself does form validation, order lookup, recipient resolution, and email dispatch, with the transaction wrapper explicitly disabled since nothing is ever written:

```java
@POST
@Consumes({ MediaType.APPLICATION_JSON })
@Transactional(false)
public Response createWithdrawalNotice(WithdrawalRequestRO request) {
    // 1. captcha gate
    // 2. four-stage form validation
    // 3. resolve order + merchant sub-order from the submitted order number
    // 4. enforce private-customer-only
    // 5. send customer confirmation email
    // 6. send merchant notification email
    // 7. return 200
}
```

The one deliberately over-engineered corner is the request DTO. The platform's base resource class silently accepts unknown JSON fields instead of rejecting them, which is exactly the wrong default for a public, unauthenticated endpoint. The fix is a custom deserializer that walks the JSON token stream by hand and rejects anything outside an explicit allow-list:

```java
static final Set<String> ALLOWED_FIELDS = Set.of(
    "merchantOrderNumber", "customerEmail", "salutation",
    "firstName", "lastName", "message"
);
```

Form validation itself runs in four strict stages, in this exact order: required-field checks (with `salutation` treated as null-only, since an empty string is a legitimate "prefer not to say"), HTML-stripping sanitisation of the free-text message only, a second blank-check *after* sanitisation (so `<script>alert(1)</script>` gets rejected as missing rather than silently accepted as an empty comment), and finally per-field format checks. One of those format checks resolves an allowed-salutation whitelist from the *current request's* locale rather than the application's default locale — get that backwards and you'll incorrectly reject valid salutations for every non-default-locale storefront.

## Two 404s, one message

Resolving the order happens in two steps: strip a merchant suffix off the submitted order number to get the parent document number, look up the order, then find the specific merchant sub-order within it. Both failure branches throw the identical message:

```java
if (order == null) {
    throw RestException.builder().notFound()
        .responseMessage("No order found for the given merchant order number").build();
}

MerchantSubOrder subOrder = merchantOrders.stream()
    .filter(mo -> merchantOrderNumber.equals(mo.getMerchantOrderNo()))
    .findFirst()
    .orElseThrow(() -> RestException.builder().notFound()
        .responseMessage("No order found for the given merchant order number").build());
```

```text
Submitted order number
 |
 v
Strip merchant suffix
 |
 v
Parent order exists?
 |-- no -----------+
 v                 |
Sub-order matches  |
the suffix?        |
 |-- no -----------+
 v                 v
Continue           404
                   "No order found
                   for the given
                   merchant order
                   number"
(both cases: identical message)
```

Two genuinely different failures, both ending in the same 404 message in the diagram. "The order number is completely wrong" and "the order exists but this merchant suffix doesn't match anything on it" are different problems with different likely causes — a typo versus a stale link, say — and a support engineer reading a log line can't tell them apart. It's a small thing, but it's exactly the kind of ambiguity that turns a two-minute support ticket into a twenty-minute one.

## The confirmation email you can't take back

This is the gotcha I'd flag first to anyone reimplementing this feature. The two emails aren't sent atomically, and they aren't sent in a symmetric order of consequence: the customer confirmation goes out first, and only if it succeeds does the code attempt the merchant notification.

```java
sendWithBcc(request.getCustomerEmail(), bcc, sender, locale, clientTemplate, subject);
// merchant email only attempted if the line above didn't throw
List<String> recipients = resolveMerchantRecipients(merchantId);
if (recipients.isEmpty()) {
    throw new WithdrawalNotificationException("No recipients found for merchant notification.");
}
sendWithBcc(recipients, bcc, sender, locale, merchantTemplate, subject);
```

If the merchant email fails — no recipients resolved, or the send itself fails after retries — the endpoint returns `500`. But the customer has already received a confirmation implying their withdrawal was processed. There's no compensating notification back to the customer, no persisted failure record, and no retry queue; the only trace is a server-side log line. Anyone building monitoring around this endpoint needs to watch logs specifically for that failure mode, because nothing queryable in the system's own data will ever surface it.

```text
1. Client -----> Endpoint
   Submit withdrawal notice
2. Endpoint --> Customer
   Confirmation email: OK
   (customer now believes it
    is being handled)
3. Endpoint --> Directory
   Resolve merchant recipients
4. Directory --> Endpoint
   no recipients / error
5. Endpoint --> Client
   500 Internal Error
   !! No compensating message
      ever reaches the customer !!
```

The email send itself does retry — three attempts, two seconds apart, hardcoded rather than configurable — but retry only protects against transient send failures, not against the ordering problem above.

## Recipients from a cache, a fallback, or nowhere

The merchant's notification address doesn't live in this system at all; it's resolved from an external merchant-directory service, fetched over OAuth2 client-credentials and cached for five minutes to avoid hammering that service on every submission:

```java
List<String> resolveMerchantRecipients(String merchantId) {
    List<String> recipients = merchantId != null
        ? fetchFromMerchantDirectory(merchantId)   // broad catch(Exception) inside
        : new ArrayList<>();
    if (recipients.isEmpty()) {
        recipients = resolveFallbackRecipient(config); // static config address
    }
    return recipients;
}
```

```text
Resolve merchant recipients
 |
 +- Merchant ID missing?
 |    yes --> fallback address
 |
 +- Query merchant directory
 |    success, non-empty
 |      --> use those recipients
 |    error or empty
 |      --> fallback address
 |
 v
Send notification
(fallback = static config address)
```

Two things worth flagging if you're building something similar. First, any failure talking to that external service — timeout, auth error, unexpected response — degrades silently to a static fallback address rather than failing the request outright. That's a defensible choice (better a generic support inbox gets the notification than nobody does), but it's a choice, and it should be a conscious one rather than an accident of a broad `catch`. Second, if more than one adapter instance for that external service is ever configured, the code takes whichever one comes back first from an unordered collection — fine with exactly one adapter configured, quietly non-deterministic with two.

The five-minute cache means a merchant who updates their notification address has up to five minutes where notices still go to the old one. Worth documenting explicitly if recipient correctness during a merchant's address rollover is ever business-critical.

## What I kept, what I'd change

**Stateless-by-design is fine — as long as you say so out loud.** Nothing here is broken by having no persistence; a lot of "just relay this to someone else" features genuinely don't need a database row. The mistake would be reimplementing it *assuming* state exists somewhere, or bolting on a database later without deciding what the dedup/status semantics should actually be.

**Identical error messages for different root causes save you nothing.** Two branches, two messages, five extra words. It costs almost nothing at write time and saves real debugging time later.

**Order your side-effecting calls by what you can and can't undo.** If one of two actions can't be walked back once it succeeds, the one you can't undo shouldn't be the one you attempt first without a plan for what happens if the second one fails. In this case, that plan doesn't fully exist yet — which is a known gap, not an oversight I'm pretending not to see.

**A silent fallback is a design decision, not a safety net.** "Degrade gracefully" is good practice; "degrade gracefully without anyone deciding that's what should happen" is how you end up debugging why notifications quietly went to a generic inbox for three months before anyone noticed.

A feature that "just sends two emails" doesn't sound like it deserves this much scrutiny. It earns it anyway, the same way a lot of small, boring-looking integration points do — not because any one piece is hard, but because it sits between a legal deadline, a cross-org communication step, and a customer-facing confirmation that, once sent, the system has no way to walk back.
