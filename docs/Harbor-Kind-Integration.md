# Harbor and Kind Integration for Mac Docker Desktop

## The Problem

When running Kind (Kubernetes in Docker) on Mac Docker Desktop, pods cannot pull images directly from Harbor registry at `localhost:8082` because:

1. **Network Isolation**: Harbor runs on the `harbor_harbor` Docker network, Kind cluster runs on the `kind` network
2. **Localhost Resolution**: Inside Kind nodes, `localhost` refers to the container itself, not the Mac host
3. **Authentication**: Harbor requires authentication even for public projects
4. **HTTP vs HTTPS**: Harbor uses HTTP, but containerd defaults to HTTPS

## The Solution

**Use `kind load docker-image` to pre-load images into Kind nodes**, combined with `imagePullPolicy: Never` in Kubernetes deployments.

### Why This Works

- Images are loaded directly into each Kind node's container runtime
- No network connectivity to Harbor required from Kind
- No authentication needed
- No HTTP/HTTPS configuration issues
- Reliable and recommended by Kind documentation

## Implementation

### 1. Automated Script (Recommended)

Use the provided script after pushing to Harbor:

```bash
./scripts/load-harbor-image-to-kind.sh localhost:8082/cicd-demo/app:latest
```

This script:
1. Pulls the image from Harbor to your local Docker
2. Tags it as `host.docker.internal:8082/cicd-demo/app:latest`
3. Loads it into all Kind cluster nodes

### 2. Manual Steps

```bash
# Pull from Harbor
docker pull localhost:8082/cicd-demo/app:latest

# Tag for Kind (using host.docker.internal naming)
docker tag localhost:8082/cicd-demo/app:latest \
           host.docker.internal:8082/cicd-demo/app:latest

# Load into Kind
kind load docker-image host.docker.internal:8082/cicd-demo/app:latest \
     --name app-demo
```

### 3. Helm Configuration

The `helm-charts/cicd-demo/values.yaml` is already configured:

```yaml
image:
  repository: host.docker.internal:8082/cicd-demo/app
  pullPolicy: Never  # Use pre-loaded images
  tag: "latest"
```

### 4. Jenkins Integration

Add this stage to your Jenkinsfile after "Push to Harbor":

```groovy
stage('Load Image into Kind') {
    steps {
        script {
            sh """
                # Pull from Harbor
                docker pull ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}

                # Tag for Kind
                docker tag ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG} \
                           host.docker.internal:8082/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}

                # Load into Kind cluster
                kind load docker-image host.docker.internal:8082/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG} \
                     --name app-demo

                # Also load the 'latest' tag
                docker pull ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:latest
                docker tag ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:latest \
                           host.docker.internal:8082/${HARBOR_PROJECT}/${IMAGE_NAME}:latest
                kind load docker-image host.docker.internal:8082/${HARBOR_PROJECT}/${IMAGE_NAME}:latest \
                     --name app-demo
            """
        }
    }
}
```

## Verification

Test that images are loaded and accessible:

```bash
# Create a test pod
kubectl run test --image=host.docker.internal:8082/cicd-demo/app:latest \
         --image-pull-policy=Never --restart=Never

# Check status (should be Running)
kubectl get pod test

# Clean up
kubectl delete pod test
```

## Deploy Application

```bash
# Deploy with Helm
helm upgrade --install cicd-demo ./helm-charts/cicd-demo

# Watch pods start
kubectl get pods -w
```

## Alternative Approaches (Not Recommended for Mac)

We tried these approaches, but they have issues on Mac Docker Desktop:

### ❌ Approach 1: Configure containerd for HTTP registry
- **Issue**: Containerd configuration is complex and error-prone
- **Issue**: Still requires authentication setup
- **Why not**: Unreliable, difficult to maintain

### ❌ Approach 2: Connect Docker networks
- **Issue**: Kind uses custom networking that doesn't bridge well
- **Issue**: Mac Docker Desktop has network limitations
- **Why not**: Doesn't work reliably on Mac

### ❌ Approach 3: imagePullSecrets with host.docker.internal
- **Issue**: Containerd still tries HTTPS despite HTTP configuration
- **Issue**: Complex TOML configuration required
- **Why not**: Hours of debugging, unreliable results

### ✅ Chosen Approach: Pre-load images
- **Advantage**: Simple, reliable, recommended by Kind
- **Advantage**: Works perfectly on Mac Docker Desktop
- **Advantage**: No network or authentication configuration needed
- **Trade-off**: Requires manual load step (automated in CI/CD)

## Best Practices

1. **Always use `imagePullPolicy: Never`** for Kind with local images
2. **Automate image loading** in your CI/CD pipeline
3. **Use `host.docker.internal:8082`** naming for consistency
4. **Load both versioned and 'latest' tags** for flexibility

## Troubleshooting

### Images not pulling?
```bash
# Check if image exists in Kind nodes
docker exec app-demo-worker crictl images | grep cicd-demo

# Reload image if missing
./scripts/load-harbor-image-to-kind.sh localhost:8082/cicd-demo/app:latest
```

### Pod stuck in ImagePullBackOff?
```bash
# Check pod events
kubectl describe pod <pod-name>

# If it says "image not found", the image wasn't loaded
# Solution: Run load script again
```

### Want to update to a new image version?
```bash
# Load new version
./scripts/load-harbor-image-to-kind.sh localhost:8082/cicd-demo/app:v2

# Update deployment
helm upgrade cicd-demo ./helm-charts/cicd-demo --set image.tag=v2
```

## References

- [Kind - Loading an Image Into Your Cluster](https://kind.sigs.k8s.io/docs/user/quick-start/#loading-an-image-into-your-cluster)
- [Mac Docker Desktop Networking](https://docs.docker.com/desktop/networking/#i-want-to-connect-from-a-container-to-a-service-on-the-host)
