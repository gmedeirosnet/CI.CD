# Jenkins Guide

## Introduction
Jenkins is an open-source automation server that enables developers to build, test, and deploy their software reliably. It is the most widely used CI/CD tool in the DevOps ecosystem.

## Key Features
- Extensible with 1800+ plugins
- Distributed builds across multiple machines
- Pipeline as Code (Jenkinsfile)
- Easy installation and configuration
- Rich plugin ecosystem
- Support for various version control systems
- Integration with all major DevOps tools
- Web-based GUI
- REST API for automation

## Prerequisites
- Java Development Kit (JDK) 11 or 17
- Minimum 256MB RAM (1GB+ recommended)
- Minimum 1GB disk space (10GB+ recommended)
- Admin access to installation machine

## Installation

### On macOS
```bash
# Using Homebrew
brew install jenkins-lts

# Start Jenkins
brew services start jenkins-lts

# Access Jenkins at: http://localhost:8080
```

### On Linux (Ubuntu/Debian)
```bash
# Add Jenkins repository key
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null

# Add Jenkins repository
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

# Update and install
sudo apt-get update
sudo apt-get install jenkins

# Start Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins
```

### Using Docker
```bash
# Run Jenkins in Docker
docker run -d -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  --name jenkins \
  jenkins/jenkins:lts

# Get initial admin password
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### Initial Setup
1. Access Jenkins at http://localhost:8080
2. Enter initial admin password from: `/var/lib/jenkins/secrets/initialAdminPassword`
3. Install suggested plugins or select specific plugins
4. Create first admin user
5. Configure Jenkins URL

## Basic Concepts

### Job/Project
A runnable task in Jenkins (freestyle, pipeline, multi-branch, etc.)

### Build
An execution instance of a job

### Node/Agent
Machine where Jenkins executes builds (master or slave)

### Executor
Thread on a node that executes builds

### Workspace
Directory where build is executed

### Plugin
Extension that adds functionality to Jenkins

## Basic Usage

### Creating Freestyle Job
1. Click "New Item"
2. Enter name and select "Freestyle project"
3. Configure Source Code Management (Git, SVN, etc.)
4. Add Build Triggers
5. Add Build Steps
6. Add Post-build Actions
7. Save and Build

### Creating Pipeline Job
1. Click "New Item"
2. Enter name and select "Pipeline"
3. Choose Pipeline script or Pipeline from SCM
4. Write or reference Jenkinsfile
5. Save and Build

## Jenkinsfile (Pipeline as Code)

### Declarative Pipeline
```groovy
pipeline {
    agent any

    environment {
        DOCKER_IMAGE = 'myapp:latest'
        HARBOR_REGISTRY = 'harbor.example.com'
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/example/repo.git'
            }
        }

        stage('Build') {
            steps {
                sh 'mvn clean package'
            }
        }

        stage('Test') {
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

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t ${DOCKER_IMAGE} .'
            }
        }

        stage('Push to Harbor') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'harbor-credentials',
                    usernameVariable: 'USER',
                    passwordVariable: 'PASS'
                )]) {
                    sh '''
                        echo $PASS | docker login ${HARBOR_REGISTRY} -u $USER --password-stdin
                        docker tag ${DOCKER_IMAGE} ${HARBOR_REGISTRY}/myproject/${DOCKER_IMAGE}
                        docker push ${HARBOR_REGISTRY}/myproject/${DOCKER_IMAGE}
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                sh 'kubectl apply -f k8s/deployment.yaml'
            }
        }
    }

    post {
        success {
            echo 'Pipeline succeeded!'
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

### Scripted Pipeline
```groovy
node {
    try {
        stage('Checkout') {
            checkout scm
        }

        stage('Build') {
            sh 'mvn clean package'
        }

        stage('Test') {
            sh 'mvn test'
        }

        stage('Deploy') {
            sh 'kubectl apply -f k8s/'
        }

        currentBuild.result = 'SUCCESS'
    } catch (Exception e) {
        currentBuild.result = 'FAILURE'
        throw e
    } finally {
        cleanWs()
    }
}
```

## Advanced Pipeline Features

### Parallel Stages
```groovy
stage('Parallel Tests') {
    parallel {
        stage('Unit Tests') {
            steps {
                sh 'mvn test'
            }
        }
        stage('Integration Tests') {
            steps {
                sh 'mvn integration-test'
            }
        }
        stage('Security Scan') {
            steps {
                sh 'trivy scan'
            }
        }
    }
}
```

### Input Step (Manual Approval)
```groovy
stage('Deploy to Production') {
    steps {
        input message: 'Deploy to production?',
              ok: 'Deploy',
              submitter: 'admin,deployers'

        sh 'kubectl apply -f k8s/prod/'
    }
}
```

### When Conditions
```groovy
stage('Deploy') {
    when {
        branch 'main'
    }
    steps {
        sh 'kubectl apply -f k8s/'
    }
}

stage('Deploy to Prod') {
    when {
        expression {
            return env.BRANCH_NAME == 'main' && env.BUILD_NUMBER.toInteger() > 10
        }
    }
    steps {
        sh 'kubectl apply -f k8s/prod/'
    }
}
```

### Shared Libraries
```groovy
// In Jenkinsfile
@Library('my-shared-library') _

mySharedFunction()

// In vars/mySharedFunction.groovy
def call() {
    echo "This is a shared function"
}
```

## Plugin Integration

### Essential Plugins
- Git Plugin: Git integration
- Pipeline Plugin: Pipeline support
- Docker Pipeline Plugin: Docker integration
- Kubernetes Plugin: Kubernetes integration
- Credentials Binding Plugin: Secure credential management
- Blue Ocean: Modern UI
- SonarQube Scanner: Code quality analysis
- JUnit Plugin: Test reporting

### Installing Plugins
1. Manage Jenkins > Plugin Manager
2. Search for plugin
3. Select and click "Install without restart"
4. Restart Jenkins if needed

## Integration with Other Tools

### GitHub Integration
```groovy
pipeline {
    agent any
    triggers {
        githubPush()
    }
    stages {
        stage('Checkout') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: '*/main']],
                    userRemoteConfigs: [[
                        url: 'https://github.com/example/repo.git',
                        credentialsId: 'github-credentials'
                    ]]
                ])
            }
        }
    }
}
```

### Docker Integration
```groovy
pipeline {
    agent {
        docker {
            image 'maven:3.8-openjdk-11'
            args '-v /root/.m2:/root/.m2'
        }
    }
    stages {
        stage('Build') {
            steps {
                sh 'mvn clean package'
            }
        }
    }
}
```

### Maven Integration
```groovy
pipeline {
    agent any
    tools {
        maven 'Maven 3.8'
        jdk 'JDK11'
    }
    stages {
        stage('Build') {
            steps {
                sh 'mvn clean install'
            }
        }
    }
}
```

### SonarQube Integration
```groovy
stage('SonarQube Analysis') {
    environment {
        scannerHome = tool 'SonarQubeScanner'
    }
    steps {
        withSonarQubeEnv('SonarQube') {
            sh "${scannerHome}/bin/sonar-scanner"
        }
    }
}

stage('Quality Gate') {
    steps {
        timeout(time: 1, unit: 'HOURS') {
            waitForQualityGate abortPipeline: true
        }
    }
}
```

### Kubernetes Integration
```groovy
pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: maven
    image: maven:3.8-openjdk-11
    command: ['cat']
    tty: true
  - name: docker
    image: docker:latest
    command: ['cat']
    tty: true
    volumeMounts:
    - name: docker-sock
      mountPath: /var/run/docker.sock
  volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
"""
        }
    }
    stages {
        stage('Build') {
            steps {
                container('maven') {
                    sh 'mvn clean package'
                }
            }
        }
        stage('Docker Build') {
            steps {
                container('docker') {
                    sh 'docker build -t myapp .'
                }
            }
        }
    }
}
```

### Ansible Integration
```groovy
stage('Configure Servers') {
    steps {
        ansiblePlaybook(
            playbook: 'playbook.yml',
            inventory: 'inventory.ini',
            credentialsId: 'ansible-ssh-key'
        )
    }
}
```

## Distributed Builds

### Adding Agent Nodes
1. Manage Jenkins > Manage Nodes and Clouds
2. New Node
3. Configure node (name, executors, labels, launch method)
4. Save

### Using Specific Agents
```groovy
pipeline {
    agent {
        label 'linux && docker'
    }
    // or
    agent {
        node {
            label 'linux'
            customWorkspace '/custom/path'
        }
    }
}
```

## Best Practices
1. Use Pipeline as Code (Jenkinsfile in SCM)
2. Use declarative pipeline syntax when possible
3. Implement proper error handling
4. Use credentials securely (never hardcode)
5. Keep builds fast (use parallel stages)
6. Archive artifacts appropriately
7. Implement proper logging
8. Use shared libraries for common code
9. Regular backups of Jenkins configuration
10. Keep Jenkins and plugins updated

## Security

### Configure Security
1. Enable security in Configure Global Security
2. Use security realm (LDAP, Active Directory, or Jenkins database)
3. Configure authorization (Matrix-based, Project-based, Role-based)
4. Enable CSRF protection
5. Use SSL/TLS for Jenkins URL

### Credentials Management
```groovy
withCredentials([usernamePassword(
    credentialsId: 'my-credentials',
    usernameVariable: 'USER',
    passwordVariable: 'PASS'
)]) {
    sh 'echo $USER'
}

withCredentials([string(
    credentialsId: 'api-token',
    variable: 'API_TOKEN'
)]) {
    sh 'curl -H "Authorization: Bearer $API_TOKEN" api.example.com'
}
```

## Backup and Restore

### Backup Jenkins
```bash
# Backup Jenkins home directory
tar -czf jenkins-backup.tar.gz /var/lib/jenkins/

# Or use ThinBackup plugin for selective backups
```

### Restore Jenkins
```bash
# Stop Jenkins
sudo systemctl stop jenkins

# Restore backup
tar -xzf jenkins-backup.tar.gz -C /

# Start Jenkins
sudo systemctl start jenkins
```

## Troubleshooting

### Build fails without clear error
- Check Console Output
- Increase log verbosity
- Check node/agent availability
- Review workspace permissions

### Plugin conflicts
- Update all plugins
- Check plugin dependencies
- Review Jenkins logs
- Use Plugin Manager to identify conflicts

### Performance issues
- Increase executor count
- Add more agent nodes
- Clean old builds
- Optimize pipeline scripts
- Check disk space

### Connection issues to agents
- Verify network connectivity
- Check firewall rules
- Verify SSH keys or JNLP configuration
- Review agent logs

## Monitoring

### Metrics
- Install Monitoring Plugin
- Configure Prometheus endpoint
- Track build queue length
- Monitor executor usage

### Logs
```bash
# Jenkins logs location
tail -f /var/log/jenkins/jenkins.log

# Or in Docker
docker logs -f jenkins
```

## References
- Official Documentation: https://www.jenkins.io/doc/
- Plugin Index: https://plugins.jenkins.io/
- Pipeline Syntax: https://www.jenkins.io/doc/book/pipeline/syntax/
- Best Practices: https://www.jenkins.io/doc/book/pipeline/pipeline-best-practices/
