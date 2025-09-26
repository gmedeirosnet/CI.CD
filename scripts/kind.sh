#!/bin/bash
# 1. local registry
docker run -d -p 5000:5000 --restart=always --name registry registry:2

# 2. kind cluster that knows about the local registry
cat > kind-registry.yaml <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5000"]
    endpoint = ["http://localhost:5000"]
EOF
kind create cluster --name dev --config kind-registry.yaml

