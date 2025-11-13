# Kyverno Prometheus Integration

This document describes the Prometheus integration setup for Kyverno metrics monitoring.

## Overview

Kyverno automatically exposes metrics on port 8000 for all controller pods:
- `kyverno-admission-controller`
- `kyverno-background-controller`
- `kyverno-cleanup-controller`
- `kyverno-reports-controller`

## Automatic Discovery

The Kyverno Helm values (`install/kyverno-values.yaml`) include Prometheus pod annotations that enable automatic metrics discovery:

```yaml
podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8000"
  prometheus.io/path: "/metrics"
```

These annotations are applied to all Kyverno controller deployments during installation.

## Prometheus Configuration

The existing Prometheus deployment in the `monitoring` namespace includes a `kubernetes-pods` scrape job that automatically discovers and scrapes pods with these annotations:

```yaml
- job_name: 'kubernetes-pods'
  kubernetes_sd_configs:
    - role: pod
  relabel_configs:
    - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
      action: keep
      regex: true
    - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
      action: replace
      target_label: __metrics_path__
      regex: (.+)
    - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
      action: replace
      regex: ([^:]+)(?::\\d+)?;(\\d+)
      replacement: $1:$2
      target_label: __address__
```

**No changes to Prometheus configuration are required.**

## Verification

### Check Prometheus Targets

```bash
# Via Prometheus UI
open http://localhost:30090/targets

# Via API
curl -s http://localhost:30090/api/v1/targets | \
  jq '.data.activeTargets[] | select(.labels.namespace=="kyverno")'
```

### Query Kyverno Metrics

```bash
# List all Kyverno metrics
curl -s 'http://localhost:30090/api/v1/label/__name__/values' | \
  jq '.data[] | select(. | startswith("kyverno"))'

# Query policy changes
curl -s 'http://localhost:30090/api/v1/query?query=kyverno_policy_changes_total' | \
  jq '.data.result'

# Query Kyverno version
curl -s 'http://localhost:30090/api/v1/query?query=kyverno_info' | \
  jq -r '.data.result[] | "Pod: \(.metric.pod) | Version: \(.metric.version)"'
```

## Key Metrics

| Metric | Description |
|--------|-------------|
| `kyverno_info` | Kyverno version and build information |
| `kyverno_policy_changes_total` | Policy lifecycle events (created, updated, deleted) |
| `kyverno_policy_execution_duration_seconds` | Time taken to execute policies |
| `kyverno_admission_requests_total` | Total admission webhook requests |
| `kyverno_http_requests_total` | HTTP API requests to Kyverno |
| `kyverno_client_queries_total` | Kubernetes API client queries |

## Manual Port-Forward (Optional)

For direct access to Kyverno metrics (useful for debugging):

```bash
# Check if port 8000 is available (may conflict with k9s)
lsof -i :8000

# Use alternative port if 8000 is in use
kubectl port-forward -n kyverno svc/kyverno-svc-metrics 8002:8000

# Test metrics endpoint
curl -s http://localhost:8002/metrics | head -20

# View Kyverno-specific metrics
curl -s http://localhost:8002/metrics | grep "^kyverno_"
```

## Prometheus Operator (Optional)

If using Prometheus Operator (requires ServiceMonitor CRD):

```bash
kubectl apply -f monitoring/prometheus-servicemonitor.yaml
```

**Note:** The standard Prometheus setup in this lab does **not** use the Prometheus Operator, so the ServiceMonitor resource is not needed. Metrics are automatically discovered via pod annotations.

## Grafana Dashboard (Future Enhancement)

To visualize Kyverno metrics in Grafana:

1. Import a Kyverno dashboard from [grafana.com/dashboards](https://grafana.com/grafana/dashboards/)
2. Configure Prometheus as the data source
3. Popular dashboard IDs:
   - **14205**: Kyverno Policy Reporter
   - **16235**: Kyverno Metrics

## Troubleshooting

### Metrics Not Appearing in Prometheus

```bash
# 1. Verify Kyverno pods are running
kubectl get pods -n kyverno

# 2. Check pod annotations
kubectl get pods -n kyverno -o yaml | grep -A 3 "prometheus.io"

# 3. Test metrics endpoint directly
kubectl exec -n kyverno deployment/kyverno-admission-controller -- \
  curl -s http://localhost:8000/metrics | head

# 4. Check Prometheus targets
curl -s http://localhost:30090/api/v1/targets | \
  jq '.data.activeTargets[] | select(.labels.namespace=="kyverno")'
```

### Port 8000 Conflicts

If port 8000 is in use (common with k9s):

```bash
# Find what's using port 8000
lsof -i :8000

# Use alternative port for manual testing
kubectl port-forward -n kyverno svc/kyverno-svc-metrics 8002:8000
```

## Related Documentation

- [Kyverno README](../README.md) - Main documentation
- [Port Reference](../../../docs/Port-Reference.md) - All service ports
- [Grafana & Loki Setup](../../../docs/Grafana-Loki.md) - Monitoring stack
