# Jenkins Build Docker Image Stage - Error Analysis

## 📊 Error Summary

**Stage:** Build Docker Image
**Error:** `docker: not found`
**Pipeline Log:** `/Users/gutembergmedeiros/Labs/CI.CD/temp/pipeline.log`

```
[Pipeline] sh
+ docker build -t localhost:8082/cicd-demo/app:27 .
/var/jenkins_home/workspace/CI.CD_main@tmp/durable-e1a82542/script.sh.copy: 2: docker: not found
```

---

## 🔍 Root Cause Analysis

### What Happened
1. Jenkins pipeline reached the "Build Docker Image" stage
2. Attempted to execute `docker build` command
3. Jenkins container searched for `docker` binary
4. Binary not found in PATH: `/var/jenkins_home/workspace/...`
5. Build failed with error code (docker command not found)

### Why It Happened
- **Jenkins is running inside a Docker container** (`/var/jenkins_home/` path indicates containerized Jenkins)
- **Docker is NOT installed** inside the Jenkins container by default
- **Docker socket is NOT mounted** or Docker CLI is not available
- Jenkins cannot execute docker commands without proper setup

### Technical Details
- **Working Directory:** `/var/jenkins_home/workspace/CI.CD_main`
- **Expected Command:** `docker build -t localhost:8082/cicd-demo/app:27 .`
- **Shell:** `/bin/sh` (POSIX shell)
- **Error Type:** Command not found (exit code 127)

---

## ✅ Solution Summary

### Required Changes

Jenkins container needs:
1. **Docker CLI installed** (docker command binary)
2. **Docker socket mounted** (`/var/run/docker.sock`)
3. **Proper permissions** to access Docker daemon

### Implementation Options

| Option | Difficulty | Downtime | Recommended |
|--------|-----------|----------|-------------|
| Run setup script | ⭐ Easy | ~2 min | ✅ **YES** |
| Manual Docker CLI install | ⭐⭐ Medium | None | For quick fix |
| Restart Jenkins with socket | ⭐⭐⭐ Hard | ~5 min | For clean setup |

---

## 🚀 Recommended Actions

### 1️⃣ Immediate Fix (Quickest - No Restart)

```bash
# Install Docker CLI in running Jenkins container
docker exec -u root jenkins bash -c "apt-get update && apt-get install -y docker.io"

# Fix permissions
docker exec -u root jenkins chmod 666 /var/run/docker.sock

# Verify
docker exec jenkins docker --version
```

**⚠️ Note:** May require Docker socket to already be mounted. If this fails, use option 2.

---

### 2️⃣ Automated Setup (Recommended - Full Fix)

```bash
cd /Users/gutembergmedeiros/Labs/CI.CD

# Make executable
chmod +x scripts/setup-jenkins-docker.sh

# Run automated setup
./scripts/setup-jenkins-docker.sh
```

**What it does:**
- ✓ Stops current Jenkins
- ✓ Restarts with Docker socket mounted
- ✓ Installs Docker CLI properly
- ✓ Configures permissions
- ✓ Tests Docker access
- ✓ **Preserves all Jenkins data** (jobs, configs, history)

**Downtime:** ~2-3 minutes

---

### 3️⃣ Manual Setup (Full Control)

See detailed steps in: `docs/Jenkins-Docker-Integration.md`

---

## 🔄 Post-Fix Verification

After applying the fix, verify with these commands:

```bash
# 1. Check Docker is installed
docker exec jenkins docker --version
# Expected: Docker version 24.x.x

# 2. Check Docker daemon is accessible
docker exec jenkins docker ps
# Expected: List of running containers

# 3. Check can build images
docker exec jenkins docker build --help
# Expected: Docker build command help
```

---

## 📈 Expected Pipeline Behavior After Fix

### Before Fix (Current State) ❌
```
[Build Docker Image] Started
+ docker build -t localhost:8082/cicd-demo/app:27 .
docker: not found
[Build Docker Image] FAILED
```

### After Fix (Expected) ✅
```
[Build Docker Image] Started
+ docker build -t localhost:8082/cicd-demo/app:27 .
Sending build context to Docker daemon  XXX kB
Step 1/11 : FROM maven:3.9-eclipse-temurin-21 AS builder
 ---> abc123def456
Step 2/11 : WORKDIR /app
 ---> Running in xyz789
...
Successfully built abc123def456
Successfully tagged localhost:8082/cicd-demo/app:27
[Build Docker Image] SUCCESS
```

---

## 🎯 Impact Assessment

### Affected Stages
1. ✅ **Checkout** - Working
2. ✅ **Setup Maven Wrapper** - Working
3. ✅ **Build with Maven** - Working
4. ✅ **Unit Tests** - Working
5. ⏸️ **SonarQube Analysis** - Commented out
6. ⏸️ **Quality Gate** - Commented out
7. ❌ **Build Docker Image** - **FAILED** (current issue)
8. ⏸️ **Push to Harbor** - Blocked (depends on #7)
9. ⏸️ **Update Helm Chart** - Blocked
10. ⏸️ **Deploy to Kubernetes** - Blocked
11. ⏸️ **Ansible Configuration** - Blocked

### Blocking Issues
- Without Docker access, **all remaining stages are blocked**
- Cannot build container images
- Cannot push to Harbor registry
- Cannot deploy to Kubernetes
- Pipeline stops at 43% completion (3 of 7 active stages)

---

## 📚 Documentation Created

1. **Full Integration Guide:**
   `docs/Jenkins-Docker-Integration.md`
   - Complete step-by-step instructions
   - Multiple setup options
   - Security considerations
   - Troubleshooting guide

2. **Automated Setup Script:**
   `scripts/setup-jenkins-docker.sh`
   - One-command fix
   - Automatic detection and configuration
   - Verification tests

3. **Quick Fix Guide:**
   `docs/Jenkins-Docker-QuickFix.md`
   - Fast solutions
   - Common issues
   - TL;DR commands

4. **This Analysis:**
   `docs/Jenkins-Docker-Error-Analysis.md`
   - Root cause analysis
   - Recommended actions
   - Impact assessment

---

## 🛠️ Related Configuration

### Current Jenkinsfile Stage (Working Code)
```groovy
stage('Build Docker Image') {
    steps {
        script {
            sh """
                docker build -t ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG} .
                docker tag ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG} \
                           ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:latest
            """
        }
    }
}
```

**Note:** The Jenkinsfile is correct. The issue is the Jenkins environment, not the code.

### Current Environment Variables
```groovy
environment {
    HARBOR_REGISTRY = 'localhost:8082'
    HARBOR_PROJECT = 'cicd-demo'
    IMAGE_NAME = 'app'
    IMAGE_TAG = "${BUILD_NUMBER}"
}
```

### Dockerfile (Verified Present)
Location: `/Users/gutembergmedeiros/Labs/CI.CD/Dockerfile`
```dockerfile
FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
EXPOSE 8080
CMD ["java", "-jar", "app.jar"]
```
**Status:** ✅ Dockerfile is valid and ready

---

## ⚡ Quick Action Summary

**To fix this issue RIGHT NOW:**

```bash
# Option 1: Run the automated script (RECOMMENDED)
cd /Users/gutembergmedeiros/Labs/CI.CD
chmod +x scripts/setup-jenkins-docker.sh
./scripts/setup-jenkins-docker.sh

# Option 2: Quick manual fix (if script doesn't work)
docker exec -u root jenkins apt-get update && apt-get install -y docker.io
docker exec -u root jenkins chmod 666 /var/run/docker.sock

# Verify it works
docker exec jenkins docker --version

# Then rebuild your pipeline in Jenkins!
```

---

## 📞 Support

If issues persist after applying fixes:

1. **Check Jenkins logs:**
   ```bash
   docker logs jenkins --tail 100
   ```

2. **Check Docker socket:**
   ```bash
   docker exec jenkins ls -l /var/run/docker.sock
   ```

3. **Test Docker access:**
   ```bash
   docker exec jenkins docker ps
   ```

4. **Review full documentation:**
   - `docs/Jenkins-Docker-Integration.md`
   - `docs/Jenkins-Docker-QuickFix.md`

---

**Last Updated:** October 14, 2025
**Status:** Solution provided, awaiting implementation
**Next Step:** Run `./scripts/setup-jenkins-docker.sh` to fix the issue
