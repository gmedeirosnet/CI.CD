# Scripts Documentation

This document describes the automation scripts available in the CI/CD lab project.

## Table of Contents

- [Port Forwarding & Docker Management](#port-forwarding--docker-management)
- [Setup Scripts](#setup-scripts)
- [Cleanup Scripts](#cleanup-scripts)
- [Utility Scripts](#utility-scripts)

---

## Port Forwarding & Docker Management

### k8s-permissions_port-forward.sh

**Location:** `scripts/k8s-permissions_port-forward.sh`

**Purpose:** Unified management of Kubernetes port forwards and Docker socket permissions for Jenkins.

**Features:**
- Automatic Docker socket permission fix for Jenkins container
- Manages port forwards for Loki, Prometheus, and ArgoCD
- PID-based process tracking for reliable start/stop operations
- Port conflict detection using `lsof`
- Status monitoring and orphaned process cleanup
- Color-coded terminal output for easy reading

**Managed Services:**

| Service | Namespace | Local Port | K8s Port | URL |
|---------|-----------|------------|----------|-----|
| Loki | logging | 31000 | 3100 | http://localhost:31000 |
| Prometheus | monitoring | 30090 | 9090 | http://localhost:30090 |
| ArgoCD | argocd | 8090 | 443 | https://localhost:8090 |

**Usage:**

```bash
# Start all port forwards (includes Docker permission fix)
./scripts/k8s-permissions_port-forward.sh start

# Check status of all port forwards
./scripts/k8s-permissions_port-forward.sh status

# Stop all port forwards
./scripts/k8s-permissions_port-forward.sh stop

# Restart all port forwards
./scripts/k8s-permissions_port-forward.sh restart

# Fix Docker permissions only (without starting port forwards)
./scripts/k8s-permissions_port-forward.sh fix-docker

# Cleanup orphaned processes
./scripts/k8s-permissions_port-forward.sh cleanup
```

**Example Output:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Kubernetes Port Forward Manager
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Docker permissions fixed for Jenkins container

Starting port forwards...

→ Starting loki (logging:loki:31000→3100)
  ✓ Started loki with PID 91001

→ Starting prometheus (monitoring:prometheus:30090→9090)
  ✓ Started prometheus with PID 91016

→ Starting argocd (argocd:argocd-server:8090→443)
  ✓ Started argocd with PID 91038

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Port Forward Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ loki (PID 91035) - logging:loki:31000→3100
✓ prometheus (PID 91036) - monitoring:prometheus:30090→9090
✓ argocd (PID 91038) - argocd:argocd-server:8090→443

Total: 3 active port forwards
```

**PID Management:**

The script stores process IDs in `/tmp/k8s-port-forward/`:
- `loki.pid`
- `prometheus.pid`
- `argocd.pid`

**Docker Permission Fix:**

The script automatically runs:
```bash
docker exec -u root jenkins chmod 666 /var/run/docker.sock
```

This fixes the common "permission denied while trying to connect to the Docker daemon socket" error in Jenkins.

**Requirements:**
- `kubectl` configured and connected to Kind cluster
- `docker` CLI available
- `lsof` for port conflict detection
- `zsh` shell (macOS default)
- Jenkins container named `jenkins`

**Troubleshooting:**

If port forwards fail to start:
1. Check if ports are already in use: `lsof -i :31000`
2. Verify Kubernetes services are running: `kubectl get svc -A`
3. Check kubectl connection: `kubectl cluster-info`
4. Review PID files in `/tmp/k8s-port-forward/`
5. Use cleanup command to remove stale processes

If Docker permission fix fails:
1. Verify Jenkins container is running: `docker ps | grep jenkins`
2. Check container name matches `jenkins`
3. Manually run: `docker exec -u root jenkins chmod 666 /var/run/docker.sock`

---

## Setup Scripts

### setup-all.sh

**Location:** `scripts/setup-all.sh`

**Purpose:** Complete automated setup of the entire CI/CD lab environment.

**What it does:**
1. Creates Kind Kubernetes cluster
2. Sets up Harbor container registry
3. Configures Jenkins with Docker support
4. Installs SonarQube
5. Deploys Grafana, Loki, and Prometheus
6. Sets up ArgoCD
7. Configures credentials and integrations

**Usage:**
```bash
./scripts/setup-all.sh
```

**Duration:** 10-15 minutes

**Requirements:**
- Docker Desktop running
- 16GB RAM minimum
- 50GB free disk space
- Internet connection

---

### setup-jenkins-docker.sh

**Location:** `scripts/setup-jenkins-docker.sh`

**Purpose:** Set up Jenkins in Docker with Docker-in-Docker capability.

**Features:**
- Creates Jenkins container with Docker socket mounted
- Automatically fixes Docker socket permissions on startup
- Configures persistent Jenkins home directory
- Sets up Jenkins network

**Usage:**
```bash
./scripts/setup-jenkins-docker.sh
```

**Custom Entrypoint:**

The script includes automatic Docker permission fixing:
```bash
--entrypoint /bin/bash -c "chmod 666 /var/run/docker.sock 2>/dev/null || true; exec /usr/bin/tini -- /usr/local/bin/jenkins.sh"
```

**Access:**
- URL: http://localhost:8080
- Initial admin password: Retrieved from container logs

---

### setup-argocd-repo.sh

**Location:** `scripts/setup-argocd-repo.sh`

**Purpose:** Configure ArgoCD to connect to your Git repository.

**Usage:**
```bash
./scripts/setup-argocd-repo.sh
```

---

### setup-sonarqube.sh

**Location:** `scripts/setup-sonarqube.sh`

**Purpose:** Install and configure SonarQube for code quality analysis.

**Usage:**
```bash
./scripts/setup-sonarqube.sh
```

**Access:**
- URL: http://localhost:8090
- Default credentials: admin/admin

---

## Cleanup Scripts

### cleanup-all.sh

**Location:** `scripts/cleanup-all.sh`

**Purpose:** Remove all lab components and clean up resources.

**What it removes:**
1. Kind Kubernetes cluster
2. Jenkins container
3. Harbor installation
4. SonarQube container
5. Grafana container
6. Docker volumes and networks
7. Local configuration files

**Usage:**
```bash
./scripts/cleanup-all.sh
```

**Warning:** This will delete all data and configurations!

---

## Utility Scripts

### verify-environment.sh

**Location:** `scripts/verify-environment.sh`

**Purpose:** Check if your system meets all prerequisites for the lab.

**Checks:**
- Docker installation and version
- Available RAM (16GB minimum)
- Available disk space (50GB minimum)
- kubectl installation
- Required tools (git, curl, etc.)

**Usage:**
```bash
./scripts/verify-environment.sh
```

---

### configure-kind-harbor-access.sh

**Location:** `scripts/configure-kind-harbor-access.sh`

**Purpose:** Configure Kind cluster nodes to access Harbor registry.

**Usage:**
```bash
./scripts/configure-kind-harbor-access.sh
```

---

### fix-kind-harbor-registry.sh

**Location:** `scripts/fix-kind-harbor-registry.sh`

**Purpose:** Fix registry connection issues between Kind and Harbor.

**Usage:**
```bash
./scripts/fix-kind-harbor-registry.sh
```

---

### load-harbor-image-to-kind.sh

**Location:** `scripts/load-harbor-image-to-kind.sh`

**Purpose:** Load Docker images from Harbor into Kind cluster.

**Usage:**
```bash
./scripts/load-harbor-image-to-kind.sh <image-name>
```

---

### create-harbor-robot.sh

**Location:** `scripts/create-harbor-robot.sh`

**Purpose:** Create a robot account in Harbor for automated access.

**Usage:**
```bash
./scripts/create-harbor-robot.sh
```

---

## Script Execution Order

For manual setup, run scripts in this order:

1. `verify-environment.sh` - Check prerequisites
2. `setup-jenkins-docker.sh` - Setup Jenkins
3. `configure-kind-harbor-access.sh` - Setup Harbor integration
4. `setup-sonarqube.sh` - Setup SonarQube
5. `k8s-permissions_port-forward.sh start` - Start port forwards
6. `setup-argocd-repo.sh` - Configure ArgoCD

Or simply run `setup-all.sh` to execute all steps automatically.

---

## Best Practices

1. **Always check status** before starting: `./scripts/k8s-permissions_port-forward.sh status`
2. **Use automated script** for port forwards instead of manual kubectl commands
3. **Verify environment** before setup: `./scripts/verify-environment.sh`
4. **Stop port forwards** when not needed to free resources: `./scripts/k8s-permissions_port-forward.sh stop`
5. **Regular cleanup** of orphaned processes: `./scripts/k8s-permissions_port-forward.sh cleanup`

---

## See Also

- [Port Reference](Port-Reference.md) - Complete port documentation
- [Troubleshooting](Troubleshooting.md) - Common issues and solutions
- [Quick Start Guide](../README.md#quick-start) - Getting started
- [Grafana & Loki Guide](Grafana-Loki.md) - Monitoring setup
- [ArgoCD Guide](ArgoCD.md) - GitOps deployment
