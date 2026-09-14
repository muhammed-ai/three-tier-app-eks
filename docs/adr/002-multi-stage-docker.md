# ADR-002: Multi-stage Docker Builds

## Status

Accepted

## Context

Container image size directly impacts:
- Build and push times in CI/CD
- Pull times during deployment
- Storage costs in container registry
- Attack surface area for security

Node.js applications typically require build tools (npm, compilers, bundlers) that aren't needed at runtime. Including these in production images unnecessarily increases size and security risk.

## Decision

We will use **multi-stage Docker builds** for both frontend and backend services:

### Backend (Express.js)

```dockerfile
# Build stage
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .

# Production stage
FROM node:20-alpine
WORKDIR /app
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/src ./src
COPY --from=builder --chown=nodejs:nodejs /app/package.json ./
USER nodejs
EXPOSE 5000
CMD ["node", "src/index.js"]
```

### Frontend (React + Vite)

```dockerfile
# Build stage
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Production stage with Nginx
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

## Consequences

### Positive

- **Smaller images**: Backend ~100MB vs ~500MB, Frontend ~25MB vs ~200MB
- **Faster builds**: Smaller layers to push/pull
- **Better security**: No build tools in production image
- **Non-root execution**: Runs as unprivileged user
- **Immutable artifacts**: Production image contains only what's needed

### Negative

- **Complex Dockerfile**: Slightly more complex build instructions
- **Build caching**: Requires careful layer ordering for optimal cache usage

## Image Size Comparison

| Image | Single-stage | Multi-stage | Reduction |
|-------|-------------|-------------|-----------|
| Backend | ~500 MB | ~110 MB | 78% |
| Frontend | ~350 MB | ~25 MB | 93% |

## Best Practices Applied

1. **Use specific versions**: `node:20-alpine` not `node:alpine`
2. **Order layers by change frequency**: package.json first, source code last
3. **Run as non-root**: Create and use dedicated user
4. **Use Alpine**: Smaller base images for production
5. **Copy only necessary files**: Exclude tests, docs, dev dependencies

## References

- [Docker Multi-stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [Best Practices for Node.js Docker Images](https://nodejs.org/en/docs/guides/nodejs-docker-webapp/)
- [Nginx with Docker](https://www.docker.com/blog/tips-for-deploying-nginx-official-image-with-docker/)

