# Grafana & Loki Logging Setup

This guide covers the installation and configuration of Grafana and Loki for Kubernetes log aggregation in the CI/CD project.

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

The logging stack consists of:
- **Loki** - Log aggregation system (runs in Kind Kubernetes cluster)
- **Promtail** - Log collector agent (DaemonSet on all nodes)
- **Grafana** - Visualization and querying interface (runs on Docker Desktop)

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Docker Desktop                                          │
│                                                         │
│  ┌──────────────────┐                                  │
│  │   Grafana        │                                  │
│  │  (Port 3000)     │                                  │
│  └────────┬─────────┘                                  │
│           │                                             │
│           │ Connects via:                              │
│           │ - NodePort (31000) OR                      │
│           │ - Kind network bridge                       │
│           │                                             │
└───────────┼─────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────┐
│ Kind Kubernetes Cluster (on Docker)                    │
│                                                         │
│  ┌────────────────────────────────────┐                │
│  │ Namespace: logging                 │                │
│  │                                    │                │
│  │  ┌──────────┐      ┌───────────┐  │                │
│  │  │  Loki    │      │ Promtail  │  │                │
│  │  │ (3100)   │◄─────┤(DaemonSet)│  │                │
│  │  └──────────┘      └───────────┘  │                │
│  │                           │        │                │
│  └───────────────────────────┼────────┘                │
│                              │                         │
│                              ▼                         │
│  ┌────────────────────────────────────┐                │
│  │ All Pods in Cluster                │                │
│  │ (Logs collected by Promtail)       │                │
│  └────────────────────────────────────┘                │
└─────────────────────────────────────────────────────────┘
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
cd grafana
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
cd grafana
./setup-grafana-docker.sh
```

**What it does:**
1. Checks if Loki is running in Kind
2. Configures Loki access (NodePort or network bridge)
3. Creates Loki datasource configuration
4. Starts Grafana with Docker Compose
5. Pre-configures Loki as default datasource
6. Verifies connectivity

**Manual installation:**
```bash
# If automated script doesn't work
cd grafana
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
cd grafana && docker-compose restart

# Stop
cd grafana && docker-compose down

# Rebuild and restart
cd grafana && docker-compose down && docker-compose up -d --force-recreate

# Access shell
docker exec -it grafana-desktop /bin/bash

# Check health
docker inspect grafana-desktop | grep -A 10 Health
```

### Verify Connectivity

```bash
# From Grafana to Loki (Docker to Kind)
docker exec grafana-desktop wget -qO- http://host.docker.internal:31000/ready

# Or via Kind network bridge
docker exec grafana-desktop wget -qO- http://app-demo-control-plane:3100/ready

# From host to Loki
curl http://localhost:31000/ready
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
```

**Check Grafana datasource:**
1. Open http://localhost:3000/connections/datasources
2. Click on "Loki"
3. Click "Test" button
4. Should show "Data source is working"

### Permission Errors

**Promtail can't read logs:**
```bash
kubectl logs -n logging daemonset/promtail
# Look for permission denied errors

# Fix with updated RBAC
kubectl apply -f grafana/setup-loki.sh
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
cd grafana
docker-compose down

# Stop Grafana (remove data)
cd grafana
./cleanup-grafana-docker.sh
# Choose "yes" to remove data
```

### Uninstall from Kubernetes

```bash
# Remove Loki and Promtail
kubectl delete namespace logging

# Remove Grafana (if installed in K8s)
kubectl delete namespace grafana
```

### Complete Cleanup

```bash
# Remove all Docker resources
cd grafana
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
- **Location:** Managed by Kind cluster

**Backup:**
```bash
# Not recommended for local development
# For production, use object storage (S3, GCS, etc.)
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
| Promtail | 9080 | HTTP | Metrics endpoint |

## Configuration Files

| File | Purpose |
|------|---------|
| `grafana/docker-compose.yml` | Grafana container definition |
| `grafana/setup-loki.sh` | Loki installation script |
| `grafana/setup-grafana-docker.sh` | Grafana installation script |
| `grafana/provisioning/datasources/loki.yml` | Loki datasource config |
| `grafana/provisioning/dashboards/dashboards.yml` | Dashboard provisioning |

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
