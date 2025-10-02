# Quick Start: Kind on MacOS M4

## 5-Minute Setup

### 1. Install Docker Desktop
```bash
brew install --cask docker
open -a Docker
```

### 2. Install Kind & kubectl
```bash
brew install kind kubectl
kind version
```

### 3. Create Your First Cluster
```bash
kind create cluster --name my-cluster
```

### 4. Verify It Works
```bash
kubectl cluster-info
kubectl get nodes
```

## That's It! 🎉

Your local Kubernetes cluster is ready. It took less than 2 minutes and cost $0.

## What Next?

### Deploy Something
```bash
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl get services
```

### Load a Local Docker Image
```bash
docker build -t my-app:latest .
kind load docker-image my-app:latest --name my-cluster
kubectl run my-app --image=my-app:latest
```

### Create Multi-Node Cluster
```bash
cat > kind-config.yaml << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: dev-cluster
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30000
    hostPort: 8080
- role: worker
- role: worker
EOF

kind create cluster --config kind-config.yaml
```

### Cleanup
```bash
kind delete cluster --name my-cluster
```

## Common Commands

```bash
# List clusters
kind get clusters

# Get cluster info
kubectl cluster-info --context kind-my-cluster

# Switch contexts
kubectl config use-context kind-my-cluster

# View all resources
kubectl get all --all-namespaces

# Delete cluster
kind delete cluster --name my-cluster
```

## Troubleshooting

### Docker Not Running?
```bash
open -a Docker
# Wait for Docker Desktop to start
```

### Cluster Won't Start?
```bash
# Restart Docker Desktop
killall Docker && open -a Docker

# Delete and recreate
kind delete cluster --name my-cluster
kind create cluster --name my-cluster
```

### Port Already in Use?
```bash
# Check what's using the port
lsof -i :8080

# Use different port in kind-config.yaml
```

## Full Documentation

For complete details, see:
- `docs/Kind-K8s.md` - Comprehensive guide
- `docs/Lab-Setup-Guide.md` - Full CI/CD pipeline setup
- https://kind.sigs.k8s.io/ - Official Kind documentation

---

**Time to First Cluster:** < 2 minutes
**Cost:** $0.00
**Complexity:** Low
**Ready for:** Learning, Development, Testing
