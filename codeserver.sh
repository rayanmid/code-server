#!/bin/bash

# Log file
LOG_FILE="/var/log/setup_script.log"

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Ensure script runs with root privileges
if [[ $EUID -ne 0 ]]; then
    log "This script must be run as root. Please use sudo."
    exit 1
fi

log "Updating package list..."
sudo apt update -y >>"$LOG_FILE" 2>&1 || {
    log "Failed to update package list."
    exit 1
}

# Install Node.js and npm if not installed
if ! command_exists node; then
    log "Installing Node.js and npm..."
    sudo apt install -y nodejs npm >>"$LOG_FILE" 2>&1 || {
        log "Failed to install Node.js and npm."
        exit 1
    }
else
    log "Node.js and npm are already installed."
fi

# Install localtunnel if not installed
if ! command_exists lt; then
    log "Installing localtunnel..."
    npm install -g localtunnel >>"$LOG_FILE" 2>&1 || {
        log "Failed to install localtunnel."
        exit 1
    }
else
    log "localtunnel is already installed."
fi

# Install code-server if not installed
if ! command_exists code-server; then
    log "Installing code-server..."
    curl -fsSL https://code-server.dev/install.sh | sh >>"$LOG_FILE" 2>&1 || {
        log "Failed to install code-server."
        exit 1
    }
else
    log "code-server is already installed."
fi

# Install nano if not installed
if ! command_exists nano; then
    log "Installing nano..."
    sudo apt install -y nano >>"$LOG_FILE" 2>&1 || {
        log "Failed to install nano."
        exit 1
    }
else
    log "nano is already installed."
fi

# Start localtunnel
log "Starting localtunnel..."
lt --port 6070 &> /dev/null &
sleep 5
TUNNEL_URL=$(wget -q -O - https://loca.lt/mytunnelpassword)

if [[ -z $TUNNEL_URL ]]; then
    log "Failed to retrieve localtunnel URL."
    exit 1
fi

log "Localtunnel started successfully with URL: $TUNNEL_URL"

# Start code-server
log "Starting code-server..."
code-server --port 6070 --auth none >>"$LOG_FILE" 2>&1 &

sleep 5
if ! pgrep -x "code-server" > /dev/null; then
    log "Failed to start code-server."
    exit 1
fi

log "Code-server started successfully."

# Display instructions
log "Your code-server is accessible via localtunnel at: $TUNNEL_URL"
log "Script completed successfully!"
