#!/bin/bash

################################################################################
# DevOps CI/CD Lab - Complete Cleanup Script
# Tears down all services and optionally removes data
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

################################################################################
# Main Cleanup
################################################################################

print_header "DevOps CI/CD Lab Cleanup"
echo ""
echo "This script will remove:"
echo "  - All running containers (Jenkins, Harbor, SonarQube)"
echo "  - Kind Kubernetes cluster"
echo "  - ArgoCD deployments"
echo ""

# Ask for confirmation
read -p "Do you want to continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Cleanup cancelled"
    exit 0
fi

# Ask about data removal
echo ""
read -p "Do you want to remove all data volumes? (y/n) " -n 1 -r
echo ""
REMOVE_VOLUMES=$REPLY

################################################################################
# Step 1: Stop Kind Cluster
################################################################################

print_header "Step 1: Removing Kind Kubernetes Cluster"

if command -v kind &> /dev/null; then
    # Get cluster name from kind-config.yaml or detect running clusters
    CLUSTER_NAME=""
    if [ -f "$PROJECT_ROOT/kind-config.yaml" ]; then
        CLUSTER_NAME=$(grep "^name:" "$PROJECT_ROOT/kind-config.yaml" | awk '{print $2}')
    fi

    # If no config or name not found, get all clusters
    CLUSTERS=$(kind get clusters 2>/dev/null || true)

    if [ -n "$CLUSTERS" ]; then
        # If we have a specific cluster name from config, delete it
        if [ -n "$CLUSTER_NAME" ] && echo "$CLUSTERS" | grep -q "^${CLUSTER_NAME}$"; then
            print_info "Deleting Kind cluster '$CLUSTER_NAME'..."
            kind delete cluster --name "$CLUSTER_NAME"
            print_success "Kind cluster '$CLUSTER_NAME' deleted"

            # Clean up kubeconfig
            kubectl config delete-context "kind-${CLUSTER_NAME}" 2>/dev/null || true
            kubectl config delete-cluster "kind-${CLUSTER_NAME}" 2>/dev/null || true
            print_success "Cleaned up kubeconfig"
        else
            # Delete all found clusters
            print_info "Found clusters: $CLUSTERS"
            for cluster in $CLUSTERS; do
                print_info "Deleting Kind cluster '$cluster'..."
                kind delete cluster --name "$cluster"
                print_success "Kind cluster '$cluster' deleted"

                # Clean up kubeconfig
                kubectl config delete-context "kind-${cluster}" 2>/dev/null || true
                kubectl config delete-cluster "kind-${cluster}" 2>/dev/null || true
            done
            print_success "Cleaned up kubeconfig"
        fi
    else
        print_info "No Kind clusters found"
    fi
else
    print_warning "Kind command not found"
fi

echo ""

################################################################################
# Step 2: Stop Jenkins
################################################################################

print_header "Step 2: Stopping Jenkins"

if docker ps -a | grep -q "jenkins"; then
    print_info "Stopping Jenkins..."
    docker stop jenkins 2>/dev/null || true
    docker rm jenkins 2>/dev/null || true
    print_success "Jenkins stopped and removed"

    if [[ $REMOVE_VOLUMES =~ ^[Yy]$ ]]; then
        print_info "Removing Jenkins volume..."
        docker volume rm jenkins_home 2>/dev/null || true
        print_success "Jenkins volume removed"
    fi
else
    print_info "Jenkins not running"
fi

echo ""

################################################################################
# Step 3: Stop Harbor
################################################################################

print_header "Step 3: Stopping Harbor"

if [ -d "$PROJECT_ROOT/harbor" ]; then
    cd "$PROJECT_ROOT/harbor"

    if docker ps | grep -q "harbor"; then
        print_info "Stopping Harbor..."
        if [[ $REMOVE_VOLUMES =~ ^[Yy]$ ]]; then
            docker-compose down -v
            print_success "Harbor stopped and volumes removed"
        else
            docker-compose down
            print_success "Harbor stopped (volumes preserved)"
        fi
    else
        print_info "Harbor not running"
    fi

    cd "$PROJECT_ROOT"
else
    print_info "Harbor directory not found"
fi

echo ""

################################################################################
# Step 4: Stop SonarQube
################################################################################

print_header "Step 4: Stopping SonarQube"

# Check if SonarQube was deployed via docker-compose
if [ -f "$SCRIPT_DIR/sonar-compose.yml" ]; then
    if docker ps -a | grep -q "sonar"; then
        print_info "Stopping SonarQube (docker-compose)..."
        cd "$SCRIPT_DIR"
        if [[ $REMOVE_VOLUMES =~ ^[Yy]$ ]]; then
            docker-compose -f sonar-compose.yml down -v
            print_success "SonarQube stopped and volumes removed"
        else
            docker-compose -f sonar-compose.yml down
            print_success "SonarQube stopped (volumes preserved)"
        fi
        cd "$PROJECT_ROOT"
    else
        print_info "SonarQube not running"
    fi
# Fallback to standalone container cleanup
elif docker ps -a | grep -q "sonarqube"; then
    print_info "Stopping SonarQube..."
    docker stop sonarqube 2>/dev/null || true
    docker rm sonarqube 2>/dev/null || true
    print_success "SonarQube stopped and removed"

    if [[ $REMOVE_VOLUMES =~ ^[Yy]$ ]]; then
        print_info "Removing SonarQube volumes..."
        docker volume rm sonarqube_data 2>/dev/null || true
        docker volume rm sonarqube_logs 2>/dev/null || true
        docker volume rm sonarqube_extensions 2>/dev/null || true
        print_success "SonarQube volumes removed"
    fi
else
    print_info "SonarQube not running"
fi

echo ""

################################################################################
# Step 5: Clean Docker Resources
################################################################################

print_header "Step 5: Cleaning Docker Resources"

# Remove stopped containers
STOPPED_CONTAINERS=$(docker ps -a -q -f status=exited 2>/dev/null || true)
if [ -n "$STOPPED_CONTAINERS" ]; then
    print_info "Removing stopped containers..."
    docker rm $STOPPED_CONTAINERS 2>/dev/null || true
    print_success "Stopped containers removed"
fi

if [[ $REMOVE_VOLUMES =~ ^[Yy]$ ]]; then
    print_info "Pruning volumes..."
    docker volume prune -f
    print_success "Unused volumes removed"
fi

# Prune networks
print_info "Pruning networks..."
docker network prune -f
print_success "Unused networks removed"

# Optional: Remove images
echo ""
read -p "Do you want to remove Docker images? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "Removing images..."
    docker image prune -a -f
    print_success "Unused images removed"
fi

echo ""

################################################################################
# Step 6: Clean Build Artifacts
################################################################################

print_header "Step 6: Cleaning Build Artifacts"

cd "$PROJECT_ROOT"

if [ -d "target" ]; then
    print_info "Removing Maven target directory..."
    rm -rf target/
    print_success "Maven artifacts removed"
fi

if [ -d ".mvn" ]; then
    print_info "Removing Maven wrapper..."
    rm -rf .mvn/
    rm -f mvnw mvnw.cmd
    print_success "Maven wrapper removed"
fi

echo ""

################################################################################
# Step 7: Optional - Clean Configuration
################################################################################

print_header "Step 7: Configuration Cleanup"

echo ""
read -p "Do you want to remove .env file? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -f "$PROJECT_ROOT/.env" ]; then
        rm "$PROJECT_ROOT/.env"
        print_success ".env file removed"
    fi
fi

echo ""

################################################################################
# Verification
################################################################################

print_header "Verification"

# Check containers
RUNNING_CONTAINERS=$(docker ps --format "{{.Names}}" | grep -E "jenkins|harbor|sonarqube|kind" || true)
if [ -z "$RUNNING_CONTAINERS" ]; then
    print_success "No lab containers running"
else
    print_warning "Some containers still running: $RUNNING_CONTAINERS"
fi

# Check Kind clusters
if command -v kind &> /dev/null; then
    KIND_CLUSTERS=$(kind get clusters 2>/dev/null || true)
    if [ -z "$KIND_CLUSTERS" ]; then
        print_success "No Kind clusters found"
    else
        print_warning "Kind clusters still exist: $KIND_CLUSTERS"
    fi
fi

# Check disk space recovered
echo ""
print_info "Docker disk usage:"
docker system df

echo ""

################################################################################
# Summary
################################################################################

print_header "Cleanup Complete!"

echo ""
echo -e "${GREEN}Successfully cleaned up the lab environment${NC}"
echo ""
echo "What was removed:"
echo "  ✓ Kind Kubernetes cluster"
echo "  ✓ Jenkins container"
echo "  ✓ Harbor container"
echo "  ✓ SonarQube container"
echo "  ✓ Docker networks"

if [[ $REMOVE_VOLUMES =~ ^[Yy]$ ]]; then
    echo "  ✓ All data volumes"
fi

echo ""
echo "What was preserved:"
echo "  - Docker images (if you chose not to remove them)"
echo "  - Source code and configuration files"
echo "  - Documentation"
if [[ ! $REMOVE_VOLUMES =~ ^[Yy]$ ]]; then
    echo "  - Data volumes (for faster restart)"
fi

echo ""
echo "To start fresh:"
echo "  ./scripts/setup-all.sh"
echo ""
print_success "Cleanup finished!"
