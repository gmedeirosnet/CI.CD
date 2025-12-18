#!/bin/bash
# Comprehensive deployment test script

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KIND_CLUSTER="${KIND_CLUSTER_NAME:-app-demo}"
NAMESPACE="${KUBE_NAMESPACE:-app-demo}"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}=========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=========================================${NC}"
}

print_test() {
    echo -e "${YELLOW}TEST:${NC} $1"
}

print_pass() {
    echo -e "${GREEN}✅ PASS:${NC} $1"
}

print_fail() {
    echo -e "${RED}❌ FAIL:${NC} $1"
    exit 1
}

print_info() {
    echo -e "${BLUE}ℹ️  INFO:${NC} $1"
}

# Test counters
TESTS_RUN=0
TESTS_PASSED=0

run_test() {
    local test_name="$1"
    local test_command="$2"

    TESTS_RUN=$((TESTS_RUN + 1))
    print_test "$test_name"

    if eval "$test_command" > /dev/null 2>&1; then
        print_pass "$test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_fail "$test_name"
        return 1
    fi
}

print_header "Full-Stack Deployment Test Suite"
echo "Project: CI/CD Demo"
echo "Cluster: $KIND_CLUSTER"
echo "Namespace: $NAMESPACE"
echo ""

print_header "Infrastructure Tests"

print_test "Kind cluster is running"
if docker ps --filter "name=${KIND_CLUSTER}-control-plane" --format '{{.Names}}' | grep -q "${KIND_CLUSTER}-control-plane"; then
    print_pass "Kind cluster is running"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_fail "Kind cluster is NOT running"
fi
TESTS_RUN=$((TESTS_RUN + 1))

print_test "Namespace exists"
if docker exec ${KIND_CLUSTER}-control-plane kubectl get namespace ${NAMESPACE} > /dev/null 2>&1; then
    print_pass "Namespace ${NAMESPACE} exists"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_fail "Namespace ${NAMESPACE} does NOT exist"
fi
TESTS_RUN=$((TESTS_RUN + 1))

print_header "PostgreSQL Deployment Tests"

print_test "PostgreSQL StatefulSet exists"
if docker exec ${KIND_CLUSTER}-control-plane kubectl get statefulset postgres -n ${NAMESPACE} > /dev/null 2>&1; then
    print_pass "StatefulSet exists"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_fail "StatefulSet does NOT exist"
fi
TESTS_RUN=$((TESTS_RUN + 1))

print_test "PostgreSQL pod is running"
if docker exec ${KIND_CLUSTER}-control-plane kubectl get pod postgres-0 -n ${NAMESPACE} -o jsonpath='{.status.phase}' | grep -q "Running"; then
    print_pass "Pod is running"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_fail "Pod is NOT running"
fi
TESTS_RUN=$((TESTS_RUN + 1))

print_test "PostgreSQL pod is ready (1/1)"
if docker exec ${KIND_CLUSTER}-control-plane kubectl get pod postgres-0 -n ${NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q "True"; then
    print_pass "Pod is ready"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_fail "Pod is NOT ready"
fi
TESTS_RUN=$((TESTS_RUN + 1))

print_test "PostgreSQL service exists"
if docker exec ${KIND_CLUSTER}-control-plane kubectl get svc postgres -n ${NAMESPACE} > /dev/null 2>&1; then
    print_pass "Service exists"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_fail "Service does NOT exist"
fi
TESTS_RUN=$((TESTS_RUN + 1))

print_test "PVC is bound"
if docker exec ${KIND_CLUSTER}-control-plane kubectl get pvc postgres-pvc -n ${NAMESPACE} -o jsonpath='{.status.phase}' | grep -q "Bound"; then
    print_pass "PVC is bound"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_fail "PVC is NOT bound"
fi
TESTS_RUN=$((TESTS_RUN + 1))

print_header "PostgreSQL Connectivity Tests"

print_test "PostgreSQL is accepting connections"
if docker exec ${KIND_CLUSTER}-control-plane kubectl exec -n ${NAMESPACE} postgres-0 -- pg_isready -U app_user > /dev/null 2>&1; then
    print_pass "PostgreSQL accepting connections"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_fail "PostgreSQL NOT accepting connections"
fi
TESTS_RUN=$((TESTS_RUN + 1))

print_test "Database 'cicd_demo' exists"
if docker exec ${KIND_CLUSTER}-control-plane kubectl exec -n ${NAMESPACE} postgres-0 -- psql -U app_user -d cicd_demo -c "SELECT 1;" > /dev/null 2>&1; then
    print_pass "Database exists and accessible"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_fail "Database does NOT exist or not accessible"
fi
TESTS_RUN=$((TESTS_RUN + 1))

print_test "User 'app_user' can connect"
if docker exec ${KIND_CLUSTER}-control-plane kubectl exec -n ${NAMESPACE} postgres-0 -- psql -U app_user -d cicd_demo -c "SELECT current_user;" | grep -q "app_user"; then
    print_pass "User can connect"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_fail "User CANNOT connect"
fi
TESTS_RUN=$((TESTS_RUN + 1))

print_header "PostgreSQL Security Tests"

print_test "Pod runs as non-root (UID 999)"
if docker exec ${KIND_CLUSTER}-control-plane kubectl exec -n ${NAMESPACE} postgres-0 -- id -u | grep -q "999"; then
    print_pass "Running as UID 999 (non-root)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_fail "NOT running as UID 999"
fi
TESTS_RUN=$((TESTS_RUN + 1))

print_test "FSGroup is set (999)"
if docker exec ${KIND_CLUSTER}-control-plane kubectl get pod postgres-0 -n ${NAMESPACE} -o jsonpath='{.spec.securityContext.fsGroup}' | grep -q "999"; then
    print_pass "FSGroup is 999"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_fail "FSGroup is NOT 999"
fi
TESTS_RUN=$((TESTS_RUN + 1))

print_test "Resource limits configured"
if docker exec ${KIND_CLUSTER}-control-plane kubectl get pod postgres-0 -n ${NAMESPACE} -o jsonpath='{.spec.containers[0].resources.limits}' | grep -q "memory"; then
    print_pass "Resource limits configured"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_fail "Resource limits NOT configured"
fi
TESTS_RUN=$((TESTS_RUN + 1))

print_test "Liveness probe configured"
if docker exec ${KIND_CLUSTER}-control-plane kubectl get pod postgres-0 -n ${NAMESPACE} -o jsonpath='{.spec.containers[0].livenessProbe}' | grep -q "pg_isready"; then
    print_pass "Liveness probe configured"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_fail "Liveness probe NOT configured"
fi
TESTS_RUN=$((TESTS_RUN + 1))

print_test "Readiness probe configured"
if docker exec ${KIND_CLUSTER}-control-plane kubectl get pod postgres-0 -n ${NAMESPACE} -o jsonpath='{.spec.containers[0].readinessProbe}' | grep -q "pg_isready"; then
    print_pass "Readiness probe configured"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_fail "Readiness probe NOT configured"
fi
TESTS_RUN=$((TESTS_RUN + 1))

print_header "Database Functionality Tests"

print_test "Can create table"
if docker exec ${KIND_CLUSTER}-control-plane kubectl exec -n ${NAMESPACE} postgres-0 -- psql -U app_user -d cicd_demo -c "CREATE TABLE IF NOT EXISTS test_table (id INT);" > /dev/null 2>&1; then
    print_pass "Can create table"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_fail "CANNOT create table"
fi
TESTS_RUN=$((TESTS_RUN + 1))

print_test "Can insert data"
if docker exec ${KIND_CLUSTER}-control-plane kubectl exec -n ${NAMESPACE} postgres-0 -- psql -U app_user -d cicd_demo -c "INSERT INTO test_table VALUES (1);" > /dev/null 2>&1; then
    print_pass "Can insert data"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_fail "CANNOT insert data"
fi
TESTS_RUN=$((TESTS_RUN + 1))

print_test "Can query data"
if docker exec ${KIND_CLUSTER}-control-plane kubectl exec -n ${NAMESPACE} postgres-0 -- psql -U app_user -d cicd_demo -c "SELECT * FROM test_table;" | grep -q "1"; then
    print_pass "Can query data"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_fail "CANNOT query data"
fi
TESTS_RUN=$((TESTS_RUN + 1))

print_test "Can drop table"
if docker exec ${KIND_CLUSTER}-control-plane kubectl exec -n ${NAMESPACE} postgres-0 -- psql -U app_user -d cicd_demo -c "DROP TABLE test_table;" > /dev/null 2>&1; then
    print_pass "Can drop table"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_fail "CANNOT drop table"
fi
TESTS_RUN=$((TESTS_RUN + 1))

print_test "Schema is empty (ready for Flyway)"
TABLE_COUNT=$(docker exec ${KIND_CLUSTER}-control-plane kubectl exec -n ${NAMESPACE} postgres-0 -- psql -U app_user -d cicd_demo -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | tr -d ' ')
if [ "$TABLE_COUNT" = "0" ]; then
    print_pass "Schema is empty and ready for Flyway migrations"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_fail "Schema is NOT empty (has $TABLE_COUNT tables)"
fi
TESTS_RUN=$((TESTS_RUN + 1))

print_header "Test Results Summary"
echo ""
echo -e "${BLUE}Total Tests:${NC} $TESTS_RUN"
echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Failed:${NC} $((TESTS_RUN - TESTS_PASSED))"
echo ""

if [ $TESTS_PASSED -eq $TESTS_RUN ]; then
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}✅ ALL TESTS PASSED!${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    print_info "PostgreSQL is fully operational and ready for backend deployment"
    echo ""
    echo "Next steps:"
    echo "  1. Trigger Jenkins pipeline: http://localhost:8080"
    echo "  2. Monitor deployment: kubectl get pods -n app-demo -w"
    echo "  3. Access frontend: http://localhost:30080"
    exit 0
else
    echo -e "${RED}=========================================${NC}"
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    echo -e "${RED}=========================================${NC}"
    exit 1
fi
