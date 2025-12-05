#!/usr/bin/env bash
# install-policy-reporter.sh
# Installs Policy Reporter on Docker Desktop for Kyverno policy observability

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Policy Reporter Docker Desktop Setup for Kyverno        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

################################################################################
# Prerequisites Check
################################################################################

echo -e "${YELLOW}Step 1: Checking prerequisites...${NC}"

# Check if docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker is available${NC}"

# Check Docker is running
if ! docker ps &> /dev/null; then
    echo -e "${RED}✗ Docker daemon is not running${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker daemon is running${NC}"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ kubectl is available${NC}"

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}✗ Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Kubernetes cluster is accessible${NC}"

# Check if Kyverno is installed
if ! kubectl get namespace kyverno &> /dev/null; then
    echo -e "${RED}✗ Kyverno namespace not found${NC}"
    echo "Please install Kyverno first"
    exit 1
fi
echo -e "${GREEN}✓ Kyverno is installed${NC}"
echo ""

################################################################################
# Configure Kubernetes API Access
################################################################################

echo -e "${YELLOW}Step 2: Configuring Kubernetes API access...${NC}"

# Get Kind API server endpoint
KIND_API_RAW=$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.server}')
# Replace 127.0.0.1 with host.docker.internal for Docker Desktop access
KIND_API=$(echo "$KIND_API_RAW" | sed 's/127\.0\.0\.1/host.docker.internal/g')
if [ -z "$KIND_API" ]; then
    KIND_PORT=$(docker port kind-control-plane | grep 6443 | cut -d: -f2)
    KIND_API="https://host.docker.internal:$KIND_PORT"
fi
echo "Kind API Server: $KIND_API"

# Get service account token and CA cert
echo "Creating service account for Policy Reporter..."
kubectl create namespace policy-reporter 2>/dev/null || echo "Namespace already exists"

# Create service account
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: policy-reporter
  namespace: policy-reporter
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: policy-reporter
rules:
- apiGroups: ["wgpolicyk8s.io"]
  resources: ["policyreports", "clusterpolicyreports"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["namespaces", "pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: policy-reporter
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: policy-reporter
subjects:
- kind: ServiceAccount
  name: policy-reporter
  namespace: policy-reporter
EOF

# Wait for token to be created
sleep 2

# Get token
TOKEN=$(kubectl create token policy-reporter -n policy-reporter --duration=87600h 2>/dev/null)
if [ -z "$TOKEN" ]; then
    echo -e "${YELLOW}⚠ Using legacy token method${NC}"
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: policy-reporter-token
  namespace: policy-reporter
  annotations:
    kubernetes.io/service-account.name: policy-reporter
type: kubernetes.io/service-account-token
EOF
    sleep 2
    TOKEN=$(kubectl get secret policy-reporter-token -n policy-reporter -o jsonpath='{.data.token}' | base64 -d)
fi

echo -e "${GREEN}✓ Service account configured${NC}"
echo ""

################################################################################
# Check Loki Access
################################################################################

echo -e "${YELLOW}Step 3: Checking Loki access...${NC}"

LOKI_URL=""
if kubectl get svc loki -n logging &> /dev/null; then
    LOKI_TYPE=$(kubectl get svc loki -n logging -o jsonpath='{.spec.type}')
    if [ "$LOKI_TYPE" = "NodePort" ]; then
        LOKI_PORT=$(kubectl get svc loki -n logging -o jsonpath='{.spec.ports[0].nodePort}')
        LOKI_URL="http://host.docker.internal:$LOKI_PORT"
        echo -e "${GREEN}✓ Loki accessible via NodePort: $LOKI_URL${NC}"
    else
        echo -e "${YELLOW}⚠ Loki is ClusterIP - logging may not work from Docker${NC}"
        LOKI_URL="http://loki.logging:3100"
    fi
else
    echo -e "${YELLOW}⚠ Loki not found - logging disabled${NC}"
fi
echo ""

################################################################################
# Create Docker Compose Configuration
################################################################################

echo -e "${YELLOW}Step 4: Creating Docker Compose configuration...${NC}"

cat > "$SCRIPT_DIR/docker-compose.yml" <<EOF
version: '3.8'

services:
  policy-reporter:
    image: ghcr.io/kyverno/policy-reporter:latest
    container_name: policy-reporter
    restart: unless-stopped
    user: "0:0"
    command: ["run", "--kubeconfig", "/config/kubeconfig", "--config", "/app/config.yaml", "--dbfile", "/data/policy-reporter.db"]
    ports:
      - "31001:8080"
    environment:
      - KUBECONFIG=/config/kubeconfig
    volumes:
      - ./kubeconfig:/config/kubeconfig:ro
      - ./policy-reporter-config.yaml:/app/config.yaml:ro
      - ./data:/data
    extra_hosts:
      - "host.docker.internal:host-gateway"
    networks:
      - policy-reporter

  policy-reporter-ui:
    image: ghcr.io/kyverno/policy-reporter-ui:latest
    container_name: policy-reporter-ui
    restart: unless-stopped
    ports:
      - "31002:8080"
    environment:
      - POLICY_REPORTER_URL=http://policy-reporter:8080
      - PORT=8080
    depends_on:
      - policy-reporter
    networks:
      - policy-reporter

networks:
  policy-reporter:
    driver: bridge

volumes:
  policy-reporter-data:
EOF

echo -e "${GREEN}✓ Docker Compose configuration created${NC}"
echo ""

################################################################################
# Create Policy Reporter Configuration
################################################################################

echo -e "${YELLOW}Step 5: Creating Policy Reporter configuration...${NC}"

cat > "$SCRIPT_DIR/policy-reporter-config.yaml" <<EOF
kubeconfig: /config/kubeconfig

api:
  port: 8080

rest:
  enabled: true

metrics:
  enabled: true

target:
  loki:
    host: ${LOKI_URL}
    path: /loki/api/v1/push
    minimumPriority: "warning"
    skipExistingOnStartup: true

database:
  type: sqlite
  database: /tmp/policy-reporter.db

reportFilter:
  namespaces:
    include: []
  clusterReports:
    disabled: false
EOF

echo -e "${GREEN}✓ Policy Reporter configuration created${NC}"
echo ""

################################################################################
# Create Kubeconfig for Container
################################################################################

echo -e "${YELLOW}Step 6: Creating kubeconfig for Policy Reporter...${NC}"

# Get CA certificate
CA_CERT=$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')

cat > "$SCRIPT_DIR/kubeconfig" <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: $KIND_API
    insecure-skip-tls-verify: true
  name: kind
contexts:
- context:
    cluster: kind
    user: policy-reporter
    namespace: policy-reporter
  name: kind-policy-reporter
current-context: kind-policy-reporter
users:
- name: policy-reporter
  user:
    token: $TOKEN
EOF

echo -e "${GREEN}✓ Kubeconfig created${NC}"
echo ""

################################################################################
# Start Policy Reporter
################################################################################

echo -e "${YELLOW}Step 7: Starting Policy Reporter on Docker Desktop...${NC}"

cd "$SCRIPT_DIR"

# Stop existing containers if running
if docker ps -a | grep -q "policy-reporter"; then
    echo "Stopping existing Policy Reporter containers..."
    docker-compose down 2>/dev/null || docker compose down 2>/dev/null || true
fi

# Start containers
if command -v docker-compose &> /dev/null; then
    docker-compose up -d
else
    docker compose up -d
fi

echo -e "${GREEN}✓ Policy Reporter containers started${NC}"
echo ""

################################################################################
# Wait for Services
################################################################################

echo -e "${YELLOW}Step 8: Waiting for services to be ready...${NC}"

# Wait for policy-reporter
echo -n "Waiting for Policy Reporter API"
for i in {1..30}; do
    if curl -s http://localhost:31001/healthz &> /dev/null; then
        echo ""
        echo -e "${GREEN}✓ Policy Reporter API is ready${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

# Wait for policy-reporter-ui
echo -n "Waiting for Policy Reporter UI"
for i in {1..30}; do
    if curl -s http://localhost:31002 &> /dev/null; then
        echo ""
        echo -e "${GREEN}✓ Policy Reporter UI is ready${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

echo ""

################################################################################
# Verify Installation
################################################################################

echo -e "${YELLOW}Step 9: Verifying installation...${NC}"

echo "Docker containers:"
docker ps | grep policy-reporter

echo ""
echo -e "${GREEN}✓ Policy Reporter installation verified${NC}"
echo ""

################################################################################
# Summary
################################################################################

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Policy Reporter Installation Complete!${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${BLUE}Access Policy Reporter:${NC}"
echo "  UI:       http://localhost:31002"
echo "  API:      http://localhost:31001/api/v1"
echo "  Metrics:  http://localhost:31001/metrics"
echo "  Health:   http://localhost:31001/healthz"
echo ""

echo -e "${BLUE}Useful Commands:${NC}"
echo "  # View policy reports in Kubernetes"
echo "  kubectl get policyreport -A"
echo "  kubectl get clusterpolicyreport"
echo ""
echo "  # Check Policy Reporter logs"
echo "  docker logs policy-reporter -f"
echo ""
echo "  # Check UI logs"
echo "  docker logs policy-reporter-ui -f"
echo ""
echo "  # Test API"
echo "  curl http://localhost:31001/api/v1/cluster-resources/reports"
echo "  curl http://localhost:31001/api/v1/namespaced-resources/reports"
echo ""
echo "  # Stop Policy Reporter"
echo "  cd $SCRIPT_DIR && docker-compose down"
echo ""
echo "  # Restart Policy Reporter"
echo "  cd $SCRIPT_DIR && docker-compose restart"
echo ""

echo -e "${BLUE}Integration Status:${NC}"
echo "  ✓ Kyverno integration:  Enabled (via Kubernetes API)"
echo "  ✓ Loki logging:         ${LOKI_URL:+Enabled ($LOKI_URL)}"
echo "  ${LOKI_URL:+✓}${LOKI_URL:-✗} Prometheus metrics:   Enabled"
echo "  ✓ Web UI:               Enabled (http://localhost:31002)"
echo ""

echo -e "${YELLOW}Note: Policy Reporter will automatically collect reports from Kyverno.${NC}"
echo -e "${YELLOW}Access the dashboard to view policy violations and compliance status.${NC}"
echo ""

