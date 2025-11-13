# Plan: Implement Kyverno Policy Engine on Kind Kubernetes

This plan will integrate Kyverno as a policy engine into your CI/CD learning lab running on Kind, providing policy-based governance for image registries, resource management, security, and compliance. Kyverno will enforce Harbor-only image usage, require resource limits, block insecure configurations, and auto-inject standard labels while integrating with your existing ArgoCD, Jenkins, and monitoring stack.

## Steps

1. **Install Kyverno via Helm** - Create `k8s/kyverno/install/setup-kyverno.sh` script and `kyverno-values.yaml` with Kind-optimized settings (single replica, reduced resources). Deploy to `kyverno` namespace following the pattern used in `k8s/grafana/setup-loki.sh` and `k8s/grafana/setup-prometheus.sh`.

2. **Deploy Core Policies in Audit Mode** - Create policy files in `k8s/kyverno/policies/` organized by category: `30-registry/harbor-only-images.yaml` (enforce Harbor registry), `20-resources/require-resource-limits.yaml` (mandate CPU/memory limits), `10-security/disallow-privileged.yaml` and `require-non-root.yaml` (security controls). Start with `validationFailureAction: Audit` to observe violations without blocking deployments.

3. **Create Testing Suite** - Build `k8s/kyverno/tests/run-tests.sh` with sample valid/invalid pod manifests in `tests/valid/` and `tests/invalid/` directories. Test policies using `kubectl apply --dry-run=server` to validate enforcement before switching to production mode.

4. **Add Mutation Policies** - Implement `k8s/kyverno/policies/40-labels/add-default-labels.yaml` to auto-inject labels (`managed-by: kyverno`, `environment: cicd-lab`, `cluster: kind-cicd-demo`) on `Deployment`, `StatefulSet`, and `DaemonSet` resources in the `app-demo` namespace.

5. **Integrate with CI/CD Pipeline** - Add policy validation stage to `Jenkinsfile` between "Build" and "Deploy" stages using `kubectl apply --dry-run=server` to validate Helm-generated manifests. Configure ArgoCD to manage Kyverno policies as GitOps by creating `argocd-apps/kyverno-policies.yaml` pointing to `k8s/kyverno/policies/`.

6. **Setup Monitoring and Reporting** - Add Kyverno metrics to `k8s/prometheus/prometheus-config.yaml` scrape targets. Create `k8s/kyverno/monitoring/view-violations.sh` helper script to query `PolicyReport` and `ClusterPolicyReport` resources. Document port forwarding for policy dashboard access in main README.

## Further Considerations

1. **Phased Enforcement Strategy** - Start all policies in Audit mode for 2-3 days to identify violations. Should Harbor registry policy be enforced first (Week 1) followed by resource limits (Week 2), or enforce all security policies simultaneously? Recommend prioritizing Harbor enforcement to align with your existing registry infrastructure.

2. **Namespace Exclusions** - Current plan excludes `kube-system`, `kyverno`, `argocd`, `monitoring`, and `logging` namespaces. Should `default` namespace also be excluded, or should it have stricter policies as a production-like environment?

3. **Read-Only Root Filesystem Policy** - The `require-ro-rootfs.yaml` policy may break some applications that write to the container filesystem. Should this policy start in Audit mode indefinitely, or should it only apply to specific namespaces after compatibility testing with your Java Spring Boot application in `src/`?
