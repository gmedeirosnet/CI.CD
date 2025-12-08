#!/bin/bash
# Setup Jenkins job for Kyverno Policy deployment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Jenkins Kyverno Policy Deployment Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if Jenkins is running
if ! docker ps | grep -q jenkins; then
    echo -e "${RED}❌ Jenkins container is not running${NC}"
    echo "Start Jenkins first: ./scripts/setup-jenkins-docker.sh"
    exit 1
fi

echo -e "${GREEN}✅ Jenkins is running${NC}"
echo ""

# Wait for Jenkins to be ready
echo "Waiting for Jenkins to be fully ready..."
max_attempts=30
attempt=0
while ! curl -s http://localhost:8080/login > /dev/null 2>&1; do
    attempt=$((attempt + 1))
    if [ $attempt -eq $max_attempts ]; then
        echo -e "${RED}❌ Jenkins did not become ready in time${NC}"
        exit 1
    fi
    echo "Attempt $attempt/$max_attempts..."
    sleep 5
done

echo -e "${GREEN}✅ Jenkins is ready${NC}"
echo ""

# Create Jenkins job using REST API
echo "Creating Jenkins Pipeline job for Kyverno policies..."

JOB_NAME="kyverno-policies-deployment"
JENKINSFILE_PATH="Jenkinsfile-kyverno-policies"

# Get Jenkins credentials from .env or use defaults
JENKINS_USER="admin"
JENKINS_PASSWORD="admin"
GITHUB_REPO="gmedeirosnet/CI.CD"
GITHUB_BRANCH="main"

# Try to load from .env if it exists and is valid
if [ -f "$PROJECT_ROOT/.env" ]; then
    # Use grep to safely extract values
    if grep -q "^JENKINS_USER=" "$PROJECT_ROOT/.env"; then
        JENKINS_USER=$(grep "^JENKINS_USER=" "$PROJECT_ROOT/.env" | cut -d '=' -f2- | tr -d '"' | tr -d "'")
    fi
    if grep -q "^JENKINS_PASSWORD=" "$PROJECT_ROOT/.env"; then
        JENKINS_PASSWORD=$(grep "^JENKINS_PASSWORD=" "$PROJECT_ROOT/.env" | cut -d '=' -f2- | tr -d '"' | tr -d "'")
    fi
    if grep -q "^GITHUB_REPO=" "$PROJECT_ROOT/.env"; then
        GITHUB_REPO=$(grep "^GITHUB_REPO=" "$PROJECT_ROOT/.env" | cut -d '=' -f2- | tr -d '"' | tr -d "'")
    fi
    if grep -q "^GITHUB_BRANCH=" "$PROJECT_ROOT/.env"; then
        GITHUB_BRANCH=$(grep "^GITHUB_BRANCH=" "$PROJECT_ROOT/.env" | cut -d '=' -f2- | tr -d '"' | tr -d "'")
    fi
fi

# Create job XML configuration
cat > /tmp/kyverno-job-config.xml <<EOF
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job@2.40">
  <description>Deploy Kyverno policies to Kubernetes cluster via ArgoCD</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
      <triggers>
        <hudson.triggers.SCMTrigger>
          <spec>H/5 * * * *</spec>
          <ignorePostCommitHooks>false</ignorePostCommitHooks>
        </hudson.triggers.SCMTrigger>
      </triggers>
    </org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps@2.90">
    <scm class="hudson.plugins.git.GitSCM" plugin="git@4.7.2">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>https://github.com/${GITHUB_REPO}.git</url>
          <credentialsId>github-credentials</credentialsId>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/${GITHUB_BRANCH}</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="list"/>
      <extensions/>
    </scm>
    <scriptPath>${JENKINSFILE_PATH}</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF

# Create the job
echo "Creating job '$JOB_NAME'..."
CRUMB=$(curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" \
    'http://localhost:8080/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,":",//crumb)')

# Check if job already exists
if curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" \
    "http://localhost:8080/job/$JOB_NAME/config.xml" > /dev/null 2>&1; then
    echo "Job already exists, updating configuration..."
    curl -X POST -u "$JENKINS_USER:$JENKINS_PASSWORD" \
        -H "$CRUMB" \
        -H "Content-Type: application/xml" \
        --data-binary @/tmp/kyverno-job-config.xml \
        "http://localhost:8080/job/$JOB_NAME/config.xml"
else
    echo "Creating new job..."
    curl -X POST -u "$JENKINS_USER:$JENKINS_PASSWORD" \
        -H "$CRUMB" \
        -H "Content-Type: application/xml" \
        --data-binary @/tmp/kyverno-job-config.xml \
        "http://localhost:8080/createItem?name=$JOB_NAME"
fi

rm /tmp/kyverno-job-config.xml

echo ""
echo -e "${GREEN}✅ Jenkins job created successfully!${NC}"
echo ""
echo -e "${YELLOW}================================================${NC}"
echo -e "${YELLOW}Jenkins Job Configuration${NC}"
echo -e "${YELLOW}================================================${NC}"
echo ""
echo "Job Name: $JOB_NAME"
echo "Job URL: http://localhost:8080/job/$JOB_NAME"
echo "Jenkinsfile: $JENKINSFILE_PATH"
echo "GitHub Repo: https://github.com/$GITHUB_REPO"
echo "Branch: $GITHUB_BRANCH"
echo ""
echo -e "${YELLOW}================================================${NC}"
echo -e "${YELLOW}Next Steps${NC}"
echo -e "${YELLOW}================================================${NC}"
echo ""
echo "1. Access Jenkins: http://localhost:8080"
echo "2. Go to job: http://localhost:8080/job/$JOB_NAME"
echo "3. Click 'Build Now' to deploy policies"
echo ""
echo "The pipeline will:"
echo "  ✓ Validate all Kyverno policy files"
echo "  ✓ Check Kyverno installation"
echo "  ✓ Create/update ArgoCD application"
echo "  ✓ Sync policies to cluster via ArgoCD"
echo "  ✓ Verify deployment and test enforcement"
echo ""
echo -e "${GREEN}Setup complete!${NC}"
