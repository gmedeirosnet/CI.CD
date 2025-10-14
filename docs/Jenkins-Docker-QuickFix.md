# Jenkins Docker Build Error - Quick Fix Guide

## 🔴 Error
```
docker: not found
```

## 🎯 Root Cause
Jenkins container doesn't have access to Docker daemon.

---

## ⚡ Quick Fix (Choose One)

### Option 1: Run Setup Script (Easiest) ✅
```bash
cd /Users/gutembergmedeiros/Labs/CI.CD

# Make executable
chmod +x scripts/setup-jenkins-docker.sh

# Run script
./scripts/setup-jenkins-docker.sh
```

The script will:
- ✓ Stop current Jenkins
- ✓ Restart with Docker access
- ✓ Install Docker CLI
- ✓ Test Docker commands
- ✓ Preserve all your data

---

### Option 2: Manual Fix (Fast)

**1. Install Docker CLI in Jenkins:**
```bash
docker exec -u root jenkins bash -c "
  apt-get update && \
  apt-get install -y docker.io
"
```

**2. Fix Docker socket permissions:**
```bash
docker exec -u root jenkins chmod 666 /var/run/docker.sock
```

**3. Test:**
```bash
docker exec jenkins docker --version
docker exec jenkins docker ps
```

---

### Option 3: Restart Jenkins with Docker Access

**Stop current Jenkins:**
```bash
docker stop jenkins
docker rm jenkins
```

**Start with Docker socket:**
```bash
docker run -d \
  --name jenkins \
  --network cicd-network \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts
```

**Install Docker CLI:**
```bash
docker exec -u root jenkins bash -c "
  apt-get update && \
  apt-get install -y apt-transport-https ca-certificates curl gnupg && \
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
  echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bullseye stable' > /etc/apt/sources.list.d/docker.list && \
  apt-get update && \
  apt-get install -y docker-ce-cli
"
```

---

## ✅ Verification

Test Docker access:
```bash
# Should show Docker version
docker exec jenkins docker --version

# Should list containers
docker exec jenkins docker ps

# Should work without errors
docker exec jenkins docker info
```

---

## 🔄 After Fix

1. **Go to Jenkins:** http://localhost:8080
2. **Run your pipeline** (Build Now)
3. **Build Docker Image stage should succeed:**
```
+ docker build -t localhost:8082/cicd-demo/app:27 .
Successfully built xxxxx
Successfully tagged localhost:8082/cicd-demo/app:27
```

---

## 🚨 Still Not Working?

### Permission Denied Error
```bash
# Fix socket permissions
docker exec -u root jenkins chmod 666 /var/run/docker.sock
```

### Docker Socket Not Mounted
```bash
# Check if socket is mounted
docker inspect jenkins | grep -A 5 Mounts

# Should show: /var/run/docker.sock
```

### Cannot Connect to Docker Daemon
```bash
# Restart Docker
sudo systemctl restart docker  # Linux
# OR restart Docker Desktop (Mac/Windows)

# Then restart Jenkins
docker restart jenkins
```

---

## 📚 Full Documentation

See: `docs/Jenkins-Docker-Integration.md` for complete guide.

---

## 💡 Understanding the Fix

**The Problem:**
- Jenkins runs in a Docker container
- Docker CLI is not installed in Jenkins container
- Jenkins cannot access host's Docker daemon

**The Solution:**
- Mount Docker socket: `/var/run/docker.sock`
- Install Docker CLI in Jenkins container
- Now Jenkins can use host's Docker to build images

**Architecture:**
```
┌─────────────────────────────────┐
│   Jenkins Container             │
│   - Has Docker CLI              │
│   - Uses Docker socket   ────┐  │
└──────────────────────────────│──┘
                               │
                               │ Docker Socket
                               │
┌──────────────────────────────▼──┐
│   Host Docker Daemon            │
│   - Builds images               │
│   - Manages containers          │
└─────────────────────────────────┘
```

**Security Note:**
Mounting Docker socket gives Jenkins full access to Docker daemon (root-level access). This is acceptable for development but consider security implications in production.

---

## 🎯 TL;DR

**Fastest fix:**
```bash
# Option A: Run the setup script
./scripts/setup-jenkins-docker.sh

# Option B: Install Docker CLI manually
docker exec -u root jenkins apt-get update && apt-get install -y docker.io
docker exec -u root jenkins chmod 666 /var/run/docker.sock
docker exec jenkins docker --version  # Should work!
```

**Then run your Jenkins pipeline again!** 🚀
