# Jenkins Docker Integration Guide

## Problem
Jenkins running in a container cannot execute `docker` commands because Docker is not installed or accessible inside the Jenkins container.

**Error:**
```
docker: not found
```

---

## Solution Options

### Option 1: Mount Docker Socket (Recommended) ✅

This allows Jenkins to use the host's Docker daemon.

#### Stop Current Jenkins Container
```bash
# Find Jenkins container
docker ps | grep jenkins

# Stop it
docker stop <jenkins-container-id>

# Remove it (your data is preserved in volumes)
docker rm <jenkins-container-id>
```

#### Start Jenkins with Docker Access

**Basic Setup:**
```bash
docker run -d \
  --name jenkins \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(which docker):/usr/bin/docker \
  jenkins/jenkins:lts
```

**Full Setup with Network:**
```bash
docker run -d \
  --name jenkins \
  --network cicd-network \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(which docker):/usr/bin/docker \
  --group-add $(stat -c '%g' /var/run/docker.sock) \
  jenkins/jenkins:lts
```

**For macOS:**
```bash
docker run -d \
  --name jenkins \
  --network cicd-network \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts
```

#### Key Parameters Explained:
- `-v /var/run/docker.sock:/var/run/docker.sock` - Mount Docker socket
- `-v $(which docker):/usr/bin/docker` - Mount Docker binary (Linux)
- `--network cicd-network` - Connect to same network as Harbor
- `--group-add` - Add Jenkins user to Docker group (Linux only)

---

### Option 2: Use Docker-in-Docker (DinD) Image

Use a Jenkins image with Docker pre-installed.

```bash
docker run -d \
  --name jenkins \
  --privileged \
  --network cicd-network \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts-jdk17
```

Or use the official Docker-in-Docker setup:

```bash
docker run -d \
  --name jenkins-docker \
  --privileged \
  --network cicd-network \
  -e DOCKER_TLS_CERTDIR=/certs \
  -v jenkins-docker-certs:/certs/client \
  -v jenkins_home:/var/jenkins_home \
  -p 8080:8080 -p 50000:50000 \
  docker:dind
```

---

### Option 3: Install Docker in Jenkins Container (Not Recommended)

This requires rebuilding the Jenkins image.

**Dockerfile:**
```dockerfile
FROM jenkins/jenkins:lts

USER root

# Install Docker
RUN apt-get update && \
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli && \
    apt-get clean

USER jenkins
```

**Build and run:**
```bash
docker build -t jenkins-with-docker .
docker run -d \
  --name jenkins \
  --network cicd-network \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins-with-docker
```

---

## Verification Steps

### 1. Check Docker is Available in Jenkins

Open Jenkins → Script Console (Manage Jenkins → Script Console):

```groovy
def sout = new StringBuilder(), serr = new StringBuilder()
def proc = 'docker --version'.execute()
proc.consumeProcessOutput(sout, serr)
proc.waitForOrKill(1000)
println "out> $sout\nerr> $serr"
```

Expected output:
```
out> Docker version 24.x.x, build xxxxx
```

### 2. Test in Pipeline

Create a test job with:
```groovy
pipeline {
    agent any
    stages {
        stage('Test Docker') {
            steps {
                sh 'docker --version'
                sh 'docker ps'
            }
        }
    }
}
```

### 3. Check Docker Socket Permissions

If you get permission errors:

```bash
# On host machine
ls -l /var/run/docker.sock

# Should show something like:
# srw-rw---- 1 root docker 0 Oct 14 12:00 /var/run/docker.sock
```

Inside Jenkins container:
```bash
docker exec -it jenkins bash
ls -l /var/run/docker.sock
groups
docker ps  # Should work without sudo
```

---

## Common Issues and Solutions

### Issue 1: Permission Denied on Docker Socket

**Error:**
```
Got permission denied while trying to connect to the Docker daemon socket
```

**Solution (Linux):**
```bash
# Get Docker group ID
stat -c '%g' /var/run/docker.sock

# Restart Jenkins with that group
docker run -d \
  --name jenkins \
  --group-add $(stat -c '%g' /var/run/docker.sock) \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ...other options...
  jenkins/jenkins:lts
```

**Solution (macOS/Windows with Docker Desktop):**
```bash
# Docker Desktop handles permissions automatically
# Just mount the socket
docker run -d \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ...other options...
  jenkins/jenkins:lts
```

### Issue 2: Docker Binary Not Found

**Error:**
```
docker: not found
```

**Solution:** Install Docker CLI in Jenkins container

```bash
docker exec -u root -it jenkins bash

# Inside container
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bullseye stable" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce-cli
exit
```

### Issue 3: Cannot Connect to Docker Daemon

**Error:**
```
Cannot connect to the Docker daemon at unix:///var/run/docker.sock
```

**Solution:** Ensure Docker is running on host and socket is mounted

```bash
# On host
docker ps  # Should work

# Check Jenkins container
docker inspect jenkins | grep -A 10 Mounts

# Should show docker.sock mount
```

---

## Docker Compose Setup (Alternative)

If you prefer using Docker Compose for Jenkins:

**docker-compose.yml:**
```yaml
version: '3.8'

services:
  jenkins:
    image: jenkins/jenkins:lts
    container_name: jenkins
    privileged: true
    user: root
    ports:
      - "8080:8080"
      - "50000:50000"
    networks:
      - cicd-network
    volumes:
      - jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
      - /usr/bin/docker:/usr/bin/docker
    environment:
      - DOCKER_HOST=unix:///var/run/docker.sock

networks:
  cicd-network:
    external: true

volumes:
  jenkins_home:
```

**Start:**
```bash
docker-compose up -d
```

---

## Security Considerations

### ⚠️ Mounting Docker Socket = Root Access

Mounting the Docker socket gives Jenkins **full access to the host's Docker daemon**, which means:
- Jenkins can create, modify, or delete ANY container
- Jenkins can mount ANY host directory
- Jenkins effectively has **root access** to the host

**Mitigation strategies:**
1. Use dedicated Jenkins server (not shared infrastructure)
2. Implement proper Jenkins access controls
3. Use Jenkins Pipeline libraries to restrict Docker commands
4. Consider using Podman instead of Docker
5. Use Kubernetes agents instead of Docker socket

---

## Recommended Setup for Production

```bash
#!/bin/bash

# Create network if it doesn't exist
docker network create cicd-network 2>/dev/null || true

# Stop and remove old Jenkins if exists
docker stop jenkins 2>/dev/null || true
docker rm jenkins 2>/dev/null || true

# Start Jenkins with Docker access
docker run -d \
  --name jenkins \
  --restart unless-stopped \
  --network cicd-network \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e JAVA_OPTS="-Djenkins.install.runSetupWizard=false" \
  jenkins/jenkins:lts

echo "Waiting for Jenkins to start..."
sleep 30

# Install Docker CLI in Jenkins
docker exec -u root jenkins bash -c "
  apt-get update && \
  apt-get install -y apt-transport-https ca-certificates curl gnupg && \
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
  echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bullseye stable' > /etc/apt/sources.list.d/docker.list && \
  apt-get update && \
  apt-get install -y docker-ce-cli && \
  apt-get clean
"

echo "✓ Jenkins started with Docker support"
echo "Access Jenkins at: http://localhost:8080"

# Get initial admin password
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

---

## Testing the Setup

After restarting Jenkins with Docker access, run this test pipeline:

```groovy
pipeline {
    agent any

    stages {
        stage('Test Docker') {
            steps {
                sh 'docker --version'
                sh 'docker info'
                sh 'docker ps'
            }
        }

        stage('Test Docker Build') {
            steps {
                sh '''
                    echo "FROM alpine" > Dockerfile.test
                    echo "CMD echo Hello" >> Dockerfile.test
                    docker build -f Dockerfile.test -t test:latest .
                    docker images | grep test
                    docker rmi test:latest
                    rm Dockerfile.test
                '''
            }
        }
    }
}
```

---

## Quick Reference

### Check Jenkins Container Status
```bash
docker ps | grep jenkins
docker logs jenkins --tail 100
```

### Restart Jenkins
```bash
docker restart jenkins
```

### Enter Jenkins Container
```bash
docker exec -it jenkins bash
```

### Check Docker in Jenkins
```bash
docker exec jenkins docker --version
docker exec jenkins docker ps
```

### View Jenkins Logs
```bash
docker logs -f jenkins
```

---

## Related Documentation

- [Docker Socket Security](https://docs.docker.com/engine/security/)
- [Jenkins Docker Plugin](https://plugins.jenkins.io/docker-plugin/)
- [Docker-in-Docker](https://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/)
