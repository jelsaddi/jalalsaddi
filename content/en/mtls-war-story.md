---
title: "The mTLS War Story: A Trust Store, Two Secret Managers, and a Password That Isn't Supposed to Exist"
date: "2026-09-12"
description: "A payment provider required mutual TLS. What looked like 'just add a certificate' turned into a trust-store gotcha, two competing secret-sync mechanisms in the same cluster, and a password Azure quietly throws away."
tags: ["mTLS", "Kubernetes", "Security", "Azure"]
image: "/mtlsWarStory.jpeg"
featured: true
---

# The mTLS War Story: A Trust Store, Two Secret Managers, and a Password That Isn't Supposed to Exist

It started with a stack trace I'd never seen in the wild before: `PKIX path building failed`. A payment provider integration I was wiring up needed mutual TLS on a handful of its API endpoints, and my first call to their sandbox just... refused to shake hands. Not a 401, not a timeout — a raw TLS handshake failure, the kind that tells you the two sides can't even agree to talk to each other yet, let alone about anything useful.

I've done plenty of "add a client certificate" integrations before. This one turned out to be a different animal, and it dragged me through Kubernetes secret plumbing, a JVM trust-store landmine, and a genuinely surprising discovery about how the same cluster was quietly running two unrelated ways of getting secrets out of the same vault.

## Two problems wearing one name

Mutual TLS is really two separate obligations bolted together under one term. Our side has to *prove who we are* by presenting a signed client certificate. And we have to *trust who they are* by accepting their server certificate. Most TLS work only ever touches the second half — your JVM already trusts every public CA out of the box, so HTTPS just works. mTLS means both directions need explicit configuration, and it turned out each half had a completely different failure mode waiting for me.

The client-certificate half was the easy one, conceptually: load a PKCS#12 keystore, hand it to the SDK's `Configuration` object, done. The SDK we were using exposed a proper per-instance hook for this, so the certificate only ever applied to that one API client — no leakage into anything else the application talked to.

The server-trust half is where things got interesting. The payment provider's mTLS endpoints present a certificate chain signed by their own private root CA — a CA that exists specifically for this purpose and, understandably, isn't in any public trust store. Turning on SSL debug logging (`-Djavax.net.debug=ssl:handshake`) confirmed it: this wasn't a malformed certificate, it was a plain "I don't know who signed this" rejection.

## Why you never *replace* a JVM's trust store

The obvious fix — point `javax.net.ssl.trustStore` at a keystore containing just the provider's root CA — is also a great way to quietly break every other outbound HTTPS call the JVM makes. Search connections, any other third-party API, anything using standard TLS: all of it depends on the JVM's default set of trusted root CAs. Swap the trust store out entirely and you've traded one integration's TLS error for a much larger and much less obvious outage everywhere else.

The fix that actually works is duller than it sounds satisfying: load the JVM's *existing* default trust store, add the provider's root CA on top of it, and write the merged result out as a new trust store that the JVM then uses instead. Same trusted CAs as before, plus one more. It's the kind of solution that looks almost too simple once you've found it, and that's exactly why it's easy to miss when you're staring at a stack trace assuming the problem must be something more exotic.

One detail worth keeping: the certificate provider's server certificate wasn't a single cert, it was a chain — an intermediate plus a root. Using the "parse one certificate" API call would have silently dropped everything but the first entry. Switching to the "parse a collection" variant and looping over whatever came back meant the code never had to know or hardcode how many certificates were in that chain.

## Where the certificates actually live

Neither the client certificate nor the trusted root CA lives anywhere near the application code. Both sit in Azure Key Vault, get synced into Kubernetes as native `Secret` objects, and land in the running containers as plain environment variables. The code that reads them has zero awareness that Key Vault exists — it just reads two base64-encoded environment variables and decodes them. That decoupling turned out to be one of the more valuable design choices in the whole thing: the exact same code path works whether the value came from a real vault sync in a managed environment, or was exported by hand in a local shell for development.

That decoupling is also what let me discover something I genuinely didn't expect going in: **two completely different applications in the same cluster, reading from the same family of vaults, using two unrelated mechanisms to get the secrets out.** One service used the External Secrets Operator — a Kubernetes-native controller that watches the vault and keeps a `Secret` object in sync on its own schedule. Another service used the Secrets Store CSI Driver, which mounts vault secrets as files into a pod and needs a small always-running helper deployment whose only job is to force that mount to happen so the values can be projected into a native `Secret` object other pods can reference.

Nothing in the platform enforces consistency here — it's simply how each piece was built over time, by different people, at different points. Once I understood *why* one team's own documentation recommended the operator-based approach over the CSI one — no permanently-running helper pod required, syncing happens on its own refresh interval rather than needing something to trigger it — the inconsistency made more sense as history rather than as an oversight. But it's the kind of thing you only find by actually going and comparing the two YAML files side by side, not by reading a design doc that describes only one of them.

## The password that Azure quietly deletes

The strangest moment of the whole project was realizing that the keystore password stored next to the client certificate in Key Vault was an empty string — on purpose. This turns out to be documented, if you go looking: once you import a password-protected certificate into a certificate-store service like this, the import password isn't retained. It was only ever needed for the one-time import operation. Every subsequent read of that certificate's backing material comes back with no password, regardless of what you used originally.

So the code had to be written to treat "no password" as the *normal* case, not an error condition — an empty password isn't a placeholder for "someone forgot to fill this in," it's the expected, correct value every time. And the password entry has to keep existing as an empty string rather than being omitted entirely, because the plumbing that injects these values as environment variables expects a fixed set of keys to exist; a missing key surfaces as a hard container-startup failure, which is a worse failure mode than a certificate that quietly loads with a blank password the application already knows how to handle.

Getting an empty string *into* the vault in the first place turned out to have its own small trap: the CLI tooling treats an empty `--value ""` as "no value provided" and rejects it outright, rather than as "explicitly set this to empty." The workaround — writing the empty value to a temp file and uploading from the file instead of the command line — is one of those five-minute fixes that costs you forty-five minutes of confused debugging first.

## The renewal problem, and why it looked easy but wasn't

Client certificates expire, roughly yearly in our case, and someone eventually has to generate a new certificate signing request, get it signed, and roll it back into every environment. This sounds like a script you write once and forget. It mostly is — except for a subject-line quirk that cost real debugging time: on Windows, Git Bash silently rewrites a leading-slash CSR subject string into something that looks like a Windows file path before the underlying TLS tooling ever sees it, producing an error message that reads like a syntax problem in your subject string when the actual issue is a shell environment variable mangling your input. The fix is one environment variable set at the top of the script; finding *why* the fix was needed took considerably longer than writing it.

The renewal tooling also had to account for a third consumer of the same certificates that didn't fit the pattern at all: an older service that stores its copy of the same credentials as plaintext SQL config inserts, committed directly into its repository — no vault, no rotation automation, the actual password sitting in plaintext in version control. That's not something this project fixed; it's a known, deliberately-flagged risk that's separate from and predates the mTLS work, left honestly documented rather than either silently ignored or hastily "fixed" under time pressure with something that might get thrown away once that service's own secret-storage story changes.

## What actually stuck with me

A few things from this one are worth carrying into the next integration that needs mutual TLS:

**Decouple the code from where the secret comes from.** The moment your application code reads an environment variable instead of talking to a vault SDK directly, local development, CI, and production all exercise the identical code path. That single decision saved more debugging time than anything else here.

**Never replace a JVM-wide resource — merge into it.** Anything that touches `javax.net.ssl.trustStore`, or any other JVM-global system property, is a blast radius bigger than your one integration. Load what's already there, add to it, write the merge back out.

**"Coexisting" secret mechanisms in one cluster are more common than you'd think, and worth mapping explicitly.** If two services solve the "get a secret out of the vault" problem differently, that's not automatically a bug — but it's exactly the kind of thing that should be written down somewhere, because the next person debugging a stale secret will otherwise burn an hour figuring out which mechanism even applies to which pod.

**When a password disappears on you, check whether that's a documented feature before you assume it's a bug.** The empty-password case looked, at first glance, exactly like a misconfiguration. It wasn't — it was the platform behaving correctly, and the fix was in how the application code interpreted "empty," not in trying to somehow recover a password that was never retrievable in the first place.

Mutual TLS earns its reputation for being fiddly not because any single piece of it is hard, but because it sits at the intersection of cryptography, cloud secret management, and Kubernetes plumbing — three layers that each have their own quiet conventions, and none of which tell you when you've violated one of the others'.
