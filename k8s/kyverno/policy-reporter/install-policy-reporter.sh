#!/usr/bin/env bash
# install-policy-reporter.sh
# Installs Policy Reporter for Kyverno policy observability

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Policy Reporter Installation for Kyverno                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

################################################################################
# Prerequisites Check
################################################################################

echo -e "${YELLOW}Step 1: Checking prerequisites...${NC}"

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo -e "${RED}✗ Helm is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Helm is available${NC}"

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
# Add Policy Reporter Helm Repository
################################################################################

echo -e "${YELLOW}Step 2: Adding Policy Reporter Helm repository...${NC}"

if helm repo list | grep -q "^policy-reporter"; then
    echo -e "${YELLOW}⚠ Policy Reporter repository already exists, updating...${NC}"
    helm repo update policy-reporter
else
    helm repo add policy-reporter https://kyverno.github.io/policy-reporter
    echo -e "${GREEN}✓ Policy Reporter repository added${NC}"
fi

helm repo update
echo -e "${GREEN}✓ Helm repositories updated${NC}"
echo ""

################################################################################
# Create Namespace
################################################################################

echo -e "${YELLOW}Step 3: Creating policy-reporter namespace...${NC}"

if kubectl get namespace policy-reporter &> /dev/null; then
    echo -e "${YELLOW}⚠ Namespace 'policy-reporter' already exists${NC}"
else
    kubectl create namespace policy-reporter
    echo -e "${GREEN}✓ Namespace 'policy-reporter' created${NC}"
fi
echo ""

################################################################################
# Install Policy Reporter
################################################################################

echo -e "${YELLOW}Step 4: Installing Policy Reporter...${NC}"

if helm list -n policy-reporter | grep -q "^policy-reporter"; then
    echo -e "${YELLOW}⚠ Policy Reporter is already installed${NC}"
    read -p "Do you want to upgrade it? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        helm upgrade policy-reporter policy-reporter/policy-reporter \
            --namespace policy-reporter \
            --values "$SCRIPT_DIR/policy-reporter-values.yaml" \
            --wait \
            --timeout 5m
        echo -e "${GREEN}✓ Policy Reporter upgraded${NC}"
    fi
else
    helm install policy-reporter policy-reporter/policy-reporter \
        --namespace policy-reporter \
        --values "$SCRIPT_DIR/policy-reporter-values.yaml" \
        --wait \
        --timeout 5m
    echo -e "${GREEN}✓ Policy Reporter installed${NC}"
fi
echo ""

################################################################################
# Wait for Deployment
################################################################################

echo -e "${YELLOW}Step 5: Waiting for Policy Reporter to be ready...${NC}"

kubectl wait --for=condition=available \
    deployment/policy-reporter \
    -n policy-reporter \
    --timeout=300s

echo -e "${GREEN}✓ Policy Reporter is ready${NC}"
echo ""

################################################################################
# Verify Installation
################################################################################

echo -e "${YELLOW}Step 6: Verifying installation...${NC}"

echo "Policy Reporter pods:"
kubectl get pods -n policy-reporter

echo ""
echo "Policy Reporter services:"
kubectl get svc -n policy-reporter

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
echo "  UI (via NodePort):    http://localhost:31001"
echo "  API:                  http://localhost:31001/api/v1"
echo "  Metrics:              http://localhost:31001/metrics"
echo ""

echo -e "${BLUE}Port Forward (alternative):${NC}"
echo "  kubectl port-forward -n policy-reporter svc/policy-reporter-ui 8080:8080"
echo "  Then open: http://localhost:8080"
echo ""

echo -e "${BLUE}Useful Commands:${NC}"
echo "  # View policy reports"
echo "  kubectl get policyreport -A"
echo "  kubectl get clusterpolicyreport"
echo ""
echo "  # Check Policy Reporter logs"
echo "  kubectl logs -n policy-reporter -l app.kubernetes.io/name=policy-reporter -f"
echo ""
echo "  # View UI logs"
echo "  kubectl logs -n policy-reporter -l app.kubernetes.io/name=ui -f"
echo ""
echo "  # Test API"
echo "  curl http://localhost:31001/api/v1/namespaced-resources/reports"
echo ""

echo -e "${BLUE}Integration Status:${NC}"
echo "  ✓ Kyverno integration:  Enabled (auto-detected)"
echo "  ✓ Loki logging:         Enabled (http://loki.logging:3100)"
echo "  ✓ Prometheus metrics:   Enabled"
echo "  ✓ Web UI:               Enabled (NodePort 31001)"
echo ""

echo -e "${YELLOW}Note: Policy Reporter will automatically collect reports from Kyverno.${NC}"
echo -e "${YELLOW}Violations are sent to Loki and visible in the UI dashboard.${NC}"
echo ""
