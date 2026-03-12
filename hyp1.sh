#!/bin/bash
# =============================================
#  HyperV1 Theme Installer / Forced License
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
    echo "Error: This script must be run as root or with sudo privileges."
    exit 1
fi

# ------------------------------
# FORCED LICENSE CHECK
# ------------------------------
LICENSE_NAME="DʀᴀɢᴏɴGᴀᴍᴇʀ"
LICENSE_EMAIL="dragondgamer432@gmail.com"

echo ""
echo "========== LICENSE VERIFICATION =========="
read -rp "Enter license name: " input_name
read -rp "Enter license email: " input_email

if [[ "$input_name" != "$LICENSE_NAME" || "$input_email" != "$LICENSE_EMAIL" ]]; then
    echo "Error: Invalid license. Installation aborted."
    exit 1
fi
echo "License verified successfully."
echo "=========================================="
echo ""

# ------------------------------
# STORE LICENSE INFO
# ------------------------------
# This creates a license file inside the panel to indicate license owner
LICENSE_FILE="/var/www/pterodactyl/public/assets/hyperv1_license.txt"
mkdir -p "$(dirname "$LICENSE_FILE")"
echo "License Name: $LICENSE_NAME" > "$LICENSE_FILE"
echo "License Email: $LICENSE_EMAIL" >> "$LICENSE_FILE"
echo "License info stored at: $LICENSE_FILE"
echo ""

read -rp "Enter your Pterodactyl panel path [/var/www/pterodactyl]: " PANEL_PATH
PANEL_PATH=${PANEL_PATH:-/var/www/pterodactyl}

if [[ ! -d "$PANEL_PATH" ]]; then
    echo "Error: Path $PANEL_PATH does not exist!"
    exit 1
fi

echo ""
echo "=============================="
echo "   HyperV1 Theme Installer"
echo "=============================="
echo "1) Install HyperV1 Theme"
echo "2) Upgrade HyperV1 Theme"
echo "3) Restore from Backup"
echo "=============================="
read -rp "Choose an option (1, 2, or 3): " OPTION

backup_panel() {
    echo "Backing up your panel files (excluding vendor/, logs, cache)..."
    cd /var/www || exit
    tar -czf "pterodactyl_backup_$(date +%Y%m%d_%H%M%S).tar.gz" \
        --exclude='pterodactyl/vendor' \
        --exclude='pterodactyl/node_modules' \
        --exclude='pterodactyl/storage/logs' \
        --exclude='pterodactyl/storage/framework/cache' \
        pterodactyl/
    echo "Backup completed."
}

backup_hyperv1() {
    echo "Backing up HyperV1 theme and settings..."
    cd "$PANEL_PATH" || exit
    local backup_name="hyperv1_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    cd /var/www || exit
    tar -czf "$backup_name" \
        pterodactyl/rolexdev/ \
        pterodactyl/public/rolexdev/ \
        pterodactyl/public/assets/hyper* 2>/dev/null || true
    echo "HyperV1 Backup completed: /var/www/$backup_name"
}

remove_old_assets() {
    echo "Removing old build files..."
    find "$PANEL_PATH/public/assets" -type f \( -name "*.js" -o -name "*.json" -o -name "*.js.map" \) -delete
}

install_hyperv1_files() {
    echo "Installing HyperV1 theme files..."
    cd "$PANEL_PATH" || exit

    TAR_FILE="Hyperv1.tar"
    DOWNLOAD_URL="https://r2.rolexdev.tech/hyperv1/Hyperv1.tar"

    rm -f "$TAR_FILE" || true

    if [[ "$USE_LOCAL_FILES" == "1" ]]; then
        if [[ -f "${SCRIPT_DIR}/Hyperv1.tar" ]]; then
            echo "[--local] Using local Hyperv1.tar from ${SCRIPT_DIR}."
            cp "${SCRIPT_DIR}/Hyperv1.tar" "$TAR_FILE"
        else
            echo "Error: --local specified but Hyperv1.tar not found in ${SCRIPT_DIR}" >&2
            exit 1
        fi
    elif command -v curl >/dev/null 2>&1; then
        echo "Downloading Hyperv1.tar via curl..."
        curl -f --retry 3 --retry-delay 2 --progress-bar -o "$TAR_FILE" "$DOWNLOAD_URL" || {
            echo "curl failed, attempting wget..."
            if command -v wget >/dev/null 2>&1; then
                wget --show-progress -O "$TAR_FILE" "$DOWNLOAD_URL"
            else
                echo "Error: neither curl nor wget could download the theme."
                exit 1
            fi
        }
    elif command -v wget >/dev/null 2>&1; then
        echo "Downloading Hyperv1.tar via wget..."
        wget --show-progress -O "$TAR_FILE" "$DOWNLOAD_URL"
    else
        echo "Error: neither curl nor wget available to download Hyperv1.tar"
        exit 1
    fi

    echo "Removing app/ directory before extraction..."
    rm -rf "$PANEL_PATH/app"
    echo "Extracting $TAR_FILE..."
    tar -xf "$TAR_FILE" --overwrite
}

set_permissions() {
    echo "Setting correct permissions..."
    chown -R www-data:www-data "$PANEL_PATH"/*
    chmod -R 755 "$PANEL_PATH"/storage/* "$PANEL_PATH"/bootstrap/cache/
}

clear_cache() {
    echo "Clearing Laravel cache..."
    cd "$PANEL_PATH" || exit
    php artisan config:clear
    php artisan cache:clear
    php artisan route:clear
    php artisan view:clear
    php artisan optimize
    php artisan queue:restart
}

migrate_db() {
    echo "Migrating database..."
    cd "$PANEL_PATH" || exit
    php artisan migrate --force
}

install_dependencies() {
    echo "Installing dependencies..."
    cd "$PANEL_PATH" || exit
    export COMPOSER_ALLOW_SUPERUSER=1
    composer install --no-dev --optimize-autoloader --no-interaction
}

case "$OPTION" in
    1|2)
        echo "Starting HyperV1 installation / upgrade..."
        backup_panel
        backup_hyperv1
        remove_old_assets
        install_hyperv1_files
        set_permissions
        clear_cache
        migrate_db
        install_dependencies
        echo "HyperV1 theme installation / upgrade completed."
        ;;
    3)
        echo "Restoring from backup..."
        read -rp "Enter path to backup tar.gz: " BACKUP_FILE
        if [[ ! -f "$BACKUP_FILE" ]]; then
            echo "Error: Backup file does not exist."
            exit 1
        fi
        tar -xzf "$BACKUP_FILE" -C /var/www
        echo "Restore completed."
        ;;
    *)
        echo "Invalid option selected. Exiting."
        exit 1
        ;;
esac

echo "All done!"
