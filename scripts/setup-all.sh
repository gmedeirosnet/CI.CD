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
        if curl -s -f "$url" > /dev/null 2>&1; then
            print_success "$service_name is ready!"
            return 0
        fi
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done

    print_warning "$service_name not responding after $max_attempts attempts"
    return 1
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
AVAILABLE_SPACE=$(df -h "$PROJECT_ROOT" | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "${AVAILABLE_SPACE%.*}" -lt 20 ]; then
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
    export $(grep -v '^#' "$PROJECT_ROOT/.env" | xargs)
    print_success "Environment variables loaded"
fi

################################################################################
# Step 3: Setup Kind Kubernetes Cluster
################################################################################

print_header "Step 3: Setting up Kind Kubernetes Cluster"

if kind get clusters | grep -q "^kind$"; then
    print_info "Kind cluster already exists"
    read -p "Do you want to recreate it? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kind delete cluster --name kind
        print_success "Deleted existing cluster"
    fi
fi

if ! kind get clusters | grep -q "^kind$"; then
    print_info "Creating Kind cluster..."
    if [ -f "$PROJECT_ROOT/kind-config.yaml" ]; then
        kind create cluster --config "$PROJECT_ROOT/kind-config.yaml"
    else
        kind create cluster
    fi
    print_success "Kind cluster created"
fi

# Verify kubectl access
kubectl cluster-info --context kind-kind
print_success "Kubernetes cluster is accessible"

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
    else
        print_info "Starting Harbor..."
        if [ -f "docker-compose.yml" ]; then
            docker-compose up -d
            print_success "Harbor started"
        else
            print_warning "Harbor docker-compose.yml not found. Run install.sh first"
        fi
    fi

    # Wait for Harbor to be ready
    wait_for_service "http://localhost:8082" "Harbor"

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
else
    print_info "Starting Jenkins..."
    if [ -f "$SCRIPT_DIR/setup-jenkins-docker.sh" ]; then
        bash "$SCRIPT_DIR/setup-jenkins-docker.sh"
    else
        # Fallback: Start basic Jenkins
        docker run -d \
            --name jenkins \
            -p 8080:8080 \
            -p 50000:50000 \
            -v jenkins_home:/var/jenkins_home \
            -v /var/run/docker.sock:/var/run/docker.sock \
            jenkins/jenkins:lts
        print_success "Jenkins started"
    fi
fi

# Wait for Jenkins
wait_for_service "http://localhost:8080" "Jenkins"

# Get initial admin password
if docker exec jenkins test -f /var/jenkins_home/secrets/initialAdminPassword; then
    JENKINS_PASSWORD=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword)
    print_success "Jenkins initial admin password: $JENKINS_PASSWORD"
fi

echo ""

################################################################################
# Step 6: Setup SonarQube
################################################################################

print_header "Step 6: Setting up SonarQube"

if docker ps | grep -q "sonarqube"; then
    print_info "SonarQube is already running"
else
    print_info "Starting SonarQube..."
    if [ -f "$SCRIPT_DIR/setup-sonarqube.sh" ]; then
        bash "$SCRIPT_DIR/setup-sonarqube.sh"
    else
        # Fallback: Start basic SonarQube
        docker run -d \
            --name sonarqube \
            -p 9000:9000 \
            -v sonarqube_data:/opt/sonarqube/data \
            -v sonarqube_logs:/opt/sonarqube/logs \
            -v sonarqube_extensions:/opt/sonarqube/extensions \
            sonarqube:latest
        print_success "SonarQube started"
    fi
fi

# Wait for SonarQube
wait_for_service "http://localhost:9000" "SonarQube"

echo ""

################################################################################
# Step 7: Setup ArgoCD
################################################################################

print_header "Step 7: Setting up ArgoCD"

# Check if ArgoCD namespace exists
if kubectl get namespace argocd &> /dev/null; then
    print_info "ArgoCD namespace already exists"
else
    print_info "Creating ArgoCD namespace..."
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    print_success "ArgoCD installed"
fi

# Wait for ArgoCD pods
print_info "Waiting for ArgoCD pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Get ArgoCD admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
print_success "ArgoCD admin password: $ARGOCD_PASSWORD"

print_info "To access ArgoCD, run: kubectl port-forward svc/argocd-server -n argocd 8080:443"

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
# Final Summary
################################################################################

print_header "Setup Complete!"

echo ""
echo -e "${GREEN}All services are now running!${NC}"
echo ""
echo "Service URLs:"
echo "  - Jenkins:   http://localhost:8080"
echo "  - Harbor:    http://localhost:8082"
echo "  - SonarQube: http://localhost:9000"
echo "  - ArgoCD:    Run 'kubectl port-forward svc/argocd-server -n argocd 8080:443'"
echo ""
echo "Credentials:"
echo "  - Jenkins:   admin / $JENKINS_PASSWORD"
echo "  - Harbor:    admin / Harbor12345"
echo "  - SonarQube: admin / admin (change on first login)"
echo "  - ArgoCD:    admin / $ARGOCD_PASSWORD"
echo ""
echo "Next steps:"
echo "  1. Configure Jenkins pipelines"
echo "  2. Set up GitHub webhooks"
echo "  3. Create Harbor projects"
echo "  4. Configure SonarQube quality gates"
echo "  5. Deploy applications via ArgoCD"
echo ""
echo "For more information, see:"
echo "  - docs/Lab-Setup-Guide.md"
echo "  - docs/Architecture-Diagram.md"
echo "  - docs/Troubleshooting.md"
echo ""
print_success "Happy learning!"
