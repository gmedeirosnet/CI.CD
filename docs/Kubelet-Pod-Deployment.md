# Kubelet Pod Deployment Process

## Overview
This document explains how the Kubelet component deploys and manages pods in a Kubernetes cluster. The Kubelet is the primary node agent that runs on each worker node and is responsible for managing pods and their containers.

## Kubelet Pod Deployment Architecture

```mermaid
graph TB
    subgraph "Control Plane"
        API[API Server]
        SCHED[Scheduler]
        ETCD[(etcd)]
        CM[Controller Manager]
    end

    subgraph "Worker Node"
        KL[Kubelet]
        CR[Container Runtime<br/>Docker/containerd/CRI-O]

        subgraph "Pod Lifecycle"
            PS[Pod Spec]
            PC[Pod Creation]
            PI[Image Pull]
            CC[Container Creation]
            CH[Health Checks]
            PR[Pod Running]
        end
    end

    API -->|Watch for<br/>Pod assignments| KL
    SCHED -->|Assign Pod<br/>to Node| API
    KL -->|Report<br/>Status| API
    API -->|Store State| ETCD

    KL -->|1. Receive| PS
    PS -->|2. Validate| PC
    PC -->|3. Request| PI
    PI -->|4. Pull Image| CR
    CR -->|5. Create| CC
    CC -->|6. Monitor| CH
    CH -->|7. Update| PR
    PR -->|8. Report| KL

    style API fill:#e3f2fd
    style KL fill:#fff3e0
    style CR fill:#f3e5f5
    style PS fill:#e8f5e9
    style PR fill:#c8e6c9
```

## Detailed Pod Deployment Flow

```mermaid
sequenceDiagram
    participant User
    participant API as API Server
    participant ETCD as etcd
    participant Scheduler
    participant Kubelet
    participant CRI as Container Runtime
    participant Registry as Image Registry

    User->>API: kubectl create pod
    API->>ETCD: Store Pod Spec
    API->>Scheduler: Notify new Pod
    Scheduler->>API: Get Pod requirements
    Scheduler->>Scheduler: Find suitable Node
    Scheduler->>API: Bind Pod to Node
    API->>ETCD: Update Pod binding

    Kubelet->>API: Watch for Pods (polling)
    API->>Kubelet: Pod assigned to this Node

    Kubelet->>Kubelet: Validate Pod Spec
    Kubelet->>CRI: Check image availability

    alt Image not present
        CRI->>Registry: Pull image
        Registry->>CRI: Image layers
    end

    Kubelet->>CRI: Create Pod sandbox
    CRI->>CRI: Setup network namespace
    CRI->>CRI: Setup IPC namespace

    loop For each container
        Kubelet->>CRI: Create container
        CRI->>CRI: Mount volumes
        CRI->>CRI: Apply resource limits
        Kubelet->>CRI: Start container
    end

    Kubelet->>Kubelet: Setup probes
    Kubelet->>API: Update Pod status: Running
    API->>ETCD: Store Pod status

    loop Health monitoring
        Kubelet->>CRI: Execute liveness probe
        Kubelet->>CRI: Execute readiness probe
        Kubelet->>API: Report health status
    end
```

## Kubelet Components and Responsibilities

```mermaid
graph LR
    subgraph "Kubelet Architecture"
        KL[Kubelet Main Process]

        subgraph "Managers"
            PM[Pod Manager]
            VM[Volume Manager]
            IM[Image Manager]
            SM[Status Manager]
            PM2[Probe Manager]
        end

        subgraph "Interfaces"
            CRI[Container Runtime<br/>Interface CRI]
            CNI[Container Network<br/>Interface CNI]
            CSI[Container Storage<br/>Interface CSI]
        end

        subgraph "Functions"
            SY[Pod Sync]
            HC[Health Checks]
            RM[Resource Monitoring]
            GC[Garbage Collection]
        end
    end

    KL --> PM
    KL --> VM
    KL --> IM
    KL --> SM
    KL --> PM2

    PM --> CRI
    VM --> CSI
    PM --> CNI

    PM --> SY
    PM2 --> HC
    SM --> RM
    IM --> GC

    style KL fill:#fff3e0
    style PM fill:#e8f5e9
    style CRI fill:#e3f2fd
    style CNI fill:#f3e5f5
    style CSI fill:#fce4ec
```

## Pod Lifecycle States

```mermaid
stateDiagram-v2
    [*] --> Pending: Pod created

    Pending --> Running: All containers started
    Pending --> Failed: Cannot schedule/pull images

    Running --> Succeeded: All containers completed successfully
    Running --> Failed: Container crashes/errors
    Running --> Unknown: Node communication lost

    Failed --> [*]: Terminal state
    Succeeded --> [*]: Terminal state

    Unknown --> Running: Node communication restored
    Unknown --> Failed: Node confirmed down

    note right of Pending
        Kubelet validates spec
        Pulls container images
        Creates pod sandbox
    end note

    note right of Running
        Kubelet monitors health
        Executes probes
        Reports status
    end note
```

## Kubelet Pod Creation Steps

```mermaid
graph TD
    START([Pod Assigned to Node]) --> S1[1. Kubelet Detects New Pod]

    S1 --> S2{Pod Spec Valid?}
    S2 -->|No| ERR1[Report Error]
    S2 -->|Yes| S3[2. Admit Pod]

    S3 --> S4[3. Create Pod Directory]
    S4 --> S5[4. Fetch Image Pull Secrets]

    S5 --> S6{Image Available?}
    S6 -->|No| S7[5. Pull Image from Registry]
    S7 --> S8{Pull Success?}
    S8 -->|No| ERR2[Report ImagePullBackOff]
    S8 -->|Yes| S9
    S6 -->|Yes| S9[6. Create Pod Sandbox]

    S9 --> S10[7. Setup Network CNI]
    S10 --> S11[8. Mount Volumes]

    S11 --> S12[9. Start Init Containers]
    S12 --> S13{Init Success?}
    S13 -->|No| ERR3[Report Init Error]
    S13 -->|Yes| S14[10. Start App Containers]

    S14 --> S15[11. Setup Health Probes]
    S15 --> S16[12. Update Status: Running]
    S16 --> S17([Monitor & Report])

    ERR1 --> END([Failed State])
    ERR2 --> END
    ERR3 --> END

    style START fill:#e8f5e9
    style S17 fill:#c8e6c9
    style END fill:#ffcdd2
```

## Kubelet Watch and Sync Loop

```mermaid
graph LR
    subgraph "Kubelet Sync Loop every 1s"
        W1[Watch API Server] --> W2[Get Pod List]
        W2 --> W3[Compare Desired<br/>vs Current State]
        W3 --> W4{Changes<br/>Detected?}
        W4 -->|Yes| W5[Sync Pod]
        W4 -->|No| W6[Continue]
        W5 --> W7[Update Status]
        W7 --> W6
        W6 --> W1
    end

    subgraph "Pod Sync Actions"
        W5 --> A1{Action Type?}
        A1 -->|Create| A2[Create New Pod]
        A1 -->|Update| A3[Update Existing Pod]
        A1 -->|Delete| A4[Terminate Pod]
        A1 -->|Restart| A5[Restart Container]
    end

    style W3 fill:#fff3e0
    style W5 fill:#e8f5e9
```

## Container Runtime Interface (CRI) Operations

```mermaid
graph TB
    subgraph "Kubelet to CRI Communication"
        KL[Kubelet]

        subgraph "CRI Runtime Service"
            RS1[RunPodSandbox]
            RS2[StopPodSandbox]
            RS3[RemovePodSandbox]
            RS4[PodSandboxStatus]
        end

        subgraph "CRI Image Service"
            IS1[PullImage]
            IS2[ListImages]
            IS3[RemoveImage]
            IS4[ImageStatus]
        end

        subgraph "CRI Container Service"
            CS1[CreateContainer]
            CS2[StartContainer]
            CS3[StopContainer]
            CS4[RemoveContainer]
            CS5[ContainerStatus]
            CS6[ExecSync]
        end
    end

    KL --> RS1
    KL --> IS1
    KL --> CS1

    RS1 -.-> CS1
    IS1 -.-> RS1
    CS1 -.-> CS2

    style KL fill:#fff3e0
    style RS1 fill:#e3f2fd
    style IS1 fill:#f3e5f5
    style CS1 fill:#e8f5e9
```

## Key Concepts

### 1. Pod Sandbox
The pod sandbox is the environment where containers run, including:
- **Network namespace**: Shared network stack for all containers
- **IPC namespace**: Inter-process communication
- **UTS namespace**: Hostname and domain name
- **Cgroups**: Resource limits and isolation

### 2. Kubelet Responsibilities
- **Pod Lifecycle Management**: Create, update, and delete pods
- **Container Health Monitoring**: Execute liveness and readiness probes
- **Resource Management**: Enforce CPU and memory limits
- **Volume Management**: Mount and unmount volumes
- **Image Management**: Pull images and garbage collect unused ones
- **Status Reporting**: Report pod and node status to API server

### 3. Pod Creation Phases

| Phase | Description | Kubelet Action |
|-------|-------------|----------------|
| **Pending** | Pod accepted but not running | Validate spec, pull images |
| **Running** | Pod bound to node, containers running | Monitor health, report status |
| **Succeeded** | All containers terminated successfully | Clean up resources |
| **Failed** | At least one container failed | Report failure, may restart |
| **Unknown** | Pod status cannot be determined | Attempt to reconnect |

### 4. Health Probes
- **Liveness Probe**: Determines if container is running; restarts on failure
- **Readiness Probe**: Determines if container is ready for traffic
- **Startup Probe**: Checks if application has started; delays other probes

### 5. Image Pull Policies
- **Always**: Always pull image from registry
- **IfNotPresent**: Pull only if image not present locally
- **Never**: Never pull, use local image only

## Kubelet Configuration

The Kubelet is configured with several important parameters:

```yaml
# Key Kubelet Configuration Options
--pod-manifest-path: Directory for static pod manifests
--sync-frequency: Sync frequency (default: 1m)
--pod-infra-container-image: Pause container image
--container-runtime-endpoint: CRI socket path
--max-pods: Maximum pods per node (default: 110)
--cluster-dns: DNS server for pods
--cluster-domain: Cluster domain (default: cluster.local)
```

## Troubleshooting Pod Deployment

### Common Issues and Resolution

1. **ImagePullBackOff**
   - Kubelet cannot pull container image
   - Check image name, registry credentials, network connectivity

2. **CrashLoopBackOff**
   - Container repeatedly crashes after starting
   - Check container logs, liveness probes, resource limits

3. **Pending State**
   - Pod stuck in Pending, not scheduled
   - Check node resources, taints/tolerations, affinity rules

4. **ContainerCreating**
   - Pod stuck creating containers
   - Check volume mounts, image pull status, CNI configuration

## Monitoring Kubelet Operations

```bash
# Check kubelet logs
journalctl -u kubelet -f

# View kubelet metrics
curl http://localhost:10255/metrics

# Check pod status
kubectl describe pod <pod-name>

# View kubelet configuration
kubectl get --raw /api/v1/nodes/<node-name>/proxy/configz
```

## References

- [Kubernetes Kubelet Documentation](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/)
- [Container Runtime Interface (CRI)](https://kubernetes.io/docs/concepts/architecture/cri/)
- [Pod Lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/)
- [Node Components](https://kubernetes.io/docs/concepts/architecture/nodes/)
