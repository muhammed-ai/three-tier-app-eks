# Monitoring Stack

This directory contains the observability configuration for the three-tier application.

## Components

### Prometheus
- **Purpose**: Metrics collection and alerting
- **Port**: 9090
- **Retention**: 15 days
- **Scrape Interval**: 15 seconds

### Grafana
- **Purpose**: Visualization and dashboards
- **Port**: 3000
- **Default Credentials**: admin / admin123 (change in production!)

### CloudWatch
- **Purpose**: AWS-native monitoring and dashboards
- **Integration**: Container Insights for EKS

## Deployment

### Deploy Prometheus and Grafana to EKS

```bash
# Create monitoring namespace
kubectl apply -f monitoring/prometheus/prometheus.yaml

# Deploy Grafana
kubectl apply -f monitoring/grafana/grafana.yaml

# Deploy alerting rules
kubectl apply -f monitoring/prometheus/rules.yaml
```

### Deploy CloudWatch Dashboard

```bash
# Create CloudWatch dashboard using AWS CLI
aws cloudwatch put-dashboard \
  --dashboard-name "Three-Tier-App" \
  --dashboard-body file://monitoring/cloudwatch/cloudwatch-dashboard.json
```

## Dashboards

### Pre-built Dashboards

1. **Three-Tier App Dashboard** (`app-dashboard.json`)
   - Request latency (p99)
   - Error rate
   - Requests per second
   - CPU usage
   - Memory usage

2. **CloudWatch Dashboard**
   - EKS cluster metrics
   - Pod CPU/memory utilization
   - ALB metrics
   - RDS MySQL metrics
   - Application error logs

## Metrics Exposed

### Application Metrics (Server)
| Metric | Type | Description |
|--------|------|-------------|
| `http_requests_total` | Counter | Total HTTP requests |
| `http_request_duration_seconds` | Histogram | Request latency |
| `http_requests_in_flight` | Gauge | Active requests |
| `db_connections_active` | Gauge | Active DB connections |
| `db_connections_idle` | Gauge | Idle DB connections |

### Kubernetes Metrics
| Metric | Type | Description |
|--------|------|-------------|
| `kube_pod_status_phase` | Gauge | Pod status |
| `kube_pod_container_status_restarts_total` | Counter | Container restarts |
| `container_cpu_usage_seconds_total` | Counter | CPU usage |
| `container_memory_usage_bytes` | Gauge | Memory usage |

## Alerts

### Critical Alerts
- `ApplicationDown`: Application not responding
- `HighErrorRate`: Error rate > 5%
- `PodCrashLooping`: Pod restarting frequently
- `DatabaseConnectionPoolExhausted`: DB connections > 90%

### Warning Alerts
- `HighLatency`: P99 latency > 1s
- `HighCPUUsage`: CPU > 80%
- `HighMemoryUsage`: Memory > 90%

## Accessing Dashboards

### Port Forward (Local Access)

```bash
# Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

### Via Ingress (Production)

Configure Ingress resources for external access with proper authentication.

## Custom Metrics

To add custom metrics to the server:

```javascript
// In src/server/src/index.js
const client = require('prom-client');

// Create a Registry
const register = new client.Registry();

// Create custom metrics
const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10],
  registers: [register]
});

// Expose metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});
```

## Cost Considerations

| Resource | Estimated Monthly Cost |
|----------|----------------------|
| Prometheus (1 pod) | $15 |
| Grafana (1 pod) | $5 |
| CloudWatch Logs (10GB) | $5 |
| CloudWatch Metrics (custom) | $10 |
| **Total** | **~$35/month** |

## Best Practices

1. **Set appropriate retention**: Prometheus retention based on compliance needs
2. **Use labels effectively**: Consistent labeling for querying
3. **Configure alerts properly**: Avoid alert fatigue
4. **Monitor the monitors**: Health checks for Prometheus/Grafana
5. **Secure access**: Use authentication for dashboards in production
