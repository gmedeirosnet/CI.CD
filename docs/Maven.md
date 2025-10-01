# Maven Guide

## Introduction
Apache Maven is a build automation and project management tool primarily used for Java projects. It uses a Project Object Model (POM) to manage project builds, dependencies, and documentation.

## Key Features
- Dependency management
- Standardized project structure
- Build lifecycle management
- Plugin-based architecture
- Multi-module project support
- Central repository (Maven Central)
- Transitive dependency resolution
- Project inheritance and aggregation

## Prerequisites
- Java Development Kit (JDK) 8 or higher
- Basic understanding of Java development
- Familiarity with XML syntax

## Installation

### On macOS
```bash
# Using Homebrew
brew install maven

# Verify installation
mvn --version
```

### On Linux (Ubuntu/Debian)
```bash
# Install Maven
sudo apt update
sudo apt install maven

# Verify installation
mvn --version
```

### Manual Installation
```bash
# Download Maven
wget https://dlcdn.apache.org/maven/maven-3/3.9.5/binaries/apache-maven-3.9.5-bin.tar.gz

# Extract
tar -xzf apache-maven-3.9.5-bin.tar.gz

# Move to /opt
sudo mv apache-maven-3.9.5 /opt/maven

# Set environment variables in ~/.bashrc or ~/.zshrc
export MAVEN_HOME=/opt/maven
export PATH=$MAVEN_HOME/bin:$PATH

# Reload shell
source ~/.bashrc

# Verify
mvn --version
```

## Basic Concepts

### Project Object Model (POM)
The pom.xml file is the core of a Maven project, containing configuration information.

### Dependency
External libraries required by your project.

### Repository
- Local: ~/.m2/repository
- Central: Maven Central Repository
- Remote: Custom repository (Nexus, Artifactory, Harbor)

### Lifecycle
Pre-defined sequence of phases (validate, compile, test, package, install, deploy)

### Plugin
Tool that executes specific tasks during the build

### Goal
Specific task performed by a plugin

## POM Structure

### Basic pom.xml
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.example</groupId>
    <artifactId>myapp</artifactId>
    <version>1.0.0-SNAPSHOT</version>
    <packaging>jar</packaging>

    <name>My Application</name>
    <description>A sample Maven project</description>

    <properties>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>

    <dependencies>
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
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.11.0</version>
            </plugin>
        </plugins>
    </build>
</project>
```

### Dependency Management
```xml
<dependencies>
    <!-- Compile scope (default) -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
        <version>3.1.5</version>
    </dependency>

    <!-- Test scope -->
    <dependency>
        <groupId>org.junit.jupiter</groupId>
        <artifactId>junit-jupiter</artifactId>
        <version>5.10.0</version>
        <scope>test</scope>
    </dependency>

    <!-- Provided scope -->
    <dependency>
        <groupId>javax.servlet</groupId>
        <artifactId>javax.servlet-api</artifactId>
        <version>4.0.1</version>
        <scope>provided</scope>
    </dependency>

    <!-- Runtime scope -->
    <dependency>
        <groupId>com.h2database</groupId>
        <artifactId>h2</artifactId>
        <version>2.2.224</version>
        <scope>runtime</scope>
    </dependency>
</dependencies>
```

### Dependency Management (Parent POM)
```xml
<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-dependencies</artifactId>
            <version>3.1.5</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
    </dependencies>
</dependencyManagement>
```

## Maven Commands

### Basic Commands
```bash
# Clean build artifacts
mvn clean

# Compile source code
mvn compile

# Run tests
mvn test

# Package application (JAR/WAR)
mvn package

# Install to local repository
mvn install

# Deploy to remote repository
mvn deploy

# Common combined commands
mvn clean install
mvn clean package
mvn clean test
```

### Advanced Commands
```bash
# Skip tests
mvn clean install -DskipTests

# Run specific test
mvn test -Dtest=MyTestClass

# Update dependencies
mvn clean install -U

# Dependency tree
mvn dependency:tree

# Effective POM
mvn help:effective-pom

# Analyze dependencies
mvn dependency:analyze

# Purge local repository
mvn dependency:purge-local-repository

# Generate project documentation
mvn site

# Run application (with exec plugin)
mvn exec:java -Dexec.mainClass="com.example.Main"
```

## Standard Directory Structure
```
myapp/
├── pom.xml
├── src/
│   ├── main/
│   │   ├── java/              # Java source code
│   │   │   └── com/example/
│   │   ├── resources/         # Resources (properties, XML, etc.)
│   │   └── webapp/            # Web resources (for WAR)
│   │       ├── WEB-INF/
│   │       └── index.html
│   └── test/
│       ├── java/              # Test source code
│       └── resources/         # Test resources
└── target/                    # Build output (generated)
    ├── classes/
    ├── test-classes/
    └── myapp-1.0.0.jar
```

## Build Lifecycle

### Default Lifecycle Phases
1. validate - Validate project structure
2. compile - Compile source code
3. test - Run unit tests
4. package - Package compiled code (JAR/WAR)
5. verify - Run integration tests
6. install - Install package to local repository
7. deploy - Deploy package to remote repository

### Clean Lifecycle
- pre-clean
- clean
- post-clean

### Site Lifecycle
- pre-site
- site
- post-site
- site-deploy

## Common Plugins

### Compiler Plugin
```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-compiler-plugin</artifactId>
    <version>3.11.0</version>
    <configuration>
        <source>11</source>
        <target>11</target>
        <encoding>UTF-8</encoding>
    </configuration>
</plugin>
```

### Surefire Plugin (Unit Tests)
```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-surefire-plugin</artifactId>
    <version>3.1.2</version>
    <configuration>
        <includes>
            <include>**/*Test.java</include>
        </includes>
    </configuration>
</plugin>
```

### JAR Plugin
```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-jar-plugin</artifactId>
    <version>3.3.0</version>
    <configuration>
        <archive>
            <manifest>
                <mainClass>com.example.Main</mainClass>
                <addClasspath>true</addClasspath>
            </manifest>
        </archive>
    </configuration>
</plugin>
```

### Shade Plugin (Fat JAR)
```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-shade-plugin</artifactId>
    <version>3.5.0</version>
    <executions>
        <execution>
            <phase>package</phase>
            <goals>
                <goal>shade</goal>
            </goals>
            <configuration>
                <transformers>
                    <transformer implementation="org.apache.maven.plugins.shade.resource.ManifestResourceTransformer">
                        <mainClass>com.example.Main</mainClass>
                    </transformer>
                </transformers>
            </configuration>
        </execution>
    </executions>
</plugin>
```

### Docker Maven Plugin (Jib)
```xml
<plugin>
    <groupId>com.google.cloud.tools</groupId>
    <artifactId>jib-maven-plugin</artifactId>
    <version>3.4.0</version>
    <configuration>
        <to>
            <image>harbor.example.com/myproject/myapp:${project.version}</image>
            <auth>
                <username>${env.HARBOR_USER}</username>
                <password>${env.HARBOR_PASS}</password>
            </auth>
        </to>
        <container>
            <jvmFlags>
                <jvmFlag>-Xms512m</jvmFlag>
                <jvmFlag>-Xmx512m</jvmFlag>
            </jvmFlags>
            <mainClass>com.example.Main</mainClass>
        </container>
    </configuration>
</plugin>
```

## Multi-Module Projects

### Parent POM
```xml
<project>
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.example</groupId>
    <artifactId>parent</artifactId>
    <version>1.0.0</version>
    <packaging>pom</packaging>

    <modules>
        <module>module-a</module>
        <module>module-b</module>
        <module>module-c</module>
    </modules>

    <properties>
        <java.version>11</java.version>
    </properties>

    <dependencyManagement>
        <!-- Centralized dependency versions -->
    </dependencyManagement>
</project>
```

### Child Module POM
```xml
<project>
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>com.example</groupId>
        <artifactId>parent</artifactId>
        <version>1.0.0</version>
    </parent>

    <artifactId>module-a</artifactId>

    <dependencies>
        <!-- Module-specific dependencies -->
    </dependencies>
</project>
```

## Profiles

### Environment-Specific Profiles
```xml
<profiles>
    <profile>
        <id>development</id>
        <activation>
            <activeByDefault>true</activeByDefault>
        </activation>
        <properties>
            <env>dev</env>
            <db.url>jdbc:h2:mem:devdb</db.url>
        </properties>
    </profile>

    <profile>
        <id>production</id>
        <properties>
            <env>prod</env>
            <db.url>jdbc:postgresql://prod-db:5432/proddb</db.url>
        </properties>
        <build>
            <plugins>
                <!-- Production-specific plugins -->
            </plugins>
        </build>
    </profile>
</profiles>
```

```bash
# Activate profile
mvn clean install -Pproduction
```

## Settings Configuration (settings.xml)

Location: `~/.m2/settings.xml`

```xml
<settings>
    <!-- Local repository location -->
    <localRepository>/path/to/.m2/repository</localRepository>

    <!-- Mirrors -->
    <mirrors>
        <mirror>
            <id>central-mirror</id>
            <url>https://repo1.maven.org/maven2</url>
            <mirrorOf>central</mirrorOf>
        </mirror>
    </mirrors>

    <!-- Servers (credentials) -->
    <servers>
        <server>
            <id>harbor-releases</id>
            <username>admin</username>
            <password>password</password>
        </server>
    </servers>

    <!-- Profiles -->
    <profiles>
        <profile>
            <id>company-repo</id>
            <repositories>
                <repository>
                    <id>company-releases</id>
                    <url>https://nexus.company.com/repository/maven-releases</url>
                </repository>
            </repositories>
        </profile>
    </profiles>

    <activeProfiles>
        <activeProfile>company-repo</activeProfile>
    </activeProfiles>
</settings>
```

## Integration with Other Tools

### Jenkins Integration
```groovy
pipeline {
    agent any
    tools {
        maven 'Maven 3.9'
        jdk 'JDK11'
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

### Docker Integration
```dockerfile
FROM maven:3.9-openjdk-11 AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline
COPY src ./src
RUN mvn clean package -DskipTests

FROM openjdk:11-jre-slim
COPY --from=builder /app/target/myapp.jar .
CMD ["java", "-jar", "myapp.jar"]
```

### SonarQube Integration
```xml
<properties>
    <sonar.host.url>http://sonarqube:9000</sonar.host.url>
    <sonar.login>admin</sonar.login>
    <sonar.password>admin</sonar.password>
</properties>
```

```bash
mvn clean verify sonar:sonar
```

## Best Practices
1. Use dependency management for version control
2. Keep POM files clean and organized
3. Use properties for repeated values
4. Implement multi-module structure for large projects
5. Use profiles for environment-specific configurations
6. Regularly update dependencies
7. Use dependency scope appropriately
8. Exclude transitive dependencies when needed
9. Keep build reproducible
10. Use Maven wrapper (mvnw) for consistent builds

## Troubleshooting

### Dependency conflicts
```bash
# View dependency tree
mvn dependency:tree

# Exclude conflicting dependency
<dependency>
    <groupId>com.example</groupId>
    <artifactId>library</artifactId>
    <version>1.0</version>
    <exclusions>
        <exclusion>
            <groupId>commons-logging</groupId>
            <artifactId>commons-logging</artifactId>
        </exclusion>
    </exclusions>
</dependency>
```

### Build failures
```bash
# Clean and rebuild
mvn clean install -U

# Debug mode
mvn -X clean install

# Skip tests temporarily
mvn clean install -DskipTests
```

### Repository issues
```bash
# Purge local repository
mvn dependency:purge-local-repository

# Force update
mvn clean install -U
```

## References
- Official Documentation: https://maven.apache.org/guides/
- Maven Central: https://search.maven.org/
- Plugin Registry: https://maven.apache.org/plugins/
- POM Reference: https://maven.apache.org/pom.html
