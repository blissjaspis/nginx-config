#!/bin/bash

# debug-site-priority.sh - Debug why specific site isn't loading
# This helps when nginx shows default page instead of your site

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

# Get domain from user
get_domain() {
    if [[ -n "$1" ]]; then
        DOMAIN="$1"
    else
        read -p "Enter your domain name (e.g., bliss.jaspis.me): " DOMAIN
    fi
    
    if [[ -z "$DOMAIN" ]]; then
        print_color $RED "Domain name is required"
        exit 1
    fi
    
    print_color $BLUE "Debugging site: $DOMAIN"
}

# Check what nginx configuration is actually loaded
check_loaded_config() {
    print_header "STEP 1: CHECK LOADED NGINX CONFIGURATION"
    
    print_color $BLUE "Checking all server blocks that nginx has loaded..."
    
    echo "All listen directives:"
    nginx -T 2>/dev/null | grep -n "listen" | sed 's/^/  /' || echo "  No listen directives found"
    
    echo
    echo "All server_name directives:"
    nginx -T 2>/dev/null | grep -n "server_name" | sed 's/^/  /' || echo "  No server_name directives found"
    
    echo
    echo "Looking for default_server:"
    nginx -T 2>/dev/null | grep -n "default_server" | sed 's/^/  /' || echo "  No default_server found"
}

# Check site-specific configuration
check_site_config() {
    print_header "STEP 2: CHECK SITE-SPECIFIC CONFIGURATION"
    
    local config_locations=(
        "/etc/nginx/sites-available/$DOMAIN"
        "/etc/nginx/sites-enabled/$DOMAIN"
        "/etc/nginx/conf.d/$DOMAIN.conf"
    )
    
    local found_config=false
    
    for config in "${config_locations[@]}"; do
        if [[ -f "$config" ]]; then
            found_config=true
            print_check "ok" "Found config: $config"
            
            echo "Configuration content:"
            cat "$config" | sed 's/^/  /'
            echo
            break
        fi
    done
    
    if [[ "$found_config" == false ]]; then
        print_check "error" "No configuration found for $DOMAIN"
        return 1
    fi
    
    # Check if it's enabled (symlinked)
    if [[ -L "/etc/nginx/sites-enabled/$DOMAIN" ]]; then
        print_check "ok" "Site is enabled (symlinked)"
    elif [[ -f "/etc/nginx/conf.d/$DOMAIN.conf" ]]; then
        print_check "ok" "Site is in conf.d (auto-enabled)"
    else
        print_check "error" "Site is NOT enabled"
        return 1
    fi
}

# Check for conflicting default site
check_default_conflicts() {
    print_header "STEP 3: CHECK FOR DEFAULT SITE CONFLICTS"
    
    local default_sites=(
        "/etc/nginx/sites-enabled/default"
        "/etc/nginx/conf.d/default.conf"
    )
    
    for default in "${default_sites[@]}"; do
        if [[ -f "$default" ]]; then
            print_check "warning" "Default site found: $default"
            
            echo "Default site configuration:"
            cat "$default" | sed 's/^/  /'
            echo
            
            if grep -q "default_server" "$default"; then
                print_check "error" "Default site has 'default_server' - this takes precedence!"
                print_color $YELLOW "Solution: Remove default_server from default site or disable it"
                return 1
            fi
        fi
    done
}

# Check nginx configuration syntax
check_syntax() {
    print_header "STEP 4: CHECK NGINX SYNTAX"
    
    if nginx -t; then
        print_check "ok" "nginx configuration syntax is valid"
    else
        print_check "error" "nginx configuration has syntax errors"
        return 1
    fi
}

# Check server directive priority
check_priority() {
    print_header "STEP 5: CHECK SERVER DIRECTIVE PRIORITY"
    
    print_color $BLUE "nginx server selection priority:"
    echo "1. Exact server_name match"
    echo "2. Wildcard server_name (*.example.com)"
    echo "3. Regular expression server_name"
    echo "4. default_server directive"
    echo "5. First server block in configuration"
    echo
    
    print_color $BLUE "Current server blocks in order:"
    nginx -T 2>/dev/null | grep -A5 "server {" | sed 's/^/  /'
}

# Test domain resolution
test_domain() {
    print_header "STEP 6: TEST DOMAIN RESOLUTION"
    
    print_color $BLUE "Testing if $DOMAIN resolves to this server..."
    
    local domain_ip=$(nslookup "$DOMAIN" 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}' || dig +short "$DOMAIN" 2>/dev/null | head -1 || echo "unknown")
    local server_ip=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}' || echo "unknown")
    
    print_color $BLUE "Domain $DOMAIN resolves to: $domain_ip"
    print_color $BLUE "This server IP is: $server_ip"
    
    if [[ "$domain_ip" == "$server_ip" ]]; then
        print_check "ok" "Domain points to this server"
    else
        print_check "warning" "Domain points to different IP"
    fi
}

# Suggest fixes
suggest_fixes() {
    print_header "SUGGESTED FIXES"
    
    print_color $YELLOW "If your site still shows the default page, try these fixes:"
    echo
    echo "1. REMOVE DEFAULT_SERVER from default site:"
    echo "   sudo sed -i 's/default_server//g' /etc/nginx/sites-enabled/default"
    echo "   sudo nginx -t && sudo systemctl reload nginx"
    echo
    echo "2. DISABLE the default site completely:"
    echo "   sudo rm /etc/nginx/sites-enabled/default"
    echo "   sudo nginx -t && sudo systemctl reload nginx"
    echo
    echo "3. ADD default_server to YOUR site:"
    echo "   Edit /etc/nginx/sites-available/$DOMAIN"
    echo "   Change 'listen 80;' to 'listen 80 default_server;'"
    echo "   sudo nginx -t && sudo systemctl reload nginx"
    echo
    echo "4. CHECK server_name directive:"
    echo "   Make sure your config has: server_name $DOMAIN;"
    echo "   Not: server_name localhost; or server_name _;"
    echo
    echo "5. VERIFY configuration order:"
    echo "   nginx -T | grep -A10 'server_name $DOMAIN'"
}

# Test HTTP request
test_http() {
    print_header "STEP 7: TEST HTTP REQUEST"
    
    print_color $BLUE "Testing HTTP request to $DOMAIN..."
    
    local response=$(curl -s -I "http://$DOMAIN" 2>/dev/null || echo "Request failed")
    echo "HTTP Response:"
    echo "$response" | sed 's/^/  /'
    
    print_color $BLUE "Testing with Host header explicitly..."
    local host_response=$(curl -s -H "Host: $DOMAIN" "http://localhost" 2>/dev/null || echo "Request failed")
    if echo "$host_response" | grep -q "nginx"; then
        print_check "warning" "Still getting default nginx page with Host header"
    else
        print_check "ok" "Custom response received with Host header"
    fi
}

# Main function
main() {
    print_color $PURPLE "nginx Site Priority Debug Tool"
    print_color $PURPLE "=============================="
    echo
    
    get_domain "$1"
    check_loaded_config
    check_site_config || exit 1
    check_default_conflicts
    check_syntax || exit 1
    check_priority
    test_domain
    test_http
    suggest_fixes
    
    echo
    print_color $CYAN "Debug complete! Follow the suggested fixes above."
}

# Run the debug
main "$@"
