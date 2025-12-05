# Kyverno Policy Reporter

Policy Reporter provides observability for Kyverno policies through:
- **Web UI Dashboard** - Visual interface for all policy reports
- **Prometheus Metrics** - Integration with monitoring stack
- **Loki Integration** - Automatic log aggregation of violations
- **REST API** - Programmatic access to policy data
- **Optional Notifications** - Slack, email, webhooks

## Quick Start

### Installation

```bash
# Install Policy Reporter
./install-policy-reporter.sh
```

### Access

- **Web UI**: http://localhost:31001
- **API**: http://localhost:31001/api/v1
- **Metrics**: http://localhost:31001/metrics

Alternative access via port-forward:
```bash
kubectl port-forward -n policy-reporter svc/policy-reporter-ui 8080:8080
# Open: http://localhost:8080
```

## Features

### 1. Web Dashboard

View all policy violations across namespaces in one unified interface:
- **Overview**: Total pass/fail/warn/error counts
- **By Namespace**: Compliance status per namespace
- **By Policy**: Which policies fail most frequently
- **By Resource**: List of non-compliant resources
- **Details**: Full violation information with remediation guidance

### 2. Loki Integration

Policy violations are automatically sent to Loki for:
- Long-term storage and retention
- Correlation with application logs
- Advanced querying in Grafana
- Audit trail compliance

Query violations in Grafana:
```logql
{cluster="kind-app-demo", source="kyverno"} |= "fail"
```

### 3. Prometheus Metrics

Expose metrics for Grafana dashboards:

```promql
# Total failed policies
policy_report_result{status="fail"}

# Failed policies by namespace
sum by (namespace) (policy_report_result{status="fail"})

# Top 5 failing policies
topk(5, sum by (policy) (policy_report_result{status="fail"}))

# Compliance rate
(sum(policy_report_result{status="pass"})) / (sum(policy_report_result))
```

### 4. REST API

Query reports programmatically:

```bash
# Get all reports
curl http://localhost:31001/api/v1/reports

# Get namespace-specific reports
curl http://localhost:31001/api/v1/namespaced-resources/reports?namespace=app-demo

# Get cluster-wide reports
curl http://localhost:31001/api/v1/cluster-resources/reports

# Get reports filtered by policy
curl http://localhost:31001/api/v1/reports?policy=disallow-privileged

# Get only failed results
curl http://localhost:31001/api/v1/reports?status=fail
```

## Configuration

### Enable Slack Notifications

Edit `policy-reporter-values.yaml`:

```yaml
target:
  slack:
    webhook: "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
    channel: "#kyverno-alerts"
    minimumPriority: "warning"
    skipExistingOnStartup: true
    sources:
      - kyverno
```

Apply changes:
```bash
helm upgrade policy-reporter policy-reporter/policy-reporter \
  -n policy-reporter \
  -f policy-reporter-values.yaml
```

### Enable Email Reports

```yaml
emailReports:
  enabled: true
  smtp:
    host: "smtp.gmail.com"
    port: 587
    username: "your-email@gmail.com"
    password: "your-app-password"
    from: "kyverno@company.com"
  to: "security-team@company.com"
  minimumPriority: "critical"
  schedule: "0 8 * * *"  # Daily at 8am
```

### Filter Reports

Only monitor specific namespaces:

```yaml
policyReportFilter:
  namespaces:
    include: ["production", "staging"]
    exclude: ["kube-system", "kube-public"]
```

## Integration with CI/CD Lab

### Grafana Dashboard

Import Policy Reporter dashboard into Grafana:

1. Access Grafana: http://localhost:3000
2. Go to Dashboards → Import
3. Use Dashboard ID: `16889` (Policy Reporter Dashboard)
4. Select Prometheus datasource
5. Click Import

### Prometheus Scraping

Policy Reporter metrics are automatically exposed. Add to Prometheus config if needed:

```yaml
scrape_configs:
  - job_name: 'policy-reporter'
    static_configs:
      - targets: ['policy-reporter.policy-reporter:8080']
```

### Loki Queries in Grafana

Create alerts based on policy violations:

```logql
# Critical violations in production
{cluster="kind-app-demo", source="kyverno", namespace="production"}
  |= "fail"
  | json
  | severity="critical"
```

## Monitoring

### Check Status

```bash
# Check pods
kubectl get pods -n policy-reporter

# View logs
kubectl logs -n policy-reporter -l app.kubernetes.io/name=policy-reporter -f

# Check UI logs
kubectl logs -n policy-reporter -l app.kubernetes.io/name=ui -f

# Check service status
kubectl get svc -n policy-reporter
```

### View Reports

```bash
# View all PolicyReports
kubectl get policyreport -A

# View ClusterPolicyReports
kubectl get clusterpolicyreport

# Describe specific report
kubectl describe policyreport -n app-demo

# View violations
kubectl get policyreport -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.summary.fail}{"\n"}{end}'
```

## Troubleshooting

### No Reports Showing

```bash
# 1. Check if Kyverno is creating reports
kubectl get policyreport -A
kubectl get clusterpolicyreport

# 2. Check Policy Reporter logs
kubectl logs -n policy-reporter -l app.kubernetes.io/name=policy-reporter

# 3. Verify Kyverno plugin is enabled
kubectl get deployment policy-reporter -n policy-reporter -o yaml | grep -A 5 "kyvernoPlugin"

# 4. Restart Policy Reporter
kubectl rollout restart deployment/policy-reporter -n policy-reporter
```

### UI Not Accessible

```bash
# Check NodePort service
kubectl get svc policy-reporter-ui -n policy-reporter

# Verify port 31001 is available
lsof -i :31001

# Use port-forward as alternative
kubectl port-forward -n policy-reporter svc/policy-reporter-ui 8080:8080
```

### Loki Integration Not Working

```bash
# Check Loki is accessible
kubectl get svc -n logging

# Test Loki endpoint
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v http://loki.logging:3100/ready

# Check Policy Reporter config
kubectl get configmap policy-reporter-targets -n policy-reporter -o yaml
```

### High Memory Usage

Adjust resources in `policy-reporter-values.yaml`:

```yaml
resources:
  limits:
    memory: 1Gi  # Increase from 512Mi
    cpu: 1000m
  requests:
    memory: 512Mi
    cpu: 300m
```

## Maintenance

### Upgrade

```bash
# Update Helm repository
helm repo update policy-reporter

# Upgrade to latest version
helm upgrade policy-reporter policy-reporter/policy-reporter \
  -n policy-reporter \
  -f policy-reporter-values.yaml
```

### Backup

```bash
# Backup configuration
helm get values policy-reporter -n policy-reporter > policy-reporter-backup.yaml

# Backup database (if using SQLite)
kubectl exec -n policy-reporter deployment/policy-reporter -- \
  cat /tmp/policy-reporter.db > policy-reporter-db-backup.db
```

### Uninstall

```bash
# Remove Policy Reporter
helm uninstall policy-reporter -n policy-reporter

# Delete namespace
kubectl delete namespace policy-reporter
```

## Documentation

- **Official Docs**: https://kyverno.github.io/policy-reporter/
- **GitHub**: https://github.com/kyverno/policy-reporter
- **Helm Chart**: https://github.com/kyverno/policy-reporter/tree/main/charts/policy-reporter

## Support

For issues or questions:
- Check logs: `kubectl logs -n policy-reporter -l app.kubernetes.io/name=policy-reporter`
- Review documentation: https://kyverno.github.io/policy-reporter/
- GitHub issues: https://github.com/kyverno/policy-reporter/issues
