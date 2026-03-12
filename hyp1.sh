#!/bin/bash

# =============================================
#  HyperV1 Theme Installer / Upgrader (Custom)
#  License system removed, forced URL applied
#  Compatible: Ubuntu, Debian, Fedora, CentOS, Arch
# =============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
FORCED_DOWNLOAD_URL="https://yourserver.com/path/to/Hyperv1.tar" # <- Replace with your tarball URL

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

echo "=============================="
echo "   HyperV1 Custom Installer"
echo "=============================="

# --- Remove old theme files ---
echo "Removing old HyperV1 / RolexDev theme files..."
rm -rf "$PANEL_PATH/rolexdev" "$PANEL_PATH/public/rolexdev" "$PANEL_PATH/public/assets/hyper*" || true
echo "Old theme files removed."

# --- Remove backup auto-feature ---
echo "Auto-backup system removed."

# --- Download and install theme ---
echo "Downloading HyperV1 theme from forced URL..."
cd "$PANEL_PATH" || exit
TAR_FILE="Hyperv1.tar"

if command -v curl >/dev/null 2>&1; then
    curl -fSL -o "$TAR_FILE" "$FORCED_DOWNLOAD_URL"
elif command -v wget >/dev/null 2>&1; then
    wget -O "$TAR_FILE" "$FORCED_DOWNLOAD_URL"
else
    echo "Error: neither curl nor wget is available"
    exit 1
fi

echo "Extracting theme..."
rm -rf "$PANEL_PATH/app" || true
tar -xf "$TAR_FILE" --overwrite
rm -f "$TAR_FILE"

# --- Set permissions ---
echo "Setting correct permissions..."
chown -R www-data:www-data "$PANEL_PATH"/*
chmod -R 755 "$PANEL_PATH"/storage/* "$PANEL_PATH"/bootstrap/cache/

# --- Clear Laravel cache ---
echo "Clearing Laravel cache..."
cd "$PANEL_PATH" || exit
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear
php artisan optimize
php artisan queue:restart

# --- Optional: Install dependencies ---
echo "Installing composer dependencies..."
export COMPOSER_ALLOW_SUPERUSER=1
composer install --no-dev --optimize-autoloader --no-interaction

# --- Set Supervisor for Discord bot ---
echo "Configuring Supervisor for Discord Bot..."
SUPERVISOR_CONF="/etc/supervisor/conf.d/pterodactyl-discord.conf"
mkdir -p /var/log/pterodactyl
chown www-data:www-data /var/log/pterodactyl

cat > "$SUPERVISOR_CONF" <<EOF
[program:pterodactyl-discord]
command=php $PANEL_PATH/artisan rolexdev:discord:run
user=www-data
autostart=true
autorestart=true
startretries=3
stderr_logfile=/var/log/pterodactyl/discord-bot.err.log
stdout_logfile=/var/log/pterodactyl/discord-bot.out.log
EOF

supervisorctl reread || true
supervisorctl update || true
supervisorctl start pterodactyl-discord || true

echo "Installation complete!"
