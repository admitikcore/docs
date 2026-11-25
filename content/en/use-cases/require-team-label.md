---
title: Require an owner label on every namespace
linkTitle: Owner label on namespaces
weight: 10
description: Every namespace has to carry a team label, so cost and on-call have a name.
policy: validation
labels:
  - topic:namespaces
  - topic:labels
  - topic:ownership
  - topic:cost
  - resource:namespaces
  - engine:cel
  - level:starter
---

A namespace without a `team` label has no owner: no department in the bill, nobody to call at 3am.

The check is one expression over the object. No other resource is involved, so CEL is enough.

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
      key: |
        has(object.metadata.labels) && "team" in object.metadata.labels
      value: "true"
  message:
    engine: plain
    template: "namespaces need a team label, so cost and on-call have a name"
```

## With Go templates

The same check, walking the labels with a template.

```yaml
apiVersion: admitik.dev/v1alpha1
kind: ClusterValidationPolicy
metadata:
  name: require-team-label-gotmpl
spec:
  failureAction: Enforce

  interceptedResources:
    - group: ""
      version: v1
      resource: namespaces
      operations:
        - CREATE
        - UPDATE

  conditions:
    - name: confirm-existing-label
      engine: gotmpl

      key: |
        {{- $object := .object -}}
        {{- $labels := $object.metadata.labels -}}
        {{- $labelFound := false -}}

        {{- range $labelKey, $labelValue := $labels -}}
          {{- if eq $labelKey "admitik.dev/mandatory-label" -}}
            {{- $labelFound = true -}}
          {{- end -}}
        {{- end -}}

        {{- if $labelFound -}}
          {{- printf "label-found" -}}
        {{- else -}}
          {{- printf "label-not-found" -}}
        {{- end -}}

      value: "label-found"

  message:
    engine: gotmpl
    template: |
      {{- $object := .object -}}
      {{/* The following will be shown to the user on kubectl apply and logged by the controller */}}
      {{- printf "Resource '%s' was rejected as some of mandatory label is missing" .object.metadata.name -}}

      {{/* The following will be only logged in stdout by Admitik */}}
      {{- logPrintf "Hello, this is a custom message for your SRE members" -}}
```

## With Starlark

A function per check, and the result printed for the comparison.

```yaml
apiVersion: admitik.dev/v1alpha1
kind: ClusterValidationPolicy
metadata:
  name: require-team-label-starlark
spec:
  failureAction: Enforce

  interceptedResources:
    - group: ""
      version: v1
      resource: namespaces
      operations:
        - CREATE
        - UPDATE

  conditions:
    - name: confirm-existing-label
      engine: starlark

      key: |

        def isLabelPresent(label):
          labels = object["metadata"].get("labels")
          if labels == None:
            return "labels-not-found"

          mostWanted = labels.get(label)
          if mostWanted == None:
            return "label-not-found"
          return "label-found"

        isPresent = isLabelPresent("admitik.dev/super-important-label")

        log.debug("Is the label present?: ", present=isPresent)

        print(isPresent)

      value: "label-found"

  message:
    engine: starlark
    template: |
      print("Resource '{}/{}' was rejected as some required label is missing".format(object["kind"], object["metadata"]["name"]))
```

## Notes

- It runs on updates too, so a namespace that already exists without the label cannot be modified
  until someone adds it. Drop `UPDATE` from the operations to limit it to new namespaces.
