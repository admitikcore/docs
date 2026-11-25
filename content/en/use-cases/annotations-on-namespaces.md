---
title: Add annotations to every namespace
linkTitle: Annotations on namespaces
weight: 35
description: Annotations that record who owns a namespace or what touched it, without asking anyone to write them.
policy: mutation
labels:
  - topic:namespaces
  - topic:annotations
  - topic:defaults
  - resource:namespaces
  - engine:plain+cel
  - engine:starlark
  - level:intermediate
---

Annotations that say who owns a namespace, or which policy touched it, are the first thing people
skip when they create one by hand.

## Creating the map when it is missing

`jsonpatch` cannot add a key to a map that does not exist, so the patch adds the map first. The
condition only lets through the namespaces without annotations.

```yaml
apiVersion: admitik.dev/v1alpha1
kind: ClusterMutationPolicy
metadata:
  name: namespace-annotations-create
spec:
  interceptedResources:
    - group: ""
      version: v1
      resource: namespaces
      operations:
        - CREATE

  conditions:
    - name: ensure-annotations-missing
      engine: cel
      key: '!has(object.metadata.annotations)'
      value: "true"

  patch:
    type: jsonpatch # JsonPatch | JsonMerge | StrategicMerge
    engine: plain+cel
    template: |
      [
        { "op": "add", "path": "/metadata/annotations", "value": {} },
        { "op": "add", "path": "/metadata/annotations/patch-03-hello", "value": "world" }
      ]
```

## Adding to an existing map

With the map in place, each operation writes one key from a value of the object.

```yaml
apiVersion: admitik.dev/v1alpha1
kind: ClusterMutationPolicy
metadata:
  name: namespace-annotations-add
spec:
  interceptedResources:
    - group: ""
      version: v1
      resource: namespaces
      operations:
        - CREATE

  conditions:
    - name: ensure-annotations-exist
      engine: cel
      key: has(object.metadata.annotations)
      value: "true"

  patch:
    type: jsonpatch # JsonPatch | JsonMerge | StrategicMerge
    engine: plain+cel
    template: |
      [
        { "op": "add", "path": "/metadata/annotations/patch-04-object-operation", "value": "{{cel: operation }}" },
        { "op": "add", "path": "/metadata/annotations/patch-04-object-kind", "value": "{{cel: object.kind }}" },
        { "op": "add", "path": "/metadata/annotations/patch-04-object-name", "value": "{{cel: object.metadata.name }}" }
      ]
```

## Building the patch in code

Starlark decides the operations itself and encodes the list, which is what `jsonpatch` expects.

```yaml
apiVersion: admitik.dev/v1alpha1
kind: ClusterMutationPolicy
metadata:
  name: namespace-annotations-starlark
spec:
  interceptedResources:
    - group: ""
      version: v1
      resource: namespaces
      operations:
        - CREATE
        - UPDATE

  conditions:
    - name: first-condition
      engine: starlark
      key: |
        def check_namespace():
          if object["metadata"]["name"].startswith("mutate-"):
            print("mutate-it")
        check_namespace()
      value: "mutate-it"

  patch:
    type: jsonpatch # JsonPatch | JsonMerge | StrategicMerge
    engine: starlark
    template: |
      def check_operation():
        patch = []

        if "annotations" not in object["metadata"]:
          patch = patch + [{"op": "add", "path": "/metadata/annotations", "value": {}}]

        if operation == "CREATE":
          patch = patch + [
            {"op": "add", "path": "/metadata/annotations/patch-06-mutated-by", "value": "admitik"}
          ]
        else:
          patch = patch + []

        print(json.encode(patch))

      check_operation()
```
