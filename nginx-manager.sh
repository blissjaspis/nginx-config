#!/bin/bash

# Nginx Configuration Manager
# Automates nginx config creation and management for different application types

set -e

# Configuration
NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/templates"

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

# Check if running as root or with sudo
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Create necessary directories
setup_directories() {
    mkdir -p "$TEMPLATE_DIR"
    mkdir -p "$NGINX_SITES_AVAILABLE"
    mkdir -p "$NGINX_SITES_ENABLED"
}

# Validate domain name
validate_domain() {
    local domain=$1
    if [[ ! $domain =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log_error "Invalid domain format: $domain"
        exit 1
    fi
}

# Validate port number
validate_port() {
    local port=$1
    if ! [[ $port =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        log_error "Invalid port number: $port"
        exit 1
    fi
}

# Create Laravel application configuration
create_laravel_config() {
    local domain=$1
    local root_path=$2
    local php_version=${3:-8.1}

    log_info "Creating Laravel configuration for $domain"

    cat > "$NGINX_SITES_AVAILABLE/$domain" << EOF
server {
    listen 80;
    listen [::]:80;

    server_name $domain www.$domain;
    root $root_path/public;
    index index.php index.html index.htm;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json;

    # Handle PHP files
    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_pass unix:/var/run/php/php$php_version-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    # Handle static files
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files \$uri =404;
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Handle Laravel routes
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    # Handle storage files
    location ^~ /storage/ {
        try_files \$uri =404;
    }

    # Handle favicon and robots.txt
    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    # Error pages
    error_page 404 /index.php;
}
EOF

    log_success "Laravel configuration created for $domain"
}

# Create static website configuration
create_static_config() {
    local domain=$1
    local root_path=$2

    log_info "Creating static website configuration for $domain"

    cat > "$NGINX_SITES_AVAILABLE/$domain" << EOF
server {
    listen 80;
    listen [::]:80;

    server_name $domain www.$domain;
    root $root_path;
    index index.html index.htm;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json;

    # Handle static files with caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot|webp|avif)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files \$uri =404;
    }

    # Handle HTML files with short cache
    location ~* \.(html|htm)$ {
        expires 1h;
        add_header Cache-Control "public";
        try_files \$uri =404;
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Handle all other requests
    location / {
        try_files \$uri \$uri/ =404;
    }

    # Handle favicon and robots.txt
    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }
}
EOF

    log_success "Static website configuration created for $domain"
}

# Create Node.js application configuration
create_nodejs_config() {
    local domain=$1
    local upstream_port=$2

    log_info "Creating Node.js configuration for $domain"

    cat > "$NGINX_SITES_AVAILABLE/$domain" << EOF
upstream $domain {
    server 127.0.0.1:$upstream_port;
    keepalive 32;
}

server {
    listen 80;
    listen [::]:80;

    server_name $domain www.$domain;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json;

    # Handle static files
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot|webp|avif)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files \$uri =404;
    }

    # Proxy to Node.js application
    location / {
        proxy_pass http://$domain;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 86400;
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Handle favicon and robots.txt
    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }
}
EOF

    log_success "Node.js configuration created for $domain"
}

# Enable a site
enable_site() {
    local domain=$1

    if [ ! -f "$NGINX_SITES_AVAILABLE/$domain" ]; then
        log_error "Configuration file for $domain does not exist"
        exit 1
    fi

    if [ -L "$NGINX_SITES_ENABLED/$domain" ]; then
        log_warning "Site $domain is already enabled"
        return
    fi

    ln -s "$NGINX_SITES_AVAILABLE/$domain" "$NGINX_SITES_ENABLED/$domain"
    log_success "Site $domain enabled"
}

# Disable a site
disable_site() {
    local domain=$1

    if [ ! -L "$NGINX_SITES_ENABLED/$domain" ]; then
        log_warning "Site $domain is not enabled"
        return
    fi

    rm "$NGINX_SITES_ENABLED/$domain"
    log_success "Site $domain disabled"
}

# Test nginx configuration
test_config() {
    log_info "Testing nginx configuration..."
    if nginx -t; then
        log_success "Nginx configuration is valid"
    else
        log_error "Nginx configuration has errors"
        exit 1
    fi
}

# Reload nginx
reload_nginx() {
    log_info "Reloading nginx..."
    if systemctl reload nginx; then
        log_success "Nginx reloaded successfully"
    else
        log_error "Failed to reload nginx"
        exit 1
    fi
}

# Show usage information
show_usage() {
    cat << EOF
Nginx Configuration Manager

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    create-laravel    Create Laravel application configuration
    create-static     Create static website configuration
    create-nodejs     Create Node.js application configuration
    enable            Enable a site
    disable           Disable a site
    fix-permissions   Fix file permissions for nginx access
    test              Test nginx configuration
    reload            Reload nginx configuration
    list              List available and enabled sites

EXAMPLES:
    # Create Laravel site
    $0 create-laravel example.com /var/www/laravel-app

    # Create static site
    $0 create-static static.example.com /var/www/static-site

    # Create Node.js site
    $0 create-nodejs api.example.com 3000

    # Fix permissions (recommended method)
    $0 fix-permissions /var/www/myapp

    # Fix permissions with custom nginx user
    $0 fix-permissions --nginx-user www-data /var/www/myapp

    # Enable a site
    $0 enable example.com

    # Disable a site
    $0 disable example.com

    # Test and reload
    $0 test && $0 reload

OPTIONS:
    --php-version VERSION    PHP version for Laravel (default: 8.1)
    --nginx-user USER        Nginx user for permissions (default: auto-detect)
    --method METHOD          Permission fix method: group, owner, world (default: group)
    --help, -h              Show this help message

EOF
}

# List sites
list_sites() {
    echo "Available sites:"
    if [ -d "$NGINX_SITES_AVAILABLE" ]; then
        ls -1 "$NGINX_SITES_AVAILABLE" 2>/dev/null || echo "  None"
    fi

    echo -e "\nEnabled sites:"
    if [ -d "$NGINX_SITES_ENABLED" ]; then
        ls -1 "$NGINX_SITES_ENABLED" 2>/dev/null || echo "  None"
    fi
}

# Main function
main() {
    check_permissions
    setup_directories

    case "${1:-}" in
        create-laravel)
            if [ $# -lt 3 ]; then
                log_error "Usage: $0 create-laravel <domain> <root_path> [--php-version VERSION]"
                exit 1
            fi
            validate_domain "$2"
            local php_version="8.1"
            if [ "${4:-}" = "--php-version" ] && [ -n "${5:-}" ]; then
                php_version="$5"
            fi
            create_laravel_config "$2" "$3" "$php_version"
            enable_site "$2"
            test_config
            ;;

        create-static)
            if [ $# -lt 3 ]; then
                log_error "Usage: $0 create-static <domain> <root_path>"
                exit 1
            fi
            validate_domain "$2"
            create_static_config "$2" "$3"
            enable_site "$2"
            test_config
            ;;

        create-nodejs)
            if [ $# -lt 3 ]; then
                log_error "Usage: $0 create-nodejs <domain> <port>"
                exit 1
            fi
            validate_domain "$2"
            validate_port "$3"
            create_nodejs_config "$2" "$3"
            enable_site "$2"
            test_config
            ;;

        fix-permissions)
            shift
            "$SCRIPT_DIR/fix-permissions.sh" "$@"
            ;;

        enable)
            if [ $# -lt 2 ]; then
                log_error "Usage: $0 enable <domain>"
                exit 1
            fi
            enable_site "$2"
            test_config
            reload_nginx
            ;;

        disable)
            if [ $# -lt 2 ]; then
                log_error "Usage: $0 disable <domain>"
                exit 1
            fi
            disable_site "$2"
            test_config
            reload_nginx
            ;;

        test)
            test_config
            ;;

        reload)
            reload_nginx
            ;;

        list)
            list_sites
            ;;

        --help|-h|"")
            show_usage
            ;;

        *)
            log_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
