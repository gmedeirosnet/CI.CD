#!/bin/bash

# ArgoCD Quick Setup Script
# Connect your GitHub repository to ArgoCD

# Note: Not using 'set -e' to handle failures gracefully
# set -e

echo "=========================================="
echo "ArgoCD Repository Setup"
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

# Step 5: Get repository information from user
echo -e "${YELLOW}Step 5: Repository Configuration${NC}"
echo ""
read -p "Enter your GitHub repository URL (e.g., https://github.com/username/repo): " REPO_URL

# Validate repository URL
if [ -z "$REPO_URL" ]; then
    echo -e "${RED}Error: Repository URL cannot be empty${NC}"
    exit 1
fi

# Extract username and repo name for display
if [[ $REPO_URL =~ github\.com[:/]([^/]+)/([^/\.]+) ]]; then
    GITHUB_USER="${BASH_REMATCH[1]}"
    REPO_NAME="${BASH_REMATCH[2]}"
    echo -e "${GREEN}✓ Repository: $GITHUB_USER/$REPO_NAME${NC}"
else
    echo -e "${YELLOW}Warning: Could not parse GitHub username/repo from URL${NC}"
    GITHUB_USER=""
    REPO_NAME="cicd-lab"
fi
echo ""

# Step 6: Add GitHub repository
echo -e "${YELLOW}Step 6: Adding GitHub repository...${NC}"

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
        argocd repo add "$REPO_URL" --name "${REPO_NAME}"
        ;;
    2)
        read -p "Enter your GitHub username [${GITHUB_USER:-username}]: " input_user
        github_user=${input_user:-${GITHUB_USER:-username}}
        read -sp "Enter your GitHub Personal Access Token: " github_token
        echo ""
        argocd repo add "$REPO_URL" \
            --username "$github_user" \
            --password "$github_token" \
            --name "${REPO_NAME}"
        ;;
    3)
        read -p "Enter path to SSH private key [~/.ssh/id_rsa]: " ssh_key
        ssh_key=${ssh_key:-~/.ssh/id_rsa}
        ssh_key="${ssh_key/#\~/$HOME}"

        if [ ! -f "$ssh_key" ]; then
            echo -e "${RED}Error: SSH key not found at $ssh_key${NC}"
            exit 1
        fi

        # Convert HTTPS URL to SSH format if needed
        SSH_REPO_URL="$REPO_URL"
        if [[ $REPO_URL =~ ^https://github\.com/(.+)$ ]]; then
            SSH_REPO_URL="git@github.com:${BASH_REMATCH[1]}.git"
        fi

        argocd repo add "$SSH_REPO_URL" \
            --ssh-private-key-path "$ssh_key" \
            --name "${REPO_NAME}"
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

# Step 7: Verify repository connection
echo -e "${YELLOW}Step 7: Verifying repository connection...${NC}"
sleep 2
if argocd repo list | grep -q "Successful"; then
    echo -e "${GREEN}✓ Repository connection verified${NC}"
else
    echo -e "${RED}Warning: Repository connection may have issues${NC}"
    argocd repo list
fi
echo ""

# Step 8: Add Kind cluster
echo -e "${YELLOW}Step 8: Checking cluster configuration...${NC}"
CURRENT_CONTEXT=$(kubectl config current-context)
echo "  Current context: $CURRENT_CONTEXT"

# Check if this is a Kind cluster
if [[ $CURRENT_CONTEXT =~ ^kind- ]]; then
    echo -e "${YELLOW}Detected Kind cluster. Checking if cluster is already configured...${NC}"

    # For Kind clusters, we typically use the in-cluster config
    # Check if the cluster is already added (look for 'in-cluster' or the specific context)
    if argocd cluster list | grep -qE "(in-cluster|$CURRENT_CONTEXT)"; then
        echo -e "${GREEN}✓ Cluster already configured${NC}"
    else
        echo -e "${YELLOW}For Kind clusters, ArgoCD typically uses in-cluster configuration.${NC}"
        echo -e "${YELLOW}The cluster will be accessible to ArgoCD applications automatically.${NC}"
        echo -e "${YELLOW}Skipping external cluster registration for Kind.${NC}"
        echo -e "${GREEN}✓ Using in-cluster configuration${NC}"
    fi
else
    # For non-Kind clusters, try to add normally
    if argocd cluster list | grep -q "$CURRENT_CONTEXT"; then
        echo -e "${GREEN}✓ Cluster already configured${NC}"
    else
        echo -e "${YELLOW}Adding cluster to ArgoCD...${NC}"
        if argocd cluster add "$CURRENT_CONTEXT" --yes 2>&1; then
            echo -e "${GREEN}✓ Cluster added${NC}"
        else
            echo -e "${RED}Warning: Failed to add cluster. This is normal for Kind clusters.${NC}"
            echo -e "${YELLOW}ArgoCD will use in-cluster configuration instead.${NC}"
        fi
    fi
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
