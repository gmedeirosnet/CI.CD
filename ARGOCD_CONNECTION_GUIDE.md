# ArgoCD Repository Connection - Complete Guide

## 🎯 Quick Start

### 1. Run the Automated Setup Script
```bash
chmod +x scripts/setup-argocd-repo.sh
./scripts/setup-argocd-repo.sh
```

**The script will:**
- ✅ Check ArgoCD is running
- ✅ Retrieve admin credentials
- ✅ Prompt for your GitHub repository URL
- ✅ Connect your repository to ArgoCD
- ✅ Configure your Kind cluster
- ✅ Display access credentials

### 2. Deploy Sample Application
```bash
# Update the repository URL in the file first
vim argocd-apps/sample-nginx-app.yaml

# Deploy
kubectl apply -f argocd-apps/sample-nginx-app.yaml

# Verify
argocd app get sample-nginx-app
kubectl get pods -l app=sample-nginx
```

### 3. Access Your Application
```bash
# If using Kind with NodePort (port 30000)
curl http://localhost:30000

# Or use port-forward
kubectl port-forward svc/sample-nginx 8080:80
curl http://localhost:8080
```

## 📁 Files Created

### Scripts
- `scripts/setup-argocd-repo.sh` - Automated repository connection script

### Documentation
- `argocd-setup.md` - Comprehensive setup guide
- `ARGOCD_QUICKREF.md` - Quick reference commands

### Sample Applications
- `k8s/sample-app/deployment.yaml` - Sample nginx deployment
- `argocd-apps/sample-nginx-app.yaml` - ArgoCD application definition
- `argocd-apps/README.md` - ArgoCD apps documentation

## 🔧 Manual Connection Steps

If you prefer to connect manually:

### 1. Get ArgoCD Credentials
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### 2. Login to ArgoCD CLI
```bash
argocd login localhost:8090
# Username: admin
# Password: [from step 1]
```

### 3. Add Your Repository

**Public Repository:**
```bash
argocd repo add https://github.com/YOUR_USERNAME/YOUR_REPO
```

**Private Repository:**
```bash
argocd repo add https://github.com/YOUR_USERNAME/YOUR_REPO \
  --username YOUR_USERNAME \
  --password YOUR_GITHUB_TOKEN
```

**Using SSH:**
```bash
argocd repo add git@github.com:YOUR_USERNAME/YOUR_REPO.git \
  --ssh-private-key-path ~/.ssh/id_rsa
```

### 4. Verify Connection
```bash
argocd repo list
```

## 🚀 Deploying Applications

### Method 1: Declarative (Recommended)
```bash
# Create application YAML
cat > argocd-apps/my-app.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_USERNAME/YOUR_REPO
    targetRevision: HEAD
    path: k8s/my-app
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

# Apply
kubectl apply -f argocd-apps/my-app.yaml
```

### Method 2: CLI
```bash
argocd app create my-app \
  --repo https://github.com/YOUR_USERNAME/YOUR_REPO \
  --path k8s/my-app \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated
```

### Method 3: UI
1. Open https://localhost:8090
2. Click "+ NEW APP"
3. Fill in the form with your repository details
4. Click "CREATE"

## 📊 Monitoring Your Applications

### CLI Commands
```bash
# List all applications
argocd app list

# Get application status
argocd app get APP_NAME

# Sync application
argocd app sync APP_NAME

# View application logs
argocd app logs APP_NAME

# View sync history
argocd app history APP_NAME
```

### UI Access
- URL: https://localhost:8090
- Username: admin
- Password: (from kubectl secret command)

## 🔍 Verification Checklist

- [ ] ArgoCD is running (`kubectl get pods -n argocd`)
- [ ] Repository is connected (`argocd repo list`)
- [ ] Cluster is configured (`argocd cluster list`)
- [ ] Application is created (`argocd app list`)
- [ ] Application is synced (`argocd app get APP_NAME`)
- [ ] Pods are running (`kubectl get pods`)
- [ ] Service is accessible (`kubectl get svc`)

## 🛠️ Troubleshooting

### Port-forward not working
```bash
# Kill existing port-forward
pkill -f "port-forward.*argocd"

# Start new one
kubectl port-forward svc/argocd-server -n argocd 8090:443
```

### Repository not connecting
```bash
# Check ArgoCD repo server logs
kubectl logs -n argocd deployment/argocd-repo-server -f

# Remove and re-add repository
argocd repo rm https://github.com/YOUR_USERNAME/YOUR_REPO
argocd repo add https://github.com/YOUR_USERNAME/YOUR_REPO
```

### Application not syncing
```bash
# Check application details
argocd app get APP_NAME

# View application events
kubectl describe application APP_NAME -n argocd

# Force sync
argocd app sync APP_NAME --force
```

### Authentication issues
```bash
# For private repos, create GitHub token:
# GitHub → Settings → Developer settings → Personal access tokens
# Select scope: repo (Full control of private repositories)

# Add repo with token
argocd repo add https://github.com/YOUR_USERNAME/YOUR_REPO \
  --username YOUR_USERNAME \
  --password YOUR_TOKEN
```

## 📚 Next Steps

### 1. Customize Sample Application
```bash
# Edit the deployment
vim k8s/sample-app/deployment.yaml

# Commit and push
git add k8s/
git commit -m "Update sample app"
git push

# ArgoCD will automatically sync (if auto-sync enabled)
```

### 2. Add Your Own Application
```bash
# Create directory structure
mkdir -p k8s/my-app

# Add your Kubernetes manifests
# (deployments, services, configmaps, etc.)

# Create ArgoCD application
kubectl apply -f argocd-apps/my-app.yaml
```

### 3. Integrate with CI/CD
- Connect Jenkins to build and push images
- Update image tags in Git
- ArgoCD automatically deploys new versions

### 4. Multi-Environment Setup
```bash
# Create environment-specific directories
mkdir -p k8s/dev k8s/staging k8s/prod

# Create separate ArgoCD applications for each
```

## 🎓 Learning Resources

- **Full Documentation:** `argocd-setup.md`
- **Quick Reference:** `ARGOCD_QUICKREF.md`
- **ArgoCD Official:** https://argo-cd.readthedocs.io/
- **GitOps Guide:** https://www.weave.works/technologies/gitops/

## ✅ Summary

You now have:
1. ✅ Automated script to connect any repository
2. ✅ Sample Kubernetes application
3. ✅ ArgoCD application definition
4. ✅ Complete documentation
5. ✅ Troubleshooting guides

**Your Repository:** Will be connected to ArgoCD at https://localhost:8090

**Next:** Run `./scripts/setup-argocd-repo.sh` to get started!
