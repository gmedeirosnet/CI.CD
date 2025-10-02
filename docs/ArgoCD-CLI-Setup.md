# ArgoCD CLI Setup on Kind Cluster

## Overview
ArgoCD has been successfully installed and configured on the Kind cluster `kind-cicd-demo-cluster` with CLI access enabled.

## Installation Details

### Cluster Information
- **Cluster Name**: cicd-demo-cluster
- **Cluster Type**: Kind (Kubernetes in Docker)
- **Context**: kind-cicd-demo-cluster

### ArgoCD Version
- **CLI Version**: v3.1.8+becb020
- **Server Version**: v3.1.8+becb020
- **Build Date**: 2025-09-30

### Components Installed
ArgoCD is running with all components healthy:
- argocd-application-controller
- argocd-applicationset-controller
- argocd-dex-server
- argocd-notifications-controller
- argocd-redis
- argocd-repo-server
- argocd-server

### Service Configuration
ArgoCD server is exposed as a ClusterIP service on:
- **HTTP**: Port 80
- **HTTPS**: Port 443

## CLI Access

### Port Forwarding
To access ArgoCD server locally:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### Login Credentials
- **Username**: admin
- **Password**: **********************

To retrieve the password:
```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
```

### CLI Login
```bash
argocd login localhost:8080 --username admin --password <PASSWORD> --insecure
```

Current login status:
- **Logged In**: true
- **Username**: admin
- **Context**: localhost:8080

## Registered Clusters

| Server | Name | Status |
|--------|------|--------|
| https://kubernetes.default.svc | in-cluster | Active |

## Common ArgoCD CLI Commands

### Account Management
```bash
# Get user info
argocd account get-user-info

# Update password
argocd account update-password
```

### Application Management
```bash
# List applications
argocd app list

# Create application
argocd app create <APP_NAME> \
  --repo <REPO_URL> \
  --path <PATH> \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace <NAMESPACE>

# Sync application
argocd app sync <APP_NAME>

# Get application status
argocd app get <APP_NAME>

# Delete application
argocd app delete <APP_NAME>
```

### Repository Management
```bash
# List repositories
argocd repo list

# Add repository
argocd repo add <REPO_URL> --username <USER> --password <PASSWORD>

# Add private repository (SSH)
argocd repo add <REPO_URL> --ssh-private-key-path ~/.ssh/id_rsa
```

### Cluster Management
```bash
# List clusters
argocd cluster list

# Add cluster
argocd cluster add <CONTEXT_NAME>
```

### Project Management
```bash
# List projects
argocd proj list

# Create project
argocd proj create <PROJECT_NAME>
```

## Web UI Access

### Option 1: Port Forward
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
Access at: https://localhost:8080

### Option 2: NodePort (for Kind)
To expose ArgoCD via NodePort:
```bash
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
```

### Option 3: Ingress
Configure an Ingress resource for production-like access (requires Ingress controller).

## Next Steps

1. Add your Git repository to ArgoCD
2. Create your first application
3. Configure sync policies
4. Set up notifications (optional)
5. Configure RBAC (optional)
6. Change the default admin password

## Sample Application Deployment

Example of deploying the sample nginx app from the repository:
```bash
argocd app create sample-nginx \
  --repo https://github.com/gmedeirosnet/CI.CD.git \
  --path argocd-apps \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated
```

## References

- [ArgoCD Official Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD CLI Reference](https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- Kind Cluster Setup: See KIND_QUICKSTART.md
- ArgoCD Connection Guide: See ARGOCD_CONNECTION_GUIDE.md

## Troubleshooting

### Port Forward Not Working
```bash
# Kill existing port-forward
pkill -f "port-forward.*argocd"

# Start new port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### Login Issues
```bash
# Verify ArgoCD server is running
kubectl get pods -n argocd

# Check service
kubectl get svc argocd-server -n argocd

# Get fresh password
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
```

### CLI Context Issues
```bash
# List contexts
argocd context

# Switch context
argocd context <CONTEXT_NAME>
```

## Security Considerations

1. **Change Default Password**: Update the admin password after initial setup
2. **Delete Initial Secret**: Remove the initial admin secret after setting a new password
   ```bash
   kubectl delete secret argocd-initial-admin-secret -n argocd
   ```
3. **Enable SSO**: Configure SSO for production environments
4. **Use RBAC**: Implement role-based access control
5. **TLS Certificates**: Use proper TLS certificates in production

## Status
- Installation: Complete
- CLI Configuration: Complete
- Login: Successful
- Ready for Application Deployment: Yes
