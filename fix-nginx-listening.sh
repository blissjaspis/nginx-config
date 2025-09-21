#!/bin/bash

# fix-nginx-listening.sh - Fix nginx not listening on port 80
# This script helps diagnose and fix nginx listening issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_header() {
    echo
    print_color $CYAN "================================================================"
    print_color $CYAN "$1"
    print_color $CYAN "================================================================"
}

print_check() {
    local status=$1
    local message=$2
    if [[ "$status" == "ok" ]]; then
        print_color $GREEN "✓ $message"
    elif [[ "$status" == "warning" ]]; then
        print_color $YELLOW "⚠ $message"
    else
        print_color $RED "✗ $message"
    fi
}

# Check if nginx is running
check_nginx_status() {
    print_header "STEP 1: CHECK NGINX STATUS"
    
    if systemctl is-active nginx &> /dev/null; then
        print_check "ok" "nginx service is active"
    elif service nginx status &> /dev/null; then
        print_check "ok" "nginx service is running"
    elif pgrep nginx > /dev/null; then
        print_check "warning" "nginx processes found but service might not be managed"
    else
        print_check "error" "nginx is NOT running"
        print_color $YELLOW "Starting nginx..."
        
        # Try to start nginx
        if systemctl start nginx 2>/dev/null || service nginx start 2>/dev/null; then
            print_check "ok" "nginx started successfully"
        else
            print_check "error" "Failed to start nginx - checking for errors..."
            return 1
        fi
    fi
}

# Check nginx configuration
check_nginx_config() {
    print_header "STEP 2: CHECK NGINX CONFIGURATION"
    
    print_color $BLUE "Testing nginx configuration..."
    if nginx -t; then
        print_check "ok" "nginx configuration is valid"
    else
        print_check "error" "nginx configuration has errors"
        print_color $YELLOW "Fix the configuration errors above, then run:"
        echo "  sudo nginx -t"
        echo "  sudo systemctl restart nginx"
        return 1
    fi
}

# Check what nginx is configured to listen on
check_listening_config() {
    print_header "STEP 3: CHECK LISTENING CONFIGURATION"
    
    print_color $BLUE "Checking nginx configuration for listen directives..."
    
    # Find nginx config files
    local main_config="/etc/nginx/nginx.conf"
    local sites_dir="/etc/nginx/sites-enabled"
    local conf_dir="/etc/nginx/conf.d"
    
    echo "Looking for 'listen' directives in nginx configuration:"
    
    # Check main config
    if [[ -f "$main_config" ]]; then
        echo "Main config ($main_config):"
        grep -n "listen" "$main_config" 2>/dev/null | sed 's/^/  /' || echo "  No listen directives found"
    fi
    
    # Check sites-enabled
    if [[ -d "$sites_dir" ]]; then
        echo "Sites enabled ($sites_dir):"
        find "$sites_dir" -name "*.conf" -o -type f ! -name ".*" | while read -r file; do
            echo "  File: $(basename "$file")"
            grep -n "listen" "$file" 2>/dev/null | sed 's/^/    /' || echo "    No listen directives found"
        done
    fi
    
    # Check conf.d
    if [[ -d "$conf_dir" ]]; then
        echo "Config directory ($conf_dir):"
        find "$conf_dir" -name "*.conf" | while read -r file; do
            echo "  File: $(basename "$file")"
            grep -n "listen" "$file" 2>/dev/null | sed 's/^/    /' || echo "    No listen directives found"
        done
    fi
}

# Check if default site exists and what it listens on
check_default_site() {
    print_header "STEP 4: CHECK DEFAULT SITE"
    
    local default_sites=(
        "/etc/nginx/sites-enabled/default"
        "/etc/nginx/sites-available/default"
        "/etc/nginx/conf.d/default.conf"
    )
    
    local found_default=false
    
    for site in "${default_sites[@]}"; do
        if [[ -f "$site" ]]; then
            found_default=true
            print_color $BLUE "Found default site: $site"
            
            if [[ "$site" == *"sites-enabled"* ]]; then
                print_check "ok" "Default site is enabled"
            else
                print_check "warning" "Default site exists but might not be enabled"
            fi
            
            echo "Listen directives in default site:"
            grep -n "listen" "$site" | sed 's/^/  /' || echo "  No listen directives found"
            break
        fi
    done
    
    if [[ "$found_default" == false ]]; then
        print_check "error" "No default site found"
        print_color $YELLOW "This might be why nginx isn't listening on port 80"
        echo
        print_color $YELLOW "Creating a basic default site..."
        create_default_site
    fi
}

# Create a basic default site
create_default_site() {
    local default_site="/etc/nginx/sites-available/default"
    local default_content="server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    server_name _;
    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
}"

    echo "$default_content" | sudo tee "$default_site" > /dev/null
    sudo ln -sf "$default_site" "/etc/nginx/sites-enabled/"
    
    print_check "ok" "Created basic default site"
    print_color $YELLOW "Testing new configuration..."
    
    if nginx -t; then
        print_check "ok" "Configuration is valid"
        print_color $YELLOW "Reloading nginx..."
        sudo systemctl reload nginx
        print_check "ok" "nginx reloaded"
    else
        print_check "error" "Configuration is invalid"
    fi
}

# Check what's actually listening on ports
check_actual_ports() {
    print_header "STEP 5: CHECK ACTUAL LISTENING PORTS"
    
    print_color $BLUE "Checking what's listening on ports 80 and 443..."
    
    # Check port 80
    if netstat -tlnp 2>/dev/null | grep ":80 " || ss -tlnp 2>/dev/null | grep ":80 "; then
        print_check "ok" "Something is listening on port 80"
        echo "Port 80 details:"
        netstat -tlnp 2>/dev/null | grep ":80 " | sed 's/^/  /' || ss -tlnp 2>/dev/null | grep ":80 " | sed 's/^/  /'
    else
        print_check "error" "Nothing is listening on port 80"
    fi
    
    # Check port 443
    if netstat -tlnp 2>/dev/null | grep ":443 " || ss -tlnp 2>/dev/null | grep ":443 "; then
        print_check "ok" "Something is listening on port 443"
        echo "Port 443 details:"
        netstat -tlnp 2>/dev/null | grep ":443 " | sed 's/^/  /' || ss -tlnp 2>/dev/null | grep ":443 " | sed 's/^/  /'
    else
        print_check "warning" "Nothing is listening on port 443 (normal if no SSL)"
    fi
    
    # Show all nginx processes and ports
    echo
    print_color $BLUE "All nginx listening ports:"
    netstat -tlnp 2>/dev/null | grep nginx | sed 's/^/  /' || ss -tlnp 2>/dev/null | grep nginx | sed 's/^/  /' || echo "  No nginx ports found"
}

# Restart nginx and verify
restart_and_verify() {
    print_header "STEP 6: RESTART NGINX AND VERIFY"
    
    print_color $YELLOW "Restarting nginx service..."
    
    if sudo systemctl restart nginx; then
        print_check "ok" "nginx restarted successfully"
        sleep 2
        
        # Check if it's now listening
        if netstat -tlnp 2>/dev/null | grep ":80.*nginx" || ss -tlnp 2>/dev/null | grep ":80.*nginx"; then
            print_check "ok" "nginx is now listening on port 80!"
        else
            print_check "error" "nginx still not listening on port 80"
            
            print_color $YELLOW "Checking nginx error logs..."
            sudo tail -10 /var/log/nginx/error.log 2>/dev/null | sed 's/^/  /' || echo "  No error log found"
        fi
    else
        print_check "error" "Failed to restart nginx"
        print_color $YELLOW "Checking why nginx won't start..."
        sudo systemctl status nginx | sed 's/^/  /'
    fi
}

# Show final status and next steps
show_final_status() {
    print_header "FINAL STATUS AND NEXT STEPS"
    
    # Test ports again
    if netstat -tlnp 2>/dev/null | grep ":80.*nginx" || ss -tlnp 2>/dev/null | grep ":80.*nginx"; then
        print_check "ok" "nginx is listening on port 80"
        print_color $GREEN "🎉 SUCCESS! Your nginx should now be accessible."
        echo
        print_color $CYAN "Test your site:"
        echo "1. curl -I http://your-domain.com"
        echo "2. curl -I http://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')"
        echo "3. Open http://your-domain.com in a browser"
    else
        print_check "error" "nginx is still not listening on port 80"
        print_color $YELLOW "Manual troubleshooting needed:"
        echo "1. Check nginx error logs: sudo tail -f /var/log/nginx/error.log"
        echo "2. Check nginx status: sudo systemctl status nginx"
        echo "3. Check configuration syntax: sudo nginx -t"
        echo "4. Check for port conflicts: sudo netstat -tlnp | grep :80"
    fi
}

# Main function
main() {
    print_color $PURPLE "nginx Listening Port Fix Tool"
    print_color $PURPLE "============================"
    echo
    
    check_nginx_status || exit 1
    check_nginx_config || exit 1
    check_listening_config
    check_default_site
    check_actual_ports
    restart_and_verify
    show_final_status
}

# Run the fix
main "$@"
