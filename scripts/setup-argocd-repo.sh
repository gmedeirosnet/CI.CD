#!/bin/bash

# ArgoCD Quick Setup Script for CI.CD Repository
# Repository: https://github.com/gmedeirosnet/CI.CD

set -e

echo "=========================================="
echo "ArgoCD Setup for CI.CD Repository"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Step 1: Check if ArgoCD is running
echo -e "${YELLOW}Step 1: Checking ArgoCD status...${NC}"
if ! kubectl get namespace argocd &> /dev/null; then
    echo -e "${RED}Error: ArgoCD namespace not found. Please install ArgoCD first.${NC}"
    exit 1
fi

if ! kubectl get pods -n argocd | grep -q "Running"; then
    echo -e "${RED}Error: ArgoCD pods are not running.${NC}"
    kubectl get pods -n argocd
    exit 1
fi

echo -e "${GREEN}✓ ArgoCD is running${NC}"
echo ""

# Step 2: Get ArgoCD admin password
echo -e "${YELLOW}Step 2: Getting ArgoCD admin password...${NC}"
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)

if [ -z "$ARGOCD_PASSWORD" ]; then
    echo -e "${RED}Error: Could not retrieve ArgoCD password${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Password retrieved${NC}"
echo -e "  Admin Username: ${GREEN}admin${NC}"
echo -e "  Admin Password: ${GREEN}${ARGOCD_PASSWORD}${NC}"
echo ""

# Step 3: Check if port-forward is needed
echo -e "${YELLOW}Step 3: Checking ArgoCD accessibility...${NC}"
if ! curl -k https://localhost:8090 &> /dev/null; then
    echo -e "${YELLOW}Port-forward not active. Starting port-forward in background...${NC}"
    kubectl port-forward svc/argocd-server -n argocd 8090:443 > /dev/null 2>&1 &
    PORTFORWARD_PID=$!
    echo -e "${GREEN}✓ Port-forward started (PID: $PORTFORWARD_PID)${NC}"
    sleep 3
else
    echo -e "${GREEN}✓ ArgoCD is accessible at localhost:8090${NC}"
fi
echo ""

# Step 4: Login to ArgoCD CLI
echo -e "${YELLOW}Step 4: Logging into ArgoCD CLI...${NC}"
echo "admin" | argocd login localhost:8090 --username admin --password "${ARGOCD_PASSWORD}" --insecure > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Successfully logged in to ArgoCD CLI${NC}"
else
    echo -e "${RED}Error: Failed to login to ArgoCD CLI${NC}"
    exit 1
fi
echo ""

# Step 5: Add GitHub repository
echo -e "${YELLOW}Step 5: Adding GitHub repository...${NC}"
REPO_URL="https://github.com/gmedeirosnet/CI.CD"

# Check if repository already exists
if argocd repo list | grep -q "$REPO_URL"; then
    echo -e "${YELLOW}Repository already exists. Updating...${NC}"
    argocd repo rm "$REPO_URL" 2>/dev/null || true
fi

# Prompt for authentication method
echo ""
echo "Choose authentication method:"
echo "1) Public repository (no authentication)"
echo "2) Private repository (GitHub token)"
echo "3) SSH key"
read -p "Enter choice [1-3]: " auth_choice

case $auth_choice in
    1)
        echo -e "${YELLOW}Adding as public repository...${NC}"
        argocd repo add "$REPO_URL" --name cicd-lab
        ;;
    2)
        read -p "Enter your GitHub username [gmedeirosnet]: " github_user
        github_user=${github_user:-gmedeirosnet}
        read -sp "Enter your GitHub Personal Access Token: " github_token
        echo ""
        argocd repo add "$REPO_URL" \
            --username "$github_user" \
            --password "$github_token" \
            --name cicd-lab
        ;;
    3)
        read -p "Enter path to SSH private key [~/.ssh/id_rsa]: " ssh_key
        ssh_key=${ssh_key:-~/.ssh/id_rsa}
        ssh_key="${ssh_key/#\~/$HOME}"

        if [ ! -f "$ssh_key" ]; then
            echo -e "${RED}Error: SSH key not found at $ssh_key${NC}"
            exit 1
        fi

        argocd repo add "git@github.com:gmedeirosnet/CI.CD.git" \
            --ssh-private-key-path "$ssh_key" \
            --name cicd-lab
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Repository added successfully${NC}"
else
    echo -e "${RED}Error: Failed to add repository${NC}"
    exit 1
fi
echo ""

# Step 6: Verify repository connection
echo -e "${YELLOW}Step 6: Verifying repository connection...${NC}"
sleep 2
if argocd repo list | grep -q "Successful"; then
    echo -e "${GREEN}✓ Repository connection verified${NC}"
else
    echo -e "${RED}Warning: Repository connection may have issues${NC}"
    argocd repo list
fi
echo ""

# Step 7: Add Kind cluster
echo -e "${YELLOW}Step 7: Checking cluster configuration...${NC}"
CURRENT_CONTEXT=$(kubectl config current-context)
echo "  Current context: $CURRENT_CONTEXT"

if argocd cluster list | grep -q "$CURRENT_CONTEXT"; then
    echo -e "${GREEN}✓ Cluster already configured${NC}"
else
    echo -e "${YELLOW}Adding cluster to ArgoCD...${NC}"
    argocd cluster add "$CURRENT_CONTEXT" --yes
    echo -e "${GREEN}✓ Cluster added${NC}"
fi
echo ""

# Summary
echo ""
echo "=========================================="
echo -e "${GREEN}ArgoCD Setup Complete!${NC}"
echo "=========================================="
echo ""
echo "Access Information:"
echo "  UI URL:  https://localhost:8090"
echo "  Username: admin"
echo "  Password: ${ARGOCD_PASSWORD}"
echo ""
echo "Repository Connected:"
echo "  ${REPO_URL}"
echo ""
echo "Next Steps:"
echo "  1. Open https://localhost:8090 in your browser"
echo "  2. Login with the credentials above"
echo "  3. Create your first application"
echo "  4. See argocd-setup.md for detailed instructions"
echo ""
echo "Useful Commands:"
echo "  argocd app list              - List all applications"
echo "  argocd repo list             - List repositories"
echo "  argocd cluster list          - List clusters"
echo "  argocd app create <name>     - Create new application"
echo ""
echo "=========================================="
