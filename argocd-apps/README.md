# ArgoCD Applications Directory

This directory contains ArgoCD Application manifests for deploying your applications to Kubernetes using GitOps.

## Files

- `sample-nginx-app.yaml` - Example nginx application deployment

## Usage

### Option 1: Apply directly with kubectl
```bash
kubectl apply -f argocd-apps/sample-nginx-app.yaml
```

### Option 2: Create via ArgoCD CLI
```bash
kubectl apply -f argocd-apps/sample-nginx-app.yaml
```

### Option 3: Use ArgoCD UI
1. Open ArgoCD UI at https://localhost:8090
2. Click "+ NEW APP"
3. Fill in the application details
4. Click "CREATE"

## Customization

To use these manifests with your own repository:

1. Update the `repoURL` in each application YAML file:
   ```yaml
   source:
     repoURL: https://github.com/YOUR_USERNAME/YOUR_REPO
   ```

2. Update the `path` if your manifests are in a different directory:
   ```yaml
   source:
     path: path/to/your/manifests
   ```

3. Apply the application:
   ```bash
   kubectl apply -f argocd-apps/your-app.yaml
   ```

## Application Structure

Each ArgoCD Application defines:
- **Source**: Where to find the Kubernetes manifests (Git repo + path)
- **Destination**: Where to deploy (cluster + namespace)
- **Sync Policy**: How to keep the cluster in sync with Git

## Automated Sync

The sample application has automated sync enabled:
- `prune: true` - Removes resources deleted from Git
- `selfHeal: true` - Automatically reverts manual changes
- `CreateNamespace: true` - Creates namespace if it doesn't exist

## Monitoring

Check application status:
```bash
# Via CLI
argocd app get sample-nginx-app
argocd app sync sample-nginx-app

# Via UI
# Visit https://localhost:8090 and view the application
```

## Troubleshooting

If sync fails:
```bash
# Check application status
argocd app get sample-nginx-app

# View application events
kubectl describe application sample-nginx-app -n argocd

# Force sync
argocd app sync sample-nginx-app --force
```
