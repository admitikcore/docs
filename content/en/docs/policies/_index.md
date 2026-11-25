---
title: Policies
linkTitle: Policies
weight: 60
description: The kinds of policy, the engines they can use, and the pieces they all share.
---

| Kind | What it does | When it runs |
| --- | --- | --- |
| `ClusterValidationPolicy` | Accepts or rejects an object | Admission, before the object is stored |
| `ClusterMutationPolicy` | Patches an object | Admission, before the object is stored |
| `ClusterGenerationPolicy` | Creates objects | Background, after something is watched |

The first two answer the API server. The third runs in the background, on the leader. That difference
decides what each one can do, and it is the reason they are separate kinds.

## Before writing one

The pieces all of them share are under [Concepts](/docs/concepts/).

## Opting out

With `--enable-special-labels`, the requests Admitik receives carry a filter that leaves out any object
with this label:

```yaml
metadata:
  labels:
    admitik.dev/ignore-admission: "true"
```

It is off by default because it lets whoever can write a label skip every policy that intercepts the
resource.
