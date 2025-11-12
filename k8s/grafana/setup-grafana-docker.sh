#!/bin/bash

# Grafana Docker Compose Setup Script
# This script exposes Loki from Kind cluster and starts Grafana on Docker Desktop

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Grafana Docker Desktop Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Check prerequisites
echo -e "${YELLOW}Step 1: Checking prerequisites...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker is available${NC}"

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}✗ Docker Compose not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker Compose is available${NC}"

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ kubectl is available${NC}"

if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}✗ Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Kubernetes cluster is accessible${NC}"

echo ""

# Step 2: Check if Loki is running
echo -e "${YELLOW}Step 2: Checking Loki installation...${NC}"

if ! kubectl get svc loki -n logging &> /dev/null; then
    echo -e "${RED}✗ Loki not found in 'logging' namespace${NC}"
    echo ""
    echo "Please install Loki first:"
    echo "  cd $SCRIPT_DIR"
    echo "  ./setup-loki.sh"
    exit 1
fi
echo -e "${GREEN}✓ Loki is running in Kind cluster${NC}"

echo ""

# Step 3: Check if Prometheus is running (optional)
echo -e "${YELLOW}Step 3: Checking Prometheus installation (optional)...${NC}"

PROMETHEUS_ENABLED=false
PROMETHEUS_URL=""

if kubectl get svc prometheus -n monitoring &> /dev/null; then
    echo -e "${GREEN}✓ Prometheus is running in Kind cluster${NC}"
    PROMETHEUS_ENABLED=true

    PROM_TYPE=$(kubectl get svc prometheus -n monitoring -o jsonpath='{.spec.type}')
    if [ "$PROM_TYPE" = "NodePort" ]; then
        PROM_NODEPORT=$(kubectl get svc prometheus -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')
        echo -e "${GREEN}✓ Prometheus exposed on NodePort $PROM_NODEPORT${NC}"
        PROMETHEUS_URL="http://host.docker.internal:$PROM_NODEPORT"
    fi
else
    echo -e "${YELLOW}⚠ Prometheus not found (optional)${NC}"
    echo "To install Prometheus, run: ./setup-prometheus.sh"
fi

echo ""

# Step 4: Get Loki service type
echo -e "${YELLOW}Step 4: Configuring Loki access...${NC}"

LOKI_TYPE=$(kubectl get svc loki -n logging -o jsonpath='{.spec.type}')
echo "Current Loki service type: $LOKI_TYPE"

if [ "$LOKI_TYPE" = "ClusterIP" ]; then
    echo -e "${YELLOW}⚠ Loki is ClusterIP - needs to be accessible from Docker Desktop${NC}"
    echo ""
    echo "Choose access method:"
    echo "  1) Patch Loki service to NodePort (Recommended)"
    echo "  2) Use Kind network bridge (Advanced)"
    read -p "Enter choice [1-2]: " ACCESS_CHOICE

    case $ACCESS_CHOICE in
        1)
            echo ""
            echo "Patching Loki service to NodePort..."
            kubectl patch svc loki -n logging -p '{"spec":{"type":"NodePort","ports":[{"port":3100,"nodePort":31000,"name":"http-metrics"}]}}'
            echo -e "${GREEN}✓ Loki exposed on NodePort 31000${NC}"
            LOKI_URL="http://host.docker.internal:31000"
            ;;
        2)
            echo ""
            echo "Using Kind network bridge..."
            CONTROL_PLANE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
            echo "Control plane IP: $CONTROL_PLANE_IP"
            LOKI_URL="http://app-demo-control-plane:3100"
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac
else
    NODEPORT=$(kubectl get svc loki -n logging -o jsonpath='{.spec.ports[0].nodePort}')
    echo -e "${GREEN}✓ Loki already exposed on NodePort $NODEPORT${NC}"
    LOKI_URL="http://host.docker.internal:$NODEPORT"
fi

echo ""

# Step 5: Update datasource configuration
echo -e "${YELLOW}Step 5: Configuring Grafana datasources...${NC}"

cat > "$SCRIPT_DIR/provisioning/datasources/loki.yml" <<EOF
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy
    url: $LOKI_URL
    isDefault: true
    editable: true
    jsonData:
      maxLines: 1000
      timeout: 60
EOF

echo -e "${GREEN}✓ Loki datasource configured: $LOKI_URL${NC}"

# Configure Prometheus datasource if enabled
if [ "$PROMETHEUS_ENABLED" = true ]; then
    cat > "$SCRIPT_DIR/provisioning/datasources/prometheus.yml" <<EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: $PROMETHEUS_URL
    isDefault: false
    editable: true
    jsonData:
      timeInterval: 15s
      queryTimeout: 60s
      httpMethod: POST
EOF

    echo -e "${GREEN}✓ Prometheus datasource configured: $PROMETHEUS_URL${NC}"
fi

echo ""

# Step 6: Stop existing Grafana container if running
echo -e "${YELLOW}Step 6: Checking for existing Grafana container...${NC}"

if docker ps -a --format '{{.Names}}' | grep -q "^grafana-desktop$"; then
    echo "Stopping and removing existing Grafana container..."
    docker-compose -f "$SCRIPT_DIR/docker-compose.yml" down
    echo -e "${GREEN}✓ Existing container removed${NC}"
else
    echo -e "${GREEN}✓ No existing container found${NC}"
fi

echo ""

# Step 7: Start Grafana with Docker Compose
echo -e "${YELLOW}Step 7: Starting Grafana...${NC}"

cd "$SCRIPT_DIR"
docker-compose up -d

echo -e "${GREEN}✓ Grafana started${NC}"

echo ""

# Step 8: Wait for Grafana to be ready
echo -e "${YELLOW}Step 8: Waiting for Grafana to be ready...${NC}"
echo "This may take 30 seconds..."

RETRY_COUNT=0
MAX_RETRIES=30

until docker exec grafana-desktop wget --spider -q http://localhost:3000/api/health 2>/dev/null; do
    sleep 2
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo -e "${RED}✗ Timeout waiting for Grafana to start${NC}"
        echo "Check logs: docker logs grafana-desktop"
        exit 1
    fi
    echo -n "."
done

echo ""
echo -e "${GREEN}✓ Grafana is ready${NC}"

echo ""

# Step 9: Verify Loki connection
echo -e "${YELLOW}Step 9: Verifying connections...${NC}"

echo "Testing Loki connection..."

if [ "$LOKI_URL" = "http://app-demo-control-plane:3100" ]; then
    echo "Testing connection to Loki via Kind network..."
    if docker exec grafana-desktop wget -qO- http://app-demo-control-plane:3100/ready 2>/dev/null | grep -q "ready"; then
        echo -e "${GREEN}✓ Grafana can reach Loki${NC}"
    else
        echo -e "${YELLOW}⚠ Cannot verify Loki connection${NC}"
        echo "This is normal - test in Grafana UI"
    fi
else
    echo "Testing connection to Loki via NodePort..."
    if curl -sf http://localhost:31000/ready &>/dev/null; then
        echo -e "${GREEN}✓ Loki is accessible${NC}"
    else
        echo -e "${YELLOW}⚠ Cannot verify Loki connection${NC}"
    fi
fi

# Test Prometheus connection if enabled
if [ "$PROMETHEUS_ENABLED" = true ]; then
    echo "Testing Prometheus connection..."
    if curl -sf http://localhost:$PROM_NODEPORT/-/ready &>/dev/null; then
        echo -e "${GREEN}✓ Prometheus is accessible${NC}"
    else
        echo -e "${YELLOW}⚠ Cannot verify Prometheus connection${NC}"
    fi
fi

echo ""

# Step 10: Display summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Grafana Information:${NC}"
echo "  Container: grafana-desktop"
echo "  URL: http://localhost:3000"
echo "  Username: admin"
echo "  Password: admin"
echo ""

echo -e "${BLUE}Configured Datasources:${NC}"
echo "  ✓ Loki: $LOKI_URL"
if [ "$PROMETHEUS_ENABLED" = true ]; then
    echo "  ✓ Prometheus: $PROMETHEUS_URL"
else
    echo "  ⚠ Prometheus: Not configured (run ./setup-prometheus.sh to install)"
fi
echo ""

echo -e "${BLUE}Loki Connection:${NC}"
echo "  URL: $LOKI_URL"
echo "  Namespace: logging (Kind K8s)"
echo "  Pre-configured: Yes"
echo ""

echo -e "${BLUE}Quick Commands:${NC}"
echo "  # View Grafana logs"
echo "  docker logs -f grafana-desktop"
echo ""
echo "  # Restart Grafana"
echo "  cd $SCRIPT_DIR && docker-compose restart"
echo ""
echo "  # Stop Grafana"
echo "  cd $SCRIPT_DIR && docker-compose down"
echo ""
echo "  # Check Loki in Kind"
echo "  kubectl get pods -n logging"
echo ""

echo -e "${BLUE}Using Grafana:${NC}"
echo "  1. Open http://localhost:3000 in your browser"
echo "  2. Login with admin/admin"
echo "  3. Go to 'Explore' from the left menu"
echo "  4. Loki is already configured as default datasource"
echo "  5. Use LogQL queries to explore logs:"
echo ""
echo "     # All logs from default namespace"
echo "     {namespace=\"default\"}"
echo ""
echo "     # Logs from specific app"
echo "     {namespace=\"default\", app=\"cicd-demo\"}"
echo ""
echo "     # Search for errors"
echo "     {namespace=\"default\"} |= \"error\""
echo ""
echo "     # Last 5 minutes"
echo "     {namespace=\"default\"} | json | __error__=\"\" [5m]"
echo ""

echo -e "${BLUE}Troubleshooting:${NC}"
echo "  # If datasource shows error:"
echo "  1. Check if Loki is running:"
echo "     kubectl get pods -n logging"
echo ""
echo "  2. Test Loki endpoint:"
if [ "$LOKI_URL" = "http://app-demo-control-plane:3100" ]; then
    echo "     docker exec grafana-desktop wget -qO- http://app-demo-control-plane:3100/ready"
else
    echo "     curl http://localhost:31000/ready"
fi
echo ""
echo "  3. View Grafana logs:"
echo "     docker logs grafana-desktop"
echo ""

echo -e "${GREEN}✓ Grafana is ready to explore logs from Kind cluster!${NC}"
echo ""
