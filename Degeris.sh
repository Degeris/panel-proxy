#!/bin/bash

set -e

REPO="https://github.com/Degeris/panel-proxy"
INSTALL_URL="https://raw.githubusercontent.com/Degeris/panel-proxy/main/install.sh"

echo "=========================================="
echo "        Degeris Panel Proxy Installer"
echo "=========================================="
echo

# Root check
if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] Please run this script as root."
    exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
else
    echo "[ERROR] Cannot detect operating system."
    exit 1
fi

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
echo "[1/5] Updating package lists..."
apt-get update -y

echo
echo "[2/5] Installing required packages..."

apt-get install -y \
    nginx \
    curl \
    wget \
    git \
    ca-certificates \
    openssl \
    unzip \
    tar \
    sudo \
    socat \
    lsof \
    net-tools

echo
echo "[3/5] Enabling Nginx..."

systemctl enable nginx
systemctl start nginx

if ! command -v nginx >/dev/null 2>&1; then
    echo "[ERROR] Nginx installation failed."
    exit 1
fi

echo "[OK] Nginx installed: $(nginx -v 2>&1)"

echo
echo "[4/5] Downloading Panel Proxy installer..."

TMP_INSTALL="/tmp/panel-proxy-install.sh"

rm -f "$TMP_INSTALL"

if ! curl -fL --retry 3 --connect-timeout 10 \
    "$INSTALL_URL" \
    -o "$TMP_INSTALL"; then

    echo "[ERROR] Failed to download install.sh"
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
echo "[5/5] Running Panel Proxy installer..."
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
echo "       Panel Proxy installation done!"
echo "=========================================="