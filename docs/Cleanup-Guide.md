# Cleanup Guide

## Overview
This guide provides comprehensive instructions for tearing down the DevOps CI/CD learning laboratory environment, including all services, containers, volumes, and configurations.

## Table of Contents
- [Quick Cleanup](#quick-cleanup)
- [Service-by-Service Cleanup](#service-by-service-cleanup)
- [Complete Environment Reset](#complete-environment-reset)
- [Selective Cleanup](#selective-cleanup)
- [Verification](#verification)

---

## Quick Cleanup

### Stop All Services

```bash
# Stop all Docker containers
docker stop $(docker ps -aq)

# Delete Kind cluster
kind delete cluster --name kind

# Stop Harbor
cd harbor && docker-compose down

# Stop SonarQube
docker stop sonarqube
```

### Remove All Resources

```bash
# Remove all containers
docker rm $(docker ps -aq)

# Remove all volumes (WARNING: Data loss)
docker volume prune -f

# Remove all networks
docker network prune -f

# Remove all images
docker image prune -a -f
```

---

## Service-by-Service Cleanup

### 1. Jenkins

```bash
# Stop Jenkins container
docker stop jenkins

# Remove Jenkins container
docker rm jenkins

# Remove Jenkins volume (optional - contains job configurations)
docker volume rm jenkins_home

# Or keep volume for later reuse
# List volumes: docker volume ls | grep jenkins
```

**What gets removed**:
- Jenkins container
- All pipeline configurations (if volume removed)
- Job history
- Installed plugins (if volume removed)

**What to keep**:
- Jenkins volume if you want to preserve configurations

---

### 2. Harbor Registry

```bash
# Navigate to Harbor directory
cd harbor

# Stop Harbor services
docker-compose down

# Remove Harbor volumes (includes images)
docker-compose down -v

# Remove Harbor data directory
rm -rf data/database/*
rm -rf data/registry/*
rm -rf data/redis/*

# Remove Harbor configuration (optional)
rm -f harbor.yml
```

**What gets removed**:
- All container images stored in Harbor
- Harbor database
- Harbor configuration
- SSL certificates

**What to keep**:
- `harbor.yml.tmpl` template file
- Original Harbor installation scripts

---

### 3. SonarQube

```bash
# Stop SonarQube
docker stop sonarqube

# Remove container
docker rm sonarqube

# Remove volumes
docker volume rm sonarqube_data
docker volume rm sonarqube_logs
docker volume rm sonarqube_extensions

# Or remove all SonarQube volumes
docker volume ls | grep sonar | awk '{print $2}' | xargs docker volume rm
```

**What gets removed**:
- Code analysis history
- Quality profiles
- Quality gates
- User accounts
- Project data

---

### 4. Kind Kubernetes Cluster

```bash
# Delete cluster
kind delete cluster --name kind

# Remove all Kind-related containers
docker ps -a | grep kind | awk '{print $1}' | xargs docker rm -f

# Remove Kind images (optional)
docker images | grep kindest | awk '{print $3}' | xargs docker rmi -f

# Clean up kubeconfig
kubectl config delete-context kind-kind
kubectl config delete-cluster kind-kind
```

**What gets removed**:
- All Kubernetes resources (deployments, services, pods, etc.)
- Kind control plane and worker nodes
- All deployed applications
- Helm releases
- ArgoCD applications

**Verification**:
```bash
# Should show no clusters
kind get clusters

# Should show no Kind contexts
kubectl config get-contexts
```

---

### 5. ArgoCD

```bash
# If running in Kubernetes (before deleting Kind cluster)
kubectl delete namespace argocd

# Remove ArgoCD CLI (optional)
rm /usr/local/bin/argocd  # macOS/Linux

# Clean up local config
rm -rf ~/.argocd
```

**What gets removed**:
- ArgoCD applications
- ArgoCD configurations
- Sync history
- Repository credentials

---

### 6. Application Deployments

```bash
# Before deleting Kind cluster, remove Helm releases
helm list --all-namespaces
helm uninstall <release-name> -n <namespace>

# Or delete all Helm releases
helm list --all-namespaces --short | xargs -L1 helm uninstall

# Delete Kubernetes resources
kubectl delete all --all -n default
kubectl delete all --all -n <your-namespace>
```

---

## Complete Environment Reset

### Full Cleanup Script

```bash
#!/bin/bash

set -e

echo "Starting complete cleanup..."

# 1. Stop all containers
echo "Stopping all containers..."
docker stop $(docker ps -aq) 2>/dev/null || true

# 2. Delete Kind cluster
echo "Deleting Kind cluster..."
kind delete cluster --name kind 2>/dev/null || true

# 3. Stop Harbor
echo "Stopping Harbor..."
if [ -d "harbor" ]; then
    cd harbor
    docker-compose down -v 2>/dev/null || true
    cd ..
fi

# 4. Remove all containers
echo "Removing all containers..."
docker rm $(docker ps -aq) 2>/dev/null || true

# 5. Remove all volumes
echo "Removing all volumes..."
docker volume prune -f

# 6. Remove all networks
echo "Removing all networks..."
docker network prune -f

# 7. Remove all unused images
echo "Removing unused images..."
docker image prune -a -f

# 8. Clean up Kubernetes config
echo "Cleaning kubeconfig..."
kubectl config delete-context kind-kind 2>/dev/null || true
kubectl config delete-cluster kind-kind 2>/dev/null || true

# 9. Remove build artifacts
echo "Cleaning build artifacts..."
rm -rf target/ 2>/dev/null || true
rm -rf .mvn/ 2>/dev/null || true

echo "Cleanup complete!"
docker system df
```

Save as `scripts/cleanup-all.sh` and run:
```bash
chmod +x scripts/cleanup-all.sh
./scripts/cleanup-all.sh
```

---

## Selective Cleanup

### Keep Data, Remove Containers Only

```bash
# Stop and remove containers but keep volumes
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)

# Volumes are preserved
docker volume ls
```

### Remove Specific Service

```bash
# Example: Remove only Jenkins
docker stop jenkins && docker rm jenkins

# Keep or remove volume
docker volume ls | grep jenkins
# To remove: docker volume rm jenkins_home
```

### Clean Build Artifacts Only

```bash
# Clean Maven artifacts
mvn clean
rm -rf target/

# Clean Docker build cache
docker builder prune -a -f

# Clean npm (if any Node.js tools)
rm -rf node_modules/
```

---

## Verification

### Check All Resources Removed

```bash
# Check containers
docker ps -a
# Should show: empty or only unrelated containers

# Check volumes
docker volume ls
# Should show: no jenkins, harbor, sonarqube volumes

# Check networks
docker network ls
# Should show: only default Docker networks

# Check images
docker images
# Should show: empty or only base images

# Check Kind clusters
kind get clusters
# Should show: No kind clusters found

# Check Kubernetes contexts
kubectl config get-contexts
# Should show: no kind-kind context

# Check disk usage
docker system df
```

### Verify Ports Released

```bash
# Check if ports are free
lsof -i :8080  # Should be empty
lsof -i :8082  # Should be empty
lsof -i :9000  # Should be empty
lsof -i :6443  # Should be empty
```

---

## Cleanup Checklist

Use this checklist to ensure complete cleanup:

- [ ] Jenkins container stopped and removed
- [ ] Jenkins volume removed (if desired)
- [ ] Harbor containers stopped and removed
- [ ] Harbor volumes and data removed
- [ ] SonarQube container and volumes removed
- [ ] Kind cluster deleted
- [ ] ArgoCD namespace removed (if applicable)
- [ ] All Helm releases uninstalled
- [ ] Kubernetes contexts cleaned from kubeconfig
- [ ] All Docker containers removed
- [ ] All Docker volumes pruned
- [ ] All Docker networks pruned
- [ ] Docker images pruned (optional)
- [ ] Build artifacts cleaned (target/, etc.)
- [ ] Ports verified as released
- [ ] Disk space recovered

---

## Preserving Important Data

### Before Cleanup - Backup

```bash
# Backup Jenkins configurations
docker cp jenkins:/var/jenkins_home/jobs ./jenkins-backup/

# Export Harbor images
docker save -o harbor-images.tar $(docker images localhost:8082/* -q)

# Backup Kubernetes resources
kubectl get all --all-namespaces -o yaml > k8s-backup.yaml

# Backup Helm releases
helm list --all-namespaces -o yaml > helm-releases.yaml

# Backup environment variables
cp .env .env.backup
```

### After Cleanup - Restore

```bash
# Restore Jenkins jobs
docker cp ./jenkins-backup jenkins:/var/jenkins_home/jobs/

# Restore Harbor images
docker load -i harbor-images.tar
docker tag <image-id> localhost:8082/project/image:tag
docker push localhost:8082/project/image:tag

# Restore Kubernetes resources
kubectl apply -f k8s-backup.yaml
```

---

## Troubleshooting Cleanup Issues

### Container Won't Stop

```bash
# Force stop
docker stop -t 1 <container>
docker kill <container>

# If still running
docker rm -f <container>
```

### Volume in Use

```bash
# Check what's using the volume
docker ps -a --filter volume=<volume-name>

# Stop and remove containers using it
docker stop <container> && docker rm <container>

# Then remove volume
docker volume rm <volume-name>
```

### Permission Denied

```bash
# Run with sudo (Linux)
sudo docker rm <container>
sudo rm -rf /var/lib/docker/volumes/<volume>

# macOS - restart Docker Desktop
killall Docker && open /Applications/Docker.app
```

### Cleanup Script Fails

```bash
# Run commands individually
# Check error messages
# Use verbose mode
docker rm -v <container>  # -v for verbose
```

---

## Post-Cleanup

### Verify Docker Health

```bash
# Check Docker info
docker info

# Check disk usage
docker system df

# Verify Docker is responsive
docker run --rm hello-world
```

### Reset Docker Desktop (macOS)

If issues persist:

1. Docker Desktop > Troubleshoot > Reset to factory defaults
2. Or: `rm -rf ~/Library/Containers/com.docker.docker`
3. Restart Docker Desktop
4. Reinstall if necessary

---

## Partial Cleanup Scenarios

### Keep Infrastructure, Remove Applications

```bash
# Remove application deployments only
kubectl delete deployment --all -n default
helm uninstall myapp

# Keep Jenkins, Harbor, SonarQube running
```

### Clean and Restart

```bash
# Clean everything
./scripts/cleanup-all.sh

# Wait for cleanup to complete
sleep 5

# Start fresh
./scripts/setup-all.sh
```

---

## Environment Variables

After cleanup, you may want to:

```bash
# Remove environment file
rm .env

# Or reset to template
cp .env.template .env
```

---

## Final Notes

- **Always backup important data before cleanup**
- **Volume removal is irreversible**
- **Use selective cleanup during development**
- **Complete cleanup recommended between major changes**
- **Verify cleanup with provided commands**
- **Check disk space recovered**: `df -h`

## Next Steps After Cleanup

1. If restarting lab: Run `./scripts/setup-all.sh`
2. If done with lab: Uninstall Docker Desktop (optional)
3. Remove repository: `rm -rf ~/Labs/CI.CD` (optional)

## Quick Commands Reference

```bash
# Complete cleanup
docker stop $(docker ps -aq) && docker rm $(docker ps -aq) && docker volume prune -f && kind delete cluster

# Verify clean state
docker ps -a && docker volume ls && kind get clusters

# Start fresh
./scripts/setup-all.sh
```
