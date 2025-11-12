#!/bin/bash

# Grafana Loki Setup Script
# This script deploys Grafana Loki and Promtail for Kubernetes log aggregation

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Grafana Loki Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Check if kubectl is available
echo -e "${YELLOW}Step 1: Checking prerequisites...${NC}"
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl not found${NC}"
    echo "Please install kubectl first"
    exit 1
fi
echo -e "${GREEN}✓ kubectl is available${NC}"

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}✗ Cannot connect to Kubernetes cluster${NC}"
    echo "Please ensure your cluster is running"
    exit 1
fi
echo -e "${GREEN}✓ Kubernetes cluster is accessible${NC}"
echo ""

# Step 2: Create namespace
echo -e "${YELLOW}Step 2: Creating logging namespace...${NC}"
if kubectl get namespace logging &> /dev/null; then
    echo -e "${YELLOW}⚠ Namespace 'logging' already exists${NC}"
else
    kubectl create namespace logging
    echo -e "${GREEN}✓ Namespace 'logging' created${NC}"
fi
echo ""

# Step 3: Deploy Loki
echo -e "${YELLOW}Step 3: Deploying Loki...${NC}"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: loki-pvc
  namespace: logging
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: loki-config
  namespace: logging
data:
  loki.yaml: |
    auth_enabled: false

    server:
      http_listen_port: 3100
      grpc_listen_port: 9096

    common:
      path_prefix: /loki
      storage:
        filesystem:
          chunks_directory: /loki/chunks
          rules_directory: /loki/rules
      replication_factor: 1
      ring:
        instance_addr: 127.0.0.1
        kvstore:
          store: inmemory

    schema_config:
      configs:
        - from: 2020-10-24
          store: boltdb-shipper
          object_store: filesystem
          schema: v11
          index:
            prefix: index_
            period: 24h

    ruler:
      alertmanager_url: http://localhost:9093

    analytics:
      reporting_enabled: false
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: loki
  namespace: logging
spec:
  replicas: 1
  selector:
    matchLabels:
      app: loki
  template:
    metadata:
      labels:
        app: loki
    spec:
      containers:
      - name: loki
        image: grafana/loki:2.9.3
        args:
          - -config.file=/etc/loki/loki.yaml
        ports:
        - containerPort: 3100
          name: http-metrics
        - containerPort: 9096
          name: grpc
        volumeMounts:
        - name: config
          mountPath: /etc/loki
        - name: storage
          mountPath: /loki
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
      volumes:
      - name: config
        configMap:
          name: loki-config
      - name: storage
        persistentVolumeClaim:
          claimName: loki-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: loki
  namespace: logging
spec:
  type: ClusterIP
  ports:
  - port: 3100
    targetPort: 3100
    name: http-metrics
  - port: 9096
    targetPort: 9096
    name: grpc
  selector:
    app: loki
EOF

echo -e "${GREEN}✓ Loki deployed${NC}"
echo ""

# Step 4: Deploy Promtail
echo -e "${YELLOW}Step 4: Deploying Promtail (log collector)...${NC}"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: promtail
  namespace: logging
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: promtail
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/proxy
  - services
  - endpoints
  - pods
  verbs: ["get", "watch", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: promtail
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: promtail
subjects:
- kind: ServiceAccount
  name: promtail
  namespace: logging
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: promtail-config
  namespace: logging
data:
  promtail.yaml: |
    server:
      http_listen_port: 9080
      grpc_listen_port: 0

    positions:
      filename: /tmp/positions.yaml

    clients:
      - url: http://loki:3100/loki/api/v1/push

    scrape_configs:
      - job_name: kubernetes-pods
        kubernetes_sd_configs:
          - role: pod
        pipeline_stages:
          - cri: {}
        relabel_configs:
          - source_labels:
              - __meta_kubernetes_pod_controller_name
            regex: ([0-9a-z-.]+?)(-[0-9a-f]{8,10})?
            action: replace
            target_label: __tmp_controller_name
          - source_labels:
              - __meta_kubernetes_pod_label_app_kubernetes_io_name
              - __meta_kubernetes_pod_label_app
              - __tmp_controller_name
              - __meta_kubernetes_pod_name
            regex: ^;*([^;]+)(;.*)?$
            action: replace
            target_label: app
          - source_labels:
              - __meta_kubernetes_pod_label_app_kubernetes_io_component
              - __meta_kubernetes_pod_label_component
            regex: ^;*([^;]+)(;.*)?$
            action: replace
            target_label: component
          - source_labels:
              - __meta_kubernetes_pod_node_name
            target_label: node_name
          - source_labels:
              - __meta_kubernetes_namespace
            target_label: namespace
          - source_labels:
              - __meta_kubernetes_pod_name
            target_label: pod
          - source_labels:
              - __meta_kubernetes_pod_container_name
            target_label: container
          - replacement: /var/log/pods/*\$1/*.log
            separator: /
            source_labels:
              - __meta_kubernetes_pod_uid
              - __meta_kubernetes_pod_container_name
            target_label: __path__
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: promtail
  namespace: logging
spec:
  selector:
    matchLabels:
      app: promtail
  template:
    metadata:
      labels:
        app: promtail
    spec:
      serviceAccountName: promtail
      containers:
      - name: promtail
        image: grafana/promtail:2.9.3
        args:
          - -config.file=/etc/promtail/promtail.yaml
        env:
        - name: HOSTNAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        volumeMounts:
        - name: config
          mountPath: /etc/promtail
        - name: varlog
          mountPath: /var/log
          readOnly: true
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        resources:
          requests:
            cpu: 50m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
      volumes:
      - name: config
        configMap:
          name: promtail-config
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      tolerations:
      - effect: NoSchedule
        operator: Exists
EOF

echo -e "${GREEN}✓ Promtail deployed${NC}"
echo ""

# Step 5: Wait for deployments
echo -e "${YELLOW}Step 5: Waiting for deployments to be ready...${NC}"
echo "This may take 1-2 minutes..."
echo ""

echo -n "Waiting for Loki..."
kubectl wait --for=condition=available --timeout=300s deployment/loki -n logging 2>/dev/null || true
if kubectl get deployment loki -n logging &> /dev/null && [ "$(kubectl get deployment loki -n logging -o jsonpath='{.status.availableReplicas}')" = "1" ]; then
    echo -e " ${GREEN}✓${NC}"
else
    echo -e " ${YELLOW}⚠ Still starting...${NC}"
fi

echo -n "Waiting for Promtail..."
kubectl rollout status daemonset/promtail -n logging --timeout=300s &> /dev/null || true
if kubectl get daemonset promtail -n logging &> /dev/null; then
    echo -e " ${GREEN}✓${NC}"
else
    echo -e " ${YELLOW}⚠ Still starting...${NC}"
fi

echo ""

# Step 6: Verify installation
echo -e "${YELLOW}Step 6: Verifying installation...${NC}"

LOKI_POD=$(kubectl get pods -n logging -l app=loki -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$LOKI_POD" ]; then
    echo -e "${GREEN}✓ Loki pod: $LOKI_POD${NC}"
else
    echo -e "${RED}✗ Loki pod not found${NC}"
fi

PROMTAIL_COUNT=$(kubectl get daemonset promtail -n logging -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
echo -e "${GREEN}✓ Promtail pods: $PROMTAIL_COUNT${NC}"

echo ""

# Step 7: Display access information
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Loki Information:${NC}"
echo "  Namespace: logging"
echo "  Service: loki.logging.svc.cluster.local:3100"
echo "  API Endpoint: http://loki.logging.svc.cluster.local:3100"
echo ""

echo -e "${BLUE}Access Loki (Port Forward):${NC}"
echo "  kubectl port-forward -n logging svc/loki 3100:3100"
echo "  Then access: http://localhost:3100"
echo ""

echo -e "${BLUE}Query Logs with LogQL:${NC}"
echo "  # All logs from default namespace"
echo "  {namespace=\"default\"}"
echo ""
echo "  # Logs from specific app"
echo "  {namespace=\"default\", app=\"cicd-demo\"}"
echo ""
echo "  # Search for errors"
echo "  {namespace=\"default\"} |= \"error\""
echo ""

echo -e "${BLUE}Integrate with Grafana:${NC}"
echo "  1. Add Loki as a Data Source in Grafana"
echo "  2. URL: http://loki.logging.svc.cluster.local:3100"
echo "  3. Use LogQL queries in Explore or Dashboard panels"
echo ""

echo -e "${BLUE}Quick Commands:${NC}"
echo "  # View Loki logs"
echo "  kubectl logs -f -n logging deployment/loki"
echo ""
echo "  # View Promtail logs"
echo "  kubectl logs -f -n logging daemonset/promtail"
echo ""
echo "  # Check Loki metrics"
echo "  kubectl port-forward -n logging svc/loki 3100:3100"
echo "  curl http://localhost:3100/metrics"
echo ""
echo "  # Query API directly"
echo "  curl 'http://localhost:3100/loki/api/v1/query?query={namespace=\"default\"}'"
echo ""

echo -e "${BLUE}Uninstall:${NC}"
echo "  kubectl delete namespace logging"
echo ""

echo -e "${GREEN}✓ Grafana Loki is ready to collect logs!${NC}"
