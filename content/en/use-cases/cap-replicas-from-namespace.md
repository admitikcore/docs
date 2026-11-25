---
title: Cap the replicas of a Deployment with a namespace label
linkTitle: Cap replicas by namespace
weight: 60
description: A namespace declares its ceiling, and every Deployment that lands in it is capped to it.
policy: mutation
labels:
  - topic:cost
  - topic:replicas
  - resource:deployments
  - resource:namespaces
  - engine:starlark
  - feature:sources
  - feature:vars
  - feature:jsonmerge
  - level:intermediate
---

A team scales a Deployment to forty replicas and the node pool empties. The ceiling lives in a
spreadsheet.

The policy reads the namespace of the incoming Deployment, takes `max-replicas` from its labels and
lowers `spec.replicas` when the request goes over it.

```yaml
apiVersion: admitik.dev/v1alpha1
kind: ClusterMutationPolicy
metadata:
  name: cap-replicas
spec:
  priority: 20
  interceptedResources:
    - group: apps
      version: v1
      resource: deployments
      operations: [CREATE, UPDATE]
  sources:
    - group: ""
      version: v1
      resource: namespaces
      filters:
        metadata:
          matchLabels:
            admitik.dev/enforce-replica-cap: "true"
  conditions:
    - name: ceiling-declared
      engine: starlark
      key: |
        namespace = next((n for n in sources[0]
            if n["metadata"]["name"] == object["metadata"]["namespace"]), None)
        if namespace and "max-replicas" in namespace["metadata"].get("labels", {}):
            vars["ceiling"] = int(namespace["metadata"]["labels"]["max-replicas"])
            print("ceiling")
        else:
            print("no-ceiling")
      value: ceiling
  patch:
    type: jsonmerge
    engine: starlark
    template: |
      replicas = object["spec"].get("replicas", 1)
      ceiling = vars["ceiling"]
      if replicas > ceiling:
          print({"spec": {"replicas": ceiling}})
      else:
          print({})
```

## Notes

- The source filter keeps only the namespaces that opted in.
- Starlark for the condition: the namespace has to be found in a list. It leaves the ceiling in
  `vars` and the patch reads it back.
- Without `max-replicas` the condition does not match and nothing happens. The policy lowers a
  request, it does not audit.
