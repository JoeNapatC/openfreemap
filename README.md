<a href="https://openfreemap.org/"><img src="https://openfreemap.org/logo.jpg" alt="logo" height="200" class="logo" /></a>

# OpenFreeMap (Containerized & Offline-Optimized)

[![Docker Support](https://img.shields.io/badge/Docker-Enabled-blue.svg?logo=docker&logoColor=white)](docs/docker_deployment.md)
[![Coolify Support](https://img.shields.io/badge/Coolify-Supported-purple.svg)](docs/coolify_deployment.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.md)

Welcome to the customized fork of **OpenFreeMap** (`JoeNapatC/openfreemap`). This repository provides a production-grade, fully containerized, and local-development-friendly map stack optimized for custom hosting environments and offline map deployment.

Unlike the upstream repository, this version has been heavily refactored to prioritize **container orchestration, private hosting (like Coolify), and robust local/offline development options**.

---

## 🚀 Key Context & Enhancements

This fork adapts the high-performance tile architecture of OpenFreeMap to meet modern enterprise and local development requirements:

1. **Complete Docker Orchestration**: Out-of-the-box `docker-compose` support for all services (HTTP Host Nginx server, optional Tile Generator, and Astro static Website).
2. **Coolify-Ready Stack**: Includes [docker-compose.coolify.yml](docker-compose.coolify.yml) pre-configured to deploy behind Coolify’s native Traefik reverse proxy without host-level port conflicts.
3. **Local & Offline Serving**: Supports serving map tiles directly over `localhost` or local network IP addresses, bypassing restrictions that previously required public domain routing.
4. **Volume Masking Resilience**: Rewritten Docker architecture that isolates runtime code and Python virtual environments to `/opt/ofm` to prevent empty persistent volume mounts from masking the codebase.
5. **Dynamic Configuration Generator**: Automatically compiles `config.json` at container startup from simple environment variables, supporting fallback features like `SELF_SIGNED_CERTS` and `SKIP_PLANET` mode.
6. **Lean & Clean Monorepo**: Streamlined codebase with legacy external modules (e.g., the Cloudflare Worker debug proxy) fully removed.

---

## 🛠️ Tech Stack & How It Works

This project serves **300+ million tiles** with sub-millisecond latency on standard hardware using a pure, file-system-level implementation.

* **No Running Database**: Tiles are generated as standard MBTiles, then extracted into optimized **Btrfs partition images** consisting of millions of hard-linked files.
* **Kernel-Level Performance**: Nginx serves tiles directly from mounted Btrfs images. This leverages the Linux kernel's high-performance file caching instead of database processes, yielding extreme throughput (tested to saturate 30 Gbit on loopback).
* **Weekly Planet Updates**: Planet-wide tiles are updated weekly and available for public download in both Btrfs and MBTiles formats.

---

## ⚡ Quick Start (Docker Compose)

The easiest and recommended way to run this stack is using Docker Compose.

### Prerequisites
* A Linux host with the **`btrfs` kernel module** loaded.
* Docker 20.10+ and Docker Compose v2.0+.

### Setup

```bash
# 1. Clone the repository
git clone https://github.com/JoeNapatC/openfreemap.git
cd openfreemap

# 2. Copy the environment template
cp docker/.env.example .env

# 3. Configure environment variables in .env
# Set DOMAIN_DIRECT to your server domain, or localhost/IP for local testing.
# Set SKIP_PLANET=true to start quickly using Monaco tile data only.
```

### Run Services

```bash
# Start the HTTP Host (serves map tiles)
docker compose up -d http-host

# (Optional) Start the Astro Website
docker compose up -d website
```

The HTTP Host container will start, download the tile data, mount the Btrfs images, and configure Nginx automatically. Follow the progress via:
```bash
docker compose logs -f http-host
```

---

## ☁️ Coolify Cloud Deployment

If you are hosting using **Coolify** (the self-hostable Heroku/Vercel alternative), deployment is fully automated out of the box:

1. Create a new resource in Coolify pointing to this Git repository.
2. Select **Docker Compose** as the build pack, and set the location to `./docker-compose.coolify.yml`.
3. In the Coolify UI, set the **FQDN** for the `http-host` service (e.g., `https://maps.yourdomain.com`).
4. Set environment variables: `DOMAIN_DIRECT=maps.yourdomain.com` and `SELF_SIGNED_CERTS=true` (since Coolify's Traefik handles external SSL termination).
5. Click **Deploy**.

For detailed, step-by-step instructions, see the [Coolify Deployment Guide](docs/coolify_deployment.md).

---

## 📂 Repository Code Structure

```
├── docker/                      # Production-ready Dockerfiles & entrypoint scripts
│   ├── Dockerfile.http-host     # Nginx & Btrfs mounting server
│   ├── Dockerfile.tile-gen      # Planetiler & Java-based tile generator
│   ├── Dockerfile.website       # Alpine-based Astro website builder
│   └── docker-entrypoint-*.sh   # Bootstrappers for dynamic runtime configs
├── docs/                        # Comprehensive guides
│   ├── docker_deployment.md     # Detailed Docker guide (environment variables, volumes)
│   ├── coolify_deployment.md    # Dedicated Coolify & Traefik guide
│   ├── dev_setup.md             # Developer setup instructions
│   └── self_hosting.md          # Original bare-metal SSH hosting guide
├── modules/                     
│   ├── http_host/               # Python logic for Btrfs sync, mounting, & Nginx config
│   ├── tile_gen/                # Java/Planetiler pipeline scripts & Btrfs compression
│   └── loadbalancer/            # DNS-based load balancer (Telegram alerting)
├── ssh_lib/                     # SSH deployment assets (Fabric scripts)
├── website/                     # Astro static site frontend
├── docker-compose.yml           # Core Docker Compose orchestration file
└── docker-compose.coolify.yml   # Coolify / Traefik optimized Compose file
```

---

## 🏗️ Generating Custom Tiles (Optional)

Tile generation is completely optional, as preprocessed planet Btrfs files are generated weekly and downloaded automatically by the HTTP Host. If you need to generate custom tiles from raw OpenStreetMap `.osm.pbf` files:

```bash
# Start tile generation using the Docker Compose 'tile-gen' profile
docker compose --profile tile-gen run --rm tile-gen make-tiles monaco
```
*Note: Generating full-planet tiles requires a high-performance machine (64GB+ RAM, 500GB+ high-speed NVMe SSD).*

---

## 🎨 Map Styles

The default styles for this project are maintained in the companion [openfreemap-styles repository](https://github.com/hyperknot/openfreemap-styles). You can customize fonts, icons, sprites, and JSON styles to match your apps.

---

## ⚖️ Attribution & License

### Attribution
Map attribution is required when displaying tiles. If you use standard libraries like MapLibre GL, it is managed automatically. For alternative clients or print/video media, add:

```html
<a href="https://openfreemap.org" target="_blank">OpenFreeMap</a> 
<a href="https://www.openmaptiles.org/" target="_blank">&copy; OpenMapTiles</a> 
Data from <a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a>
```

### License
* The code in this repository is licensed under the [MIT License](LICENSE.md).
* Map data is from [OpenStreetMap](https://www.openstreetmap.org/copyright) (ODbL).
* Third-party licenses for dependencies are documented in [LICENSE.md](LICENSE.md).
