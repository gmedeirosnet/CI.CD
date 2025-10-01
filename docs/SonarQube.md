# SonarQube Guide

## Introduction
SonarQube is an open-source platform for continuous inspection of code quality. It performs automatic reviews with static analysis to detect bugs, code smells, and security vulnerabilities in 30+ programming languages.

## Key Features
- Static code analysis for multiple languages
- Code quality metrics and technical debt calculation
- Security vulnerability detection
- Code coverage tracking
- Code duplication detection
- Customizable quality gates
- Integration with CI/CD pipelines
- Web-based dashboard
- RESTful API
- Historical trend analysis

## Prerequisites
- Java 11 or 17 installed
- Minimum 2GB RAM (4GB+ recommended for production)
- PostgreSQL, MySQL, or Oracle database (for production)
- Modern web browser
- Admin privileges for installation

## Installation

### Using Docker (Recommended for Testing)
```bash
# Start SonarQube
docker run -d --name sonarqube \
  -p 9000:9000 \
  -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
  sonarqube:lts-community

# Access SonarQube at: http://localhost:9000
# Default credentials: admin / admin
```

### Using Docker Compose (With PostgreSQL)
```yaml
version: "3"

services:
  sonarqube:
    image: sonarqube:lts-community
    depends_on:
      - db
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://db:5432/sonar
      SONAR_JDBC_USERNAME: sonar
      SONAR_JDBC_PASSWORD: sonar
    ports:
      - "9000:9000"
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_logs:/opt/sonarqube/logs

  db:
    image: postgres:13
    environment:
      POSTGRES_USER: sonar
      POSTGRES_PASSWORD: sonar
      POSTGRES_DB: sonar
    volumes:
      - postgresql_data:/var/lib/postgresql/data

volumes:
  sonarqube_data:
  sonarqube_extensions:
  sonarqube_logs:
  postgresql_data:
```

### Linux Installation (Ubuntu/Debian)
```bash
# Update system
sudo apt update

# Install Java
sudo apt install openjdk-17-jdk

# Add SonarQube user
sudo useradd -r -s /bin/false sonarqube

# Download SonarQube
cd /opt
sudo wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.3.0.82913.zip
sudo unzip sonarqube-10.3.0.82913.zip
sudo mv sonarqube-10.3.0.82913 sonarqube
sudo chown -R sonarqube:sonarqube /opt/sonarqube

# Configure PostgreSQL
sudo -u postgres psql
CREATE USER sonar WITH PASSWORD 'sonar';
CREATE DATABASE sonar OWNER sonar;
\q

# Configure SonarQube
sudo vi /opt/sonarqube/conf/sonar.properties
# Add:
# sonar.jdbc.username=sonar
# sonar.jdbc.password=sonar
# sonar.jdbc.url=jdbc:postgresql://localhost/sonar

# Create systemd service
sudo vi /etc/systemd/system/sonarqube.service
```

```ini
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonarqube
Group=sonarqube
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
```

```bash
# Start SonarQube
sudo systemctl start sonarqube
sudo systemctl enable sonarqube
sudo systemctl status sonarqube
```

### Initial Setup
1. Access http://localhost:9000
2. Login with admin / admin
3. Change admin password
4. Configure email server (optional)
5. Install additional language plugins if needed
6. Configure quality profiles
7. Set up quality gates

## Basic Concepts

### Projects
Applications or modules to be analyzed

### Quality Profiles
Set of rules applied to code analysis

### Quality Gates
Conditions that must be met for code to pass quality check

### Issues
Problems found in code (bugs, vulnerabilities, code smells)

### Metrics
Measurements of code quality (coverage, duplication, complexity)

### Technical Debt
Estimated time to fix all code issues

## Scanner Installation

### SonarScanner CLI
```bash
# Download SonarScanner
wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006.zip
unzip sonar-scanner-cli-5.0.1.3006.zip
sudo mv sonar-scanner-5.0.1.3006 /opt/sonar-scanner

# Add to PATH
export PATH=$PATH:/opt/sonar-scanner/bin

# Configure
vi /opt/sonar-scanner/conf/sonar-scanner.properties
# Add:
# sonar.host.url=http://localhost:9000
# sonar.login=<your-token>
```

### Generate Authentication Token
1. Login to SonarQube
2. User > My Account > Security
3. Generate Tokens
4. Use token instead of password

## Code Analysis

### Using SonarScanner CLI
```bash
# Create sonar-project.properties
cat > sonar-project.properties << EOF
sonar.projectKey=my-project
sonar.projectName=My Project
sonar.projectVersion=1.0
sonar.sources=src
sonar.sourceEncoding=UTF-8
sonar.language=java
sonar.java.binaries=target/classes
EOF

# Run analysis
sonar-scanner \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.login=<your-token>
```

### Using Maven
```xml
<!-- Add to pom.xml -->
<properties>
    <sonar.host.url>http://localhost:9000</sonar.host.url>
</properties>
```

```bash
# Run analysis
mvn clean verify sonar:sonar \
  -Dsonar.login=<your-token>

# With specific profile
mvn clean verify sonar:sonar \
  -Dsonar.projectKey=my-project \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.login=<your-token>
```

### Using Gradle
```groovy
// build.gradle
plugins {
    id "org.sonarqube" version "4.4.1.3373"
}

sonarqube {
    properties {
        property "sonar.projectKey", "my-project"
        property "sonar.host.url", "http://localhost:9000"
        property "sonar.login", "<your-token>"
    }
}
```

```bash
# Run analysis
./gradlew sonarqube
```

### Using Docker
```bash
docker run --rm \
  -e SONAR_HOST_URL=http://sonarqube:9000 \
  -e SONAR_LOGIN=<your-token> \
  -v $(pwd):/usr/src \
  sonarsource/sonar-scanner-cli
```

## Quality Gates

### Default Quality Gate Conditions
- New coverage < 80%
- New duplicated lines > 3%
- Maintainability rating worse than A
- Reliability rating worse than A
- Security rating worse than A
- Security hotspots reviewed < 100%

### Creating Custom Quality Gate
1. Quality Gates > Create
2. Add conditions:
   - Coverage on New Code
   - Duplicated Lines on New Code
   - Maintainability Rating
   - Reliability Rating
   - Security Rating
3. Set as default
4. Assign to projects

### Quality Gate in Pipeline
```bash
# Check quality gate status
curl -u <token>: \
  "http://localhost:9000/api/qualitygates/project_status?projectKey=my-project"
```

## Integration with Other Tools

### Jenkins Integration

#### Install Plugin
1. Manage Jenkins > Plugin Manager
2. Search for "SonarQube Scanner"
3. Install and restart

#### Configure SonarQube Server
1. Manage Jenkins > Configure System
2. SonarQube servers
3. Add SonarQube
   - Name: SonarQube
   - Server URL: http://localhost:9000
   - Server authentication token

#### Jenkinsfile
```groovy
pipeline {
    agent any

    tools {
        maven 'Maven 3.9'
    }

    environment {
        SONAR_TOKEN = credentials('sonarqube-token')
    }

    stages {
        stage('Checkout') {
            steps {
                git 'https://github.com/example/repo.git'
            }
        }

        stage('Build') {
            steps {
                sh 'mvn clean package'
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
                timeout(time: 1, unit: 'HOURS') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Deploy') {
            steps {
                echo 'Deploying application...'
            }
        }
    }
}
```

### GitHub Actions Integration
```yaml
name: Build and Analyze

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3
      with:
        fetch-depth: 0

    - name: Set up JDK 11
      uses: actions/setup-java@v3
      with:
        java-version: 11
        distribution: 'temurin'

    - name: Cache SonarQube packages
      uses: actions/cache@v3
      with:
        path: ~/.sonar/cache
        key: ${{ runner.os }}-sonar

    - name: Cache Maven packages
      uses: actions/cache@v3
      with:
        path: ~/.m2
        key: ${{ runner.os }}-m2-${{ hashFiles('**/pom.xml') }}

    - name: Build and analyze
      env:
        SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
        SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}
      run: mvn -B verify org.sonarsource.scanner.maven:sonar-maven-plugin:sonar
```

### Docker Integration
```dockerfile
# Dockerfile
FROM maven:3.9-openjdk-11 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src

# Run tests and SonarQube analysis
ARG SONAR_TOKEN
ARG SONAR_HOST_URL
RUN mvn clean verify sonar:sonar \
    -Dsonar.host.url=${SONAR_HOST_URL} \
    -Dsonar.login=${SONAR_TOKEN}

# Package application
RUN mvn package -DskipTests

FROM openjdk:11-jre-slim
COPY --from=build /app/target/myapp.jar .
CMD ["java", "-jar", "myapp.jar"]
```

### Kubernetes Integration
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: sonarqube-scan
spec:
  template:
    spec:
      containers:
      - name: scanner
        image: sonarsource/sonar-scanner-cli:latest
        env:
        - name: SONAR_HOST_URL
          value: "http://sonarqube:9000"
        - name: SONAR_LOGIN
          valueFrom:
            secretKeyRef:
              name: sonar-token
              key: token
        volumeMounts:
        - name: source
          mountPath: /usr/src
      volumes:
      - name: source
        persistentVolumeClaim:
          claimName: source-code-pvc
      restartPolicy: Never
```

## Advanced Features

### Branch Analysis
```bash
# Analyze specific branch
mvn sonar:sonar \
  -Dsonar.branch.name=feature/my-feature

# Analyze pull request
mvn sonar:sonar \
  -Dsonar.pullrequest.key=123 \
  -Dsonar.pullrequest.branch=feature/my-feature \
  -Dsonar.pullrequest.base=main
```

### Security Hotspots
- Review security-sensitive code
- Mark as safe or fix vulnerability
- Track remediation progress

### Custom Rules
1. Administration > Rules
2. Create custom rule or extend existing
3. Add to quality profile
4. Apply to projects

## Best Practices
1. Integrate SonarQube early in development
2. Use quality gates to enforce standards
3. Review new code issues regularly
4. Fix security vulnerabilities immediately
5. Maintain high code coverage (80%+)
6. Address technical debt incrementally
7. Customize quality profiles per project type
8. Use branch analysis for feature branches
9. Automate analysis in CI/CD pipeline
10. Monitor trends over time

## Troubleshooting

### Analysis fails with memory error
```bash
# Increase heap size
export SONAR_SCANNER_OPTS="-Xmx2g"

# Or in sonar-scanner.properties
sonar.scanner.javaOpts=-Xmx2g
```

### Authentication issues
- Verify token is valid
- Check token permissions
- Regenerate token if expired

### Quality gate timeout
- Increase timeout in Jenkins pipeline
- Check SonarQube server performance
- Review webhook configuration

### Missing code coverage
```xml
<!-- Add JaCoCo plugin to pom.xml -->
<plugin>
    <groupId>org.jacoco</groupId>
    <artifactId>jacoco-maven-plugin</artifactId>
    <version>0.8.10</version>
    <executions>
        <execution>
            <goals>
                <goal>prepare-agent</goal>
            </goals>
        </execution>
        <execution>
            <id>report</id>
            <phase>test</phase>
            <goals>
                <goal>report</goal>
            </goals>
        </execution>
    </executions>
</plugin>
```

## Maintenance

### Backup
```bash
# Backup database
pg_dump -U sonar sonar > sonarqube_backup.sql

# Backup configuration and plugins
tar -czf sonarqube-data.tar.gz /opt/sonarqube/data /opt/sonarqube/extensions
```

### Upgrade
```bash
# Stop SonarQube
sudo systemctl stop sonarqube

# Backup
pg_dump -U sonar sonar > backup.sql

# Download new version
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-X.X.X.zip

# Extract and replace
sudo unzip sonarqube-X.X.X.zip -d /opt/
sudo mv /opt/sonarqube-X.X.X /opt/sonarqube-new

# Copy configuration
sudo cp /opt/sonarqube/conf/sonar.properties /opt/sonarqube-new/conf/

# Start and check logs
sudo systemctl start sonarqube
sudo tail -f /opt/sonarqube/logs/sonar.log
```

## References
- Official Documentation: https://docs.sonarqube.org/
- Rules Reference: https://rules.sonarsource.com/
- Community Forum: https://community.sonarsource.com/
- GitHub: https://github.com/SonarSource/sonarqube
