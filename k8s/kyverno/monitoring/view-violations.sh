#!/usr/bin/env bash
# view-violations.sh
# Helper script to view Kyverno policy violations

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Kyverno Policy Violations Report                  ║${NC}"
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
    echo "Please install Kyverno first"
    exit 1
fi

################################################################################
# Cluster-wide Policy Reports
################################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Cluster-wide Policy Reports${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

if kubectl get clusterpolicyreport &> /dev/null; then
    kubectl get clusterpolicyreport -o wide
    echo ""

    # Count violations
    FAIL_COUNT=$(kubectl get clusterpolicyreport -o json 2>/dev/null | \
        jq '[.items[].results[] | select(.result=="fail")] | length' 2>/dev/null || echo "0")
    PASS_COUNT=$(kubectl get clusterpolicyreport -o json 2>/dev/null | \
        jq '[.items[].results[] | select(.result=="pass")] | length' 2>/dev/null || echo "0")

    echo -e "${GREEN}Pass: $PASS_COUNT${NC}"
    echo -e "${RED}Fail: $FAIL_COUNT${NC}"
    echo ""
else
    echo -e "${YELLOW}No cluster policy reports found${NC}"
    echo ""
fi

################################################################################
# Namespace Policy Reports
################################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Namespace Policy Reports${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

NAMESPACES=$(kubectl get ns -o jsonpath='{.items[*].metadata.name}')

for ns in $NAMESPACES; do
    if kubectl get policyreport -n "$ns" &> /dev/null; then
        REPORT_COUNT=$(kubectl get policyreport -n "$ns" --no-headers 2>/dev/null | wc -l | tr -d ' ')
        if [ "$REPORT_COUNT" -gt 0 ]; then
            echo -e "${YELLOW}Namespace: $ns${NC}"
            kubectl get policyreport -n "$ns" -o wide
            echo ""
        fi
    fi
done

################################################################################
# Detailed Violations (if any)
################################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Detailed Violations${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check for violations in app-demo namespace (primary namespace)
if kubectl get policyreport -n app-demo &> /dev/null; then
    echo -e "${YELLOW}Violations in app-demo namespace:${NC}"
    echo ""

    kubectl get policyreport -n app-demo -o json 2>/dev/null | \
        jq -r '.items[].results[] | select(.result=="fail") |
        "Policy: \(.policy)\nResource: \(.resources[0].kind)/\(.resources[0].name)\nMessage: \(.message)\n---"' \
        2>/dev/null || echo "No violations found"
    echo ""
fi

# Check cluster-wide violations
if kubectl get clusterpolicyreport -o json &> /dev/null; then
    echo -e "${YELLOW}Cluster-wide violations:${NC}"
    echo ""

    kubectl get clusterpolicyreport -o json 2>/dev/null | \
        jq -r '.items[].results[] | select(.result=="fail") |
        "Policy: \(.policy)\nResource: \(.resources[0].kind)/\(.resources[0].name)\nNamespace: \(.resources[0].namespace // "cluster-wide")\nMessage: \(.message)\n---"' \
        2>/dev/null || echo "No violations found"
    echo ""
fi

################################################################################
# Policy Summary
################################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Policy Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo "Installed ClusterPolicies:"
kubectl get clusterpolicies -o custom-columns=\
NAME:.metadata.name,\
ACTION:.spec.validationFailureAction,\
BACKGROUND:.spec.background

echo ""
echo "Installed Policies (namespace-scoped):"
kubectl get policies -A -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
ACTION:.spec.validationFailureAction

echo ""

################################################################################
# Recommendations
################################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Recommendations${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠ Found $FAIL_COUNT policy violations${NC}"
    echo ""
    echo "Actions to take:"
    echo "  1. Review violations above and fix non-compliant resources"
    echo "  2. Update application manifests to meet policy requirements"
    echo "  3. Consider excluding specific resources if violations are acceptable"
    echo "  4. Monitor for 2-3 days before switching policies to Enforce mode"
    echo ""
else
    echo -e "${GREEN}✓ No policy violations found${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Continue monitoring for new violations"
    echo "  2. Consider switching policies from Audit to Enforce mode"
    echo "  3. Add more policies as needed"
    echo ""
fi

echo -e "${BLUE}Useful Commands:${NC}"
echo "  # View specific policy report"
echo "  kubectl describe policyreport <report-name> -n <namespace>"
echo ""
echo "  # Export violations to JSON"
echo "  kubectl get policyreport -n app-demo -o json > violations.json"
echo ""
echo "  # Watch for new violations"
echo "  watch -n 5 'kubectl get policyreport -A'"
echo ""
