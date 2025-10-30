# Harbor Guide

## Introduction
Harbor is an open-source container image registry that secures images with role-based access control, scans images for vulnerabilities, and signs images as trusted. It extends the open-source Docker Distribution and adds features needed for enterprise use.

## Key Features
- Role-based access control (RBAC)
- Vulnerability scanning
- Image signing and verification
- Image replication between registries
- Image deletion and garbage collection
- Audit logging
- RESTful API
- Graphical user portal
- LDAP/AD integration
- Multi-tenancy support

## Prerequisites
- Docker Engine 17.06.0-ce+ or higher
- Docker Compose 1.18.0 or higher
- OpenSSL for generating certificates
- At least 2 CPU cores and 4GB RAM
- Ports 80 and 443 available

## Installation

### Using Docker Compose (Recommended)
```bash
# Download Harbor installer
wget https://github.com/goharbor/harbor/releases/download/v2.9.0/harbor-offline-installer-v2.9.0.tgz

# Extract the package
tar xzvf harbor-offline-installer-v2.9.0.tgz

# Navigate to Harbor directory
cd harbor

# Copy and edit configuration
cp harbor.yml.tmpl harbor.yml
vi harbor.yml
```

### Configure harbor.yml
```yaml
hostname: harbor.example.com

http:
  port: 80

https:
  port: 443
  certificate: /path/to/cert.crt
  private_key: /path/to/cert.key

harbor_admin_password: Harbor12345

database:
  password: root123
  max_idle_conns: 100
  max_open_conns: 900

data_volume: /data

trivy:
  ignore_unfixed: false
  skip_update: false
  insecure: false

jobservice:
  max_job_workers: 10

notification:
  webhook_job_max_retry: 10

log:
  level: info
  local:
    rotate_count: 50
    rotate_size: 200M
    location: /var/log/harbor
```

### Install Harbor
```bash
# Install Harbor
sudo ./install.sh

# With Trivy scanner (recommended)
sudo ./install.sh --with-trivy

# With Notary for image signing
sudo ./install.sh --with-notary

# With Chart Museum for Helm charts
sudo ./install.sh --with-chartmuseum
```

### Verify Installation
```bash
# Check if containers are running
docker-compose ps

# Access web interface
# https://harbor.example.com
# Default credentials: admin / Harbor12345
```

## Basic Usage

### Creating the cicd-demo Project

#### Method 1: Using Web Interface
1. Access Harbor UI: http://127.0.0.1:8082
2. Login with admin credentials (default: `admin` / `Harbor12345`)
3. Click **Projects** in the left navigation
4. Click **NEW PROJECT** button
5. Configure the project:
   - **Project Name**: `cicd-demo`
   - **Access Level**: Private (recommended) or Public
   - **Storage Quota**: -1 (unlimited) or set a specific limit
6. Click **OK** to create the project

#### Method 2: Using Harbor API
```bash
# Create project via API
curl -X POST "http://127.0.0.1:8082/api/v2.0/projects" \
  -H "Content-Type: application/json" \
  -u "admin:Harbor12345" \
  -d '{
    "project_name": "cicd-demo",
    "public": false,
    "metadata": {
      "auto_scan": "true",
      "enable_content_trust": "false",
      "prevent_vul": "false",
      "severity": "low"
    }
  }'

# Verify project creation
curl -X GET "http://127.0.0.1:8082/api/v2.0/projects?name=cicd-demo" \
  -u "admin:Harbor12345" | jq .
```

### Creating Robot Account for CI/CD

After creating the `cicd-demo` project, create a robot account for Jenkins to authenticate:

#### Using the Automation Script
```bash
# Run the robot account creation script
cd scripts
./create-harbor-robot.sh
```

The script will:
1. Query Harbor API for the `cicd-demo` project
2. Create a robot account named `robot-ci-cd-demo` with push/pull permissions
3. Display the robot token (shown only once - save it immediately)
4. Provide Jenkins credential configuration instructions

#### Manual Robot Account Creation via UI
1. In Harbor UI, navigate to **Projects** > **cicd-demo**
2. Click **Robot Accounts** tab
3. Click **NEW ROBOT ACCOUNT**
4. Configure:
   - **Name**: `robot-ci-cd-demo`
   - **Expiration time**: Never expires (or set custom)
   - **Description**: "Robot account for Jenkins CI"
   - **Permissions**:
     - Push Artifact
     - Pull Artifact
5. Click **ADD** and **copy the token immediately** (it won't be shown again)

#### Using Robot Account in Jenkins
1. In Jenkins, go to **Manage Jenkins** > **Credentials**
2. Add credentials:
   - **Kind**: Username with password
   - **Username**: `robot$robot-ci-cd-demo` (note the `robot$` prefix)
   - **Password**: The token you copied
   - **ID**: `harbor-robot-credentials`
   - **Description**: "Harbor Robot Account for cicd-demo"

#### Testing Robot Account
```bash
# Test docker login with robot account
echo "<ROBOT_TOKEN>" | docker login 127.0.0.1:8082 \
  -u "robot\$robot-ci-cd-demo" --password-stdin

# Test push
docker pull busybox:latest
docker tag busybox:latest 127.0.0.1:8082/cicd-demo/busybox-test:ci-test
docker push 127.0.0.1:8082/cicd-demo/busybox-test:ci-test

# Verify in Harbor UI
# Navigate to Projects > cicd-demo > Repositories
```

**Important Notes:**
- Robot tokens are shown only once during creation - save them securely
- The robot username format is `robot$<robot-name>` (with `$` separator)
- If using localhost, ensure Docker daemon allows insecure registries for `127.0.0.1:8082`
- The `create-harbor-robot.sh` script requires `curl` and `jq` (or `python3` as fallback)

### Using Web Interface
1. Access Harbor UI: https://harbor.example.com
2. Login with admin credentials
3. Browse projects and repositories
4. Add members to project
5. Push/pull images through UI or CLI

### Docker CLI Commands
```bash
# Login to Harbor
docker login harbor.example.com

# Tag image for Harbor
docker tag myimage:1.0 harbor.example.com/myproject/myimage:1.0

# Push image to Harbor
docker push harbor.example.com/myproject/myimage:1.0

# Pull image from Harbor
docker pull harbor.example.com/myproject/myimage:1.0
```

### Project Management
```bash
# Projects are created through Web UI or API
# Projects can be public or private
# Public projects: anyone can pull images
# Private projects: only members can access
```

## Advanced Features

### Vulnerability Scanning
```bash
# Scanning can be triggered:
# 1. Manually through UI
# 2. Automatically on push
# 3. Scheduled scanning

# Configure in project settings:
# - Enable automatic scan on push
# - Set scan schedule
# - Configure scan policy
```

### Image Replication
```yaml
# Configure replication rules:
# - Source registry
# - Destination registry
# - Filter rules
# - Trigger mode (manual, scheduled, event-based)

# Push-based replication (default)
# Pull-based replication (for air-gapped environments)
```

### Webhook Notifications
```json
{
  "name": "mywebhook",
  "description": "Notify on image push",
  "enabled": true,
  "event_types": [
    "pushImage",
    "pullImage",
    "deleteImage",
    "scanningCompleted"
  ],
  "targets": [
    {
      "type": "http",
      "address": "https://myserver.com/webhook",
      "skip_cert_verify": false
    }
  ]
}
```

### RBAC Configuration
```bash
# Project roles:
# - Project Admin: full control
# - Maintainer: push/pull, scan images
# - Developer: push/pull images
# - Guest: pull images only
# - Limited Guest: pull images with conditions

# System roles:
# - Harbor System Admin
# - Anonymous (public projects only)
```

## Integration with Other Tools

### Kubernetes Integration
```yaml
# Create secret for Harbor credentials
kubectl create secret docker-registry harbor-secret \
  --docker-server=harbor.example.com \
  --docker-username=admin \
  --docker-password=Harbor12345 \
  --docker-email=admin@example.com

# Use in pod specification
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  containers:
  - name: myapp
    image: harbor.example.com/myproject/myapp:1.0
  imagePullSecrets:
  - name: harbor-secret
```

### Jenkins Integration
```groovy
// Jenkinsfile
pipeline {
    agent any
    environment {
        HARBOR_REGISTRY = 'harbor.example.com'
        HARBOR_CREDENTIAL = credentials('harbor-credentials')
    }
    stages {
        stage('Build') {
            steps {
                sh 'docker build -t myapp:${BUILD_NUMBER} .'
            }
        }
        stage('Push to Harbor') {
            steps {
                sh '''
                    echo $HARBOR_CREDENTIAL_PSW | docker login $HARBOR_REGISTRY -u $HARBOR_CREDENTIAL_USR --password-stdin
                    docker tag myapp:${BUILD_NUMBER} $HARBOR_REGISTRY/myproject/myapp:${BUILD_NUMBER}
                    docker push $HARBOR_REGISTRY/myproject/myapp:${BUILD_NUMBER}
                '''
            }
        }
    }
}
```

### ArgoCD Integration
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: harbor-repo-secret
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: helm
  url: https://harbor.example.com/chartrepo/myproject
  username: admin
  password: Harbor12345
```

### Helm Integration
```bash
# Add Harbor as Helm repository
helm repo add myrepo https://harbor.example.com/chartrepo/myproject \
  --username admin \
  --password Harbor12345

# Update repository
helm repo update

# Install chart from Harbor
helm install myapp myrepo/mychart
```

## Harbor API Usage

### Authentication
```bash
# Get basic auth token
curl -u "admin:Harbor12345" https://harbor.example.com/api/v2.0/projects

# Use bearer token
TOKEN=$(curl -k -u "admin:Harbor12345" "https://harbor.example.com/service/token?service=harbor-registry&scope=repository:library/hello-world:pull" | jq -r '.token')
```

### Common API Operations
```bash
# List projects
curl -X GET "https://harbor.example.com/api/v2.0/projects" \
  -H "authorization: Basic $(echo -n 'admin:Harbor12345' | base64)"

# Create project
curl -X POST "https://harbor.example.com/api/v2.0/projects" \
  -H "Content-Type: application/json" \
  -u "admin:Harbor12345" \
  -d '{
    "project_name": "myproject",
    "public": false
  }'

# List repositories
curl -X GET "https://harbor.example.com/api/v2.0/projects/myproject/repositories" \
  -u "admin:Harbor12345"

# Get repository tags
curl -X GET "https://harbor.example.com/api/v2.0/projects/myproject/repositories/myrepo/artifacts" \
  -u "admin:Harbor12345"

# Delete tag
curl -X DELETE "https://harbor.example.com/api/v2.0/projects/myproject/repositories/myrepo/artifacts/1.0" \
  -u "admin:Harbor12345"
```

## Best Practices
1. Enable HTTPS with valid certificates
2. Change default admin password immediately
3. Enable vulnerability scanning on push
4. Implement image retention policies
5. Use project-level RBAC
6. Enable audit logging
7. Regular backup of Harbor data
8. Monitor Harbor performance and logs
9. Use image signing for critical images
10. Implement replication for disaster recovery

## Security Considerations
- Always use HTTPS in production
- Enable vulnerability scanning
- Implement image signing with Notary
- Use strong passwords and rotate regularly
- Integrate with corporate LDAP/AD
- Enable audit logging
- Implement network security (firewall rules)
- Regular security updates
- Use read-only root filesystem
- Enable CVE allowlist for exceptions

## Maintenance Tasks

### Backup and Restore
```bash
# Backup Harbor data
cd harbor
docker-compose stop
tar -czvf harbor-backup.tar.gz /data

# Restore Harbor data
cd harbor
docker-compose down
tar -xzvf harbor-backup.tar.gz -C /
docker-compose up -d
```

### Garbage Collection
```bash
# Run garbage collection manually
docker exec -it harbor-jobservice /harbor/harbor_jobservice -c /etc/jobservice/config.yml

# Or configure in UI:
# Administration > Clean Up > Garbage Collection
```

### Upgrade Harbor
```bash
# Stop Harbor
cd harbor
docker-compose down

# Backup data
tar -czvf harbor-backup.tar.gz /data

# Download new version
wget https://github.com/goharbor/harbor/releases/download/v2.9.0/harbor-offline-installer-v2.9.0.tgz

# Run migration
docker run -it --rm -v /data/database:/var/lib/postgresql/data \
  goharbor/harbor-migrator:v2.9.0 up head

# Install new version
./install.sh
```

## Troubleshooting

### Cannot login to Harbor
- Check Docker daemon configuration for insecure registries
- Verify certificates are valid
- Check network connectivity
- Review Harbor logs: `docker-compose logs -f`

### Image push fails
- Verify user has push permissions
- Check disk space on Harbor server
- Review project quotas
- Check Docker daemon logs

### Scanning not working
- Ensure Trivy scanner is installed
- Check internet connectivity for CVE database updates
- Review jobservice logs
- Verify scanner configuration

### Replication issues
- Verify destination registry credentials
- Check network connectivity between registries
- Review replication rule configuration
- Check replication job logs

## Monitoring

### Check Harbor Status
```bash
# Check all containers
docker-compose ps

# View logs
docker-compose logs -f

# Check specific service
docker-compose logs -f core
```

### Metrics
Harbor exposes Prometheus metrics at:
```
https://harbor.example.com/metrics
```

### Health Check
```bash
curl -k https://harbor.example.com/api/v2.0/health
```

## References
- Official Documentation: https://goharbor.io/docs/
- GitHub Repository: https://github.com/goharbor/harbor
- API Documentation: https://goharbor.io/docs/latest/build-customize-contribute/configure-swagger/
- Harbor Community: https://github.com/goharbor/community
