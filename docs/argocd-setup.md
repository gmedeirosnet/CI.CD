# ArgoCD Configuration for CI.CD Repository

## Current Setup
- **ArgoCD UI:** http://localhost:8090
- **Repository:** https://github.com/gmedeirosnet/CI.CD
- **Branch:** main

## Step 1: Login to ArgoCD

### Via CLI
```bash
# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo

# Login to ArgoCD CLI
argocd login localhost:8090

# When prompted:
# Username: admin
# Password: [use the password from above]
# WARNING: server certificate had error: tls: failed to verify certificate: x509: certificate signed by unknown authority. Proceed insecurely (y/n)? y
```

### Via UI
```
1. Open browser: https://localhost:8090
2. Accept the self-signed certificate warning
3. Login with:
   - Username: admin
   - Password: [from kubectl command above]
```

## Step 2: Add GitHub Repository to ArgoCD

### Option A: Public Repository (No Authentication)
```bash
argocd repo add https://github.com/gmedeirosnet/CI.CD \
  --name cicd-lab
```

### Option B: Private Repository (With GitHub Token)
If your repository is private, create a GitHub Personal Access Token first:

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Give it a name: "ArgoCD CI.CD Lab"
4. Select scopes: `repo` (Full control of private repositories)
5. Click "Generate token" and copy it

Then add the repository:
```bash
argocd repo add https://github.com/gmedeirosnet/CI.CD \
  --username gmedeirosnet \
  --password <YOUR_GITHUB_TOKEN> \
  --name cicd-lab
```

### Option C: Via SSH Key
```bash
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -C "argocd@cicd-lab" -f ~/.ssh/argocd_ed25519

# Add the public key to GitHub
cat ~/.ssh/argocd_ed25519.pub
# Copy this and add it to GitHub: Settings → SSH and GPG keys → New SSH key

# Add repository to ArgoCD using SSH
argocd repo add git@github.com:gmedeirosnet/CI.CD.git \
  --ssh-private-key-path ~/.ssh/argocd_ed25519 \
  --name cicd-lab
```

## Step 3: Verify Repository Connection

### Via CLI
```bash
# List all repositories
argocd repo list

# You should see your repository listed with "Successful" connection status
```

### Via UI
```
1. Navigate to Settings → Repositories
2. You should see "https://github.com/gmedeirosnet/CI.CD" listed
3. Connection status should be green/successful
```

## Step 4: Add Kind Cluster to ArgoCD (if not already added)

```bash
# Check current context
kubectl config current-context

# Add the cluster to ArgoCD
argocd cluster add kind-app-demo

# Or if using a different cluster name
kubectl config get-contexts
argocd cluster add <your-kind-cluster-context>
```

## Step 5: Create Sample Application

Create a directory structure for your first ArgoCD application:

```bash
mkdir -p k8s/sample-app
```

Create a sample deployment file:
```bash
cat > k8s/sample-app/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app
  namespace: app-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: sample-app
  template:
    metadata:
      labels:
        app: sample-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: sample-app
  namespace: app-demo
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30000
  selector:
    app: sample-app
EOF
```

Commit and push to GitHub:
```bash
git add k8s/
git commit -m "Add sample app for ArgoCD"
git push origin main
```

## Step 6: Create ArgoCD Application

### Via CLI
```bash
argocd app create sample-app \
  --repo https://github.com/gmedeirosnet/CI.CD \
  --path k8s/sample-app \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace app-demo \
  --sync-policy automated \
  --auto-prune \
  --self-heal
```

### Via UI
```
1. Click "+ NEW APP" button
2. Fill in the form:
   - Application Name: sample-app
   - Project: default
   - Sync Policy: Automatic
   - Auto-create namespace: checked

   Source:
   - Repository URL: https://github.com/gmedeirosnet/CI.CD
   - Revision: HEAD
   - Path: k8s/sample-app

   Destination:
   - Cluster URL: https://kubernetes.default.svc
   - Namespace: app-demo

3. Click "CREATE"
```

### Via Declarative YAML
```bash
cat > argocd-apps/sample-app.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sample-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/gmedeirosnet/CI.CD
    targetRevision: HEAD
    path: k8s/sample-app
  destination:
    server: https://kubernetes.default.svc
    namespace: app-demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
    - CreateNamespace=true
EOF

# Apply it
kubectl apply -f argocd-apps/sample-app.yaml
```

## Step 7: Verify Deployment

### Via CLI
```bash
# Get application status
argocd app get sample-app

# Watch sync progress
argocd app sync sample-app --watch

# List all applications
argocd app list
```

### Via UI
```
1. Navigate to Applications
2. Click on "sample-app"
3. You should see the deployment tree with all resources
4. Status should be "Healthy" and "Synced"
```

### Via kubectl
```bash
# Check pods
kubectl get pods -l app=sample-app

# Check service
kubectl get svc sample-app

# Access the application (if using Kind with port mapping)
curl http://localhost:30000
```

## Troubleshooting

### Can't Connect to ArgoCD
```bash
# Check if ArgoCD is running
kubectl get pods -n argocd

# Check port-forward is active
kubectl port-forward svc/argocd-server -n argocd 8090:443

# In a new terminal window
```

### Repository Connection Failed
```bash
# Check repository status
argocd repo list

# Remove and re-add repository
argocd repo rm https://github.com/gmedeirosnet/CI.CD
argocd repo add https://github.com/gmedeirosnet/CI.CD --name cicd-lab

# Check logs
kubectl logs -n argocd deployment/argocd-repo-server
```

### Application Not Syncing
```bash
# Force sync
argocd app sync sample-app --force

# Check application details
argocd app get sample-app

# View logs
kubectl logs -n argocd deployment/argocd-application-controller
```

### GitHub Authentication Issues
```bash
# If using token, verify it's correct
# If using SSH, verify the key is added to GitHub

# Test GitHub connection
ssh -T git@github.com

# Or with HTTPS
curl -u gmedeirosnet:<token> https://api.github.com/user
```

## Useful Commands

```bash
# Get ArgoCD password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Change admin password
argocd account update-password

# List all applications
argocd app list

# Get application details
argocd app get <app-name>

# Sync application
argocd app sync <app-name>

# Delete application
argocd app delete <app-name>

# List repositories
argocd repo list

# List clusters
argocd cluster list

# View application logs
argocd app logs <app-name>

# View application history
argocd app history <app-name>

# Rollback to previous version
argocd app rollback <app-name> <revision-number>
```

## Next Steps

1. ✅ Connect repository to ArgoCD
2. ✅ Create sample application
3. ✅ Deploy to Kind cluster
4. 📝 Create more complex applications
5. 📝 Set up multi-environment deployments (dev/staging/prod)
6. 📝 Integrate with Jenkins pipeline
7. 📝 Add Helm charts
8. 📝 Configure notifications
9. 📝 Set up RBAC and access controls

## Resources

- ArgoCD Documentation: https://argo-cd.readthedocs.io/
- GitOps Patterns: https://www.weave.works/technologies/gitops/
- Your Repository: https://github.com/gmedeirosnet/CI.CD
