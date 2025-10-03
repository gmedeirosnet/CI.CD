# SonarQube Quick Reference

## Quick Start Commands

```bash
# Make setup script executable
chmod +x scripts/setup-sonarqube.sh

# Run automated setup
./scripts/setup-sonarqube.sh
```

## Access Information

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| SonarQube UI | http://localhost:9000 | admin / admin |
| Jenkins | http://localhost:8080 | (your Jenkins creds) |

## Essential Configuration Steps

### 1. Start SonarQube
```bash
cd /Users/gutembergmedeiros/Labs/CI.CD
docker-compose -f sonar-compose.yml up -d
```

### 2. Generate SonarQube Token
1. Open http://localhost:9000
2. Login: admin / admin (change password when prompted)
3. My Account → Security → Generate Token
4. Name: `Jenkins`, Type: `Global Analysis Token`
5. **COPY THE TOKEN!**

### 3. Configure Jenkins
**Install Plugin:**
- Manage Jenkins → Plugins → Available
- Search: `SonarQube Scanner`
- Install and restart

**Add SonarQube Server:**
- Manage Jenkins → System
- SonarQube servers section:
  - Name: `SonarQube`
  - URL: `http://sonarqube:9000`
  - Add Secret token credential

**Add Scanner Tool:**
- Manage Jenkins → Tools
- SonarQube Scanner → Add
- Name: `SonarQube Scanner`
- Install automatically: ✓

### 4. Create SonarQube Project
```bash
# Via UI:
1. Click "+ Create Project"
2. Manually
3. Project key: cicd-demo
4. Display name: CI/CD Demo
5. Previous version → Create
```

## Verification Checklist

- [ ] Docker network `cicd-network` exists
- [ ] Jenkins connected to network
- [ ] SonarQube running (http://localhost:9000 accessible)
- [ ] SonarQube password changed
- [ ] Authentication token generated
- [ ] Jenkins plugin installed
- [ ] SonarQube server configured in Jenkins
- [ ] Scanner tool configured
- [ ] Project created in SonarQube
- [ ] Jenkinsfile SonarQube stages uncommented

## Troubleshooting

### SonarQube not accessible
```bash
# Check containers
docker ps | grep sonar

# Check logs
docker-compose -f sonar-compose.yml logs -f sonarqube

# Restart
docker-compose -f sonar-compose.yml restart sonarqube
```

### Jenkins can't reach SonarQube
```bash
# Verify network connection
docker network inspect cicd-network

# Should show both jenkins and sonarqube containers

# Test from Jenkins container
docker exec <jenkins-container> curl -I http://sonarqube:9000
```

### Analysis fails with "server not found"
**Solution:** Ensure Jenkins is using `http://sonarqube:9000` (container name), not `localhost`

### Quality Gate times out
**Solution:** Increase timeout in Jenkinsfile or check SonarQube processing

## Useful Commands

```bash
# Start
docker-compose -f sonar-compose.yml up -d

# Stop
docker-compose -f sonar-compose.yml stop

# Stop and remove
docker-compose -f sonar-compose.yml down

# View logs
docker-compose -f sonar-compose.yml logs -f sonarqube

# Restart
docker-compose -f sonar-compose.yml restart sonarqube

# Check status
curl -I http://localhost:9000

# Clean restart (removes all data!)
docker-compose -f sonar-compose.yml down -v
docker-compose -f sonar-compose.yml up -d
```

## Pipeline Integration

Your Jenkinsfile now includes:
- **SonarQube Analysis** - Analyzes code quality
- **Quality Gate** - Enforces quality standards

The pipeline will fail if quality gate conditions are not met.

## Next Steps

1. Run the setup script: `./scripts/setup-sonarqube.sh`
2. Follow on-screen instructions
3. Configure Jenkins as directed
4. Run a Jenkins build
5. Check results in SonarQube UI

## More Information

See detailed guide: `docs/SonarQube-Setup.md`
