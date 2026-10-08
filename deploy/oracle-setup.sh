#!/usr/bin/env bash
# One-shot setup for an Ubuntu VM (Oracle Cloud Always Free or any VPS).
# Installs Node 22, runs the store as a locked-down systemd service, puts Caddy in front for automatic HTTPS,
# opens ports 80/443, and sets up daily backups.
#   sudo bash deploy/oracle-setup.sh shop.example.com you@example.com
set -euo pipefail
DOMAIN="${1:-}"; EMAIL="${2:-}"
[ "$(id -u)" -eq 0 ] || { echo "Run with sudo."; exit 1; }
[ -n "$DOMAIN" ] || { echo "Usage: sudo bash deploy/oracle-setup.sh <your-domain> [admin-email]"; exit 1; }
SRC="$(cd "$(dirname "$0")/.." && pwd)"; APP=/opt/asingh; DATA=/var/lib/asingh; ENVF=/etc/asingh.env
export DEBIAN_FRONTEND=noninteractive

echo "==> Packages"
apt-get update -y && apt-get install -y curl ca-certificates gnupg debian-keyring debian-archive-keyring apt-transport-https iptables-persistent rsync
if ! command -v node >/dev/null || [ "$(node -p 'process.versions.node.split(".")[0]')" -lt 20 ]; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && apt-get install -y nodejs
fi
if ! command -v caddy >/dev/null; then
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' > /etc/apt/sources.list.d/caddy-stable.list
  apt-get update -y && apt-get install -y caddy
fi

echo "==> App user and files"
id asingh >/dev/null 2>&1 || useradd --system --home "$APP" --shell /usr/sbin/nologin asingh
mkdir -p "$APP" "$DATA" /var/backups/asingh
rsync -a --delete --exclude .git --exclude data --exclude node_modules --exclude preview "$SRC/" "$APP/"
chown -R root:root "$APP"; chown -R asingh:asingh "$DATA"; chmod 700 "$DATA"

echo "==> Secrets and settings ($ENVF)"
if [ ! -f "$ENVF" ]; then
  PW="$(head -c 18 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20)"
  cat > "$ENVF" <<ENV
PORT=3000
HOST=127.0.0.1
DATA_DIR=$DATA
COOKIE_SECURE=1
TRUST_PROXY=1
ADMIN_EMAIL=${EMAIL:-admin@$DOMAIN}
ADMIN_PASSWORD=$PW
# ADMIN_WEBHOOK_URL=https://hooks.slack.com/...
# WEBHOOK_SECRET_GENERIC=change-me
ENV
  chmod 600 "$ENVF"; echo "   Admin login: ${EMAIL:-admin@$DOMAIN}   password: $PW   (also saved in $ENVF — change it in Admin → Security)"
else echo "   $ENVF already exists — keeping it."; fi

echo "==> systemd service"
cat > /etc/systemd/system/asingh.service <<UNIT
[Unit]
Description=Chandravanshi store
After=network.target
[Service]
User=asingh
WorkingDirectory=$APP
EnvironmentFile=$ENVF
ExecStart=/usr/bin/node server/index.js
Restart=always
RestartSec=3
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
ReadWritePaths=$DATA
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload && systemctl enable --now asingh && systemctl restart asingh

echo "==> HTTPS (Caddy) for $DOMAIN"
cat > /etc/caddy/Caddyfile <<CADDY
$DOMAIN {
	encode zstd gzip
	reverse_proxy 127.0.0.1:3000
}
CADDY
systemctl enable caddy && systemctl restart caddy

echo "==> Firewall (Ubuntu images on Oracle block 80/443 by default)"
for p in 80 443; do iptables -C INPUT -p tcp --dport $p -j ACCEPT 2>/dev/null || iptables -I INPUT 5 -p tcp --dport $p -j ACCEPT; done
netfilter-persistent save >/dev/null 2>&1 || true

echo "==> Daily backup (keeps 14 days)"
cat > /usr/local/bin/asingh-backup <<'BK'
#!/usr/bin/env bash
set -e; f=/var/backups/asingh/asingh-$(date +%F).tar.gz
tar -C /var/lib -czf "$f" asingh && chmod 600 "$f"; find /var/backups/asingh -name 'asingh-*.tar.gz' -mtime +14 -delete
BK
chmod +x /usr/local/bin/asingh-backup
echo "17 3 * * * root /usr/local/bin/asingh-backup" > /etc/cron.d/asingh-backup

sleep 2; systemctl is-active --quiet asingh && echo "✓ Store is running" || { echo "✗ Service failed — see: journalctl -u asingh -n 50"; exit 1; }
echo "Open: https://$DOMAIN  (admin: https://$DOMAIN/admin.html). If the page doesn't load, check the Oracle Security List allows TCP 80 and 443, and that $DOMAIN points to this VM's public IP."
