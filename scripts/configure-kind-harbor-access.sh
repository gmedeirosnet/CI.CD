#!/usr/bin/env bash
# configure-kind-harbor-access.sh
# Configures Kind cluster nodes to access Harbor registry on Mac Docker Desktop
# This script configures containerd in Kind nodes to use host.docker.internal:8082

set -euo pipefail

CLUSTER_NAME="${1:-cicd-demo-cluster}"
HARBOR_HOST="host.docker.internal:8082"

echo "🔧 Configuring Kind cluster '${CLUSTER_NAME}' to access Harbor at ${HARBOR_HOST}"
echo

# Get all Kind nodes
NODES=$(kind get nodes --name "${CLUSTER_NAME}" 2>/dev/null || true)

if [ -z "$NODES" ]; then
  echo "❌ Error: Kind cluster '${CLUSTER_NAME}' not found."
  echo "Available clusters:"
  kind get clusters
  exit 1
fi

echo "📋 Found nodes:"
echo "$NODES"
echo

# Configure each node
for NODE in $NODES; do
  echo "⚙️  Configuring node: ${NODE}"

  # Backup existing config
  docker exec "${NODE}" sh -c "
    if [ -f /etc/containerd/config.toml ]; then
      cp /etc/containerd/config.toml /etc/containerd/config.toml.backup-\$(date +%Y%m%d-%H%M%S) 2>/dev/null || true
    fi
  "

  # Generate new config and add Harbor registry configuration
  echo "   Generating fresh containerd config with Harbor registry..."
  docker exec "${NODE}" sh -c "
    # Generate default config
    containerd config default > /tmp/config-new.toml

    # Add Harbor registry config at the end
    cat >> /tmp/config-new.toml << 'EOF'

# Harbor Registry Configuration
[plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"${HARBOR_HOST}\"]
  endpoint = [\"http://${HARBOR_HOST}\"]

[plugins.\"io.containerd.grpc.v1.cri\".registry.configs.\"${HARBOR_HOST}\"]
  [plugins.\"io.containerd.grpc.v1.cri\".registry.configs.\"${HARBOR_HOST}\".tls]
    insecure_skip_verify = true
  [plugins.\"io.containerd.grpc.v1.cri\".registry.configs.\"${HARBOR_HOST}\".transport]
    plain_http = true
EOF

    # Replace the active config
    mv /tmp/config-new.toml /etc/containerd/config.toml
  "

  # Restart containerd by restarting the entire node container
  echo "   Restarting containerd..."
  docker restart "${NODE}" >/dev/null 2>&1

  echo "   Waiting for node to be ready..."
  sleep 5

  # Wait for node to be Ready in Kubernetes
  timeout=60
  elapsed=0
  while [ $elapsed -lt $timeout ]; do
    if kubectl get node "${NODE}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"; then
      echo "   ✅ Node is ready"
      break
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done

  # Test connectivity to Harbor
  echo "   Testing connectivity to Harbor..."
  if docker exec "${NODE}" sh -c "curl -s -o /dev/null -w '%{http_code}' 'http://${HARBOR_HOST}/api/v2.0/systeminfo' 2>/dev/null" | grep -q "200\|401"; then
    echo "   ✅ Harbor is reachable from node"
  else
    echo "   ⚠️  Warning: Could not verify Harbor connectivity"
  fi

  echo
done

echo "✅ Configuration complete!"
echo
echo "📝 Next steps:"
echo "1. Verify all nodes are ready:"
echo "   kubectl get nodes"
echo
echo "2. Update your Helm values to use: ${HARBOR_HOST}/cicd-demo/app:latest"
echo "   (Already updated in helm-charts/cicd-demo/values.yaml)"
echo
echo "3. Deploy or update your application:"
echo "   helm upgrade --install cicd-demo ./helm-charts/cicd-demo"
echo
echo "4. Verify pods can pull images:"
echo "   kubectl get pods -w"
echo
echo "🔍 Troubleshooting:"
echo "- Check node config: docker exec ${CLUSTER_NAME}-control-plane cat /etc/containerd/config.toml | grep -A 10 'host.docker'"
echo "- Test image pull: kubectl run test --image=${HARBOR_HOST}/cicd-demo/app:latest --rm -it --restart=Never"
echo "- Check pod events: kubectl describe pod <pod-name>"
