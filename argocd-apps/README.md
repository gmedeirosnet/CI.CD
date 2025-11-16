# ArgoCD Applications Directory

This directory contains ArgoCD Application manifests for deploying your applications to Kubernetes using GitOps.

## Files

- `sample-nginx-app.yaml` - Example nginx application deployment
- `kyverno-policies.yaml` - Kyverno policy engine policies deployment

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

# For Kyverno policies
argocd app get kyverno-policies
argocd app sync kyverno-policies

# Via UI
# Visit https://localhost:8090 and view the application
```

## Kyverno Policies Application

The `kyverno-policies.yaml` application deploys all Kyverno policies from the repository:

**Features:**
- Automatically deploys all policies from `k8s/kyverno/policies/`
- Recursive directory scanning (deploys all subdirectories)
- Auto-sync enabled with self-healing
- Namespace: Policies are ClusterPolicies (cluster-wide)

**Deployment:**
```bash
# Deploy Kyverno policies via ArgoCD
kubectl apply -f argocd-apps/kyverno-policies.yaml

# Check sync status
argocd app get kyverno-policies

# View deployed policies
kubectl get clusterpolicies

# View policy reports
kubectl get clusterpolicyreport -A
kubectl get policyreport -n app-demo
```

**Policy Categories Deployed:**
1. **Namespace Requirements** (`00-namespace/`) - Label enforcement
2. **Security Policies** (`10-security/`) - Privileged containers, non-root users, read-only filesystem
3. **Resource Limits** (`20-resources/`) - CPU/memory requirements
4. **Registry Enforcement** (`30-registry/`) - Harbor-only images
5. **Label Management** (`40-labels/`) - Auto-inject standard labels

**Important Notes:**
- All policies are deployed in **Audit mode** (violations logged, not blocked)
- Policies exclude system namespaces (kube-system, argocd, monitoring, logging, kyverno)
- Policy changes in Git are automatically synced to the cluster
- Use `kubectl describe clusterpolicy <name>` to view policy details

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
