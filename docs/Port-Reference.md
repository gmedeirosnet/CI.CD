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
| **Promtail** | 9080 | - | HTTP | - | Log collector metrics |
| **Application** | 8080 | 8080 | HTTP | http://localhost:8080 | Demo Spring Boot app |
| **ArgoCD UI** | 8080 | 8080 | HTTP | http://localhost:8080 | GitOps deployment UI |
| **ArgoCD API** | 8080 | 8080 | HTTPS | https://localhost:8080 | GitOps deployment API |
| **Kind API Server** | 6443 | 6443 | HTTPS | https://127.0.0.1:6443 | Kubernetes API |
| **Kind Dashboard** | - | 30000-32767 | HTTP | http://localhost:30xxx | K8s NodePort services |

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

### Grafana & Loki

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

Connection:
  Grafana -> Loki: http://host.docker.internal:31000
  Or via Kind network: http://app-demo-control-plane:3100
```

**Port Forward Commands**:
```bash
# Loki (from K8s to host)
kubectl port-forward -n logging svc/loki 3100:3100

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
  External: 8080
  Internal: 8080
  Protocol: HTTP

Health Endpoint:
  URL: http://localhost:8080/health

API Endpoints:
  Base URL: http://localhost:8080

Kubernetes Service:
  Type: LoadBalancer or NodePort
  Port: 80 -> 8080
  TargetPort: 8080
```

---

### ArgoCD

```yaml
Server Port:
  External: 8080 (HTTP redirect)
  External: 8443 (HTTPS)
  Internal: 8080

API Server:
  URL: localhost:8080
  gRPC Port: 8080

Repo Server:
  Internal Port: 8081

Redis:
  Internal Port: 6379

Metrics:
  Internal Port: 8082
```

**Port Forward Command**:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

---

## Port Conflict Resolution

### Common Conflicts

| Port | Common Conflicts | Solution |
|------|-----------------|----------|
| 8080 | Jenkins, Application, ArgoCD, Tomcat | Use different external ports |
| 9000 | SonarQube, Other applications | Change SonarQube port |
| 8082 | Harbor, Other services | Modify Harbor configuration |
| 3000 | Node.js apps, Grafana, Dev servers | Use alternative port (3001) |
| 3100 | Loki, Other log collectors | Change NodePort mapping |
| 5432 | PostgreSQL databases | Use Docker networks |

### Checking Port Usage

**macOS/Linux**:
```bash
# Check if port is in use
lsof -i :8080

# Check all listening ports
netstat -an | grep LISTEN

# Find process using specific port
lsof -ti:8080
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
| Application | http://localhost:8080/health | 200 OK |
| ArgoCD | http://localhost:8080/healthz | 200 OK |
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
curl -I http://localhost:8080

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
export SONAR_HOST=http://localhost:${SONAR_PORT}

# Grafana & Loki
export GRAFANA_PORT=3000
export GRAFANA_URL=http://localhost:${GRAFANA_PORT}
export LOKI_PORT=31000
export LOKI_URL=http://localhost:${LOKI_PORT}

# Application
export APP_PORT=8080
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
kubectl get svc -o wide

# Port forward to Kubernetes service
kubectl port-forward svc/myapp 8080:80

# Test connectivity
curl -v http://localhost:8080/health

# View Kind cluster configuration
kind get clusters
kubectl cluster-info --context kind-kind
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
docker exec -it <container> curl localhost:8080

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
