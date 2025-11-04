# ArgoCD Quick Reference

## Connect Your Repository

### Automated Setup (Recommended)
```bash
# Make script executable
chmod +x scripts/setup-argocd-repo.sh

# Run the setup script
./scripts/setup-argocd-repo.sh
```

The script will:
1. Check ArgoCD is running
2. Get admin credentials
3. Prompt for your repository URL
4. Connect your repository to ArgoCD
5. Configure your Kind cluster

### Manual Setup

#### 1. Get ArgoCD Password
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo
```

#### 2. Access ArgoCD
- **UI:** https://localhost:8090
- **Username:** admin
- **Password:** (from step 1)

#### 3. Add Repository (CLI)
```bash
# Login
argocd login localhost:8090

# Public repository
argocd repo add https://github.com/YOUR_USERNAME/YOUR_REPO

# Private repository (with token)
argocd repo add https://github.com/YOUR_USERNAME/YOUR_REPO \
  --username YOUR_USERNAME \
  --password YOUR_GITHUB_TOKEN
```

## Deploy Your First Application

### Option 1: Using kubectl
```bash
# Update the repoURL in the file first
kubectl apply -f argocd-apps/sample-nginx-app.yaml
```

### Option 2: Using ArgoCD CLI
```bash
argocd app create sample-app \
  --repo https://github.com/YOUR_USERNAME/YOUR_REPO \
  --path k8s/sample-app \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace app-demo \
  --sync-policy automated
```

### Option 3: Using UI
1. Open https://localhost:8090
2. Click "+ NEW APP"
3. Fill in:
   - **App Name:** sample-app
   - **Project:** default
   - **Repo URL:** Your GitHub repository
   - **Path:** k8s/sample-app
   - **Cluster:** https://kubernetes.default.svc
   - **Namespace:** app-demo
4. Enable "Auto-Sync"
5. Click "CREATE"

## Common Commands

### Repository Management
```bash
# List repositories
argocd repo list

# Remove repository
argocd repo rm https://github.com/YOUR_USERNAME/YOUR_REPO
```

### Application Management
```bash
# List applications
argocd app list

# Get app status
argocd app get APP_NAME

# Sync application
argocd app sync APP_NAME

# Delete application
argocd app delete APP_NAME

# View application logs
argocd app logs APP_NAME

# View application history
argocd app history APP_NAME
```

### Cluster Management
```bash
# List clusters
argocd cluster list

# Add current cluster
argocd cluster add $(kubectl config current-context)
```

## Verify Deployment

```bash
# Check application status
argocd app get sample-nginx-app

# Check pods
kubectl get pods -l app=sample-nginx

# Check service
kubectl get svc sample-nginx

# Access the application (Kind with NodePort)
curl http://localhost:30000
```

## Troubleshooting

### Can't access ArgoCD UI
```bash
# Start port-forward
kubectl port-forward svc/argocd-server -n argocd 8090:443
```

### Repository not connecting
```bash
# Check repository status
argocd repo list

# View ArgoCD logs
kubectl logs -n argocd deployment/argocd-repo-server -f
```

### Application not syncing
```bash
# Check application details
argocd app get APP_NAME

# Force sync
argocd app sync APP_NAME --force

# View sync status
kubectl describe application APP_NAME -n argocd
```

## Next Steps

1. ✅ Connect your repository
2. ✅ Deploy sample application
3. 📝 Customize for your project
4. 📝 Add more applications
5. 📝 Set up CI/CD pipeline with Jenkins
6. 📝 Configure notifications

## Resources

- Full Guide: `argocd-setup.md`
- Sample Apps: `k8s/sample-app/`
- App Definitions: `argocd-apps/`
- ArgoCD Docs: https://argo-cd.readthedocs.io/
