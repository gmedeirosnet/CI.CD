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

### Configuration & Analysis
- **Ansible** - Agentless automation and configuration management
- **SonarQube** - Code quality and security analysis

## Repository Structure

```
CI.CD/
├── ai/                          # AI-assisted learning configurations
│   ├── instructions.json        # Project guidelines
│   ├── tools.json              # Tool catalog
│   ├── prompts.json            # Learning prompts
│   ├── modes.json              # Learning modes
│   └── documentation.json      # Documentation structure
│
├── docs/                        # Comprehensive documentation
│   ├── ArgoCD.md               # ArgoCD guide
│   ├── Kind-K8s.md             # Kind (K8s in Docker) guide
│   ├── Ansible.md              # Ansible guide
│   ├── Docker.md               # Docker guide
│   ├── Harbor.md               # Harbor guide
│   ├── Helm-Charts.md          # Helm guide
│   ├── Jenkins.md              # Jenkins guide
│   ├── Maven.md                # Maven guide
│   ├── SonarQube.md            # SonarQube guide
│   ├── Lab-Setup-Guide.md      # Complete lab setup
│   ├── Project-Overview.md     # Detailed overview
│   └── StudyPlan.md            # Learning curriculum
│
├── plan.md                      # Execution plan
└── README.md                    # This file
```

## Quick Start

### Prerequisites
- 16GB RAM minimum (32GB recommended)
- 50GB free disk space
- macOS (M4 recommended), Linux, or Windows with WSL2
- Docker Desktop installed (required for Kind)
- GitHub account

### Getting Started

1. **Clone the repository**
   ```bash
   git clone https://github.com/gmedeirosnet/CI.CD.git
   cd CI.CD
   ```

2. **Review the learning plan**
   ```bash
   cat docs/StudyPlan.md
   ```

3. **Follow the lab setup guide**
   ```bash
   cat docs/Lab-Setup-Guide.md
   ```

4. **Explore individual tool guides**
   - Start with Docker for containerization basics
   - Progress through the learning phases
   - Complete hands-on exercises

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
                    Ansible Configuration
```

## Key Features

- Complete CI/CD pipeline implementation
- Hands-on labs for each tool
- Real-world examples and scenarios
- Best practices and security guidelines
- Troubleshooting guides
- Integration patterns
- Production-ready configurations

## Documentation Highlights

### Tool Guides
Each tool has a comprehensive guide including:
- Introduction and key features
- Installation instructions
- Basic and advanced usage
- Integration with other tools
- Best practices
- Troubleshooting
- References and resources

### Lab Setup Guide
Step-by-step instructions for:
- Setting up the complete environment
- Creating sample applications
- Implementing the full pipeline
- Testing and validation
- Monitoring and optimization

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
- Build and containerize applications
- Create CI/CD pipelines
- Deploy to Kubernetes
- Implement GitOps workflows
- Manage infrastructure as code
- Ensure code quality and security
- Troubleshoot common issues
- Follow DevOps best practices

## Guidelines

- All AI configurations are in JSON format in `/ai` directory
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
- [Ansible](https://docs.ansible.com/)
- [Maven](https://maven.apache.org/guides/)
- [SonarQube](https://docs.sonarqube.org/)
- [Harbor](https://goharbor.io/docs/)
- [Kind](https://kind.sigs.k8s.io/)

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
