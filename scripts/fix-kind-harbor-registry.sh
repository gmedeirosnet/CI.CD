#!/usr/bin/env bash
# fix-kind-harbor-registry.sh
# Simpler approach - patches the containerd config with proper format for containerd 1.6+

set -euo pipefail

CLUSTER_NAME="${1:-cicd-demo-cluster}"
REGISTRY="host.docker.internal:8082"

echo "🔧 Fixing containerd config for Harbor registry access..."
echo

for NODE in $(kind get nodes --name "${CLUSTER_NAME}"); do
  echo "📝 Configuring ${NODE}..."

  # Create a patch script inside the node
  docker exec "${NODE}" bash <<'NODESCRIPT'
# Backup
cp /etc/containerd/config.toml /etc/containerd/config.toml.bak-$(date +%s)

# Generate fresh default config
containerd config default > /tmp/config.toml

# Add registry configuration at the end
cat >> /tmp/config.toml <<'EOF'

# Harbor Registry Configuration for Mac Docker Desktop
[plugins."io.containerd.grpc.v1.cri".registry]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."host.docker.internal:8082"]
      endpoint = ["http://host.docker.internal:8082"]
  [plugins."io.containerd.grpc.v1.cri".registry.configs]
    [plugins."io.containerd.grpc.v1.cri".registry.configs."host.docker.internal:8082"]
      [plugins."io.containerd.grpc.v1.cri".registry.configs."host.docker.internal:8082".tls]
        insecure_skip_verify = true
      [plugins."io.containerd.grpc.v1.cri".registry.configs."host.docker.internal:8082".auth]
        username = ""
        password = ""
EOF

# Apply the new config
mv /tmp/config.toml /etc/containerd/config.toml
NODESCRIPT

  echo "   Restarting ${NODE}..."
  docker restart "${NODE}" >/dev/null
  sleep 3
done

echo "⏳ Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s

echo "✅ Done! Test with:"
echo "   kubectl run test --image=host.docker.internal:8082/cicd-demo/app:latest --restart=Never"
