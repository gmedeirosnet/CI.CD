# Kyverno Policy Engine for Kind CI/CD Lab

A comprehensive policy-as-code implementation for Kubernetes using Kyverno, integrated into the CI/CD learning laboratory.

## Overview

Kyverno is a Kubernetes-native policy engine that validates, mutates, and generates configurations using policies written in YAML. This implementation provides:

- **Image Registry Enforcement**: Ensures all images come from Harbor registry
- **Resource Management**: Mandates CPU and memory limits on all pods
- **Security Controls**: Blocks privileged containers, enforces non-root users
- **Label Management**: Auto-injects standard labels for tracking and monitoring
- **Namespace Governance**: Enforces naming conventions and required labels

## Quick Start

### 1. Install Kyverno

```bash
cd /Users/gutembergmedeiros/Labs/CI.CD/k8s/kyverno
./install/setup-kyverno.sh
```

This installs Kyverno via Helm with Kind-optimized settings.

### 2. Deploy Policies

```bash
# Deploy all policies in Audit mode
kubectl apply -f policies/ -R

# Verify policies are installed
kubectl get clusterpolicies
```

### 3. Test Policies

```bash
# Run test suite
./tests/run-tests.sh

# View policy violations
./monitoring/view-violations.sh
```

### 4. Monitor Violations

```bash
# View policy reports
kubectl get clusterpolicyreport -A
kubectl get policyreport -n app-demo

# Detailed report
kubectl describe policyreport -n app-demo
```

## Directory Structure

```
k8s/kyverno/
├── README.md                           # This file
├── plan-kyvernoImplementation.prompt.md # Implementation plan
│
├── install/                            # Installation files
│   ├── kyverno-values.yaml            # Helm values for Kind
│   └── setup-kyverno.sh               # Installation script
│
├── policies/                           # Policy definitions
│   ├── 00-namespace/                  # Namespace policies
│   │   └── namespace-requirements.yaml
│   ├── 10-security/                   # Security policies
│   │   ├── disallow-privileged.yaml
│   │   ├── require-non-root.yaml
│   │   └── require-ro-rootfs.yaml
│   ├── 20-resources/                  # Resource policies
│   │   └── require-resource-limits.yaml
│   ├── 30-registry/                   # Registry policies
│   │   └── harbor-only-images.yaml
│   └── 40-labels/                     # Label mutation policies
│       └── add-default-labels.yaml
│
├── tests/                              # Testing suite
│   ├── valid/                         # Compliant manifests
│   │   ├── compliant-pod.yaml
│   │   └── compliant-deployment.yaml
│   ├── invalid/                       # Non-compliant manifests
│   │   ├── wrong-registry.yaml
│   │   ├── no-resource-limits.yaml
│   │   ├── privileged-pod.yaml
│   │   └── runs-as-root.yaml
│   └── run-tests.sh                   # Test runner
│
└── monitoring/                         # Monitoring tools
    ├── view-violations.sh             # Violations report script
    └── prometheus-servicemonitor.yaml # Prometheus integration
```

## Policies

All policies are deployed in **Audit mode** by default. This means:
- Violations are **logged** but not **blocked**
- Resources can still be deployed even if non-compliant
- Policy reports track violations for review

### Policy Categories

#### 1. Namespace Policies (`00-namespace/`)

**namespace-requirements.yaml**
- Requires `team` and `purpose` labels on all namespaces
- Helps with organization and resource tracking
- Excludes system namespaces

#### 2. Security Policies (`10-security/`)

**disallow-privileged.yaml**
- Blocks containers with `privileged: true`
- Prevents access to all Linux capabilities
- Critical for multi-tenant security

**require-non-root.yaml**
- Enforces `runAsNonRoot: true`
- Reduces attack surface
- Requires containers to run as non-root user

**require-ro-rootfs.yaml**
- Requires `readOnlyRootFilesystem: true`
- Prevents malicious file writes
- Applications needing write access should use volumes

#### 3. Resource Policies (`20-resources/`)

**require-resource-limits.yaml**
- Mandates CPU and memory requests/limits
- Prevents resource exhaustion
- Ensures fair resource allocation

Example:
```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```

#### 4. Registry Policies (`30-registry/`)

**harbor-only-images.yaml**
- Enforces Harbor registry usage
- Ensures all images are scanned and approved
- Pattern: `host.docker.internal:8082/cicd-demo/*`

#### 5. Label Policies (`40-labels/`)

**add-default-labels.yaml**
- Auto-injects standard labels
- Applied to Deployments, StatefulSets, DaemonSets
- Labels added:
  - `managed-by: kyverno`
  - `environment: cicd-lab`
  - `cluster: kind-cicd-demo`

## Usage Examples

### Test a Pod Manifest

```bash
# Dry-run to test against policies
kubectl apply -f your-pod.yaml --dry-run=server
```

### Deploy Compliant Application

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
  namespace: app-demo
spec:
  containers:
  - name: app
    image: host.docker.internal:8082/cicd-demo/app:latest
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "500m"
        memory: "512Mi"
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
```

### View Policy Violations

```bash
# Cluster-wide violations
kubectl get clusterpolicyreport -A

# Namespace-specific violations
kubectl get policyreport -n app-demo

# Detailed report
kubectl describe policyreport -n app-demo

# JSON output for automation
kubectl get policyreport -n app-demo -o json | \
  jq '.results[] | select(.result=="fail")'
```

### Check Kyverno Status

```bash
# Check Kyverno pods
kubectl get pods -n kyverno

# View Kyverno logs
kubectl logs -n kyverno -l app.kubernetes.io/name=kyverno -f

# Check webhook configurations
kubectl get validatingwebhookconfigurations | grep kyverno
kubectl get mutatingwebhookconfigurations | grep kyverno
```

## Integration with CI/CD

### Jenkins Pipeline

Add policy validation to your Jenkinsfile:

```groovy
stage('Validate Kubernetes Policies') {
    steps {
        script {
            sh """
                # Generate manifests from Helm chart
                helm template cicd-demo ./helm-charts/cicd-demo \
                  --set image.tag=${BUILD_NUMBER} \
                  > /tmp/manifests.yaml

                # Validate against Kyverno policies
                kubectl apply -f /tmp/manifests.yaml \
                  --dry-run=server \
                  --namespace=app-demo
            """
        }
    }
}
```

### ArgoCD Integration

Deploy the ArgoCD application to manage policies via GitOps:

```bash
kubectl apply -f /Users/gutembergmedeiros/Labs/CI.CD/argocd-apps/kyverno-policies.yaml
```

This enables:
- Version-controlled policies
- Automated policy deployment
- Policy drift detection
- Rollback capabilities

### Prometheus Monitoring

Add Kyverno metrics to Prometheus:

```bash
# Apply ServiceMonitor
kubectl apply -f monitoring/prometheus-servicemonitor.yaml

# Port-forward to view metrics
kubectl port-forward -n kyverno svc/kyverno-svc-metrics 8000:8000
curl http://localhost:8000/metrics
```

Key metrics:
- `kyverno_policy_rule_results_total`: Policy evaluation results
- `kyverno_admission_requests_total`: Total admission requests
- `kyverno_admission_review_duration_seconds`: Request processing time

## Switching to Enforce Mode

After monitoring violations for 2-3 days:

1. **Review all violations**
   ```bash
   ./monitoring/view-violations.sh
   ```

2. **Fix non-compliant resources**
   Update manifests to meet policy requirements

3. **Update policy mode**
   ```bash
   # Edit policy file
   vim policies/30-registry/harbor-only-images.yaml

   # Change:
   spec:
     validationFailureAction: Audit

   # To:
   spec:
     validationFailureAction: Enforce

   # Apply changes
   kubectl apply -f policies/30-registry/harbor-only-images.yaml
   ```

4. **Test in Enforce mode**
   ```bash
   # This should now be blocked
   kubectl apply -f tests/invalid/wrong-registry.yaml --dry-run=server
   ```

## Troubleshooting

### Policy Not Applied

```bash
# Check policy status
kubectl get clusterpolicy <policy-name> -o yaml

# View policy events
kubectl get events -n kyverno --sort-by='.lastTimestamp'
```

### Webhook Errors

```bash
# Check webhook configuration
kubectl get validatingwebhookconfigurations -o yaml | grep kyverno

# Restart Kyverno
kubectl rollout restart deployment/kyverno -n kyverno
```

### False Positives

If a resource is incorrectly flagged:

1. Check policy pattern matching
2. Add resource to exclusion list
3. Refine policy conditions

Example exclusion:
```yaml
spec:
  rules:
  - exclude:
      any:
      - resources:
          names:
          - "debug-*"  # Exclude debug pods
```

## Best Practices

1. **Start with Audit Mode**
   - Monitor violations for 2-3 days
   - Identify and fix non-compliant resources
   - Switch to Enforce mode gradually

2. **Test Policies Thoroughly**
   - Use dry-run mode: `kubectl apply --dry-run=server`
   - Run test suite regularly
   - Test both valid and invalid manifests

3. **Exclude System Namespaces**
   - Always exclude `kube-system`, `kube-public`
   - Exclude monitoring and logging namespaces
   - Be careful with ArgoCD namespace

4. **Document Policies**
   - Use annotations for policy metadata
   - Include clear violation messages
   - Provide examples in messages

5. **Monitor Continuously**
   - Check policy reports daily
   - Set up alerts for violations
   - Review and update policies regularly

## Resources

- **Kyverno Documentation**: https://kyverno.io/docs/
- **Policy Library**: https://kyverno.io/policies/
- **GitHub**: https://github.com/kyverno/kyverno
- **Slack Community**: https://kubernetes.slack.com (#kyverno)

## Related Documentation

- [Kind Kubernetes Guide](../../docs/Kind-K8s.md)
- [Harbor Registry Guide](../../docs/Harbor.md)
- [ArgoCD Guide](../../docs/ArgoCD.md)
- [Helm Charts Guide](../../docs/Helm-Charts.md)

## Support

For issues or questions:
1. Check policy reports: `./monitoring/view-violations.sh`
2. Review Kyverno logs: `kubectl logs -n kyverno -l app.kubernetes.io/name=kyverno`
3. Run test suite: `./tests/run-tests.sh`
4. Consult Kyverno documentation: https://kyverno.io/docs/
