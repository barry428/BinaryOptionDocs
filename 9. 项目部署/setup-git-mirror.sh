#!/bin/bash

################################################################################
# Git Mirror Server Setup Script
#
# This script automates the setup of a Git mirror server that acts as a
# relay between local development and remote GitLab.
#
# Usage:
#   ./setup-git-mirror.sh [--config config.env]
#   ./setup-git-mirror.sh --interactive
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
NC='\033[0m' # No Color

# Default values
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/git-mirror-config.env"
LOG_FILE="${SCRIPT_DIR}/setup-git-mirror.log"

# Configuration variables
GIT_USER=""
REPO_NAME=""
REPO_PATH=""
REMOTE_GITLAB_URL=""
SSH_KEY_PATH=""
CREATE_GIT_USER=""
MIRROR_MODE=""  # hook or cron
SYNC_INTERVAL=""  # for cron mode

################################################################################
# Helper Functions
################################################################################

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

print_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
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
    echo "========================================"
    echo "$1"
    echo "========================================"
    echo ""
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
    local cmd=$1
    if ! command -v "$cmd" &> /dev/null; then
        print_error "$cmd is not installed"
        return 1
    fi
    print_success "$cmd is available"
    return 0
}

################################################################################
# Configuration Functions
################################################################################

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        print_info "Loading configuration from $CONFIG_FILE"
        source "$CONFIG_FILE"
        print_success "Configuration loaded"
        return 0
    fi
    return 1
}

save_config() {
    print_info "Saving configuration to $CONFIG_FILE"
    cat > "$CONFIG_FILE" << EOF
# Git Mirror Server Configuration
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

GIT_USER="$GIT_USER"
REPO_NAME="$REPO_NAME"
REPO_PATH="$REPO_PATH"
REMOTE_GITLAB_URL="$REMOTE_GITLAB_URL"
SSH_KEY_PATH="$SSH_KEY_PATH"
CREATE_GIT_USER="$CREATE_GIT_USER"
MIRROR_MODE="$MIRROR_MODE"
SYNC_INTERVAL="$SYNC_INTERVAL"
EOF
    print_success "Configuration saved"
}

interactive_config() {
    print_header "Git Mirror Server Configuration"

    print_info "This script will set up a Git mirror server"
    echo ""

    # Git user
    if prompt_confirm "Do you want to create a dedicated 'git' user?" "y"; then
        CREATE_GIT_USER="yes"
        GIT_USER="git"
    else
        CREATE_GIT_USER="no"
        prompt_input "Enter the username to use" "$(whoami)" GIT_USER
    fi

    # Repository name
    prompt_input "Enter repository name" "BinaryOption" REPO_NAME

    # Repository path
    local default_path="/home/$GIT_USER/repositories"
    if [ "$GIT_USER" = "$(whoami)" ]; then
        default_path="$HOME/repositories"
    fi
    prompt_input "Enter repository path" "$default_path" REPO_PATH

    # Remote GitLab URL
    echo ""
    print_info "Enter the remote GitLab repository URL"
    print_info "Examples:"
    print_info "  - SSH: git@gitlab.example.com:group/project.git"
    print_info "  - HTTPS: https://gitlab.example.com/group/project.git"
    prompt_input "Remote GitLab URL" "" REMOTE_GITLAB_URL

    # SSH key
    echo ""
    local default_ssh_key="/home/$GIT_USER/.ssh/id_ed25519"
    if [ "$GIT_USER" = "$(whoami)" ]; then
        default_ssh_key="$HOME/.ssh/id_ed25519"
    fi
    prompt_input "SSH key path" "$default_ssh_key" SSH_KEY_PATH

    # Mirror mode
    echo ""
    print_info "Choose synchronization mode:"
    print_info "  1) Git Hook (recommended) - Automatic sync on push"
    print_info "  2) Cron Job - Scheduled sync"

    local mode_choice
    read -p "Enter choice [1]: " mode_choice
    mode_choice=${mode_choice:-1}

    case "$mode_choice" in
        1)
            MIRROR_MODE="hook"
            ;;
        2)
            MIRROR_MODE="cron"
            prompt_input "Enter sync interval in minutes" "5" SYNC_INTERVAL
            ;;
        *)
            print_error "Invalid choice, using Git Hook mode"
            MIRROR_MODE="hook"
            ;;
    esac

    # Confirm configuration
    echo ""
    print_header "Configuration Summary"
    echo "Git User:         $GIT_USER"
    echo "Create User:      $CREATE_GIT_USER"
    echo "Repository Name:  $REPO_NAME"
    echo "Repository Path:  $REPO_PATH/$REPO_NAME.git"
    echo "Remote GitLab:    $REMOTE_GITLAB_URL"
    echo "SSH Key Path:     $SSH_KEY_PATH"
    echo "Mirror Mode:      $MIRROR_MODE"
    if [ "$MIRROR_MODE" = "cron" ]; then
        echo "Sync Interval:    $SYNC_INTERVAL minutes"
    fi
    echo ""

    if ! prompt_confirm "Is this configuration correct?" "y"; then
        print_warning "Configuration cancelled"
        exit 0
    fi

    save_config
}

################################################################################
# Setup Functions
################################################################################

check_prerequisites() {
    print_header "Checking Prerequisites"

    local all_ok=true

    # Check required commands
    check_command "git" || all_ok=false
    check_command "ssh" || all_ok=false
    check_command "ssh-keygen" || all_ok=false

    if [ "$all_ok" = false ]; then
        print_error "Prerequisites check failed"
        exit 1
    fi

    # Check if running as correct user
    if [ "$CREATE_GIT_USER" = "yes" ] && [ "$(whoami)" != "root" ]; then
        print_error "Must run as root to create git user"
        print_info "Run: sudo $0"
        exit 1
    fi

    print_success "All prerequisites satisfied"
}

create_git_user() {
    if [ "$CREATE_GIT_USER" = "yes" ]; then
        print_header "Creating Git User"

        if id "$GIT_USER" &>/dev/null; then
            print_warning "User $GIT_USER already exists"
        else
            print_info "Creating user $GIT_USER"
            useradd -m -s /bin/bash "$GIT_USER"
            print_success "User $GIT_USER created"

            if prompt_confirm "Do you want to set a password for $GIT_USER?" "n"; then
                passwd "$GIT_USER"
            fi
        fi
    fi
}

setup_ssh_keys() {
    print_header "Setting Up SSH Keys"

    local ssh_dir="$(dirname "$SSH_KEY_PATH")"
    local target_user="$GIT_USER"

    # Create .ssh directory
    if [ "$CREATE_GIT_USER" = "yes" ]; then
        sudo -u "$target_user" mkdir -p "$ssh_dir"
        sudo -u "$target_user" chmod 700 "$ssh_dir"
    else
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
    fi

    # Generate SSH key if not exists
    if [ ! -f "$SSH_KEY_PATH" ]; then
        print_info "Generating SSH key at $SSH_KEY_PATH"
        if [ "$CREATE_GIT_USER" = "yes" ]; then
            sudo -u "$target_user" ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -C "git-mirror@$(hostname)"
        else
            ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -C "git-mirror@$(hostname)"
        fi
        print_success "SSH key generated"
    else
        print_info "SSH key already exists at $SSH_KEY_PATH"
    fi

    # Display public key
    echo ""
    print_header "SSH Public Key"
    print_info "Add this public key to your GitLab account:"
    echo ""
    cat "${SSH_KEY_PATH}.pub"
    echo ""

    if ! prompt_confirm "Have you added the public key to GitLab?" "n"; then
        print_warning "Please add the public key to GitLab before continuing"
        print_info "GitLab: Settings -> SSH Keys"
        read -p "Press Enter when done..."
    fi

    # Test SSH connection
    print_info "Testing SSH connection to GitLab..."
    local gitlab_host=$(echo "$REMOTE_GITLAB_URL" | sed -n 's/.*@\([^:]*\).*/\1/p')

    if [ -n "$gitlab_host" ]; then
        if [ "$CREATE_GIT_USER" = "yes" ]; then
            sudo -u "$target_user" ssh -T -o StrictHostKeyChecking=no "git@$gitlab_host" 2>&1 | grep -i "welcome\|successfully" && print_success "SSH connection successful" || print_warning "SSH connection test inconclusive, continuing anyway"
        else
            ssh -T -o StrictHostKeyChecking=no "git@$gitlab_host" 2>&1 | grep -i "welcome\|successfully" && print_success "SSH connection successful" || print_warning "SSH connection test inconclusive, continuing anyway"
        fi
    fi
}

create_mirror_repo() {
    print_header "Creating Mirror Repository"

    local full_repo_path="$REPO_PATH/$REPO_NAME.git"

    # Create repository directory
    if [ "$CREATE_GIT_USER" = "yes" ]; then
        sudo -u "$GIT_USER" mkdir -p "$REPO_PATH"
    else
        mkdir -p "$REPO_PATH"
    fi

    # Initialize bare repository
    if [ -d "$full_repo_path" ]; then
        print_warning "Repository already exists at $full_repo_path"
        if prompt_confirm "Do you want to delete and recreate it?" "n"; then
            rm -rf "$full_repo_path"
        else
            print_info "Using existing repository"
            return 0
        fi
    fi

    print_info "Creating bare repository at $full_repo_path"
    if [ "$CREATE_GIT_USER" = "yes" ]; then
        sudo -u "$GIT_USER" git init --bare "$full_repo_path"
    else
        git init --bare "$full_repo_path"
    fi
    print_success "Bare repository created"

    # Add remote
    print_info "Adding remote 'origin' -> $REMOTE_GITLAB_URL"
    if [ "$CREATE_GIT_USER" = "yes" ]; then
        cd "$full_repo_path"
        sudo -u "$GIT_USER" git remote add origin "$REMOTE_GITLAB_URL" 2>/dev/null || sudo -u "$GIT_USER" git remote set-url origin "$REMOTE_GITLAB_URL"
    else
        cd "$full_repo_path"
        git remote add origin "$REMOTE_GITLAB_URL" 2>/dev/null || git remote set-url origin "$REMOTE_GITLAB_URL"
    fi
    print_success "Remote configured"
}

fetch_initial_data() {
    print_header "Fetching Initial Data from GitLab"

    local full_repo_path="$REPO_PATH/$REPO_NAME.git"

    print_info "Fetching all branches and tags from GitLab..."
    print_warning "This may take a while depending on repository size"

    cd "$full_repo_path"

    if [ "$CREATE_GIT_USER" = "yes" ]; then
        if sudo -u "$GIT_USER" git fetch origin --prune; then
            print_success "Initial data fetched successfully"
        else
            print_error "Failed to fetch initial data"
            print_info "Please check:"
            print_info "  1. SSH key is added to GitLab"
            print_info "  2. Repository URL is correct"
            print_info "  3. Network connectivity"
            exit 1
        fi
    else
        if git fetch origin --prune; then
            print_success "Initial data fetched successfully"
        else
            print_error "Failed to fetch initial data"
            exit 1
        fi
    fi

    # Show fetched branches
    print_info "Fetched branches:"
    if [ "$CREATE_GIT_USER" = "yes" ]; then
        sudo -u "$GIT_USER" git branch -r
    else
        git branch -r
    fi
}

setup_git_hook() {
    print_header "Setting Up Git Hook"

    local full_repo_path="$REPO_PATH/$REPO_NAME.git"
    local hook_file="$full_repo_path/hooks/post-receive"

    print_info "Creating post-receive hook at $hook_file"

    cat > "$hook_file" << 'EOF'
#!/bin/bash

# Git Hook: Auto-sync to remote GitLab
# Generated by setup-git-mirror.sh

echo "========================================"
echo "Starting sync to remote GitLab..."
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"

# Push all refs to origin
if git push --mirror origin; then
    echo "✓ Successfully synced to remote GitLab"
    echo "========================================"
    exit 0
else
    echo "✗ Failed to sync to remote GitLab"
    echo "========================================"
    exit 1
fi
EOF

    chmod +x "$hook_file"

    if [ "$CREATE_GIT_USER" = "yes" ]; then
        chown "$GIT_USER:$GIT_USER" "$hook_file"
    fi

    print_success "Git hook configured"
}

setup_cron_sync() {
    print_header "Setting Up Cron Sync"

    local full_repo_path="$REPO_PATH/$REPO_NAME.git"
    local sync_script="$REPO_PATH/sync-to-gitlab.sh"

    print_info "Creating sync script at $sync_script"

    cat > "$sync_script" << EOF
#!/bin/bash

# Auto-sync script for Git mirror
# Generated by setup-git-mirror.sh

REPO_PATH="$full_repo_path"
LOG_FILE="$REPO_PATH/sync.log"

cd "\$REPO_PATH"

echo "[\$(date '+%Y-%m-%d %H:%M:%S')] Starting sync..." >> "\$LOG_FILE"

if git push --mirror origin >> "\$LOG_FILE" 2>&1; then
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] Sync successful" >> "\$LOG_FILE"
else
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] Sync failed" >> "\$LOG_FILE"
fi
EOF

    chmod +x "$sync_script"

    if [ "$CREATE_GIT_USER" = "yes" ]; then
        chown "$GIT_USER:$GIT_USER" "$sync_script"
    fi

    # Add to crontab
    print_info "Adding to crontab (every $SYNC_INTERVAL minutes)"

    local cron_entry="*/$SYNC_INTERVAL * * * * $sync_script"

    if [ "$CREATE_GIT_USER" = "yes" ]; then
        (sudo -u "$GIT_USER" crontab -l 2>/dev/null; echo "$cron_entry") | sudo -u "$GIT_USER" crontab -
    else
        (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
    fi

    print_success "Cron sync configured"
}

generate_client_guide() {
    print_header "Generating Client Configuration Guide"

    local guide_file="$SCRIPT_DIR/client-setup-guide.md"
    local mirror_host=$(hostname)
    local mirror_ssh="$GIT_USER@$mirror_host"
    local mirror_repo_url="$mirror_ssh:$REPO_PATH/$REPO_NAME.git"

    cat > "$guide_file" << EOF
# Git Mirror Client Setup Guide

## Mirror Server Information

- **Mirror Server**: $mirror_host
- **Repository Path**: $REPO_PATH/$REPO_NAME.git
- **Clone URL**: $mirror_repo_url
- **Remote GitLab**: $REMOTE_GITLAB_URL

## Setup Steps

### 1. Configure SSH Access (Run on Local Machine)

\`\`\`bash
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -C "your-email@example.com"

# Display your public key
cat ~/.ssh/id_ed25519.pub

# Copy the public key and add it to the mirror server
# On mirror server, run:
# echo "YOUR_PUBLIC_KEY" >> ~/.ssh/authorized_keys

# Test SSH connection
ssh $mirror_ssh
\`\`\`

### 2. Option A: Update Existing Repository

\`\`\`bash
cd /Users/barry.wang/Documents/BinaryOption

# Backup current remote configuration
git remote -v > .git/remote-backup.txt

# Rename current origin to gitlab
git remote rename origin gitlab

# Add mirror as new origin
git remote add origin $mirror_repo_url

# Verify configuration
git remote -v

# Test by pulling
git pull origin main

# Test by pushing
git push origin main
\`\`\`

### 2. Option B: Clone from Mirror

\`\`\`bash
cd /Users/barry.wang/Documents

# Backup existing repository
mv BinaryOption BinaryOption.backup

# Clone from mirror
git clone $mirror_repo_url

cd BinaryOption

# Add direct GitLab remote as backup
git remote add gitlab $REMOTE_GITLAB_URL

# Verify
git remote -v
\`\`\`

## Daily Workflow

\`\`\`bash
# Pull latest changes
git pull origin main

# Make changes and commit
git add .
git commit -m "Your commit message"

# Push to mirror (automatically syncs to GitLab)
git push origin main
\`\`\`

## Emergency: Direct Push to GitLab

If the mirror server is down, push directly to GitLab:

\`\`\`bash
git push gitlab main
\`\`\`

## Troubleshooting

### Check sync status on mirror server

\`\`\`bash
ssh $mirror_ssh
cd $REPO_PATH/$REPO_NAME.git

# Check if mirror is up to date with GitLab
git fetch origin --dry-run
\`\`\`

### Manual sync on mirror server

\`\`\`bash
ssh $mirror_ssh
cd $REPO_PATH/$REPO_NAME.git
git push --mirror origin
\`\`\`

## Mirror Server Management Commands

\`\`\`bash
# SSH to mirror server
ssh $mirror_ssh

# Check repository status
cd $REPO_PATH/$REPO_NAME.git
git remote -v
git branch -r

# View sync logs (if using cron)
tail -f $REPO_PATH/$REPO_NAME.git/sync.log

# View git hook logs
# Check syslog or journal for git operations
\`\`\`

---
Generated: $(date '+%Y-%m-%d %H:%M:%S')
EOF

    print_success "Client guide generated: $guide_file"
}

create_management_scripts() {
    print_header "Creating Management Scripts"

    local full_repo_path="$REPO_PATH/$REPO_NAME.git"

    # Status check script
    local status_script="$REPO_PATH/check-mirror-status.sh"
    cat > "$status_script" << EOF
#!/bin/bash

# Check mirror sync status
# Generated by setup-git-mirror.sh

REPO_PATH="$full_repo_path"

cd "\$REPO_PATH"

echo "========================================"
echo "Git Mirror Status Check"
echo "Timestamp: \$(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"
echo ""

echo "Repository: \$REPO_PATH"
echo ""

echo "Remote configuration:"
git remote -v
echo ""

echo "Fetching latest from GitLab..."
git fetch origin --prune > /dev/null 2>&1

echo ""
echo "Branch sync status:"
for branch in \$(git for-each-ref --format='%(refname:short)' refs/heads/); do
    local_commit=\$(git rev-parse \$branch 2>/dev/null)
    remote_commit=\$(git rev-parse origin/\$branch 2>/dev/null)

    if [ "\$local_commit" = "\$remote_commit" ]; then
        echo "  ✓ \$branch: Synced"
    else
        echo "  ✗ \$branch: Out of sync"
        echo "    Local:  \$local_commit"
        echo "    Remote: \$remote_commit"
    fi
done

echo ""
echo "========================================"
EOF

    chmod +x "$status_script"

    # Manual sync script
    local manual_sync_script="$REPO_PATH/manual-sync.sh"
    cat > "$manual_sync_script" << EOF
#!/bin/bash

# Manual sync to GitLab
# Generated by setup-git-mirror.sh

REPO_PATH="$full_repo_path"

cd "\$REPO_PATH"

echo "========================================"
echo "Manual Sync to GitLab"
echo "Timestamp: \$(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"

if git push --mirror origin; then
    echo "✓ Sync successful"
else
    echo "✗ Sync failed"
    exit 1
fi

echo "========================================"
EOF

    chmod +x "$manual_sync_script"

    if [ "$CREATE_GIT_USER" = "yes" ]; then
        chown "$GIT_USER:$GIT_USER" "$status_script"
        chown "$GIT_USER:$GIT_USER" "$manual_sync_script"
    fi

    print_success "Management scripts created:"
    print_info "  - Status check: $status_script"
    print_info "  - Manual sync: $manual_sync_script"
}

################################################################################
# Main Setup Flow
################################################################################

run_setup() {
    print_header "Git Mirror Server Setup"

    check_prerequisites
    create_git_user
    setup_ssh_keys
    create_mirror_repo
    fetch_initial_data

    if [ "$MIRROR_MODE" = "hook" ]; then
        setup_git_hook
    else
        setup_cron_sync
    fi

    create_management_scripts
    generate_client_guide

    print_header "Setup Complete!"

    print_success "Git mirror server is ready"
    echo ""
    print_info "Next steps:"
    print_info "  1. Review the client setup guide: $SCRIPT_DIR/client-setup-guide.md"
    print_info "  2. Configure your local repository"
    print_info "  3. Test push/pull operations"
    echo ""
    print_info "Management commands:"
    print_info "  - Check status: $REPO_PATH/check-mirror-status.sh"
    print_info "  - Manual sync: $REPO_PATH/manual-sync.sh"
    echo ""
    print_success "Setup completed successfully!"
}

################################################################################
# Main Entry Point
################################################################################

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Setup a Git mirror server for relay between local dev and remote GitLab.

Options:
    -h, --help              Show this help message
    -i, --interactive       Run in interactive mode (default)
    -c, --config FILE       Load configuration from file

Examples:
    # Interactive setup
    $0 --interactive

    # Use existing configuration
    $0 --config /path/to/config.env

EOF
}

main() {
    local mode="interactive"

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

    # Initialize log file
    log "INFO" "=== Setup Started ==="

    # Load or create configuration
    case $mode in
        interactive)
            interactive_config
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

    # Run setup
    run_setup

    log "INFO" "=== Setup Finished ==="
}

# Run main function
main "$@"
