#!/bin/bash

# =============================================
#  HyperV1 Personal Theme Installer
#  Author: RolexDev Team (for DragonGamer)
# =============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
USE_LOCAL_FILES=1

# -----------------------------
# Auto-detect Pterodactyl path
# -----------------------------
if [ -d "/var/www/pterodactyl" ]; then
    PANEL_PATH="/var/www/pterodactyl"
else
    PANEL_PATH=$(find /var/www -maxdepth 2 -type d -name "pterodactyl" | head -1)
    if [[ -z "$PANEL_PATH" ]]; then
        echo "Error: Could not find Pterodactyl installation under /var/www."
        exit 1
    fi
fi
echo "Detected Pterodactyl path: $PANEL_PATH"

# -----------------------------
# Remove old theme files
# -----------------------------
echo "Removing old HyperV1 theme files..."
rm -rf "$PANEL_PATH/app" \
       "$PANEL_PATH/public/rolexdev" \
       "$PANEL_PATH/public/assets/hyper*" \
       "$PANEL_PATH/hyper_fetch.sh" \
       "$PANEL_PATH/hyper_auto_update.sh" \
       "$PANEL_PATH/hyper_auto_update_ioncube.sh"

# -----------------------------
# Install HyperV1 theme from local tar
# -----------------------------
TAR_FILE="$SCRIPT_DIR/Hyperv1.tar"

if [[ ! -f "$TAR_FILE" ]]; then
    echo "Error: Hyperv1.tar not found in ${SCRIPT_DIR}"
    exit 1
fi

echo "Installing HyperV1 theme..."
tar -xf "$TAR_FILE" -C "$PANEL_PATH" --overwrite

# -----------------------------
# Set license info (personal)
# -----------------------------
LICENSE_NAME="DʀᴀɢᴏɴGᴀᴍᴇʀ"
LICENSE_EMAIL="dragondgamer432@gmail.com"

echo "Setting license info in panel..."
# Update your settings in database via artisan tinker
php "$PANEL_PATH/artisan" tinker <<PHP
DB::table('settings')->updateOrInsert(
    ['key' => 'hyper_license_name'],
    ['value' => '$LICENSE_NAME']
);
DB::table('settings')->updateOrInsert(
    ['key' => 'hyper_license_email'],
    ['value' => '$LICENSE_EMAIL']
);
PHP

# -----------------------------
# Set permissions
# -----------------------------
echo "Setting permissions..."
chown -R www-data:www-data "$PANEL_PATH"
chmod -R 755 "$PANEL_PATH"/storage/* "$PANEL_PATH"/bootstrap/cache/*

# -----------------------------
# Laravel optimization
# -----------------------------
echo "Clearing Laravel cache and optimizing..."
cd "$PANEL_PATH"
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear
php artisan optimize
php artisan queue:restart

# -----------------------------
# Ensure PHP 8.4 (optional)
# -----------------------------
if ! php -v | grep -q "8.4"; then
    echo "Warning: PHP 8.4 not detected. Theme may require PHP 8.4."
fi

# -----------------------------
# Setup Supervisor for Discord bot (if exists)
# -----------------------------
DISCORD_ARTISAN="$PANEL_PATH/artisan rolexdev:discord:run"
if [[ -f "$DISCORD_ARTISAN" ]]; then
    echo "Configuring Supervisor for Discord bot..."
    if ! command -v supervisorctl &>/dev/null; then
        apt-get update -y
        apt-get install -y supervisor
        systemctl enable supervisor
        systemctl start supervisor
    fi

    LOG_DIR="/var/log/pterodactyl"
    mkdir -p "$LOG_DIR"
    chown www-data:www-data "$LOG_DIR"

    CONFIG_FILE="/etc/supervisor/conf.d/pterodactyl-discord.conf"
    cat <<EOF > "$CONFIG_FILE"
[program:pterodactyl-discord]
command=php $DISCORD_ARTISAN
user=www-data
autostart=true
autorestart=true
startretries=3
stderr_logfile=$LOG_DIR/discord-bot.err.log
stderr_logfile_maxbytes=10MB
stderr_logfile_backups=3
stdout_logfile=$LOG_DIR/discord-bot.out.log
stdout_logfile_maxbytes=10MB
stdout_logfile_backups=3
EOF

    supervisorctl reread || true
    supervisorctl update || true
    supervisorctl restart pterodactyl-discord || true
fi

# -----------------------------
# Setup logrotate
# -----------------------------
LOGROTATE_FILE="/etc/logrotate.d/pterodactyl"
echo "Configuring logrotate..."
cat <<LOGROTATE > "$LOGROTATE_FILE"
/var/log/pterodactyl/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}

/var/www/pterodactyl/storage/logs/laravel-*.log {
    daily
    size 50M
    rotate 3
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    su www-data www-data
}
LOGROTATE

logrotate -f "$LOGROTATE_FILE" 2>/dev/null || true

echo ""
echo "======================================"
echo " HyperV1 Theme installed successfully!"
echo " License: $LICENSE_NAME <$LICENSE_EMAIL>"
echo " Pterodactyl path: $PANEL_PATH"
echo "======================================"
