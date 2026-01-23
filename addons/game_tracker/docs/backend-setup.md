# GameTracker Backend Setup

This guide shows how to set up the LGTM stack (Loki, Grafana, Tempo, Mimir) with Grafana Alloy using Docker Compose.

## Architecture

```
Game (GameTracker)
        │
        ▼
   Grafana Alloy (collector)
        │
   ┌────┼────┬────────┐
   ▼    ▼    ▼        ▼
 Loki  Tempo Mimir  Grafana
(logs)(traces)(metrics)(UI)
```

## Quick Start

1. Create a directory for your backend:
```bash
mkdir game-tracker-backend
cd game-tracker-backend
```

2. Create the files below
3. Run `docker compose up -d`
4. Open Grafana at http://localhost:3000 (admin/admin)
5. Configure GameTracker with endpoint `http://localhost:4318`

## Files

### docker-compose.yml

```yaml
version: "3.8"

services:
  # Grafana Alloy - receives data from games
  alloy:
    image: grafana/alloy:latest
    ports:
      - "4318:4318"   # HTTP receiver (games send here)
      - "12345:12345" # Alloy UI
    volumes:
      - ./alloy-config.alloy:/etc/alloy/config.alloy
    command:
      - run
      - /etc/alloy/config.alloy
      - --server.http.listen-addr=0.0.0.0:12345
    depends_on:
      - loki
      - tempo
      - mimir

  # Loki - log storage
  loki:
    image: grafana/loki:latest
    ports:
      - "3100:3100"
    volumes:
      - ./loki-config.yaml:/etc/loki/local-config.yaml
      - loki-data:/loki
    command: -config.file=/etc/loki/local-config.yaml

  # Tempo - trace storage
  tempo:
    image: grafana/tempo:latest
    ports:
      - "3200:3200"   # Tempo API
      - "4317:4317"   # OTLP gRPC
    volumes:
      - ./tempo-config.yaml:/etc/tempo/tempo.yaml
      - tempo-data:/var/tempo
    command: -config.file=/etc/tempo/tempo.yaml

  # Mimir - metrics storage
  mimir:
    image: grafana/mimir:latest
    ports:
      - "9009:9009"
    volumes:
      - ./mimir-config.yaml:/etc/mimir/mimir.yaml
      - mimir-data:/data
    command: -config.file=/etc/mimir/mimir.yaml

  # Grafana - visualization
  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Admin
    volumes:
      - ./grafana-datasources.yaml:/etc/grafana/provisioning/datasources/datasources.yaml
      - grafana-data:/var/lib/grafana
    depends_on:
      - loki
      - tempo
      - mimir

volumes:
  loki-data:
  tempo-data:
  mimir-data:
  grafana-data:
```

### alloy-config.alloy

```hcl
// Receive logs from GameTracker (Loki push format)
loki.source.api "game_logs" {
  http {
    listen_address = "0.0.0.0"
    listen_port    = 4318
    conn_limit     = 100
  }
  forward_to = [loki.write.local.receiver]
}

// Write logs to Loki
loki.write "local" {
  endpoint {
    url = "http://loki:3100/loki/api/v1/push"
  }
}

// Receive metrics from GameTracker (Prometheus remote write)
prometheus.receive_http "game_metrics" {
  http {
    listen_address = "0.0.0.0"
    listen_port    = 4318
  }
  forward_to = [prometheus.remote_write.mimir.receiver]
}

// Write metrics to Mimir
prometheus.remote_write "mimir" {
  endpoint {
    url = "http://mimir:9009/api/v1/push"
  }
}

// Receive traces from GameTracker (OTLP HTTP)
otelcol.receiver.otlp "game_traces" {
  http {
    endpoint = "0.0.0.0:4318"
  }
  output {
    traces = [otelcol.exporter.otlp.tempo.input]
  }
}

// Write traces to Tempo
otelcol.exporter.otlp "tempo" {
  client {
    endpoint = "tempo:4317"
    tls {
      insecure = true
    }
  }
}
```

### loki-config.yaml

```yaml
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  instance_addr: 127.0.0.1
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

schema_config:
  configs:
    - from: 2020-10-24
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://localhost:9093

limits_config:
  reject_old_samples: false
  reject_old_samples_max_age: 168h
  ingestion_rate_mb: 16
  ingestion_burst_size_mb: 32
```

### tempo-config.yaml

```yaml
server:
  http_listen_port: 3200

distributor:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: "0.0.0.0:4317"
        http:
          endpoint: "0.0.0.0:4318"

ingester:
  max_block_duration: 5m

compactor:
  compaction:
    block_retention: 48h

storage:
  trace:
    backend: local
    wal:
      path: /var/tempo/wal
    local:
      path: /var/tempo/blocks

metrics_generator:
  registry:
    external_labels:
      source: tempo
  storage:
    path: /var/tempo/generator/wal
```

### mimir-config.yaml

```yaml
multitenancy_enabled: false

server:
  http_listen_port: 9009
  grpc_listen_port: 9095

ingester:
  ring:
    replication_factor: 1

blocks_storage:
  backend: filesystem
  filesystem:
    dir: /data/blocks
  bucket_store:
    sync_dir: /data/tsdb-sync

compactor:
  data_dir: /data/compactor
  sharding_ring:
    kvstore:
      store: memberlist

distributor:
  ring:
    kvstore:
      store: memberlist

store_gateway:
  sharding_ring:
    replication_factor: 1

limits:
  max_global_series_per_user: 0
  max_global_series_per_metric: 0
  ingestion_rate: 100000
  ingestion_burst_size: 1000000
```

### grafana-datasources.yaml

```yaml
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    isDefault: false
    jsonData:
      timeout: 60
      maxLines: 1000

  - name: Tempo
    type: tempo
    access: proxy
    url: http://tempo:3200
    isDefault: false

  - name: Mimir
    type: prometheus
    access: proxy
    url: http://mimir:9009/prometheus
    isDefault: true
```

## Usage

### Start the stack

```bash
docker compose up -d
```

### Check status

```bash
docker compose ps
docker compose logs -f alloy
```

### Access UIs

| Service | URL | Credentials |
|---------|-----|-------------|
| Grafana | http://localhost:3000 | admin / admin |
| Alloy | http://localhost:12345 | - |
| Loki | http://localhost:3100/ready | - |
| Tempo | http://localhost:3200/ready | - |
| Mimir | http://localhost:9009/ready | - |

### Stop the stack

```bash
docker compose down
```

### Reset all data

```bash
docker compose down -v
```

## Configure GameTracker

In your Godot game:

```gdscript
func _ready():
    GameTracker.init({
        "endpoint": "http://localhost:4318",
        "game": "my-game",
        "version": "1.0.0",
        "environment": "development"
    })
```

## Viewing Data in Grafana

### Logs (Loki)

1. Go to Explore
2. Select "Loki" datasource
3. Use LogQL queries:

```logql
{game="my-game"} |= "error"
{game="my-game", level="error"}
{game="my-game"} | json | data_player_id = "123"
```

### Metrics (Mimir)

1. Go to Explore
2. Select "Mimir" datasource
3. Use PromQL queries:

```promql
# Total button clicks
sum(demo_button_clicks_total{game="my-game"})

# Player health over time
demo_player_health{game="my-game"}

# Request latency percentiles
histogram_quantile(0.95, rate(demo_response_time_ms_bucket[5m]))
```

### Traces (Tempo)

1. Go to Explore
2. Select "Tempo" datasource
3. Search by:
   - Service name: your game name
   - Span name: operation names
   - Duration: filter slow operations

## Production Considerations

For production deployments:

1. **Security**: Add authentication to Alloy endpoint
2. **TLS**: Enable HTTPS for all endpoints
3. **Storage**: Use object storage (S3, GCS) instead of local filesystem
4. **Scaling**: Deploy multiple instances behind a load balancer
5. **Retention**: Configure appropriate data retention policies
6. **Monitoring**: Monitor the monitoring stack itself

## Troubleshooting

### No data appearing

1. Check Alloy logs: `docker compose logs alloy`
2. Verify GameTracker endpoint matches Alloy port
3. Check if data is being received: Alloy UI at http://localhost:12345

### Connection refused

1. Ensure all services are running: `docker compose ps`
2. Check if ports are available: `lsof -i :4318`
3. Verify Docker network connectivity

### High memory usage

1. Reduce retention periods
2. Limit ingestion rates in configs
3. Add resource limits to docker-compose.yml
