#!/bin/bash

# Jenkins Docker Integration Setup Script
# This script restarts Jenkins with Docker access

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Jenkins Docker Integration Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Check if Docker is running
echo -e "${YELLOW}Step 1: Checking Docker...${NC}"
if ! docker ps >/dev/null 2>&1; then
    echo -e "${RED}✗ Docker is not running${NC}"
    echo "Please start Docker and try again"
    exit 1
fi
echo -e "${GREEN}✓ Docker is running${NC}"
echo ""

# Step 2: Find Jenkins container
echo -e "${YELLOW}Step 2: Finding Jenkins container...${NC}"
JENKINS_CONTAINER=$(docker ps -a --filter "name=jenkins" --format "{{.ID}}" | head -1)

if [ -z "$JENKINS_CONTAINER" ]; then
    echo -e "${YELLOW}⚠ No existing Jenkins container found${NC}"
    echo "Will create a new Jenkins container"
    JENKINS_EXISTS=false
else
    echo -e "${GREEN}✓ Found Jenkins container: $JENKINS_CONTAINER${NC}"
    JENKINS_EXISTS=true

    # Check if it's running
    JENKINS_STATUS=$(docker inspect -f '{{.State.Status}}' $JENKINS_CONTAINER)
    echo "  Status: $JENKINS_STATUS"
fi
echo ""

# Step 3: Backup warning
if [ "$JENKINS_EXISTS" = true ]; then
    echo -e "${YELLOW}Step 3: Backup Warning${NC}"
    echo "This script will restart Jenkins with Docker access."
    echo "Your Jenkins data (jobs, configuration) is stored in a Docker volume and will be preserved."
    echo ""
    echo -e "${RED}WARNING: Any running builds will be interrupted!${NC}"
    echo ""
    read -p "Do you want to continue? (yes/no): " CONFIRM

    if [ "$CONFIRM" != "yes" ]; then
        echo "Aborted by user"
        exit 0
    fi
    echo ""
fi

# Step 4: Check/Create network
echo -e "${YELLOW}Step 4: Setting up Docker network...${NC}"
if docker network inspect cicd-network >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Network 'cicd-network' already exists${NC}"
else
    docker network create cicd-network
    echo -e "${GREEN}✓ Created network 'cicd-network'${NC}"
fi
echo ""

# Step 5: Stop and remove old Jenkins
if [ "$JENKINS_EXISTS" = true ]; then
    echo -e "${YELLOW}Step 5: Stopping old Jenkins container...${NC}"
    docker stop $JENKINS_CONTAINER 2>/dev/null || true
    echo -e "${GREEN}✓ Jenkins stopped${NC}"

    echo "Removing old container..."
    docker rm $JENKINS_CONTAINER 2>/dev/null || true
    echo -e "${GREEN}✓ Old container removed${NC}"
else
    echo -e "${YELLOW}Step 5: Skipping (no existing container)${NC}"
fi
echo ""

# Step 6: Detect OS for Docker socket path
echo -e "${YELLOW}Step 6: Detecting system configuration...${NC}"
OS_TYPE=$(uname -s)
echo "Operating System: $OS_TYPE"

if [ "$OS_TYPE" = "Darwin" ]; then
    # macOS
    DOCKER_SOCK="/var/run/docker.sock"
    DOCKER_GROUP_ADD=""
    echo "Platform: macOS (Docker Desktop)"
elif [ "$OS_TYPE" = "Linux" ]; then
    # Linux
    DOCKER_SOCK="/var/run/docker.sock"
    DOCKER_GID=$(stat -c '%g' /var/run/docker.sock 2>/dev/null || echo "")
    if [ ! -z "$DOCKER_GID" ]; then
        DOCKER_GROUP_ADD="--group-add $DOCKER_GID"
        echo "Docker group ID: $DOCKER_GID"
    else
        DOCKER_GROUP_ADD=""
    fi
    echo "Platform: Linux"
else
    # Windows or other
    DOCKER_SOCK="/var/run/docker.sock"
    DOCKER_GROUP_ADD=""
    echo "Platform: $OS_TYPE"
fi
echo ""

# Step 7: Start new Jenkins with Docker access
echo -e "${YELLOW}Step 7: Starting Jenkins with Docker access...${NC}"

docker run -d \
  --name jenkins \
  --restart unless-stopped \
  --network cicd-network \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v $DOCKER_SOCK:/var/run/docker.sock \
  $DOCKER_GROUP_ADD \
  jenkins/jenkins:lts

echo -e "${GREEN}✓ Jenkins container started${NC}"
echo ""

# Step 8: Wait for Jenkins to be ready
echo -e "${YELLOW}Step 8: Waiting for Jenkins to start...${NC}"
echo "This may take 30-60 seconds..."

RETRY_COUNT=0
MAX_RETRIES=60

# Wait for Jenkins to be responsive
until curl -s http://localhost:8080 >/dev/null 2>&1; do
    sleep 2
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo -e "${RED}✗ Timeout waiting for Jenkins to start${NC}"
        echo "Check logs: docker logs jenkins"
        exit 1
    fi
    echo -n "."
done

echo ""
echo -e "${GREEN}✓ Jenkins is running${NC}"
echo ""

# Step 9: Detect architecture and install Docker CLI
echo -e "${YELLOW}Step 9: Installing Docker CLI in Jenkins container...${NC}"

# Detect architecture
ARCH=$(docker exec jenkins dpkg --print-architecture 2>/dev/null)
echo "Detected architecture: $ARCH"

# Detect Debian version
DEBIAN_VERSION=$(docker exec jenkins cat /etc/os-release 2>/dev/null | grep VERSION_CODENAME | cut -d= -f2)
echo "Detected Debian version: $DEBIAN_VERSION"

# Install Docker CLI with correct architecture
echo "Installing Docker CLI for $ARCH..."
docker exec -u root jenkins bash -c "
  set -e
  apt-get update >/dev/null 2>&1
  apt-get install -y apt-transport-https ca-certificates curl gnupg >/dev/null 2>&1
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg 2>/dev/null
  echo 'deb [arch=$ARCH signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $DEBIAN_VERSION stable' > /etc/apt/sources.list.d/docker.list
  apt-get update >/dev/null 2>&1
  apt-get install -y docker-ce-cli docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1
  apt-get clean
  rm -rf /var/lib/apt/lists/*
" 2>&1 | grep -v "^debconf:" || true

if docker exec jenkins docker --version >/dev/null 2>&1; then
    DOCKER_CLI_VERSION=$(docker exec jenkins docker --version)
    echo -e "${GREEN}✓ Docker CLI installed successfully${NC}"
    echo "  Version: $DOCKER_CLI_VERSION"
else
    echo -e "${RED}✗ Failed to install Docker CLI${NC}"
    echo "Attempting manual installation..."

    # Fallback: try simple docker.io package
    docker exec -u root jenkins bash -c "
      apt-get update >/dev/null 2>&1
      apt-get install -y docker.io >/dev/null 2>&1
    " 2>&1 | grep -v "^debconf:" || true

    if docker exec jenkins docker --version >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Docker CLI installed via docker.io package${NC}"
    else
        echo -e "${RED}✗ Docker CLI installation failed${NC}"
        echo "You may need to install it manually"
    fi
fi
echo ""

# Step 10: Verify Docker access
echo -e "${YELLOW}Step 10: Verifying Docker access from Jenkins...${NC}"
DOCKER_VERSION=$(docker exec jenkins docker --version 2>/dev/null)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Docker is accessible from Jenkins${NC}"
    echo "  $DOCKER_VERSION"
else
    echo -e "${RED}✗ Docker is not accessible from Jenkins${NC}"
    echo "Check permissions: docker exec jenkins docker ps"
    echo ""
    echo "You may need to fix permissions:"
    echo "  docker exec -u root jenkins chmod 666 /var/run/docker.sock"
fi
echo ""

# Step 11: Test Docker commands
echo -e "${YELLOW}Step 11: Testing Docker commands...${NC}"
if docker exec jenkins docker ps >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Can list Docker containers${NC}"
else
    echo -e "${YELLOW}⚠ Cannot list Docker containers (may need permissions)${NC}"
    echo "Attempting to fix permissions..."
    docker exec -u root jenkins chmod 666 /var/run/docker.sock 2>/dev/null || true

    if docker exec jenkins docker ps >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Permissions fixed!${NC}"
    else
        echo -e "${RED}✗ Still cannot access Docker${NC}"
        echo "Manual fix: docker exec -u root jenkins chmod 666 /var/run/docker.sock"
    fi
fi
echo ""

# Step 12: Display summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Jenkins Information:${NC}"
echo "  URL: http://localhost:8080"
echo "  Container: jenkins"
echo "  Network: cicd-network"
echo ""

if [ "$JENKINS_EXISTS" = false ]; then
    echo -e "${BLUE}Initial Admin Password:${NC}"
    if docker exec jenkins test -f /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null; then
        docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null
    else
        echo "  (Password file not yet created - Jenkins may still be initializing)"
        echo "  Run: docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword"
    fi
    echo ""
else
    echo -e "${BLUE}Existing Jenkins Installation:${NC}"
    echo "  Use your existing admin credentials to log in"
    echo "  (Initial admin password file is deleted after first setup)"
    echo ""
fi

echo -e "${BLUE}Quick Commands:${NC}"
echo "  View logs:      docker logs -f jenkins"
echo "  Restart:        docker restart jenkins"
echo "  Stop:           docker stop jenkins"
echo "  Enter shell:    docker exec -it jenkins bash"
echo "  Test Docker:    docker exec jenkins docker --version"
echo ""

echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Access Jenkins at http://localhost:8080"
if [ "$JENKINS_EXISTS" = false ]; then
    echo "  2. Complete the setup wizard"
    echo "  3. Install recommended plugins"
fi
echo "  4. Run your pipeline with Docker build stage"
echo "  5. Verify images are built successfully"
echo ""

echo -e "${BLUE}Troubleshooting:${NC}"
echo "  If builds still fail with 'docker: not found':"
echo "    docker exec jenkins docker --version"
echo ""
echo "  If permission denied:"
echo "    docker exec -u root jenkins chmod 666 /var/run/docker.sock"
echo ""
echo "  Full documentation:"
echo "    docs/Jenkins-Docker-Integration.md"
echo ""

echo -e "${GREEN}✓ Jenkins is ready to build Docker images!${NC}"
