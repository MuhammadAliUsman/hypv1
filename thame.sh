#!/bin/bash

# =========================================
# Pterodactyl Theme Installer (Stellar & Enigma)
# =========================================

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Theme URLs
STELLAR_URL="https://github.com/DITZZ112/fox/raw/main/stellar.zip"
ENIGMA_URL="https://github.com/DITZZ112/fox/raw/main/enigma.zip"

# Temporary directory
TEMP_DIR="/root/pterodactyl_temp"

# Welcome message
welcome() {
    clear
    echo -e "${BLUE}==============================================="
    echo "      PTERODACTYL THEME INSTALLER"
    echo -e "===============================================${NC}"
    echo ""
    sleep 2
}

# Install jq (optional)
install_jq() {
    echo -e "${BLUE}Installing jq...${NC}"
    sudo apt update && sudo apt install -y jq
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}jq installed successfully${NC}"
    else
        echo -e "${RED}Failed to install jq${NC}"
        exit 1
    fi
}

# Install theme function
install_theme() {
    THEME_NAME=$1
    THEME_URL=$2

    echo -e "${BLUE}Installing $THEME_NAME theme...${NC}"

    # Remove old temp dir
    sudo rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"

    # Download and unzip theme
    wget -q "$THEME_URL" -O "$TEMP_DIR/theme.zip"
    unzip -o "$TEMP_DIR/theme.zip" -d "$TEMP_DIR"

    # Remove old Pterodactyl folder
    sudo rm -rf /var/www/pterodactyl

    # Copy extracted pterodactyl folder directly
    sudo cp -rfT "$TEMP_DIR/pterodactyl" /var/www/pterodactyl

    # Install NodeJS & Yarn
    curl -sL https://deb.nodesource.com/setup_16.x | sudo -E bash -
    sudo apt install -y nodejs
    sudo npm i -g yarn

    # Build frontend
    cd /var/www/pterodactyl || exit
    yarn add react-feather
    php artisan migrate
    yarn build:production
    php artisan view:clear

    # Cleanup
    sudo rm -rf "$TEMP_DIR"

    echo -e "${GREEN}$THEME_NAME theme installed successfully!${NC}"
    sleep 2
}

# Main menu
main_menu() {
    while true; do
        clear
        echo -e "${BLUE}==============================${NC}"
        echo "     SELECT THEME TO INSTALL"
        echo -e "${BLUE}==============================${NC}"
        echo "1) Stellar"
        echo "2) Enigma"
        echo "x) Exit"
        read -rp "Enter choice (1/2/x): " CHOICE

        case "$CHOICE" in
            1)
                install_theme "Stellar" "$STELLAR_URL"
                ;;
            2)
                install_theme "Enigma" "$ENIGMA_URL"
                ;;
            x)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice, try again.${NC}"
                ;;
        esac
    done
}

# =========================================
# Script Execution
# =========================================
welcome
install_jq
main_menu
