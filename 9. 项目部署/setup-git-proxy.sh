#!/bin/bash

################################################################################
# Git Proxy Server Setup Script
#
# This script automates the setup of various proxy solutions for Git access.
# Supports: SSH Tunnel, SOCKS5 (Dante), HTTP Proxy (Squid), WireGuard VPN
#
# Usage:
#   ./setup-git-proxy.sh [--mode MODE] [--config config.env]
#   ./setup-git-proxy.sh --interactive
#
# Author: Barry Wang
# Created: 2025-11-19
################################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/git-proxy-config.env"
LOG_FILE="${SCRIPT_DIR}/setup-git-proxy.log"

# Configuration variables
PROXY_MODE=""           # ssh-tunnel, socks5, http-proxy, wireguard
PROXY_USER=""           # User to run proxy service
PROXY_PORT=""           # Proxy listening port
SSH_TUNNEL_TYPE=""      # dynamic or local
GITLAB_HOST=""          # GitLab server hostname
GITLAB_PORT="22"        # GitLab SSH port
CLIENT_SETUP="no"       # Generate client setup guide
VPN_NETWORK="10.0.0.0/24"  # WireGuard network

################################################################################
# Helper Functions
################################################################################

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
    log "INFO" "$1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
    log "SUCCESS" "$1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    log "WARNING" "$1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
    log "ERROR" "$1"
}

print_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

print_step() {
    echo -e "${GREEN}▶${NC} $1"
}

prompt_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    local value=""

    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " value
        value=${value:-$default}
    else
        read -p "$prompt: " value
        while [ -z "$value" ]; do
            print_warning "This field is required"
            read -p "$prompt: " value
        done
    fi

    eval "$var_name='$value'"
}

prompt_confirm() {
    local prompt="$1"
    local default="${2:-n}"
    local response

    if [ "$default" = "y" ]; then
        read -p "$prompt [Y/n]: " response
        response=${response:-y}
    else
        read -p "$prompt [y/N]: " response
        response=${response:-n}
    fi

    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

check_command() {
    if command -v "$1" &> /dev/null; then
        print_success "$1 is available"
        return 0
    else
        print_warning "$1 is not installed"
        return 1
    fi
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root"
        print_info "Please run: sudo $0 $@"
        exit 1
    fi
}

################################################################################
# Configuration Functions
################################################################################

interactive_config() {
    print_header "Git Proxy Server Configuration"

    echo "Choose proxy mode:"
    echo "  1) SSH Tunnel (Recommended - Simplest)"
    echo "  2) SOCKS5 Proxy (Dante Server)"
    echo "  3) HTTP/HTTPS Proxy (Squid)"
    echo "  4) WireGuard VPN (Most Complete)"
    echo ""

    local mode_choice
    read -p "Enter choice [1]: " mode_choice
    mode_choice=${mode_choice:-1}

    case "$mode_choice" in
        1)
            PROXY_MODE="ssh-tunnel"
            configure_ssh_tunnel
            ;;
        2)
            PROXY_MODE="socks5"
            configure_socks5
            ;;
        3)
            PROXY_MODE="http-proxy"
            configure_http_proxy
            ;;
        4)
            PROXY_MODE="wireguard"
            configure_wireguard
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac

    # Ask if client setup is needed
    if prompt_confirm "Generate client setup guide?" "y"; then
        CLIENT_SETUP="yes"
    fi
}

configure_ssh_tunnel() {
    print_header "SSH Tunnel Configuration"

    echo "SSH Tunnel doesn't require server-side installation."
    echo "This mode will generate client-side configuration only."
    echo ""

    prompt_input "Proxy server hostname/IP" "" PROXY_SERVER
    prompt_input "SSH username" "$(whoami)" PROXY_USER

    echo ""
    echo "Choose tunnel type:"
    echo "  1) Dynamic port forwarding (SOCKS5 proxy)"
    echo "  2) Local port forwarding (Direct SSH to GitLab)"
    echo ""

    local tunnel_choice
    read -p "Enter choice [1]: " tunnel_choice
    tunnel_choice=${tunnel_choice:-1}

    case "$tunnel_choice" in
        1)
            SSH_TUNNEL_TYPE="dynamic"
            prompt_input "Local SOCKS5 port" "1080" PROXY_PORT
            ;;
        2)
            SSH_TUNNEL_TYPE="local"
            prompt_input "GitLab server hostname" "" GITLAB_HOST
            prompt_input "GitLab SSH port" "22" GITLAB_PORT
            prompt_input "Local forwarding port" "2222" PROXY_PORT
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
}

configure_socks5() {
    print_header "SOCKS5 Proxy Configuration"

    prompt_input "SOCKS5 listening port" "1080" PROXY_PORT
    prompt_input "Service username" "proxy" PROXY_USER
}

configure_http_proxy() {
    print_header "HTTP Proxy Configuration"

    prompt_input "HTTP proxy port" "3128" PROXY_PORT
    prompt_input "HTTPS proxy port" "3129" HTTPS_PORT
}

configure_wireguard() {
    print_header "WireGuard VPN Configuration"

    prompt_input "WireGuard listening port" "51820" PROXY_PORT
    prompt_input "VPN network CIDR" "10.0.0.0/24" VPN_NETWORK
}

save_config() {
    print_info "Saving configuration to $CONFIG_FILE"
    cat > "$CONFIG_FILE" << EOF
# Git Proxy Server Configuration
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

PROXY_MODE="$PROXY_MODE"
PROXY_USER="$PROXY_USER"
PROXY_PORT="$PROXY_PORT"
HTTPS_PORT="$HTTPS_PORT"
SSH_TUNNEL_TYPE="$SSH_TUNNEL_TYPE"
GITLAB_HOST="$GITLAB_HOST"
GITLAB_PORT="$GITLAB_PORT"
PROXY_SERVER="$PROXY_SERVER"
CLIENT_SETUP="$CLIENT_SETUP"
VPN_NETWORK="$VPN_NETWORK"
EOF
    print_success "Configuration saved"
}

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        print_info "Loading configuration from $CONFIG_FILE"
        source "$CONFIG_FILE"
        print_success "Configuration loaded"
        return 0
    fi
    return 1
}

################################################################################
# Setup Functions
################################################################################

setup_ssh_server() {
    print_header "SSH Server Configuration"

    # Ensure SSH is installed
    if ! check_command sshd; then
        print_info "Installing OpenSSH server..."
        apt-get update
        apt-get install -y openssh-server
    fi

    # Enable TCP forwarding
    print_info "Enabling TCP forwarding in SSH config..."

    if ! grep -q "^AllowTcpForwarding yes" /etc/ssh/sshd_config; then
        echo "AllowTcpForwarding yes" >> /etc/ssh/sshd_config
        print_success "TCP forwarding enabled"
    else
        print_info "TCP forwarding already enabled"
    fi

    # Restart SSH service
    systemctl restart sshd
    print_success "SSH server configured and restarted"
}

setup_socks5_proxy() {
    print_header "Installing SOCKS5 Proxy (Dante)"

    # Install Dante
    print_info "Installing Dante SOCKS server..."
    apt-get update
    apt-get install -y dante-server

    # Backup original config
    if [ -f /etc/danted.conf ]; then
        cp /etc/danted.conf /etc/danted.conf.backup
    fi

    # Get network interface
    local iface=$(ip route | grep default | awk '{print $5}' | head -1)
    print_info "Using network interface: $iface"

    # Create configuration
    print_info "Creating Dante configuration..."
    cat > /etc/danted.conf << EOF
# Dante SOCKS5 Server Configuration
# Generated by setup-git-proxy.sh

logoutput: syslog /var/log/danted.log

# Network interface
internal: $iface port = $PROXY_PORT
external: $iface

# Authentication method
clientmethod: none
socksmethod: none

# Access rules
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    protocol: tcp udp
    log: error
}
EOF

    # Enable and start service
    systemctl enable danted
    systemctl restart danted

    # Check status
    if systemctl is-active --quiet danted; then
        print_success "Dante SOCKS5 server is running on port $PROXY_PORT"
    else
        print_error "Failed to start Dante server"
        systemctl status danted
        exit 1
    fi
}

setup_http_proxy() {
    print_header "Installing HTTP Proxy (Squid)"

    # Install Squid
    print_info "Installing Squid proxy server..."
    apt-get update
    apt-get install -y squid apache2-utils

    # Backup original config
    cp /etc/squid/squid.conf /etc/squid/squid.conf.backup

    # Create SSL directory and certificate
    print_info "Generating SSL certificate..."
    mkdir -p /etc/squid/ssl
    openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=squid-proxy" \
        -keyout /etc/squid/ssl/squid.pem \
        -out /etc/squid/ssl/squid.pem
    chown -R proxy:proxy /etc/squid/ssl
    chmod 400 /etc/squid/ssl/squid.pem

    # Create configuration
    print_info "Creating Squid configuration..."
    cat > /etc/squid/squid.conf << EOF
# Squid HTTP Proxy Configuration
# Generated by setup-git-proxy.sh

# HTTP port
http_port $PROXY_PORT

# HTTPS port (optional)
# https_port $HTTPS_PORT cert=/etc/squid/ssl/squid.pem

# Access control
acl localnet src 0.0.0.0/0
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 443
acl Safe_ports port 22
acl CONNECT method CONNECT

# Access rules
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localnet
http_access deny all

# Cache settings
cache_dir ufs /var/spool/squid 1000 16 256
maximum_object_size 100 MB
coredump_dir /var/spool/squid

# Refresh patterns
refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern ^gopher:        1440    0%      1440
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
refresh_pattern .               0       20%     4320
EOF

    # Initialize cache and start service
    print_info "Initializing Squid cache..."
    squid -z

    systemctl enable squid
    systemctl restart squid

    # Check status
    if systemctl is-active --quiet squid; then
        print_success "Squid HTTP proxy is running on port $PROXY_PORT"
    else
        print_error "Failed to start Squid server"
        systemctl status squid
        exit 1
    fi
}

setup_wireguard() {
    print_header "Installing WireGuard VPN"

    # Install WireGuard
    print_info "Installing WireGuard..."
    apt-get update
    apt-get install -y wireguard wireguard-tools

    # Generate server keys
    print_info "Generating WireGuard keys..."
    wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
    chmod 600 /etc/wireguard/server_private.key

    # Generate client keys
    wg genkey | tee /etc/wireguard/client_private.key | wg pubkey > /etc/wireguard/client_public.key
    chmod 600 /etc/wireguard/client_private.key

    # Get keys
    local server_private=$(cat /etc/wireguard/server_private.key)
    local server_public=$(cat /etc/wireguard/server_public.key)
    local client_public=$(cat /etc/wireguard/client_public.key)

    # Get network interface
    local iface=$(ip route | grep default | awk '{print $5}' | head -1)

    # Create server configuration
    print_info "Creating WireGuard server configuration..."
    cat > /etc/wireguard/wg0.conf << EOF
[Interface]
Address = 10.0.0.1/24
ListenPort = $PROXY_PORT
PrivateKey = $server_private
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $iface -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $iface -j MASQUERADE

[Peer]
PublicKey = $client_public
AllowedIPs = 10.0.0.2/32
EOF

    # Enable IP forwarding
    print_info "Enabling IP forwarding..."
    sysctl -w net.ipv4.ip_forward=1
    sysctl -w net.ipv6.conf.all.forwarding=1

    if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
        echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
    fi

    # Start WireGuard
    systemctl enable wg-quick@wg0
    systemctl start wg-quick@wg0

    # Check status
    if systemctl is-active --quiet wg-quick@wg0; then
        print_success "WireGuard VPN is running on port $PROXY_PORT"
        wg show
    else
        print_error "Failed to start WireGuard"
        systemctl status wg-quick@wg0
        exit 1
    fi

    # Save client config for later
    local client_private=$(cat /etc/wireguard/client_private.key)
    cat > /etc/wireguard/client.conf << EOF
[Interface]
PrivateKey = $client_private
Address = 10.0.0.2/24
DNS = 8.8.8.8

[Peer]
PublicKey = $server_public
Endpoint = $(hostname -I | awk '{print $1}'):$PROXY_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

    print_success "WireGuard client config saved to /etc/wireguard/client.conf"
}

generate_client_guide() {
    print_header "Generating Client Setup Guide"

    local guide_file="${SCRIPT_DIR}/client-proxy-setup.md"
    local server_ip=$(hostname -I | awk '{print $1}')

    case "$PROXY_MODE" in
        ssh-tunnel)
            generate_ssh_tunnel_guide "$guide_file" "$server_ip"
            ;;
        socks5)
            generate_socks5_guide "$guide_file" "$server_ip"
            ;;
        http-proxy)
            generate_http_proxy_guide "$guide_file" "$server_ip"
            ;;
        wireguard)
            generate_wireguard_guide "$guide_file" "$server_ip"
            ;;
    esac

    print_success "Client setup guide: $guide_file"
}

generate_ssh_tunnel_guide() {
    local guide_file=$1
    local server_ip=$2

    cat > "$guide_file" << EOF
# SSH Tunnel Client Setup Guide

## Server Information
- **Proxy Server**: ${PROXY_SERVER:-$server_ip}
- **SSH Username**: $PROXY_USER
- **Tunnel Type**: $SSH_TUNNEL_TYPE

## Setup Steps

### 1. Configure SSH Key Authentication

\`\`\`bash
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -C "git-proxy"

# Copy public key to proxy server
ssh-copy-id $PROXY_USER@${PROXY_SERVER:-$server_ip}

# Test connection
ssh $PROXY_USER@${PROXY_SERVER:-$server_ip}
\`\`\`

EOF

    if [ "$SSH_TUNNEL_TYPE" = "dynamic" ]; then
        cat >> "$guide_file" << EOF
### 2. Start SSH Tunnel (Dynamic Port Forwarding)

\`\`\`bash
# Start tunnel in foreground
ssh -D $PROXY_PORT -C -N $PROXY_USER@${PROXY_SERVER:-$server_ip}

# Or start in background
ssh -D $PROXY_PORT -C -N -f $PROXY_USER@${PROXY_SERVER:-$server_ip}

# Using autossh for auto-reconnect (recommended)
autossh -M 0 -f -N -D $PROXY_PORT -C \\
    -o "ServerAliveInterval 30" \\
    -o "ServerAliveCountMax 3" \\
    $PROXY_USER@${PROXY_SERVER:-$server_ip}
\`\`\`

### 3. Configure Git to Use SOCKS5 Proxy

\`\`\`bash
# For HTTPS repositories
git config --global http.proxy 'socks5://127.0.0.1:$PROXY_PORT'
git config --global https.proxy 'socks5://127.0.0.1:$PROXY_PORT'

# For SSH repositories (add to ~/.ssh/config)
cat >> ~/.ssh/config << 'SSHEOF'
Host gitlab.your-company.com
    ProxyCommand nc -X 5 -x 127.0.0.1:$PROXY_PORT %h %p
SSHEOF
\`\`\`

### 4. Test Connection

\`\`\`bash
# Test HTTPS
git ls-remote https://gitlab.your-company.com/group/repo.git

# Test SSH
ssh -T git@gitlab.your-company.com
\`\`\`

### 5. Create Systemd Service (Optional, Linux only)

\`\`\`bash
sudo tee /etc/systemd/system/git-ssh-tunnel.service << 'SERVICEEOF'
[Unit]
Description=SSH Tunnel for Git Proxy
After=network.target

[Service]
Type=simple
User=$(whoami)
ExecStart=/usr/bin/ssh -D $PROXY_PORT -C -N -o ServerAliveInterval=30 -o ServerAliveCountMax=3 $PROXY_USER@${PROXY_SERVER:-$server_ip}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICEEOF

sudo systemctl daemon-reload
sudo systemctl enable git-ssh-tunnel
sudo systemctl start git-ssh-tunnel
sudo systemctl status git-ssh-tunnel
\`\`\`

EOF
    else
        cat >> "$guide_file" << EOF
### 2. Start SSH Tunnel (Local Port Forwarding)

\`\`\`bash
# Forward local port $PROXY_PORT to $GITLAB_HOST:$GITLAB_PORT
ssh -L $PROXY_PORT:$GITLAB_HOST:$GITLAB_PORT $PROXY_USER@${PROXY_SERVER:-$server_ip} -N -f

# Using autossh for auto-reconnect
autossh -M 0 -f -N -L $PROXY_PORT:$GITLAB_HOST:$GITLAB_PORT \\
    -o "ServerAliveInterval 30" \\
    -o "ServerAliveCountMax 3" \\
    $PROXY_USER@${PROXY_SERVER:-$server_ip}
\`\`\`

### 3. Configure SSH to Use Local Port

\`\`\`bash
# Add to ~/.ssh/config
cat >> ~/.ssh/config << 'SSHEOF'
Host gitlab-proxy
    HostName 127.0.0.1
    Port $PROXY_PORT
    User git
SSHEOF
\`\`\`

### 4. Use Proxy for Git Operations

\`\`\`bash
# Clone using proxy
git clone gitlab-proxy:your-group/your-project.git

# Update existing repository
cd your-project
git remote set-url origin gitlab-proxy:your-group/your-project.git
\`\`\`

EOF
    fi

    cat >> "$guide_file" << EOF
## Uninstall/Cleanup

\`\`\`bash
# Kill SSH tunnel
pkill -f "ssh -D $PROXY_PORT"

# Remove Git proxy config
git config --global --unset http.proxy
git config --global --unset https.proxy

# Remove systemd service
sudo systemctl stop git-ssh-tunnel
sudo systemctl disable git-ssh-tunnel
sudo rm /etc/systemd/system/git-ssh-tunnel.service
\`\`\`

---
Generated: $(date '+%Y-%m-%d %H:%M:%S')
EOF
}

generate_socks5_guide() {
    local guide_file=$1
    local server_ip=$2

    cat > "$guide_file" << EOF
# SOCKS5 Proxy Client Setup Guide

## Server Information
- **Proxy Server**: $server_ip
- **SOCKS5 Port**: $PROXY_PORT

## Setup Steps

### 1. Configure Git to Use SOCKS5 Proxy

\`\`\`bash
# For HTTPS repositories
git config --global http.proxy "socks5://$server_ip:$PROXY_PORT"
git config --global https.proxy "socks5://$server_ip:$PROXY_PORT"
\`\`\`

### 2. Configure SSH to Use SOCKS5 Proxy (for SSH Git URLs)

\`\`\`bash
# Add to ~/.ssh/config
cat >> ~/.ssh/config << 'EOF'
Host gitlab.your-company.com
    ProxyCommand nc -X 5 -x $server_ip:$PROXY_PORT %h %p
EOF
\`\`\`

### 3. Test Connection

\`\`\`bash
# Test SOCKS5 proxy
curl --socks5 $server_ip:$PROXY_PORT https://www.google.com

# Test Git
git ls-remote https://gitlab.your-company.com/group/repo.git
\`\`\`

## Cleanup

\`\`\`bash
# Remove proxy configuration
git config --global --unset http.proxy
git config --global --unset https.proxy
\`\`\`

---
Generated: $(date '+%Y-%m-%d %H:%M:%S')
EOF
}

generate_http_proxy_guide() {
    local guide_file=$1
    local server_ip=$2

    cat > "$guide_file" << EOF
# HTTP Proxy Client Setup Guide

## Server Information
- **Proxy Server**: $server_ip
- **HTTP Port**: $PROXY_PORT

## Setup Steps

### 1. Configure Git to Use HTTP Proxy

\`\`\`bash
# Global configuration
git config --global http.proxy "http://$server_ip:$PROXY_PORT"
git config --global https.proxy "http://$server_ip:$PROXY_PORT"
\`\`\`

### 2. Test Connection

\`\`\`bash
# Test HTTP proxy
curl -x http://$server_ip:$PROXY_PORT https://www.google.com

# Test Git
git ls-remote https://gitlab.your-company.com/group/repo.git
\`\`\`

### 3. Use Environment Variables (Alternative)

\`\`\`bash
# Add to ~/.bashrc or ~/.zshrc
export http_proxy="http://$server_ip:$PROXY_PORT"
export https_proxy="http://$server_ip:$PROXY_PORT"
\`\`\`

## Cleanup

\`\`\`bash
# Remove proxy configuration
git config --global --unset http.proxy
git config --global --unset https.proxy

# Remove environment variables
unset http_proxy
unset https_proxy
\`\`\`

---
Generated: $(date '+%Y-%m-%d %H:%M:%S')
EOF
}

generate_wireguard_guide() {
    local guide_file=$1
    local server_ip=$2

    cat > "$guide_file" << EOF
# WireGuard VPN Client Setup Guide

## Server Information
- **VPN Server**: $server_ip
- **VPN Port**: $PROXY_PORT
- **VPN Network**: $VPN_NETWORK

## Client Configuration File

The WireGuard client configuration has been saved to:
\`/etc/wireguard/client.conf\`

Copy this file to your local machine.

## Setup Steps

### For macOS

\`\`\`bash
# Install WireGuard
brew install wireguard-tools

# Copy client config
scp root@$server_ip:/etc/wireguard/client.conf /usr/local/etc/wireguard/wg0.conf

# Start VPN
sudo wg-quick up wg0

# Stop VPN
sudo wg-quick down wg0

# Or use WireGuard GUI app from App Store
\`\`\`

### For Linux

\`\`\`bash
# Install WireGuard
sudo apt install wireguard  # Ubuntu/Debian
sudo yum install wireguard-tools  # CentOS/RHEL

# Copy client config
sudo scp root@$server_ip:/etc/wireguard/client.conf /etc/wireguard/wg0.conf

# Start VPN
sudo wg-quick up wg0

# Enable on boot
sudo systemctl enable wg-quick@wg0

# Check status
sudo wg show
\`\`\`

### For Windows

1. Download WireGuard from https://www.wireguard.com/install/
2. Install the application
3. Copy the client configuration file content
4. Import the configuration in WireGuard GUI
5. Activate the tunnel

## Test Connection

\`\`\`bash
# Check VPN status
sudo wg show

# Test internet connectivity through VPN
ping 10.0.0.1

# Test Git access
git ls-remote https://gitlab.your-company.com/group/repo.git
\`\`\`

## Troubleshooting

\`\`\`bash
# View VPN logs
sudo journalctl -u wg-quick@wg0 -f

# Restart VPN
sudo wg-quick down wg0 && sudo wg-quick up wg0

# Check routing
ip route show
\`\`\`

---
Generated: $(date '+%Y-%m-%d %H:%M:%S')
EOF
}

################################################################################
# Main Setup Flow
################################################################################

run_setup() {
    print_header "Git Proxy Server Setup - $PROXY_MODE"

    case "$PROXY_MODE" in
        ssh-tunnel)
            # SSH tunnel is client-side only, configure server for forwarding
            setup_ssh_server
            print_success "SSH server configured for tunneling"
            print_info "No additional server-side setup required"
            ;;
        socks5)
            setup_socks5_proxy
            ;;
        http-proxy)
            setup_http_proxy
            ;;
        wireguard)
            setup_wireguard
            ;;
        *)
            print_error "Unknown proxy mode: $PROXY_MODE"
            exit 1
            ;;
    esac

    if [ "$CLIENT_SETUP" = "yes" ]; then
        generate_client_guide
    fi

    print_header "Setup Complete!"
    print_success "Git proxy server is ready"

    echo ""
    print_info "Server Details:"
    print_info "  - Mode: $PROXY_MODE"
    print_info "  - Port: $PROXY_PORT"
    if [ "$PROXY_MODE" != "ssh-tunnel" ]; then
        print_info "  - Status: $(systemctl is-active dante 2>/dev/null || systemctl is-active squid 2>/dev/null || systemctl is-active wg-quick@wg0 2>/dev/null)"
    fi

    echo ""
    print_info "Next Steps:"
    if [ "$CLIENT_SETUP" = "yes" ]; then
        print_info "  1. Review client setup guide: ${SCRIPT_DIR}/client-proxy-setup.md"
    fi
    print_info "  2. Configure your local Git client"
    print_info "  3. Test Git operations"

    echo ""
    print_success "Setup completed successfully!"
}

################################################################################
# Main Entry Point
################################################################################

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Setup a Git proxy server for accessing GitLab through a relay server.

Options:
    -h, --help              Show this help message
    -i, --interactive       Run in interactive mode (default)
    -m, --mode MODE         Proxy mode: ssh-tunnel, socks5, http-proxy, wireguard
    -c, --config FILE       Load configuration from file

Examples:
    # Interactive setup
    sudo $0 --interactive

    # Setup SOCKS5 proxy directly
    sudo $0 --mode socks5

    # Use existing configuration
    sudo $0 --config /path/to/config.env

EOF
}

main() {
    local mode="interactive"
    local preset_mode=""

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -i|--interactive)
                mode="interactive"
                shift
                ;;
            -m|--mode)
                preset_mode="$2"
                mode="preset"
                shift 2
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                mode="config"
                shift 2
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Initialize log
    log "INFO" "=== Setup Started ==="

    # Load or create configuration
    case $mode in
        interactive)
            interactive_config
            save_config
            ;;
        preset)
            PROXY_MODE="$preset_mode"
            case "$PROXY_MODE" in
                socks5) PROXY_PORT=1080 ;;
                http-proxy) PROXY_PORT=3128 ;;
                wireguard) PROXY_PORT=51820 ;;
                *) print_error "Invalid mode: $PROXY_MODE"; exit 1 ;;
            esac
            CLIENT_SETUP="yes"
            ;;
        config)
            if load_config; then
                print_info "Using configuration from $CONFIG_FILE"
            else
                print_error "Configuration file not found: $CONFIG_FILE"
                exit 1
            fi
            ;;
    esac

    # Check root privileges for server-side setup
    if [ "$PROXY_MODE" != "ssh-tunnel" ]; then
        check_root
    fi

    # Run setup
    run_setup

    log "INFO" "=== Setup Finished ==="
}

# Run main function
main "$@"
