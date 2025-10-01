# Complete CI/CD Pipeline Lab Setup

## Overview
This guide provides step-by-step instructions to set up a complete DevOps CI/CD laboratory environment using all the focus tools: ArgoCD, AWS EKS, Ansible, Docker, GitHub, Harbor, Helm Charts, Maven, Jenkins, and SonarQube.

## Prerequisites
- macOS, Linux, or Windows with WSL2
- At least 16GB RAM and 50GB free disk space
- AWS account (for EKS)
- GitHub account
- Basic understanding of command line
- Administrator/sudo access

## Lab Architecture

```
Developer → GitHub → Jenkins → Maven Build → SonarQube Analysis
                          ↓
                     Docker Build → Harbor Registry
                          ↓
                     Helm Package → ArgoCD → AWS EKS
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
# Using Docker
docker network create cicd-network

docker run -d \
  --name jenkins \
  --network cicd-network \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts

# Get initial password
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword

# Access Jenkins at http://localhost:8080
# Complete setup wizard
# Install suggested plugins plus:
# - Docker Pipeline
# - SonarQube Scanner
# - Kubernetes CLI
# - Ansible
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

## Phase 3: AWS EKS Setup

### 3.1 Install AWS CLI and eksctl
```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /

# Configure AWS
aws configure
# Enter: Access Key ID, Secret Access Key, Region (us-west-2), Output format (json)

# Install eksctl
brew tap weaveworks/tap
brew install weaveworks/tap/eksctl

# Install kubectl
brew install kubectl
```

### 3.2 Create EKS Cluster
```bash
# Create cluster (takes 15-20 minutes)
eksctl create cluster \
  --name cicd-demo-cluster \
  --region us-west-2 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 4 \
  --managed

# Update kubeconfig
aws eks update-kubeconfig --name cicd-demo-cluster --region us-west-2

# Verify
kubectl get nodes
kubectl get pods --all-namespaces
```

## Phase 4: ArgoCD Installation

### 4.1 Install ArgoCD on EKS
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
# Add GitHub repository
argocd repo add https://github.com/yourusername/cicd-demo.git \
  --username yourusername \
  --password your-token

# Add EKS cluster (if not already default)
argocd cluster add cicd-demo-cluster
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

[eks]
eks-node-1 ansible_host=<NODE_IP>
EOF

cat > deploy.yml << 'EOF'
---
- name: Configure EKS environment
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

# Delete EKS cluster
eksctl delete cluster --name cicd-demo-cluster --region us-west-2

# Stop Docker containers
docker-compose -f sonar-compose.yml down -v
docker stop jenkins harbor

# Remove Docker volumes
docker volume prune -f
```

## Troubleshooting

### Common Issues
1. Jenkins can't connect to Docker: Ensure Docker socket is mounted
2. Harbor SSL errors: Use http for local testing
3. ArgoCD sync fails: Check GitHub credentials and repository access
4. EKS nodes not ready: Wait longer or check AWS quotas
5. SonarQube out of memory: Increase Docker memory limits

## Next Steps
1. Add monitoring with Prometheus and Grafana
2. Implement blue-green deployments
3. Add integration tests
4. Configure backup and disaster recovery
5. Implement secrets management with Vault
6. Add API gateway
7. Configure service mesh (Istio)

## References
- Complete lab documentation in docs/
- Tool-specific guides for each component
- Example code repository
- Troubleshooting guides
