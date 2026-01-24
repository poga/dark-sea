# GameTracker

A GDScript observability addon for Godot 4 that sends logs, metrics, and traces to the LGTM stack (Loki, Grafana, Tempo, Mimir) via Grafana Alloy.

## Features

- **Logging** - Structured logs with levels (info, warn, error, debug)
- **Metrics** - Counters, gauges, and histograms
- **Tracing** - Spans with nested support for tracking operations
- **Context** - Automatic device info + custom user/tags/context
- **Non-blocking** - Fire-and-forget, won't slow down your game
- **Portable** - Single file, copy to any Godot 4 project

## Installation

1. Copy `addons/game_tracker/` to your project
2. Add to Project Settings > Autoload:
   - Path: `res://addons/game_tracker/game_tracker.gd`
   - Name: `GameTracker`

## Quick Start

```gdscript
# Initialize in your main scene
func _ready():
    GameTracker.init({
        "endpoint": "https://alloy.example.com",
        "game": "my-game",
        "version": "1.0.0",
        "environment": "production" if OS.has_feature("release") else "development"
    })
```

## Configuration

| Key | Required | Default | Description |
|-----|----------|---------|-------------|
| `endpoint` | Yes | `""` | Grafana Alloy base URL |
| `game` | Yes | `"unknown"` | Your game identifier |
| `version` | No | `"0.0.0"` | Game version |
| `environment` | No | `"development"` | Environment (production/staging/development) |

## API Reference

### Logging

```gdscript
GameTracker.log_info("Player joined", {"player_id": "123"})
GameTracker.log_warn("Low memory", {"available_mb": 128})
GameTracker.log_error("Failed to load", {"path": "res://missing.png"})
GameTracker.log_debug("State change", {"from": "menu", "to": "game"})
```

### Metrics

```gdscript
# Counters - track cumulative values
GameTracker.increment("enemies_killed", {"level": "forest"})
GameTracker.increment("gold_earned", {}, 50)  # increment by 50

# Gauges - track point-in-time values
GameTracker.gauge("player_health", 85, {"player_id": "123"})

# Histograms - track distributions
GameTracker.histogram("load_time_ms", 1250, {"scene": "level_3"})
```

### Tracing

```gdscript
# Simple span
var span = GameTracker.start_span("level_load", {"level": "forest"})
# ... do the loading ...
span.end()

# Nested spans (child inherits parent's trace_id)
var parent = GameTracker.start_span("game_session")
var child = GameTracker.start_span("tutorial", {}, parent)
child.end()
parent.end()
```

### Context

Context is attached to all events automatically:

```gdscript
# Set user identity
GameTracker.set_user({"id": "player_123", "tier": "premium"})

# Set custom context
GameTracker.set_context("player", {"health": 100, "level": 5})

# Set tags for filtering
GameTracker.set_tag("build", "demo")
GameTracker.set_tag("region", "us-west")
```

## Automatic Context

Every event includes:
- `session_id` - Unique ID per game launch
- `os` - Operating system name
- `os_version` - OS version
- `locale` - User locale
- `godot_version` - Godot engine version
- `gpu` - GPU name
- `screen` - Screen resolution

## Infrastructure Setup

GameTracker sends data to Grafana Alloy, which forwards to:

| Data Type | Alloy Endpoint | Backend |
|-----------|----------------|---------|
| Logs | `/loki/api/v1/push` | Loki |
| Metrics | `/api/v1/push` | Mimir/Prometheus |
| Traces | `/v1/traces` | Tempo |

### Example Alloy Config

```hcl
// Receive logs
loki.source.api "game_logs" {
  http { listen_address = "0.0.0.0" listen_port = 3100 }
  forward_to = [loki.write.default.receiver]
}

// Receive metrics
prometheus.receive_http "game_metrics" {
  http { listen_address = "0.0.0.0" listen_port = 9090 }
  forward_to = [prometheus.remote_write.default.receiver]
}

// Receive traces
otelcol.receiver.otlp "game_traces" {
  http { endpoint = "0.0.0.0:4318" }
  output { traces = [otelcol.exporter.otlp.tempo.input] }
}
```

## Behavior

- **Batched sending** - Events are queued and sent every 5 seconds
- **Queue limits** - Max 100 items per queue; oldest dropped when full
- **Fire-and-forget** - Failed requests are silently dropped (no retries)
- **Non-blocking** - All API calls return immediately

## Example Usage

```gdscript
# player.gd
func _ready():
    GameTracker.set_user({"id": save_data.player_id})
    GameTracker.log_info("player_spawned", {"level": current_level})

func take_damage(amount: int):
    health -= amount
    GameTracker.gauge("player_health", health)
    if health <= 0:
        GameTracker.increment("player_deaths", {"cause": last_damage_source})

# level_manager.gd
func load_level(level_name: String):
    var span = GameTracker.start_span("level_load", {"level": level_name})

    var scene = load("res://levels/%s.tscn" % level_name)
    if scene == null:
        GameTracker.log_error("level_load_failed", {"level": level_name})
        span.end()
        return

    get_tree().change_scene_to_packed(scene)
    GameTracker.log_info("level_loaded", {"level": level_name})
    GameTracker.increment("levels_started", {"level": level_name})
    span.end()
```

