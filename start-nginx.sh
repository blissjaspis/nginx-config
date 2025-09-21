#!/bin/bash

# start-nginx.sh - Get nginx running from scratch
# For when nginx is completely not running

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

# Check if nginx is installed
check_nginx_installed() {
    print_header "STEP 1: CHECK NGINX INSTALLATION"
    
    if command -v nginx &> /dev/null; then
        local version=$(nginx -v 2>&1 | cut -d'/' -f2)
        print_check "ok" "nginx is installed (version: $version)"
        return 0
    else
        print_check "error" "nginx is NOT installed"
        print_color $YELLOW "Installing nginx..."
        
        # Detect OS and install nginx
        if [[ -f /etc/debian_version ]]; then
            sudo apt update
            sudo apt install -y nginx
        elif [[ -f /etc/redhat-release ]]; then
            sudo yum install -y nginx || sudo dnf install -y nginx
        else
            print_color $RED "Cannot detect OS. Please install nginx manually:"
            echo "  Ubuntu/Debian: sudo apt install nginx"
            echo "  CentOS/RHEL: sudo yum install nginx"
            exit 1
        fi
        
        if command -v nginx &> /dev/null; then
            print_check "ok" "nginx installed successfully"
        else
            print_check "error" "nginx installation failed"
            exit 1
        fi
    fi
}

# Check nginx service status
check_nginx_service() {
    print_header "STEP 2: CHECK NGINX SERVICE STATUS"
    
    if systemctl is-active nginx &> /dev/null; then
        print_check "ok" "nginx service is active and running"
        return 0
    elif systemctl is-enabled nginx &> /dev/null; then
        print_check "warning" "nginx service is enabled but not running"
    else
        print_check "warning" "nginx service is not enabled"
        print_color $YELLOW "Enabling nginx service..."
        sudo systemctl enable nginx
    fi
    
    print_color $BLUE "Current nginx service status:"
    sudo systemctl status nginx --no-pager -l || true
}

# Test nginx configuration before starting
test_nginx_config() {
    print_header "STEP 3: TEST NGINX CONFIGURATION"
    
    print_color $BLUE "Testing nginx configuration..."
    if sudo nginx -t; then
        print_check "ok" "nginx configuration is valid"
        return 0
    else
        print_check "error" "nginx configuration has errors"
        print_color $YELLOW "Attempting to fix common configuration issues..."
        
        # Check if nginx.conf exists
        if [[ ! -f /etc/nginx/nginx.conf ]]; then
            print_color $YELLOW "Main nginx.conf missing, creating basic configuration..."
            create_basic_nginx_conf
        fi
        
        # Test again
        if sudo nginx -t; then
            print_check "ok" "Configuration fixed and is now valid"
            return 0
        else
            print_check "error" "Configuration still has errors. Manual fix needed."
            return 1
        fi
    fi
}

# Create basic nginx.conf if missing
create_basic_nginx_conf() {
    local nginx_conf="/etc/nginx/nginx.conf"
    local basic_config="user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 768;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    gzip on;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}"

    sudo mkdir -p /etc/nginx/conf.d
    sudo mkdir -p /etc/nginx/sites-available
    sudo mkdir -p /etc/nginx/sites-enabled
    
    echo "$basic_config" | sudo tee "$nginx_conf" > /dev/null
    print_check "ok" "Created basic nginx.conf"
}

# Create default site if missing
create_default_site() {
    print_header "STEP 4: CREATE DEFAULT SITE"
    
    local default_site="/etc/nginx/sites-available/default"
    
    if [[ -f "$default_site" ]] && [[ -L "/etc/nginx/sites-enabled/default" ]]; then
        print_check "ok" "Default site already exists and is enabled"
        return 0
    fi
    
    print_color $YELLOW "Creating default site configuration..."
    
    # Create web root directory
    sudo mkdir -p /var/www/html
    
    # Create simple index.html
    local index_content="<!DOCTYPE html>
<html>
<head>
    <title>Welcome to nginx!</title>
    <style>
        body { width: 35em; margin: 0 auto; font-family: Tahoma, Verdana, Arial, sans-serif; }
    </style>
</head>
<body>
    <h1>Welcome to nginx!</h1>
    <p>If you see this page, the nginx web server is successfully installed and working.</p>
    <p><em>Thank you for using nginx.</em></p>
</body>
</html>"
    
    echo "$index_content" | sudo tee /var/www/html/index.html > /dev/null
    
    # Create default site configuration
    local default_config="server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;

    server_name _;

    location / {
        try_files \$uri \$uri/ =404;
    }
}"

    echo "$default_config" | sudo tee "$default_site" > /dev/null
    sudo ln -sf "$default_site" "/etc/nginx/sites-enabled/"
    
    print_check "ok" "Created default site"
    
    # Set proper permissions
    sudo chown -R www-data:www-data /var/www/html
    sudo chmod -R 755 /var/www/html
}

# Start nginx service
start_nginx() {
    print_header "STEP 5: START NGINX SERVICE"
    
    print_color $YELLOW "Starting nginx service..."
    
    if sudo systemctl start nginx; then
        print_check "ok" "nginx service started successfully"
        
        # Wait a moment for the service to fully start
        sleep 2
        
        if systemctl is-active nginx &> /dev/null; then
            print_check "ok" "nginx service is now active"
        else
            print_check "warning" "nginx service start command succeeded but service not active"
        fi
    else
        print_check "error" "Failed to start nginx service"
        print_color $YELLOW "Checking what went wrong..."
        sudo systemctl status nginx --no-pager -l || true
        sudo journalctl -u nginx --no-pager -l -n 20 || true
        return 1
    fi
}

# Verify nginx is listening
verify_listening() {
    print_header "STEP 6: VERIFY NGINX IS LISTENING"
    
    print_color $BLUE "Checking if nginx is now listening on port 80..."
    sleep 2
    
    if netstat -tlnp 2>/dev/null | grep ":80.*nginx" || ss -tlnp 2>/dev/null | grep ":80.*nginx"; then
        print_check "ok" "nginx is listening on port 80!"
        
        echo "Nginx listening details:"
        netstat -tlnp 2>/dev/null | grep nginx | sed 's/^/  /' || ss -tlnp 2>/dev/null | grep nginx | sed 's/^/  /'
        
    else
        print_check "error" "nginx is still not listening on port 80"
        
        print_color $YELLOW "Debugging information:"
        echo "Nginx processes:"
        ps aux | grep nginx | grep -v grep | sed 's/^/  /' || echo "  No nginx processes found"
        
        echo "All listening ports:"
        netstat -tlnp 2>/dev/null | grep LISTEN | sed 's/^/  /' || ss -tlnp | grep LISTEN | sed 's/^/  /'
        
        return 1
    fi
}

# Test HTTP connection
test_connection() {
    print_header "STEP 7: TEST HTTP CONNECTION"
    
    print_color $BLUE "Testing local HTTP connection..."
    
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost" | grep -q "200"; then
        print_check "ok" "HTTP connection to localhost successful"
    else
        print_check "warning" "HTTP connection to localhost failed"
    fi
    
    # Get server IP
    local server_ip=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}' || echo "unknown")
    
    if [[ "$server_ip" != "unknown" ]]; then
        print_color $BLUE "Testing external HTTP connection to $server_ip..."
        if curl -s -o /dev/null -w "%{http_code}" "http://$server_ip" --connect-timeout 5 | grep -q "200"; then
            print_check "ok" "HTTP connection to $server_ip successful"
        else
            print_check "warning" "HTTP connection to $server_ip failed (could be firewall)"
        fi
    fi
}

# Show final status
show_final_status() {
    print_header "FINAL STATUS"
    
    if netstat -tlnp 2>/dev/null | grep ":80.*nginx" || ss -tlnp 2>/dev/null | grep ":80.*nginx"; then
        print_color $GREEN "🎉 SUCCESS! nginx is now running and listening on port 80"
        echo
        print_color $CYAN "Your nginx is ready! Next steps:"
        echo "1. Test: curl -I http://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')"
        echo "2. Create your site config: sudo ./nginx-manager.sh create"
        echo "3. Point your domain to this server IP"
        echo "4. Access your site: http://your-domain.com"
        echo
        print_color $YELLOW "Current nginx status:"
        sudo systemctl status nginx --no-pager -l | head -10
    else
        print_color $RED "❌ nginx is still not working properly"
        echo
        print_color $YELLOW "Manual troubleshooting needed:"
        echo "1. Check error logs: sudo tail -f /var/log/nginx/error.log"
        echo "2. Check system logs: sudo journalctl -u nginx -f"
        echo "3. Check configuration: sudo nginx -t"
        echo "4. Check service status: sudo systemctl status nginx"
    fi
}

# Main function
main() {
    print_color $PURPLE "nginx Startup Fix Tool"
    print_color $PURPLE "====================="
    echo
    print_color $BLUE "This script will get nginx running from scratch"
    echo
    
    check_nginx_installed
    check_nginx_service
    test_nginx_config || exit 1
    create_default_site
    start_nginx || exit 1
    verify_listening || exit 1
    test_connection
    show_final_status
}

# Run the startup fix
main "$@"
