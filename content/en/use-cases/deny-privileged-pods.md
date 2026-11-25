---
title: Deny privileged containers
linkTitle: Deny privileged containers
weight: 20
description: A pod that asks for privileged mode does not get created, in any namespace.
policy: validation
labels:
  - topic:security
  - topic:containers
  - resource:pods
  - engine:cel
  - level:starter
---

A privileged container has the capabilities of the node.

The policy intercepts pods, so it also covers the ones that Deployments, StatefulSets and Jobs
create.

```yaml
apiVersion: admitik.dev/v1alpha1
kind: ClusterValidationPolicy
metadata:
  name: deny-privileged-pods
spec:
  failureAction: Enforce
  interceptedResources:
    - group: ""
      version: v1
      resource: pods
      operations: [CREATE, UPDATE]
  conditions:
    - name: not-privileged
      engine: cel
      key: |
        object.spec.containers.all(c,
          !has(c.securityContext) || !c.securityContext.privileged)
      value: "true"
  message:
    engine: gotmpl
    template: |
      pod {{ .object.metadata.name }} asks for privileged mode, which gives it the node
```

## Notes

- The denial shows on the pod, not on the Deployment that created it, because the pod is admitted
  before the controller finishes reconciling.
- The message names the pod. Naming the container needs Starlark, which can leave the offending
  names in `vars` for the message to read.
