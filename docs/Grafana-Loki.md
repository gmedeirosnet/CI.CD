# Grafana, Loki & Prometheus Monitoring Setup

This guide covers the installation and configuration of Grafana, Loki, and Prometheus for comprehensive Kubernetes monitoring, logging, and metrics collection in the CI/CD project.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
  - [Loki Setup](#loki-setup)
  - [Grafana Setup](#grafana-setup)
- [Access](#access)
- [Usage](#usage)
- [LogQL Query Examples](#logql-query-examples)
- [Management Commands](#management-commands)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

## Overview

The monitoring and logging stack consists of:
- **Loki** - Log aggregation system (runs in Kind Kubernetes cluster)
- **Promtail** - Log collector agent (DaemonSet on all nodes)
- **Prometheus** - Metrics collection and time-series database (runs in Kind Kubernetes cluster)
- **kube-state-metrics** - Kubernetes object metrics exporter
- **node-exporter** - System and hardware metrics exporter (DaemonSet on all nodes)
- **Grafana** - Unified visualization and querying interface (runs on Docker Desktop)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Docker Desktop                                              │
│                                                             │
│  ┌──────────────────┐                                      │
│  │   Grafana        │                                      │
│  │  (Port 3000)     │                                      │
│  └────────┬─────────┘                                      │
│           │                                                 │
│           │ Connects via NodePort:                         │
│           │ - Loki:       31000                            │
│           │ - Prometheus: 30090                            │
│           │                                                 │
└───────────┼─────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────┐
│ Kind Kubernetes Cluster (on Docker)                        │
│                                                             │
│  ┌────────────────────────────────────┐                    │
│  │ Namespace: logging                 │                    │
│  │                                    │                    │
│  │  ┌──────────┐      ┌───────────┐  │                    │
│  │  │  Loki    │      │ Promtail  │  │                    │
│  │  │ (3100)   │◄─────┤(DaemonSet)│  │                    │
│  │  └──────────┘      └───────────┘  │                    │
│  │                           │        │                    │
│  └───────────────────────────┼────────┘                    │
│                              │                             │
│  ┌────────────────────────────────────────┐                │
│  │ Namespace: monitoring                  │                │
│  │                                        │                │
│  │  ┌────────────┐  ┌──────────────────┐ │                │
│  │  │ Prometheus │  │ kube-state-      │ │                │
│  │  │  (9090)    │◄─┤ metrics (8080)   │ │                │
│  │  └─────┬──────┘  └──────────────────┘ │                │
│  │        │                               │                │
│  │        │         ┌──────────────────┐ │                │
│  │        └─────────┤ node-exporter    │ │                │
│  │                  │ (DaemonSet:9100) │ │                │
│  │                  └──────────────────┘ │                │
│  └────────────────────────────────────────┘                │
│                     │                                      │
│                     ▼                                      │
│  ┌─────────────────────────────────────────┐              │
│  │ All Pods, Nodes & Services in Cluster  │              │
│  │ (Logs → Promtail, Metrics → Prometheus)│              │
│  └─────────────────────────────────────────┘              │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

- Docker Desktop running
- Kind Kubernetes cluster running (`app-demo`)
- kubectl configured and accessible
- docker-compose available

## Installation

### Loki Setup

Loki runs in the Kind Kubernetes cluster and aggregates logs from all pods.

```bash
cd k8s/grafana
./setup-loki.sh
```

**What it does:**
1. Creates `logging` namespace
2. Deploys Loki with 10GB persistent storage
3. Deploys Promtail as DaemonSet on all nodes
4. Configures automatic pod log discovery
5. Sets up RBAC permissions

**Verify installation:**
```bash
kubectl get pods -n logging
kubectl logs -n logging deployment/loki
```

### Grafana Setup

Grafana runs on Docker Desktop and connects to Loki in the Kind cluster.

```bash
cd k8s/grafana
./setup-grafana-docker.sh
```

**What it does:**
1. Checks if Loki is running in Kind
2. Checks if Prometheus is running (optional)
3. Configures datasource access via NodePort
4. Creates Loki and Prometheus datasource configurations
5. Starts Grafana with Docker Compose
6. Pre-configures both datasources
7. Verifies connectivity

**Manual installation:**
```bash
# If automated script doesn't work
cd k8s/grafana
docker-compose up -d
```

### Prometheus Setup

Prometheus runs in the Kind Kubernetes cluster and collects metrics from all components.

```bash
cd k8s/grafana
./setup-prometheus.sh
```

**What it does:**
1. Creates `monitoring` namespace
2. Deploys Prometheus with 10GB persistent storage (15-day retention)
3. Deploys kube-state-metrics for Kubernetes object metrics
4. Deploys node-exporter as DaemonSet for system metrics
5. Configures RBAC permissions for metric scraping
6. Sets up scrape configurations for:
   - Prometheus self-monitoring
   - Kubernetes API server
   - Kubernetes nodes
   - kube-state-metrics
   - node-exporter
   - Loki metrics
   - Annotated pods (prometheus.io/scrape=true)
7. Exposes Prometheus via NodePort 30090

**Verify installation:**
```bash
kubectl get pods -n monitoring
kubectl logs -n monitoring deployment/prometheus

# Check scrape targets
open http://localhost:30090/targets
```

**Manual installation:**
```bash
# If automated script doesn't work
cd k8s/grafana
docker-compose up -d
```

## Access

### Grafana Web UI

**URL:** http://localhost:3000

**Credentials:**
- Username: `admin`
- Password: `admin`

**Port Forward (if needed):**
```bash
# For Loki
kubectl port-forward -n logging svc/loki 3100:3100

# For Grafana (if using K8s deployment)
kubectl port-forward -n grafana svc/grafana 3000:3000
```

## Usage

### Exploring Logs

1. Open Grafana: http://localhost:3000
2. Login with admin/admin
3. Click **Explore** (compass icon) in left sidebar
4. Loki is already selected as datasource
5. Enter LogQL query in query field
6. Click **Run query** or press Shift+Enter

### Creating Dashboards

1. Click **+** → **Dashboard** → **Add visualization**
2. Select **Loki** datasource
3. Enter LogQL query
4. Choose visualization type:
   - **Logs** - Raw log output
   - **Time series** - Metrics over time
   - **Stat** - Single value
   - **Table** - Tabular data
5. Customize appearance and settings
6. Click **Save dashboard**

## LogQL Query Examples

### Basic Queries

```logql
# All logs from a namespace
{namespace="default"}

# Specific application
{namespace="default", app="cicd-demo"}

# Specific pod
{namespace="default", pod="cicd-demo-5d7f8b9c4-abc12"}

# Multiple namespaces
{namespace=~"default|kube-system"}
```

### Filtering

```logql
# Search for text (case-insensitive)
{namespace="default"} |= "error"

# Exclude text
{namespace="default"} != "debug"

# Multiple filters
{namespace="default", app="cicd-demo"} |= "error" != "timeout"

# Regex matching
{namespace="default"} |~ "error|exception|failed"

# Case-sensitive regex
{namespace="default"} |~ `(?-i)ERROR`
```

### Parsing & Formatting

```logql
# Parse JSON logs
{namespace="default"} | json

# Extract specific JSON fields
{namespace="default"} | json | level="error"

# Parse logfmt
{namespace="default"} | logfmt

# Pattern matching
{namespace="default"} | pattern `<timestamp> <level> <message>`

# Line format
{namespace="default"} | line_format "{{.pod}}: {{.message}}"
```

### Metrics & Aggregations

```logql
# Count log lines per second
rate({namespace="default"}[5m])

# Sum by label
sum by (app) (rate({namespace="default"}[5m]))

# Count by level
sum by (level) (count_over_time({namespace="default"} | json [5m]))

# Bytes per second
sum(rate({namespace="default"}[5m] | unwrap bytes))

# Top 10 pods by log volume
topk(10, sum by (pod) (rate({namespace="default"}[5m])))
```

### Time Ranges

```logql
# Last 5 minutes
{namespace="default"} [5m]

# Logs with timestamp
{namespace="default"} | __timestamp__ > time("2025-11-11T10:00:00Z")

# Specific time window
{namespace="default"} | __timestamp__ >= time("2025-11-11T09:00:00Z") | __timestamp__ <= time("2025-11-11T10:00:00Z")
```

### Advanced Queries

```logql
# Error rate by application
sum by (app) (rate({namespace="default"} |= "error" [5m])) / sum by (app) (rate({namespace="default"}[5m]))

# Logs with duration > 100ms
{namespace="default"} | json | duration > 100

# Unique error messages
count by (error) ({namespace="default"} | json | level="error")

# Request latency percentiles
quantile_over_time(0.95, {namespace="default"} | json | unwrap duration [5m])
```

## PromQL Query Examples

### Basic Metrics

```promql
# CPU usage by pod
sum(rate(container_cpu_usage_seconds_total[5m])) by (pod)

# Memory usage by namespace
sum(container_memory_usage_bytes) by (namespace)

# Network bytes received
sum(rate(container_network_receive_bytes_total[5m])) by (pod)

# Disk usage
sum(container_fs_usage_bytes) by (pod)
```

### Node Metrics

```promql
# Node CPU usage percentage
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Node memory usage percentage
100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))

# Node disk usage
100 - ((node_filesystem_avail_bytes{mountpoint="/"} * 100) / node_filesystem_size_bytes{mountpoint="/"})

# Network traffic by node
rate(node_network_receive_bytes_total[5m])
```

### Kubernetes Object Metrics

```promql
# Pod count by namespace
count(kube_pod_info) by (namespace)

# Deployment replica status
kube_deployment_status_replicas_available / kube_deployment_spec_replicas

# Failed pods
kube_pod_status_phase{phase="Failed"}

# Pending pods
count(kube_pod_status_phase{phase="Pending"})

# Container restarts
sum(rate(kube_pod_container_status_restarts_total[5m])) by (pod)
```

### Resource Requests & Limits

```promql
# CPU requests by namespace
sum(kube_pod_container_resource_requests{resource="cpu"}) by (namespace)

# Memory limits by pod
sum(kube_pod_container_resource_limits{resource="memory"}) by (pod)

# Pods over memory limit
sum(container_memory_usage_bytes) / sum(kube_pod_container_resource_limits{resource="memory"}) * 100

# CPU throttling
rate(container_cpu_cfs_throttled_seconds_total[5m])
```

### Application Metrics

```promql
# HTTP request rate
sum(rate(http_requests_total[5m])) by (job)

# HTTP error rate (4xx, 5xx)
sum(rate(http_requests_total{status=~"4..|5.."}[5m])) / sum(rate(http_requests_total[5m]))

# Request duration 95th percentile
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Active connections
sum(http_server_active_connections) by (instance)
```

### Prometheus Meta Metrics

```promql
# Prometheus targets up
up

# Scrape duration
scrape_duration_seconds

# Time series count
prometheus_tsdb_symbol_table_size_bytes

# Storage size
prometheus_tsdb_storage_blocks_bytes
```

## Management Commands

### Loki (Kubernetes)

```bash
# Check status
kubectl get pods -n logging

# View logs
kubectl logs -n logging deployment/loki --tail=100 -f
kubectl logs -n logging daemonset/promtail --tail=100 -f

# Restart
kubectl rollout restart deployment/loki -n logging
kubectl rollout restart daemonset/promtail -n logging

# Scale
kubectl scale deployment loki -n logging --replicas=2

# Port forward for testing
kubectl port-forward -n logging svc/loki 3100:3100

# Test Loki API
curl http://localhost:3100/ready
curl http://localhost:3100/metrics
curl 'http://localhost:3100/loki/api/v1/labels'
```

### Grafana (Docker)

```bash
# View logs
docker logs -f grafana-desktop

# Restart
cd k8s/grafana && docker-compose restart

# Stop
cd k8s/grafana && docker-compose down

# Rebuild and restart
cd k8s/grafana && docker-compose down && docker-compose up -d --force-recreate

# Access shell
docker exec -it grafana-desktop /bin/bash

# Check health
docker inspect grafana-desktop | grep -A 10 Health
```

### Prometheus (Kubernetes)

```bash
# Check status
kubectl get pods -n monitoring

# View logs
kubectl logs -n monitoring deployment/prometheus --tail=100 -f
kubectl logs -n monitoring deployment/kube-state-metrics --tail=100 -f
kubectl logs -n monitoring daemonset/node-exporter --tail=100 -f

# Restart
kubectl rollout restart deployment/prometheus -n monitoring
kubectl rollout restart deployment/kube-state-metrics -n monitoring
kubectl rollout restart daemonset/node-exporter -n monitoring

# Port forward for testing
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Test Prometheus API
curl http://localhost:30090/-/ready
curl http://localhost:30090/-/healthy
curl http://localhost:30090/api/v1/targets
curl http://localhost:30090/api/v1/query?query=up

# Reload configuration (without restart)
kubectl exec -n monitoring deployment/prometheus -- \
  wget --post-data='' -O- http://localhost:9090/-/reload

# Check configuration
kubectl exec -n monitoring deployment/prometheus -- \
  promtool check config /etc/prometheus/prometheus.yml
```

### Verify Connectivity

```bash
# From Grafana to Loki (Docker to Kind)
docker exec grafana-desktop wget -qO- http://host.docker.internal:31000/ready

# From Grafana to Prometheus (Docker to Kind)
docker exec grafana-desktop wget -qO- http://host.docker.internal:30090/-/ready

# From host to Loki
curl http://localhost:31000/ready

# From host to Prometheus
curl http://localhost:30090/-/ready
```

## Troubleshooting

### Loki Not Showing Logs

**Check Promtail:**
```bash
kubectl get pods -n logging
kubectl logs -n logging daemonset/promtail --tail=50
```

**Verify pods have logs:**
```bash
kubectl logs -n default --all-containers=true --tail=10
```

**Check Loki is receiving logs:**
```bash
kubectl port-forward -n logging svc/loki 3100:3100
curl 'http://localhost:3100/loki/api/v1/labels'
```

### Grafana Can't Connect to Loki

**Check Loki service:**
```bash
kubectl get svc -n logging loki
```

**Test from host:**
```bash
curl http://localhost:31000/ready
```

**Test from Grafana container:**
```bash
docker exec grafana-desktop wget -qO- http://host.docker.internal:31000/ready
docker exec grafana-desktop wget -qO- http://host.docker.internal:30090/-/ready
```

**Check Grafana datasources:**
1. Open http://localhost:3000/connections/datasources
2. Click on "Loki" or "Prometheus"
3. Click "Test" button
4. Should show "Data source is working"

### Prometheus Not Scraping Targets

**Check scrape targets:**
```bash
# View targets in UI
open http://localhost:30090/targets

# Or via API
curl http://localhost:30090/api/v1/targets | jq .
```

**Common issues:**
- RBAC permissions not set: `kubectl get clusterrolebinding prometheus`
- ServiceAccount not configured: `kubectl get sa -n monitoring prometheus`
- Network policies blocking: `kubectl get networkpolicies -A`

**Fix scrape configuration:**
```bash
# Edit ConfigMap
kubectl edit configmap prometheus-config -n monitoring

# Then reload Prometheus
kubectl exec -n monitoring deployment/prometheus -- \
  wget --post-data='' -O- http://localhost:9090/-/reload
```

### Permission Errors

**Promtail can't read logs:**
```bash
kubectl logs -n logging daemonset/promtail
# Look for permission denied errors

# Reapply RBAC configuration
cd k8s/grafana
./setup-loki.sh
```

**Prometheus can't scrape metrics:**
```bash
kubectl logs -n monitoring deployment/prometheus | grep -i "permission\|forbidden"

# Reapply RBAC configuration
cd k8s/grafana
./setup-prometheus.sh
```

### High Memory Usage

**Loki using too much memory:**
```bash
# Check resource usage
kubectl top pod -n logging

# Adjust resource limits
kubectl edit deployment loki -n logging
# Modify resources.limits.memory
```

**Prometheus using too much memory:**
```bash
# Check resource usage
kubectl top pod -n monitoring

# Check TSDB size
kubectl exec -n monitoring deployment/prometheus -- \
  du -sh /prometheus

# Adjust retention or reduce scrape frequency
kubectl edit configmap prometheus-config -n monitoring
```

**Grafana using too much memory:**
```bash
# Check usage
docker stats grafana-desktop

# Adjust in docker-compose.yml
# Add: mem_limit: 512m
```

### Logs Not Parsing Correctly

**JSON logs not parsed:**
```logql
# Explicitly parse JSON
{namespace="default"} | json | line_format "{{.level}}: {{.message}}"
```

**Multiline logs split:**
- Configure Promtail pipeline stages in ConfigMap
- Add multiline stage configuration

### Query Performance Issues

**Slow queries:**
1. Reduce time range
2. Add more specific label filters
3. Use metric queries instead of log queries
4. Limit number of lines: `| limit 1000`

**Out of memory errors:**
```logql
# Instead of this (memory intensive):
{namespace="default"}

# Use this (more efficient):
{namespace="default", app="cicd-demo"} [5m]
```

## Cleanup

### Stop Services

```bash
# Stop Grafana (keep data)
cd k8s/grafana
docker-compose down

# Stop Grafana (remove data)
cd k8s/grafana
./cleanup-grafana-docker.sh
# Choose "yes" to remove data
```

### Uninstall from Kubernetes

```bash
# Remove Loki and Promtail
kubectl delete namespace logging

# Remove Prometheus and metrics exporters
kubectl delete namespace monitoring

# Clean up cluster roles and bindings
kubectl delete clusterrole prometheus loki kube-state-metrics
kubectl delete clusterrolebinding prometheus loki kube-state-metrics
```

### Complete Cleanup

```bash
# Remove all Docker resources
cd k8s/grafana
docker-compose down -v

# Remove Kind cluster (if needed)
kind delete cluster --name app-demo

# Remove all Docker containers and networks
docker system prune -a
```

## Data Persistence

### Loki (Kubernetes)
- **Storage:** PersistentVolumeClaim `loki-pvc` in `logging` namespace
- **Size:** 10GB
- **Retention:** Based on available storage
- **Location:** Managed by Kind cluster

### Prometheus (Kubernetes)
- **Storage:** PersistentVolumeClaim `prometheus-pvc` in `monitoring` namespace
- **Size:** 10GB (9GB usable, 1GB buffer)
- **Retention:** 15 days
- **Location:** Managed by Kind cluster

**Check storage usage:**
```bash
# Loki
kubectl exec -n logging deployment/loki -- du -sh /loki

# Prometheus
kubectl exec -n monitoring deployment/prometheus -- du -sh /prometheus
```

### Grafana (Docker)
- **Storage:** Docker volume `grafana-data`
- **Contents:** Dashboards, datasources, settings, users

**Backup:**
```bash
docker run --rm -v grafana-data:/data -v $(pwd):/backup alpine \
  tar czf /backup/grafana-backup.tar.gz -C /data .
```

**Restore:**
```bash
docker run --rm -v grafana-data:/data -v $(pwd):/backup alpine \
  tar xzf /backup/grafana-backup.tar.gz -C /data
```

## Port Reference

| Service | Port | Protocol | Access |
|---------|------|----------|--------|
| Grafana | 3000 | HTTP | Docker Desktop |
| Loki | 3100 | HTTP | Kind cluster internal |
| Loki NodePort | 31000 | HTTP | Host → Kind cluster |
| Prometheus | 9090 | HTTP | Kind cluster internal |
| Prometheus NodePort | 30090 | HTTP | Host → Kind cluster |
| Promtail | 9080 | HTTP | Metrics endpoint |
| kube-state-metrics | 8080 | HTTP | Metrics endpoint |
| node-exporter | 9100 | HTTP | Metrics endpoint |

## Configuration Files

| File | Purpose |
|------|---------||
| `k8s/grafana/docker-compose.yml` | Grafana container definition |
| `k8s/grafana/setup-loki.sh` | Loki installation script |
| `k8s/grafana/setup-grafana-docker.sh` | Grafana installation script |
| `k8s/grafana/setup-prometheus.sh` | Prometheus installation script |
| `k8s/grafana/provisioning/datasources/loki.yml` | Loki datasource config |
| `k8s/grafana/provisioning/datasources/prometheus.yml` | Prometheus datasource config |
| `k8s/grafana/provisioning/dashboards/dashboards.yml` | Dashboard provisioning |
| `k8s/prometheus/prometheus-config.yaml` | Prometheus scrape configuration |
| `k8s/prometheus/prometheus-deployment.yaml` | Prometheus deployment manifest |
| `k8s/prometheus/kube-state-metrics.yaml` | Kubernetes metrics exporter |
| `k8s/prometheus/node-exporter.yaml` | Node metrics exporter |

## Related Documentation

- [Port Reference](Port-Reference.md)
- [Kubernetes Setup](Kind-K8s.md)
- [Docker Setup](Docker.md)
- [Project Overview](Project-Overview.md)

## Resources

- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [LogQL Language](https://grafana.com/docs/loki/latest/logql/)
- [Promtail Configuration](https://grafana.com/docs/loki/latest/clients/promtail/)
