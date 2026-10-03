#!/usr/bin/env bash
#
# deploy-web.sh -- deploy the ACS730 demo web app on Amazon Linux 2023.
# Safe to run more than once: every step either creates something, or
# leaves the existing one alone.
 
set -euo pipefail
 
APP_USER="acs730web"
APP_DIR="/opt/acs730-web"
UNIT_SRC="$(dirname "$0")/../acs730-web.service"
UNIT_DST="/etc/systemd/system/acs730-web.service"
 
echo "==> Installing packages"
sudo dnf -y install python3
 
echo "==> Creating service user $APP_USER if it does not exist"
if ! id -u "$APP_USER" >/dev/null 2>&1; then
  sudo useradd --system --no-create-home --shell /sbin/nologin "$APP_USER"
fi
 
echo "==> Laying down the application in $APP_DIR"
sudo mkdir -p "$APP_DIR"
sudo tee "$APP_DIR/index.html" >/dev/null <<'HTML'
<!doctype html>
<html><head><title>ACS730 Lab 2</title></head>
<body><h1>ACS730 Lab 2</h1>
<p>Deployed by deploy-web.sh and kept alive by systemd.</p></body></html>
HTML
sudo chown -R "$APP_USER:$APP_USER" "$APP_DIR"
 
echo "==> Installing the systemd unit"
sudo cp "$UNIT_SRC" "$UNIT_DST"
sudo chmod 644 "$UNIT_DST"
sudo systemctl daemon-reload
 
echo "==> Enabling and starting the service"
sudo systemctl enable acs730-web
sudo systemctl restart acs730-web
 
echo "==> Done. Local check:"
sleep 1
curl -fsS http://localhost/ | head -3
