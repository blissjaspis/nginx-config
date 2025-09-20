#!/bin/bash

# Nginx Permissions Fixer
# Helps resolve common permission issues between nginx user and website files

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
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Detect nginx user
detect_nginx_user() {
    # Check common nginx user names
    if id -u nginx >/dev/null 2>&1; then
        echo "nginx"
    elif id -u www-data >/dev/null 2>&1; then
        echo "www-data"
    elif id -u apache >/dev/null 2>&1; then
        echo "apache"
    else
        log_error "Could not detect nginx user. Please specify with --nginx-user"
        exit 1
    fi
}

# Check current permissions
check_permissions_for_path() {
    local path=$1
    local nginx_user=$2

    log_info "Checking permissions for: $path"

    if [ ! -d "$path" ] && [ ! -f "$path" ]; then
        log_error "Path does not exist: $path"
        return 1
    fi

    # Get current ownership
    local owner=$(stat -c '%U' "$path" 2>/dev/null || stat -f '%Su' "$path")
    local group=$(stat -c '%G' "$path" 2>/dev/null || stat -f '%Sg' "$path")
    local perms=$(stat -c '%a' "$path" 2>/dev/null || stat -f '%Lp' "$path" | cut -c -3)

    echo "Current ownership: $owner:$group (perms: $perms)"

    # Check if nginx user can access
    log_info "Testing nginx access with su command..."
    if ! su -c "test -r '$path' && echo 'Access OK'" "$nginx_user" 2>/dev/null; then
        log_warning "Nginx user '$nginx_user' cannot read: $path"

        # Additional debugging info
        log_info "Debug info:"
        echo "  - Parent directory permissions:"
        ls -ld "$(dirname "$path")" 2>/dev/null || echo "    Cannot read parent directory"
        echo "  - Target permissions:"
        ls -ld "$path" 2>/dev/null || ls -l "$path" 2>/dev/null || echo "    Cannot read target"
        echo "  - Nginx user info:"
        id "$nginx_user" 2>/dev/null || echo "    User does not exist"

        # Try alternative check
        log_info "Trying alternative access check..."
        if [ -r "$path" ] && [ -x "$(dirname "$path")" ]; then
            log_info "Basic permissions look OK, but su test failed. This might be a su configuration issue."
        else
            log_info "Basic permission check also failed."
        fi

        return 1
    else
        log_success "Nginx user '$nginx_user' can read: $path"
        return 0
    fi
}

# Fix permissions using group method (recommended)
fix_permissions_group() {
    local path=$1
    local nginx_user=$2
    local file_owner=${3:-$(stat -c '%U' "$path" 2>/dev/null || stat -f '%Su' "$path")}

    log_info "Fixing permissions using group method..."

    # Check if nginx user exists
    if ! id "$nginx_user" >/dev/null 2>&1; then
        log_error "Nginx user '$nginx_user' does not exist"
        return 1
    fi

    # Add nginx user to the file owner's group
    log_info "Adding $nginx_user to group of $file_owner"
    if ! usermod -a -G "$file_owner" "$nginx_user"; then
        log_error "Failed to add $nginx_user to group $file_owner"
        return 1
    fi

    # CRITICAL FIX: Fix parent directory permissions
    # The issue is that parent directories may not allow group access
    log_info "Fixing parent directory permissions for access..."
    local current="$path"
    for i in {1..5}; do
        current="$(dirname "$current")"
        if [ "$current" = "/" ]; then
            break
        fi

        # Check if parent directory allows group access
        local parent_perms=$(stat -c '%a' "$current" 2>/dev/null || stat -f '%Lp' "$current" | cut -c -3 2>/dev/null || echo "000")
        local parent_owner=$(stat -c '%U' "$current" 2>/dev/null || stat -f '%Su' "$current" 2>/dev/null || echo "unknown")

        # If parent is owned by the same user and doesn't allow group access, fix it
        if [ "$parent_owner" = "$file_owner" ] && [ "${parent_perms:1:1}" = "0" ] && [ "${parent_perms:2:1}" = "0" ]; then
            log_info "Fixing parent directory: $current (was ${parent_perms}, setting to 755)"
            if ! chmod 755 "$current"; then
                log_warning "Could not fix permissions for parent directory: $current"
            fi
        fi
    done

    # Set group ownership to file owner's group
    log_info "Setting group ownership to $file_owner"
    if ! chown -R "$file_owner:$file_owner" "$path"; then
        log_error "Failed to change ownership of $path"
        return 1
    fi

    # Set proper permissions
    log_info "Setting directory permissions to 755"
    if ! find "$path" -type d -exec chmod 755 {} \;; then
        log_warning "Some directory permissions may not have been set"
    fi

    log_info "Setting file permissions to 644"
    if ! find "$path" -type f -exec chmod 644 {} \;; then
        log_warning "Some file permissions may not have been set"
    fi

    # Special permissions for Laravel/Node.js
    if [ -d "$path/storage" ]; then
        log_info "Setting Laravel storage permissions"
        chmod -R 775 "$path/storage"
        chmod -R 775 "$path/bootstrap/cache" 2>/dev/null || true
    fi

    if [ -d "$path/.next" ] || [ -d "$path/node_modules" ]; then
        log_info "Setting Node.js permissions"
        find "$path" -name "node_modules" -type d -exec chmod 755 {} \; 2>/dev/null || true
    fi

    log_success "Permissions fixed using group method"
    log_info "Restart nginx and php-fpm to apply group changes:"
    log_info "  sudo systemctl restart nginx"
    log_info "  sudo systemctl restart php*-fpm"
}

# Fix permissions using nginx ownership method
fix_permissions_nginx_owner() {
    local path=$1
    local nginx_user=$2

    log_info "Fixing permissions by changing ownership to $nginx_user..."
    log_warning "This method gives nginx full ownership - use with caution!"

    # Change ownership to nginx user
    chown -R "$nginx_user:$nginx_user" "$path"

    # Set proper permissions
    find "$path" -type d -exec chmod 755 {} \;
    find "$path" -type f -exec chmod 644 {} \;

    # Special permissions for Laravel
    if [ -d "$path/storage" ]; then
        log_info "Setting Laravel storage permissions"
        chmod -R 775 "$path/storage"
    fi

    log_success "Permissions fixed using nginx ownership method"
}

# Fix permissions using world-readable method (less secure)
fix_permissions_world() {
    local path=$1

    log_info "Fixing permissions using world-readable method..."
    log_warning "This method makes files world-readable - less secure!"

    # Make directories world-executable
    find "$path" -type d -exec chmod 755 {} \;

    # Make files world-readable
    find "$path" -type f -exec chmod 644 {} \;

    log_success "Permissions fixed using world-readable method"
}

# Show usage
show_usage() {
    cat << EOF
Nginx Permissions Fixer

USAGE:
    $0 [OPTIONS] <website_path>

OPTIONS:
    --nginx-user USER    Specify nginx user (default: auto-detect)
    --method METHOD      Fix method: group (default), owner, world
    --check-only         Only check permissions, don't fix
    --help, -h           Show this help

METHODS:
    group    Add nginx user to file owner's group (recommended)
    owner    Change ownership to nginx user (secure but restrictive)
    world    Make files world-readable (less secure)

EXAMPLES:
    # Check permissions for a website
    $0 --check-only /var/www/myapp

    # Fix using group method (recommended)
    $0 /var/www/myapp

    # Fix using nginx ownership
    $0 --method owner /var/www/myapp

    # Fix with custom nginx user
    $0 --nginx-user www-data /var/www/myapp

EOF
}

# Main function
main() {
    check_permissions

    local nginx_user=""
    local method="group"
    local check_only=false
    local path=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --nginx-user)
                nginx_user="$2"
                shift 2
                ;;
            --method)
                method="$2"
                shift 2
                ;;
            --check-only)
                check_only=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                if [ -z "$path" ]; then
                    path="$1"
                else
                    log_error "Unexpected argument: $1"
                    show_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # Validate path
    if [ -z "$path" ]; then
        log_error "Website path is required"
        show_usage
        exit 1
    fi

    # Detect nginx user if not specified
    if [ -z "$nginx_user" ]; then
        nginx_user=$(detect_nginx_user)
        log_info "Detected nginx user: $nginx_user"
    fi

    # Check if nginx user exists
    if ! id -u "$nginx_user" >/dev/null 2>&1; then
        log_error "Nginx user '$nginx_user' does not exist"
        exit 1
    fi

    # Check current permissions
    if ! check_permissions_for_path "$path" "$nginx_user"; then
        if [ "$check_only" = true ]; then
            log_info "Permission check completed. Use without --check-only to fix."
            exit 1
        fi

        # Fix permissions based on method
        case $method in
            group)
                fix_permissions_group "$path" "$nginx_user"
                ;;
            owner)
                fix_permissions_nginx_owner "$path" "$nginx_user"
                ;;
            world)
                fix_permissions_world "$path"
                ;;
            *)
                log_error "Unknown method: $method"
                show_usage
                exit 1
                ;;
        esac

        # Verify fix
        log_info "Verifying fix..."
        if check_permissions_for_path "$path" "$nginx_user"; then
            log_success "Permissions successfully fixed!"
        else
            log_error "Failed to fix permissions automatically"
            log_info "Manual fix commands (run these as root):"
            local file_owner=$(stat -c '%U' "$path" 2>/dev/null || stat -f '%Su' "$path")
            echo "  # Check current permissions:"
            echo "  ls -la '$path'"
            echo "  id $nginx_user"
            echo ""
            echo "  # CRITICAL: Check and fix parent directories:"
            local current="$path"
            for i in {1..3}; do
                current="$(dirname "$current")"
                if [ "$current" = "/" ]; then break; fi
                echo "  ls -ld '$current'  # Check if this blocks access"
                echo "  chmod 755 '$current'  # Fix if permissions are 700/750"
            done
            echo ""
            echo "  # Manual group method:"
            echo "  usermod -a -G $file_owner $nginx_user"
            echo "  chown -R $file_owner:$file_owner '$path'"
            echo "  find '$path' -type d -exec chmod 755 {} \\;"
            echo "  find '$path' -type f -exec chmod 644 {} \\;"
            echo "  systemctl restart nginx"
            echo ""
            echo "  # Alternative: Make world-readable (less secure):"
            echo "  chmod -R 755 '$path'"
            echo "  find '$path' -type f -exec chmod 644 {} \\;"
            exit 1
        fi
    else
        log_success "Permissions are already correct"
    fi
}

main "$@"
