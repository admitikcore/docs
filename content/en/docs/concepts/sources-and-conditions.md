---
title: Sources and conditions
linkTitle: Sources and conditions
weight: 30
description: How to bring other objects into an evaluation, and how to decide with them.
---

## Sources

A source is another resource, fetched before the policy is evaluated:

```yaml
sources:
  - group: ""
    version: v1
    resource: namespaces
```

The first source is `sources[0]`, and the objects arrive as they are in the cluster, as a list.

### Filters

Admitik watches the whole resource type, so the filter is what keeps the evaluation small:

```yaml
sources:
  - group: ""
    version: v1
    resource: secrets
    filters:
      namespace:
        matchList: ["kube-system", "{{cel: object.metadata.namespace }}"]
      name:
        matchRegex:
          negative: true
          expression: "^("{{cel: object.metadata.name }}")-.*$"
      metadata:
        matchLabels:
          managed-by: custom-operator
        matchAnnotations:
          managed-by: custom-operator
```

- `matchList` takes literal values or `{{cel: ...}}` placeholders resolved against the object that
  triggered the policy.
- `matchRegex` takes `expression` and `negative`. Both are available for `namespace` and for `name`.
- `matchLabels` and `matchAnnotations` take exact key and value pairs.

The filters of one source are applied together: an object has to match all of them to be injected.

## Conditions

Conditions are a list, evaluated in order. Each one renders a `key` with its engine and compares the
result with `value`:

```yaml
conditions:
  - name: has-owner
    engine: cel
    key: has(object.metadata.labels) && "owner" in object.metadata.labels
    value: "true"
```

All of them have to match for the policy to act. A policy without conditions always acts.

### On the object that arrives

```yaml
conditions:
  - name: under-ten-replicas
    engine: cel
    key: object.spec.replicas <= 10
    value: "true"
```

### On what was there before

`oldObject` is only filled on updates, so the condition has to allow the other operations:

```yaml
conditions:
  - name: no-owner-change
    engine: cel
    key: |
      operation != "UPDATE" ||
      oldObject.metadata.labels.owner == object.metadata.labels.owner
    value: "true"
```

### Against another object

```yaml
sources:
  - group: ""
    version: v1
    resource: namespaces

conditions:
  - name: namespace-is-labelled
    engine: cel
    key: |
      sources[0].exists(ns,
        ns.metadata.name == object.metadata.namespace &&
        "team" in ns.metadata.labels)
    value: "true"
```

Starlark does the same with a loop, and is the way to compare two lists:

```yaml
conditions:
  - name: no-route-collision
    engine: starlark
    key: |
      incoming = object
      for existing in sources[0]:
          if existing["metadata"]["name"] == incoming["metadata"]["name"]:
              continue
          if existing["spec"]["hostnames"] == incoming["spec"]["hostnames"]:
              print("collision")
              break
      else:
          print("clear")
    value: clear
```

### Leaving values for the next condition

{{% alert title="Not every engine can" color="warning" %}}
Reading and writing `vars` depends on what each engine is meant for. The
[comparison table](/docs/concepts/engines-and-context/#who-sees-what) says which one does what, and
[writing and reading values](/docs/concepts/engines-and-context/#writing-and-reading-values) shows how
to do it in the ones that can.
{{% /alert %}}

What a condition computes stays available to everything that computes after it in the same policy: the
conditions that follow, the patch of a mutation policy, or the object template of a generation policy.

```yaml
conditions:
  - name: compute-ceiling
    engine: starlark
    key: |
      namespace = next((n for n in sources[0]
          if n["metadata"]["name"] == object["metadata"]["namespace"]), None)
      vars["ceiling"] = int(namespace["metadata"]["labels"]["max-replicas"])
      print("computed")
    value: computed

  - name: over-the-ceiling
    engine: starlark
    key: |
      if object["spec"].get("replicas", 1) > vars["ceiling"]:
          print("over")
      else:
          print("under")
    value: over

patch:
  type: jsonmerge
  engine: gotmpl
  template: |
    spec:
      replicas: {{ .vars.ceiling }}
```

The patch is a Go template and the value was computed in Starlark: one engine leaves it and another
one reads it.

### Always true

A `plain` condition has nothing to evaluate, so it always matches. It is useful to keep a policy that
only depends on its trigger:

```yaml
conditions:
  - name: always
    engine: plain
    key: deny
    value: deny
```
