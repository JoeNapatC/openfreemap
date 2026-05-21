# Walkthrough: Dockerization & Debug Proxy Removal

## Summary

Two major changes were made to the OpenFreeMap repository:

1. **Removed the Debug Proxy (Cloudflare Worker)** — the `modules/debug_proxy/` module
2. **Added Docker support** — Dockerfiles, docker-compose, entrypoint scripts, and documentation

---

## Changes Made

### 1. Debug Proxy Removal

| Action | File |
|--------|------|
| **DELETED** | [modules/debug_proxy/](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/modules/debug_proxy) — entire directory (src/index.js, package.json, wrangler.toml, pnpm-lock.yaml, .gitignore) |
| **MODIFIED** | [README.md](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/README.md) — removed "Docker-free on purpose" statement, removed Cloudflare Worker contributing item |
| **MODIFIED** | [review-this-repo-and-try-to-add-docker-container.md](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/review-this-repo-and-try-to-add-docker-container.md) — updated to reflect removal |

---

### 2. New Docker Files

| File | Purpose |
|------|---------|
| [.dockerignore](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/.dockerignore) | Excludes .git, node_modules, *.pyc, large data files from build context |
| [docker-compose.yml](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/docker-compose.yml) | 3 services: http-host, tile-gen (profile-gated), website |
| [docker/Dockerfile.http-host](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/docker/Dockerfile.http-host) | Ubuntu 22.04, nginx, Python, btrfs-progs, certbot, rclone |
| [docker/docker-entrypoint-http-host.sh](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/docker/docker-entrypoint-http-host.sh) | Generates config.json, SSL certs, runs sync, starts nginx as PID 1 |
| [docker/Dockerfile.tile-gen](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/docker/Dockerfile.tile-gen) | Ubuntu 22.04, Java 24 (Temurin), Python, btrfs-progs |
| [docker/docker-entrypoint-tile-gen.sh](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/docker/docker-entrypoint-tile-gen.sh) | Generates config.json, passes args to tile_gen.py |
| [docker/Dockerfile.website](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/docker/Dockerfile.website) | Multi-stage: node:20-alpine + pnpm build → serve on port 4321 |
| [docker/.env.example](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/docker/.env.example) | Example env config for Docker deployment |

---

### 3. Code Modifications for Docker Compatibility

| File | Change |
|------|--------|
| [modules/http_host/http_host_lib/config.py](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/modules/http_host/http_host_lib/config.py) | Added `OFM_CONFIG_DIR` env var override; made config.json loading fail gracefully |
| [modules/tile_gen/tile_gen_lib/config.py](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/modules/tile_gen/tile_gen_lib/config.py) | Same changes as http_host config |

```diff
+import os
+    # Support OFM_CONFIG_DIR env var override for Docker compatibility
+    _config_dir_override = os.environ.get('OFM_CONFIG_DIR')
+    if _config_dir_override:
+        ofm_config_dir = Path(_config_dir_override)
-    if Path('/data/ofm').exists():
+    elif Path('/data/ofm').exists():
         ofm_config_dir = Path('/data/ofm/config')

-    ofm_config = json.loads((ofm_config_dir / 'config.json').read_text())
+    config_json_path = ofm_config_dir / 'config.json'
+    if config_json_path.exists():
+        ofm_config = json.loads(config_json_path.read_text())
+    else:
+        ofm_config = {}
```

---

### 4. Documentation Updates

| File | Change |
|------|--------|
| [README.md](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/README.md) | Added Docker deployment option in limitations section; updated self-hosting link |
| [docs/docker_deployment.md](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/docs/docker_deployment.md) | **NEW** — Full Docker deployment guide with quick start, config reference, troubleshooting |
| [docs/dev_setup.md](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/docs/dev_setup.md) | Added Docker dev setup option |

---

## Verification Results

| Check | Result |
|-------|--------|
| `modules/debug_proxy/` deleted | ✅ PASS |
| No stale `debug_proxy` references in code | ✅ PASS |
| All 8 Docker files exist | ✅ PASS |
| Documentation files created | ✅ PASS |
| README updated with Docker info | ✅ PASS |
| Config.py files have `OFM_CONFIG_DIR` override | ✅ PASS |
| No wrangler references in Python/Shell code | ✅ PASS |
| All Dockerfiles have valid structure | ✅ PASS |
| docker-compose.yml has all required services | ✅ PASS |

---

## Usage

```bash
# Quick start
cp docker/.env.example .env
# Edit .env with your domain
docker compose up -d

# View logs
docker compose logs -f http-host

# Generate tiles (on-demand)
docker compose --profile tile-gen run --rm tile-gen make-tiles monaco

# Start website
docker compose up -d website
```

> [!NOTE]
> The existing SSH-based deployment (`init-server.py`) remains fully functional. Docker is an alternative deployment method.

> [!WARNING]
> The `http-host` and `tile-gen` containers require `--privileged` mode for Btrfs loop device mounting. This is configured automatically in `docker-compose.yml`.
