#!/bin/bash

# Set default values
USERNAME="user"
PASSWORD="root"
DESKTOP_ENV="gnome"
CHROME_REMOTE_DESKTOP_URL="https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb"
LOG_FILE="$(pwd)/rdp.log"

# Function to log messages
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to handle errors
error_exit() {
    log "Error: $1" >&2
    exit 1
}

# Function to install a package
install_package() {
    PACKAGE_URL=$1
    log "Downloading $PACKAGE_URL"
    wget -q --show-progress "$PACKAGE_URL" -O "$(basename $PACKAGE_URL)" 2>&1 | tee -a "$LOG_FILE" || error_exit "Failed to download $PACKAGE_URL"
    log "Installing $(basename $PACKAGE_URL)"
    sudo dpkg --install "$(basename $PACKAGE_URL)" 2>&1 | tee -a "$LOG_FILE" || error_exit "Failed to install $(basename $PACKAGE_URL)"
    log "Fixing broken dependencies"
    sudo apt-get install --fix-broken -y 2>&1 | tee -a "$LOG_FILE" || error_exit "Failed to fix dependencies"
    rm "$(basename $PACKAGE_URL)"
}

# Installation steps
log "Starting installation"

# Step 1: Create user
log "Creating user '$USERNAME'"
if id -u "$USERNAME" >/dev/null 2>&1; then
    log "User '$USERNAME' already exists. Skipping user creation."
else
    sudo useradd -m "$USERNAME" 2>&1 | tee -a "$LOG_FILE" || error_exit "Failed to create user $USERNAME"
    echo "$USERNAME:$PASSWORD" | sudo chpasswd 2>&1 | tee -a "$LOG_FILE" || error_exit "Failed to set password for user $USERNAME"
    sudo usermod -s /bin/bash "$USERNAME" 2>&1 | tee -a "$LOG_FILE"
fi

# Step 2: Update and upgrade the system
log "Updating and upgrading the system"
sudo apt-get update -y 2>&1 | tee -a "$LOG_FILE" || error_exit "Failed to update package list"
log "Package list updated"
sudo apt-get upgrade -y 2>&1 | tee -a "$LOG_FILE" || error_exit "Failed to upgrade packages"
log "Packages upgraded"

log "Fixing broken dependencies"
sudo apt --fix-broken install -y 2>&1 | tee -a "$LOG_FILE" || error_exit "Failed to fix broken dependencies"

# Step 3: Install dependencies for Chrome Remote Desktop
log "Installing dependencies for Chrome Remote Desktop"
sudo apt-get install -y xserver-xorg-video-dummy xbase-clients python3-packaging python3-psutil python3-xdg pipewire 2>&1 | tee -a "$LOG_FILE" || error_exit "Failed to install dependencies for Chrome Remote Desktop"
log "Dependencies for Chrome Remote Desktop installed"

# Step 4: Install Chrome Remote Desktop
log "Installing Chrome Remote Desktop"
install_package "$CHROME_REMOTE_DESKTOP_URL"

# Step 5: Install the selected desktop environment
log "Installing $DESKTOP_ENV desktop environment"
case $DESKTOP_ENV in
    xfce4)
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y xfce4 desktop-base dbus-x11 xscreensaver 2>&1 | tee -a "$LOG_FILE" || error_exit "Failed to install XFCE"
        log "XFCE desktop environment installed"
        SESSION_CMD="/usr/bin/xfce4-session"
        ;;
    gnome)
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ubuntu-desktop 2>&1 | tee -a "$LOG_FILE" || error_exit "Failed to install GNOME"
        log "GNOME desktop environment installed"
        SESSION_CMD="/usr/bin/gnome-session"
        ;;
    kde-plasma-desktop)
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y kde-plasma-desktop 2>&1 | tee -a "$LOG_FILE" || error_exit "Failed to install KDE"
        log "KDE desktop environment installed"
        SESSION_CMD="/usr/bin/startplasma-x11"
        ;;
    cinnamon)
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y cinnamon-desktop-environment 2>&1 | tee -a "$LOG_FILE" || error_exit "Failed to install Cinnamon"
        log "Cinnamon desktop environment installed"
        SESSION_CMD="/usr/bin/cinnamon-session"
        ;;
    *)
        error_exit "Invalid desktop environment specified: $DESKTOP_ENV"
        ;;
esac

# Step 6: Set up Chrome Remote Desktop session
log "Setting up Chrome Remote Desktop session"
sudo bash -c "echo 'exec /etc/X11/Xsession $SESSION_CMD' > /etc/chrome-remote-desktop-session" 2>&1 | tee -a "$LOG_FILE" || error_exit "Failed to configure Chrome Remote Desktop session"
log "Chrome Remote Desktop session configured"

# Step 7: Disable unused services
log "Disabling unused services (e.g., lightdm)"
sudo systemctl disable lightdm.service 2>&1 | tee -a "$LOG_FILE" || log "Warning: lightdm.service may not exist, skipping."
log "Unused services disabled"

# Final log
log "Installation completed successfully"