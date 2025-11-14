#!/bin/bash

# Prometheus Setup Script
# This script deploys Prometheus, kube-state-metrics, and node-exporter for Kubernetes monitoring

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
K8S_DIR="$SCRIPT_DIR/../prometheus"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Prometheus Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Check prerequisites
echo -e "${YELLOW}Step 1: Checking prerequisites...${NC}"
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl not found${NC}"
    echo "Please install kubectl first"
    exit 1
fi
echo -e "${GREEN}✓ kubectl is available${NC}"

if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}✗ Cannot connect to Kubernetes cluster${NC}"
    echo "Please ensure your cluster is running"
    exit 1
fi
echo -e "${GREEN}✓ Kubernetes cluster is accessible${NC}"
echo ""

# Step 2: Create namespace
echo -e "${YELLOW}Step 2: Creating monitoring namespace...${NC}"
if kubectl get namespace monitoring &> /dev/null; then
    echo -e "${YELLOW}⚠ Namespace 'monitoring' already exists${NC}"
else
    kubectl create namespace monitoring
    echo -e "${GREEN}✓ Namespace 'monitoring' created${NC}"
fi
echo ""

# Step 3: Deploy Prometheus RBAC
echo -e "${YELLOW}Step 3: Deploying Prometheus RBAC...${NC}"
kubectl apply -f "$K8S_DIR/prometheus-rbac.yaml"
echo -e "${GREEN}✓ Prometheus RBAC configured${NC}"
echo ""

# Step 4: Deploy Prometheus ConfigMap
echo -e "${YELLOW}Step 4: Deploying Prometheus configuration...${NC}"
kubectl apply -f "$K8S_DIR/prometheus-config.yaml"
echo -e "${GREEN}✓ Prometheus configuration deployed${NC}"
echo ""

# Step 5: Deploy Prometheus
echo -e "${YELLOW}Step 5: Deploying Prometheus...${NC}"
kubectl apply -f "$K8S_DIR/prometheus-deployment.yaml"
echo -e "${GREEN}✓ Prometheus deployed${NC}"
echo ""

# Step 6: Deploy kube-state-metrics
echo -e "${YELLOW}Step 6: Deploying kube-state-metrics...${NC}"
kubectl apply -f "$K8S_DIR/kube-state-metrics.yaml"
echo -e "${GREEN}✓ kube-state-metrics deployed${NC}"
echo ""

# Step 7: Deploy node-exporter
echo -e "${YELLOW}Step 7: Deploying node-exporter...${NC}"
kubectl apply -f "$K8S_DIR/node-exporter.yaml"
echo -e "${GREEN}✓ node-exporter deployed${NC}"
echo ""

# Step 8: Wait for deployments
echo -e "${YELLOW}Step 8: Waiting for deployments to be ready...${NC}"
echo "This may take 1-2 minutes..."
echo ""

echo -n "Waiting for Prometheus..."
kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n monitoring 2>/dev/null || true
if kubectl get deployment prometheus -n monitoring &> /dev/null && [ "$(kubectl get deployment prometheus -n monitoring -o jsonpath='{.status.availableReplicas}')" = "1" ]; then
    echo -e " ${GREEN}✓${NC}"
else
    echo -e " ${YELLOW}⚠ Still starting...${NC}"
fi

echo -n "Waiting for kube-state-metrics..."
kubectl wait --for=condition=available --timeout=300s deployment/kube-state-metrics -n monitoring 2>/dev/null || true
if kubectl get deployment kube-state-metrics -n monitoring &> /dev/null && [ "$(kubectl get deployment kube-state-metrics -n monitoring -o jsonpath='{.status.availableReplicas}')" = "1" ]; then
    echo -e " ${GREEN}✓${NC}"
else
    echo -e " ${YELLOW}⚠ Still starting...${NC}"
fi

echo -n "Waiting for node-exporter..."
kubectl rollout status daemonset/node-exporter -n monitoring --timeout=300s &> /dev/null || true
if kubectl get daemonset node-exporter -n monitoring &> /dev/null; then
    echo -e " ${GREEN}✓${NC}"
else
    echo -e " ${YELLOW}⚠ Still starting...${NC}"
fi

echo ""

# Step 9: Verify installation
echo -e "${YELLOW}Step 9: Verifying installation...${NC}"

PROMETHEUS_POD=$(kubectl get pods -n monitoring -l app=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$PROMETHEUS_POD" ]; then
    echo -e "${GREEN}✓ Prometheus pod: $PROMETHEUS_POD${NC}"
else
    echo -e "${RED}✗ Prometheus pod not found${NC}"
fi

KSM_POD=$(kubectl get pods -n monitoring -l app=kube-state-metrics -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$KSM_POD" ]; then
    echo -e "${GREEN}✓ kube-state-metrics pod: $KSM_POD${NC}"
else
    echo -e "${RED}✗ kube-state-metrics pod not found${NC}"
fi

NODE_EXPORTER_COUNT=$(kubectl get daemonset node-exporter -n monitoring -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
echo -e "${GREEN}✓ node-exporter pods: $NODE_EXPORTER_COUNT${NC}"

NODEPORT=$(kubectl get svc prometheus -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')
echo -e "${GREEN}✓ Prometheus exposed on NodePort: $NODEPORT${NC}"

echo ""

# Step 10: Display access information
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Prometheus Information:${NC}"
echo "  Namespace: monitoring"
echo "  Service: prometheus.monitoring.svc.cluster.local:9090"
echo "  NodePort: http://localhost:$NODEPORT"
echo "  UI: http://localhost:$NODEPORT"
echo ""

echo -e "${BLUE}Access Prometheus:${NC}"
echo "  # Via NodePort (recommended for Docker Desktop + Kind)"
echo "  open http://localhost:$NODEPORT"
echo ""
echo "  # Via Port Forward"
echo "  kubectl port-forward -n monitoring svc/prometheus 9090:9090"
echo "  open http://localhost:9090"
echo ""

echo -e "${BLUE}Deployed Components:${NC}"
echo "  ✓ Prometheus - Metrics collection and storage"
echo "  ✓ kube-state-metrics - Kubernetes object metrics"
echo "  ✓ node-exporter - Node/system metrics"
echo ""

echo -e "${BLUE}Check Scrape Targets:${NC}"
echo "  open http://localhost:$NODEPORT/targets"
echo ""

echo -e "${BLUE}Example Queries:${NC}"
echo "  # CPU usage by pod"
echo "  sum(rate(container_cpu_usage_seconds_total[5m])) by (pod)"
echo ""
echo "  # Memory usage by namespace"
echo "  sum(container_memory_usage_bytes) by (namespace)"
echo ""
echo "  # Node CPU usage"
echo "  100 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)"
echo ""
echo "  # Pod count by namespace"
echo "  count(kube_pod_info) by (namespace)"
echo ""

echo -e "${BLUE}Quick Commands:${NC}"
echo "  # View Prometheus logs"
echo "  kubectl logs -f -n monitoring deployment/prometheus"
echo ""
echo "  # Check Prometheus configuration"
echo "  kubectl exec -n monitoring deployment/prometheus -- promtool check config /etc/prometheus/prometheus.yml"
echo ""
echo "  # Reload configuration"
echo "  kubectl exec -n monitoring deployment/prometheus -- wget --post-data='' -O- http://localhost:9090/-/reload"
echo ""

echo -e "${BLUE}Integration with Grafana:${NC}"
echo "  Run: ./setup-grafana-docker.sh"
echo "  Prometheus will be automatically configured as a datasource"
echo ""

echo -e "${BLUE}Uninstall:${NC}"
echo "  kubectl delete namespace monitoring"
echo ""

echo -e "${GREEN}✓ Prometheus is ready to collect metrics!${NC}"
