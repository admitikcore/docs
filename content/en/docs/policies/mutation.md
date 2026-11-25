---
title: Mutation
linkTitle: Mutation
weight: 20
description: Patch an object before it is stored, and decide whether later policies see the result.
---

A `ClusterMutationPolicy` answers the API server with a JSON patch. It never writes to the cluster
on its own.

```yaml
apiVersion: admitik.dev/v1alpha1
kind: ClusterMutationPolicy
metadata:
  name: add-team-owner
spec:
  priority: 10
  interceptedResources:
    - group: ""
      version: v1
      resource: namespaces
      operations: [CREATE]
  patch:
    type: jsonmerge
    engine: plain
    template: |
      metadata:
        labels:
          managed-by: platform
```

## Patch types

| `type` | The template must render |
| --- | --- |
| `jsonmerge` | A partial object, merged into the existing one |
| `strategicmerge` | A strategic merge patch, resolved against the OpenAPI schema |
| `jsonpatch` | A list of RFC 6902 operations |

`jsonmerge` and `strategicmerge` are the ones to reach for: the template describes the result, not the
mechanics. `jsonpatch` is for removals and moves.

## Priority and order

Mutations are evaluated by `priority` ascending, then by name. That order is what makes several
replicas produce the same result, so it is not negotiable.

## Composition

By default every mutation policy sees the **original** object, so two policies that touch the same
field both compute from the same starting point and the last one wins.

With `--compose-mutations`, each policy sees the object as the previous ones left it. It is opt-in
because a policy written for the original object can then behave differently, and because the order
becomes visible in the result.
