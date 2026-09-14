# ADR-001: Retag-and-Promote Deployment Strategy

## Status

Accepted

## Context

In a CI/CD pipeline with multiple environments (QA, Production), we need a strategy for promoting container images between environments. The traditional approach rebuilds images for each environment, but this introduces risk.

When an image is rebuilt, even with the same source code, the resulting artifact can differ due to:
- Base image updates between builds
- Non-deterministic package resolution
- Build timestamp differences
- Different build environments

This leads to the classic "works in QA, fails in production" scenario.

## Decision

We will use a **retag-and-promote** strategy where:

1. Build the container image **once** in the CI pipeline
2. Push the image to ECR with a QA tag (e.g., `v1.2.3-qa`)
3. Deploy to QA environment and run integration tests
4. If tests pass, retag the **same image** to production (e.g., `v1.2.3-prod`)
5. Deploy the retagged image to production

```
Build → Push (QA tag) → Deploy QA → Test → Retag (Prod) → Deploy Prod
```

The image digest remains identical between environments.

## Consequences

### Positive

- **Guaranteed consistency**: The exact artifact tested in QA reaches production
- **Faster deployments**: No rebuild time for production promotion
- **Reduced risk**: Eliminates environment-specific build variations
- **Audit trail**: Image tags clearly show promotion history
- **Cost savings**: Fewer build minutes consumed

### Negative

- **Environment-specific config**: Must be injected at runtime (not build time)
- **Requires externalized configuration**: ConfigMaps, Secrets, environment variables
- **Rollback complexity**: Must retag previous image version

## Implementation

```bash
# Promote image from QA to production
docker tag $ECR_REPO:v1.2.3-qa $ECR_REPO:v1.2.3-prod
docker push $ECR_REPO:v1.2.3-prod
```

Or using ECR batch operations:
```bash
aws ecr batch-get-image --repository-name app --image-ids imageTag=v1.2.3-qa \
  | jq '.images[0].imageManifest' \
  | aws ecr put-image --repository-name app --image-tag v1.2.3-prod --image-manifest file:///dev/stdin
```

## References

- [Docker Image Promotion Best Practices](https://docs.docker.com/scout/policy/promotion/)
- [AWS ECR Image Tagging](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-tagging.html)
- [GitLab Image Retagging](https://docs.gitlab.com/ee/user/packages/container_registry/)

