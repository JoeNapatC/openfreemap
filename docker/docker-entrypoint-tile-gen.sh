#!/usr/bin/env bash
# =============================================================================
# OpenFreeMap Tile Generation Entrypoint
# =============================================================================
# This script:
#   1. Generates config.json from environment variables
#   2. Sets up rclone config if provided
#   3. Passes all arguments through to tile_gen.py
#
# Usage:
#   docker run ofm-tile-gen make-tiles monaco
#   docker run ofm-tile-gen make-tiles planet --upload
#   docker run ofm-tile-gen upload-area monaco
#   docker run ofm-tile-gen set-version monaco
# =============================================================================

set -e

# Ensure directory structure exists in case of empty volume mounts or host bind-mounts
mkdir -p /data/ofm/config

echo "========================================"
echo "  OpenFreeMap Tile Gen - Starting Up"
echo "========================================"

# ---------------------------------------------------------------------------
# 1. Generate config.json from environment variables
# ---------------------------------------------------------------------------
echo "[entrypoint] Generating config.json from environment variables..."

python3 -c "
import json, os

config = {
    'domain_direct': os.environ.get('DOMAIN_DIRECT', '').lower(),
    'domain_roundrobin': os.environ.get('DOMAIN_ROUNDROBIN', '').lower(),
    'letsencrypt_email': os.environ.get('LETSENCRYPT_EMAIL', '').lower(),
    'skip_planet': os.environ.get('SKIP_PLANET', 'false').lower() == 'true',
    'self_signed_certs': os.environ.get('SELF_SIGNED_CERTS', 'false').lower() == 'true',
    'http_host_list': [h.strip() for h in os.environ.get('HTTP_HOST_LIST', '').split(',') if h.strip()],
    'telegram_token': os.environ.get('TELEGRAM_TOKEN', ''),
    'telegram_chat_id': os.environ.get('TELEGRAM_CHAT_ID', ''),
}

with open('/data/ofm/config/config.json', 'w') as f:
    json.dump(config, f, indent=2)

print('Config generated:', json.dumps(config, indent=2))
"

# ---------------------------------------------------------------------------
# 2. Set up rclone config if provided via environment variable
#    The rclone.conf can also be bind-mounted directly (preferred method).
# ---------------------------------------------------------------------------
if [ -n "${RCLONE_CONF_CONTENT:-}" ]; then
    echo "[entrypoint] Writing rclone.conf from RCLONE_CONF_CONTENT env var..."
    echo "${RCLONE_CONF_CONTENT}" > /data/ofm/config/rclone.conf
    chmod 600 /data/ofm/config/rclone.conf
fi

if [ -f /data/ofm/config/rclone.conf ]; then
    echo "[entrypoint] rclone.conf found at /data/ofm/config/rclone.conf"
    export RCLONE_CONFIG=/data/ofm/config/rclone.conf
else
    echo "[entrypoint] WARNING: No rclone.conf found. Upload commands will fail."
fi

# ---------------------------------------------------------------------------
# 3. Pass all arguments through to tile_gen.py
# ---------------------------------------------------------------------------
echo "[entrypoint] Running: tile_gen.py $*"
echo "========================================"

exec /opt/ofm/venv/bin/python -u /opt/ofm/tile_gen/bin/tile_gen.py "$@"
