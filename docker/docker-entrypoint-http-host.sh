#!/usr/bin/env bash
# =============================================================================
# OpenFreeMap HTTP Host Entrypoint
# =============================================================================
# This script:
#   1. Generates config.json from environment variables
#   2. Sets up SSL certificates (self-signed fallback + DH params)
#   3. Starts nginx, runs initial sync, sets up cron, then keeps nginx in fg
# =============================================================================

set -e

echo "========================================"
echo "  OpenFreeMap HTTP Host - Starting Up"
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
# 2. Generate self-signed certificate if not present
#    This is used by the default_disable.conf server block and as a fallback
#    until Let's Encrypt issues real certificates.
# ---------------------------------------------------------------------------
if [ ! -f /etc/nginx/ssl/dummy.cert ]; then
    echo "[entrypoint] Generating self-signed SSL certificate..."
    mkdir -p /etc/nginx/ssl
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/dummy.key \
        -out /etc/nginx/ssl/dummy.cert \
        -subj "/C=US/ST=Dummy/L=Dummy/O=Dummy/CN=example.com" \
        2>/dev/null
    echo "[entrypoint] Self-signed certificate generated."
fi

# ---------------------------------------------------------------------------
# 3. Download Mozilla DH parameters if not present
#    Used for TLS configuration (ffdhe2048 recommended by Mozilla)
# ---------------------------------------------------------------------------
if [ ! -f /etc/nginx/ffdhe2048.txt ]; then
    echo "[entrypoint] Downloading Mozilla ffdhe2048 DH parameters..."
    curl -sS https://ssl-config.mozilla.org/ffdhe2048.txt -o /etc/nginx/ffdhe2048.txt
    echo "[entrypoint] DH parameters downloaded."
fi

# ---------------------------------------------------------------------------
# 4. Test and start nginx (in background initially)
# ---------------------------------------------------------------------------
echo "[entrypoint] Testing nginx configuration..."
nginx -t

echo "[entrypoint] Starting nginx (background)..."
nginx

# ---------------------------------------------------------------------------
# 5. Run initial sync (force flag ensures it runs immediately)
# ---------------------------------------------------------------------------
echo "[entrypoint] Running initial sync (this may take a while on first run)..."
/opt/ofm/venv/bin/python -u /opt/ofm/http_host/bin/http_host.py sync --force || {
    echo "[entrypoint] WARNING: Initial sync failed (may succeed on retry via cron)"
}

# ---------------------------------------------------------------------------
# 6. Set up cron job for periodic sync (every minute)
# ---------------------------------------------------------------------------
echo "[entrypoint] Setting up cron job for periodic sync..."
cat > /etc/cron.d/ofm_http_host <<'CRON'
# OpenFreeMap HTTP Host - sync every minute
* * * * * root /opt/ofm/venv/bin/python -u /opt/ofm/http_host/bin/http_host.py sync >> /data/ofm/http_host/logs/sync.log 2>&1
CRON
chmod 0644 /etc/cron.d/ofm_http_host

# ---------------------------------------------------------------------------
# 7. Start cron daemon in background
# ---------------------------------------------------------------------------
echo "[entrypoint] Starting cron daemon..."
cron

# ---------------------------------------------------------------------------
# 8. Stop the backgrounded nginx and restart in foreground
#    This ensures nginx is PID 1 and handles signals properly.
# ---------------------------------------------------------------------------
echo "[entrypoint] Switching nginx to foreground mode..."
nginx -s stop 2>/dev/null || true
sleep 1

echo "========================================"
echo "  OpenFreeMap HTTP Host - Ready"
echo "  Serving on ports 80 and 443"
echo "========================================"

exec nginx -g 'daemon off;'
