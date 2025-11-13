# Port Reference Guide

## Overview
This document provides a comprehensive reference for all network ports used in the DevOps CI/CD learning laboratory environment.

## Port Summary Table

| Service | Internal Port | External Port | Protocol | Access URL | Purpose |
|---------|--------------|---------------|----------|------------|---------|
| **Jenkins** | 8080 | 8080 | HTTP | http://localhost:8080 | CI/CD orchestration |
| **Jenkins (Agent)** | 50000 | 50000 | TCP | - | Agent communication |
| **Harbor (HTTP)** | 80 | 8082 | HTTP | http://localhost:8082 | Container registry web UI |
| **Harbor (HTTPS)** | 443 | 8443 | HTTPS | https://localhost:8443 | Secure container registry |
| **SonarQube** | 9000 | 9000 | HTTP | http://localhost:9000 | Code quality analysis |
| **Grafana** | 3000 | 3000 | HTTP | http://localhost:3000 | Observability & Logs UI |
| **Loki** | 3100 | 31000 | HTTP | http://localhost:31000 | Log aggregation API |
| **Prometheus** | 9090 | 30090 | HTTP | http://localhost:30090 | Metrics & monitoring |
| **ArgoCD** | 80 | 8081 | HTTP | http://localhost:8081 | GitOps deployment UI |
| **Kyverno** | 8000 | - | HTTP | - | Policy engine metrics |
| **Promtail** | 9080 | - | HTTP | - | Log collector metrics |
| **kube-state-metrics** | 8080 | - | HTTP | - | K8s object metrics |
| **node-exporter** | 9100 | - | HTTP | - | Node/system metrics |
| **Application** | 8001 | 8001 | HTTP | http://localhost:8001 | Demo Spring Boot app |
| **Kind API Server** | 6443 | 6443 | HTTPS | https://127.0.0.1:6443 | Kubernetes API |
| **Kind Dashboard** | - | 30000-32767 | HTTP | http://localhost:30xxx | K8s NodePort services |

## Automated Port Forwarding

The lab includes an automated script for managing Kubernetes port forwards and Docker permissions.

**Script**: `scripts/k8s-permissions_port-forward.sh`

**Features**:
- Automatically fixes Docker socket permissions for Jenkins
- Manages port forwards for Loki, Prometheus, and ArgoCD
- PID-based tracking for reliable start/stop
- Status monitoring and orphaned process cleanup

**Usage**:
```bash
# Start all port forwards (includes Docker permission fix)
./scripts/k8s-permissions_port-forward.sh start

# Check status
./scripts/k8s-permissions_port-forward.sh status

# Stop all port forwards
./scripts/k8s-permissions_port-forward.sh stop

# Restart all
./scripts/k8s-permissions_port-forward.sh restart

# Fix Docker permissions only
./scripts/k8s-permissions_port-forward.sh fix-docker

# Cleanup orphaned processes
./scripts/k8s-permissions_port-forward.sh cleanup
```

**Managed Services**:
- **Loki**: localhost:31000 → logging/loki:3100
- **Prometheus**: localhost:30090 → monitoring/prometheus:9090
- **ArgoCD**: localhost:8081 → argocd/argocd-server:80

**PID Files**: Stored in `/tmp/k8s-port-forward/*.pid`

## Detailed Service Configurations

### Jenkins

```yaml
Ports:
  - 8080:8080    # Web UI and API
  - 50000:50000  # Agent communication (JNLP)

Environment Variables:
  JENKINS_PORT: 8080
  JENKINS_SLAVE_AGENT_PORT: 50000

Access:
  URL: http://localhost:8080
  Default User: admin
  Password: (set during initial setup)
```

**Port Conflicts**: If port 8080 is in use, modify `docker-compose.yml` or Jenkins startup script.

---

### Harbor Registry

```yaml
HTTP Port:
  External: 8082
  Internal: 80
  Protocol: HTTP
  URL: http://localhost:8082

HTTPS Port:
  External: 8443
  Internal: 443
  Protocol: HTTPS
  URL: https://localhost:8443

Docker Registry API:
  URL: localhost:8082 (for docker push/pull)

Environment Variables:
  HARBOR_HTTP_PORT: 8082
  HARBOR_HTTPS_PORT: 8443
```

**Docker Configuration**:
```json
{
  "insecure-registries": ["localhost:8082"]
}
```

---

### SonarQube

```yaml
Port:
  External: 9000
  Internal: 9000
  Protocol: HTTP
  URL: http://localhost:9000

Environment Variables:
  SONAR_HOST: http://localhost:9000
  SONAR_PORT: 9000

Database:
  Internal Port: 5432 (PostgreSQL)
  Not exposed externally
```

---

### Grafana, Loki & Prometheus

```yaml
Grafana:
  External: 3000
  Internal: 3000
  Protocol: HTTP
  URL: http://localhost:3000
  Deployment: Docker Desktop

  Environment Variables:
    GF_SECURITY_ADMIN_USER: admin
    GF_SECURITY_ADMIN_PASSWORD: admin

  Access:
    Username: admin
    Password: admin

  Datasources:
    - Loki (logs)
    - Prometheus (metrics)

Loki:
  Internal: 3100 (ClusterIP in K8s)
  NodePort: 31000 (for external access)
  Protocol: HTTP
  Namespace: logging (Kind K8s)

  API Endpoints:
    Ready: http://localhost:31000/ready
    Metrics: http://localhost:31000/metrics
    Labels: http://localhost:31000/loki/api/v1/labels
    Query: http://localhost:31000/loki/api/v1/query

Promtail:
  Internal: 9080 (metrics)
  Deployment: DaemonSet (Kind K8s)
  Namespace: logging

Prometheus:
  Internal: 9090 (ClusterIP in K8s)
  NodePort: 30090 (for external access)
  Protocol: HTTP
  Namespace: monitoring (Kind K8s)

  API Endpoints:
    UI: http://localhost:30090
    Ready: http://localhost:30090/-/ready
    Healthy: http://localhost:30090/-/healthy
    Targets: http://localhost:30090/targets
    Config: http://localhost:30090/config
    Query: http://localhost:30090/api/v1/query

kube-state-metrics:
  Internal: 8080 (metrics), 8081 (telemetry)
  Deployment: Deployment (Kind K8s)
  Namespace: monitoring

node-exporter:
  Internal: 9100 (metrics)
  Deployment: DaemonSet (Kind K8s)
  Namespace: monitoring

Connections:
  Grafana -> Loki: http://host.docker.internal:31000
  Grafana -> Prometheus: http://host.docker.internal:30090
  Prometheus -> kube-state-metrics: kube-state-metrics.monitoring.svc.cluster.local:8080
  Prometheus -> node-exporter: Pod IP discovery
  Prometheus -> Loki: loki.logging.svc.cluster.local:3100
```

**Port Forward Commands (Manual)**:

For automated port forwarding, use `scripts/k8s-permissions_port-forward.sh start`

Manual commands:
```bash
# Loki (from K8s to host)
kubectl port-forward -n logging svc/loki 31000:3100

# Prometheus (from K8s to host)
kubectl port-forward -n monitoring svc/prometheus 30090:9090

# ArgoCD (from K8s to host)
kubectl port-forward -n argocd svc/argocd-server 8081:80

# Grafana (if in K8s)
kubectl port-forward -n grafana svc/grafana 3000:3000
```

---

### Kind Kubernetes Cluster

```yaml
API Server:
  Port: 6443
  Protocol: HTTPS
  URL: https://127.0.0.1:6443

Control Plane:
  Container Port: 6443
  Mapped Port: 6443

Worker Nodes:
  NodePort Range: 30000-32767
  Used for exposing services externally

DNS:
  Internal Port: 53
  Service: CoreDNS

Metrics Server:
  Internal Port: 443
```

**kubeconfig Location**: `~/.kube/config`

---

### Spring Boot Application

```yaml
Application Port:
  External: 8001
  Internal: 8001
  Protocol: HTTP

Health Endpoint:
  URL: http://localhost:8001/health

API Endpoints:
  Base URL: http://localhost:8001

Kubernetes Service:
  Type: LoadBalancer or NodePort
  Port: 80 -> 8001
  TargetPort: 8001
```

---

### ArgoCD

```yaml
Server Port:
  External: 8081 (HTTP - automated script)
  External: 8080 (HTTP - manual)
  External: 8443 (HTTPS - manual)
  Internal: 80/443

API Server:
  URL: localhost:8081 (automated) or localhost:8080 (manual)
  gRPC Port: 8080

Repo Server:
  Internal Port: 8081

Redis:
  Internal Port: 6379

Metrics:
  Internal Port: 8082

Namespace:
  argocd (Kind K8s)
```

**Automated Access**:
```bash
# Start port forward (includes Docker permission fix)
./scripts/k8s-permissions_port-forward.sh start

# Access UI
open http://localhost:8081
```

**Manual Port Forward Command**:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

**Note**: Automated script uses port 8081 to avoid conflict with Jenkins (8080)

---

### Kyverno

```yaml
Metrics Port:
  Internal: 8000
  Protocol: HTTP
  Namespace: kyverno (Kind K8s)
  Note: Port 8000 often conflicts with k9s or other tools

Webhook Server:
  Internal Port: 9443 (HTTPS)

Metrics Endpoints:
  URL: http://kyverno-svc-metrics.kyverno.svc.cluster.local:8000/metrics

  Key Metrics:
    - kyverno_policy_rule_results_total: Policy evaluation results
    - kyverno_admission_requests_total: Total admission requests
    - kyverno_admission_review_duration_seconds: Request processing time
    - kyverno_policy_changes_total: Policy lifecycle tracking

Prometheus Integration:
  ServiceMonitor: k8s/kyverno/monitoring/prometheus-servicemonitor.yaml
  Scrape Interval: 30s
  Target: kyverno-svc-metrics.kyverno.svc.cluster.local:8000

Policy Reports:
  Access via kubectl:
    - kubectl get clusterpolicyreport -A
    - kubectl get policyreport -n app-demo
    - kubectl describe policyreport -n app-demo

Webhooks:
  Validating: kyverno-resource-validating-webhook-cfg
  Mutating: kyverno-resource-mutating-webhook-cfg
  Port: 9443
```

**Port Forward for Metrics** (optional):
```bash
# Check if port 8000 is available
lsof -i :8000

# If port 8000 is in use, use alternative port (recommended)
kubectl port-forward -n kyverno svc/kyverno-svc-metrics 8002:8000

# Test metrics endpoint
curl -s http://localhost:8002/metrics | head -20

# View Kyverno-specific metrics
curl -s http://localhost:8002/metrics | grep "^kyverno_"

# Check policy execution details
curl -s http://localhost:8002/metrics | grep -E "kyverno_(policy_|rule_)"

# Stop port-forward when done
pkill -f "port-forward.*kyverno-svc-metrics"
```

---

## Port Conflict Resolution

### Common Conflicts

| Port | Common Conflicts | Solution |
|------|-----------------|----------|
| 8080 | Jenkins, Application, Tomcat | Use different external ports (ArgoCD→8081) |
| 9000 | SonarQube, Other applications | Change SonarQube port |
| 8082 | Harbor, Other services | Modify Harbor configuration |
| 3000 | Node.js apps, Grafana, Dev servers | Use alternative port (3001) |
| 3100 | Loki, Other log collectors | Use NodePort 31000 mapping |
| 5432 | PostgreSQL databases | Use Docker networks |

### Checking Port Usage

The automated script (`k8s-permissions_port-forward.sh`) includes port conflict detection using `lsof`.

**macOS/Linux**:
```bash
# Check if port is in use
lsof -i :8080

# Check all listening ports
netstat -an | grep LISTEN

# Find process using specific port
lsof -ti:8080

# Check script-managed port forwards
./scripts/k8s-permissions_port-forward.sh status
```

**Kill process on port**:
```bash
# macOS/Linux
kill -9 $(lsof -ti:8080)

# Or using pkill
pkill -f "process-name"
```

---

## Docker Network Configuration

### Bridge Network

```yaml
Network: bridge (default)
Subnet: 172.17.0.0/16
Gateway: 172.17.0.1

Containers can communicate using:
  - Container names (DNS)
  - IP addresses
  - Exposed ports on host
```

### Kind Network

```yaml
Network: kind
Driver: bridge
Subnet: (dynamically assigned)

Container Communication:
  - All Kind nodes in same network
  - Can access host via host.docker.internal
```

---

## Firewall Configuration

### macOS

```bash
# Allow Docker
# No specific firewall rules needed for localhost

# If using remote access, add rules for:
# - Jenkins: 8080
# - Harbor: 8082, 8443
# - SonarQube: 9000
```

### Linux (UFW)

```bash
# Allow Jenkins
sudo ufw allow 8080/tcp

# Allow Harbor
sudo ufw allow 8082/tcp
sudo ufw allow 8443/tcp

# Allow SonarQube
sudo ufw allow 9000/tcp

# Allow Kubernetes API
sudo ufw allow 6443/tcp
```

---

## Service-to-Service Communication

### Internal Docker Network

```yaml
Jenkins -> Harbor:
  URL: http://harbor:80 or harbor:443
  Note: Use container name, not localhost

Jenkins -> SonarQube:
  URL: http://sonarqube:9000

Jenkins -> Kind:
  Use kubectl with kubeconfig
  API: https://kind-control-plane:6443
```

### Within Kubernetes

```yaml
Service Communication:
  Format: <service-name>.<namespace>.svc.cluster.local
  Example: myapp.default.svc.cluster.local

Pod to Service:
  Direct service name within same namespace
  Example: myapp:8080
```

---

## Health Check Endpoints

| Service | Health Check URL | Expected Response |
|---------|-----------------|-------------------|
| Jenkins | http://localhost:8080/login | 200 OK |
| Harbor | http://localhost:8082/api/v2.0/health | 200 OK |
| SonarQube | http://localhost:9000/api/system/health | 200 OK |
| Grafana | http://localhost:3000/api/health | 200 OK |
| Loki | http://localhost:31000/ready | ready |
| Prometheus | http://localhost:30090/-/ready | Prometheus is Ready. |
| Prometheus (Healthy) | http://localhost:30090/-/healthy | Prometheus is Healthy. |
| Application | http://localhost:8001/health | 200 OK |
| ArgoCD | http://localhost:8081/healthz | 200 OK |
| Kind API | kubectl get --raw='/healthz' | ok |

---

## Port Testing Commands

### Test Port Connectivity

```bash
# Using netcat
nc -zv localhost 8080

# Using telnet
telnet localhost 8080

# Using curl
curl -I http://localhost:8001

# Using kubectl (for K8s services)
kubectl port-forward svc/service-name 8080:80
```

### Check Service Status

```bash
# Docker containers
docker ps --format "table {{.Names}}\t{{.Ports}}\t{{.Status}}"

# Kubernetes services
kubectl get svc --all-namespaces

# Kind cluster ports
docker ps | grep kind
```

---

## Environment Variable Reference

```bash
# Jenkins
export JENKINS_PORT=8080
export JENKINS_URL=http://localhost:${JENKINS_PORT}

# Harbor
export HARBOR_HTTP_PORT=8082
export HARBOR_HTTPS_PORT=8443
export HARBOR_REGISTRY=localhost:${HARBOR_HTTP_PORT}

# SonarQube
export SONAR_PORT=9000
export SONAR_URL=http://localhost:${SONAR_PORT}

# Grafana & Monitoring
export GRAFANA_PORT=3000
export GRAFANA_URL=http://localhost:${GRAFANA_PORT}
export LOKI_NODEPORT=31000
export LOKI_URL=http://localhost:${LOKI_NODEPORT}
export PROMETHEUS_NODEPORT=30090
export PROMETHEUS_URL=http://localhost:${PROMETHEUS_NODEPORT}
export SONAR_HOST=http://localhost:${SONAR_PORT}

# Application
export APP_PORT=8001
export APP_URL=http://localhost:${APP_PORT}

# Kubernetes
export KUBE_API_PORT=6443
export KUBE_API=https://127.0.0.1:${KUBE_API_PORT}
```

---

## Quick Reference Commands

```bash
# List all ports in use
lsof -i -P -n | grep LISTEN

# Check Docker container ports
docker ps --format "{{.Names}}: {{.Ports}}"

# Check Kubernetes service ports
kubectl get svc -o wide --all-namespaces

# Check monitoring stack
kubectl get svc -n logging
kubectl get svc -n monitoring

# Port forward to Kubernetes services
kubectl port-forward -n logging svc/loki 3100:3100
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Test connectivity
curl -v http://localhost:8001/health
curl -v http://localhost:31000/ready
curl -v http://localhost:30090/-/ready

# View Kind cluster configuration
kind get clusters
kubectl cluster-info --context kind-kind

# Check all monitoring endpoints
echo "Grafana: $(curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/api/health)"
echo "Loki: $(curl -s http://localhost:31000/ready)"
echo "Prometheus: $(curl -s http://localhost:30090/-/ready | grep -o 'Ready')"
```

---

## Troubleshooting

### Port Already in Use

```bash
# 1. Identify the process
lsof -i :8080

# 2. Kill the process
kill -9 <PID>

# 3. Or change the service port
# Edit docker-compose.yml or service configuration
```

### Cannot Connect to Service

```bash
# 1. Verify service is running
docker ps | grep service-name

# 2. Check port binding
docker port <container-name>

# 3. Test from inside container
# Test from within container
docker exec -it <container> curl localhost:8001
```

# 4. Check firewall rules
sudo ufw status
```

### Kubernetes Service Not Accessible

```bash
# 1. Check service exists
kubectl get svc

# 2. Check endpoints
kubectl get endpoints service-name

# 3. Port forward to test
kubectl port-forward svc/service-name 8080:80

# 4. Check pod status
kubectl get pods
kubectl logs <pod-name>
```

---

## Security Considerations

1. **Localhost Only**: By default, all services bind to localhost for security
2. **Production**: Never expose these ports directly to the internet
3. **Credentials**: Use environment variables, not hardcoded passwords
4. **SSL/TLS**: Enable HTTPS for Harbor, ArgoCD in production environments
5. **Firewall**: Configure firewall rules for remote access scenarios

---

## See Also

- [Grafana & Loki Setup](Grafana-Loki.md) - Complete logging setup guide
- [Architecture Diagram](Architecture-Diagram.md) - Visual representation of service communication
- [Lab Setup Guide](#Lab-Setup-Guide.md) - Complete setup instructions
- [Troubleshooting Guide](Troubleshooting.md) - Common issues and solutions
- [Cleanup Guide](Cleanup-Guide.md) - How to tear down services
