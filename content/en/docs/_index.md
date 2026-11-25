---
title: Documentation
linkTitle: Documentation
weight: 10
description: What Admitik is, how to install it, and how to write policies.
---

Admitik is a policy engine for Kubernetes. It reads policies from the cluster as custom resources
and acts on two paths:

- **Admission.** It answers the API server before an object is stored. It validates, mutates, or both.
- **Background.** It watches what already exists and writes the objects a policy asks for.

Nothing else is needed: no database, no sidecar, no external service. A policy is a CR, and deleting
it is how you turn it off.

## Where to start

- [Installation](/docs/installation/) if you want it running.
- [Concepts](/docs/concepts/) if you want to know what a policy is made of.
- [Policies](/docs/policies/) if you want to write one.
- [Use cases](/use-cases/) if you want a working example to copy.
