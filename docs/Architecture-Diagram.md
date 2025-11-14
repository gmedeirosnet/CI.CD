# CI/CD Pipeline Architecture

## Overview
This document provides a comprehensive view of the DevOps CI/CD pipeline architecture for the learning laboratory.

## Complete Pipeline Flow

```mermaid
graph TB
    Dev[Developer] -->|git push| GH[GitHub Repository]
    GH -->|webhook| JK[Jenkins]

    JK -->|1. Checkout| Code[Source Code]
    JK -->|2. Build| MVN[Maven Build]
    MVN -->|3. Test| Test[Unit Tests]
    MVN -->|4. Analyze| SQ[SonarQube]

    JK -->|5. Build Image| DK[Docker Build]
    DK -->|6. Push| HB[Harbor Registry]

    JK -->|7. Package| HLM[Helm Chart]
    HLM -->|8. Deploy| AC[ArgoCD]
    AC -->|9. Sync| K8S[Kind K8s Cluster]

    AN[Ansible] -.->|Configure| K8S

    K8S -->|Running App| APP[Application]

    style Dev fill:#e1f5fe
    style GH fill:#fff3e0
    style JK fill:#f3e5f5
    style MVN fill:#e8f5e9
    style SQ fill:#fff9c4
    style DK fill:#e0f2f1
    style HB fill:#fce4ec
    style HLM fill:#f1f8e9
    style AC fill:#e8eaf6
    style K8S fill:#e0f7fa
    style APP fill:#c8e6c9
```

## Detailed Architecture Diagram

```mermaid
graph LR
    subgraph "Development"
        D1[Developer Workstation]
        D2[Git Client]
    end

    subgraph "Source Control"
        SC1[GitHub Repository]
        SC2[Branches: main/dev]
        SC3[Pull Requests]
    end

    subgraph "CI/CD Orchestration"
        J1[Jenkins Master]
        J2[Jenkins Agent]
        J3[Pipeline Scripts]
    end

    subgraph "Build & Test"
        B1[Maven Build]
        B2[Unit Tests]
        B3[Integration Tests]
        SQ1[SonarQube Analysis]
    end

    subgraph "Containerization"
        DC1[Dockerfile]
        DC2[Docker Build]
        DC3[Container Image]
    end

    subgraph "Artifact Storage"
        H1[Harbor Registry]
        H2[Image Scanning]
        H3[Image Signing]
    end

    subgraph "Package Management"
        HM1[Helm Chart]
        HM2[Chart Repository]
    end

    subgraph "GitOps Deployment"
        AR1[ArgoCD]
        AR2[Application Sync]
        AR3[Health Monitoring]
    end

    subgraph "Kubernetes Cluster - Kind"
        K1[Control Plane]
        K2[Worker Nodes]
        K3[Pods]
        K4[Services]
        K5[Ingress]
    end

    subgraph "Configuration Management"
        AN1[Ansible]
        AN2[Playbooks]
        AN3[Inventory]
    end

    D1 --> D2
    D2 --> SC1
    SC1 --> SC2
    SC2 --> SC3
    SC1 -.->|webhook| J1
    J1 --> J2
    J2 --> J3
    J3 --> B1
    B1 --> B2
    B2 --> B3
    B1 --> SQ1
    J3 --> DC1
    DC1 --> DC2
    DC2 --> DC3
    DC3 --> H1
    H1 --> H2
    H2 --> H3
    J3 --> HM1
    HM1 --> HM2
    HM2 --> AR1
    AR1 --> AR2
    AR2 --> K1
    K1 --> K2
    K2 --> K3
    K3 --> K4
    K4 --> K5
    AN1 --> AN2
    AN2 --> AN3
    AN3 -.-> K2
```

## Component Interaction Matrix

```mermaid
graph TD
    subgraph "Layer 1: Source"
        GitHub
    end

    subgraph "Layer 2: CI"
        Jenkins
        Maven
        SonarQube
    end

    subgraph "Layer 3: Containerization"
        Docker
        Harbor
    end

    subgraph "Layer 4: Packaging"
        Helm
    end

    subgraph "Layer 5: CD"
        ArgoCD
        Ansible
    end

    subgraph "Layer 6: Runtime"
        Kind[Kind - K8s in Docker]
        App[Application]
    end

    GitHub --> Jenkins
    Jenkins --> Maven
    Jenkins --> SonarQube
    Jenkins --> Docker
    Docker --> Harbor
    Jenkins --> Helm
    Helm --> ArgoCD
    ArgoCD --> Kind
    Ansible -.-> Kind
    Kind --> App
```

## Network Architecture

```mermaid
graph TB
    subgraph "Host Machine - macOS"
        subgraph "Docker Desktop"
            subgraph "Kind Cluster Network"
                CP[Control Plane<br/>:6443]
                W1[Worker Node 1]
                W2[Worker Node 2]

                subgraph "Pods"
                    APP1[App Pod 1<br/>:8000]
                    APP2[App Pod 2<br/>:8000]
                end
            end

            JC[Jenkins Container<br/>:8080]
            HC[Harbor Container<br/>:8082,:8443]
            SC[SonarQube Container<br/>:9000]
        end

        LH[localhost]
    end

    Internet[Internet] --> LH
    LH --> JC
    LH --> HC
    LH --> SC
    LH --> CP

    CP --> W1
    CP --> W2
    W1 --> APP1
    W2 --> APP2

    JC -.->|build/deploy| HC
    JC -.->|analysis| SC
    JC -.->|kubectl| CP
```

## Data Flow Diagram

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub
    participant JK as Jenkins
    participant MV as Maven
    participant SQ as SonarQube
    participant DK as Docker
    participant HB as Harbor
    participant HL as Helm
    participant AC as ArgoCD
    participant K8 as Kind K8s

    Dev->>GH: git push
    GH->>JK: webhook trigger
    JK->>GH: checkout code
    JK->>MV: mvn clean package
    MV->>MV: compile & test
    MV-->>JK: artifacts
    JK->>SQ: analyze code
    SQ-->>JK: quality report
    JK->>DK: docker build
    DK->>HB: docker push
    HB->>HB: scan image
    JK->>HL: helm package
    HL->>GH: update manifests
    GH->>AC: git sync
    AC->>K8: kubectl apply
    K8->>HB: pull image
    K8->>K8: deploy pods
    K8-->>Dev: app running
```

## Security Architecture

```mermaid
graph TB
    subgraph "Security Layers"
        subgraph "Code Security"
            SQ[SonarQube<br/>Static Analysis]
            UT[Unit Tests]
        end

        subgraph "Image Security"
            HS[Harbor Scanning]
            IS[Image Signing]
            VS[Vulnerability Scanning]
        end

        subgraph "Runtime Security"
            RBAC[K8s RBAC]
            NS[Network Policies]
            SA[Service Accounts]
            SEC[Security Contexts]
        end

        subgraph "Secrets Management"
            KS[K8s Secrets]
            ENV[Environment Variables]
            HC[Harbor Credentials]
        end
    end

    Code[Source Code] --> SQ
    Code --> UT
    SQ --> Build[Build Process]
    UT --> Build

    Build --> Image[Container Image]
    Image --> HS
    HS --> IS
    IS --> VS

    VS --> Deploy[Deployment]
    Deploy --> RBAC
    Deploy --> NS
    Deploy --> SA
    Deploy --> SEC

    HC --> Image
    KS --> Deploy
    ENV --> Deploy
```

## Tool Integration Map

| Tool | Integrates With | Purpose |
|------|----------------|---------|
| **GitHub** | Jenkins, ArgoCD | Source control, manifest storage |
| **Jenkins** | Maven, SonarQube, Docker, Harbor, Helm, Kind | CI/CD orchestration |
| **Maven** | Jenkins, SonarQube | Build automation |
| **SonarQube** | Jenkins, Maven | Code quality analysis |
| **Docker** | Jenkins, Harbor, Kind | Container image creation |
| **Harbor** | Jenkins, Docker, Kind | Image registry and security |
| **Helm** | Jenkins, ArgoCD, Kind | Package management |
| **ArgoCD** | GitHub, Helm, Kind | GitOps deployment |
| **Kind** | kubectl, ArgoCD, Harbor | Kubernetes runtime |
| **Ansible** | Kind nodes | Configuration management |

## Deployment States

```mermaid
stateDiagram-v2
    [*] --> Development
    Development --> CodeReview: Pull Request
    CodeReview --> Development: Changes Required
    CodeReview --> CI: Approved & Merged

    CI --> Build: Maven Build
    Build --> Test: Unit Tests
    Test --> Analysis: SonarQube
    Analysis --> Failed: Quality Gate Failed
    Analysis --> Containerize: Quality Gate Passed
    Failed --> Development: Fix Issues

    Containerize --> DockerBuild: Create Image
    DockerBuild --> HarborPush: Push Image
    HarborPush --> Scanning: Security Scan
    Scanning --> ScanFailed: Vulnerabilities Found
    Scanning --> Package: Scan Passed
    ScanFailed --> Development: Fix Security Issues

    Package --> HelmPackage: Create Chart
    HelmPackage --> GitOps: Update Manifests
    GitOps --> ArgoCD: Sync Application
    ArgoCD --> Deploy: Apply to K8s
    Deploy --> Running: Pods Healthy
    Running --> Monitoring: Health Checks

    Monitoring --> Running: Healthy
    Monitoring --> Rollback: Unhealthy
    Rollback --> Running: Previous Version

    Running --> [*]: Successful Deployment
```

## Port Mappings Reference

| Service | Internal Port | External Port | Protocol | Access URL |
|---------|--------------|---------------|----------|------------|
| Jenkins | 8080 | 8080 | HTTP | http://localhost:8080 |
| Harbor | 80/443 | 8082/8443 | HTTP/HTTPS | http://localhost:8082 |
| SonarQube | 9000 | 8090 | HTTP | http://localhost:8090 |
| Application | 8000 | 8000 | HTTP | http://localhost:8000 |
| ArgoCD | 8080 | 8080 | HTTP | http://localhost:8080 |
| Kind API Server | 6443 | 6443 | HTTPS | https://localhost:6443 |

## Scaling Architecture

```mermaid
graph TB
    subgraph "Horizontal Scaling"
        HPA[Horizontal Pod Autoscaler]
        HPA --> Pods

        subgraph "Pods"
            P1[Pod 1]
            P2[Pod 2]
            P3[Pod 3]
            PN[Pod N...]
        end
    end

    subgraph "Load Distribution"
        SVC[Kubernetes Service]
        SVC --> P1
        SVC --> P2
        SVC --> P3
        SVC --> PN
    end

    Metrics[Metrics Server] --> HPA
    Users[Users] --> Ingress[Ingress/LoadBalancer]
    Ingress --> SVC
```

## Disaster Recovery Flow

```mermaid
graph LR
    subgraph "Backup"
        Git[Git Repository<br/>Source of Truth]
        Helm[Helm Charts]
        Config[Configuration Files]
    end

    subgraph "Recovery"
        Clone[Clone Repository]
        Setup[Setup Infrastructure]
        Deploy[Deploy via ArgoCD]
        Verify[Verify Deployment]
    end

    Git --> Clone
    Helm --> Clone
    Config --> Clone
    Clone --> Setup
    Setup --> Deploy
    Deploy --> Verify
    Verify -->|Success| Running[Running System]
    Verify -->|Failure| Setup
```

## Summary

This architecture provides:
- **Automation**: Full CI/CD pipeline from code commit to deployment
- **Security**: Multiple scanning and validation layers
- **Scalability**: Kubernetes-based deployment with autoscaling
- **Reliability**: GitOps approach with rollback capabilities
- **Observability**: Health monitoring and metrics collection
- **Portability**: Container-based deployment on local Kind cluster
- **Best Practices**: Industry-standard tools and patterns

## Next Steps

1. Review the [Port Reference Guide](Port-Reference.md) for detailed port configurations
2. Follow the [Lab Setup Guide](#Lab-Setup-Guide.md) for implementation
3. Refer to [Troubleshooting Guide](Troubleshooting.md) for common issues
4. Check [Cleanup Guide](Cleanup-Guide.md) for environment teardown procedures
