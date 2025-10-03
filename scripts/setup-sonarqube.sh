#!/bin/bash

# SonarQube Quick Setup Script
# Automates the initial setup of SonarQube for CI/CD pipeline

set -e

echo "=========================================="
echo "SonarQube Setup for CI/CD Pipeline"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Step 1: Check if Docker is running
echo -e "${YELLOW}Step 1: Checking Docker...${NC}"
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running. Please start Docker first.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker is running${NC}"
echo ""

# Step 2: Create network if it doesn't exist
echo -e "${YELLOW}Step 2: Setting up Docker network...${NC}"
if docker network inspect cicd-network > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Network 'cicd-network' already exists${NC}"
else
    echo "Creating network 'cicd-network'..."
    docker network create cicd-network
    echo -e "${GREEN}✓ Network created${NC}"
fi
echo ""

# Step 3: Connect Jenkins to network
echo -e "${YELLOW}Step 3: Connecting Jenkins to network...${NC}"
JENKINS_CONTAINER=$(docker ps --filter "name=jenkins" --format "{{.Names}}" | head -n 1)

if [ -z "$JENKINS_CONTAINER" ]; then
    echo -e "${RED}Warning: Jenkins container not found.${NC}"
    echo "Please connect Jenkins manually after starting it:"
    echo "  docker network connect cicd-network <jenkins-container>"
else
    echo "Found Jenkins container: $JENKINS_CONTAINER"
    if docker network inspect cicd-network | grep -q "$JENKINS_CONTAINER"; then
        echo -e "${GREEN}✓ Jenkins already connected to network${NC}"
    else
        echo "Connecting Jenkins to network..."
        docker network connect cicd-network "$JENKINS_CONTAINER"
        echo -e "${GREEN}✓ Jenkins connected${NC}"
    fi
fi
echo ""

# Step 4: Start SonarQube
echo -e "${YELLOW}Step 4: Starting SonarQube...${NC}"
if docker ps | grep -q "sonarqube"; then
    echo -e "${GREEN}✓ SonarQube is already running${NC}"
else
    echo "Starting SonarQube and PostgreSQL..."
    docker-compose -f sonar-compose.yml up -d
    echo -e "${GREEN}✓ Containers started${NC}"
    echo ""
    echo -e "${YELLOW}Waiting for SonarQube to be ready (this may take 2-3 minutes)...${NC}"

    for i in {1..60}; do
        if curl -sf http://localhost:9000/api/system/status | grep -q '"status":"UP"'; then
            echo -e "${GREEN}✓ SonarQube is operational!${NC}"
            break
        fi
        echo -n "."
        sleep 3
    done
    echo ""
fi
echo ""

# Step 5: Display access information
echo "=========================================="
echo -e "${GREEN}SonarQube Setup Complete!${NC}"
echo "=========================================="
echo ""
echo "Access Information:"
echo "  URL:      http://localhost:9000"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: Change the default password on first login!${NC}"
echo ""
echo "Next Steps:"
echo "  1. Open http://localhost:9000 in your browser"
echo "  2. Login with admin/admin"
echo "  3. Change the password when prompted"
echo "  4. Generate an authentication token:"
echo "     - My Account → Security → Generate Token"
echo "     - Token Name: 'Jenkins'"
echo "     - Click Generate and COPY the token"
echo "  5. Follow the guide in docs/SonarQube-Setup.md"
echo ""
echo "Jenkins Plugin Required:"
echo "  - SonarQube Scanner for Jenkins"
echo "  - Install via: Manage Jenkins → Plugins → Available"
echo ""
echo "Useful Commands:"
echo "  docker-compose -f sonar-compose.yml logs -f    # View logs"
echo "  docker-compose -f sonar-compose.yml stop       # Stop SonarQube"
echo "  docker-compose -f sonar-compose.yml down       # Stop and remove"
echo ""
echo "=========================================="
