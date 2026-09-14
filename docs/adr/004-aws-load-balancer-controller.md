# ADR-004: AWS Load Balancer Controller

## Status

Accepted

## Context

Kubernetes services of type `LoadBalancer` need a cloud provider to provision external load balancers. On AWS, we have two options:

1. **In-tree AWS Cloud Provider**: Built into Kubernetes, deprecated and frozen
2. **AWS Load Balancer Controller**: AWS-maintained, actively developed, feature-rich

We need to expose our application to external traffic with proper TLS termination, health checks, and integration with AWS services.

## Decision

We will use the **AWS Load Balancer Controller** (LBC) for all ingress and load balancer management.

## Features

The AWS Load Balancer Controller provides:

| Feature | In-tree Provider | AWS LBC |
|---------|-----------------|---------|
| Application Load Balancer (ALB) | ✓ | ✓ |
| Network Load Balancer (NLB) | ✓ | ✓ |
| Target Group Binding | ✗ | ✓ |
| IP mode for NLB | ✗ | ✓ |
| NLB with TLS | Limited | ✓ |
| ALB with TLS (ACM) | ✓ | ✓ |
| Multiple listeners | ✗ | ✓ |
| Weighted Target Groups | ✗ | ✓ |
| Graceful shutdown | ✗ | ✓ |

## Architecture

```
Internet
    │
    ▼
┌─────────────────────────────────┐
│  Application Load Balancer (ALB) │
│  - TLS termination (ACM)         │
│  - WAF integration               │
│  - Health checks                 │
└─────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────┐
│  Kubernetes Ingress              │
│  (managed by AWS LBC)            │
└─────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────┐
│  Service (ClusterIP)             │
│  + TargetGroupBinding            │
└─────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────┐
│  Pods                            │
│  (registered by IP)              │
└─────────────────────────────────┘
```

## Implementation

### IAM Policy for Service Account (IRSA)

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/AWSLoadBalancerControllerIAMRole
```

### Ingress Resource

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: three-tier-app
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:region:account:certificate/id
    alb.ingress.kubernetes.io/healthcheck-path: /health
spec:
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: client
                port:
                  number: 80
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: server
                port:
                  number: 5000
```

## Consequences

### Positive

- **Active development**: AWS maintains and actively develops the controller
- **Rich features**: Support for ALB, NLB, IP targets, and advanced routing
- **Better integration**: Native AWS service integration (ACM, WAF, Shield)
- **IP target mode**: Pods registered directly, no NodePort required
- **Cost optimization**: Can share ALBs across multiple services
- **Graceful shutdown**: Proper connection draining during deployments

### Negative

- **External dependency**: Must install and maintain the controller
- **IAM setup**: Requires IAM roles for service accounts (IRSA)
- **Learning curve**: Team needs to learn annotation-based configuration

## Installation

```bash
# Add EKS Helm repository
helm repo add eks https://aws.github.io/eks-charts

# Install the controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=three-tier-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

## Best Practices

1. **Use IP target mode**: Eliminates NodePort requirement
2. **Enable WAF**: Protect applications with AWS WAF
3. **Use ACM for TLS**: Managed certificates
4. **Set resource requests**: Controller needs appropriate resources
5. **Configure health checks**: Proper health check paths for zero-downtime deploys

## References

- [AWS Load Balancer Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [EKS Best Practices for ALB](https://aws.github.io/aws-eks-best-practices/networking/loadbalancing/)
- [IAM Roles for Service Accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)

