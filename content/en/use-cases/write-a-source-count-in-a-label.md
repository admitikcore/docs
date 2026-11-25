---
title: Write the size of a source into a label
linkTitle: Source size in a label
weight: 65
description: A label that carries a count computed from another resource, filtered to the namespace of the object.
policy: mutation
labels:
  - topic:namespaces
  - topic:labels
  - topic:configmaps
  - resource:namespaces
  - engine:plain+cel
  - feature:sources
  - level:intermediate
---

A source is not only for conditions: the patch can read it too. Here the label carries the number of
ConfigMaps in the namespace, and the source filter uses a value of the incoming object.

```yaml
apiVersion: admitik.dev/v1alpha1
kind: ClusterMutationPolicy
metadata:
  name: namespace-configmaps-count
spec:
  interceptedResources:
    - group: ""
      version: v1
      resource: namespaces
      operations:
        - CREATE

  sources:
    - group: ""
      version: v1
      resource: configmaps
      filters:
        namespace:
          matchList:
            - kube-system
            - "{{cel: object.metadata.name }}"

  conditions:
    - name: ensure-labels-exist
      engine: cel
      key: has(object.metadata.labels)
      value: "true"

  patch:
    type: jsonpatch # JsonPatch | JsonMerge | StrategicMerge
    engine: plain+cel
    template: |
      [
        { "op": "add", "path": "/metadata/labels/patch-05-configmaps-count", "value": "{{cel: sources[0].size() }}" }
      ]
```

## Notes

- The filter has `"{{cel: object.metadata.name }}"` in its namespace list, so each namespace reads
  its own ConfigMaps instead of the whole cluster.
- `sources[0].size()` counts the objects the source returned.
