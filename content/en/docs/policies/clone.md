---
title: Clone
linkTitle: Clone
weight: 40
description: Copy an object into another namespace or another resource. In progress.
---

{{% alert title="In progress" color="warning" %}}
The field exists in the CRD and does nothing yet. Until it ships, use a
[generation policy](/docs/policies/generation/) with a template that renders the copy.
{{% /alert %}}

Cloning copies an object that already exists into another namespace, or into another resource, when
something happens in the cluster.

The cases it covers are the ones where the object cannot be rendered from scratch: a Secret whose
contents nobody wants to repeat, a ConfigMap that a team maintains, a namespace where the same
resource has to exist in several places.
