---
title: Generation
linkTitle: Generation
weight: 30
description: Write the objects that should exist because something else exists.
---

A `ClusterGenerationPolicy` runs in the background. It watches resources, and when the conditions
match it writes the object the policy defines with the labels that mark where it came from.

```yaml
apiVersion: admitik.dev/v1alpha1
kind: ClusterGenerationPolicy
metadata:
  name: default-quota
spec:
  overwriteExisting: true
  deletionPolicy: Delete
  watchedResources:
    - group: ""
      version: v1
      resource: namespaces
  conditions:
    - name: skip-system
      engine: cel
      key: object.metadata.name != "kube-system"
      value: "true"
  object:
    definition:
      engine: gotmpl
      template: |
        apiVersion: v1
        kind: ResourceQuota
        metadata:
          name: default
          namespace: {{ .object.metadata.name }}
        spec:
          hard:
            pods: "50"
```

## Writing the object

The `definition` template renders a whole Kubernetes object, YAML included, with the same context as
the conditions. Any engine works, and Go templates are usually the shortest way to fill in names and
namespaces.

## overwriteExisting

- `false` (default): the object is written once. Later changes made by people are left alone.
- `true`: every event on a watched resource renders the object again and writes it, so drift is
  corrected.

## deletionPolicy

- `Keep` (default): deleting the policy leaves the generated objects in place.
- `Delete`: everything the policy wrote is removed with it.

## Provenance

Every generated object carries three labels:

```yaml
admitik.dev/managed-by: admitik
admitik.dev/policy: default-quota
admitik.dev/policy-kind: ClusterGenerationPolicy
```

They are how `deletionPolicy: Delete` finds the objects later, and how you can tell what wrote a
resource.
