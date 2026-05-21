# Docker Deployment Guide

This guide covers deploying OpenFreeMap using Docker and Docker Compose.

## Prerequisites

- **Docker** 20.10+ and **Docker Compose** v2.0+
- **Linux host** with the `btrfs` kernel module loaded (required for HTTP Host and Tile Gen)
- At least **300 GB** of disk space for HTTP Host (for storing and serving tile data)
- At least **500 GB SSD + 64 GB RAM** for Tile Gen (only if generating tiles yourself)

> **Note:** The HTTP Host container must run with `--privileged` mode because it mounts Btrfs partition images via loop devices. This is fundamental to how OpenFreeMap serves tiles.

## Quick Start

### 1. Clone and configure

```bash
git clone https://github.com/hyperknot/openfreemap
cd openfreemap
```

Copy the example environment file and edit it:

```bash
cp docker/.env.example .env
```

Edit `.env` and set:
- `DOMAIN_DIRECT` — your domain/subdomain (e.g., `maps.example.com`)
- `LETSENCRYPT_EMAIL` — your email for Let's Encrypt certificates
- `SKIP_PLANET` — set to `true` for initial testing (uses Monaco only)
- `SELF_SIGNED_CERTS` — set to `true` if managing certificates externally

### 2. Start the HTTP Host

```bash
# Start with just the HTTP host (most common use case)
docker compose up -d http-host
```

The first run will:
1. Generate self-signed SSL certificates
2. Download tile data (Monaco first if `SKIP_PLANET=true`)
3. Mount Btrfs images and configure nginx
4. Start serving tiles

This process takes several minutes. Monitor progress:

```bash
docker compose logs -f http-host
```

### 3. Start the Website (optional)

```bash
docker compose up -d website
```

The website will be available at `http://localhost:4321`.

### 4. Start Tile Generation (optional)

Tile generation is rarely needed since pre-built planet tiles are available for download.

```bash
# Start tile gen (uses the 'tile-gen' profile)
docker compose --profile tile-gen run tile-gen make-tiles planet
```

## Configuration Reference

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DOMAIN_DIRECT` | `maps.example.com` | Your domain with A record pointing to server |
| `LETSENCRYPT_EMAIL` | _(empty)_ | Email for Let's Encrypt certificates |
| `SKIP_PLANET` | `false` | Skip full planet download (use Monaco only) |
| `SELF_SIGNED_CERTS` | `false` | Use self-signed certs instead of Let's Encrypt |
| `DOMAIN_ROUNDROBIN` | _(empty)_ | Round-robin DNS domain (advanced) |
| `HTTP_HOST_LIST` | _(empty)_ | Comma-separated list of HTTP hosts (advanced) |
| `TELEGRAM_TOKEN` | _(empty)_ | Telegram bot token for notifications |
| `TELEGRAM_CHAT_ID` | _(empty)_ | Telegram chat ID for notifications |

### Volumes

| Volume | Container Path | Description |
|--------|---------------|-------------|
| `ofm-data` | `/data/ofm` | Main data: config, tile runs, assets |
| `nginx-data` | `/data/nginx` | Nginx: configs, logs, certificates |
| `mnt-ofm` | `/mnt/ofm` | Btrfs mount points (loop mounts) |

### Ports

| Service | Port | Description |
|---------|------|-------------|
| HTTP Host | 80, 443 | HTTP and HTTPS for tile serving |
| Website | 4321 | Astro website |

## Services

### http-host

The main tile-serving container. Runs nginx with optimized configuration for serving 300+ million tile files from Btrfs images.

**Requires:** `--privileged` mode (for Btrfs loop mounting)

**What it does:**
1. Downloads Btrfs tile images from Cloudflare R2
2. Mounts images as read-only loop devices
3. Configures nginx location blocks for each tile version
4. Runs periodic sync (every minute) to check for new versions
5. Manages Let's Encrypt certificates (unless `SELF_SIGNED_CERTS=true`)

### tile-gen

Optional tile generation container. Used only if you want to generate tiles from raw OSM data.

**Requires:** `--privileged` mode (for Btrfs image creation), 500 GB SSD, 64 GB RAM

**Commands:**
```bash
# Generate tiles for an area
docker compose --profile tile-gen run tile-gen make-tiles planet

# Upload generated tiles
docker compose --profile tile-gen run tile-gen upload-area planet

# Generate indexes
docker compose --profile tile-gen run tile-gen make-indexes
```

### website

The OpenFreeMap website (Astro static site). Simple container that serves the built static files.

## Testing Your Deployment

After starting the HTTP host, test with:

```bash
# Wait a few minutes for initial sync, then:
curl -sI https://your-domain.com/monaco | head -20
```

Expected response includes:
```
HTTP/2 200
content-type: application/json
access-control-allow-origin: *
```

## Updating

To update to a newer version:

```bash
git pull
docker compose build
docker compose up -d
```

The HTTP host automatically checks for new tile versions every minute, so tile data stays current without rebuilding.

## Troubleshooting

### "needs to be run on Linux"
The HTTP host container checks for `/etc/fstab`. This should exist inside the container. If you see this error, make sure you're running the container on a Linux host.

### Btrfs mount failures
Ensure the `btrfs` kernel module is loaded on the Docker host:
```bash
sudo modprobe btrfs
lsmod | grep btrfs
```

### Certificate issues
If Let's Encrypt fails, set `SELF_SIGNED_CERTS=true` and manage certificates externally.

### Checking logs
```bash
# HTTP host logs
docker compose logs http-host

# Sync logs inside the container
docker compose exec http-host cat /data/ofm/http_host/logs/sync.log

# Nginx error logs
docker compose exec http-host cat /data/nginx/logs/nginx-error.log
```
