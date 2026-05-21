# Dockerize OpenFreeMap & Remove Debug Proxy (Cloudflare Worker)

## Background

The OpenFreeMap project is a Python/JS monorepo that deploys map tile hosting to bare-metal Ubuntu servers via SSH (Fabric). The user wants to:

1. **Remove the Debug Proxy (Cloudflare Worker)** module entirely
2. **Add Docker support** for the core components

The project currently has zero Docker support and explicitly states it's "Docker-free on purpose." Key challenges include privileged operations (btrfs mounting, fstab editing, kernel tuning), system-level dependencies, and heavy use of SSH-based deployment.

---

## Proposed Changes

### Component 1: Remove Debug Proxy (Cloudflare Worker)

The `modules/debug_proxy/` directory is a Cloudflare Worker that proxies `/styles` requests to `tiles.openfreemap.org`. It has no dependencies elsewhere in the codebase — no Python module imports it, no deploy script references it, and it runs independently on Cloudflare's platform.

#### [DELETE] [debug_proxy](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/modules/debug_proxy)
- Delete entire directory: `modules/debug_proxy/` (includes `src/index.js`, `package.json`, `wrangler.toml`, `pnpm-lock.yaml`, `.gitignore`)

#### [MODIFY] [README.md](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/README.md)
- Remove the "Cloudflare worker for indexing the public buckets" mention from the Contributing section (line 171) — this was a wishlist item referencing a different worker, but is related to the Cloudflare Worker pattern being removed
- Update code structure section to remove any reference to debug_proxy if present

#### [MODIFY] [review-this-repo-and-try-to-add-docker-container.md](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/review-this-repo-and-try-to-add-docker-container.md)
- Remove/update sections about the Debug Proxy in the architecture diagram and component section

---

### Component 2: Docker Support — HTTP Host

The HTTP host is the most important component. It downloads btrfs images, mounts them, configures nginx, and serves tiles. This requires a **privileged** container with access to btrfs kernel modules.

#### [NEW] [Dockerfile.http-host](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/docker/Dockerfile.http-host)
- Base: `ubuntu:22.04`
- Install: Python 3, nginx (from official repo), btrfs-progs, aria2, pigz, rclone, curl, certbot
- Copy in: `modules/http_host/`, `ssh_lib/assets/nginx/`, nginx config templates
- Create: `/data/ofm`, `/data/nginx`, `/mnt/ofm` directories
- Entrypoint: A `docker-entrypoint.sh` that:
  1. Generates self-signed cert (if not present)
  2. Sets up nginx base config
  3. Runs `http_host.py sync --force` to bootstrap
  4. Starts nginx in foreground + cron for periodic sync

> [!IMPORTANT]
> This container **must** run with `--privileged` and have the `btrfs` kernel module available on the Docker host. Without this, btrfs image mounting will fail. This is inherent to the project's architecture.

#### [NEW] [docker-entrypoint-http-host.sh](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/docker/docker-entrypoint-http-host.sh)
- Shell script that orchestrates the startup sequence
- Generates self-signed SSL certs
- Copies nginx base config
- Creates config.json from environment variables
- Runs initial sync
- Starts nginx and cron in the foreground

---

### Component 3: Docker Support — Tile Generator

The tile generator downloads OSM data, runs Planetiler (Java), creates btrfs images, and uploads them. This also requires privileged access for btrfs operations.

#### [NEW] [Dockerfile.tile-gen](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/docker/Dockerfile.tile-gen)
- Base: `ubuntu:22.04`
- Install: Python 3, Java (Temurin 24), btrfs-progs, aria2, pigz, rclone, git, build-essential
- Copy in: `modules/tile_gen/`
- Entrypoint: CLI-based (`tile_gen.py`)

---

### Component 4: Docker Support — Website (Astro)

The website is a simple Astro static site — straightforward to containerize.

#### [NEW] [Dockerfile.website](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/docker/Dockerfile.website)
- Multi-stage build:
  - Stage 1: `node:20-alpine`, install pnpm, build Astro site
  - Stage 2: `node:20-alpine`, serve with lightweight HTTP server
- Remove wrangler devDependency from consideration (it's for Cloudflare Pages deployment)

---

### Component 5: Docker Compose & Configuration

#### [NEW] [docker-compose.yml](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/docker-compose.yml)
- Service `http-host`: Builds from `docker/Dockerfile.http-host`, privileged, ports 80/443, volumes for `/data/ofm`, `/data/nginx`, `/mnt/ofm`, config
- Service `tile-gen` (optional profile): Builds from `docker/Dockerfile.tile-gen`, privileged, volumes for `/data/ofm`
- Service `website`: Builds from `docker/Dockerfile.website`, port 4321

#### [NEW] [docker/.env.example](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/docker/.env.example)
- Docker-specific env file derived from `config/.env.sample`
- Includes DOMAIN_DIRECT, LETSENCRYPT_EMAIL, SKIP_PLANET, SELF_SIGNED_CERTS

#### [NEW] [.dockerignore](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/.dockerignore)
- Exclude `.git`, `node_modules`, `*.pyc`, `__pycache__`, `.venv`, `venv`, temp files

---

### Component 6: Documentation Updates

#### [MODIFY] [README.md](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/README.md)
- Update the statement "This repo is Docker-free on purpose" to indicate Docker support is now available
- Add a "Docker Deployment" section with quick-start instructions
- Update the architecture diagram to remove debug_proxy

#### [NEW] [docs/docker_deployment.md](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/docs/docker_deployment.md)
- Detailed Docker deployment guide
- Prerequisites (Docker, docker-compose, btrfs kernel module for http-host)
- Quick start with `docker compose up`
- Configuration reference
- Volume mount explanations
- Notes on privileged mode

#### [MODIFY] [docs/dev_setup.md](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/docs/dev_setup.md)
- Add Docker-based dev setup option alongside the existing OrbStack approach

---

### Component 7: Minor Code Adjustments for Docker Compatibility

#### [MODIFY] [modules/http_host/http_host_lib/utils.py](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/modules/http_host/http_host_lib/utils.py)
- Make `assert_linux()` work inside Docker (it already checks for `/etc/fstab` which exists in Docker)
- No changes needed — already compatible

#### [MODIFY] [modules/http_host/http_host_lib/config.py](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/modules/http_host/http_host_lib/config.py)
- Add environment variable override support for config paths so Docker can inject config without the SSH deployment path
- Make `config.json` loading resilient — support env var `OFM_CONFIG_DIR` override

#### [MODIFY] [modules/tile_gen/tile_gen_lib/config.py](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/modules/tile_gen/tile_gen_lib/config.py)
- Same env var override pattern as http_host config

---

## User Review Required

> [!IMPORTANT]
> **Privileged containers**: The HTTP Host and Tile Gen containers must run with `--privileged` flag because they mount btrfs images via loop devices and modify `/etc/fstab`. This is a security trade-off inherent to the project's architecture. Are you comfortable with this?

> [!WARNING]
> **The SSH-based deployment (`init-server.py`) is NOT being removed.** The Docker setup is an alternative deployment method. The existing SSH/Fabric deployment path remains intact for users who prefer it. Is this the correct approach, or should the SSH path be removed?

> [!IMPORTANT]
> **Website wrangler config**: The website (`website/`) currently has `wrangler.jsonc` and wrangler as a devDependency for deploying to Cloudflare Pages. Should these be removed as well, or kept since they're separate from the debug_proxy?

---

## Verification Plan

### Automated Tests
1. `docker build` each Dockerfile to verify they build successfully
2. `docker compose config` to validate the compose file
3. Verify the debug_proxy directory is fully removed
4. `grep -r "debug_proxy"` to confirm no stale references remain

### Manual Verification
1. Run `docker compose up website` to verify the website container serves correctly
2. Run `docker compose up http-host` (requires Linux host with btrfs) to verify the HTTP host bootstraps
3. Review documentation for accuracy and completeness
