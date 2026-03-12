#!/bin/bash
# =============================================
# HyperV1 Personal Installer (Error-Resilient)
# =============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
TAR_FILE="$SCRIPT_DIR/Hyperv1.tar"

if [[ ! -f "$TAR_FILE" ]]; then
    echo "Error: Hyperv1.tar not found in $SCRIPT_DIR"
    exit 1
fi

# -----------------------------
# Detect Pterodactyl path
# -----------------------------
if [ -d "/var/www/pterodactyl" ]; then
    PANEL_PATH="/var/www/pterodactyl"
else
    PANEL_PATH=$(find /var/www -maxdepth 3 -type d -name "pterodactyl" | head -1)
fi

if [[ -z "$PANEL_PATH" ]]; then
    echo "Error: Pterodactyl path not found in /var/www"
    exit 1
fi

echo "Pterodactyl path detected: $PANEL_PATH"

# -----------------------------
# Backup old theme (optional)
# -----------------------------
echo "Removing old HyperV1 theme files..."
rm -rf "$PANEL_PATH/public/rolexdev" \
       "$PANEL_PATH/public/assets/hyper*" \
       "$PANEL_PATH/hyper_fetch.sh" \
       "$PANEL_PATH/hyper_auto_update.sh" \
       "$PANEL_PATH/hyper_auto_update_ioncube.sh" || true

# -----------------------------
# Extract theme
# -----------------------------
echo "Extracting theme..."
tar -xf "$TAR_FILE" -C "$PANEL_PATH"

# -----------------------------
# Set permissions
# -----------------------------
echo "Setting permissions..."
chown -R www-data:www-data "$PANEL_PATH"
chmod -R 755 "$PANEL_PATH"/storage/* "$PANEL_PATH"/bootstrap/cache/*

# -----------------------------
# Set personal license
# -----------------------------
LICENSE_NAME="DʀᴀɢᴏɴGᴀᴍᴇʀ"
LICENSE_EMAIL="dragondgamer432@gmail.com"

echo "Setting license..."
if php -r "exit(file_exists('$PANEL_PATH/artisan') ? 0 : 1)"; then
    sudo -u www-data php "$PANEL_PATH/artisan" tinker <<PHP
try {
DB::table('settings')->updateOrInsert(
    ['key' => 'hyper_license_name'],
    ['value' => '$LICENSE_NAME']
);
DB::table('settings')->updateOrInsert(
    ['key' => 'hyper_license_email'],
    ['value' => '$LICENSE_EMAIL']
);
} catch (\Exception \$e) {}
PHP
fi

# -----------------------------
# Laravel optimization
# -----------------------------
echo "Clearing Laravel caches..."
sudo -u www-data php "$PANEL_PATH/artisan" config:clear || true
sudo -u www-data php "$PANEL_PATH/artisan" cache:clear || true
sudo -u www-data php "$PANEL_PATH/artisan" route:clear || true
sudo -u www-data php "$PANEL_PATH/artisan" view:clear || true
sudo -u www-data php "$PANEL_PATH/artisan" optimize || true

echo ""
echo "======================================"
echo " HyperV1 Theme installed successfully!"
echo " License: $LICENSE_NAME <$LICENSE_EMAIL>"
echo " Pterodactyl path: $PANEL_PATH"
echo "======================================"
