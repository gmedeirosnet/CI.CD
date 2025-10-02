# ArgoCD CLI Quick Reference

## Connection

### Login
```bash
# Login with password
argocd login localhost:8080 --username admin --password <PASSWORD> --insecure

# Login with SSO
argocd login <ARGOCD_SERVER> --sso

# Get current context
argocd context
```

### Port Forward
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## Applications

### Create
```bash
# Basic application
argocd app create <APP_NAME> \
  --repo <REPO_URL> \
  --path <PATH> \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace <NAMESPACE>

# With auto-sync
argocd app create <APP_NAME> \
  --repo <REPO_URL> \
  --path <PATH> \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace <NAMESPACE> \
  --sync-policy automated

# From Helm chart
argocd app create <APP_NAME> \
  --repo <HELM_REPO_URL> \
  --helm-chart <CHART_NAME> \
  --revision <VERSION> \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace <NAMESPACE>
```

### List and Get
```bash
# List all applications
argocd app list

# Get application details
argocd app get <APP_NAME>

# Get application manifest
argocd app manifests <APP_NAME>
```

### Sync
```bash
# Sync application
argocd app sync <APP_NAME>

# Sync with prune (delete resources not in Git)
argocd app sync <APP_NAME> --prune

# Force sync
argocd app sync <APP_NAME> --force

# Dry run
argocd app sync <APP_NAME> --dry-run
```

### Update
```bash
# Set parameter
argocd app set <APP_NAME> -p <PARAM>=<VALUE>

# Set sync policy
argocd app set <APP_NAME> --sync-policy automated

# Set auto-prune
argocd app set <APP_NAME> --auto-prune

# Set self-heal
argocd app set <APP_NAME> --self-heal
```

### Delete
```bash
# Delete application (keep resources)
argocd app delete <APP_NAME>

# Delete application and resources
argocd app delete <APP_NAME> --cascade
```

### Rollback
```bash
# List history
argocd app history <APP_NAME>

# Rollback to revision
argocd app rollback <APP_NAME> <REVISION>
```

## Repositories

### Add Repository
```bash
# HTTPS with credentials
argocd repo add <REPO_URL> \
  --username <USER> \
  --password <PASSWORD>

# SSH
argocd repo add <REPO_URL> \
  --ssh-private-key-path ~/.ssh/id_rsa

# Helm repository
argocd repo add <HELM_REPO_URL> \
  --type helm \
  --name <REPO_NAME>
```

### List and Remove
```bash
# List repositories
argocd repo list

# Remove repository
argocd repo rm <REPO_URL>
```

## Clusters

### Manage Clusters
```bash
# List clusters
argocd cluster list

# Add cluster
argocd cluster add <CONTEXT_NAME>

# Remove cluster
argocd cluster rm <CLUSTER_URL>
```

## Projects

### Create and Manage
```bash
# Create project
argocd proj create <PROJECT_NAME>

# List projects
argocd proj list

# Get project details
argocd proj get <PROJECT_NAME>

# Add source repository
argocd proj add-source <PROJECT_NAME> <REPO_URL>

# Add destination
argocd proj add-destination <PROJECT_NAME> \
  <CLUSTER_URL> <NAMESPACE>

# Delete project
argocd proj delete <PROJECT_NAME>
```

## Account Management

### User Info
```bash
# Get user info
argocd account get-user-info

# Update password
argocd account update-password

# List accounts
argocd account list
```

## Version and System

### Version Info
```bash
# Client version
argocd version --client

# Server and client version
argocd version
```

## Logs and Debugging

### Application Logs
```bash
# Get application logs
argocd app logs <APP_NAME>

# Follow logs
argocd app logs <APP_NAME> -f

# Get logs for specific resource
argocd app logs <APP_NAME> --kind Deployment --name <DEPLOYMENT_NAME>
```

### Diff
```bash
# Show diff
argocd app diff <APP_NAME>

# Show diff with live state
argocd app diff <APP_NAME> --local <PATH>
```

## Common Workflows

### Deploy New Application
```bash
# 1. Add repository
argocd repo add https://github.com/user/repo.git

# 2. Create application
argocd app create myapp \
  --repo https://github.com/user/repo.git \
  --path k8s \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default

# 3. Sync application
argocd app sync myapp

# 4. Watch status
argocd app wait myapp
```

### Update Application
```bash
# Git push changes, then:
argocd app sync <APP_NAME>

# Or with auto-sync:
argocd app set <APP_NAME> --sync-policy automated
```

### Troubleshoot Application
```bash
# Get application status
argocd app get <APP_NAME>

# Show diff
argocd app diff <APP_NAME>

# Get logs
argocd app logs <APP_NAME> -f

# Check resources
kubectl get all -n <NAMESPACE>
```

## Useful Flags

- `--grpc-web`: Use gRPC web protocol (useful behind proxies)
- `--insecure`: Skip TLS verification
- `--server`: Specify ArgoCD server URL
- `--auth-token`: Use token for authentication
- `-o yaml|json`: Output in YAML or JSON format
- `--watch`: Watch for changes
- `--timeout`: Set operation timeout

## Environment Variables

```bash
# Set default server
export ARGOCD_SERVER=localhost:8080

# Set auth token
export ARGOCD_AUTH_TOKEN=<TOKEN>

# Skip TLS verification
export ARGOCD_OPTS='--insecure'
```

## Aliases (Optional)

Add to your `~/.zshrc`:
```bash
alias ac='argocd'
alias acl='argocd app list'
alias acg='argocd app get'
alias acs='argocd app sync'
alias acd='argocd app diff'
```
