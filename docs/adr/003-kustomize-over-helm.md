# ADR-003: Kubernetes Kustomize Over Helm

## Status

Accepted

## Context

We need a tool to manage Kubernetes manifests across multiple environments (QA, Production) with environment-specific configurations. The two main options are:

- **Helm**: Package manager with templating engine
- **Kustomize**: Template-free manifest customization

Both are supported natively by kubectl (`kubectl apply -f` with kustomize, `kubectl apply -k` for kustomize).

## Decision

We will use **Kustomize** for managing Kubernetes configurations.

## Rationale

### Why Not Helm?

1. **Templating complexity**: Helm charts use Go templates which are error-prone
2. **YAML-in-YAML**: Embedded YAML strings are hard to validate
3. **Release management overhead**: Helm tracks releases, adding operational complexity
4. **Learning curve**: Team members need to learn Helm's DSL

### Why Kustomize?

1. **Native kubectl support**: No additional tool installation required
2. **Pure YAML**: All manifests remain valid YAML
3. **Declarative patches**: Clear overlay structure for environment differences
4. **GitOps friendly**: Manifests can be validated without rendering
5. **Simpler mental model**: Base + Overlay pattern is intuitive

## Directory Structure

```
k8s/
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
├── qa/
│   ├── kustomization.yaml
│   ├── kustomization.yaml
│   └── patches/
│       └── deployment-replicas.yaml
└── prod/
    ├── kustomization.yaml
    └── patches/
        ├── deployment-replicas.yaml
        └── resource-limits.yaml
```

## Example

### Base `kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml

commonLabels:
  app.kubernetes.io/name: three-tier-app
  app.kubernetes.io/managed-by: kustomize
```

### QA Overlay `k8s/qa/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../base

namespace: qa

patchesStrategicMerge:
  - patches/deployment-replicas.yaml
```

### Production Overlay `k8s/prod/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../base

namespace: production

patchesStrategicMerge:
  - patches/deployment-replicas.yaml
  - patches/resource-limits.yaml
```

## Consequences

### Positive

- **No template debugging**: Pure YAML is easier to validate
- **kubectl native**: No separate CLI tool required
- **Clear separation**: Base manifests are clearly distinct from environment overlays
- **Diff-friendly**: Easy to see what changes between environments

### Negative

- **No packaging**: Can't create distributable "charts" like Helm
- **No release history**: Must rely on Git history for rollback context
- **Limited logic**: No conditionals or loops (though this can be a feature)

## When to Use Helm Instead

Consider Helm if you need:
- Distributable packages to share with other teams
- Complex conditional logic in manifests
- Release management with rollback capabilities
- Large ecosystem of pre-built charts

## References

- [Kustomize Documentation](https://kustomize.io/)
- [Helm vs Kustomize](https://argo-cd.readthedocs.io/en/stable/user-guide/kustomize/)
- [Kubernetes Native Configuration Management](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/)

