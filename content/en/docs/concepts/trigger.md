---
title: Trigger
linkTitle: Trigger
weight: 10
description: Which resources make a policy run, and on which events.
---

Every policy declares what it watches.

- **Admission policies** use `interceptedResources`. Admitik tells Kubernetes which requests to send it
  while an object is being stored, and it builds that from this list: the policy sees nothing it did
  not ask for.
- **Background policies** use `watchedResources`, and each entry is one resource type to follow.

## Intercepted resources

```yaml
interceptedResources:
  - group: apps
    version: v1
    resource: deployments
    operations: [CREATE, UPDATE]
    namespace: production   # optional
    name: web               # optional
```

| Field | Meaning |
| --- | --- |
| `group` | The API group. Empty means the core group |
| `version` | The version, such as `v1` |
| `resource` | The plural name, such as `deployments` |
| `operations` | Any of `CREATE`, `UPDATE`, `DELETE` |
| `namespace` | Only the objects in this namespace. Empty means all of them |
| `name` | Only the object with this name. Empty means all of them |

`namespace` must be empty for cluster scoped resources. Leaving it out of the manifest and leaving it
empty are the same thing.

## Watched resources

```yaml
watchedResources:
  - group: ""
    version: v1
    resource: namespaces
    name: team-a        # optional
    namespace: ""       # optional
```

Same fields, minus `operations`: the background path reacts to what appears and what changes, not to
deletions of the objects it watches.

## Several entries

A policy can list as many as it needs. They share the policy, the sources and the conditions:

```yaml
interceptedResources:
  - group: apps
    version: v1
    resource: deployments
    operations: [CREATE, UPDATE]
  - group: apps
    version: v1
    resource: statefulsets
    operations: [CREATE, UPDATE]
```

## What it costs

**Admission costs requests.** Each `interceptedResources` entry becomes one rule that tells Kubernetes
which requests to send to Admitik before storing the object. Every matching request is evaluated, so
each entry adds work to the cluster. Setting `name` or `namespace` on the entry removes requests from
that rule: the objects outside stay out of the policy.

**Background costs memory.** To notice that an object appeared or changed, Admitik keeps a copy of the
whole resource type in memory, updated with every change. A watch over `pods` in a large cluster holds
every pod, in every replica. Two policies watching the same resource type share one copy.

Setting `namespace` limits the copy to that namespace, and `name` limits it to that object. What a
[source filter](/docs/concepts/sources-and-conditions/#filters) does is different: the copy is the
same, and the filter only reduces what each evaluation receives.

A watch over a resource type that does not exist in the cluster retries forever and writes to the log
of the controller. Leave out what you do not have.
