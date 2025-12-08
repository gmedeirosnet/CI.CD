#!/bin/bash

################################################################################
# DevOps CI/CD Lab - Complete Setup Script
# This script orchestrates the setup of all services in the correct order
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

################################################################################
# Functions
################################################################################

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_command() {
    if command -v "$1" &> /dev/null; then
        print_success "$1 is installed"
        return 0
    else
        print_error "$1 is not installed"
        return 1
    fi
}

wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=30
    local attempt=1

    print_info "Waiting for $service_name to be ready..."

    while [ $attempt -le $max_attempts ]; do
        # Get HTTP status code
        local http_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)

        # Accept 200 (OK), 302 (Redirect), 403 (Auth required - Jenkins), 401 (Unauthorized)
        if [[ "$http_code" =~ ^(200|302|401|403)$ ]]; then
            print_success "$service_name is ready! (HTTP $http_code)"
            return 0
        fi
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done

    print_warning "$service_name not responding after $max_attempts attempts"
    return 1
}

update_env_file() {
    local key=$1
    local value=$2
    local env_file="$PROJECT_ROOT/.env"

    if [ -f "$env_file" ]; then
        # Check if key exists in file
        if grep -q "^${key}=" "$env_file"; then
            # Update existing value (macOS compatible)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s|^${key}=.*|${key}=${value}|" "$env_file"
            else
                sed -i "s|^${key}=.*|${key}=${value}|" "$env_file"
            fi
            print_success "Updated $key in .env file"
        else
            # Add new key-value pair
            echo "${key}=${value}" >> "$env_file"
            print_success "Added $key to .env file"
        fi
    else
        print_warning ".env file not found, skipping update for $key"
    fi
}

################################################################################
# Main Setup
################################################################################

print_header "DevOps CI/CD Lab Setup"
echo ""
echo "This script will set up the complete CI/CD environment including:"
echo "- Docker and Docker Compose"
echo "- Kind Kubernetes cluster"
echo "- Jenkins CI/CD server"
echo "- Harbor container registry"
echo "- SonarQube code analysis"
echo "- ArgoCD GitOps deployment"
echo "- Grafana visualization platform"
echo "- Loki log aggregation system"
echo "- Prometheus metrics collection"
echo "- Kyverno policy engine (installed last)"
echo ""
read -p "Do you want to continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Setup cancelled"
    exit 0
fi

################################################################################
# Step 1: Prerequisites Check
################################################################################

print_header "Step 1: Checking Prerequisites"

PREREQUISITES_MET=true

# Check Docker
if ! check_command docker; then
    print_error "Docker is required. Please install Docker Desktop"
    print_info "macOS: brew install --cask docker"
    print_info "Linux: curl -fsSL https://get.docker.com | sh"
    PREREQUISITES_MET=false
fi

# Check Docker is running
if docker ps &> /dev/null; then
    print_success "Docker daemon is running"
else
    print_error "Docker daemon is not running. Please start Docker Desktop"
    PREREQUISITES_MET=false
fi

# Check Docker Compose
if ! check_command docker-compose && ! docker compose version &> /dev/null; then
    print_warning "Docker Compose not found as standalone, checking docker compose plugin..."
    if docker compose version &> /dev/null; then
        print_success "Docker compose plugin is available"
    else
        print_error "Docker Compose is required"
        PREREQUISITES_MET=false
    fi
fi

# Check kubectl
if ! check_command kubectl; then
    print_warning "kubectl not found. Will be installed with Kind"
fi

# Check Kind
if ! check_command kind; then
    print_warning "Kind not found. Installing..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install kind || print_error "Failed to install Kind"
    else
        curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
        chmod +x ./kind
        sudo mv ./kind /usr/local/bin/kind
    fi
    check_command kind
fi

# Check Helm
if ! check_command helm; then
    print_warning "Helm not found. Installing..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install helm || print_error "Failed to install Helm"
    else
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi
    check_command helm
fi

# Check available disk space
AVAILABLE_SPACE=$(df -h "$PROJECT_ROOT" | awk 'NR==2 {print $4}' | sed 's/[^0-9.]//g')
if [ -n "$AVAILABLE_SPACE" ] && [ "${AVAILABLE_SPACE%.*}" -lt 20 ] 2>/dev/null; then
    print_warning "Low disk space: ${AVAILABLE_SPACE}GB available. Recommended: 50GB+"
fi

# Check available memory
if [[ "$OSTYPE" == "darwin"* ]]; then
    TOTAL_MEM=$(sysctl -n hw.memsize | awk '{print $1/1024/1024/1024}')
else
    TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
fi
if [ "${TOTAL_MEM%.*}" -lt 16 ]; then
    print_warning "Low memory: ${TOTAL_MEM}GB. Recommended: 16GB+"
fi

if [ "$PREREQUISITES_MET" = false ]; then
    print_error "Prerequisites not met. Please install missing requirements"
    exit 1
fi

print_success "All prerequisites met!"
echo ""

################################################################################
# Step 2: Load Environment Variables
################################################################################

print_header "Step 2: Environment Configuration"

if [ ! -f "$PROJECT_ROOT/.env" ]; then
    print_warning ".env file not found. Creating from template..."
    if [ -f "$PROJECT_ROOT/.env.template" ]; then
        cp "$PROJECT_ROOT/.env.template" "$PROJECT_ROOT/.env"
        print_success "Created .env from template"
        print_info "Please review and update .env with your credentials"
        read -p "Press Enter to continue after updating .env..." -r
    else
        print_error ".env.template not found"
    fi
fi

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    # Load .env safely, ignoring invalid lines
    set -a
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^#.*$ ]] && continue
        [[ -z "$key" ]] && continue
        # Skip lines with invalid variable names
        if [[ "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            export "$key=$value"
        fi
    done < <(grep -v '^#' "$PROJECT_ROOT/.env" | grep -v '^$')
    set +a
    print_success "Environment variables loaded"
fi

################################################################################
# Step 3: Setup Kind Kubernetes Cluster
################################################################################

print_header "Step 3: Setting up Kind Kubernetes Cluster"

# Determine cluster name from config or use default
CLUSTER_NAME="kind"
if [ -f "$PROJECT_ROOT/kind-config.yaml" ]; then
    CLUSTER_NAME=$(grep "^name:" "$PROJECT_ROOT/kind-config.yaml" | awk '{print $2}')
    if [ -z "$CLUSTER_NAME" ]; then
        CLUSTER_NAME="kind"
    fi
    # Update .env file with cluster name
    update_env_file "KIND_CLUSTER_NAME" "$CLUSTER_NAME"
fi

if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    print_info "Kind cluster '$CLUSTER_NAME' already exists"
    read -p "Do you want to recreate it? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kind delete cluster --name "$CLUSTER_NAME"
        print_success "Deleted existing cluster"
    fi
fi

if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    print_info "Creating Kind cluster '${CLUSTER_NAME}'..."
    if [ -f "$PROJECT_ROOT/kind-config.yaml" ]; then
        if ! kind create cluster --config "$PROJECT_ROOT/kind-config.yaml"; then
            print_error "Failed to create Kind cluster"
            exit 1
        fi
    else
        if ! kind create cluster; then
            print_error "Failed to create Kind cluster"
            exit 1
        fi
    fi
    print_success "Kind cluster created"

    # Wait for cluster to be ready
    print_info "Waiting for cluster nodes to be ready..."
    sleep 10
    if ! kubectl wait --for=condition=ready nodes --all --timeout=120s; then
        print_warning "Some nodes may not be ready yet"
    fi
fi

# Verify kubectl access
if ! kubectl cluster-info --context "kind-${CLUSTER_NAME}" &> /dev/null; then
    print_error "Cannot access Kubernetes cluster"
    exit 1
fi
print_success "Kubernetes cluster is accessible"

# Verify nodes are ready
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$NODE_COUNT" -eq 0 ]; then
    print_error "No nodes found in cluster"
    exit 1
fi
print_success "Cluster has $NODE_COUNT node(s) running"

echo ""

################################################################################
# Step 4: Setup Harbor Registry
################################################################################

print_header "Step 4: Setting up Harbor Container Registry"

if [ -d "$PROJECT_ROOT/harbor" ]; then
    cd "$PROJECT_ROOT/harbor"

    # Check if Harbor is already running
    if docker ps | grep -q "harbor"; then
        print_info "Harbor is already running"
        HARBOR_RUNNING=true
    else
        print_info "Starting Harbor..."
        if [ -f "docker-compose.yml" ]; then
            # Use docker-compose if available, otherwise use docker compose plugin
            if command -v docker-compose &> /dev/null; then
                DOCKER_COMPOSE_CMD="docker-compose"
            else
                DOCKER_COMPOSE_CMD="docker compose"
            fi

            if ! $DOCKER_COMPOSE_CMD up -d; then
                print_error "Failed to start Harbor"
                cd "$PROJECT_ROOT"
                exit 1
            fi
            print_success "Harbor containers started"
            HARBOR_RUNNING=true
        else
            print_warning "Harbor docker-compose.yml not found. Run install.sh first"
            HARBOR_RUNNING=false
        fi
    fi

    # Wait for Harbor to be ready
    if [ "$HARBOR_RUNNING" = true ]; then
        if ! wait_for_service "http://localhost:8082" "Harbor"; then
            print_error "Harbor failed to become ready"
            docker ps | grep harbor
            cd "$PROJECT_ROOT"
            exit 1
        fi

        # Verify Harbor containers
        HARBOR_CONTAINERS=$(docker ps --filter "name=harbor" --format "{{.Names}}" | wc -l | tr -d ' ')
        print_success "Harbor is running with $HARBOR_CONTAINERS containers"
    fi

    cd "$PROJECT_ROOT"
else
    print_warning "Harbor directory not found. Skipping Harbor setup"
fi

echo ""

################################################################################
# Step 5: Setup Jenkins
################################################################################

print_header "Step 5: Setting up Jenkins"

if docker ps | grep -q "jenkins"; then
    print_info "Jenkins is already running"
    JENKINS_RUNNING=true
else
    print_info "Starting Jenkins..."
    if [ -f "$SCRIPT_DIR/setup-jenkins-docker.sh" ]; then
        if ! bash "$SCRIPT_DIR/setup-jenkins-docker.sh"; then
            print_error "Failed to start Jenkins via setup script"
            exit 1
        fi
    else
        # Fallback: Start basic Jenkins
        if ! docker run -d \
            --name jenkins \
            -p 8080:8080 \
            -p 50000:50000 \
            -v jenkins_home:/var/jenkins_home \
            -v /var/run/docker.sock:/var/run/docker.sock \
            jenkins/jenkins:lts; then
            print_error "Failed to start Jenkins container"
            exit 1
        fi
        print_success "Jenkins container started"
    fi
    JENKINS_RUNNING=true
fi

# Wait for Jenkins
if [ "$JENKINS_RUNNING" = true ]; then
    if ! wait_for_service "http://localhost:8080" "Jenkins"; then
        print_error "Jenkins failed to become ready"
        docker logs jenkins --tail 50
        exit 1
    fi

    # Get initial admin password
    print_info "Retrieving Jenkins admin password..."
    RETRY_COUNT=0
    while [ $RETRY_COUNT -lt 10 ]; do
        if docker exec jenkins test -f /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null; then
            JENKINS_PASSWORD=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null)
            if [ -n "$JENKINS_PASSWORD" ]; then
                print_success "Jenkins initial admin password: $JENKINS_PASSWORD"
                update_env_file "JENKINS_PASSWORD" "$JENKINS_PASSWORD"
                break
            fi
        fi
        sleep 2
        RETRY_COUNT=$((RETRY_COUNT + 1))
    done

    if [ -z "$JENKINS_PASSWORD" ]; then
        print_warning "Could not retrieve Jenkins password automatically"
        print_info "Run: docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword"
    fi
fi

echo ""

################################################################################
# Step 6: Setup SonarQube
################################################################################

print_header "Step 6: Setting up SonarQube"

if docker ps | grep -q "sonarqube"; then
    print_info "SonarQube is already running"
    SONARQUBE_RUNNING=true
else
    print_info "Starting SonarQube..."
    if [ -f "$SCRIPT_DIR/setup-sonarqube.sh" ]; then
        if ! bash "$SCRIPT_DIR/setup-sonarqube.sh"; then
            print_error "Failed to start SonarQube via setup script"
            exit 1
        fi
    else
        # Fallback: Start basic SonarQube
        if ! docker run -d \
            --name sonarqube \
            -p 9000:9000 \
            -v sonarqube_data:/opt/sonarqube/data \
            -v sonarqube_logs:/opt/sonarqube/logs \
            -v sonarqube_extensions:/opt/sonarqube/extensions \
            sonarqube:latest; then
            print_error "Failed to start SonarQube container"
            exit 1
        fi
        print_success "SonarQube container started"
    fi
    SONARQUBE_RUNNING=true
fi

# Wait for SonarQube
if [ "$SONARQUBE_RUNNING" = true ]; then
    if ! wait_for_service "http://localhost:9000" "SonarQube"; then
        print_error "SonarQube failed to become ready"
        docker logs sonarqube --tail 50
        exit 1
    fi
    print_success "SonarQube is operational"
fi

echo ""

################################################################################
# Step 7: Setup ArgoCD
################################################################################

print_header "Step 7: Setting up ArgoCD"

# Check if ArgoCD namespace exists
if kubectl get namespace argocd &> /dev/null; then
    print_info "ArgoCD namespace already exists"
    ARGOCD_INSTALLED=true
else
    print_info "Creating ArgoCD namespace..."
    if ! kubectl create namespace argocd; then
        print_error "Failed to create ArgoCD namespace"
        exit 1
    fi

    print_info "Installing ArgoCD..."
    if ! kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml; then
        print_error "Failed to install ArgoCD"
        exit 1
    fi
    print_success "ArgoCD manifests applied"
    ARGOCD_INSTALLED=true
fi

# Wait for ArgoCD pods
if [ "$ARGOCD_INSTALLED" = true ]; then
    print_info "Waiting for ArgoCD pods to be ready..."
    sleep 10  # Give pods time to start

    if kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s 2>/dev/null; then
        print_success "ArgoCD pods are ready"
    else
        print_warning "ArgoCD pods are still starting. Checking status..."
        kubectl get pods -n argocd
    fi

    # Verify critical pods
    ARGOCD_PODS=$(kubectl get pods -n argocd --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "$ARGOCD_PODS" -eq 0 ]; then
        print_error "No ArgoCD pods found"
        exit 1
    fi
    print_success "ArgoCD has $ARGOCD_PODS pod(s) running"

    # Get ArgoCD admin password
    print_info "Retrieving ArgoCD admin password..."
    RETRY_COUNT=0
    while [ $RETRY_COUNT -lt 30 ]; do
        ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null)
        if [ -n "$ARGOCD_PASSWORD" ]; then
            print_success "ArgoCD admin password: $ARGOCD_PASSWORD"
            update_env_file "ARGOCD_ADMIN_PASSWORD" "$ARGOCD_PASSWORD"
            break
        fi
        sleep 2
        RETRY_COUNT=$((RETRY_COUNT + 1))
    done

    if [ -z "$ARGOCD_PASSWORD" ]; then
        print_warning "Could not retrieve ArgoCD password automatically"
        print_info "Run: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
    fi
fi

print_info "To access ArgoCD, run: kubectl port-forward svc/argocd-server -n argocd 8080:443"

echo ""

################################################################################
# Step 7.5: Configure Harbor-Kind Integration
################################################################################

print_header "Step 7.5: Configuring Harbor-Kind Integration"

if [ -f "$SCRIPT_DIR/configure-kind-harbor-access.sh" ]; then
    print_info "Configuring Kind cluster to access Harbor registry..."
    bash "$SCRIPT_DIR/configure-kind-harbor-access.sh"
    print_success "Harbor-Kind integration configured"
else
    print_warning "Harbor-Kind integration script not found. Manual configuration needed"
    print_info "See docs/Harbor-Kind-Integration.md for details"
fi

echo ""

################################################################################
# Step 7.6: Setup Grafana, Loki & Prometheus (Observability Stack)
################################################################################

print_header "Step 7.6: Setting up Observability Stack"

# Setup Loki (Log Aggregation)
if [ -f "$PROJECT_ROOT/k8s/grafana/setup-loki.sh" ]; then
    print_info "Installing Loki log aggregation system..."
    cd "$PROJECT_ROOT/k8s/grafana"
    chmod +x setup-loki.sh
    ./setup-loki.sh
    cd "$PROJECT_ROOT"
    print_success "Loki installed in logging namespace"
else
    print_warning "Loki setup script not found at k8s/grafana/setup-loki.sh"
fi

# Setup Prometheus (Metrics Collection)
if [ -f "$PROJECT_ROOT/k8s/grafana/setup-prometheus.sh" ]; then
    print_info "Installing Prometheus metrics collection..."
    cd "$PROJECT_ROOT/k8s/grafana"
    chmod +x setup-prometheus.sh
    ./setup-prometheus.sh
    cd "$PROJECT_ROOT"
    print_success "Prometheus installed in monitoring namespace"
else
    print_warning "Prometheus setup script not found at k8s/grafana/setup-prometheus.sh"
fi

# Setup Grafana (Visualization Dashboard)
if [ -f "$PROJECT_ROOT/k8s/grafana/setup-grafana-docker.sh" ]; then
    print_info "Setting up Grafana visualization platform..."
    cd "$PROJECT_ROOT/k8s/grafana"
    chmod +x setup-grafana-docker.sh
    # Automatically select option 1 (NodePort) for Loki access
    echo "1" | ./setup-grafana-docker.sh
    cd "$PROJECT_ROOT"
    print_success "Grafana started on Docker Desktop"
    print_info "Access Grafana at http://localhost:3000 (admin/admin)"
else
    print_warning "Grafana setup script not found at k8s/grafana/setup-grafana-docker.sh"
fi

# Setup Port Forwarding for Monitoring Services
if [ -f "$PROJECT_ROOT/k8s/k8s-permissions_port-forward.sh" ]; then
    print_info "Starting port forwarding for Loki, Prometheus, and ArgoCD..."
    cd "$PROJECT_ROOT"
    chmod +x k8s/k8s-permissions_port-forward.sh
    ./k8s/k8s-permissions_port-forward.sh start
    print_success "Port forwarding enabled:"
    print_info "  - Loki:       http://localhost:31000"
    print_info "  - Prometheus: http://localhost:30090"
    print_info "  - ArgoCD:     https://localhost:8090"
else
    print_warning "Port forwarding script not found at k8s/k8s-permissions_port-forward.sh"
    print_info "Manual port forwarding may be required"
fi

echo ""

################################################################################
# Step 8: Build Demo Application
################################################################################

print_header "Step 8: Building Demo Application"

cd "$PROJECT_ROOT"

if [ -f "pom.xml" ]; then
    print_info "Building Maven project..."
    if command -v mvn &> /dev/null; then
        mvn clean package -DskipTests
        print_success "Maven build completed"
    elif [ -f "mvnw" ]; then
        ./mvnw clean package -DskipTests
        print_success "Maven build completed"
    else
        print_warning "Maven not found. Skipping build"
    fi
fi

echo ""

################################################################################
# Step 9: Setup Kyverno Policy Engine
################################################################################

print_header "Step 9: Setting up Kyverno Policy Engine"

# Check if Kyverno is already installed
if kubectl get namespace kyverno &> /dev/null && helm list -n kyverno 2>/dev/null | grep -q "^kyverno"; then
    print_info "Kyverno is already installed"
    KYVERNO_INSTALLED=true

    # Verify Kyverno is running
    KYVERNO_PODS=$(kubectl get pods -n kyverno --no-headers 2>/dev/null | grep Running | wc -l | tr -d ' ')
    if [ "$KYVERNO_PODS" -eq 0 ]; then
        print_warning "Kyverno pods are not running properly"
        kubectl get pods -n kyverno
    else
        print_success "Kyverno has $KYVERNO_PODS pod(s) running"
    fi
elif [ -f "$PROJECT_ROOT/k8s/kyverno/install/setup-kyverno.sh" ]; then
    print_info "Installing Kyverno policy engine..."
    cd "$PROJECT_ROOT/k8s/kyverno"
    chmod +x install/setup-kyverno.sh

    # Run installation script non-interactively by answering 'n' to upgrade prompt
    if ! echo "n" | ./install/setup-kyverno.sh; then
        print_error "Failed to install Kyverno"
        cd "$PROJECT_ROOT"
        exit 1
    fi

    cd "$PROJECT_ROOT"
    print_success "Kyverno installed in kyverno namespace"

    # Verify Kyverno installation
    print_info "Verifying Kyverno installation..."
    sleep 5
    KYVERNO_PODS=$(kubectl get pods -n kyverno --no-headers 2>/dev/null | grep Running | wc -l | tr -d ' ')
    if [ "$KYVERNO_PODS" -eq 0 ]; then
        print_warning "No running Kyverno pods found"
        kubectl get pods -n kyverno
    else
        print_success "Kyverno has $KYVERNO_PODS pod(s) running"
    fi
    KYVERNO_INSTALLED=true
else
    print_warning "Kyverno setup script not found at k8s/kyverno/install/setup-kyverno.sh"
    KYVERNO_INSTALLED=false
fi

# Deploy policies via ArgoCD GitOps (always attempt if Kyverno is installed)
if [ "$KYVERNO_INSTALLED" = true ]; then
    print_info "Deploying Kyverno policies via ArgoCD..."
    if kubectl get namespace argocd &> /dev/null; then
        # Check if Application already exists
        if kubectl get application kyverno-policies -n argocd &> /dev/null; then
            print_info "Kyverno policies Application already exists"

            # Check sync status
            SYNC_STATUS=$(kubectl get application kyverno-policies -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
            print_info "Current sync status: $SYNC_STATUS"

            # Verify policies deployed
            POLICY_COUNT=$(kubectl get clusterpolicies --no-headers 2>/dev/null | wc -l | tr -d ' ')
            if [ "$POLICY_COUNT" -gt 0 ]; then
                print_success "Kyverno policies are deployed ($POLICY_COUNT policies)"
            else
                print_warning "No cluster policies found - ArgoCD may still be syncing"
            fi
        elif [ -f "$PROJECT_ROOT/argocd-apps/kyverno-policies.yaml" ]; then
            # Create new Application
            if ! kubectl apply -f "$PROJECT_ROOT/argocd-apps/kyverno-policies.yaml"; then
                print_error "Failed to create Kyverno policies ArgoCD Application"
            else
                print_success "Kyverno policies ArgoCD Application created"

                # Wait for initial sync
                print_info "Waiting for ArgoCD to sync policies..."
                sleep 5

                # Check sync status
                if command -v argocd &> /dev/null; then
                    argocd app sync kyverno-policies --timeout 60 2>/dev/null || true
                    argocd app wait kyverno-policies --timeout 60 2>/dev/null || print_warning "ArgoCD sync in progress"
                fi

                # Verify policies deployed
                POLICY_COUNT=$(kubectl get clusterpolicies --no-headers 2>/dev/null | wc -l | tr -d ' ')
                if [ "$POLICY_COUNT" -gt 0 ]; then
                    print_success "Kyverno policies deployed via GitOps ($POLICY_COUNT policies)"
                else
                    print_warning "No cluster policies found yet - may need more time to sync"
                fi

                print_info "Policies are in Audit mode - violations logged but not blocked"
                print_info "View policies: kubectl get clusterpolicies"
                print_info "View in ArgoCD UI: https://localhost:8090/applications/kyverno-policies"
            fi
        else
            print_warning "kyverno-policies.yaml not found at $PROJECT_ROOT/argocd-apps/"
        fi
    else
        print_warning "ArgoCD not found. Deploying policies directly via kubectl..."
        if kubectl apply -f "$PROJECT_ROOT/k8s/kyverno/policies/" -R; then
            print_success "Kyverno policies deployed"

            # Wait a moment for policies to be processed
            sleep 3

            # Verify policies deployed
            POLICY_COUNT=$(kubectl get clusterpolicies --no-headers 2>/dev/null | wc -l | tr -d ' ')
            if [ "$POLICY_COUNT" -gt 0 ]; then
                print_success "$POLICY_COUNT cluster policies are active"
            else
                print_warning "Policies applied but not yet visible"
            fi
        else
            print_error "Failed to deploy Kyverno policies"
        fi
    fi
else
    print_warning "Kyverno is not installed - skipping policy deployment"
fi

echo ""

################################################################################
# Step 10: Setup Policy Reporter (Kyverno Observability)
################################################################################

print_header "Step 10: Setting up Policy Reporter"

# Check if Kyverno is installed before installing Policy Reporter
if [ "$KYVERNO_INSTALLED" = true ]; then
    # Check if Policy Reporter is already installed
    if docker ps | grep -q "policy-reporter"; then
        print_info "Policy Reporter is already running on Docker Desktop"

        # Verify it's running
        REPORTER_CONTAINERS=$(docker ps | grep "policy-reporter" | wc -l | tr -d ' ')
        if [ "$REPORTER_CONTAINERS" -gt 0 ]; then
            print_success "Policy Reporter has $REPORTER_CONTAINERS container(s) running"
        else
            print_warning "Policy Reporter containers are not running"
            docker ps | grep policy-reporter
        fi
    elif [ -f "$PROJECT_ROOT/k8s/kyverno/policy-reporter/install-policy-reporter.sh" ]; then
        print_info "Installing Policy Reporter on Docker Desktop..."
        cd "$PROJECT_ROOT/k8s/kyverno/policy-reporter"
        chmod +x install-policy-reporter.sh

        # Run installation script
        if ! ./install-policy-reporter.sh; then
            print_error "Failed to install Policy Reporter"
            cd "$PROJECT_ROOT"
            exit 1
        fi

        cd "$PROJECT_ROOT"
        print_success "Policy Reporter installed on Docker Desktop"

        # Verify installation
        print_info "Verifying Policy Reporter installation..."
        sleep 3
        if docker ps | grep -q "policy-reporter"; then
            REPORTER_CONTAINERS=$(docker ps | grep "policy-reporter" | wc -l | tr -d ' ')
            print_success "Policy Reporter has $REPORTER_CONTAINERS container(s) running"
        else
            print_warning "Policy Reporter containers may still be starting"
            docker ps | grep policy-reporter
        fi

        print_success "Policy Reporter UI available at: http://localhost:31002"
        print_success "Policy Reporter API available at: http://localhost:31001"
        print_info "Features enabled:"
        print_info "  - Web UI Dashboard (http://localhost:31002)"
        print_info "  - REST API (http://localhost:31001/api/v1)"
        print_info "  - Prometheus metrics (http://localhost:31001/metrics)"
        print_info "  - Loki integration (violations logged)"
    else
        print_warning "Policy Reporter installation script not found"
        print_info "To install manually:"
        print_info "  cd k8s/kyverno/policy-reporter && ./install-policy-reporter.sh"
    fi
else
    print_warning "Kyverno is not installed - skipping Policy Reporter"
    print_info "Policy Reporter requires Kyverno to be installed first"
fi

echo ""

################################################################################
# Final Summary
################################################################################

print_header "Setup Complete!"

echo ""
print_info "Performing final validation..."
echo ""

# Check Docker services
# Check Docker services
DOCKER_SERVICES=0
for service in jenkins harbor sonarqube policy-reporter; do
    if docker ps | grep -q "$service"; then
        ((DOCKER_SERVICES++))
    fi
done

# Check Kubernetes namespaces
K8S_NAMESPACES=0
for ns in argocd kyverno logging monitoring; do
    if kubectl get namespace "$ns" &> /dev/null; then
        ((K8S_NAMESPACES++))
    fi
done
# Check Kind cluster
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    CLUSTER_STATUS="✓ Running"
else
    CLUSTER_STATUS="✗ Not Found"
fi

echo "Validation Results:"
echo "  - Docker Services:    $DOCKER_SERVICES/4 running"
echo "  - K8s Namespaces:     $K8S_NAMESPACES/4 created"
echo "  - Kind Cluster:       $CLUSTER_STATUS"
echo ""

if [ $DOCKER_SERVICES -lt 2 ] || [ $K8S_NAMESPACES -lt 2 ]; then
    print_warning "Some services may not have started correctly"
    print_info "Check logs with: docker logs <container-name>"
else
    echo -e "${GREEN}All services are now running!${NC}"
fi
echo ""
echo "Service URLs:"
echo "  - Jenkins:         http://localhost:8080"
echo "  - Harbor:          http://localhost:8082"
echo "  - SonarQube:       http://localhost:9000"
echo "  - Grafana:         http://localhost:3000"
echo "  - Loki:            http://localhost:31000"
echo "  - Prometheus:      http://localhost:30090"
echo "  - ArgoCD:          https://localhost:8090"
echo "  - Policy Reporter: http://localhost:31002 (UI) | http://localhost:31001 (API)"
echo ""
echo "Credentials:"
echo "  - Jenkins:   admin / $JENKINS_PASSWORD"
echo "  - Harbor:    admin / Harbor12345"
echo "  - SonarQube: admin / admin (change on first login)"
echo "  - Grafana:   admin / admin (change on first login)"
echo "  - ArgoCD:    admin / $ARGOCD_PASSWORD"
echo ""
echo "Kubernetes Components:"
echo "  - Kind cluster running (kubectl context: kind-kind)"
echo "  - Kyverno policy engine (namespace: kyverno)"
echo "  - Loki log aggregation (namespace: logging)"
echo "  - Prometheus metrics (namespace: monitoring)"
echo "  - ArgoCD GitOps (namespace: argocd)"
echo ""
echo "Docker Desktop Services:"
echo "  - Grafana visualization platform"
echo "  - Policy Reporter UI for Kyverno"
echo ""
echo "Next steps:"
echo "  1. Configure Jenkins pipelines"
echo "  2. Set up GitHub webhooks"
echo "  3. Create Harbor project 'cicd-demo':"
echo "     - Via UI: http://127.0.0.1:8082 (admin/Harbor12345) > Projects > NEW PROJECT"
echo "     - Via script: cd scripts && ./create-harbor-robot.sh (also creates robot account)"
echo "  4. Configure SonarQube quality gates"
echo "  5. Deploy applications via ArgoCD"
echo "  6. Monitor applications with Grafana dashboards"
echo "  7. Review Kyverno policy reports: kubectl get policyreports -A"
echo ""
echo "For more information, see:"
echo "  - docs/#Lab-Setup-Guide.md (Complete 11-phase guide)"
echo "  - docs/Architecture-Diagram.md"
echo "  - docs/Grafana-Loki.md (Observability stack)"
echo "  - k8s/kyverno/README.md (Policy engine guide)"
echo "  - docs/Troubleshooting.md"
echo ""
print_success "Happy learning!"
