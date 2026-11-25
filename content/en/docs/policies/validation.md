---
title: Validation
linkTitle: Validation
weight: 10
description: Reject an object with a message, or let it through with a warning.
---

A `ClusterValidationPolicy` answers the API server with a denial or an admission. Nothing is
written to the cluster.

```yaml
apiVersion: admitik.dev/v1alpha1
kind: ClusterValidationPolicy
metadata:
  name: require-team-label
spec:
  failureAction: Enforce
  interceptedResources:
    - group: ""
      version: v1
      resource: namespaces
      operations: [CREATE, UPDATE]
  conditions:
    - name: has-team
      engine: cel
      key: has(object.metadata.labels) && "team" in object.metadata.labels
      value: "true"
  message:
    engine: plain
    template: "namespaces need a team label, so cost has an owner"
```

## failureAction

- `Enforce` rejects the request when a condition does not match.
- `Permissive` lets it through and adds a warning, which `kubectl` prints and the audit log records.

The default is `Enforce`.

## The message

The message is rendered with the engine it declares, and it can read everything the conditions read:
`object`, `oldObject`, `sources` and `vars`. Use Starlark or Go templates when the denial should
name the values that caused it.

## A policy that cannot be evaluated

If the policy itself fails, the object is rejected with:

```text
policy 'require-team-label' could not be evaluated, so the object was rejected
```

That is deliberate: a policy that cannot run is not a policy that passes.

## What it does not do

Validation does not look at what is already in the cluster. For that, the periodic compliance scan
reports existing objects against these policies through metrics; see
[Metrics](/docs/observability/metrics/).
