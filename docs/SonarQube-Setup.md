# SonarQube Setup Guide for CI/CD Pipeline

## Overview
This guide walks you through setting up SonarQube for code quality analysis in your Jenkins CI/CD pipeline.

---

## Prerequisites

- Docker and Docker Compose installed
- Jenkins running in Docker
- Project with `sonar-compose.yml` file

---

## Part 1: Start SonarQube

### Step 1: Create Docker Network
```bash
# Create a shared network for Jenkins, SonarQube, and other services
docker network create cicd-network

# Verify network creation
docker network ls | grep cicd-network
```

### Step 2: Connect Jenkins to the Network
```bash
# Find your Jenkins container ID or name
docker ps | grep jenkins

# Connect Jenkins to the network (replace <jenkins-container> with actual name/ID)
docker network connect cicd-network <jenkins-container>

# Example:
# docker network connect cicd-network jenkins

# Verify connection
docker network inspect cicd-network
```

### Step 3: Start SonarQube
```bash
cd /Users/gutembergmedeiros/Labs/CI.CD

# Start SonarQube and PostgreSQL
docker-compose -f sonar-compose.yml up -d

# Check if containers are running
docker ps | grep sonar

# Watch the logs (wait for "SonarQube is operational")
docker-compose -f sonar-compose.yml logs -f sonarqube
```

**Expected output:**
```
sonarqube  | SonarQube is operational
```

This can take 2-3 minutes. Press `Ctrl+C` to exit log viewing.

### Step 4: Verify SonarQube Access
```bash
# From your host machine
curl -I http://localhost:9000

# You should see HTTP/1.1 200 or 302
```

Open in browser: http://localhost:9000

**Default credentials:**
- Username: `admin`
- Password: `admin`

⚠️ **Important:** You'll be prompted to change the password on first login.

---

## Part 2: Configure SonarQube

### Step 1: Initial Setup
1. Open http://localhost:9000
2. Login with `admin` / `admin`
3. Change password when prompted (e.g., to `admin123`)
4. Click "Skip this tutorial" (or complete it if you prefer)

### Step 2: Generate Authentication Token
1. Click on your profile icon (top right) → **My Account**
2. Click **Security** tab
3. Under "Generate Tokens":
   - Token Name: `Jenkins`
   - Type: `Global Analysis Token`
   - Expires in: `No expiration` (or choose a duration)
4. Click **Generate**
5. **COPY THE TOKEN** immediately (you won't see it again!)
   - Example: `squ_1234567890abcdefghijklmnopqrstuvwxyz`

### Step 3: Create a Project
1. Click **"+ Create Project"** (top right)
2. Choose **Manually**
3. Enter:
   - Project key: `cicd-demo`
   - Display name: `CI/CD Demo`
4. Click **Set Up**
5. Choose baseline: **Previous version**
6. Click **Create project**

---

## Part 3: Configure Jenkins

### Step 1: Install SonarQube Scanner Plugin
1. Open Jenkins: http://localhost:8080
2. Go to **Manage Jenkins** → **Plugins**
3. Click **Available plugins** tab
4. Search: `SonarQube Scanner`
5. Check the box for **SonarQube Scanner for Jenkins**
6. Click **Install**
7. Wait for installation, then check **Restart Jenkins when installation is complete**

Wait for Jenkins to restart (about 30 seconds).

### Step 2: Configure SonarQube Server in Jenkins
1. **Manage Jenkins** → **System** (or **Configure System**)
2. Scroll down to **SonarQube servers**
3. Check **Environment variables** → **Enable injection of SonarQube server configuration**
4. Click **Add SonarQube**
5. Fill in:
   - **Name:** `SonarQube` (must match name in Jenkinsfile!)
   - **Server URL:** `http://sonarqube:9000` (use container name)
   - **Server authentication token:**
     - Click **Add** → **Jenkins**
     - Kind: **Secret text**
     - Secret: Paste the token you generated in SonarQube
     - ID: `sonarqube-token`
     - Description: `SonarQube Authentication Token`
     - Click **Add**
     - Select the newly created credential from dropdown
6. Click **Save**

### Step 3: Configure SonarQube Scanner Tool
1. **Manage Jenkins** → **Tools**
2. Scroll to **SonarQube Scanner**
3. Click **Add SonarQube Scanner**
4. Fill in:
   - **Name:** `SonarQube Scanner`
   - Check **Install automatically**
   - Choose latest version from dropdown
5. Click **Save**

---

## Part 4: Update Jenkinsfile

The Jenkinsfile needs to be updated to use the correct SonarQube server URL.

### Update Environment Variables
Make sure your Jenkinsfile has:
```groovy
environment {
    SONAR_HOST = 'http://sonarqube:9000'  // Use container name, not localhost
    // ... other variables
}
```

### Uncomment SonarQube Stages
Remove the `/*` and `*/` around the SonarQube stages in your Jenkinsfile.

---

## Part 5: Test the Integration

### Step 1: Run a Test Build
1. Go to your Jenkins job
2. Click **Build Now**
3. Monitor the build output

### Step 2: Verify SonarQube Analysis
1. Build should show:
   ```
   [INFO] ANALYSIS SUCCESSFUL
   [INFO] BUILD SUCCESS
   ```
2. Go to SonarQube UI: http://localhost:9000
3. You should see your project `cicd-demo` with analysis results

---

## Troubleshooting

### Issue: "SonarQube server cannot be reached"
**Solution:**
```bash
# Ensure both containers are on the same network
docker network inspect cicd-network

# You should see both jenkins and sonarqube containers listed
```

### Issue: "Failed to authenticate with SonarQube"
**Solution:**
- Regenerate token in SonarQube
- Update credential in Jenkins
- Rebuild the job

### Issue: "Connection refused to localhost:9000"
**Solution:**
- Change SONAR_HOST from `localhost` to `sonarqube` (container name)
- Restart Jenkins to apply changes

### Issue: SonarQube won't start
**Solution:**
```bash
# Check logs
docker-compose -f sonar-compose.yml logs sonarqube

# Common issue: Increase max_map_count on host
sudo sysctl -w vm.max_map_count=524288

# For macOS with Docker Desktop, this is usually not needed
```

### Issue: "Quality Gate" stage fails
**Solution:**
- SonarQube needs time to process quality gate
- Check SonarQube UI for quality gate status
- Adjust timeout in Jenkinsfile if needed

---

## Useful Commands

```bash
# Start SonarQube
docker-compose -f sonar-compose.yml up -d

# Stop SonarQube
docker-compose -f sonar-compose.yml down

# View logs
docker-compose -f sonar-compose.yml logs -f sonarqube

# Restart SonarQube
docker-compose -f sonar-compose.yml restart sonarqube

# Check if SonarQube is healthy
docker exec sonarqube curl -I http://localhost:9000

# Clean up and start fresh (WARNING: deletes all data)
docker-compose -f sonar-compose.yml down -v
docker-compose -f sonar-compose.yml up -d
```

---

## SonarQube Configuration Options

### Quality Gates
1. Go to **Quality Gates** in SonarQube
2. Click on **Sonar way** (default)
3. Review or customize conditions
4. Set as default if modified

### Quality Profiles
1. Go to **Quality Profiles**
2. Choose language (Java)
3. Review or customize rules
4. Set as default if modified

---

## Next Steps

Once SonarQube is working:
1. Add source code to your project
2. Configure quality gates
3. Set up notifications
4. Integrate with pull requests
5. Review and fix code smells

---

## References

- [SonarQube Documentation](https://docs.sonarqube.org/latest/)
- [Jenkins SonarQube Plugin](https://plugins.jenkins.io/sonar/)
- [SonarQube Maven Plugin](https://docs.sonarqube.org/latest/analyzing-source-code/scanners/sonarscanner-for-maven/)
