# Troubleshooting Guide

## Overview
This guide provides solutions to common issues encountered while setting up and running the DevOps CI/CD learning laboratory.

## Table of Contents
- [Docker Issues](#docker-issues)
- [Jenkins Problems](#jenkins-problems)
- [Harbor Registry Issues](#harbor-registry-issues)
- [Kind Kubernetes Issues](#kind-kubernetes-issues)
- [Maven Build Problems](#maven-build-problems)
- [SonarQube Issues](#sonarqube-issues)
- [ArgoCD Problems](#argocd-problems)
- [Helm Chart Issues](#helm-chart-issues)
- [Ansible Problems](#ansible-problems)
- [Network and Connectivity](#network-and-connectivity)

---

## Docker Issues

### Docker Desktop Not Starting (macOS)

**Symptom**: Docker Desktop fails to start or shows "Starting..." indefinitely

**Solutions**:
```bash
# 1. Restart Docker Desktop
killall Docker && open /Applications/Docker.app

# 2. Clear Docker data (WARNING: removes all containers/images)
rm -rf ~/Library/Containers/com.docker.docker
rm -rf ~/Library/Group\ Containers/group.com.docker

# 3. Check system resources
# Ensure at least 4GB RAM and 20GB disk space available

# 4. Check macOS version compatibility
sw_vers
```

### Docker Daemon Not Accessible

**Symptom**: `Cannot connect to the Docker daemon`

**Solutions**:
```bash
# Check Docker status
docker info

# Verify Docker is running
ps aux | grep -i docker

# Restart Docker service (Linux)
sudo systemctl restart docker

# Check permissions (Linux)
sudo usermod -aG docker $USER
newgrp docker
```

### Port Already in Use

**Symptom**: `Bind for 0.0.0.0:8080 failed: port is already allocated`

**Solutions**:
```bash
# Find process using the port
lsof -i :8080

# Kill the process
kill -9 <PID>

# Or modify docker-compose.yml to use different port
ports:
  - "8081:8080"  # Change external port
```

### Insufficient Disk Space

**Symptom**: `no space left on device`

**Solutions**:
```bash
# Check disk usage
df -h

# Remove unused Docker resources
docker system prune -a --volumes

# Remove specific items
docker container prune
docker image prune -a
docker volume prune
docker network prune

# Check Docker disk usage
docker system df
```

---

## Jenkins Problems

### Cannot Access Jenkins UI

**Symptom**: `This site can't be reached` at http://localhost:8080

**Solutions**:
```bash
# 1. Verify Jenkins container is running
docker ps | grep jenkins

# 2. Check Jenkins logs
docker logs jenkins

# 3. Check port mapping
docker port jenkins

# 4. Restart Jenkins container
docker restart jenkins

# 5. Verify no firewall blocking
curl http://localhost:8080
```

### Jenkins Initial Password Not Found

**Symptom**: Cannot find initial admin password

**Solutions**:
```bash
# Method 1: Check container logs
docker logs jenkins | grep -A 5 "password"

# Method 2: Execute command in container
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword

# Method 3: Check Jenkins volume
docker volume inspect jenkins_home
# Then access the mount point
```

### Pipeline Fails with Maven Not Found

**Symptom**: `mvn: command not found` in Jenkins pipeline

**Solutions**:
```bash
# 1. Install Maven in Jenkins container
docker exec -it jenkins bash
apt-get update && apt-get install -y maven

# 2. Or use Maven Docker image in Jenkinsfile
agent {
    docker {
        image 'maven:3.9-eclipse-temurin-21'
    }
}

# 3. Configure Maven tool in Jenkins
# Jenkins > Manage Jenkins > Tools > Maven installations
```

### Docker Permission Denied in Jenkins

**Symptom**: `permission denied while trying to connect to Docker daemon`

**Solutions**:
```bash
# 1. Run Jenkins with proper Docker socket access
docker run -v /var/run/docker.sock:/var/run/docker.sock jenkins/jenkins

# 2. Add Jenkins user to docker group inside container
docker exec -u root jenkins bash
usermod -aG docker jenkins

# 3. Restart Jenkins container
docker restart jenkins
```

### GitHub Webhook Not Triggering

**Symptom**: Push to GitHub doesn't trigger Jenkins build

**Solutions**:
1. **Check webhook configuration**:
   - GitHub > Repository > Settings > Webhooks
   - Payload URL: `http://YOUR_JENKINS_URL/github-webhook/`
   - Content type: `application/json`
   - Events: Push events

2. **Verify Jenkins GitHub plugin**:
   - Jenkins > Manage Plugins > Installed
   - Search for "GitHub Integration Plugin"

3. **Check Jenkins job configuration**:
   ```groovy
   triggers {
       githubPush()
   }
   ```

4. **Use ngrok for local testing**:
   ```bash
   ngrok http 8080
   # Use ngrok URL in GitHub webhook
   ```

---

## Harbor Registry Issues

### Cannot Access Harbor UI

**Symptom**: `ERR_CONNECTION_REFUSED` at http://localhost:8082

**Solutions**:
```bash
# 1. Check Harbor containers
docker-compose -f harbor/docker-compose.yml ps

# 2. Check Harbor logs
docker-compose -f harbor/docker-compose.yml logs

# 3. Restart Harbor
cd harbor
docker-compose down
docker-compose up -d

# 4. Verify port binding
netstat -an | grep 8082
```

### Docker Push to Harbor Fails

**Symptom**: `http: server gave HTTP response to HTTPS client`

**Solutions**:
```bash
# Add Harbor to Docker insecure registries
# Edit Docker Desktop settings or daemon.json

# macOS: Docker Desktop > Preferences > Docker Engine
{
  "insecure-registries": ["localhost:8082"]
}

# Linux: /etc/docker/daemon.json
{
  "insecure-registries": ["localhost:8082"]
}

# Restart Docker
sudo systemctl restart docker  # Linux
# Or restart Docker Desktop on macOS
```

### Harbor Login Fails

**Symptom**: `Error response from daemon: login attempt failed`

**Solutions**:
```bash
# 1. Verify Harbor is running
curl http://localhost:8082

# 2. Use correct credentials
docker login localhost:8082
# Username: admin
# Password: Harbor12345 (default)

# 3. Check Harbor user exists
# Harbor UI > Administration > Users

# 4. Create robot account for CI/CD
./scripts/create-harbor-robot.sh
```

### Harbor Database Initialization Failed

**Symptom**: `database initialization failed`

**Solutions**:
```bash
# 1. Remove Harbor data and start fresh
cd harbor
docker-compose down -v
rm -rf data/database/*
docker-compose up -d

# 2. Check database logs
docker logs harbor-db

# 3. Verify PostgreSQL port not in use
lsof -i :5432
```

---

## Kind Kubernetes Issues

### Kind Cluster Creation Fails

**Symptom**: `ERROR: failed to create cluster`

**Solutions**:
```bash
# 1. Check Docker is running
docker ps

# 2. Delete existing cluster and recreate
kind delete cluster --name kind
kind create cluster --config kind-config.yaml

# 3. Check available resources
docker system df

# 4. Use simpler configuration
kind create cluster
```

### Cannot Connect to Kind Cluster

**Symptom**: `Unable to connect to the server`

**Solutions**:
```bash
# 1. Verify cluster exists
kind get clusters

# 2. Set kubeconfig context
kubectl cluster-info --context kind-kind

# 3. Export kubeconfig
kind export kubeconfig --name kind

# 4. Verify connectivity
kubectl get nodes

# 5. Check API server
docker ps | grep kind-control-plane
```

### Pods Stuck in Pending State

**Symptom**: `kubectl get pods` shows pods in Pending

**Solutions**:
```bash
# 1. Describe pod to see events
kubectl describe pod <pod-name>

# 2. Check node resources
kubectl describe nodes

# 3. Check if image can be pulled
kubectl get events --sort-by='.lastTimestamp'

# 4. Check for ImagePullBackOff
kubectl get pods
# If ImagePullBackOff, check image name and registry access
```

### Kind Node Out of Disk Space

**Symptom**: Pods failing due to disk pressure

**Solutions**:
```bash
# 1. Clean up Docker
docker system prune -a

# 2. Delete unused images in Kind nodes
docker exec kind-control-plane crictl rmi --prune

# 3. Increase Docker disk space
# Docker Desktop > Preferences > Resources > Disk

# 4. Recreate cluster with more space
kind delete cluster
kind create cluster --config kind-config.yaml
```

---

## Maven Build Problems

### Maven Dependencies Cannot Be Downloaded

**Symptom**: `Could not resolve dependencies`

**Solutions**:
```bash
# 1. Clear Maven cache
rm -rf ~/.m2/repository

# 2. Force update dependencies
mvn clean install -U

# 3. Check Maven settings
cat ~/.m2/settings.xml

# 4. Use Maven wrapper
./mvnw clean install

# 5. Check internet connectivity
ping repo.maven.apache.org
```

### Compilation Errors

**Symptom**: `compilation failed`

**Solutions**:
```bash
# 1. Verify Java version
java -version
# Should be Java 21

# 2. Set JAVA_HOME
export JAVA_HOME=/path/to/jdk-21

# 3. Clean and rebuild
mvn clean compile

# 4. Check pom.xml for version mismatches
cat pom.xml | grep version
```

### Tests Failing

**Symptom**: `Tests run: X, Failures: Y`

**Solutions**:
```bash
# 1. Run tests with more details
mvn test -X

# 2. Run specific test
mvn test -Dtest=TestClassName

# 3. Skip tests temporarily (not recommended)
mvn package -DskipTests

# 4. Check test logs
cat target/surefire-reports/*.txt
```

---

## SonarQube Issues

### SonarQube Not Starting

**Symptom**: Container exits immediately

**Solutions**:
```bash
# 1. Check logs
docker logs sonarqube

# 2. Increase max_map_count (Linux)
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf

# 3. Check memory allocation
# SonarQube needs at least 2GB RAM

# 4. Remove and recreate
docker rm sonarqube
docker run -d --name sonarqube -p 9000:9000 sonarqube:latest
```

### Quality Gate Fails

**Symptom**: SonarQube analysis shows failures

**Solutions**:
```bash
# 1. Review quality gate rules
# SonarQube UI > Quality Gates

# 2. Check specific issues
# SonarQube UI > Projects > Your Project > Issues

# 3. Run analysis locally
mvn sonar:sonar -Dsonar.host.url=http://localhost:9000

# 4. Adjust quality gate thresholds (for learning)
# SonarQube UI > Quality Gates > Copy > Modify conditions
```

### Cannot Generate Token

**Symptom**: Token generation fails

**Solutions**:
```bash
# 1. Login as admin
# Default: admin/admin

# 2. Change default password
# SonarQube will force password change on first login

# 3. Generate token
# User Menu > My Account > Security > Generate Token

# 4. Save token immediately (shown only once)
```

---

## ArgoCD Problems

### Cannot Access ArgoCD UI

**Symptom**: Connection refused on port 8080

**Solutions**:
```bash
# 1. Check ArgoCD pods
kubectl get pods -n argocd

# 2. Port forward ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 3. Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# 4. Check service
kubectl get svc -n argocd
```

### Application Sync Fails

**Symptom**: ArgoCD shows "OutOfSync" or sync errors

**Solutions**:
```bash
# 1. Check application status
kubectl get applications -n argocd

# 2. Describe application
kubectl describe application <app-name> -n argocd

# 3. Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-application-controller

# 4. Manually sync
argocd app sync <app-name>

# 5. Hard refresh
argocd app sync <app-name> --force
```

### Git Repository Connection Issues

**Symptom**: Cannot connect to GitHub repository

**Solutions**:
```bash
# 1. Add repository credentials
argocd repo add https://github.com/user/repo \
  --username <user> --password <token>

# 2. Verify repository
argocd repo list

# 3. Test connection
argocd repo get https://github.com/user/repo

# 4. Use HTTPS instead of SSH
# Or add SSH key to ArgoCD
```

---

## Helm Chart Issues

### Helm Install Fails

**Symptom**: `Error: INSTALLATION FAILED`

**Solutions**:
```bash
# 1. Dry run to check template
helm install --dry-run --debug myapp ./helm-charts/cicd-demo

# 2. Lint chart
helm lint ./helm-charts/cicd-demo

# 3. Check values
helm template myapp ./helm-charts/cicd-demo --values values.yaml

# 4. Install with debug
helm install myapp ./helm-charts/cicd-demo --debug

# 5. Check release status
helm list
helm status myapp
```

### Chart Template Errors

**Symptom**: Template rendering fails

**Solutions**:
```bash
# 1. Validate syntax
helm template ./helm-charts/cicd-demo

# 2. Check for missing values
helm template ./helm-charts/cicd-demo --values values.yaml --debug

# 3. Use helm lint
helm lint ./helm-charts/cicd-demo

# 4. Verify indentation in YAML files
```

---

## Ansible Problems

### Cannot Connect to Hosts

**Symptom**: `Failed to connect to host`

**Solutions**:
```bash
# 1. Test connectivity
ansible all -m ping -i ansible/inventory.ini

# 2. Check inventory
cat ansible/inventory.ini

# 3. Use verbose mode
ansible-playbook playbook.yml -vvv

# 4. Check SSH keys
ssh-add -l
```

### Playbook Execution Fails

**Symptom**: Task fails during execution

**Solutions**:
```bash
# 1. Run with check mode (dry run)
ansible-playbook playbook.yml --check

# 2. Run step by step
ansible-playbook playbook.yml --step

# 3. Start at specific task
ansible-playbook playbook.yml --start-at-task="task name"

# 4. Check syntax
ansible-playbook playbook.yml --syntax-check
```

---

## Network and Connectivity

### Services Cannot Communicate

**Symptom**: Service A cannot reach Service B

**Solutions**:
```bash
# 1. Check network connectivity
docker network ls
docker network inspect bridge

# 2. Use container names for DNS
# Instead of localhost, use container name

# 3. Verify containers are on same network
docker inspect <container> | grep NetworkMode

# 4. Test from inside container
docker exec -it <container> curl http://other-container:port
```

### DNS Resolution Failures

**Symptom**: `could not resolve host`

**Solutions**:
```bash
# 1. Check Docker DNS
docker run --rm alpine nslookup google.com

# 2. Add DNS servers to Docker
# Edit daemon.json
{
  "dns": ["8.8.8.8", "8.8.4.4"]
}

# 3. Restart Docker
sudo systemctl restart docker
```

---

## General Debugging Tips

### Enable Debug Logging

```bash
# Docker
docker logs --follow <container>

# Kubernetes
kubectl logs <pod> --follow
kubectl logs <pod> --previous  # For crashed pods

# Jenkins
# Manage Jenkins > System Log > All Jenkins Logs

# Maven
mvn -X clean install  # Debug mode
```

### Check System Resources

```bash
# Disk space
df -h

# Memory
free -h  # Linux
vm_stat  # macOS

# Docker resources
docker system df
docker stats

# Kubernetes resources
kubectl top nodes
kubectl top pods
```

### Reset Everything

```bash
# Stop all containers
docker stop $(docker ps -aq)

# Remove all containers
docker rm $(docker ps -aq)

# Remove all volumes (WARNING: data loss)
docker volume prune -a

# Delete Kind cluster
kind delete cluster --name kind

# Restart Docker Desktop
killall Docker && open /Applications/Docker.app

# Start fresh
./scripts/setup-all.sh
```

---

## Getting Help

If issues persist:

1. Check logs with verbose/debug mode
2. Search GitHub issues: https://github.com/gmedeirosnet/CI.CD/issues
3. Review tool-specific documentation in `docs/` directory
4. Verify system meets prerequisites (16GB RAM, 50GB disk)
5. Check official documentation for each tool

## Quick Reference Commands

```bash
# Check all services status
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Check Kubernetes
kubectl get all --all-namespaces

# Check logs for all services
docker-compose logs -f

# Restart everything
docker-compose restart

# Clean restart
docker-compose down && docker-compose up -d
```
