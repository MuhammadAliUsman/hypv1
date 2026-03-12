#!/bin/bash
# =============================================
#  HyperV1 / RolexDev Theme Installer (Dev Mode)
#  Auto-detects Pterodactyl panel path
#  Developer Mode: skips DGEN license checks
# =============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
USE_LOCAL_FILES=0

for _arg in "$@"; do
    case "$_arg" in
        --local) USE_LOCAL_FILES=1 ;;
    esac
done
unset _arg

if [[ "$EUID" -ne 0 ]]; then
    echo "Error: This script must be run as root or with sudo."
    exit 1
fi

# ------------------------------
# Auto-detect Pterodactyl panel
# ------------------------------
echo "Detecting Pterodactyl panel path..."
PANEL_PATH=$(find /var/www /srv /home -type f -name artisan -exec dirname {} \; | head -n 1)

if [[ -z "$PANEL_PATH" ]]; then
    echo "Error: Could not detect Pterodactyl panel path automatically!"
    exit 1
fi

echo "Pterodactyl panel found at: $PANEL_PATH"

# ------------------------------
# Remove old theme
# ------------------------------
echo "Removing old HyperV1 / RolexDev theme files..."
rm -rf "$PANEL_PATH/rolexdev"
rm -rf "$PANEL_PATH/public/rolexdev"
find "$PANEL_PATH/public/assets" -type f -name "hyper*" -delete
rm -f "$PANEL_PATH/hyperv1_settings_backup.sql" || true
echo "Old theme removed."

# ------------------------------
# Install theme
# ------------------------------
echo "Installing HyperV1 / RolexDev theme..."

TAR_FILE="$PANEL_PATH/Hyperv1.tar"

if [[ "$USE_LOCAL_FILES" == "1" ]]; then
    if [[ -f "${SCRIPT_DIR}/Hyperv1.tar" ]]; then
        echo "[--local] Using local Hyperv1.tar from ${SCRIPT_DIR}"
        cp "${SCRIPT_DIR}/Hyperv1.tar" "$TAR_FILE"
    else
        echo "Error: Hyperv1.tar not found in ${SCRIPT_DIR}" >&2
        exit 1
    fi
else
    DOWNLOAD_URL="https://r2.rolexdev.tech/hyperv1/Hyperv1.tar"
    echo "Downloading theme..."
    if command -v curl >/dev/null 2>&1; then
        curl -fSL -o "$TAR_FILE" "$DOWNLOAD_URL"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$TAR_FILE" "$DOWNLOAD_URL"
    else
        echo "Error: curl or wget required to download theme." >&2
        exit 1
    fi
fi

echo "Extracting theme..."
tar -xf "$TAR_FILE" -C "$PANEL_PATH" --overwrite
rm -f "$TAR_FILE"

echo "Setting developer license..."
cat > "$PANEL_PATH/rolexdev/config/dev.php" <<'EOF'
<?php
return [
    'developer_mode' => true,
    'license_name' => 'DʀᴀɢᴏɴGᴀᴍᴇʀ',
    'license_email' => 'dragondgamer432@gmail.com'
];
EOF

# ------------------------------
# Clear Laravel cache
# ------------------------------
echo "Clearing Laravel cache..."
cd "$PANEL_PATH" || exit
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear
php artisan optimize
php artisan queue:restart

# ------------------------------
# Set permissions
# ------------------------------
echo "Setting permissions..."
chown -R www-data:www-data "$PANEL_PATH"/*
chmod -R 755 "$PANEL_PATH"/storage/* "$PANEL_PATH"/bootstrap/cache/

# ------------------------------
# Migrate database
# ------------------------------
echo "Migrating database..."
php artisan migrate --force

echo "=============================="
echo "Theme installation completed!"
echo "Developer license automatically applied."
echo "Pterodactyl path: $PANEL_PATH"
echo "=============================="
