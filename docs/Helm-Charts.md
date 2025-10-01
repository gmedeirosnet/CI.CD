# Helm Charts Guide

## Introduction
Helm is a package manager for Kubernetes that helps you define, install, and upgrade complex Kubernetes applications. Charts are packages of pre-configured Kubernetes resources.

## Key Features
- Package management for Kubernetes
- Version control for deployments
- Templating engine for configuration
- Dependency management
- Rollback capabilities
- Release management
- Repository system for sharing charts
- Hooks for lifecycle management

## Prerequisites
- Kubernetes cluster (v1.19+)
- kubectl configured
- Basic understanding of Kubernetes concepts
- Familiarity with YAML syntax

## Installation

### On macOS
```bash
brew install helm
```

### On Linux
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### On Windows
```powershell
choco install kubernetes-helm
```

### Verify Installation
```bash
helm version
```

## Basic Concepts

### Chart
A Helm package containing:
- Chart.yaml: metadata about the chart
- values.yaml: default configuration values
- templates/: Kubernetes manifest templates
- charts/: dependent charts
- README.md: documentation

### Release
An instance of a chart running in a Kubernetes cluster.

### Repository
Location where charts are stored and shared.

### Values
Configuration parameters that customize chart installation.

## Basic Usage

### Working with Repositories
```bash
# Add repository
helm repo add stable https://charts.helm.sh/stable
helm repo add bitnami https://charts.bitnami.com/bitnami

# Update repositories
helm repo update

# List repositories
helm repo list

# Search for charts
helm search repo nginx

# Search Helm Hub
helm search hub wordpress

# Remove repository
helm repo remove stable
```

### Installing Charts
```bash
# Install chart
helm install myrelease bitnami/nginx

# Install with custom values
helm install myrelease bitnami/nginx --set service.type=LoadBalancer

# Install with values file
helm install myrelease bitnami/nginx -f custom-values.yaml

# Install in specific namespace
helm install myrelease bitnami/nginx -n production --create-namespace

# Dry run (test installation)
helm install myrelease bitnami/nginx --dry-run --debug

# Generate manifest without installation
helm template myrelease bitnami/nginx
```

### Managing Releases
```bash
# List releases
helm list

# List all releases (including failed)
helm list -a

# Get release status
helm status myrelease

# Get release values
helm get values myrelease

# Get release manifest
helm get manifest myrelease

# Get release notes
helm get notes myrelease

# Upgrade release
helm upgrade myrelease bitnami/nginx

# Upgrade with new values
helm upgrade myrelease bitnami/nginx --set replicaCount=3

# Rollback release
helm rollback myrelease 1

# Uninstall release
helm uninstall myrelease

# Uninstall but keep history
helm uninstall myrelease --keep-history
```

## Creating Custom Charts

### Create New Chart
```bash
# Create chart scaffolding
helm create mychart

# Chart structure
mychart/
├── Chart.yaml          # Chart metadata
├── values.yaml         # Default values
├── charts/             # Dependent charts
├── templates/          # Template files
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── _helpers.tpl    # Template helpers
│   ├── NOTES.txt       # Post-install notes
│   └── tests/          # Test files
└── .helmignore         # Files to ignore
```

### Chart.yaml Example
```yaml
apiVersion: v2
name: mychart
description: A Helm chart for my application
type: application
version: 1.0.0
appVersion: "1.0.0"
keywords:
  - myapp
  - web
home: https://github.com/example/mychart
sources:
  - https://github.com/example/myapp
maintainers:
  - name: John Doe
    email: john@example.com
dependencies:
  - name: postgresql
    version: "11.x"
    repository: https://charts.bitnami.com/bitnami
    condition: postgresql.enabled
```

### values.yaml Example
```yaml
# Default values for mychart
replicaCount: 2

image:
  repository: myapp
  pullPolicy: IfNotPresent
  tag: "1.0.0"

service:
  type: ClusterIP
  port: 80
  targetPort: 8080

ingress:
  enabled: false
  className: nginx
  annotations: {}
  hosts:
    - host: myapp.example.com
      paths:
        - path: /
          pathType: Prefix
  tls: []

resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80

postgresql:
  enabled: true
  auth:
    username: myapp
    password: changeme
    database: myappdb
```

### Template Example (deployment.yaml)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "mychart.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "mychart.selectorLabels" . | nindent 8 }}
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - name: http
          containerPort: {{ .Values.service.targetPort }}
          protocol: TCP
        resources:
          {{- toYaml .Values.resources | nindent 12 }}
        env:
        - name: DATABASE_HOST
          value: {{ include "mychart.fullname" . }}-postgresql
        - name: DATABASE_PORT
          value: "5432"
```

### Template Helpers (_helpers.tpl)
```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "mychart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "mychart.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mychart.labels" -}}
helm.sh/chart: {{ include "mychart.chart" . }}
{{ include "mychart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
```

## Advanced Features

### Chart Dependencies
```yaml
# Chart.yaml
dependencies:
  - name: postgresql
    version: "11.x"
    repository: https://charts.bitnami.com/bitnami
  - name: redis
    version: "17.x"
    repository: https://charts.bitnami.com/bitnami
    condition: redis.enabled
    tags:
      - cache
```

```bash
# Update dependencies
helm dependency update

# Build dependencies
helm dependency build

# List dependencies
helm dependency list
```

### Conditional Templates
```yaml
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "mychart.fullname" . }}
spec:
  # ... ingress spec
{{- end }}
```

### Loops in Templates
```yaml
{{- range .Values.env }}
- name: {{ .name }}
  value: {{ .value | quote }}
{{- end }}
```

### Template Functions
```yaml
# String manipulation
{{ .Values.name | upper }}
{{ .Values.name | lower }}
{{ .Values.name | quote }}
{{ .Values.name | default "default-value" }}

# Conditionals
{{ if eq .Values.environment "production" }}prod{{ else }}dev{{ end }}

# Indentation
{{- toYaml .Values.resources | nindent 12 }}
```

### Hooks
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "mychart.fullname" . }}-post-install
  annotations:
    "helm.sh/hook": post-install
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    spec:
      containers:
      - name: post-install
        image: busybox
        command: ['sh', '-c', 'echo Post-install hook']
      restartPolicy: Never
```

## Chart Testing
```bash
# Lint chart
helm lint mychart/

# Test chart templates
helm template myrelease mychart/

# Dry run installation
helm install myrelease mychart/ --dry-run --debug

# Run chart tests
helm test myrelease
```

## Packaging and Distribution

### Package Chart
```bash
# Package chart
helm package mychart/

# Package with version
helm package mychart/ --version 1.0.1

# Package with dependencies
helm package mychart/ --dependency-update
```

### Chart Repository

#### Create Repository
```bash
# Create index file
helm repo index .

# Update index after adding new charts
helm repo index . --merge index.yaml
```

#### Use GitHub Pages as Repository
```bash
# 1. Create gh-pages branch
git checkout --orphan gh-pages

# 2. Add charts
helm package mychart/
helm repo index .

# 3. Commit and push
git add .
git commit -m "Add chart repository"
git push origin gh-pages

# 4. Use repository
helm repo add myrepo https://username.github.io/repo-name/
```

## Integration with Other Tools

### ArgoCD Integration
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
spec:
  source:
    repoURL: https://charts.bitnami.com/bitnami
    chart: nginx
    targetRevision: 13.2.0
    helm:
      values: |
        replicaCount: 3
        service:
          type: LoadBalancer
```

### Jenkins Integration
```groovy
stage('Deploy with Helm') {
    steps {
        sh '''
            helm upgrade --install myrelease mychart/ \
              --set image.tag=${BUILD_NUMBER} \
              --namespace production
        '''
    }
}
```

### Harbor Integration
```bash
# Enable OCI support in Helm 3.8+
export HELM_EXPERIMENTAL_OCI=1

# Login to Harbor
helm registry login harbor.example.com

# Push chart to Harbor
helm chart save mychart/ harbor.example.com/myproject/mychart:1.0.0
helm chart push harbor.example.com/myproject/mychart:1.0.0

# Pull chart from Harbor
helm chart pull harbor.example.com/myproject/mychart:1.0.0
```

## Best Practices
1. Use semantic versioning for charts
2. Document all values in values.yaml with comments
3. Use _helpers.tpl for reusable templates
4. Implement proper RBAC in templates
5. Use named templates for common patterns
6. Test charts thoroughly before distribution
7. Keep charts modular and focused
8. Use dependencies instead of bundling
9. Implement proper resource limits
10. Version control your charts

## Common Use Cases

### Multi-Environment Deployment
```bash
# Development
helm install myapp mychart/ -f values-dev.yaml

# Staging
helm install myapp mychart/ -f values-staging.yaml

# Production
helm install myapp mychart/ -f values-prod.yaml
```

### Blue-Green Deployment
```bash
# Deploy blue version
helm install myapp-blue mychart/ --set color=blue

# Deploy green version
helm install myapp-green mychart/ --set color=green

# Switch traffic to green
kubectl patch service myapp -p '{"spec":{"selector":{"version":"green"}}}'
```

## Troubleshooting

### Chart installation fails
```bash
# Check chart syntax
helm lint mychart/

# Dry run with debug
helm install myrelease mychart/ --dry-run --debug

# Check generated manifests
helm template myrelease mychart/ > output.yaml
```

### Release upgrade issues
```bash
# Check release history
helm history myrelease

# Rollback to previous version
helm rollback myrelease

# Force upgrade
helm upgrade myrelease mychart/ --force
```

### Template rendering errors
```bash
# Debug template rendering
helm template myrelease mychart/ --debug

# Check specific template
helm template myrelease mychart/ --show-only templates/deployment.yaml
```

## References
- Official Documentation: https://helm.sh/docs/
- Chart Repository: https://artifacthub.io/
- GitHub: https://github.com/helm/helm
- Best Practices: https://helm.sh/docs/chart_best_practices/
