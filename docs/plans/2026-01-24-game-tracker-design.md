# GameTracker: GDScript Observability Addon

**Date:** 2026-01-24
**Status:** Design Complete

## Overview

A single-file GDScript addon for Godot 4 that provides logging, metrics, and tracing capabilities. Pushes data to a Grafana Alloy instance which routes to the LGTM stack (Loki, Grafana, Tempo, Mimir).

## Goals

- Production-ready observability for Godot games
- Manual capture only (developer controls what gets tracked)
- Non-blocking, fire-and-forget (game performance unaffected)
- Portable (copy one folder, add autoload, done)

## Non-Goals

- Automatic error capture
- Retry/persistence on failure
- Sampling or rate limiting (beyond queue cap)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       GameTracker                           │
│                    (Autoload Singleton)                     │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Logger    │  │   Metrics   │  │      Tracer         │  │
│  │   (Loki)    │  │ (Prometheus)│  │      (Tempo)        │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
│         │                │                    │             │
│         ▼                ▼                    ▼             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              HTTP Sender (fire & forget)            │    │
│  │         Pushes to Grafana Alloy endpoints           │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  Grafana Alloy  │
                    └────────┬────────┘
                             │
            ┌────────────────┼────────────────┐
            ▼                ▼                ▼
        ┌───────┐       ┌────────┐       ┌───────┐
        │ Loki  │       │ Mimir  │       │ Tempo │
        └───────┘       └────────┘       └───────┘
```

## File Structure

```
addons/game_tracker/
  ├── plugin.cfg
  └── game_tracker.gd     # Everything in one file
```

## Public API

### Initialization

```gdscript
GameTracker.init({
    "endpoint": "https://alloy.example.com",  # Base URL for Alloy
    "game": "my-awesome-game",                # Identifies your game
    "version": "1.2.3",                       # Game version
    "environment": "production",              # production/staging/development
})
```

### Logging (→ Loki)

```gdscript
GameTracker.log_info("Player joined", {"player_id": "123"})
GameTracker.log_warn("Low memory detected", {"available_mb": 128})
GameTracker.log_error("Failed to load asset", {"path": "res://missing.png"})
GameTracker.log_debug("State transition", {"from": "menu", "to": "game"})
```

### Metrics (→ Prometheus/Mimir)

```gdscript
GameTracker.increment("enemies_killed", {"level": "forest"})           # Counter
GameTracker.gauge("player_health", 85, {"player_id": "123"})           # Gauge
GameTracker.histogram("load_time_ms", 1250, {"scene": "level_3"})      # Histogram
```

### Tracing (→ Tempo)

```gdscript
var span = GameTracker.start_span("level_load", {"level": "forest"})
# ... do the loading ...
span.end()

# Nested spans
var parent = GameTracker.start_span("game_session")
var child = GameTracker.start_span("tutorial", {}, parent)
child.end()
parent.end()
```

### Context (attached to all events)

```gdscript
GameTracker.set_user({"id": "player_123", "tier": "premium"})
GameTracker.set_context("device", {"gpu": "RTX 3080", "ram_gb": 16})
GameTracker.set_tag("build", "demo")
```

## Non-blocking Design

### Guarantees

- API calls return immediately (no `await`)
- Network happens in background
- Failures are silent (no errors, no callbacks)
- Game performance unaffected

### Implementation

```gdscript
func log_info(message: String, data: Dictionary = {}):
    _queue_log("info", message, data)  # Returns instantly

func _queue_log(level: String, message: String, data: Dictionary):
    if _log_queue.size() >= MAX_QUEUE_SIZE:
        _log_queue.pop_front()  # Drop oldest, don't block
    _log_queue.append({
        "level": level,
        "msg": message,
        "data": data,
        "ts": Time.get_unix_time_from_system()
    })
```

### Batched Sending

- Flush queue every N seconds (configurable, default: 5s)
- Or when queue hits threshold (e.g., 20 items)
- Single HTTP request per batch
- Max 1 in-flight request at a time
- Queue hard cap: 100 items (oldest dropped when full)

### On Failure

- HTTP timeout → silently drop batch
- Connection error → silently drop batch
- Non-200 response → silently drop batch
- No retries, no persistence

## Wire Formats

### Logs → Loki Push API

`POST /loki/api/v1/push`

```json
{
  "streams": [{
    "stream": {
      "game": "my-awesome-game",
      "env": "production",
      "level": "error"
    },
    "values": [
      ["1704067200000000000", "{\"msg\":\"Failed to load\",\"path\":\"res://x.png\"}"]
    ]
  }]
}
```

### Metrics → Prometheus Remote Write

`POST /api/v1/push`

```
enemies_killed_total{game="my-awesome-game",env="production",level="forest"} 1
player_health{game="my-awesome-game",player_id="123"} 85
```

### Traces → OTLP HTTP

`POST /v1/traces`

```json
{
  "resourceSpans": [{
    "resource": {
      "attributes": [
        {"key": "service.name", "value": {"stringValue": "my-awesome-game"}}
      ]
    },
    "scopeSpans": [{
      "spans": [{
        "traceId": "abc123...",
        "spanId": "def456...",
        "name": "level_load",
        "startTimeUnixNano": 1704067200000000000,
        "endTimeUnixNano": 1704067201500000000,
        "attributes": [
          {"key": "level", "value": {"stringValue": "forest"}}
        ]
      }]
    }]
  }]
}
```

## Automatic Context

Attached to every event without manual calls:

```gdscript
{
    # From init config
    "game": "my-awesome-game",
    "version": "1.2.3",
    "environment": "production",
    "session_id": "uuid-generated",  # Unique per game launch

    # Device info (collected once)
    "os": "Windows",
    "os_version": "10.0.19041",
    "locale": "en_US",
    "godot_version": "4.6",
    "gpu": "NVIDIA GeForce RTX 3080",
    "screen": "1920x1080",
}
```

## Integration Example

```gdscript
# main.gd
func _ready():
    GameTracker.init({
        "endpoint": "https://alloy.example.com",
        "game": "forest-adventure",
        "version": "1.0.0",
        "environment": "production" if OS.has_feature("release") else "development"
    })

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
    GameTracker.set_tag("current_level", level_name)

    var scene = load("res://levels/%s.tscn" % level_name)
    if scene == null:
        GameTracker.log_error("level_load_failed", {"level": level_name})
        span.end()
        return

    get_tree().change_scene_to_packed(scene)
    GameTracker.log_info("level_loaded", {"level": level_name})
    GameTracker.increment("levels_started", {"level": level_name})
    span.end()

# shop.gd
func purchase_item(item_id: String, price: int):
    GameTracker.log_info("purchase_attempt", {"item": item_id, "price": price})
    if player.gold >= price:
        player.gold -= price
        GameTracker.increment("purchases", {"item": item_id})
        GameTracker.increment("revenue_gold", {"item": item_id}, price)
    else:
        GameTracker.log_info("purchase_failed_funds", {"item": item_id})
```

## Installation

1. Copy `addons/game_tracker/` to your project
2. Add to Project Settings → Autoload:
   - Path: `res://addons/game_tracker/game_tracker.gd`
   - Name: `GameTracker`
3. Call `GameTracker.init({...})` in your game startup

## Infrastructure Requirements

- Grafana Alloy instance configured to receive:
  - Loki push API on `/loki/api/v1/push`
  - Prometheus remote write on `/api/v1/push`
  - OTLP traces on `/v1/traces`
- Alloy forwarding to Loki, Mimir, and Tempo backends
- Grafana for visualization
