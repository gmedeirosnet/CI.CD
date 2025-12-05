# Policy Reporter for Kyverno (Docker Desktop)

Policy Reporter is a monitoring and observability tool for Kyverno policies. It provides a web UI, REST API, and integrations with monitoring tools to track policy violations and compliance status.

## Installation

Policy Reporter runs as Docker Desktop containers, connecting to your Kind Kubernetes cluster to monitor Kyverno policy reports.

### Prerequisites

- Docker Desktop installed and running
- kubectl configured to access your Kind cluster
- Kyverno installed in the cluster
- Loki (optional, for violation logging)

### Install Policy Reporter

```bash
cd k8s/kyverno/policy-reporter
./install-policy-reporter.sh
```

The installation script will:
1. Create a Kubernetes service account with permissions to read PolicyReports
2. Generate a kubeconfig file for the container
3. Configure access to Loki in the Kind cluster
4. Start Policy Reporter and UI containers on Docker Desktop
5. Expose the UI on http://localhost:31002

## Features

### Web UI Dashboard
- View policy violations across all namespaces
- Filter by severity, policy, and resource type
- Track compliance trends over time
- **Access**: http://localhost:31002

### REST API
- Query policy reports programmatically
- Integrate with CI/CD pipelines
- Export data for custom dashboards
- **Access**: http://localhost:31001/api/v1

### Loki Integration
- Automatic logging of policy violations
- Searchable violation history
- Integration with Grafana dashboards

### Prometheus Metrics
- Metrics for policy violations, passes, and failures
- **Access**: http://localhost:31001/metrics

## Configuration

Policy Reporter is configured via Docker Compose. The configuration file is in `docker-compose.yml`.

### Key Settings

```yaml
environment:
  # Loki integration
  LOKI_HOST: http://host.docker.internal:31000
  LOKI_MINIMUM_PRIORITY: warning

  # API and metrics
  REST_ENABLED: true
  METRICS_ENABLED: true
```

### Customize Loki Settings

Edit `docker-compose.yml` and restart:

```bash
cd k8s/kyverno/policy-reporter
# Edit docker-compose.yml
docker-compose restart
```

## Usage

### View Policy Reports

Open the dashboard at http://localhost:31002 to see:
- Total violations by severity
- Recent policy failures
- Compliance status per namespace
- Detailed violation information

### API Examples

#### Get all cluster-level policy reports
```bash
curl http://localhost:31001/api/v1/cluster-resources/reports
```

#### Get namespace-level policy reports
```bash
curl http://localhost:31001/api/v1/namespaced-resources/reports
```

#### Get reports for specific namespace
```bash
curl http://localhost:31001/api/v1/namespaced-resources/reports?namespace=default
```

#### Get violations only
```bash
curl http://localhost:31001/api/v1/cluster-resources/reports?status=fail
```

### Docker Commands

#### View logs
```bash
# Policy Reporter logs
docker logs policy-reporter -f

# UI logs
docker logs policy-reporter-ui -f
```

#### Restart services
```bash
cd k8s/kyverno/policy-reporter
docker-compose restart
```

#### Stop services
```bash
cd k8s/kyverno/policy-reporter
docker-compose down
```

#### Start services
```bash
cd k8s/kyverno/policy-reporter
docker-compose up -d
```

## Integration with Grafana

Policy Reporter integrates with Grafana for advanced visualization:

1. **Metrics via Prometheus**
   - Policy Reporter exposes metrics at http://localhost:31001/metrics
   - Configure Prometheus to scrape this endpoint
   - Import Grafana dashboards for policy metrics

2. **Logs via Loki**
   - Violations are automatically sent to Loki
   - Query in Grafana: `{app="policy-reporter"}`
   - Filter by severity: `{app="policy-reporter"} |= "severity=high"`

### Import Dashboard

1. Open Grafana (http://localhost:3000)
2. Go to Dashboards → Import
3. Enter dashboard ID: 15324 (Policy Reporter Dashboard)
4. Select Prometheus data source
5. Click Import

## Troubleshooting

### Container Not Starting

Check container logs:
```bash
docker logs policy-reporter
```

Common issues:
- Kubernetes API not reachable: Check kubeconfig
- Loki connection failed: Verify Loki is running and accessible

### No Policy Reports Showing

1. Verify Kyverno is running:
```bash
kubectl get pods -n kyverno
```

2. Check if PolicyReports exist:
```bash
kubectl get policyreport -A
kubectl get clusterpolicyreport
```

3. Verify service account permissions:
```bash
kubectl get clusterrolebinding policy-reporter -o yaml
```

### API Not Responding

Check if container is running:
```bash
docker ps | grep policy-reporter
```

Test API health:
```bash
curl http://localhost:31001/healthz
```

### Loki Integration Not Working

1. Verify Loki is accessible from Docker Desktop:
```bash
# From your host
curl http://localhost:31000/ready
```

2. Check Policy Reporter configuration:
```bash
docker exec policy-reporter env | grep LOKI
```

3. Check Policy Reporter logs for Loki errors:
```bash
docker logs policy-reporter | grep -i loki
```

### Update Kubeconfig

If your Kind cluster configuration changes:

```bash
cd k8s/kyverno/policy-reporter
# Regenerate kubeconfig
./install-policy-reporter.sh
```

## Architecture

```
┌─────────────────────────────────────────────────┐
│           Docker Desktop (Host)                 │
│                                                 │
│  ┌──────────────────┐  ┌──────────────────┐   │
│  │ Policy Reporter  │  │ Policy Reporter  │   │
│  │   (Container)    │  │   UI Container   │   │
│  │                  │  │                  │   │
│  │ - REST API       │  │ - Web Dashboard  │   │
│  │ - Metrics        │  │                  │   │
│  │ - Loki Client    │  │                  │   │
│  └────────┬─────────┘  └────────┬─────────┘   │
│           │                     │              │
│           │ :31001              │ :31002       │
└───────────┼─────────────────────┼──────────────┘
            │                     │
            │ kubeconfig          │
            │ mounted             │
            ▼                     ▼
┌─────────────────────────────────────────────────┐
│         Kind Cluster (app-demo)                 │
│                                                 │
│  ┌──────────────┐  ┌──────────────┐           │
│  │   Kyverno    │  │     Loki     │           │
│  │  (kyverno)   │  │  (logging)   │           │
│  │              │  │              │           │
│  │ PolicyReport │  │ :31000       │           │
│  │     CRDs     │  │ (NodePort)   │           │
│  └──────────────┘  └──────────────┘           │
│                                                 │
└─────────────────────────────────────────────────┘
```

## Additional Resources

- [Policy Reporter Documentation](https://kyverno.github.io/policy-reporter/)
- [Kyverno Documentation](https://kyverno.io/)
- [Example Dashboards](https://github.com/kyverno/policy-reporter/tree/main/grafana)
- [API Reference](https://github.com/kyverno/policy-reporter/blob/main/docs/api-reference.md)
