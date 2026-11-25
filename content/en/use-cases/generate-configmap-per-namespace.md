---
title: Generate a ConfigMap in every new namespace
linkTitle: ConfigMap per namespace
weight: 40
description: A namespace gets its platform ConfigMap the moment it exists, without a controller of your own.
policy: generation
labels:
  - topic:configmaps
  - topic:namespaces
  - topic:bootstrap
  - resource:configmaps
  - resource:namespaces
  - engine:gotmpl
  - level:intermediate
---

Every namespace needs the same small ConfigMap: the log endpoint, the cluster name, the region. Done
by hand, it is a step in a checklist that half the teams skip.

```yaml
apiVersion: admitik.dev/v1alpha1
kind: ClusterGenerationPolicy
metadata:
  name: platform-config
spec:
  overwriteExisting: true
  deletionPolicy: Delete
  watchedResources:
    - group: ""
      version: v1
      resource: namespaces
  conditions:
    - name: skip-system-namespaces
      engine: cel
      key: |
        !(object.metadata.name in ["kube-system", "kube-public", "kube-node-lease"])
      value: "true"
  object:
    definition:
      engine: gotmpl
      template: |
        apiVersion: v1
        kind: ConfigMap
        metadata:
          name: platform
          namespace: {{ .object.metadata.name }}
        data:
          CLUSTER: "prod-eu-1"
          LOG_ENDPOINT: "https://logs.internal/ingest"
```

## Fixed values

When nothing has to be computed, a `plain` definition is the whole manifest.

```yaml
apiVersion: admitik.dev/v1alpha1
kind: ClusterGenerationPolicy
metadata:
  name: platform-config-fixed
spec:
  overwriteExisting: true

  watchedResources:
    - group: ""
      version: v1
      resource: namespaces

  conditions:
    - name: first-condition
      engine: cel
      key: |
        object.metadata.name
      value: "default"

  object:
    clone: {}
    definition:
      engine: plain
      template: |
        apiVersion: v1
        kind: ConfigMap
        metadata:
          name: whatever-config-plain
          namespace: "default"
        data:
          FIRST_SOURCE_ITEM_NAME: "fixed-value"
          FIRST_SOURCE_ITEM_NAMESPACE: "fixed-value-other"
```

## With a source and plain+cel

The namespace comes from the event and the first data key from a source.

```yaml
apiVersion: admitik.dev/v1alpha1
kind: ClusterGenerationPolicy
metadata:
  name: platform-config-cel
spec:
  overwriteExisting: true

  watchedResources:
    - group: ""
      version: v1
      resource: namespaces

  sources:
    - group: ""
      version: v1
      resource: configmaps

  conditions:
    - name: first-condition
      engine: cel
      key: |
        object.metadata.name
      value: "default"

  object:
    clone: {}
    definition:
      engine: plain+cel
      template: |
        apiVersion: v1
        kind: ConfigMap
        metadata:
          name: whatever-config
          namespace: "{{cel: object.metadata.name }}"
        data:
          FIRST_SOURCE_ITEM_NAME: "{{cel: sources[0][0].metadata.name }}"
          FIRST_SOURCE_ITEM_NAMESPACE: "{{cel: sources[0][0].metadata.namespace }}"
```

## Notes

- `overwriteExisting: true` writes the ConfigMap again on every event on the namespace, which
  overwrites a hand edit.
- `deletionPolicy: Delete` removes the generated ConfigMaps when the policy is removed. The
  `admitik.dev/policy` label is what finds them.
