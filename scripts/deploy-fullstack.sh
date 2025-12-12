#!/bin/bash
# Deployment Guide for Full-Stack CI/CD Demo Application
# This script deploys PostgreSQL, Backend (Spring Boot), and Frontend (React)

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KIND_CLUSTER="${KIND_CLUSTER_NAME:-app-demo}"
NAMESPACE="${KUBE_NAMESPACE:-app-demo}"

echo "========================================="
echo "Full-Stack Application Deployment"
echo "========================================="
echo "Project Root: $PROJECT_ROOT"
echo "Kind Cluster: $KIND_CLUSTER"
echo "Namespace: $NAMESPACE"
echo "========================================="

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored messages
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

# Step 1: Verify Kind cluster is running
echo ""
echo "Step 1: Verifying Kind cluster..."
if ! docker ps --filter "name=${KIND_CLUSTER}-control-plane" --format '{{.Names}}' | grep -q "${KIND_CLUSTER}-control-plane"; then
    print_error "Kind cluster '${KIND_CLUSTER}' not found. Please start the cluster first."
fi
print_success "Kind cluster is running"

# Step 2: Create namespace if needed
echo ""
echo "Step 2: Ensuring namespace exists..."
docker exec ${KIND_CLUSTER}-control-plane kubectl create namespace ${NAMESPACE} 2>/dev/null || \
    echo "Namespace ${NAMESPACE} already exists"
print_success "Namespace ${NAMESPACE} is ready"

# Step 3: Deploy PostgreSQL
echo ""
echo "Step 3: Deploying PostgreSQL database..."
docker exec -i ${KIND_CLUSTER}-control-plane kubectl apply -f - < ${PROJECT_ROOT}/k8s/postgres/postgres-statefulset.yaml

echo "Waiting for PostgreSQL to be ready (this may take 30-60 seconds)..."
docker exec ${KIND_CLUSTER}-control-plane kubectl wait --for=condition=ready pod \
    -l app=postgres -n ${NAMESPACE} --timeout=120s || print_warning "PostgreSQL pod may not be ready yet"

print_success "PostgreSQL deployed"

# Step 4: Verify PostgreSQL is accessible
echo ""
echo "Step 4: Verifying PostgreSQL connection..."
sleep 5  # Give PostgreSQL extra time to fully initialize

docker exec ${KIND_CLUSTER}-control-plane kubectl exec -n ${NAMESPACE} \
    $(docker exec ${KIND_CLUSTER}-control-plane kubectl get pod -n ${NAMESPACE} -l app=postgres -o jsonpath='{.items[0].metadata.name}') \
    -- pg_isready -U app_user && print_success "PostgreSQL is accepting connections" || \
    print_warning "PostgreSQL connection check failed - database may still be initializing"

# Step 5: Show deployment status
echo ""
echo "========================================="
echo "Deployment Summary"
echo "========================================="

echo ""
echo "PostgreSQL Status:"
docker exec ${KIND_CLUSTER}-control-plane kubectl get pods -n ${NAMESPACE} -l app=postgres

echo ""
echo "PostgreSQL Service:"
docker exec ${KIND_CLUSTER}-control-plane kubectl get svc -n ${NAMESPACE} -l app.kubernetes.io/name=postgres

echo ""
echo "========================================="
echo "Next Steps:"
echo "========================================="
echo "1. Run Jenkins pipeline to build and deploy backend + frontend"
echo "   - Jenkins will build both Spring Boot and React applications"
echo "   - Images will be pushed to Harbor"
echo "   - ArgoCD will deploy via Helm charts"
echo ""
echo "2. Verify backend deployment:"
echo "   kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/component=backend"
echo ""
echo "3. Test backend API (once deployed):"
echo "   kubectl port-forward -n ${NAMESPACE} svc/cicd-demo-backend 8001:8001"
echo "   curl http://localhost:8001/api/tasks"
echo ""
echo "4. Access frontend (once deployed):"
echo "   http://localhost:30080"
echo ""
echo "5. View logs:"
echo "   Backend:  kubectl logs -n ${NAMESPACE} -l app.kubernetes.io/component=backend --tail=100 -f"
echo "   Frontend: kubectl logs -n ${NAMESPACE} -l app.kubernetes.io/component=frontend --tail=100 -f"
echo "   Database: kubectl logs -n ${NAMESPACE} -l app=postgres --tail=100 -f"
echo ""
echo "========================================="
print_success "PostgreSQL deployment complete!"
