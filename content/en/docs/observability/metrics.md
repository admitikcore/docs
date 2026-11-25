---
title: Metrics
weight: 10
description: What Admitik publishes to Prometheus, with the labels of each metric.
---

The controller serves Prometheus metrics on `--metrics-bind-address`, which is `0` (disabled) by
default. Point it at a port and scrape every replica: each one answers admission requests and keeps
its own counters.

## `admitik_decisions_total`

Counter. One increment per policy decision.

| Label | Values |
| --- | --- |
| `kind` | `validate`, `mutate`, `generate` |
| `policy` | The name of the policy |
| `operation` | `CREATE`, `UPDATE`, `DELETE` |
| `resource` | The intercepted resource, as `group/version/resource` |
| `result` | `allowed`, `denied`, `permissive`, `patched`, `unchanged`, `generated`, `skipped`, `failed` |
| `reason` | `none`, `sources`, `conditions`, `template`, `patch` or `apply` |

## `admitik_evaluation_seconds`

Histogram. Time spent evaluating one object with one policy, labelled by `kind` and `policy`.

## `admitik_injected_objects`

Histogram. How many source objects were injected into the templates of one evaluation, labelled by
`kind` and `policy`.

## `admitik_policies`

Gauge. Policies loaded, by `kind`. Only the leader publishes it.

## `admitik_compliance_objects`

Gauge. Objects evaluated by the last compliance scan, by `policy`, `resource` and `result`. The scan
runs every `--compliance-scan-interval` and `0` disables it. It walks the objects that already exist
and reports them against the validation policies.

## Example

```promql
# Rejections per policy in the last hour
sum by (policy) (increase(admitik_decisions_total{result="denied"}[1h]))

# p99 time to evaluate, by policy
histogram_quantile(0.99, sum by (policy, le) (rate(admitik_evaluation_seconds_bucket[5m])))

# Policies that failed to evaluate
sum by (policy) (rate(admitik_decisions_total{result="failed"}[5m]))
```
