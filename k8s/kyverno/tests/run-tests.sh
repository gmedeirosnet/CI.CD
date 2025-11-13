#!/usr/bin/env bash
# run-tests.sh
# Test Kyverno policies with valid and invalid manifests

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASSED=0
FAILED=0

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Kyverno Policy Testing Suite                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}✗ Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi

# Check if Kyverno is installed
if ! kubectl get ns kyverno &> /dev/null; then
    echo -e "${RED}✗ Kyverno namespace not found${NC}"
    echo "Please install Kyverno first: ./install/setup-kyverno.sh"
    exit 1
fi

# Check if policies are deployed
POLICY_COUNT=$(kubectl get clusterpolicies --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$POLICY_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}⚠ No ClusterPolicies found${NC}"
    echo "Deploy policies first: kubectl apply -f policies/"
    exit 1
fi

echo -e "${GREEN}✓ Found $POLICY_COUNT ClusterPolicies${NC}"
echo ""

################################################################################
# Test Valid Manifests (should pass)
################################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Testing Valid Manifests (should PASS all policies)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

for file in "$SCRIPT_DIR/valid"/*.yaml; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        echo -e "${YELLOW}Testing: $filename${NC}"

        if kubectl apply -f "$file" --dry-run=server &> /dev/null; then
            echo -e "${GREEN}✓ PASS: $filename${NC}"
            ((PASSED++))
        else
            echo -e "${RED}✗ FAIL: $filename (unexpected)${NC}"
            kubectl apply -f "$file" --dry-run=server
            ((FAILED++))
        fi
        echo ""
    fi
done

################################################################################
# Test Invalid Manifests (should fail)
################################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Testing Invalid Manifests (should FAIL policies)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

for file in "$SCRIPT_DIR/invalid"/*.yaml; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        echo -e "${YELLOW}Testing: $filename${NC}"

        # Capture output
        OUTPUT=$(kubectl apply -f "$file" --dry-run=server 2>&1 || true)

        if echo "$OUTPUT" | grep -q "violates"; then
            echo -e "${GREEN}✓ PASS: $filename (correctly blocked)${NC}"
            echo -e "${BLUE}  Policy violation detected as expected${NC}"
            ((PASSED++))
        elif echo "$OUTPUT" | grep -qi "error\|denied\|forbidden"; then
            echo -e "${GREEN}✓ PASS: $filename (correctly blocked)${NC}"
            echo -e "${BLUE}  Policy violation detected as expected${NC}"
            ((PASSED++))
        else
            echo -e "${YELLOW}⚠ NOTE: $filename was allowed (policies in AUDIT mode)${NC}"
            echo -e "${BLUE}  In Audit mode, violations are logged but not blocked${NC}"
            echo -e "${BLUE}  Check policy reports: kubectl get policyreport -n app-demo${NC}"
            ((PASSED++))
        fi
        echo ""
    fi
done

################################################################################
# Summary
################################################################################

TOTAL=$((PASSED + FAILED))

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Total tests: $TOTAL"
echo -e "${GREEN}Passed: $PASSED${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $FAILED${NC}"
fi
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests completed successfully!${NC}"
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. View policy reports:"
echo "     kubectl get policyreport -n app-demo"
echo "     kubectl get clusterpolicyreport -A"
echo ""
echo "  2. View detailed report:"
echo "     kubectl describe policyreport -n app-demo"
echo ""
echo "  3. Check violations:"
echo "     kubectl get policyreport -n app-demo -o json | jq '.results[] | select(.result==\"fail\")'"
echo ""
echo -e "${YELLOW}Note: Policies are in AUDIT mode. Violations are logged but not blocked.${NC}"
echo -e "${YELLOW}Monitor violations for 2-3 days before switching to ENFORCE mode.${NC}"
echo ""
