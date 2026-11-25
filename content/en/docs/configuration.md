---
title: Configuration
weight: 30
description: Every flag of the controller, with its default.
---

The controller takes its configuration as flags. The chart sets the ones an installation needs and
leaves the rest alone.

<!-- flags:start -->
| Flag | Description | Default |
| --- | --- | --- |
| `--cleanup-webhooks` | Delete the webhook configurations and exit. Used by the chart to clean up after an uninstall | false |
| `--compliance-scan-interval` | Interval between compliance scans over the objects that already exist. Zero disables them | - |
| `--compose-mutations` | Make every mutation policy see the object as the previous ones left it. Without it, every policy evaluates the object as it arrived | false |
| `--enable-http2` | If set, HTTP/2 will be enabled for the metrics and webhook servers | false |
| `--enable-special-labels` | Enable labels that perform sensitive actions | false |
| `--exclude-admission-self-namespace` | Exclude Admitik resources from admission evaluations | false |
| `--excluded-admission-namespaces` | Comma-separated list of namespaces to be excluded from admission evaluations. Commonly used for 'kube-system' | - |
| `--health-probe-bind-address` | The address the probe endpoint binds to. | :8081 |
| `--kube-client-burst` | The burst capacity of communication between the controller and the API Server | 10 |
| `--kube-client-qps` | The QPS rate of communication between controller and the API Server | 5 |
| `--kubeconfig` | Paths to a kubeconfig. Only required if out-of-cluster. | - |
| `--leader-elect` | Enable leader election for controller manager. Enabling this will ensure there is only one active controller manager. | false |
| `--metrics-bind-address` | The address the metric endpoint binds to. Use the port :8080. If not set, it will be 0 in order to disable the metrics server | 0 |
| `--metrics-secure` | If set the metrics endpoint is served securely | false |
| `--sources-time-to-resync-informers` | Interval to resynchronize all resources in the informers | 1m0s |
| `--webhook-client-hostname` | The hostname Kubernetes uses to reach the webhooks server. Empty means admitik-webhooks.<namespace>.svc | - |
| `--webhook-client-port` | The port used by Kubernetes when calling the webhooks server | 10250 |
| `--webhook-client-timeout` | The time waited by Kubernetes when calling the webhooks server before considering timeout | 10 |
| `--webhook-server-autogenerate-certs` | Enable autogeneration of certificates for webhooks server | false |
| `--webhook-server-ca` | The CA bundle to use for the webhooks server | - |
| `--webhook-server-certificate` | The Certificate used by webhooks server | - |
| `--webhook-server-certs-secret-name` | Kubernetes Secret object name to get certificates from. Keys are: ca.crt, tls.crt, tls.key | - |
| `--webhook-server-path` | The path where the webhooks server listens | /admission |
| `--webhook-server-port` | The port where the webhooks server listens | 10250 |
| `--webhook-server-private-key` | The Private Key used by webhooks server | - |
| `--zap-devel` | Development Mode defaults(encoder=consoleEncoder,logLevel=Debug,stackTraceLevel=Warn). Production Mode defaults(encoder=jsonEncoder,logLevel=Info,stackTraceLevel=Error) | false |
| `--zap-encoder` | Zap log encoding (one of 'json' or 'console') | - |
| `--zap-log-level` | Zap Level to configure the verbosity of logging. Can be one of 'debug', 'info', 'error', 'panic'or any integer value > 0 which corresponds to custom debug levels of increasing verbosity | - |
| `--zap-stacktrace-level` | Zap Level at and above which stacktraces are captured (one of 'info', 'error', 'panic'). | - |
| `--zap-time-encoding` | Zap time encoding (one of 'epoch', 'millis', 'nano', 'iso8601', 'rfc3339' or 'rfc3339nano'). Defaults to 'epoch'. | - |
<!-- flags:end -->

## Changing them

With the chart, `controller.extraArgs` appends flags to the ones it already passes:

```yaml
controller:
  extraArgs:
    - --compose-mutations
    - --compliance-scan-interval=1h
```

With the bundle, edit the `args` of the Deployment.

## Logging

`--zap-*` comes from controller-runtime. The default is JSON at info level, which is what you want in
a cluster. `--zap-devel` switches to console output at debug level. What a decision writes is in
[Logs](/docs/observability/logs/).
