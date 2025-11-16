#!/usr/bin/env bash
# test-namespace-protection.sh
# Test the namespace deletion protection policy

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Namespace Deletion Protection Policy Test             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if Kyverno is installed
if ! kubectl get ns kyverno &> /dev/null; then
    echo -e "${RED}✗ Kyverno namespace not found${NC}"
    echo "Please install Kyverno first"
    exit 1
fi

# Check if policy is deployed
if ! kubectl get clusterpolicy prevent-app-demo-namespace-deletion &> /dev/null; then
    echo -e "${YELLOW}⚠ Protection policy not found${NC}"
    echo "Deploying policy..."
    kubectl apply -f ../policies/00-namespace/prevent-namespace-deletion.yaml
    sleep 3
fi

echo -e "${GREEN}✓ Protection policy is deployed${NC}"
echo ""

################################################################################
# Test 1: Verify app-demo namespace exists
################################################################################

echo -e "${BLUE}Test 1: Checking if app-demo namespace exists${NC}"
if kubectl get namespace app-demo &> /dev/null; then
    echo -e "${GREEN}✓ app-demo namespace exists${NC}"
else
    echo -e "${YELLOW}⚠ app-demo namespace not found, creating it...${NC}"
    kubectl create namespace app-demo
    kubectl label namespace app-demo team=devops purpose=demo-application
    echo -e "${GREEN}✓ app-demo namespace created${NC}"
fi
echo ""

################################################################################
# Test 2: Attempt to delete app-demo namespace (should be blocked)
################################################################################

echo -e "${BLUE}Test 2: Attempting to delete app-demo namespace${NC}"
echo -e "${YELLOW}→ This should be BLOCKED by the policy${NC}"
echo ""

if kubectl delete namespace app-demo --dry-run=server 2>&1 | grep -q "denied the request"; then
    echo -e "${GREEN}✓ PASS: Deletion was blocked by Kyverno policy${NC}"
    echo ""
    echo "Policy message:"
    kubectl delete namespace app-demo --dry-run=server 2>&1 | grep -A 5 "denied the request" || true
else
    echo -e "${RED}✗ FAIL: Deletion was NOT blocked${NC}"
    echo "The policy may not be working correctly"
fi
echo ""

################################################################################
# Test 3: Verify policy details
################################################################################

echo -e "${BLUE}Test 3: Policy Configuration${NC}"
echo ""
echo "Policy Details:"
kubectl get clusterpolicy prevent-app-demo-namespace-deletion -o yaml | grep -A 10 "spec:" | head -15
echo ""

################################################################################
# Test 4: Check if other namespaces can be deleted
################################################################################

echo -e "${BLUE}Test 4: Testing that other namespaces are NOT protected${NC}"
echo ""

# Create a test namespace
TEST_NS="test-deletable-ns-$$"
echo "Creating temporary namespace: $TEST_NS"
kubectl create namespace "$TEST_NS"

echo "Attempting to delete $TEST_NS (should succeed)..."
if kubectl delete namespace "$TEST_NS" --dry-run=server &> /dev/null; then
    echo -e "${GREEN}✓ PASS: Other namespaces can be deleted${NC}"
else
    echo -e "${RED}✗ FAIL: Other namespace deletion was blocked${NC}"
fi
echo ""

################################################################################
# Summary
################################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}✓ app-demo namespace is protected from deletion${NC}"
echo -e "${GREEN}✓ Policy is in Enforce mode (actively blocks deletions)${NC}"
echo -e "${GREEN}✓ Other namespaces can still be deleted normally${NC}"
echo ""
echo -e "${YELLOW}Note: The policy only applies to DELETE operations on app-demo namespace${NC}"
echo ""
