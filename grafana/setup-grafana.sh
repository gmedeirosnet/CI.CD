#!/bin/bash

# Grafana Setup Script
# This script deploys Grafana and configures it to use Loki as a data source

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Grafana Setup${NC}"
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

# Step 2: Create or verify namespace
echo -e "${YELLOW}Step 2: Setting up namespace...${NC}"
if kubectl get namespace grafana &> /dev/null; then
    echo -e "${YELLOW}⚠ Namespace 'grafana' already exists${NC}"
else
    kubectl create namespace grafana
    echo -e "${GREEN}✓ Namespace 'grafana' created${NC}"
fi
echo ""

# Step 3: Check if Loki is installed
echo -e "${YELLOW}Step 3: Checking for Loki installation...${NC}"
if kubectl get service loki -n logging &> /dev/null; then
    echo -e "${GREEN}✓ Loki found in 'logging' namespace${NC}"
    LOKI_AVAILABLE=true
else
    echo -e "${YELLOW}⚠ Loki not found in 'logging' namespace${NC}"
    echo "  Grafana will be configured to connect to: http://loki.logging.svc.cluster.local:3100"
    echo "  You can install Loki by running: ./grafana/setup-loki.sh"
    LOKI_AVAILABLE=false
fi
echo ""

# Step 4: Create Grafana configuration
echo -e "${YELLOW}Step 4: Creating Grafana configuration...${NC}"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: grafana
data:
  datasources.yaml: |
    apiVersion: 1
    datasources:
      - name: Loki
        type: loki
        access: proxy
        url: http://loki.logging.svc.cluster.local:3100
        isDefault: true
        editable: true
        jsonData:
          maxLines: 1000
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-config
  namespace: grafana
data:
  grafana.ini: |
    [server]
    root_url = http://localhost:3000

    [auth.anonymous]
    enabled = true
    org_role = Admin

    [security]
    admin_user = admin
    admin_password = admin

    [users]
    allow_sign_up = false

    [log]
    mode = console
    level = info
EOF

echo -e "${GREEN}✓ Grafana configuration created${NC}"
echo ""

# Step 5: Deploy Grafana
echo -e "${YELLOW}Step 5: Deploying Grafana...${NC}"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-pvc
  namespace: grafana
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: grafana
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      securityContext:
        fsGroup: 472
        supplementalGroups:
          - 0
      containers:
      - name: grafana
        image: grafana/grafana:10.2.3
        ports:
        - containerPort: 3000
          name: http-grafana
          protocol: TCP
        env:
        - name: GF_SECURITY_ADMIN_USER
          value: admin
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: admin
        - name: GF_AUTH_ANONYMOUS_ENABLED
          value: "true"
        - name: GF_AUTH_ANONYMOUS_ORG_ROLE
          value: Admin
        - name: GF_USERS_ALLOW_SIGN_UP
          value: "false"
        - name: GF_SERVER_ROOT_URL
          value: http://localhost:3000
        volumeMounts:
        - name: grafana-storage
          mountPath: /var/lib/grafana
        - name: grafana-datasources
          mountPath: /etc/grafana/provisioning/datasources
        - name: grafana-config
          mountPath: /etc/grafana
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        readinessProbe:
          httpGet:
            path: /api/health
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /api/health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
      - name: grafana-storage
        persistentVolumeClaim:
          claimName: grafana-pvc
      - name: grafana-datasources
        configMap:
          name: grafana-datasources
      - name: grafana-config
        configMap:
          name: grafana-config
          items:
          - key: grafana.ini
            path: grafana.ini
---
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: grafana
spec:
  type: NodePort
  ports:
  - port: 3000
    targetPort: 3000
    nodePort: 30300
    protocol: TCP
  selector:
    app: grafana
EOF

echo -e "${GREEN}✓ Grafana deployed${NC}"
echo ""

# Step 6: Wait for deployment
echo -e "${YELLOW}Step 6: Waiting for Grafana to be ready...${NC}"
echo "This may take 1-2 minutes..."
echo ""

kubectl wait --for=condition=available --timeout=300s deployment/grafana -n grafana 2>/dev/null || true

# Check if deployment is ready
if kubectl get deployment grafana -n grafana &> /dev/null && [ "$(kubectl get deployment grafana -n grafana -o jsonpath='{.status.availableReplicas}')" = "1" ]; then
    echo -e "${GREEN}✓ Grafana is ready${NC}"
else
    echo -e "${YELLOW}⚠ Grafana is still starting...${NC}"
    echo "Check status: kubectl get pods -n grafana"
fi

echo ""

# Step 7: Verify installation
echo -e "${YELLOW}Step 7: Verifying installation...${NC}"

GRAFANA_POD=$(kubectl get pods -n grafana -l app=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$GRAFANA_POD" ]; then
    echo -e "${GREEN}✓ Grafana pod: $GRAFANA_POD${NC}"

    # Check pod status
    POD_STATUS=$(kubectl get pod $GRAFANA_POD -n grafana -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    echo "  Status: $POD_STATUS"
else
    echo -e "${RED}✗ Grafana pod not found${NC}"
fi

echo ""

# Step 8: Get NodePort
NODEPORT=$(kubectl get svc grafana -n grafana -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30300")
echo -e "${GREEN}✓ Grafana service exposed on NodePort: $NODEPORT${NC}"

echo ""

# Step 9: Display access information
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Grafana Information:${NC}"
echo "  Namespace: grafana"
echo "  Service: grafana.grafana.svc.cluster.local:3000"
echo "  NodePort: $NODEPORT"
echo ""

echo -e "${BLUE}Access Grafana:${NC}"
echo "  # Option 1: Port Forward (Recommended)"
echo "  kubectl port-forward -n grafana svc/grafana 3000:3000"
echo "  Then open: http://localhost:3000"
echo ""
echo "  # Option 2: NodePort (for Kind cluster)"
echo "  http://localhost:$NODEPORT"
echo ""

echo -e "${BLUE}Login Credentials:${NC}"
echo "  Username: admin"
echo "  Password: admin"
echo ""

echo -e "${BLUE}Loki Data Source:${NC}"
if [ "$LOKI_AVAILABLE" = true ]; then
    echo -e "  ${GREEN}✓ Pre-configured and ready to use${NC}"
else
    echo -e "  ${YELLOW}⚠ Configured but Loki is not running${NC}"
    echo "  Install Loki first: ./grafana/setup-loki.sh"
fi
echo "  URL: http://loki.logging.svc.cluster.local:3100"
echo "  Name: Loki (default datasource)"
echo ""

echo -e "${BLUE}Using Grafana with Loki:${NC}"
echo "  1. Access Grafana at http://localhost:3000"
echo "  2. Login with admin/admin"
echo "  3. Go to 'Explore' from the left menu"
echo "  4. Select 'Loki' from the data source dropdown"
echo "  5. Use LogQL queries to explore logs:"
echo ""
echo "     # All logs from default namespace"
echo "     {namespace=\"default\"}"
echo ""
echo "     # Logs from specific app"
echo "     {namespace=\"default\", app=\"cicd-demo\"}"
echo ""
echo "     # Search for errors"
echo "     {namespace=\"default\"} |= \"error\""
echo ""
echo "     # Filter by pod"
echo "     {namespace=\"default\", pod=~\"cicd-demo-.*\"}"
echo ""

echo -e "${BLUE}Create a Dashboard:${NC}"
echo "  1. Click '+' -> 'Dashboard' -> 'Add visualization'"
echo "  2. Select 'Loki' as data source"
echo "  3. Enter your LogQL query"
echo "  4. Choose visualization type (Logs, Time series, etc.)"
echo "  5. Save dashboard"
echo ""

echo -e "${BLUE}Quick Commands:${NC}"
echo "  # View Grafana logs"
echo "  kubectl logs -f -n grafana deployment/grafana"
echo ""
echo "  # Restart Grafana"
echo "  kubectl rollout restart deployment/grafana -n grafana"
echo ""
echo "  # Check Grafana status"
echo "  kubectl get all -n grafana"
echo ""
echo "  # Access Grafana shell"
echo "  kubectl exec -it -n grafana deployment/grafana -- /bin/bash"
echo ""
echo "  # Test Loki connection from Grafana"
echo "  kubectl exec -it -n grafana deployment/grafana -- wget -qO- http://loki.logging.svc.cluster.local:3100/ready"
echo ""

echo -e "${BLUE}Verify Loki Connection:${NC}"
echo "  # Check if Loki data source is working"
echo "  kubectl port-forward -n grafana svc/grafana 3000:3000"
echo "  # Then in browser: http://localhost:3000/connections/datasources"
echo "  # Click on 'Loki' and test the connection"
echo ""

echo -e "${BLUE}Troubleshooting:${NC}"
echo "  # If Loki datasource shows error:"
echo "  1. Verify Loki is running:"
echo "     kubectl get pods -n logging"
echo ""
echo "  2. Test connectivity from Grafana to Loki:"
echo "     kubectl exec -n grafana deployment/grafana -- wget -qO- http://loki.logging.svc.cluster.local:3100/ready"
echo ""
echo "  3. Check Grafana logs for errors:"
echo "     kubectl logs -n grafana deployment/grafana"
echo ""

echo -e "${BLUE}Uninstall:${NC}"
echo "  kubectl delete namespace grafana"
echo ""

if [ "$LOKI_AVAILABLE" = true ]; then
    echo -e "${GREEN}✓ Grafana is ready with Loki integration!${NC}"
    echo ""
    echo -e "${YELLOW}Next step: Access Grafana and start exploring logs!${NC}"
else
    echo -e "${YELLOW}⚠ Grafana is deployed but Loki is not available${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Install Loki: ./grafana/setup-loki.sh"
    echo "  2. Access Grafana: kubectl port-forward -n grafana svc/grafana 3000:3000"
    echo "  3. Start exploring logs!"
fi
echo ""
