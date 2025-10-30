#!/bin/bash

################################################################################
# DevOps CI/CD Lab - Environment Verification Script
# Checks all prerequisites before setup
################################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

################################################################################
# Functions
################################################################################

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

check_pass() {
    echo -e "${GREEN}✓ $1${NC}"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
}

check_fail() {
    echo -e "${RED}✗ $1${NC}"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
}

check_warn() {
    echo -e "${YELLOW}⚠ $1${NC}"
    CHECKS_WARNING=$((CHECKS_WARNING + 1))
}

check_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_command_exists() {
    local cmd=$1
    local name=$2
    local install_hint=$3

    if command -v "$cmd" &> /dev/null; then
        local version=$("$cmd" --version 2>&1 | head -n 1)
        check_pass "$name is installed: $version"
        return 0
    else
        check_fail "$name is not installed"
        if [ -n "$install_hint" ]; then
            echo "    Install: $install_hint"
        fi
        return 1
    fi
}

check_port_available() {
    local port=$1
    local service=$2

    if lsof -i ":$port" &> /dev/null; then
        local process=$(lsof -i ":$port" | grep LISTEN | awk '{print $1}' | head -1)
        check_warn "Port $port is in use by $process (needed for $service)"
        return 1
    else
        check_pass "Port $port is available ($service)"
        return 0
    fi
}

################################################################################
# Main Verification
################################################################################

print_header "DevOps CI/CD Lab - Environment Verification"
echo ""

################################################################################
# System Information
################################################################################

print_header "System Information"

# OS Detection
OS_TYPE=$(uname -s)
echo "Operating System: $OS_TYPE"

if [[ "$OS_TYPE" == "Darwin" ]]; then
    OS_VERSION=$(sw_vers -productVersion)
    ARCH=$(uname -m)
    echo "macOS Version: $OS_VERSION"
    echo "Architecture: $ARCH"
elif [[ "$OS_TYPE" == "Linux" ]]; then
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "Distribution: $NAME $VERSION"
    fi
    ARCH=$(uname -m)
    echo "Architecture: $ARCH"
fi

echo ""

################################################################################
# Resource Checks
################################################################################

print_header "Resource Requirements"

# Check available disk space
AVAILABLE_SPACE=$(df -h . | awk 'NR==2 {print $4}')
AVAILABLE_SPACE_GB=$(df -k . | awk 'NR==2 {print int($4/1024/1024)}')

echo "Available Disk Space: $AVAILABLE_SPACE"
if [ "$AVAILABLE_SPACE_GB" -ge 50 ]; then
    check_pass "Sufficient disk space (>= 50GB)"
elif [ "$AVAILABLE_SPACE_GB" -ge 20 ]; then
    check_warn "Low disk space. Recommended: 50GB, Available: ${AVAILABLE_SPACE_GB}GB"
else
    check_fail "Insufficient disk space. Minimum: 20GB, Available: ${AVAILABLE_SPACE_GB}GB"
fi

# Check available memory
if [[ "$OS_TYPE" == "Darwin" ]]; then
    TOTAL_MEM_BYTES=$(sysctl -n hw.memsize)
    TOTAL_MEM_GB=$((TOTAL_MEM_BYTES / 1024 / 1024 / 1024))
else
    TOTAL_MEM_GB=$(free -g | awk '/^Mem:/{print $2}')
fi

echo "Total Memory: ${TOTAL_MEM_GB}GB"
if [ "$TOTAL_MEM_GB" -ge 16 ]; then
    check_pass "Sufficient memory (>= 16GB)"
elif [ "$TOTAL_MEM_GB" -ge 8 ]; then
    check_warn "Low memory. Recommended: 16GB, Available: ${TOTAL_MEM_GB}GB"
else
    check_fail "Insufficient memory. Minimum: 8GB, Available: ${TOTAL_MEM_GB}GB"
fi

# Check CPU cores
CPU_CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "unknown")
echo "CPU Cores: $CPU_CORES"
if [ "$CPU_CORES" != "unknown" ] && [ "$CPU_CORES" -ge 4 ]; then
    check_pass "Sufficient CPU cores (>= 4)"
else
    check_warn "Recommended: 4+ CPU cores"
fi

echo ""

################################################################################
# Docker Checks
################################################################################

print_header "Docker Environment"

# Check Docker command
if check_command_exists docker "Docker" "macOS: brew install --cask docker | Linux: curl -fsSL https://get.docker.com | sh"; then

    # Check Docker daemon
    if docker ps &> /dev/null; then
        check_pass "Docker daemon is running"

        # Docker version details
        DOCKER_VERSION=$(docker version --format '{{.Server.Version}}')
        echo "    Docker Version: $DOCKER_VERSION"

        # Check Docker resources
        DOCKER_INFO=$(docker info 2>/dev/null)
        if echo "$DOCKER_INFO" | grep -q "CPUs"; then
            DOCKER_CPUS=$(echo "$DOCKER_INFO" | grep "CPUs" | awk '{print $2}')
            DOCKER_MEM=$(echo "$DOCKER_INFO" | grep "Total Memory" | awk '{print $3 $4}')
            echo "    Docker CPUs: $DOCKER_CPUS"
            echo "    Docker Memory: $DOCKER_MEM"
        fi

    else
        check_fail "Docker daemon is not running. Please start Docker Desktop"
    fi
else
    check_fail "Docker is required"
fi

# Check Docker Compose
if command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version)
    check_pass "Docker Compose: $COMPOSE_VERSION"
elif docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version)
    check_pass "Docker Compose (plugin): $COMPOSE_VERSION"
else
    check_fail "Docker Compose not found"
    echo "    Install: Part of Docker Desktop or 'brew install docker-compose'"
fi

echo ""

################################################################################
# Kubernetes Tools
################################################################################

print_header "Kubernetes Tools"

check_command_exists kubectl "kubectl" "macOS: brew install kubectl | Linux: snap install kubectl --classic"
check_command_exists kind "Kind" "macOS: brew install kind | Linux: curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64"
check_command_exists helm "Helm" "macOS: brew install helm | Linux: curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"

# Check for existing Kind cluster
if command -v kind &> /dev/null; then
    if kind get clusters 2>/dev/null | grep -q "kind"; then
        check_info "Existing Kind cluster found"
    fi
fi

echo ""

################################################################################
# Development Tools
################################################################################

print_header "Development Tools"

check_command_exists git "Git" "macOS: brew install git | Linux: apt-get install git"
check_command_exists java "Java" "Download from: https://adoptium.net/"

if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | head -n 1)
    if echo "$JAVA_VERSION" | grep -q "21"; then
        check_pass "Java 21 detected"
    else
        check_warn "Java 21 recommended for this project"
        echo "    Current: $JAVA_VERSION"
    fi
fi

check_command_exists mvn "Maven" "macOS: brew install maven | Linux: apt-get install maven"

# Optional but useful tools
echo ""
echo "Optional Tools:"
if command -v curl &> /dev/null; then
    check_pass "curl is installed"
else
    check_warn "curl is recommended"
fi

if command -v jq &> /dev/null; then
    check_pass "jq is installed"
else
    check_warn "jq is recommended for JSON processing"
fi

echo ""

################################################################################
# Port Availability
################################################################################

print_header "Port Availability"

check_port_available 8080 "Jenkins / Application / ArgoCD"
check_port_available 8082 "Harbor HTTP"
check_port_available 8443 "Harbor HTTPS"
check_port_available 9000 "SonarQube"
check_port_available 6443 "Kubernetes API"
check_port_available 50000 "Jenkins Agent"

echo ""

################################################################################
# Network Connectivity
################################################################################

print_header "Network Connectivity"

# Check internet connectivity
if ping -c 1 google.com &> /dev/null; then
    check_pass "Internet connectivity"
else
    check_warn "Cannot reach google.com - check internet connection"
fi

# Check Docker Hub
if curl -s https://hub.docker.com &> /dev/null; then
    check_pass "Can reach Docker Hub"
else
    check_warn "Cannot reach Docker Hub"
fi

# Check GitHub
if curl -s https://github.com &> /dev/null; then
    check_pass "Can reach GitHub"
else
    check_warn "Cannot reach GitHub"
fi

# Check Maven Central
if curl -s https://repo.maven.apache.org/maven2/ &> /dev/null; then
    check_pass "Can reach Maven Central"
else
    check_warn "Cannot reach Maven Central"
fi

echo ""

################################################################################
# File System Checks
################################################################################

print_header "Project Files"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# Check key files
if [ -f "pom.xml" ]; then
    check_pass "pom.xml found"
else
    check_warn "pom.xml not found"
fi

if [ -f "Dockerfile" ]; then
    check_pass "Dockerfile found"
else
    check_warn "Dockerfile not found"
fi

if [ -f "Jenkinsfile" ]; then
    check_pass "Jenkinsfile found"
else
    check_warn "Jenkinsfile not found"
fi

if [ -f ".env" ]; then
    check_pass ".env file exists"
elif [ -f ".env.template" ]; then
    check_warn ".env not found but .env.template exists"
    echo "    Run: cp .env.template .env"
else
    check_fail "Neither .env nor .env.template found"
fi

# Check directories
if [ -d "helm-charts" ]; then
    check_pass "helm-charts directory exists"
else
    check_warn "helm-charts directory not found"
fi

if [ -d "k8s" ]; then
    check_pass "k8s directory exists"
else
    check_warn "k8s directory not found"
fi

echo ""

################################################################################
# Summary
################################################################################

print_header "Verification Summary"

echo ""
echo -e "${GREEN}Passed:  $CHECKS_PASSED${NC}"
echo -e "${YELLOW}Warnings: $CHECKS_WARNING${NC}"
echo -e "${RED}Failed:  $CHECKS_FAILED${NC}"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ Environment is ready for setup!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Review and update .env file with your credentials"
    echo "  2. Run: ./scripts/setup-all.sh"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Environment is NOT ready${NC}"
    echo ""
    echo "Please address the failed checks above before running setup."
    echo ""
    echo "Common fixes:"
    echo "  - Install Docker Desktop: https://www.docker.com/products/docker-desktop"
    echo "  - Start Docker Desktop application"
    echo "  - Free up disk space (need at least 20GB)"
    echo "  - Install missing tools using package manager (brew/apt)"
    echo ""
    exit 1
fi
