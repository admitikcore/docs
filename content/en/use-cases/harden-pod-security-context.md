---
title: A hardened security context on every pod
linkTitle: Hardening for every pod
weight: 25
description: One security floor for every pod of the cluster, and a rejection for the manifests that try to go below it.
policy: solution
labels:
  - topic:security
  - topic:containers
  - resource:pods
  - resource:deployments
  - engine:cel
  - engine:starlark
  - engine:gotmpl
  - feature:strategicmerge
  - feature:sources
  - level:advanced
---

Every team writes its own manifests, and it writes them with the service in mind: the image, the port,
the probe, the memory limit. The security context is not on that list. It breaks nothing when it is
missing, and it is the first thing that goes in a review.

What is left is a hundred workloads with a hundred different levels of isolation, and nothing in a
Deployment tells them apart.

A pod that declares no `securityContext` runs with the default set of the container runtime. In
Docker and containerd that is 14 capabilities, and `NET_RAW` is one of them.

This solution aims at one thing: every pod runs with the same floor, whether or not its manifest
mentions security, and the few that need more than the floor declare it in a place the cluster can
read.

Three policies get there. The first two patch the security context of what arrives. The third rejects
what a patch cannot fix.

The floor is three fields:

| Field | Value | What it does |
| --- | --- | --- |
| `seccompProfile.type` | `RuntimeDefault` | The runtime's seccomp filter. It blocks `io_uring_setup`, `io_uring_enter` and `io_uring_register` |
| `allowPrivilegeEscalation` | `false` | A setuid binary inside the container cannot gain capabilities the container did not have |
| `capabilities.drop` | `["ALL"]` | Removes the bounding set. `NET_RAW`, `SETPCAP` and `MKNOD` go with it |

A manifest that already adds a capability keeps it. The patch only writes `drop`.

## Patch the pod templates

The first policy intercepts the four kinds that carry a pod template: `deployments`,
`statefulsets`, `daemonsets` and `jobs`. All of them keep it at `spec.template.spec`.

```yaml
apiVersion: admitik.dev/v1alpha1
kind: ClusterMutationPolicy
metadata:
  name: harden-pod-templates
spec:
  priority: 10
  interceptedResources:
    - group: apps
      version: v1
      resource: deployments
      operations: [CREATE, UPDATE]
    - group: apps
      version: v1
      resource: statefulsets
      operations: [CREATE, UPDATE]
    - group: apps
      version: v1
      resource: daemonsets
      operations: [CREATE, UPDATE]
    - group: batch
      version: v1
      resource: jobs
      operations: [CREATE, UPDATE]
  patch:
    type: strategicmerge
    engine: starlark
    template: |
      def harden(containers):
          return [{"name": c["name"],
                   "securityContext": {"allowPrivilegeEscalation": False,
                                       "capabilities": {"drop": ["ALL"]}}}
                  for c in (containers or [])]

      spec = object["spec"]["template"]["spec"]

      pod = {"securityContext": {"seccompProfile": {"type": "RuntimeDefault"}},
             "containers": harden(spec["containers"]),
             "initContainers": harden(spec.get("initContainers"))}

      print(yaml.encode({"spec": {"template": {"spec": pod}}}))
```

`strategicmerge` merges the container list by `name` and leaves the rest of each container alone:
`image`, `ports`, `env`, `resources` and the `securityContext` fields the team already set.
`yaml.encode` prints the dictionary as the patch document.

## Patch the pods

Not every pod comes from a template. Bare pods, `kubectl run`, CronJobs and the controllers that build
their own pods never pass through one, and the first policy does not see them.

```yaml
apiVersion: admitik.dev/v1alpha1
kind: ClusterMutationPolicy
metadata:
  name: harden-pods
spec:
  priority: 20
  interceptedResources:
    - group: ""
      version: v1
      resource: pods
      operations: [CREATE, UPDATE]
  patch:
    type: strategicmerge
    engine: starlark
    template: |
      def harden(containers):
          return [{"name": c["name"],
                   "securityContext": {"allowPrivilegeEscalation": False,
                                       "capabilities": {"drop": ["ALL"]}}}
                  for c in (containers or [])]

      spec = object["spec"]

      pod = {"securityContext": {"seccompProfile": {"type": "RuntimeDefault"}},
             "containers": harden(spec["containers"]),
             "initContainers": harden(spec.get("initContainers"))}

      print(yaml.encode({"spec": pod}))
```

The two policies run in order. A pod created by a Deployment arrives already patched, and the second
policy finds nothing to change.

CronJobs are the one gap. Their template lives at `spec.jobTemplate.spec.template.spec`, which is
neither of the two paths, so the second policy covers their pods and not their template.

## Before and after

This is the Deployment a team writes:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payments-api
  namespace: payments
spec:
  replicas: 3
  selector:
    matchLabels:
      app: payments-api
  template:
    metadata:
      labels:
        app: payments-api
    spec:
      containers:
        - name: api
          image: registry.admitik.dev/payments/api:1.4.2
          ports:
            - containerPort: 8080
          resources:
            limits:
              memory: 512Mi
```

The same Deployment once stored. The image, the ports and the limits are the ones the team wrote,
and the three fields are there:

```yaml
spec:
  template:
    spec:
      securityContext:
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: api
          image: registry.admitik.dev/payments/api:1.4.2
          ports:
            - containerPort: 8080
          resources:
            limits:
              memory: 512Mi
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
```

## What a patch cannot fix

The mutation empties the capability set, but it cannot refuse a request. A manifest that puts
`SYS_ADMIN` back keeps it: the container ends up with `drop: ["ALL"]` and `add: ["SYS_ADMIN"]`, and
runs with exactly that one capability.

That needs a policy that can deny. This one reads the security context of the pod and of its
containers, and rejects:

- `privileged: true` on any container
- `hostNetwork`, `hostPID` or `hostIPC` on the pod
- seccomp `Unconfined`, on the pod or on a container
- a capability added outside the baseline list of the Pod Security Standards

```yaml
apiVersion: admitik.dev/v1alpha1
kind: ClusterValidationPolicy
metadata:
  name: deny-risky-security-context
spec:
  failureAction: Enforce
  interceptedResources:
    - group: ""
      version: v1
      resource: pods
      operations: [CREATE, UPDATE]
  conditions:
    - name: security-context
      engine: starlark
      key: |
        allowed = ["AUDIT_WRITE", "CHOWN", "DAC_OVERRIDE", "FOWNER", "FSETID", "KILL",
                   "MKNOD", "NET_BIND_SERVICE", "SETFCAP", "SETGID", "SETPCAP",
                   "SETUID", "SYS_CHROOT"]

        def seccomp_type(context):
            return ((context or {}).get("seccompProfile") or {}).get("type")

        def problems():
            spec = object["spec"]
            found = []

            for field in ["hostNetwork", "hostPID", "hostIPC"]:
                if spec.get(field):
                    found.append(field)

            if seccomp_type(spec.get("securityContext")) == "Unconfined":
                found.append("pod seccomp Unconfined")

            for container in (spec.get("containers") or []) + (spec.get("initContainers") or []):
                context = container.get("securityContext") or {}
                if context.get("privileged"):
                    found.append("%s is privileged" % container["name"])
                if seccomp_type(context) == "Unconfined":
                    found.append("%s seccomp Unconfined" % container["name"])
                for capability in (context.get("capabilities") or {}).get("add") or []:
                    name = capability.upper().replace("CAP_", "")
                    if name not in allowed:
                        found.append("%s adds %s" % (container["name"], name))

            return found

        found = problems()
        vars["problems"] = ", ".join(found)
        print("clean" if not found else "failed")
      value: clean

  message:
    engine: gotmpl
    template: |
      {{ .object.metadata.namespace }}/{{ .object.metadata.name }}: {{ .vars.problems }}
```

The message names everything the pod got wrong, not just the first thing.

With that policy in place, a pod that adds a capability outside the list does not get created:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: debug
  namespace: payments
spec:
  containers:
    - name: shell
      image: registry.admitik.dev/tools/shell:1
      securityContext:
        capabilities:
          add: ["SYS_ADMIN"]
```

```text
Error from server: error when creating "debug.yaml": admission webhook "validate.admitik.dev"
denied the request: payments/debug: shell adds SYS_ADMIN
```

## The namespaces that ask for more

Not every workload fits the same shape. `runAsNonRoot` breaks an image that starts as root: the kubelet
refuses to start the container, with `CreateContainerConfigError`. `readOnlyRootFilesystem` breaks any
image that writes to `/var`. Neither belongs in a floor applied to every namespace, so they live in a
policy of their own, and a namespace opts in with a label:

```yaml
apiVersion: admitik.dev/v1alpha1
kind: ClusterValidationPolicy
metadata:
  name: restricted-namespaces
spec:
  failureAction: Permissive
  interceptedResources:
    - group: ""
      version: v1
      resource: pods
      operations: [CREATE, UPDATE]
  sources:
    - group: ""
      version: v1
      resource: namespaces
      filters:
        name:
          matchList: ["{{cel: object.metadata.namespace }}"]
        metadata:
          matchLabels:
            admitik.dev/security: restricted
  conditions:
    - name: non-root
      engine: cel
      key: |
        sources[0].size() == 0
        || object.spec.containers.all(c, has(c.securityContext)
             && has(c.securityContext.runAsNonRoot)
             && c.securityContext.runAsNonRoot == true)
      value: "true"
  message:
    engine: plain
    template: containers in a restricted namespace run as non-root
```

The source returns the namespace only when it carries the label, so an empty `sources[0]` is a
namespace that did not opt in. `readOnlyRootFilesystem` and `hostUsers` take one condition each, with
the same shape.

## Rolling it out

The two mutations go first. They rewrite the security context and reject nothing, so a workload that
runs today keeps running.

They apply at admission. A pod that is already running keeps the security context it was created with
until its next restart, so a rolling restart is what moves the cluster to the new floor.

The validation is the one to turn on slowly. `failureAction: Permissive` first, for a week: the
warnings land in the audit log and in `kubectl` output, and they name the workloads that would have
been rejected:

```text
Warning: payments/worker: worker adds NET_ADMIN
```

Then `Enforce`.

## Notes

- `seccompProfile: Localhost` needs the profile file at the same path on every node. A pod whose
  profile is missing does not start, so the policy uses `RuntimeDefault`.
- A `seccompProfile` on a single container wins over the one the mutation sets on the pod. The
  validation reads both.
- A pod with no init containers still gets `initContainers: []` in the patch. The list is empty, and
  `strategicmerge` leaves the field as it was.
- Both mutations intercept `UPDATE` as well as `CREATE`. Without it, an edit that removes the
  security context would be stored, and the template would stop describing what runs.
- The checks that read several optional fields are Starlark. In CEL, each of those fields needs a
  `has()` in front, and the rule disappears behind them.
- AppArmor is out of scope here. The field is `securityContext.appArmorProfile`, and older clusters
  still carry the `container.apparmor.security.beta.kubernetes.io/<container>` annotation.
