#!/bin/bash

set -e

INSTALL_URL="https://raw.githubusercontent.com/Degeris/panel-proxy/main/install.sh"
TMP_INSTALL="/tmp/panel-proxy-install.sh"

echo "=========================================="
echo "       Degeris Panel Proxy Installer"
echo "=========================================="
echo

# Root check
if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] Please run this script as root."
    exit 1
fi

# OS detection
if [ ! -f /etc/os-release ]; then
    echo "[ERROR] Cannot detect operating system."
    exit 1
fi

. /etc/os-release

case "$ID" in
    ubuntu|debian)
        echo "[INFO] Operating System: $PRETTY_NAME"
        ;;
    *)
        echo "[ERROR] This installer currently supports Ubuntu/Debian."
        echo "[INFO] Detected: $PRETTY_NAME"
        exit 1
        ;;
esac

echo
echo "[1/6] Updating package lists..."
apt-get update -y

echo
echo "[2/6] Installing all required packages..."

DEBIAN_FRONTEND=noninteractive apt-get install -y \
    nginx \
    certbot \
    python3-certbot-nginx \
    curl \
    wget \
    git \
    ca-certificates \
    openssl \
    unzip \
    tar \
    gzip \
    sudo \
    socat \
    lsof \
    net-tools \
    iproute2 \
    dnsutils \
    cron \
    logrotate

echo
echo "[3/6] Checking installed dependencies..."

COMMANDS=(
    nginx
    certbot
    curl
    wget
    git
    openssl
    unzip
    tar
    socat
    lsof
    ss
    dig
)

for CMD in "${COMMANDS[@]}"; do
    if command -v "$CMD" >/dev/null 2>&1; then
        echo "[OK] $CMD"
    else
        echo "[ERROR] Missing dependency: $CMD"
        exit 1
    fi
done

echo
echo "[4/6] Enabling and starting Nginx..."

systemctl enable nginx
systemctl restart nginx

if ! systemctl is-active --quiet nginx; then
    echo "[ERROR] Nginx failed to start."
    systemctl status nginx --no-pager
    exit 1
fi

if ! nginx -t; then
    echo "[ERROR] Nginx configuration test failed."
    exit 1
fi

echo "[OK] Nginx is running."

echo
echo "[5/6] Checking Certbot..."

echo "Certbot: $(certbot --version 2>&1)"

if certbot plugins 2>/dev/null | grep -q "nginx"; then
    echo "[OK] Certbot Nginx plugin is installed."
else
    echo "[ERROR] Certbot Nginx plugin was not detected."
    exit 1
fi

echo
echo "[6/6] Downloading Panel Proxy installer..."

rm -f "$TMP_INSTALL"

if ! curl -fL \
    --retry 3 \
    --connect-timeout 15 \
    --max-time 120 \
    "$INSTALL_URL" \
    -o "$TMP_INSTALL"; then

    echo "[ERROR] Failed to download install.sh"
    rm -f "$TMP_INSTALL"
    exit 1
fi

if [ ! -s "$TMP_INSTALL" ]; then
    echo "[ERROR] Downloaded install.sh is empty."
    rm -f "$TMP_INSTALL"
    exit 1
fi

chmod +x "$TMP_INSTALL"

echo "[OK] install.sh downloaded successfully."
echo
echo "=========================================="
echo "     Starting Panel Proxy installation"
echo "=========================================="
echo

bash "$TMP_INSTALL"
STATUS=$?

rm -f "$TMP_INSTALL"

if [ "$STATUS" -ne 0 ]; then
    echo
    echo "[ERROR] Panel Proxy installer failed."
    exit "$STATUS"
fi

echo
echo "=========================================="
echo "   Panel Proxy installation completed!"
echo "=========================================="
