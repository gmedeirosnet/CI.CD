### LEARNING CONTINUOUS INTEGRATION AND CONTINUOUS DELIVERY ###
# DevOps CI/CD Learning Laboratory

A comprehensive hands-on laboratory environment for learning DevOps CI/CD deployment tools and practices.

## Overview

This repository provides a complete learning experience for mastering DevOps CI/CD tools through practical, hands-on labs. The curriculum focuses on 10 industry-standard tools that form the backbone of modern DevOps practices.

## Tools Covered

### Continuous Integration/Delivery
- **Jenkins** - Industry-leading CI/CD automation server
- **ArgoCD** - GitOps continuous delivery for Kubernetes

### Version Control & Artifacts
- **GitHub** - Source code management and collaboration
- **Harbor** - Enterprise container image registry
- **Maven** - Build automation and dependency management

### Containerization & Orchestration
- **Docker** - Container platform for application packaging
- **Kind (K8s in Docker)** - Local Kubernetes clusters for development and testing
- **Helm Charts** - Kubernetes package manager

### Code Quality & Observability
- **SonarQube** - Code quality and security analysis
- **Grafana** - Unified visualization and monitoring dashboard
- **Loki** - Log aggregation and querying system
- **Prometheus** - Metrics collection and time-series database

## Repository Structure

```
CI.CD/
├── instructions/                # AI-assisted learning configurations
│   ├── instructions.json        # Project guidelines
│   ├── tools.json              # Tool catalog
│   ├── prompts.json            # Learning prompts
│   ├── modes.json              # Learning modes
│   └── documentation.json      # Documentation structure
│
├── docs/                        # Comprehensive documentation
│   ├── ArgoCD.md               # ArgoCD guide
│   ├── Kind-K8s.md             # Kind (K8s in Docker) guide
│   ├── Docker.md               # Docker guide
│   ├── Harbor.md               # Harbor guide
│   ├── Helm-Charts.md          # Helm guide
│   ├── Jenkins.md              # Jenkins guide
│   ├── Maven.md                # Maven guide
│   ├── SonarQube.md            # SonarQube guide
│   ├── Grafana-Loki.md         # Grafana, Loki & Prometheus guide
│   ├── Lab-Setup-Guide.md      # Complete lab setup
│   ├── Project-Overview.md     # Detailed overview
│   ├── Port-Reference.md       # All service ports and URLs
│   ├── Troubleshooting.md      # Common issues and solutions
│   └── StudyPlan.md            # Learning curriculum
│
├── plan.md                      # Execution plan
└── README.md                    # This file
```

## Quick Start

### Prerequisites
- 16GB RAM minimum (32GB recommended)
- 50GB free disk space
- macOS (M1 recommended), Linux, or Windows with WSL2
- Docker Desktop installed and running
- GitHub account

### Automated Setup

The fastest way to get started:

```bash
# 1. Verify your environment meets prerequisites
./scripts/verify-environment.sh

# 2. Run the complete setup (takes 10-15 minutes)
./scripts/setup-all.sh

# 3. Access the services:
# - Jenkins:    http://localhost:8080
# - Harbor:     http://localhost:8082
# - SonarQube:  http://localhost:9000
# - Grafana:    http://localhost:3000
# - Prometheus: http://localhost:30090
# - Loki:       http://localhost:31000
```

### Manual Setup Steps

If you prefer step-by-step setup:

1. **Verify Prerequisites**
   ```bash
   ./scripts/verify-environment.sh
   ```

2. **Configure Environment**
   ```bash
   cp .env.template .env
   # Edit .env with your GitHub token and other credentials
   ```

3. **Create Kind Cluster**
   ```bash
   kind create cluster --config kind-config.yaml
   ```

4. **Start Services**
   ```bash
   # Harbor
   cd harbor && docker-compose up -d

   # Jenkins
   ./scripts/setup-jenkins-docker.sh

   # SonarQube
   ./scripts/setup-sonarqube.sh

   # Grafana + Loki + Prometheus
   cd k8s/grafana
   ./setup-loki.sh
   ./setup-prometheus.sh
   ./setup-grafana-docker.sh

   # ArgoCD
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```

5. **Build Application**
   ```bash
   mvn clean package
   ```

### First Steps After Setup

1. **Access Jenkins** at http://localhost:8080
   - Get password: `docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword`
   - Install suggested plugins
   - Create admin user

3. **Access Harbor** at http://localhost:8082
   - Login: admin / Harbor12345
   - Create project `cicd-demo`:
     - Click **Projects** > **NEW PROJECT**
     - Set name: `cicd-demo`, Access Level: Private
   - Create robot account (automated):
     ```bash
     cd scripts
     ./create-harbor-robot.sh
     ```
   - Save the robot token shown (displayed only once)
   - Add robot credentials in Jenkins:
     - Manage Jenkins > Credentials
     - Username: `robot$robot-ci-cd-demo`
     - Password: (the token from script)

4. **Configure Docker to use Harbor**
   ```bash
   # Add to Docker daemon.json:
   {
     "insecure-registries": ["localhost:8082"]
   }
   # Restart Docker Desktop
   ```

5. **Access Grafana** at http://localhost:3000
   - Login: admin / admin (change on first login)
   - Verify datasources: Loki and Prometheus should be pre-configured
   - Import dashboards or create custom queries

6. **Run your first pipeline**
   - Create Jenkins pipeline from Jenkinsfile
   - Trigger build
   - Watch it build → test → push to Harbor → deploy to Kind
   - View logs in Grafana (Loki) and metrics in Prometheus

### Cleanup

```bash
# Stop all services and optionally remove data
./scripts/cleanup-all.sh
```

---

## Learning Path

### Phase 1: Foundations (2-3 weeks)
- Git and GitHub
- Docker containerization
- Linux basics

### Phase 2: Build and Test (2-3 weeks)
- Maven builds
- Jenkins pipelines
- SonarQube analysis

### Phase 3: Container Orchestration (3-4 weeks)
- Kubernetes
- Kind (local K8s clusters)
- Helm

### Phase 4: Configuration and Deployment (2-3 weeks)
- ArgoCD GitOps
- Harbor security

### Phase 5: Integration (4-6 weeks)
- Complete pipeline
- Best practices
- Production readiness

## Complete Pipeline Flow

```
Developer → GitHub → Jenkins → Maven → SonarQube
                         ↓
                    Docker Build → Harbor
                         ↓
                    Helm Package → ArgoCD → Kind K8s
                                                ↓
                                    ┌───────────┴────────────┐
                                    ↓                        ↓
                                Application             Monitoring
                                                    ┌────────┴────────┐
                                                    ↓                 ↓
                                              Logs (Loki)      Metrics (Prometheus)
                                                    └────────┬────────┘
                                                             ↓
                                                         Grafana
                                                    (on Docker Desktop)
```

## Key Features## Key Features

- **Complete CI/CD Pipeline** - From code commit to Kubernetes deployment
- **Observability Stack** - Integrated logging (Loki) and metrics (Prometheus) with Grafana visualization
- **Hands-on Labs** - Practical exercises for each tool
- **Real-world Application** - Spring Boot demo application
- **GitOps Workflow** - ArgoCD-based deployment automation
- **Container Registry** - Harbor with security scanning
- **Code Quality Gates** - SonarQube integration
- **Local Kubernetes** - Kind cluster for safe testing
- **Automated Setup** - Scripts for quick environment provisioning
- **Comprehensive Documentation** - Step-by-step guides and troubleshooting

## Key Resources

### Essential Documentation
- [Architecture Diagram](docs/Architecture-Diagram.md) - Visual pipeline overview
- [Lab Setup Guide](docs/#Lab-Setup-Guide.md) - Complete setup instructions
- [Port Reference](docs/Port-Reference.md) - All service ports and URLs
- [Troubleshooting Guide](docs/Troubleshooting.md) - Common issues and solutions
- [Cleanup Guide](docs/Cleanup-Guide.md) - Teardown procedures

### Tool-Specific Guides
- [Docker](docs/Docker.md) - Containerization
- [Jenkins](docs/Jenkins.md) - CI/CD automation
- [Harbor](docs/Harbor.md) - Container registry
- [Kind](docs/Kind-K8s.md) - Local Kubernetes
- [Helm](docs/Helm-Charts.md) - Package management
- [ArgoCD](docs/ArgoCD.md) - GitOps deployment
- [SonarQube](docs/SonarQube.md) - Code quality
- [Maven](docs/Maven.md) - Build automation
- [Grafana, Loki & Prometheus](docs/Grafana-Loki.md) - Monitoring and logging

### Learning Materials
- [Study Plan](docs/StudyPlan.md) - DevOps learning curriculum
- [Project Overview](docs/Project-Overview.md) - Detailed project information

## What's Included

- Complete CI/CD pipeline implementation
- Integrated monitoring and logging stack (Prometheus, Loki, Grafana)
- Hands-on labs for each tool
- Real-world Spring Boot demo application
- Kubernetes deployment examples with observability
- Helm charts and manifests
- Jenkins pipeline scripts
- Docker configurations
- Best practices and security guidelines
- Troubleshooting guides
- Integration patterns
- Automated setup scripts

## Project Structure

```
CI.CD/
├── .env.template           # Environment variables template
├── .gitignore             # Git ignore rules
├── Dockerfile             # Application container image
├── Jenkinsfile            # CI/CD pipeline definition
├── pom.xml                # Maven project configuration
├── kind-config.yaml       # Kubernetes cluster config
│
├── docs/                  # Comprehensive documentation
│   ├── Architecture-Diagram.md
│   ├── Port-Reference.md
│   ├── Troubleshooting.md
│   ├── Cleanup-Guide.md
│   ├── Grafana-Loki.md    # Monitoring & logging guide
│   └── [Tool Guides...]
│
├── scripts/               # Automation scripts
│   ├── setup-all.sh      # Complete environment setup
│   ├── verify-environment.sh
│   ├── cleanup-all.sh
│   └── [Setup Scripts...]
│
├── src/                   # Demo Spring Boot application
│   ├── main/java/
│   └── test/java/
│
├── helm-charts/          # Kubernetes Helm charts
│   └── cicd-demo/
│
├── k8s/                  # Kubernetes configurations
│   ├── grafana/         # Grafana, Loki & Promtail setup
│   │   ├── docker-compose.yml
│   │   ├── setup-grafana-docker.sh
│   │   ├── setup-loki.sh
│   │   ├── setup-prometheus.sh
│   │   └── provisioning/
│   │       └── datasources/
│   │           ├── loki.yml
│   │           └── prometheus.yml
│   ├── prometheus/      # Prometheus monitoring stack
│   │   ├── prometheus-config.yaml
│   │   ├── prometheus-deployment.yaml
│   │   ├── prometheus-rbac.yaml
│   │   ├── kube-state-metrics.yaml
│   │   └── node-exporter.yaml
│   ├── kind-config.yaml
│   └── sample-app/
│
├── harbor/               # Harbor registry setup
│   └── docker-compose.yml
│
├── argocd-apps/         # ArgoCD applications
│   └── sample-nginx-app.yaml
│
└── instructions/         # JSON configs for AI assistance
    ├── instructions.json
    ├── tools.json
    └── [Config Files...]
```

## Use Cases

### For Beginners
- Learn DevOps fundamentals
- Understand CI/CD concepts
- Gain hands-on experience
- Build portfolio projects

### For Professionals
- Practice with industry tools
- Learn integration patterns
- Implement best practices
- Prepare for certifications

### For Teams
- Standardize tooling
- Share knowledge
- Train new members
- Document processes

## Success Metrics

After completing this lab, you will be able to:
- Build and containerize applications with Docker
- Create automated CI/CD pipelines with Jenkins
- Deploy to Kubernetes using GitOps (ArgoCD)
- Manage container images with Harbor registry
- Implement code quality gates with SonarQube
- Monitor applications with Prometheus metrics
- Aggregate and query logs with Loki
- Visualize data with Grafana dashboards
- Use Helm for Kubernetes package management
- Manage infrastructure as code
- Troubleshoot containerized applications
- Follow DevOps best practices and security standards

## Guidelines

- All AI configurations are in JSON format in `/instructions` directory
- Documentation files are in `/docs` directory only
- No emojis in documentation
- Git commands require explicit permission
- Follow the plan.md for structured execution

## Contributing

This is a learning laboratory. Contributions welcome:
- Documentation improvements
- Additional examples
- Troubleshooting tips
- Tool updates
- New scenarios

## Resources

### Official Documentation
- [Jenkins](https://www.jenkins.io/doc/)
- [Docker](https://docs.docker.com/)
- [Kubernetes](https://kubernetes.io/docs/)
- [ArgoCD](https://argo-cd.readthedocs.io/)
- [Helm](https://helm.sh/docs/)
- [Maven](https://maven.apache.org/guides/)
- [SonarQube](https://docs.sonarqube.org/)
- [Harbor](https://goharbor.io/docs/)
- [Kind](https://kind.sigs.k8s.io/)
- [Grafana](https://grafana.com/docs/)
- [Loki](https://grafana.com/docs/loki/latest/)
- [Prometheus](https://prometheus.io/docs/)

### Study Reference
- [NotebookLM Study Guide](https://notebooklm.google.com/notebook/04068cbd-0312-45b1-b221-ec2642e79464)

## Support

For questions and support:
1. Review tool-specific documentation
2. Check troubleshooting sections
3. Search community forums
4. Create GitHub issues for documentation

## License

Educational use. Check individual tool licenses for production deployment.

## Acknowledgments

Built on open-source tools maintained by amazing communities. Thanks to all contributors and maintainers.

---

**Start your DevOps learning journey today!**

For detailed information, see [Project Overview](docs/Project-Overview.md) and [Lab Setup Guide](docs/Lab-Setup-Guide.md).
