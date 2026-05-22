# Coolify Deployment Guide

This guide covers how to deploy and host **OpenFreeMap** using **Coolify**, the open-source & self-hostable Heroku/Vercel alternative.

---

## Why Use the Coolify Config?

The default `docker-compose.yml` configures host-level ports mapping (`80:80` and `443:443`). Since **Coolify** runs its own Traefik reverse proxy to handle domain routing and automatic SSL termination at the host level, mapping these ports directly on the host would cause severe network conflicts.

We provide a specialized, pre-configured [docker-compose.coolify.yml](file:///Users/napatc/ARV/Aerial/Maps-Offine-Dev/docker-compose.coolify.yml) in the root of this repository.

### Key differences in the Coolify configuration:
1. **No Host Port Conflicts**: Exposes internal ports (`80` for the HTTP Host and `4321` for the Astro Website) via `expose` instead of mapping host ports. Traefik will dynamically proxy traffic to these containers.
2. **Simplified SSL**: Traefik handles Let's Encrypt certificates, so the HTTP Host container runs purely as an HTTP server internally (`SELF_SIGNED_CERTS=false`), simplifying setup and eliminating standalone certbot container renewals.
3. **Privileged Access Preserved**: Keeps `privileged: true` configuration, allowing the HTTP Host to mount Btrfs images via loop devices (which is fully supported by Coolify).

---

## Step-by-Step Deployment on Coolify

### 1. Import Your Git Repository
1. Log into your Coolify Dashboard.
2. Click **Sources** -> **Add New Source** (or use your existing Git integration).
3. Create a **New Resource** -> Select **Private Repository** (or Public) and select your OpenFreeMap repository.

### 2. Configure the Build Pack
1. In the Resource Creation wizard, select **Docker Compose** as the Build Pack.
2. Change the **Docker Compose Location** to:
   ```bash
   ./docker-compose.coolify.yml
   ```
3. Set the **Destination** (the server and Docker network where it should deploy).

### 3. Assign Domains (FQDNs)
Unlike typical docker-compose files where domains are written in code, Coolify configures routing via the UI:

1. Click on the **http-host** service inside your new Coolify resource.
2. Locate the **FQDN** field and enter your map serving domain:
   * Example: `https://maps.yourdomain.com`
   * *Coolify will automatically configure Traefik to route all public traffic from this domain to port `80` of the `http-host` container and manage SSL certificates.*
3. (Optional) If deploying the website, click on the **website** service and set its **FQDN**:
   * Example: `https://yourdomain.com`
   * *Coolify will automatically route public traffic to port `4321` of the `website` container.*

### 4. Configure Environment Variables
In the Coolify dashboard under the **Environment Variables** tab for the stack, add the following variables:

| Key | Value | Description |
|-----|-------|-------------|
| `DOMAIN_DIRECT` | `maps.yourdomain.com` | The domain pointing to your maps server. |
| `SKIP_PLANET` | `false` | Set to `true` if you only want to download and serve Monaco for initial testing. |
| `TELEGRAM_TOKEN` | _(Optional)_ | Bot token for server alerts. |
| `TELEGRAM_CHAT_ID` | _(Optional)_ | Chat ID for server alerts. |

### 5. Launch the Stack
Click **Deploy** at the top right of the Coolify dashboard.

* **Initial Sync**: The container will build, start up, and immediately begin downloading the Btrfs tile data files. This initial download can take several minutes (or hours if downloading the full planet).
* **Logs Monitoring**: Go to the **Logs** tab of the `http-host` service to watch the download progress and verify the mounting of tile images.

---

## Manual Tile Generation under Coolify

If you need to generate tiles dynamically inside the Coolify-managed VM:
1. SSH into the host machine managed by Coolify.
2. Find the active Docker network and run standard `tile-gen` via standard terminal commands:
   ```bash
   # Run the tile-gen container manually with your local configurations
   docker run --rm --privileged \
     --network coolify \
     -v maps-offine-dev_ofm-data:/data/ofm \
     maps-offine-dev-tile-gen:latest make-tiles monaco
   ```

---

## Troubleshooting on Coolify

### 1. Loop Device / Btrfs Failures
Make sure your Coolify Host OS is Linux and has Btrfs loaded at the kernel level:
```bash
sudo modprobe btrfs
```

### 2. Permission Denied Errors
Ensure the docker socket or loop mounts are not restricted by AppArmor or SELinux policies on your Coolify host. `privileged: true` is mandatory for the Btrfs mounts to work.

### 3. FQDN Proxy Routing Issues
If your domain returns a `502 Bad Gateway`, check:
* The `http-host` container logs to see if the server has finished downloading the tile files and starting Nginx.
* That the FQDN in Coolify is typed correctly (including the `https://` prefix).
