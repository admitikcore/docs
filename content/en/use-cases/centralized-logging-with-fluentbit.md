---
title: Ship container logs to FluentD without touching the app
linkTitle: Centralized logging with FluentBit
weight: 70
description: Three policies that generate the FluentBit configuration, point the pod template at it and inject the sidecar.
policy: solution
labels:
  - topic:logging
  - topic:sidecars
  - topic:configmaps
  - resource:deployments
  - resource:pods
  - engine:cel
  - engine:starlark
  - level:advanced
---

Every team that wants centralized logs has to add a log shipper to its own manifests, and every team
does it differently. This is three policies that do it for them.

A workload opts in with two annotations. From there, Admitik generates the FluentBit configuration for
its containers, puts the name of that ConfigMap in the pod template and injects the sidecar.

```yaml
metadata:
  labels:
    admitik.policy.v1/logging: "true"
  annotations:
    admitik.policy.v1/loggingConfig: |
      - container: "app"
        parser: "json"
        index: "my-app-logs"
        host: "fluentd.logging.svc.cluster.local"
        port: "24224"
      - container: "nginx"
        parser: "nginx"
        index: "nginx-logs"
```

## loggingConfig

One entry per container. Anything the entry sets ends up as a record field that FluentD reads.

| Field | What it is | Default |
| --- | --- | --- |
| `container` | The container whose logs are read | required |
| `index` | The index on the receiving side | required |
| `parser` | The FluentD parser for those logs | `json` |
| `ilm_policy_id` | Retention policy of the index | `30d` |
| `ingest_anyways` | Forward logs that fail to parse | `true` |
| `host` | Where the sidecar sends them | `fluentd.logging.svc.cluster.local` |
| `port` | Port of that host | `24224` |

## 1. Generate the ConfigMap

Watches the workloads, reads the annotation and writes one `fluentbit_<container>.conf` per entry.

```yaml
# logging-generate-fluentbit-configmap-v1 is a policy that generates a fluentbit configmap for deployments,
# daemonsets, statefulsets and cronjobs which have the label admitik.policy.v1/logging set to true and the annotation
# admitik.policy.v1/loggingConfig set to a valid yaml configuration.

# This configmap is used to configure the fluentbit sidecar in the pods and send the logs to a fluentd instance.

apiVersion: admitik.dev/v1alpha1
kind: ClusterGenerationPolicy
metadata:
  name: logging-generate-fluentbit-configmap-v1

spec:

  overwriteExisting: true

  watchedResources:
    - group: apps
      version: v1
      resource: deployments
    - group: apps
      version: v1
      resource: daemonsets
    - group: apps
      version: v1
      resource: statefulsets
    - group: batch
      version: v1
      resource: cronjobs
    - group: argoproj.io
      version: v1alpha1
      resource: rollouts

  sources: []

  conditions:

    - name: apply-on-specific-mark
      engine: cel
      key: |              
        (has(object.metadata.labels) &&
        object.metadata.labels.exists(label, label == 'admitik.policy.v1/logging')) ||
        
        (has(object.metadata.annotations) &&
        object.metadata.annotations.exists(label, label == 'admitik.policy.v1/logging')) &&
        
        (has(object.metadata.annotations) &&
        object.metadata.annotations.exists(label, label == 'admitik.policy.v1/loggingConfig'))

      value: "true"

  object:
    clone: {}
    definition:
      engine: starlark
      template: |
        def generate_configmap():
          configmap_data_section = {
            "fluentbit.conf": """
        [SERVICE]
            Flush         1
            Log_Level     info
            Daemon        off

        @INCLUDE /fluent-bit/etc/fluentbit_*.conf
            """
          }

          for entry in yaml.decode(object["metadata"]["annotations"]["admitik.policy.v1/loggingConfig"]):
              namespace = object["metadata"]["namespace"]
              container = entry.get("container")
              parser = entry.get("parser", "json")
              index = entry.get("index")
              ilm = entry.get("ilm_policy_id", "30d")
              ingest_anyways = entry.get("ingest_anyways", "true")
              host = entry.get("host", "fluentd.logging.svc.cluster.local")
              port = entry.get("port", "24224")

              content = """
        [INPUT]
            Name              tail
            Path              /var/log/containers/${{HOSTNAME}}_{}_{}-*.log
            multiline.parser  docker, cri
            Tag               {}.{}
            Mem_Buf_Limit     25MB
            Skip_Long_Lines   On
            Refresh_Interval  5
            db                /fluent-bit/pos/{}.db

        [FILTER]
            Name                record_modifier
            Match               {}.{}
            Record              index "{}"
            Record              pod_name "${{HOSTNAME}}"
            Record              namespace "{}"
            Record              container "{}"
            Record              ilm_policy_id "{}"
            Record              ingest_anyways "{}"

        [OUTPUT]
            Name  forward
            Match {}.{}
            Host  {}
            Port  {}
            Retry_Limit 5""".format(namespace, container, container, parser,
                        container, container, parser, index, namespace,
                        container, ilm, ingest_anyways, container, parser, host, port)

              configmap_data_section["fluentbit_" + container + ".conf"] = content  

          configmap_resource = {
            "apiVersion": "v1",
            "kind": "ConfigMap",
            "metadata": {
              "name": "fluentbit-" + object["metadata"]["name"] + "-autogenerated",
              "namespace": object["metadata"]["namespace"],
              "labels": {
                "managed-by": "admitik",
                "policy-name": "logging-generate-fluentbit-configmap-v1",
                "parent-object-kind": object["kind"],
                "parent-object-name": object["metadata"]["name"]
              },
            },
            "data": configmap_data_section
          }
          return configmap_resource

        print(generate_configmap())
```

## 2. Point the pod template at it

Writes the name of the generated ConfigMap into the pod template, and copies the sidecar resources
from `admitik.policy.v1/loggingSidecarResources` to `admitik.policy.v1/fluentbitResources`.

```yaml
# logging-mutate-fluentbit-configmap-name-v1 is a policy that adds the name of the fluentbit configmap for the pods created by
# deployments, daemonsets, statefulsets and cronjobs which have the label admitik.policy.v1/logging set to true and the annotation
# admitik.policy.v1/loggingConfig set to a valid yaml configuration.

# This policy adds the name of the configmap to the annotations of the child object.
# If the admitik.policy.v1/loggingSidecarResources annotation is present, it will be propagated as admitik.policy.v1/fluentbitResources to the pod template.

apiVersion: admitik.dev/v1alpha1
kind: ClusterMutationPolicy
metadata:
  name: logging-mutate-fluentbit-configmap-name-v1
spec:

  # Resources to be intercepted before reaching the cluster
  interceptedResources:
    - group: apps
      version: v1
      resource: deployments
      operations:
        - CREATE
        - UPDATE
    - group: apps
      version: v1
      resource: daemonsets
      operations:
        - CREATE
        - UPDATE
    - group: apps
      version: v1
      resource: statefulsets
      operations:
        - CREATE
        - UPDATE
    - group: argoproj.io
      version: v1alpha1
      resource: rollouts
      operations:
        - CREATE
        - UPDATE

  # Other resources to be retrieved for conditions templates.
  # They will be included under .sources scope in the template
  sources: []

  # Conditions are optional, so no-conditions means they are always met
  conditions:
    - name: apply-on-specific-mark
      engine: cel
      key: |              
        (has(object.metadata.labels) &&
        object.metadata.labels.exists(label, label == 'admitik.policy.v1/logging')) ||
        
        (has(object.metadata.annotations) &&
        object.metadata.annotations.exists(label, label == 'admitik.policy.v1/logging'))

      value: "true"

  patch:
    type: jsonpatch # JsonPatch | JsonMerge
    engine: starlark
    template: |
      def check_operation():
        patch = []
      
        if "annotations" not in object["spec"]["template"]["metadata"]:
          patch = patch + [{"op": "add", "path": "/spec/template/metadata/annotations", "value": {}}]
      
        patch = patch + [
          {"op": "add", "path": "/spec/template/metadata/annotations/admitik.policy.v1~1fluentbitConfigmap", "value": "fluentbit-" + object["metadata"]["name"] + "-autogenerated" },
          {"op": "add", "path": "/spec/template/metadata/annotations/admitik.policy.v1~1fluentbitConfigmapHash", "value": hashlib.sha256(object["metadata"]["annotations"]["admitik.policy.v1/loggingConfig"]) },
          {"op": "add", "path": "/spec/template/metadata/labels/admitik.policy.v1~1logging", "value": "true" }
        ]

        # Add fluentbitResources annotation if loggingSidecarResources is present
        if object["metadata"].get("annotations", {}).get("admitik.policy.v1/loggingSidecarResources"):
          entry = yaml.decode(object["metadata"]["annotations"]["admitik.policy.v1/loggingSidecarResources"])
          if entry.get("requests"):
              cpuRequest = entry.get("requests").get("cpu", "50m")
              memoryRequest = entry.get("requests").get("memory", "50Mi")
          else:
              cpuRequest = "50m"
              memoryRequest = "50Mi"
          if entry.get("limits"):
              memoryLimit = entry.get("limits").get("memory", "100Mi")
          else:
              memoryLimit = "100Mi"
          resources = {
              "requests": {
                  "cpu": cpuRequest,
                  "memory": memoryRequest
              },
              "limits": {
                  "memory": memoryLimit
              }
          }
          patch = patch + [
            {"op": "add", "path": "/spec/template/metadata/annotations/admitik.policy.v1~1fluentbitResources", "value": json.encode(resources) }
          ]

        print(json.encode(patch))
    
      check_operation()

---

# For cronjobs, we need to mutate the jobTemplate.spec.template.metadata.annotations and labels instead of the spec.template.metadata.annotations and labels
apiVersion: admitik.dev/v1alpha1
kind: ClusterMutationPolicy
metadata:
  name: logging-mutate-fluentbit-cronjob-configmap-name-v1
spec:

  # Resources to be intercepted before reaching the cluster
  interceptedResources:
    - group: batch
      version: v1
      resource: cronjobs
      operations:
        - CREATE
        - UPDATE

  # Other resources to be retrieved for conditions templates.
  # They will be included under .sources scope in the template
  sources: []

  # Conditions are optional, so no-conditions means they are always met
  conditions:
    - name: apply-on-specific-mark
      engine: cel
      key: |              
        (has(object.metadata.labels) &&
        object.metadata.labels.exists(label, label == 'admitik.policy.v1/logging')) ||
        
        (has(object.metadata.annotations) &&
        object.metadata.annotations.exists(label, label == 'admitik.policy.v1/logging'))

      value: "true"

  patch:
    type: jsonpatch # JsonPatch | StrategicMerge
    engine: starlark
    template: |
      def check_operation():
        patch = []
      
        if "annotations" not in object["spec"]["jobTemplate"]["spec"]["template"]["metadata"]:
          patch = patch + [{"op": "add", "path": "/spec/jobTemplate/spec/template/metadata/annotations", "value": {}}]
      
        patch = patch + [
          {"op": "add", "path": "/spec/jobTemplate/spec/template/metadata/annotations/admitik.policy.v1~1fluentbitConfigmap", "value": "fluentbit-" + object["metadata"]["name"] + "-autogenerated" },
          {"op": "add", "path": "/spec/jobTemplate/spec/template/metadata/labels/admitik.policy.v1~1logging", "value": "true" }
        ]

        # Add fluentbitResources annotation if loggingSidecarResources is present
        if object["metadata"].get("annotations", {}).get("admitik.policy.v1/loggingSidecarResources"):
          entry = yaml.decode(object["metadata"]["annotations"]["admitik.policy.v1/loggingSidecarResources"])
          if entry.get("requests"):
              cpuRequest = entry.get("requests").get("cpu", "50m")
              memoryRequest = entry.get("requests").get("memory", "50Mi")
          else:
              cpuRequest = "50m"
              memoryRequest = "50Mi"
          if entry.get("limits"):
              memoryLimit = entry.get("limits").get("memory", "100Mi")
          else:
              memoryLimit = "100Mi"
          resources = {
              "requests": {
                  "cpu": cpuRequest,
                  "memory": memoryRequest
              },
              "limits": {
                  "memory": memoryLimit
              }
          }
          patch = patch + [
            {"op": "add", "path": "/spec/jobTemplate/spec/template/metadata/annotations/admitik.policy.v1~1fluentbitResources", "value": object["metadata"]["annotations"]["admitik.policy.v1/loggingSidecarResources"] }
          ]

        print(json.encode(patch))
    
      check_operation()
```

## 3. Inject the sidecar

Adds the FluentBit container to the pod, with the volumes for the container logs, the configuration
and its own position database.

```yaml
# logging-mutate-fluentbit-pod-sidecar-v1 is a policy that mutates the pods which have the label
# admitik.policy.v1/logging set to true and a configmap with the name in the annotation
# admitik.policy.v1/fluentbitConfigmap.
#
# This policy adds an init container to the pod with the fluentbit sidecar to send the logs to a
# fluentd instance. Resources can be customized using the annotation
# admitik.policy.v1/fluentbitResources with JSON format.
# Example: '{"limits":{"memory":"100Mi"},"requests":{"cpu":"100m","memory":"50Mi"}}'
apiVersion: admitik.dev/v1alpha1
kind: ClusterMutationPolicy
metadata:
  name: logging-mutate-fluentbit-pod-sidecar-v1

spec:

  # Resources to be intercepted before reaching the cluster
  interceptedResources:
    - group: ""
      version: v1
      resource: pods
      operations:
        - CREATE

  # Other resources to be retrieved for conditions templates
  sources: []

  conditions:
    - name: apply-on-specific-mark
      engine: cel
      key: |
        (has(object.metadata.labels) &&
        object.metadata.labels.exists(label, label == 'admitik.policy.v1/logging')) ||

        (has(object.metadata.annotations) &&
        object.metadata.annotations.exists(label, label == 'admitik.policy.v1/logging') &&
        object.metadata.annotations.exists(label, label == 'admitik.policy.v1/fluentbitConfigmap'))
      value: "true"

  patch:
    type: jsonmerge # JsonPatch | JsonMerge
    engine: starlark
    template: |
      def build_patch():

          # Default resources
          default_resources = {
              "limits": {
                  "memory": "50Mi"
              },
              "requests": {
                  "cpu": "50m",
                  "memory": "50Mi"
              }
          }

          # Check if custom resources are provided via annotation
          custom_resources = default_resources
          if object["metadata"].get("annotations", {}).get("admitik.policy.v1/fluentbitResources"):
              custom_resources = json.decode(object["metadata"]["annotations"]["admitik.policy.v1/fluentbitResources"])

          # Init containers
          existing_init_containers = object["spec"].get("initContainers", [])

          new_container = [
              {
                  "name": "fluentbit-sidecar",
                  "image": "fluent/fluent-bit:4.0.2",
                  "restartPolicy": "Always",
                  "imagePullPolicy": "IfNotPresent",
                  "command": ["/fluent-bit/bin/fluent-bit"],
                  "args": ["--config=/fluent-bit/etc/fluentbit.conf"],
                  "resources": custom_resources,
                  "volumeMounts": [
                      {"name": "fluentbit-config", "mountPath": "/fluent-bit/etc/", "readOnly": True},
                      {"name": "k8s-container-logs", "mountPath": "/var/log/containers", "readOnly": True},
                      {"name": "k8s-pods-logs", "mountPath": "/var/log/pods", "readOnly": True},
                      {"name": "fluentbit-pos", "mountPath": "/fluent-bit/pos"}
                  ],
                  "securityContext": {
                      "runAsNonRoot": True,
                      "runAsUser": 1000,
                      "allowPrivilegeEscalation": False,
                      "capabilities": {
                          "drop": ["ALL"]
                      },
                      "readOnlyRootFilesystem": True
                  }
              }
          ]

          # Exclude init container if it already exists
          existing_container_names = [container["name"] for container in existing_init_containers]
          if "fluentbit-sidecar" not in existing_container_names:
              init_containers = existing_init_containers + new_container
          else:
              init_containers = existing_init_containers

          # Volumes
          existing_volumes = object["spec"].get("volumes", [])

          new_volumes = [
              {
                  "name": "fluentbit-config",
                  "configMap": {
                      "name": object["metadata"]["annotations"]["admitik.policy.v1/fluentbitConfigmap"]
                  }
              },
              {"name": "k8s-container-logs", "hostPath": {"path": "/var/log/containers"}},
              {"name": "k8s-pods-logs", "hostPath": {"path": "/var/log/pods"}},
              {"name": "fluentbit-pos", "emptyDir": {}}
          ]

          # Exclude volumes if they already exist
          existing_volume_names = [volume["name"] for volume in existing_volumes]
          new_volumes_filtered = [volume for volume in new_volumes if volume["name"] not in existing_volume_names]
          volumes = existing_volumes + new_volumes_filtered

          return {"spec": {"initContainers": init_containers, "volumes": volumes}}

      # The result of the template is what the script prints
      print(json.encode(build_patch()))
```

## Notes

- The sidecar runs as non-root, without privilege escalation, with a read-only root filesystem and
  every capability dropped. Its resources default to `50m` of CPU and `50Mi` of memory, and the
  workload can change them with `admitik.policy.v1/loggingSidecarResources`.
- The generation policy also watches `rollouts.argoproj.io`. Without Argo Rollouts installed that
  watch retries forever and fills the log of the reflector. Drop it from `watchedResources` if you do
  not use it.
