#!/bin/bash
# =============================================
# HyperV1 Theme Installer (No License Check)
# URL: https://r2.rolexdev.tech/hyperv1/Hyperv1.tar
# =============================================

set -e

FORCED_DOWNLOAD_URL="https://r2.rolexdev.tech/hyperv1/Hyperv1.tar"

# Detect Pterodactyl path
if [ -d "/var/www/pterodactyl" ]; then
    PANEL_PATH="/var/www/pterodactyl"
else
    read -rp "Enter your Pterodactyl panel path: " PANEL_PATH
    if [[ ! -d "$PANEL_PATH" ]]; then
        echo "Error: Path $PANEL_PATH does not exist!"
        exit 1
    fi
fi

echo "Using Pterodactyl panel path: $PANEL_PATH"

# Remove old HyperV1 files
echo "Removing old HyperV1 theme files..."
rm -rf "$PANEL_PATH/rolexdev" "$PANEL_PATH/public/rolexdev" "$PANEL_PATH/public/assets/hyper*"

# Download HyperV1
echo "Downloading HyperV1 theme..."
cd "$PANEL_PATH" || exit
TAR_FILE="Hyperv1.tar"

if command -v curl >/dev/null 2>&1; then
    curl -fSL -o "$TAR_FILE" "$FORCED_DOWNLOAD_URL"
elif command -v wget >/dev/null 2>&1; then
    wget -O "$TAR_FILE" "$FORCED_DOWNLOAD_URL"
else
    echo "Error: Neither curl nor wget is installed."
    exit 1
fi

echo "Extracting theme..."
tar -xf "$TAR_FILE" --overwrite
rm -f "$TAR_FILE"

# Set permissions
echo "Setting permissions..."
chown -R www-data:www-data "$PANEL_PATH"/*
chmod -R 755 "$PANEL_PATH"/storage/* "$PANEL_PATH"/bootstrap/cache/

# Clear Laravel cache
echo "Clearing Laravel cache..."
cd "$PANEL_PATH"
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear
php artisan optimize
php artisan queue:restart || true

# Run database migrations
echo "Migrating database..."
php artisan migrate --force

# Set forced license key in DB (your own license)
echo "Setting forced license..."
php artisan tinker --execute="DB::table('settings')->updateOrInsert(['key'=>'hyperv1_license'], ['value'=>'ROLEXDEV-FORCED-LICENSE'])"

echo "HyperV1 theme installed successfully!"
