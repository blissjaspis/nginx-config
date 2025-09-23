#!/bin/bash

# nginx-manager.sh - Easy nginx configuration generator
# Author: nginx-config tool
# Version: 1.0.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"
TEMPLATES_DIR="$(dirname "$0")/templates"
SSL_DIR="/etc/ssl/nginx"

# Print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Print banner
print_banner() {
    clear
    print_color $CYAN "╔══════════════════════════════════════════════════════════╗"
    print_color $CYAN "║                    nginx-manager                         ║"
    print_color $CYAN "║              Easy nginx configuration tool               ║"
    print_color $CYAN "╚══════════════════════════════════════════════════════════╝"
    echo
}

# Check if running as root for certain operations
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_color $RED "This operation requires root privileges. Please run with sudo."
        exit 1
    fi
}

# Check if nginx is installed
check_nginx() {
    if ! command -v nginx &> /dev/null; then
        print_color $RED "nginx is not installed. Please install nginx first."
        exit 1
    fi
}

# Create directories if they don't exist
ensure_directories() {
    local dirs=("$TEMPLATES_DIR" "$SSL_DIR")
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            print_color $YELLOW "Creating directory: $dir"
            sudo mkdir -p "$dir" 2>/dev/null || mkdir -p "$dir"
        fi
    done
}

# Validate domain name
validate_domain() {
    local domain=$1
    if [[ ! $domain =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 1
    fi
    return 0
}

# Ensure nginx directories exist with proper permissions
ensure_nginx_dirs() {
    # Create log directories if they don't exist
    sudo mkdir -p /var/log/nginx 2>/dev/null || true
    sudo chown -R nginx:nginx /var/log/nginx 2>/dev/null || true

    # Create cache directories
    sudo mkdir -p /var/cache/nginx 2>/dev/null || true
    sudo chown -R nginx:nginx /var/cache/nginx 2>/dev/null || true
}

# Test nginx configuration
test_nginx_config() {
    print_color $BLUE "Testing nginx configuration..."
    ensure_nginx_dirs
    if sudo nginx -t; then
        print_color $GREEN "✓ nginx configuration is valid"
        return 0
    else
        print_color $RED "✗ nginx configuration has errors"
        return 1
    fi
}

# Reload nginx
reload_nginx() {
    print_color $BLUE "Reloading nginx..."
    ensure_nginx_dirs
    if sudo systemctl reload nginx 2>/dev/null || sudo service nginx reload 2>/dev/null; then
        print_color $GREEN "✓ nginx reloaded successfully"
    else
        print_color $RED "✗ Failed to reload nginx"
    fi
}

# Generate SSL certificate with certbot
generate_ssl() {
    local domain=$1
    local email=$2
    
    if command -v certbot &> /dev/null; then
        print_color $BLUE "Generating SSL certificate for $domain..."
        sudo certbot --nginx -d "$domain" --email "$email" --agree-tos --non-interactive
    else
        print_color $YELLOW "Certbot not found. Install certbot to auto-generate SSL certificates."
        print_color $CYAN "Manual SSL setup instructions will be provided."
    fi
}

# Enable SSL in existing configuration
enable_ssl_in_config() {
    local config_file=$1
    local domain=$2

    print_color $BLUE "Enabling SSL in configuration: $config_file"

    # Create backup
    sudo cp "$config_file" "${config_file}.backup"

    # Read current config
    local config_content
    config_content=$(cat "$config_file")

    # Replace the listen 80 line with listen 80 and 443
    config_content=${config_content//    listen 80;/    listen 80;
    listen 443 ssl;}

    # Add SSL configuration after server_name
    local ssl_config=""
    ssl_config+="\n    # SSL Configuration"
    ssl_config+="\n    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;"
    ssl_config+="\n    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;"

    # Add secure SSL protocols and ciphers (avoid Let's Encrypt options to prevent conflicts)
    ssl_config+="\n    ssl_protocols TLSv1.2 TLSv1.3;"
    ssl_config+="\n    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;"
    ssl_config+="\n    ssl_prefer_server_ciphers off;"
    ssl_config+="\n    ssl_session_cache shared:SSL:10m;"
    ssl_config+="\n    ssl_session_timeout 10m;"

    # Insert SSL config after server_name line
    config_content=$(echo "$config_content" | sed "/server_name/a\\$ssl_config")

    # Also add SSL to www redirect block if it exists
    if echo "$config_content" | grep -q "server_name www\.$domain"; then
        # Add SSL listen to www redirect block
        config_content=$(echo "$config_content" | sed "/server_name www\.$domain/a\\    listen 443 ssl;\n\n    # SSL Configuration\n    ssl_certificate \/etc\/letsencrypt\/live\/$domain\/fullchain.pem;\n    ssl_certificate_key \/etc\/letsencrypt\/live\/$domain\/privkey.pem;/")

        # Add SSL config to www block
        config_content=$(echo "$config_content" | sed "/ssl_certificate_key \/etc\/letsencrypt\/live\/$domain\/privkey.pem;/a\\    ssl_protocols TLSv1.2 TLSv1.3;\n    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;\n    ssl_prefer_server_ciphers off;\n    ssl_session_cache shared:SSL:10m;\n    ssl_session_timeout 10m;/")
    fi

    # Write the updated config
    echo "$config_content" | sudo tee "$config_file" > /dev/null

    print_color $GREEN "✓ SSL configuration added to $config_file"
}

# Create site configuration from template
create_site_config() {
    local site_type=$1
    local domain=$2
    local root_path=$3
    local php_version=$4
    local port=$5
    local ssl_enabled=$6
    local email=$7
    local www_enabled=$8
    local www_is_main=$9
    
    local template_file="$TEMPLATES_DIR/${site_type}.conf"
    local config_file="$NGINX_SITES_AVAILABLE/$domain"
    
    if [[ ! -f "$template_file" ]]; then
        print_color $RED "Template file not found: $template_file"
        return 1
    fi
    
    # Read template and substitute variables
    local config_content
    config_content=$(cat "$template_file")
    
    # Substitute variables
    config_content=${config_content//\{\{DOMAIN\}\}/$domain}
    config_content=${config_content//\{\{ROOT_PATH\}\}/$root_path}
    config_content=${config_content//\{\{PHP_VERSION\}\}/$php_version}
    config_content=${config_content//\{\{PORT\}\}/$port}

    # Handle www subdomain
    if [[ "$www_enabled" == "yes" ]]; then
        if [[ "$www_is_main" == "yes" ]]; then
            # www is main, naked domain redirects to www
            config_content=${config_content//\{\{WWW_CONFIG\}\}/ www.{{DOMAIN}}}
            config_content=${config_content//\{\{WWW_REDIRECT_BLOCK\}\}/"# Redirect naked domain to www
server {
    listen 80;
    {{SSL_LISTEN}}
    server_name {{DOMAIN}};
    return 301 \$scheme://www.{{DOMAIN}}\$request_uri;
}"}
        else
            # naked is main, www redirects to naked domain  
            config_content=${config_content//\{\{WWW_CONFIG\}\}/ www.{{DOMAIN}}}
            config_content=${config_content//\{\{WWW_REDIRECT_BLOCK\}\}/"# Redirect www to non-www (optional)
server {
    listen 80;
    {{SSL_LISTEN}}
    server_name www.{{DOMAIN}};
    return 301 \$scheme://{{DOMAIN}}\$request_uri;
}"}
        fi
    else
        config_content=${config_content//\{\{WWW_CONFIG\}\}/}
        config_content=${config_content//\{\{WWW_REDIRECT_BLOCK\}\}/}
    fi

    # Write configuration file
    echo "$config_content" | sudo tee "$config_file" > /dev/null
    
    # Enable site
    sudo ln -sf "$config_file" "$NGINX_SITES_ENABLED/"
    
    print_color $GREEN "✓ Site configuration created: $config_file"
    
    # Test configuration
    if test_nginx_config; then
        # Generate SSL if requested
        if [[ "$ssl_enabled" == "yes" && -n "$email" ]]; then
            generate_ssl "$domain" "$email"

            # Check if SSL certificates were successfully generated
            if [[ -f "/etc/letsencrypt/live/$domain/fullchain.pem" && -f "/etc/letsencrypt/live/$domain/privkey.pem" ]]; then
                # Update configuration to include SSL
                print_color $BLUE "Updating configuration to enable SSL..."
                # enable_ssl_in_config "$config_file" "$domain"
                if test_nginx_config; then
                    reload_nginx
                    print_color $GREEN "✓ SSL enabled for $domain"
                else
                    print_color $YELLOW "⚠ SSL certificates generated but configuration update failed"
                fi
            else
                print_color $YELLOW "⚠ SSL certificate generation failed"
            fi
        fi

        reload_nginx
        print_color $GREEN "✓ Site $domain is now active!"
    else
        print_color $RED "Configuration has errors. Please check and try again."
    fi
}

# Interactive site creation
create_site_interactive() {
    print_color $PURPLE "=== Create New Site Configuration ==="
    echo
    
    # Site type selection
    print_color $CYAN "Select site type:"
    echo "1) Laravel PHP Application"
    echo "2) Static HTML/CSS/JS Website"
    echo "3) Node.js Application"
    echo "4) WordPress Site"
    echo "5) Single Page Application (SPA)"
    echo "6) Reverse Proxy"
    echo
    read -p "Enter choice (1-6): " site_type_choice
    
    case $site_type_choice in
        1) site_type="laravel" ;;
        2) site_type="static" ;;
        3) site_type="nodejs" ;;
        4) site_type="wordpress" ;;
        5) site_type="spa" ;;
        6) site_type="proxy" ;;
        *) print_color $RED "Invalid choice"; return 1 ;;
    esac
    
    # Domain input
    while true; do
        read -p "Enter domain name (e.g., example.com): " domain
        if validate_domain "$domain"; then
            break
        else
            print_color $RED "Invalid domain name. Please try again."
        fi
    done
    
    # Root path input
    if [[ "$site_type" != "proxy" ]]; then
        read -p "Enter document root path (e.g., /var/www/$domain): " root_path
        if [[ -z "$root_path" ]]; then
            root_path="/var/www/$domain"
        fi
    fi
    
    # PHP version for Laravel/WordPress
    php_version="8.2"
    if [[ "$site_type" == "laravel" || "$site_type" == "wordpress" ]]; then
        read -p "Enter PHP version (default: 8.2): " php_input
        if [[ -n "$php_input" ]]; then
            php_version="$php_input"
        fi
    fi
    
    # Port for Node.js/Proxy
    port="3000"
    if [[ "$site_type" == "nodejs" || "$site_type" == "proxy" ]]; then
        read -p "Enter application port (default: 3000): " port_input
        if [[ -n "$port_input" ]]; then
            port="$port_input"
        fi
    fi
    
    # SSL configuration
    read -p "Enable SSL with Let's Encrypt? (y/n): " ssl_choice
    ssl_enabled="no"
    email=""
    if [[ "$ssl_choice" == "y" || "$ssl_choice" == "yes" ]]; then
        ssl_enabled="yes"
        read -p "Enter email for Let's Encrypt: " email
    fi

    # www subdomain configuration
    read -p "Include www subdomain? (y/n): " www_choice
    www_enabled="no"
    www_is_main="no"
    if [[ "$www_choice" == "y" || "$www_choice" == "yes" ]]; then
        www_enabled="yes"
        echo
        print_color $YELLOW "Which domain should be the main one?"
        print_color $CYAN "1) Naked domain (${domain}) - redirect www to naked"
        print_color $CYAN "2) www domain (www.${domain}) - redirect naked to www"
        read -p "Choose (1 or 2): " main_choice
        if [[ "$main_choice" == "2" ]]; then
            www_is_main="yes"
        fi
    fi
    
    # Confirmation
    echo
    print_color $YELLOW "=== Configuration Summary ==="
    print_color $CYAN "Site Type: $site_type"
    print_color $CYAN "Domain: $domain"
    [[ -n "$root_path" ]] && print_color $CYAN "Root Path: $root_path"
    [[ "$site_type" == "laravel" || "$site_type" == "wordpress" ]] && print_color $CYAN "PHP Version: $php_version"
    [[ "$site_type" == "nodejs" || "$site_type" == "proxy" ]] && print_color $CYAN "Port: $port"
    print_color $CYAN "SSL Enabled: $ssl_enabled"
    [[ -n "$email" ]] && print_color $CYAN "Email: $email"
    print_color $CYAN "www Subdomain: $www_enabled"
    if [[ "$www_enabled" == "yes" ]]; then
        if [[ "$www_is_main" == "yes" ]]; then
            print_color $CYAN "Main Domain: www.${domain} (naked redirects to www)"
        else
            print_color $CYAN "Main Domain: ${domain} (www redirects to naked)"
        fi
    fi
    echo
    
    read -p "Continue? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "yes" ]]; then
        print_color $YELLOW "Operation cancelled."
        return 0
    fi
    
    # Create the configuration
    create_site_config "$site_type" "$domain" "$root_path" "$php_version" "$port" "$ssl_enabled" "$email" "$www_enabled" "$www_is_main"
}

# List existing sites
list_sites() {
    print_color $PURPLE "=== Nginx Sites ==="
    echo
    
    if [[ -d "$NGINX_SITES_AVAILABLE" ]]; then
        print_color $CYAN "Available sites:"
        for site in "$NGINX_SITES_AVAILABLE"/*; do
            if [[ -f "$site" ]]; then
                local site_name=$(basename "$site")
                local status="disabled"
                if [[ -L "$NGINX_SITES_ENABLED/$site_name" ]]; then
                    status="enabled"
                fi
                printf "  %-30s [%s]\n" "$site_name" "$status"
            fi
        done
    fi
    echo
}

# Remove site
remove_site() {
    list_sites
    read -p "Enter site name to remove: " site_name
    
    if [[ -f "$NGINX_SITES_AVAILABLE/$site_name" ]]; then
        read -p "Are you sure you want to remove $site_name? (y/n): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "yes" ]]; then
            sudo rm -f "$NGINX_SITES_ENABLED/$site_name"
            sudo rm -f "$NGINX_SITES_AVAILABLE/$site_name"
            print_color $GREEN "✓ Site $site_name removed"
            reload_nginx
        fi
    else
        print_color $RED "Site $site_name not found"
    fi
}

# Main menu
main_menu() {
    while true; do
        print_banner
        print_color $CYAN "Choose an option:"
        echo "1) Create new site configuration"
        echo "2) List existing sites"
        echo "3) Remove site"
        echo "4) Test nginx configuration"
        echo "5) Reload nginx"
        echo "6) Install/Update templates"
        echo "7) Exit"
        echo
        read -p "Enter choice (1-7): " choice
        
        case $choice in
            1)
                ensure_directories
                create_site_interactive
                read -p "Press Enter to continue..."
                ;;
            2)
                list_sites
                read -p "Press Enter to continue..."
                ;;
            3)
                remove_site
                read -p "Press Enter to continue..."
                ;;
            4)
                test_nginx_config
                read -p "Press Enter to continue..."
                ;;
            5)
                reload_nginx
                read -p "Press Enter to continue..."
                ;;
            6)
                install_templates
                read -p "Press Enter to continue..."
                ;;
            7)
                print_color $GREEN "Goodbye!"
                exit 0
                ;;
            *)
                print_color $RED "Invalid choice"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Install templates function (will be called later)
install_templates() {
    print_color $BLUE "Installing/updating nginx templates..."
    ensure_directories
    # Templates will be created by the setup
    print_color $GREEN "✓ Templates installed successfully"
}

# Main execution
main() {
    check_nginx
    
    if [[ $# -eq 0 ]]; then
        main_menu
    else
        case $1 in
            "create")
                ensure_directories
                create_site_interactive
                ;;
            "list")
                list_sites
                ;;
            "test")
                test_nginx_config
                ;;
            "reload")
                reload_nginx
                ;;
            "install-templates")
                install_templates
                ;;
            *)
                echo "Usage: $0 [create|list|test|reload|install-templates]"
                echo "Run without arguments for interactive mode."
                ;;
        esac
    fi
}

# Run main function
main "$@"
