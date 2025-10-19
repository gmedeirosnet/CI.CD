# Harbor Jenkins Credential Setup

## Robot Account Details
Successfully created Harbor robot account for CI/CD pipeline.

**Robot Account Name:** `robot-ci-cd-demo`
**Robot Token:** `YourRobotToken`
**Harbor Registry:** `127.0.0.1:8082`
**Harbor Project:** `cicd-demo`

---

## Jenkins Credential Configuration

### Step 1: Add Credential in Jenkins

1. Navigate to Jenkins: **Credentials → System → Global credentials (unrestricted)**
2. Click **Add Credentials**
3. Configure as follows:

   | Field | Value |
   |-------|-------|
   | **Kind** | Username with password |
   | **Scope** | Global |
   | **Username** | `robot$robot-ci-cd-demo` |
   | **Password** | `YourRobotToken` |
   | **ID** | `harbor-credentials` |
   | **Description** | Harbor robot account for CI/CD pipeline |

4. Click **Create**

### Step 2: Verify Jenkinsfile Configuration

Your `Jenkinsfile` should reference the credential ID `harbor-credentials` in the "Push to Harbor" stage:

```groovy
stage('Push to Harbor') {
    steps {
        withCredentials([usernamePassword(
            credentialsId: 'harbor-credentials',
            usernameVariable: 'USER',
            passwordVariable: 'PASS'
        )]) {
            sh """
                echo \$PASS | docker login ${HARBOR_REGISTRY} -u \$USER --password-stdin
                docker push ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}
                docker push ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:latest
            """
        }
    }
}
```

---

## Test Docker Login (Local/Jenkins Agent)

Run these commands on the machine that will execute Docker builds:

```bash
# Test login
echo "YourRobotToken" | docker login 127.0.0.1:8082 -u "robot\$robot-ci-cd-demo" --password-stdin

# Expected output: "Login Succeeded"
```

### Test Push (Optional)
```bash
# Pull a test image
docker pull busybox:latest

# Tag for Harbor
docker tag busybox:latest 127.0.0.1:8082/cicd-demo/busybox-test:ci-test

# Push to Harbor
docker push 127.0.0.1:8082/cicd-demo/busybox-test:ci-test
```

---

## Troubleshooting

### Insecure Registry Error
If you see TLS or "insecure registry" errors when running `docker login` or `docker push`:

**Solution:** Configure Docker to allow insecure registry access for Harbor.

#### macOS (Docker Desktop)
1. Open Docker Desktop → Settings → Docker Engine
2. Add to the JSON configuration:
   ```json
   {
     "insecure-registries": ["127.0.0.1:8082"]
   }
   ```
3. Click **Apply & Restart**

#### Linux
1. Edit `/etc/docker/daemon.json`:
   ```bash
   sudo nano /etc/docker/daemon.json
   ```
2. Add:
   ```json
   {
     "insecure-registries": ["127.0.0.1:8082"]
   }
   ```
3. Restart Docker:
   ```bash
   sudo systemctl restart docker
   ```

#### Jenkins Agent (Running in Container)
If Jenkins agent runs in a Docker container and needs to use the host Docker daemon:

1. The host Docker daemon must have the insecure registry configured (see above)
2. Verify the Jenkins container has access to `/var/run/docker.sock`
3. Test `docker login` from inside the Jenkins container

### 401 Unauthorized
- Verify username format is exactly: `robot$robot-ci-cd-demo` (note the `$` separator)
- Confirm token was copied correctly (no extra spaces)
- Check robot account has push/pull permissions in Harbor UI

### Connection Refused
- Verify Harbor is running: `curl http://127.0.0.1:8082/api/v2.0/systeminfo`
- If Jenkins runs in Docker/Kubernetes, ensure it can reach the Harbor host (use `host.docker.internal:8082` on Docker Desktop or appropriate service name in k8s)

---

## Security Notes

- **Token Storage:** The robot token is stored securely in Jenkins credentials and never exposed in logs
- **Scope:** This robot account has push/pull access only to the `cicd-demo` project
- **Rotation:** Robot tokens can be regenerated in Harbor UI if compromised
- **Expiration:** Currently set to never expire (expires_at: 0). Consider setting an expiration for production environments

---

## Next Steps

1. ✅ Add the credential in Jenkins (see Step 1 above)
2. ✅ Verify your Jenkinsfile uses `credentialsId: 'harbor-credentials'`
3. ✅ Configure Docker daemon for insecure registry (if needed)
4. 🔄 Run your Jenkins pipeline to test the full flow
5. 🔄 Verify images appear in Harbor UI: http://127.0.0.1:8082/harbor → Projects → cicd-demo → Repositories

## Verification Checklist

- [ ] Jenkins credential `harbor-credentials` created with robot account
- [ ] Docker daemon configured for insecure registry `127.0.0.1:8082`
- [ ] Test docker login successful from Jenkins agent
- [ ] Jenkins pipeline runs and pushes images to Harbor
- [ ] Images visible in Harbor web UI under cicd-demo project
