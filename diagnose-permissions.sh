#!/bin/bash

# Permission Diagnostic Tool
# Helps diagnose nginx permission issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root or with sudo"
    exit 1
fi

# Main diagnostic function
diagnose_path() {
    local path=$1

    echo "========================================"
    log_info "Diagnosing permissions for: $path"
    echo "========================================"

    # Check if path exists
    if [ ! -d "$path" ] && [ ! -f "$path" ]; then
        log_error "Path does not exist: $path"
        return 1
    fi

    # Get path info
    echo "Path information:"
    echo "  - Type: $([ -d "$path" ] && echo "Directory" || echo "File")"
    echo "  - Full path: $(readlink -f "$path")"
    echo ""

    # Get ownership and permissions
    echo "Ownership and permissions:"
    ls -la "$path" | head -1
    if [ -d "$path" ]; then
        ls -ld "$path"
    else
        ls -l "$path"
    fi
    echo ""

    # Get stat info
    echo "Detailed permissions:"
    stat "$path" 2>/dev/null || echo "stat command failed"
    echo ""

    # Check parent directories
    echo "Parent directory permissions:"
    local current="$path"
    for i in {1..5}; do
        current="$(dirname "$current")"
        if [ "$current" = "/" ]; then
            echo "  / (root): $(ls -ld / | awk '{print $1, $3, $4}')"
            break
        fi
        echo "  $current: $(ls -ld "$current" 2>/dev/null | awk '{print $1, $3, $4}' || echo "Cannot access")"
    done
    echo ""

    # Detect nginx user
    echo "Nginx user detection:"
    local nginx_user=""
    if id -u nginx >/dev/null 2>&1; then
        nginx_user="nginx"
    elif id -u www-data >/dev/null 2>&1; then
        nginx_user="www-data"
    elif id -u apache >/dev/null 2>&1; then
        nginx_user="apache"
    else
        log_warning "Could not detect nginx user automatically"
    fi

    if [ -n "$nginx_user" ]; then
        echo "  - Detected nginx user: $nginx_user"
        id "$nginx_user"
        echo ""

        # Test access as nginx user
        echo "Access test as $nginx_user:"
        if su -c "test -r '$path' && echo '  ✓ Can read'" "$nginx_user" 2>/dev/null; then
            log_success "$nginx_user can read $path"
        else
            log_error "$nginx_user cannot read $path"
        fi
        echo ""
    fi

    # Check what user nginx actually runs as
    echo "Running nginx processes:"
    ps aux | grep nginx | grep -v grep || echo "  No nginx processes found"
    echo ""

    # Recommendations
    echo "Recommendations:"
    local owner=$(stat -c '%U' "$path" 2>/dev/null || stat -f '%Su' "$path")
    echo "  1. Add $nginx_user to group '$owner':"
    echo "     sudo usermod -a -G $owner $nginx_user"
    echo ""
    echo "  2. Set proper permissions:"
    echo "     sudo chown -R $owner:$owner '$path'"
    echo "     sudo find '$path' -type d -exec chmod 755 {} \\;"
    echo "     sudo find '$path' -type f -exec chmod 644 {} \\;"
    echo ""
    echo "  3. Restart services:"
    echo "     sudo systemctl restart nginx"
    echo "     sudo systemctl restart php*-fpm"
    echo ""

    # Quick fix
    echo "Quick fix command:"
    echo "sudo ./nginx-manager.sh fix-permissions '$path'"
    echo ""
}

# Show usage
show_usage() {
    cat << EOF
Nginx Permission Diagnostic Tool

USAGE:
    $0 <website_path>

DESCRIPTION:
    This tool helps diagnose permission issues between nginx and website files.
    It provides detailed information about ownership, permissions, and access rights.

EXAMPLES:
    $0 /var/www/myapp
    $0 /home/jaspis/www/bliss.jaspis.me

EOF
}

# Main function
main() {
    if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_usage
        exit 0
    fi

    local path="$1"
    diagnose_path "$path"
}

main "$@"
