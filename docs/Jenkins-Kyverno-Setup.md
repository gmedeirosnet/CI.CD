# Jenkins Setup Guide for Kyverno Policy Deployment

## Overview
This guide shows how to configure Jenkins to deploy Kyverno policies to your Kubernetes cluster via ArgoCD.

## Prerequisites
- ✅ Jenkins running on Docker
- ✅ Kyverno installed on cluster
- ✅ ArgoCD installed on cluster
- ✅ GitHub credentials configured in Jenkins
- ✅ kubectl configured to access cluster

## Step 1: Create Jenkins Pipeline Job

1. **Access Jenkins**
   - Open: http://localhost:8080
   - Login with admin credentials

2. **Create New Pipeline**
   - Click "New Item"
   - Enter name: `kyverno-policies-deployment`
   - Select "Pipeline"
   - Click "OK"

3. **Configure General Settings**
   - Description: `Deploy Kyverno policies to Kubernetes cluster via ArgoCD`
   - Check "GitHub project"
   - Project URL: `https://github.com/gmedeirosnet/CI.CD/`

4. **Configure Build Triggers** (Optional)
   - Check "Poll SCM"
   - Schedule: `H/5 * * * *` (every 5 minutes)
   - Or check "GitHub hook trigger for GITScm polling"

5. **Configure Pipeline**
   - Definition: `Pipeline script from SCM`
   - SCM: `Git`
   - Repository URL: `https://github.com/gmedeirosnet/CI.CD.git`
   - Credentials: Select your GitHub credentials
   - Branch: `*/main` (or your branch)
   - Script Path: `Jenkinsfile-kyverno-policies`

6. **Save the Job**

## Step 2: Run the Pipeline

1. **Trigger Build**
   - Go to the job page
   - Click "Build Now"

2. **Monitor Execution**
   - Click on the build number
   - Click "Console Output"
   - Watch the deployment progress

## Step 3: Verify Deployment

After successful build:

```bash
# Check policies in cluster
kubectl get clusterpolicies

# Check ArgoCD sync status
kubectl get application kyverno-policies -n argocd

# View policy reports
kubectl get policyreport -A

# Access Policy Reporter UI
open http://localhost:31002
```

## Pipeline Stages

The Jenkins pipeline performs these stages:

1. **Checkout** - Clone repository from GitHub
2. **Validate Policies** - Validate YAML syntax with kubectl
3. **Check Kyverno Installation** - Verify Kyverno is running
4. **Check/Create ArgoCD Application** - Ensure ArgoCD app exists
5. **Sync with ArgoCD** - Trigger policy sync to cluster
6. **Verify Deployment** - Confirm policies are deployed
7. **Policy Reports Summary** - Show violation statistics
8. **Test Policy Enforcement** - Test policy rules
9. **Policy Reporter Status** - Check monitoring dashboard

## Alternative: Manual Trigger via CLI

```bash
# Get Jenkins crumb
CRUMB=$(curl -s -u admin:admin \
  'http://localhost:8080/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,":",//crumb)')

# Trigger build
curl -X POST -u admin:admin \
  -H "$CRUMB" \
  http://localhost:8080/job/kyverno-policies-deployment/build

# Check build status
curl -s -u admin:admin \
  http://localhost:8080/job/kyverno-policies-deployment/lastBuild/api/json | \
  jq '.result'
```

## Automated Deployment Flow

```
Developer commits policy change
          ↓
    Push to GitHub
          ↓
    Jenkins polls SCM (or webhook trigger)
          ↓
    Jenkins pipeline starts
          ↓
    Validate policy files
          ↓
    ArgoCD syncs to cluster
          ↓
    Kyverno applies policies
          ↓
    Policy Reporter monitors violations
```

## Troubleshooting

### Issue: Jenkins can't access kubectl

**Solution:** Ensure Jenkins container has kubectl and kubeconfig:
```bash
docker exec jenkins kubectl version
docker exec jenkins kubectl get nodes
```

### Issue: GitHub credentials not working

**Solution:** Add credentials in Jenkins:
1. Manage Jenkins → Credentials
2. Add GitHub personal access token
3. Use in pipeline configuration

### Issue: ArgoCD app not syncing

**Solution:** Check ArgoCD application:
```bash
kubectl get application kyverno-policies -n argocd -o yaml
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### Issue: Policies not applying

**Solution:** Check Kyverno logs:
```bash
kubectl logs -n kyverno -l app.kubernetes.io/name=kyverno
kubectl get clusterpolicies
```

## Manual Policy Deployment (Without Jenkins)

If you prefer manual deployment:

```bash
# Apply policies directly
kubectl apply -f k8s/kyverno/policies/ -R

# Or via ArgoCD
kubectl apply -f argocd-apps/kyverno-policies.yaml
argocd app sync kyverno-policies
```

## Access Points

After successful setup:

- **Jenkins**: http://localhost:8080/job/kyverno-policies-deployment
- **ArgoCD**: https://localhost:8090/applications/kyverno-policies
- **Policy Reporter**: http://localhost:31002
- **Prometheus Metrics**: http://localhost:30090

## Next Steps

1. Configure GitHub webhook for automatic builds
2. Set up Slack/email notifications for build failures
3. Add policy validation tests
4. Create separate jobs for different environments
5. Implement policy approval workflow

## Files Created

- `Jenkinsfile-kyverno-policies` - Pipeline definition
- `scripts/setup-jenkins-kyverno-job.sh` - Automated setup script
- `docs/Jenkins-Kyverno-Setup.md` - This documentation
