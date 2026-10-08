#!/usr/bin/env bash
# Pull the latest code and restart. Run from your cloned repo on the VM:  sudo bash deploy/update.sh
set -euo pipefail
cd "$(dirname "$0")/.." && git pull --ff-only
rsync -a --delete --exclude .git --exclude data --exclude node_modules --exclude preview ./ /opt/asingh/
systemctl restart asingh && sleep 1 && systemctl is-active asingh
