# AWS EKS Guide

## Introduction
Amazon Elastic Kubernetes Service (EKS) is a managed Kubernetes service that makes it easy to run Kubernetes on AWS without needing to install and operate your own Kubernetes control plane.

## Key Features
- Fully managed Kubernetes control plane
- High availability across multiple availability zones
- Automated version upgrades and patching
- Integration with AWS services (IAM, VPC, ELB, ECR)
- Support for EC2 and Fargate compute options
- Built-in security and compliance
- Seamless scaling capabilities

## Prerequisites
- AWS account with appropriate permissions
- AWS CLI installed and configured
- kubectl installed
- eksctl installed (recommended for easier cluster creation)
- Basic understanding of Kubernetes and AWS concepts

## Installation

### Install Required Tools
```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /

# Install eksctl
brew tap weaveworks/tap
brew install weaveworks/tap/eksctl

# Install kubectl
brew install kubectl
```

## Basic Usage

### Create EKS Cluster
Using eksctl (recommended):
```bash
eksctl create cluster \
  --name my-cluster \
  --region us-west-2 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 1 \
  --nodes-max 4 \
  --managed
```

Using AWS CLI:
```bash
aws eks create-cluster \
  --name my-cluster \
  --role-arn arn:aws:iam::123456789012:role/eks-service-role \
  --resources-vpc-config subnetIds=subnet-12345678,subnet-87654321,securityGroupIds=sg-12345678
```

### Configure kubectl
```bash
aws eks update-kubeconfig --name my-cluster --region us-west-2
```

### Verify Cluster
```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

### Create Node Group
```bash
eksctl create nodegroup \
  --cluster my-cluster \
  --name my-nodegroup \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 1 \
  --nodes-max 4 \
  --managed
```

## Advanced Features

### Fargate Profile
```bash
eksctl create fargateprofile \
  --cluster my-cluster \
  --name my-fargate-profile \
  --namespace my-namespace
```

### IAM Roles for Service Accounts (IRSA)
```bash
eksctl create iamserviceaccount \
  --name my-service-account \
  --namespace my-namespace \
  --cluster my-cluster \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess \
  --approve
```

### Cluster Autoscaler
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
```

## Integration with Other Tools

### Docker Integration
- Build Docker images locally
- Push images to Amazon ECR
- Deploy containerized applications to EKS

### Harbor Integration
- Configure Harbor as private registry
- Set up imagePullSecrets for EKS
- Implement image scanning before deployment

### Jenkins Integration
- Use Jenkins for CI/CD pipelines to EKS
- Configure AWS credentials in Jenkins
- Deploy applications using kubectl or Helm

### ArgoCD Integration
- Install ArgoCD on EKS cluster
- Configure ArgoCD to manage EKS applications
- Implement GitOps workflows

### Helm Integration
- Install Tiller (Helm 2) or use Helm 3
- Deploy applications using Helm charts
- Manage releases across environments

## Best Practices
1. Use managed node groups for easier maintenance
2. Implement pod security policies
3. Enable cluster logging and monitoring
4. Use IAM roles for service accounts instead of instance profiles
5. Configure network policies for pod-to-pod communication
6. Use multiple node groups for different workload types
7. Implement backup and disaster recovery strategies
8. Use AWS Load Balancer Controller for ingress
9. Enable encryption for secrets at rest
10. Regularly update cluster and node versions

## Security Considerations
- Enable envelope encryption for Kubernetes secrets
- Use private endpoints for API server access
- Implement network policies
- Use AWS Security Groups for pod-level security
- Enable audit logging
- Implement least privilege IAM policies
- Use Pod Security Standards
- Scan container images for vulnerabilities

## Cost Optimization
- Use Spot instances for non-critical workloads
- Right-size node types based on workload requirements
- Implement cluster autoscaler
- Use Fargate for variable workloads
- Monitor and optimize resource requests/limits
- Delete unused resources and clusters

## Troubleshooting

### Nodes not joining cluster
- Verify IAM role permissions
- Check VPC and subnet configuration
- Review security group rules
- Verify AMI compatibility

### Pods failing to start
- Check node resources (CPU, memory)
- Verify image pull secrets
- Review pod logs: `kubectl logs <pod-name>`
- Check events: `kubectl describe pod <pod-name>`

### Cannot access cluster
- Verify AWS credentials
- Update kubeconfig: `aws eks update-kubeconfig --name my-cluster`
- Check IAM permissions for EKS access
- Verify cluster endpoint accessibility

## Monitoring and Logging

### Enable Control Plane Logging
```bash
aws eks update-cluster-config \
  --name my-cluster \
  --logging '{"clusterLogging":[{"types":["api","audit","authenticator","controllerManager","scheduler"],"enabled":true}]}'
```

### Deploy Metrics Server
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### CloudWatch Container Insights
```bash
eksctl create addon \
  --name amazon-cloudwatch-observability \
  --cluster my-cluster
```

## Cleanup
```bash
# Delete node groups
eksctl delete nodegroup --cluster=my-cluster --name=my-nodegroup

# Delete cluster
eksctl delete cluster --name my-cluster
```

## References
- Official Documentation: https://docs.aws.amazon.com/eks/
- eksctl Documentation: https://eksctl.io/
- AWS EKS Best Practices Guide: https://aws.github.io/aws-eks-best-practices/
- Kubernetes Documentation: https://kubernetes.io/docs/
