# Complete CI/CD Pipeline Lab Setup

## Overview
This guide provides step-by-step instructions to set up a complete DevOps CI/CD laboratory environment using all the focus tools: ArgoCD, Kind (K8s in Docker), Ansible, Docker, GitHub, Harbor, Helm Charts, Maven, Jenkins, and SonarQube.

## Prerequisites
- macOS (M1 recommended), Linux, or Windows with WSL2
- At least 16GB RAM and 50GB free disk space
- Docker Desktop installed (required for Kind)
- GitHub account
- Basic understanding of command line
- Administrator/sudo access

## Lab Architecture

```
Developer → GitHub → Jenkins → Maven Build → SonarQube Analysis
                          ↓
                     Docker Build → Harbor Registry
                          ↓
                     Helm Package → ArgoCD → Kind K8s Cluster
                          ↓
                     Ansible (Configuration Management)
```

## Phase 1: Foundation Setup

### 1.1 Install Docker
```bash
# macOS
brew install --cask docker

# Linux
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Verify
docker --version
docker-compose --version
```

### 1.2 Set Up GitHub Repository
```bash
# Create new repository on GitHub
# Clone repository
git clone https://github.com/yourusername/cicd-demo.git
cd cicd-demo

# Create basic structure
mkdir -p src/main/java/com/example
mkdir -p src/test/java/com/example
mkdir -p k8s
mkdir -p helm-charts
mkdir -p ansible

# Initialize Git
git add .
git commit -m "Initial project structure"
git push origin main
```

### 1.3 Create Sample Java Application
```bash
# Create pom.xml
cat > pom.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.example</groupId>
    <artifactId>cicd-demo</artifactId>
    <version>1.0.0-SNAPSHOT</version>
    <packaging>jar</packaging>

    <properties>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
            <version>2.7.14</version>
        </dependency>
        <dependency>
            <groupId>junit</groupId>
            <artifactId>junit</artifactId>
            <version>4.13.2</version>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <version>2.7.14</version>
            </plugin>
        </plugins>
    </build>
</project>
EOF

# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM maven:3.9-openjdk-11 AS builder
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

FROM openjdk:11-jre-slim
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
EXPOSE 8080
CMD ["java", "-jar", "app.jar"]
EOF
```

## Phase 2: CI/CD Tools Installation

### 2.1 Install Jenkins
```bash
# Create Docker network for CI/CD tools
docker network create cicd-network

# Run Jenkins with Docker access (IMPORTANT for building images)
docker run -d \
  --name jenkins \
  --restart unless-stopped \
  --network cicd-network \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts

# Wait for Jenkins to start (30-60 seconds)
echo "Waiting for Jenkins to start..."
sleep 30

# Install Docker CLI in Jenkins container
echo "Installing Docker CLI in Jenkins..."

# Detect architecture and Debian version
ARCH=$(docker exec jenkins dpkg --print-architecture)
DEBIAN_VERSION=$(docker exec jenkins cat /etc/os-release | grep VERSION_CODENAME | cut -d= -f2)

# Install Docker CLI
docker exec -u root jenkins bash -c "
  apt-get update
  apt-get install -y apt-transport-https ca-certificates curl gnupg
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo \"deb [arch=$ARCH signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $DEBIAN_VERSION stable\" > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce-cli docker-buildx-plugin docker-compose-plugin
  apt-get clean
"

# Fix Docker socket permissions
docker exec -u root jenkins chmod 666 /var/run/docker.sock

# Verify Docker is working
docker exec jenkins docker --version
docker exec jenkins docker ps

# Get initial admin password
echo "Jenkins Initial Admin Password:"
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword

# Access Jenkins at http://localhost:8080
# Complete setup wizard
# Install suggested plugins plus:
# - Docker Pipeline
# - SonarQube Scanner
# - Kubernetes CLI
# - Ansible
```

**Important Notes:**
- Docker socket mounting gives Jenkins access to build Docker images
- The script automatically detects ARM64 (Apple Silicon) or AMD64 architecture
- Docker CLI must be installed inside the Jenkins container
- Permissions on Docker socket may need adjustment (chmod 666)

**Alternative: Use Automated Setup Script**
```bash
# Use the provided setup script for easier installation
chmod +x scripts/setup-jenkins-docker.sh
./scripts/setup-jenkins-docker.sh
```

### 2.2 Install SonarQube
```bash
# Create docker-compose.yml for SonarQube
cat > sonar-compose.yml << 'EOF'
version: "3"

services:
  sonarqube:
    image: sonarqube:lts-community
    container_name: sonarqube
    networks:
      - cicd-network
    depends_on:
      - sonar-db
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://sonar-db:5432/sonar
      SONAR_JDBC_USERNAME: sonar
      SONAR_JDBC_PASSWORD: sonar
    ports:
      - "9000:9000"
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_logs:/opt/sonarqube/logs

  sonar-db:
    image: postgres:13
    container_name: sonar-db
    networks:
      - cicd-network
    environment:
      POSTGRES_USER: sonar
      POSTGRES_PASSWORD: sonar
      POSTGRES_DB: sonar
    volumes:
      - postgresql_data:/var/lib/postgresql/data

networks:
  cicd-network:
    external: true

volumes:
  sonarqube_data:
  sonarqube_extensions:
  sonarqube_logs:
  postgresql_data:
EOF

docker-compose -f sonar-compose.yml up -d

# Access SonarQube at http://localhost:9000
# Login: admin / admin (change password)
# Generate token: User > My Account > Security > Generate Token
```

### 2.3 Install Harbor
```bash
# Download Harbor
wget https://github.com/goharbor/harbor/releases/download/v2.9.0/harbor-offline-installer-v2.9.0.tgz
tar xzvf harbor-offline-installer-v2.9.0.tgz
cd harbor

# Configure Harbor
cp harbor.yml.tmpl harbor.yml
vi harbor.yml
# Set:
# hostname: localhost
# http.port: 8082
# harbor_admin_password: Harbor12345

# Install Harbor
sudo ./install.sh --with-trivy

# Access Harbor at http://localhost:8082
# Login: admin / Harbor12345
# Create project: cicd-demo
```

## Phase 3: Kind (Kubernetes in Docker) Setup

### 3.1 Install Kind and kubectl
```bash
# Install Kind via Homebrew (recommended for macOS M4)
brew install kind

# Verify Kind installation
kind version

# Install kubectl
brew install kubectl

# Verify kubectl installation
kubectl version --client
```

### 3.2 Create Kind Cluster
```bash
# Create a configuration file for multi-node cluster
cat > kind-config.yaml << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: cicd-demo-cluster
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30000
    hostPort: 30000
    protocol: TCP
  - containerPort: 30001
    hostPort: 30001
    protocol: TCP
  - containerPort: 30002
    hostPort: 30002
    protocol: TCP
- role: worker
- role: worker
EOF

# Create cluster (takes 1-2 minutes)
kind create cluster --config kind-config.yaml

# Verify cluster
kubectl cluster-info --context kind-cicd-demo-cluster
kubectl get nodes
kubectl get pods --all-namespaces

# Install NGINX Ingress Controller for Kind
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

## Phase 4: ArgoCD Installation

### 4.1 Install ArgoCD on Kind Cluster
```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Get initial password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8090:443

# Access at https://localhost:8090
# Login: admin / [password from above]

# Or install CLI
brew install argocd
argocd login localhost:8090
```

### 4.2 Configure ArgoCD
```bash
# Running the following command to allow ArgoCD to access the local Kind cluster
1. chmod 0755 scripts/setup-argocd-repo.sh
2. ./scripts/setup-argocd-repo.sh
```

## Phase 5: Helm Charts Creation

### 5.1 Create Helm Chart
```bash
cd helm-charts
helm create cicd-demo

# Edit values.yaml
cat > cicd-demo/values.yaml << 'EOF'
replicaCount: 2

image:
  repository: localhost:8082/cicd-demo/app
  pullPolicy: Always
  tag: "latest"

service:
  type: LoadBalancer
  port: 80
  targetPort: 8080

ingress:
  enabled: false

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
EOF

# Package chart
helm package cicd-demo
```

## Phase 6: Ansible Configuration

### 6.1 Install Ansible
```bash
brew install ansible

# Verify
ansible --version
```

### 6.2 Create Ansible Playbook
```bash
cd ansible

cat > inventory.ini << 'EOF'
[local]
localhost ansible_connection=local

[kind-nodes]
kind-worker-1 ansible_host=<NODE_IP>
EOF

cat > deploy.yml << 'EOF'
---
- name: Configure Kind K8s environment
  hosts: local
  tasks:
    - name: Ensure kubectl is installed
      command: kubectl version --client
      register: kubectl_version

    - name: Display kubectl version
      debug:
        var: kubectl_version.stdout

    - name: Apply Kubernetes manifests
      command: kubectl apply -f ../k8s/

- name: Verify deployment
  hosts: local
  tasks:
    - name: Check pod status
      command: kubectl get pods
      register: pod_status

    - name: Display pod status
      debug:
        var: pod_status.stdout
EOF
```

## Phase 7: Complete Jenkins Pipeline

### 7.1 Configure Jenkins Credentials
1. Manage Jenkins > Credentials
2. Add credentials:
   - GitHub: username + token
   - Harbor: username + password
   - SonarQube: secret text (token)
   - AWS: AWS access key + secret
   - Kubeconfig: secret file

### 7.2 Create Jenkinsfile
```groovy
pipeline {
    agent any

    environment {
        // Harbor
        HARBOR_REGISTRY = 'localhost:8082'
        HARBOR_PROJECT = 'cicd-demo'
        IMAGE_NAME = 'app'
        IMAGE_TAG = "${BUILD_NUMBER}"

        // SonarQube
        SONAR_HOST = 'http://sonarqube:9000'

        // Kubernetes
        KUBECONFIG = credentials('kubeconfig')
        NAMESPACE = 'default'
    }

    tools {
        maven 'Maven 3.9'
        jdk 'JDK11'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "Building version ${IMAGE_TAG}"
            }
        }

        stage('Maven Build') {
            steps {
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('Unit Tests') {
            steps {
                sh 'mvn test'
            }
            post {
                always {
                    junit '**/target/surefire-reports/*.xml'
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh 'mvn sonar:sonar'
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

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

        stage('Update Helm Chart') {
            steps {
                sh """
                    cd helm-charts/cicd-demo
                    sed -i '' 's/tag: .*/tag: "${IMAGE_TAG}"/' values.yaml
                    git add values.yaml
                    git commit -m "Update image tag to ${IMAGE_TAG}" || true
                    git push origin main || true
                """
            }
        }

        stage('Deploy with ArgoCD') {
            steps {
                sh """
                    argocd app create cicd-demo \
                        --repo https://github.com/yourusername/cicd-demo.git \
                        --path helm-charts/cicd-demo \
                        --dest-server https://kubernetes.default.svc \
                        --dest-namespace ${NAMESPACE} \
                        --sync-policy automated \
                        --auto-prune \
                        --self-heal \
                        || true

                    argocd app sync cicd-demo
                    argocd app wait cicd-demo --timeout 300
                """
            }
        }

        stage('Ansible Post-Deploy') {
            steps {
                sh """
                    cd ansible
                    ansible-playbook -i inventory.ini deploy.yml
                """
            }
        }

        stage('Verify Deployment') {
            steps {
                sh """
                    kubectl get pods -n ${NAMESPACE}
                    kubectl get svc -n ${NAMESPACE}
                """
            }
        }
    }

    post {
        success {
            echo 'Pipeline succeeded!'
            echo "Application deployed with image tag: ${IMAGE_TAG}"
        }
        failure {
            echo 'Pipeline failed!'
        }
        always {
            cleanWs()
        }
    }
}
```

## Phase 8: Testing the Pipeline

### 8.1 Create Jenkins Job
1. New Item > Pipeline
2. Name: cicd-demo
3. Pipeline > Definition: Pipeline script from SCM
4. SCM: Git
5. Repository URL: https://github.com/yourusername/cicd-demo.git
6. Script Path: Jenkinsfile
7. Save

### 8.2 Trigger Build
```bash
# Make a code change
echo "// Test change" >> src/main/java/com/example/Application.java
git add .
git commit -m "Test pipeline"
git push origin main

# Or manually trigger in Jenkins UI
```

### 8.3 Monitor Deployment
```bash
# Watch Jenkins build
# Check SonarQube analysis at http://localhost:9000
# Check Harbor for new image at http://localhost:8082
# Check ArgoCD sync status at https://localhost:8090
# Check Kubernetes pods
kubectl get pods -w

# Get service URL
kubectl get svc
```

## Phase 9: Monitoring and Validation

### 9.1 Verify Each Component
```bash
# Jenkins
curl http://localhost:8080

# SonarQube
curl http://localhost:9000/api/system/status

# Harbor
curl http://localhost:8082/api/v2.0/health

# ArgoCD
kubectl get pods -n argocd

# Application
kubectl get pods
kubectl get svc
kubectl logs <pod-name>
```

### 9.2 Access Application
```bash
# Get LoadBalancer URL
kubectl get svc -o wide

# Test application
curl http://<EXTERNAL-IP>:80
```

## Phase 10: Cleanup

### 10.1 Remove Resources
```bash
# Delete ArgoCD application
argocd app delete cicd-demo

# Delete Kind cluster
kind delete cluster --name cicd-demo-cluster

# Stop Docker containers
docker-compose -f sonar-compose.yml down -v
docker stop jenkins harbor


# Remove Docker volumes
docker volume prune -f
```

## Troubleshooting

### Common Issues

#### 1. Jenkins can't connect to Docker
**Error:** `docker: not found` or `Cannot connect to the Docker daemon`

**Solution:**
```bash
# Install Docker CLI in Jenkins container
docker exec -u root jenkins bash -c "
  apt-get update && \
  apt-get install -y docker.io
"

# Fix Docker socket permissions
docker exec -u root jenkins chmod 666 /var/run/docker.sock

# Verify
docker exec jenkins docker --version
docker exec jenkins docker ps
```

**For ARM64 (Apple Silicon M1/M2/M3/M4):**
```bash
# Use correct architecture in Docker repository
ARCH=$(docker exec jenkins dpkg --print-architecture)
DEBIAN_VERSION=$(docker exec jenkins cat /etc/os-release | grep VERSION_CODENAME | cut -d= -f2)

docker exec -u root jenkins bash -c "
  apt-get update
  apt-get install -y apt-transport-https ca-certificates curl gnupg
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo 'deb [arch=$ARCH signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $DEBIAN_VERSION stable' > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce-cli
"
```

#### 2. Harbor SSL errors
**Solution:** Use http for local testing

#### 3. ArgoCD sync fails
**Solution:** Check GitHub credentials and repository access

#### 4. Kind cluster fails to start
**Solution:** Restart Docker Desktop and try again

#### 5. SonarQube out of memory
**Solution:** Increase Docker Desktop memory limits to 8GB+

#### 6. Pods not starting in Kind
**Solution:** Check `kubectl describe pod <name>` and verify images are loaded

#### 7. Port conflicts
**Solution:** Check if ports 30000-30002, 8080, 8090 are already in use

#### 8. Initial admin password not found
**Error:** `cat: /var/jenkins_home/secrets/initialAdminPassword: No such file or directory`

**This is NORMAL if:**
- Jenkins was already set up previously
- The password file is deleted after first-time setup (security feature)
- You should use your existing admin credentials

**If this is a new installation:**
```bash
# Wait for Jenkins to fully initialize
sleep 30
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword

# If still not found, check Jenkins logs
docker logs jenkins --tail 50
```

#### 9. Docker socket permissions reset after reboot
**Solution:**
```bash
# Re-apply permissions
docker exec -u root jenkins chmod 666 /var/run/docker.sock

# Or restart Jenkins container
docker restart jenkins
docker exec -u root jenkins chmod 666 /var/run/docker.sock
```

### Detailed Documentation

For comprehensive troubleshooting and setup guides, see:
- **Jenkins Docker Integration:** `docs/Jenkins-Docker-Integration.md`
- **Quick Fix Guide:** `docs/Jenkins-Docker-QuickFix.md`
- **Resolution Report:** `docs/Jenkins-Docker-Resolution-Report.md`
- **Harbor Integration:** `docs/Harbor-Jenkins-Integration.md`

### Kind-Specific Issues
```bash
# View Kind cluster logs
kind export logs --name cicd-demo-cluster

# Reload Docker images into Kind
kind load docker-image <image:tag> --name cicd-demo-cluster

# Access Kind node directly
docker exec -it cicd-demo-cluster-control-plane bash
```

## Next Steps
1. Add monitoring with Prometheus and Grafana on Kind
2. Implement blue-green deployments in local cluster
3. Add integration tests
4. Configure backup strategies for local development
5. Implement secrets management with sealed-secrets
6. Add API gateway (Kong or Ambassador)
7. Experiment with service mesh (Istio/Linkerd) on Kind

## References
- Complete lab documentation in docs/
- Tool-specific guides for each component
- Kind documentation: https://kind.sigs.k8s.io/
- Troubleshooting guides

