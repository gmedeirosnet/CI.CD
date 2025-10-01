# ArgoCD Guide

## Introduction
ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes. It follows the GitOps pattern of using Git repositories as the source of truth for defining the desired application state.

## Key Features
- Automated deployment of applications to Kubernetes clusters
- Support for multiple config management tools (Helm, Kustomize, Jsonnet, plain YAML)
- Real-time monitoring of application state
- Automated or manual sync of desired state
- Web UI and CLI for application management
- Multi-cluster support
- SSO integration
- RBAC for security

## Installation

### Prerequisites
- Kubernetes cluster (v1.19+)
- kubectl configured to access the cluster
- Basic understanding of Kubernetes concepts

### Install ArgoCD
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### Access ArgoCD UI
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Get initial admin password:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Basic Usage

### Create an Application
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/example/repo
    targetRevision: HEAD
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: myapp
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### CLI Commands
```bash
# Login
argocd login <ARGOCD_SERVER>

# Add a repository
argocd repo add https://github.com/example/repo --username <username> --password <password>

# Create an application
argocd app create myapp --repo https://github.com/example/repo --path k8s --dest-server https://kubernetes.default.svc --dest-namespace myapp

# Sync an application
argocd app sync myapp

# Get application status
argocd app get myapp
```

## Integration with Other Tools

### GitHub Integration
- Configure webhook for automatic sync triggers
- Use GitHub Actions for automated deployments
- Integrate with GitHub SSO for authentication

### Helm Integration
- ArgoCD natively supports Helm charts
- Specify Helm values in Application manifest
- Override values using multiple sources

### Harbor Integration
- Pull container images from Harbor registry
- Configure imagePullSecrets in Kubernetes
- Use Harbor as secure artifact storage

## Best Practices
1. Use Git branches for different environments (dev, staging, prod)
2. Implement automated sync with caution in production
3. Use ApplicationSets for managing multiple applications
4. Enable notifications for sync status
5. Implement proper RBAC policies
6. Use projects to group related applications
7. Store secrets using Sealed Secrets or external secret managers

## Troubleshooting

### Application stuck in Progressing state
- Check pod logs: `kubectl logs -n <namespace> <pod-name>`
- Verify image pull secrets
- Check resource quotas and limits

### Sync fails with permission errors
- Verify ArgoCD service account permissions
- Check RBAC policies in target namespace
- Ensure cluster role bindings are correct

### Out of Sync despite manual sync
- Check for webhooks or controllers modifying resources
- Review resource health checks
- Verify sync options and prune settings

## References
- Official Documentation: https://argo-cd.readthedocs.io/
- GitHub Repository: https://github.com/argoproj/argo-cd
- Community: https://argoproj.github.io/community/
