#!/bin/bash

# Exit on any error
set -e

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run with sudo"
   exit 1
fi

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Configure automatic login and remove password
configure_autologin() {
    local USERNAME=$1

    # Remove user password
    log "Removing password for user $USERNAME"
    passwd -d "$USERNAME"

    # Configure LightDM for automatic login
    log "Configuring LightDM for automatic login"
    
    # Ensure lightdm configuration directory exists
    mkdir -p /etc/lightdm

    # Create or modify lightdm configuration
    cat > /etc/lightdm/lightdm.conf << EOL
[Seat:*]
autologin-user=$USERNAME
autologin-user-timeout=0
EOL

    # Configure systemd to autologin on tty1
    mkdir -p /etc/systemd/system/getty@tty1.service.d/
    cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOL
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USERNAME --noclear %I \$TERM
EOL

    log "Automatic login configured"
}

# Install necessary packages
install_packages() {
    log "Installing necessary packages"
    apt-get update
    apt-get install -y \
        kodi \
        xserver-xorg \
        xinit \
        lightdm
}

# Configure Kodi autostart
configure_kodi_autostart() {
    local USERNAME=$1

    # Create Kodi autostart file
    mkdir -p "/home/$USERNAME/.config/autostart"
    cat > "/home/$USERNAME/.config/autostart/kodi.desktop" << EOL
[Desktop Entry]
Type=Application
Name=Kodi
Exec=kodi
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOL

    # Set permissions
    chown "$USERNAME:$USERNAME" "/home/$USERNAME/.config/autostart/kodi.desktop"

    # Enable Kodi service
    systemctl set-default graphical.target
    systemctl enable kodi

    log "Kodi autostart configured"
}

# Comprehensive package cleanup
cleanup_packages() {
    log "Starting comprehensive package cleanup"
    
    # List of packages to remove
    local packages_to_remove=(
        # Desktop environments
        "gnome-*"
        "kde-*"
        "xfce4-*"
        "mate-*"
        "lxde-*"
        "cinnamon-*"
        "budgie-*"
        "unity-*"

        # Office and productivity
        "libreoffice-*"
        "thunderbird"
        "firefox"
        "transmission-*"
        "rhythmbox"
        "totem"

        # System utilities
        "cups"
        "printer-driver-*"
        "network-manager-gnome"
        
        # Development tools
        "python3"
        "python3-pip"
        "build-essential"
        "git"
        "nodejs"
        "npm"
        "gcc"
        "g++"
        "perl"
        "ruby"
    )

    # Remove packages
    for pkg in "${packages_to_remove[@]}"; do
        apt-get remove --purge -y $pkg || true
    done

    # Additional cleanup steps
    log "Performing system cleanup"
    apt-get autoremove -y
    apt-get autoclean
    apt-get clean

    # Remove unnecessary configuration files
    find /etc -type f \( -name "*.dpkg-old" -o -name "*.dpkg-new" \) -delete

    # Clear package manager cache
    rm -rf /var/cache/apt/archives/*

    log "Package cleanup completed"
}

# Main function
main() {
    # Prompt for username
    read -p "Enter your username: " USERNAME

    # Configure automatic login first
    configure_autologin "$USERNAME"

    # Install necessary packages
    install_packages

    # Configure Kodi autostart
    configure_kodi_autostart "$USERNAME"

    # Final package cleanup
    cleanup_packages

    log "Setup completed. Rebooting in 5 seconds..."
    sleep 5
    reboot
}

# Run main function
main
