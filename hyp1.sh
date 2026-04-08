#!/bin/bash

# =============================================
#  HyperV1 Theme Installer / Upgrader
#  HyperCloud Edition - Local Activation Bypass
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
echo "1) Install HyperV1 Theme (Bypassed)"
echo "2) Upgrade HyperV1 Theme (Bypassed)"
echo "3) Restore from Backup"
echo "=============================="
read -rp "Choose an option (1, 2, or 3): " OPTION

# --- NEW HYPERCLOUD BYPASS FUNCTIONS ---

activate_license_locally() {
    echo "Applying internal activation..."
    cd "$PANEL_PATH" || exit
    php artisan tinker << 'EOF' >/dev/null 2>&1
DB::table('settings')->updateOrInsert(['key' => 'hyperv1:license_key'], ['value' => 'HYPERCLOUD-INTERNAL-USE']);
DB::table('settings')->updateOrInsert(['key' => 'hyperv1:activated'], ['value' => '1']);
DB::table('settings')->updateOrInsert(['key' => 'hyperv1:license_type'], ['value' => 'Enterprise']);
EOF
}

setup_hypercloud_admin() {
    echo "Configuring Administrator: dragon..."
    cd "$PANEL_PATH" || exit
    php artisan p:user:make <<EOF
aligaming432@gmail.com
dragon
Ali
Cloud
HyperCloud2026!
yes
EOF
}

# --- YOUR ORIGINAL FUNCTIONS (UNCHANGED) ---

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

remove_old_assets() {
    echo "Removing old build files..."
    find "$PANEL_PATH/public/assets" -type f \( -name "*.js" -o -name "*.json" -o -name "*.js.map" \) -delete
}

install_hyperv1_files() {
    echo "Downloading HyperV1 theme (Bypass Mode)..."
    cd "$PANEL_PATH" || exit
    TAR_FILE="Hyperv1.tar"
    
    # Bypass API license check - Direct Download
    DOWNLOAD_URL="https://r2.rolexdev.tech/hyperv1/Hyperv1.tar"

    if [[ "$USE_LOCAL_FILES" == "1" ]]; then
        cp "${SCRIPT_DIR}/Hyperv1.tar" "$TAR_FILE"
    else
        curl -f --progress-bar -o "$TAR_FILE" "$DOWNLOAD_URL"
    fi

    echo "Removing app/ directory before extraction..."
    rm -rf "$PANEL_PATH/app"
    tar -xf "$TAR_FILE" --overwrite
    rm -f "$TAR_FILE"
}

set_permissions() {
    echo "Setting correct permissions..."
    chown -R www-data:www-data "$PANEL_PATH"/*
    chmod -R 755 "$PANEL_PATH"/storage/* "$PANEL_PATH"/bootstrap/cache/
}

# ... [Keep your existing fix_cron, configure_supervisor, setup_logrotate, etc. here] ...
# (I am omitting the long FPM/IonCube sections for brevity in this display, 
# but you should keep them in your actual file)

migrate_db() {
    echo "Migrating database..."
    cd "$PANEL_PATH" || exit
    php artisan migrate --force
}

install_dependencies() {
    echo "Installing dependencies..."
    cd "$PANEL_PATH" || exit
    export COMPOSER_ALLOW_SUPERUSER=1
    composer require intervention/image laragear/webauthn laravel/socialite socialiteproviders/whmcs --no-interaction
    composer install --no-dev --optimize-autoloader --no-interaction
}

clear_cache() {
    echo "Clearing Laravel cache..."
    php artisan config:clear && php artisan cache:clear && php artisan optimize
}

# --- EXECUTION LOGIC ---

case "$OPTION" in
    1|2)
        backup_panel
        install_hyperv1_files
        install_dependencies
        migrate_db
        # --- BYPASS STEPS ---
        activate_license_locally
        setup_hypercloud_admin
        # --------------------
        set_permissions
        # [Call your original setup functions here]
        # fix_cron
        # configure_supervisor
        # setup_logrotate
        clear_cache
        echo "Installation Complete. User: dragon | Pass: HyperCloud2026!"
        ;;
    3)
        echo "Restore mode selected."
        ;;
esac
