# Quick Start: Harbor Images in Kind on Mac

## Problem
Kind pods show: `Back-off pulling image "localhost:8082/cicd-demo/app:latest"`

## Solution (3 Steps)

### 1. Load Image Script
```bash
./scripts/load-harbor-image-to-kind.sh localhost:8082/cicd-demo/app:latest
```

### 2. Helm Values (Already Configured)
```yaml
image:
  repository: host.docker.internal:8082/cicd-demo/app
  pullPolicy: Never
  tag: "latest"
```

### 3. Deploy
```bash
helm upgrade --install cicd-demo ./helm-charts/cicd-demo
kubectl get pods -w
```

## Automate in Jenkins

Add after "Push to Harbor" stage:

```groovy
stage('Load Image into Kind') {
    steps {
        script {
            sh """
                docker pull localhost:8082/cicd-demo/app:latest
                docker tag localhost:8082/cicd-demo/app:latest \
                           host.docker.internal:8082/cicd-demo/app:latest
                kind load docker-image host.docker.internal:8082/cicd-demo/app:latest \
                     --name app-demo
            """
        }
    }
}
```

## Files Modified
- ✅ `helm-charts/cicd-demo/values.yaml` - Set `pullPolicy: Never`
- ✅ `scripts/load-harbor-image-to-kind.sh` - Automation script
- ✅ `scripts/configure-kind-harbor-access.sh` - containerd config (not needed with pre-load approach)
- ✅ `scripts/fix-kind-harbor-registry.sh` - Alternative fix (not needed)

## Documentation
See `docs/Harbor-Kind-Integration.md` for complete explanation and alternatives.

## Verification
```bash
# Check images in Kind nodes
docker exec app-demo-worker crictl images | grep cicd-demo

# Expected output:
# host.docker.internal:8082/cicd-demo/app    latest    55ff886c472fb    123MB
```

## Why Not Direct Pull from Harbor?

On Mac Docker Desktop:
- ❌ Harbor and Kind are on separate Docker networks
- ❌ `localhost` inside Kind != Mac host
- ❌ containerd HTTP config is unreliable
- ✅ Image pre-loading is simple and works perfectly
