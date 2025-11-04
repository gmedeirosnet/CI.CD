#!/usr/bin/env bash
# load-harbor-image-to-kind.sh
# Loads an image from Harbor into Kind cluster for Mac Docker Desktop
#
# Usage: ./load-harbor-image-to-kind.sh [IMAGE:TAG] [CLUSTER_NAME]
# Example: ./load-harbor-image-to-kind.sh localhost:8082/cicd-demo/app:latest app-demo

set -euo pipefail

# Default values
HARBOR_IMAGE="${1:-localhost:8082/cicd-demo/app:latest}"
CLUSTER_NAME="${2:-app-demo}"
KIND_IMAGE=$(echo "$HARBOR_IMAGE" | sed 's/localhost:8082/host.docker.internal:8082/g')

echo "🐳 Loading Harbor image into Kind cluster"
echo "   Harbor image: $HARBOR_IMAGE"
echo "   Kind image:   $KIND_IMAGE"
echo "   Cluster:      $CLUSTER_NAME"
echo

# Step 1: Pull from Harbor (if not already present)
echo "1️⃣  Pulling image from Harbor..."
if docker pull "$HARBOR_IMAGE"; then
  echo "   ✅ Image pulled successfully"
else
  echo "   ❌ Failed to pull image from Harbor"
  echo "   Make sure Harbor is running and the image exists"
  exit 1
fi

# Step 2: Tag for Kind (using host.docker.internal)
echo
echo "2️⃣  Tagging image for Kind..."
docker tag "$HARBOR_IMAGE" "$KIND_IMAGE"
echo "   ✅ Tagged as $KIND_IMAGE"

# Step 3: Load into Kind cluster
echo
echo "3️⃣  Loading image into Kind cluster nodes..."
if kind load docker-image "$KIND_IMAGE" --name "$CLUSTER_NAME"; then
  echo "   ✅ Image loaded into all Kind nodes"
else
  echo "   ❌ Failed to load image into Kind"
  echo "   Make sure Kind cluster '$CLUSTER_NAME' is running"
  exit 1
fi

echo
echo "✅ Success! Image is now available in Kind cluster"
echo
echo "📝 Next steps:"
echo "   1. Deploy with Helm (uses imagePullPolicy: Never):"
echo "      helm upgrade --install cicd-demo ./helm-charts/cicd-demo \\"
echo "        --set image.repository=host.docker.internal:8082/cicd-demo/app \\"
echo "        --set image.tag=latest"
echo
echo "   2. Or create a pod directly:"
echo "      kubectl run test --image=$KIND_IMAGE --image-pull-policy=Never"
echo
echo "💡 Tip: This process should be automated in your CI/CD pipeline after pushing to Harbor"
