#!/bin/bash
# Verification script for PostgreSQL deployment

echo "========================================="
echo "PostgreSQL Deployment Verification"
echo "========================================="
echo ""

echo "1. Pod Status:"
docker exec app-demo-control-plane kubectl get pods -n app-demo -l app=postgres
echo ""

echo "2. Service Status:"
docker exec app-demo-control-plane kubectl get svc -n app-demo postgres
echo ""

echo "3. PVC Status:"
docker exec app-demo-control-plane kubectl get pvc -n app-demo postgres-pvc
echo ""

echo "4. Database Connection:"
docker exec app-demo-control-plane kubectl exec -n app-demo postgres-0 -- pg_isready -U app_user
echo ""

echo "5. Database List:"
docker exec app-demo-control-plane kubectl exec -n app-demo postgres-0 -- psql -U app_user -d cicd_demo -c "SELECT datname FROM pg_database;"
echo ""

echo "========================================="
echo "✅ PostgreSQL Verification Complete"
echo "========================================="
