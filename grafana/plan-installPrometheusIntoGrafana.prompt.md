## Plan: Install Prometheus and integrate with Grafana

Add Prometheus to the existing monitoring stack (Grafana + Loki) by deploying it into the Kind Kubernetes cluster and configuring Grafana to use it as a datasource. This follows the same deployment pattern used for Loki.

### Steps

1. **Create Prometheus deployment manifests** in [`k8s/prometheus/`](k8s/) with ConfigMap for scrape configs (Harbor, Jenkins, kube-state-metrics), Deployment with 10GB PVC for data persistence, Service with NodePort (30090), and RBAC for Kubernetes metrics scraping

2. **Create setup script** [`scripts/setup-prometheus.sh`](scripts/) following the pattern of [`setup-loki.sh`](scripts/setup-loki.sh) to create `monitoring` namespace, deploy Prometheus, verify readiness, and expose via NodePort

3. **Add Prometheus datasource config** [`grafana/provisioning/datasources/prometheus.yml`](grafana/provisioning/datasources/) with URL `http://host.docker.internal:30090` matching the Loki pattern in [`loki.yml`](grafana/provisioning/datasources/loki.yml)

4. **Deploy metric exporters** including kube-state-metrics and node-exporter into Kind cluster for comprehensive Kubernetes monitoring, and configure application metrics from the Spring Boot demo app (currently on port 9090)

5. **Update setup scripts** to modify [`setup-grafana-docker.sh`](scripts/setup-grafana-docker.sh) to verify Prometheus availability and update [`setup-all.sh`](scripts/setup-all.sh) to include Prometheus setup step

6. **Document the integration** by updating [`docs/Grafana-Loki.md`](docs/Grafana-Loki.md) with Prometheus sections and adding Prometheus references to [`docs/Port-Reference.md`](docs/Port-Reference.md) for ports 9090 and 30090

### Further Considerations

1. **Deployment location**: Deploy Prometheus in Kind cluster (recommended, matches Loki) or Docker Desktop alongside Grafana? Kind cluster provides better integration with K8s metrics.

2. **Scrape targets**: Start with basic targets (Kubernetes metrics, node-exporter) or immediately configure all available targets (Harbor, Jenkins, application)? Recommend starting basic, then expanding.

3. **Data retention**: Use default 15-day retention or customize based on storage constraints? Current pattern uses 10GB PVC for Loki.
