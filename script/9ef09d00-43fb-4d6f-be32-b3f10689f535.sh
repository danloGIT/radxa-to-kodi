#!/bin/bash

# Enable strict error handling
set -euo pipefail

# Error trap to provide debugging information
trap 'log "Error occurred on line $LINENO. Exiting."; exit 1' ERR

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Ensure the script is run as root
if [[ $(id -u) -ne 0 ]]; then
    log "This script must be run as root."
    exit 1
fi

# Update the system immediately
log "Updating the system..."
apt update && apt upgrade -y

# Prompt for the username
log "Prompting for username..."
echo "Please enter the username to be used for auto-login and Kodi:"
read -r USERNAME

# Check if the user exists
if ! id "$USERNAME" &>/dev/null; then
    log "User $USERNAME does not exist. Please create the user and run the script again."
    exit 1
fi

# Remove the user's password to enable password-less login
log "Removing password for user $USERNAME"
passwd -d "$USERNAME"

# Install necessary dependencies
log "Installing necessary packages..."
apt install -y kodi xserver-xorg xserver-xorg-legacy alsa-utils pulseaudio curl wget bluetooth rfkill lightdm

# Configure LightDM for automatic login
log "Configuring LightDM for automatic login"
mkdir -p /etc/lightdm
cat > /etc/lightdm/lightdm.conf <<EOL
[Seat:*]
autologin-user=$USERNAME
autologin-user-timeout=0
EOL

# Configure systemd to autologin on tty1
log "Configuring systemd for automatic login"
mkdir -p /etc/systemd/system/getty@tty1.service.d/
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOL
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USERNAME --noclear %I \$TERM
EOL

# Set up Kodi to start automatically
log "Setting up Kodi as an auto-start application..."
mkdir -p "/home/$USERNAME/.config/autostart"
cat > "/home/$USERNAME/.config/autostart/kodi.desktop" <<EOL
[Desktop Entry]
Type=Application
Name=Kodi
Exec=kodi
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOL
chown "$USERNAME:$USERNAME" "/home/$USERNAME/.config/autostart/kodi.desktop"

# Enable Kodi service
log "Enabling Kodi system service"
systemctl set-default graphical.target
systemctl enable kodi

# Allow Xorg to run without root permissions
log "Adjusting Xorg configuration..."
sed -i 's/# needs_root_rights = yes/needs_root_rights = yes/' /etc/X11/Xwrapper.config || echo "needs_root_rights = yes" >> /etc/X11/Xwrapper.config

# Remove unnecessary packages
log "Removing unnecessary packages..."
declare -a packages_to_remove=(
    "gnome-*" "kde-*" "xfce4-*" "mate-*" "lxde-*" "cinnamon-*" "budgie-*" "unity-*"
    "libreoffice-*" "thunderbird" "firefox" "transmission-*" "rhythmbox" "totem"
    "cups" "printer-driver-*" "network-manager-gnome"
    "python3" "python3-pip" "build-essential" "git" "nodejs" "npm" "gcc" "g++" "perl" "ruby"
)
for pkg in "${packages_to_remove[@]}"; do
    apt-get remove --purge -y $pkg || true
done

log "Performing system cleanup"
apt autoremove -y
apt autoclean
apt clean
rm -rf /var/cache/apt/archives/*

# Optimize boot time
log "Optimizing boot time..."
systemctl disable NetworkManager-wait-online.service
systemctl mask systemd-networkd-wait-online.service

# Completion message
log "Setup completed successfully! Rebooting the system in 5 seconds..."
sleep 5
reboot
