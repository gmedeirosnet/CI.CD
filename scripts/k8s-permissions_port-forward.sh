#!/usr/bin/env zsh

# Kubernetes Service Port Forwarding & Permissions Script
# Sets up port forwarding for monitoring and logging services
# Fixes Docker socket permissions for Jenkins
# Usage: ./k8s-permissions_port-forward.sh [start|stop|status|restart|fix-docker]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Port forwarding configurations (zsh associative array)
typeset -A PORT_FORWARDS
PORT_FORWARDS=(
    loki "logging:loki:31000:3100"
    prometheus "monitoring:prometheus:30090:9090"
    argocd "argocd:argocd-server:8081:80"
)

# PID file location
PID_DIR="/tmp/k8s-port-forward"
mkdir -p "$PID_DIR"

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}✗ kubectl not found${NC}"
        echo "Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
}

# Function to check if service exists
check_service() {
    local namespace=$1
    local service=$2

    if ! kubectl get svc -n "$namespace" "$service" &> /dev/null; then
        echo -e "${YELLOW}⚠ Service $service not found in namespace $namespace${NC}"
        return 1
    fi
    return 0
}

# Function to start port forwarding
start_port_forward() {
    local name=$1
    local config=$2

    IFS=':' read -r namespace service local_port remote_port <<< "$config"

    # Check if already running
    local pid_file="$PID_DIR/${name}.pid"
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        echo -e "${YELLOW}⚠ Port forward for $name already running (PID: $(cat "$pid_file"))${NC}"
        return 0
    fi

    # Check if service exists
    if ! check_service "$namespace" "$service"; then
        return 1
    fi

    # Check if port is already in use
    if lsof -Pi ":$local_port" -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠ Port $local_port already in use${NC}"
        local existing_pid=$(lsof -Pi ":$local_port" -sTCP:LISTEN -t)
        echo "  Process using port: $existing_pid"
        return 1
    fi

    # Start port forwarding
    echo -e "${BLUE}→ Starting port forward: $name${NC}"
    echo "  $namespace/$service: localhost:$local_port → $remote_port"

    kubectl port-forward -n "$namespace" "svc/$service" "$local_port:$remote_port" > /dev/null 2>&1 &
    local pid=$!

    # Save PID
    echo "$pid" > "$pid_file"

    # Verify it started
    sleep 1
    if kill -0 "$pid" 2>/dev/null; then
        echo -e "${GREEN}✓ Port forward started (PID: $pid)${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to start port forward${NC}"
        rm -f "$pid_file"
        return 1
    fi
}

# Function to stop port forwarding
stop_port_forward() {
    local name=$1
    local pid_file="$PID_DIR/${name}.pid"

    if [ ! -f "$pid_file" ]; then
        echo -e "${YELLOW}⚠ No PID file found for $name${NC}"
        return 0
    fi

    local pid=$(cat "$pid_file")

    if kill -0 "$pid" 2>/dev/null; then
        echo -e "${BLUE}→ Stopping port forward: $name (PID: $pid)${NC}"
        kill "$pid" 2>/dev/null || true
        sleep 1

        # Force kill if still running
        if kill -0 "$pid" 2>/dev/null; then
            kill -9 "$pid" 2>/dev/null || true
        fi

        echo -e "${GREEN}✓ Port forward stopped${NC}"
    else
        echo -e "${YELLOW}⚠ Process not running for $name${NC}"
    fi

    rm -f "$pid_file"
}

# Function to show status
show_status() {
    echo -e "${BLUE}Port Forward Status:${NC}"
    echo ""

    local active_count=0

    for name in ${(k)PORT_FORWARDS}; do
        local config=${PORT_FORWARDS[$name]}
        IFS=':' read -r namespace service local_port remote_port <<< "$config"
        local pid_file="$PID_DIR/${name}.pid"

        printf "%-15s " "$name:"

        if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
            local pid=$(cat "$pid_file")
            echo -e "${GREEN}✓ Running${NC} (PID: $pid, localhost:$local_port → $namespace/$service:$remote_port)"
            active_count=$((active_count + 1))
        else
            echo -e "${RED}✗ Stopped${NC}"
            [ -f "$pid_file" ] && rm -f "$pid_file"
        fi
    done

    echo ""
    echo "Active forwards: $active_count/${#PORT_FORWARDS}"
}

# Function to start all port forwards
start_all() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Starting Kubernetes Port Forwards${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # First, fix Docker permissions if Jenkins is running
    echo -e "${BLUE}→ Checking Docker permissions...${NC}"
    if docker ps --format "{{.Names}}" | grep -q "^jenkins$" 2>/dev/null; then
        if docker exec -u root jenkins chmod 666 /var/run/docker.sock 2>/dev/null; then
            echo -e "${GREEN}✓ Docker socket permissions fixed${NC}"
        else
            echo -e "${YELLOW}⚠ Could not fix Docker permissions (will continue)${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Jenkins not running (skipping Docker fix)${NC}"
    fi
    echo ""

    local success_count=0
    local fail_count=0

    for name in ${(k)PORT_FORWARDS}; do
        if start_port_forward "$name" "${PORT_FORWARDS[$name]}"; then
            success_count=$((success_count + 1))
        else
            fail_count=$((fail_count + 1))
        fi
    done

    echo ""
    echo -e "${BLUE}Summary:${NC}"
    echo "  Started: $success_count"
    echo "  Failed:  $fail_count"
    echo ""

    if [ $success_count -gt 0 ]; then
        echo -e "${GREEN}✓ Port forwarding active${NC}"
        echo ""
        echo "Access services at:"
        for name in ${(k)PORT_FORWARDS}; do
            local config=${PORT_FORWARDS[$name]}
            IFS=':' read -r namespace service local_port remote_port <<< "$config"
            echo "  - $name: http://localhost:$local_port"
        done
        echo ""
        echo "To stop: $0 stop"
        echo "To check status: $0 status"
    fi
}

# Function to stop all port forwards
stop_all() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Stopping Kubernetes Port Forwards${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    for name in ${(k)PORT_FORWARDS}; do
        stop_port_forward "$name"
    done

    echo ""
    echo -e "${GREEN}✓ All port forwards stopped${NC}"
}

# Function to restart all port forwards
restart_all() {
    echo -e "${BLUE}Restarting port forwards...${NC}"
    echo ""
    stop_all
    echo ""
    sleep 2
    start_all
}

# Function to cleanup orphaned processes
cleanup() {
    echo -e "${BLUE}Cleaning up orphaned port forward processes...${NC}"

    # Find kubectl port-forward processes
    local pids=$(pgrep -f "kubectl port-forward")

    if [ -z "$pids" ]; then
        echo -e "${GREEN}✓ No orphaned processes found${NC}"
        return
    fi

    echo "Found processes: $pids"
    echo "$pids" | xargs kill 2>/dev/null || true

    # Clean up PID files
    rm -f "$PID_DIR"/*.pid

    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Function to fix Docker socket permissions for Jenkins
fix_docker_permissions() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Fixing Docker Socket Permissions${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # Check if Jenkins container exists
    if ! docker ps -a --format "{{.Names}}" | grep -q "^jenkins$"; then
        echo -e "${RED}✗ Jenkins container not found${NC}"
        echo "Please ensure Jenkins is running"
        return 1
    fi

    # Check if Jenkins is running
    if ! docker ps --format "{{.Names}}" | grep -q "^jenkins$"; then
        echo -e "${YELLOW}⚠ Jenkins container is not running${NC}"
        echo "Starting Jenkins..."
        docker start jenkins
        sleep 3
    fi

    echo -e "${BLUE}→ Fixing Docker socket permissions...${NC}"

    if docker exec -u root jenkins chmod 666 /var/run/docker.sock 2>/dev/null; then
        echo -e "${GREEN}✓ Docker socket permissions fixed${NC}"
        echo ""
        echo "Verifying Docker access..."
        if docker exec jenkins docker ps >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Jenkins can access Docker${NC}"

            # Show Docker version
            local docker_version=$(docker exec jenkins docker --version 2>/dev/null)
            echo "  $docker_version"
        else
            echo -e "${RED}✗ Jenkins still cannot access Docker${NC}"
            echo "You may need to restart Jenkins: docker restart jenkins"
            return 1
        fi
    else
        echo -e "${RED}✗ Failed to fix permissions${NC}"
        echo "Try manually: docker exec -u root jenkins chmod 666 /var/run/docker.sock"
        return 1
    fi

    echo ""
    echo -e "${GREEN}✓ Docker permissions configured${NC}"
}

# Main script
main() {
    check_kubectl

    local command=${1:-start}

    case "$command" in
        start)
            start_all
            ;;
        stop)
            stop_all
            ;;
        restart)
            restart_all
            ;;
        status)
            show_status
            ;;
        cleanup)
            cleanup
            ;;
        fix-docker)
            fix_docker_permissions
            ;;
        *)
            echo "Usage: $0 [start|stop|restart|status|cleanup|fix-docker]"
            echo ""
            echo "Commands:"
            echo "  start      - Start all port forwards (default)"
            echo "  stop       - Stop all port forwards"
            echo "  restart    - Restart all port forwards"
            echo "  status     - Show current status"
            echo "  cleanup    - Kill orphaned port forward processes"
            echo "  fix-docker - Fix Docker socket permissions for Jenkins"
            exit 1
            ;;
    esac
}

main "$@"