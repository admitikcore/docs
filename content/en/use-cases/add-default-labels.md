---
title: Add platform labels to every namespace
linkTitle: Default labels on namespaces
weight: 30
description: Namespaces get the labels the platform reads, without asking anyone to remember them.
policy: mutation
labels:
  - topic:namespaces
  - topic:labels
  - topic:defaults
  - resource:namespaces
  - engine:plain
  - level:starter
---

Labels that the platform reads are labels people forget.

```yaml
apiVersion: admitik.dev/v1alpha1
kind: ClusterMutationPolicy
metadata:
  name: default-namespace-labels
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
          admitik.dev/tier: standard
```

## With Plain + CEL

`plain+cel` keeps the patch readable and lets one value come from the object.

```yaml
apiVersion: admitik.dev/v1alpha1
kind: ClusterMutationPolicy
metadata:
  name: default-namespace-labels-cel
spec:
  interceptedResources:
    - group: ""
      version: v1
      resource: namespaces
      operations:
        - CREATE

  patch:
    type: jsonmerge # JsonPatch | JsonMerge | StrategicMerge
    engine: plain+cel
    template: |
      metadata:
        labels:
          patch-01-custom-label/namespace: "{{cel: object.metadata.name }}"
```

## With a strategic merge

A strategic merge needs the whole object, not only the part that changes.

```yaml
apiVersion: admitik.dev/v1alpha1
kind: ClusterMutationPolicy
metadata:
  name: default-namespace-labels-strategic
spec:
  interceptedResources:
    - group: ""
      version: v1
      resource: namespaces
      operations:
        - CREATE

  patch:
    type: strategicmerge # JsonPatch | JsonMerge | StrategicMerge
    engine: plain+cel
    template: |
      apiVersion: v1
      kind: Namespace
      metadata:
        labels:
          patch-07-custom-label/namespace: "{{cel: object.metadata.name }}"
```

## Notes

- `jsonmerge` merges into what the namespace already has. A `managed-by` already set by the team stays.
- If the platform value has to win, reject the other one with a validation policy instead of
  patching over it.
- Mutations run by `priority` and then by name. Ten leaves room for the policies that have to run
  before this one.
