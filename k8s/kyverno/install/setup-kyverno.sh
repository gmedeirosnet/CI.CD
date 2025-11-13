#!/usr/bin/env bash
# setup-kyverno.sh
# Installs Kyverno policy engine on Kind cluster for CI/CD lab

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KYVERNO_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Kyverno Policy Engine Setup for Kind CI/CD Lab          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

################################################################################
# Step 1: Prerequisites Check
################################################################################

echo -e "${YELLOW}Step 1: Checking prerequisites...${NC}"

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo -e "${RED}✗ Helm is not installed${NC}"
    echo "Please install Helm: brew install helm"
    exit 1
fi
echo -e "${GREEN}✓ Helm is available${NC}"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl is not installed${NC}"
    echo "Please install kubectl: brew install kubectl"
    exit 1
fi
echo -e "${GREEN}✓ kubectl is available${NC}"

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}✗ Cannot connect to Kubernetes cluster${NC}"
    echo "Please ensure your Kind cluster is running"
    exit 1
fi
echo -e "${GREEN}✓ Kubernetes cluster is accessible${NC}"
echo ""

################################################################################
# Step 2: Add Kyverno Helm Repository
################################################################################

echo -e "${YELLOW}Step 2: Adding Kyverno Helm repository...${NC}"

if helm repo list | grep -q "^kyverno"; then
    echo -e "${YELLOW}⚠ Kyverno repository already exists, updating...${NC}"
    helm repo update kyverno
else
    helm repo add kyverno https://kyverno.github.io/kyverno/
    echo -e "${GREEN}✓ Kyverno repository added${NC}"
fi

helm repo update
echo -e "${GREEN}✓ Helm repositories updated${NC}"
echo ""

################################################################################
# Step 3: Create Kyverno Namespace
################################################################################

echo -e "${YELLOW}Step 3: Creating kyverno namespace...${NC}"

if kubectl get namespace kyverno &> /dev/null; then
    echo -e "${YELLOW}⚠ Namespace 'kyverno' already exists${NC}"
else
    kubectl create namespace kyverno
    kubectl label namespace kyverno pod-security.kubernetes.io/enforce=privileged
    echo -e "${GREEN}✓ Namespace 'kyverno' created${NC}"
fi
echo ""

################################################################################
# Step 4: Install Kyverno via Helm
################################################################################

echo -e "${YELLOW}Step 4: Installing Kyverno...${NC}"

if helm list -n kyverno | grep -q "^kyverno"; then
    echo -e "${YELLOW}⚠ Kyverno is already installed${NC}"
    read -p "Do you want to upgrade it? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        helm upgrade kyverno kyverno/kyverno \
            --namespace kyverno \
            --values "$SCRIPT_DIR/kyverno-values.yaml" \
            --wait
        echo -e "${GREEN}✓ Kyverno upgraded${NC}"
    fi
else
    helm install kyverno kyverno/kyverno \
        --namespace kyverno \
        --values "$SCRIPT_DIR/kyverno-values.yaml" \
        --wait \
        --timeout 5m
    echo -e "${GREEN}✓ Kyverno installed${NC}"
fi
echo ""

################################################################################
# Step 5: Wait for Kyverno to be Ready
################################################################################

echo -e "${YELLOW}Step 5: Waiting for Kyverno pods to be ready...${NC}"

kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=kyverno \
    -n kyverno \
    --timeout=300s

echo -e "${GREEN}✓ Kyverno is ready${NC}"
echo ""

################################################################################
# Step 6: Verify Installation
################################################################################

echo -e "${YELLOW}Step 6: Verifying installation...${NC}"

# Check pods
echo "Kyverno pods:"
kubectl get pods -n kyverno

echo ""
echo "Kyverno services:"
kubectl get svc -n kyverno

echo ""
echo "Kyverno webhooks:"
kubectl get validatingwebhookconfigurations | grep kyverno || echo "No validating webhooks found"
kubectl get mutatingwebhookconfigurations | grep kyverno || echo "No mutating webhooks found"

echo ""
echo -e "${GREEN}✓ Kyverno installation verified${NC}"
echo ""

################################################################################
# Summary
################################################################################

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Kyverno Policy Engine Installation Complete!${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Deploy policies:"
echo "     kubectl apply -f $KYVERNO_DIR/policies/"
echo ""
echo "  2. View policy reports:"
echo "     kubectl get clusterpolicyreport -A"
echo "     kubectl get policyreport -n app-demo"
echo ""
echo "  3. Check Kyverno logs:"
echo "     kubectl logs -n kyverno -l app.kubernetes.io/name=kyverno -f"
echo ""
echo "  4. View metrics (for Prometheus):"
echo "     kubectl port-forward -n kyverno svc/kyverno-svc-metrics 8000:8000"
echo "     curl http://localhost:8000/metrics"
echo ""

echo -e "${BLUE}Useful Commands:${NC}"
echo "  # List all policies"
echo "  kubectl get clusterpolicies"
echo "  kubectl get policies -A"
echo ""
echo "  # View policy details"
echo "  kubectl describe clusterpolicy <policy-name>"
echo ""
echo "  # Test with dry-run"
echo "  kubectl apply -f test-pod.yaml --dry-run=server"
echo ""

echo -e "${BLUE}Documentation:${NC}"
echo "  README: $KYVERNO_DIR/README.md"
echo "  Policies: $KYVERNO_DIR/policies/"
echo "  Tests: $KYVERNO_DIR/tests/"
echo ""

echo -e "${YELLOW}Note: All policies are deployed in AUDIT mode by default.${NC}"
echo -e "${YELLOW}Monitor violations for 2-3 days before switching to ENFORCE mode.${NC}"
echo ""
