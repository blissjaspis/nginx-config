#!/bin/bash

# diagnose.sh - nginx-manager diagnostic tool
# Helps troubleshoot "This site can't be reached" issues

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
    print_header "CHECKING NGINX INSTALLATION"
    
    if command -v nginx &> /dev/null; then
        local version=$(nginx -v 2>&1 | cut -d'/' -f2)
        print_check "ok" "nginx is installed (version: $version)"
        return 0
    else
        print_check "error" "nginx is NOT installed"
        print_color $YELLOW "To install nginx:"
        echo "  Ubuntu/Debian: sudo apt update && sudo apt install nginx"
        echo "  CentOS/RHEL: sudo yum install nginx"
        echo "  macOS: brew install nginx"
        return 1
    fi
}

# Check if nginx is running
check_nginx_running() {
    print_header "CHECKING NGINX SERVICE STATUS"
    
    if pgrep nginx > /dev/null; then
        print_check "ok" "nginx is running"
        
        # Check nginx master and worker processes
        local master_count=$(pgrep -f "nginx: master" | wc -l)
        local worker_count=$(pgrep -f "nginx: worker" | wc -l)
        print_color $BLUE "  Master processes: $master_count"
        print_color $BLUE "  Worker processes: $worker_count"
        return 0
    else
        print_check "error" "nginx is NOT running"
        print_color $YELLOW "To start nginx:"
        echo "  sudo systemctl start nginx    # systemd"
        echo "  sudo service nginx start     # SysV"
        echo "  sudo nginx                   # manual start"
        return 1
    fi
}

# Check nginx configuration
check_nginx_config() {
    print_header "CHECKING NGINX CONFIGURATION"
    
    if nginx -t &> /dev/null; then
        print_check "ok" "nginx configuration is valid"
    else
        print_check "error" "nginx configuration has errors"
        print_color $YELLOW "Configuration errors:"
        nginx -t 2>&1 | sed 's/^/  /'
        return 1
    fi
}

# Check listening ports
check_ports() {
    print_header "CHECKING LISTENING PORTS"
    
    # Check port 80
    if netstat -ln 2>/dev/null | grep -q ":80 " || ss -ln 2>/dev/null | grep -q ":80 "; then
        print_check "ok" "Port 80 (HTTP) is listening"
    else
        print_check "error" "Port 80 (HTTP) is NOT listening"
    fi
    
    # Check port 443
    if netstat -ln 2>/dev/null | grep -q ":443 " || ss -ln 2>/dev/null | grep -q ":443 "; then
        print_check "ok" "Port 443 (HTTPS) is listening"
    else
        print_check "warning" "Port 443 (HTTPS) is NOT listening (normal if no SSL sites)"
    fi
    
    # Show all nginx listening ports
    print_color $BLUE "nginx listening ports:"
    if command -v ss &> /dev/null; then
        ss -tlnp | grep nginx | sed 's/^/  /' || echo "  No nginx ports found"
    elif command -v netstat &> /dev/null; then
        netstat -tlnp 2>/dev/null | grep nginx | sed 's/^/  /' || echo "  No nginx ports found"
    else
        echo "  Cannot check ports (ss and netstat not available)"
    fi
}

# Check firewall status
check_firewall() {
    print_header "CHECKING FIREWALL STATUS"
    
    # Check ufw (Ubuntu/Debian)
    if command -v ufw &> /dev/null; then
        local ufw_status=$(ufw status 2>/dev/null | head -1)
        print_color $BLUE "UFW Status: $ufw_status"
        
        if ufw status 2>/dev/null | grep -q "80/tcp"; then
            print_check "ok" "Port 80 is allowed in UFW"
        else
            print_check "warning" "Port 80 might be blocked by UFW"
            print_color $YELLOW "To allow: sudo ufw allow 80"
        fi
        
        if ufw status 2>/dev/null | grep -q "443/tcp"; then
            print_check "ok" "Port 443 is allowed in UFW"
        else
            print_check "warning" "Port 443 might be blocked by UFW"
            print_color $YELLOW "To allow: sudo ufw allow 443"
        fi
    fi
    
    # Check iptables
    if command -v iptables &> /dev/null; then
        local iptables_rules=$(iptables -L INPUT 2>/dev/null | wc -l)
        if [[ $iptables_rules -gt 3 ]]; then
            print_color $BLUE "iptables rules detected ($iptables_rules rules)"
            print_color $YELLOW "Check if ports 80/443 are allowed:"
            echo "  sudo iptables -L INPUT | grep -E '(80|443)'"
        fi
    fi
    
    # Check firewalld (CentOS/RHEL)
    if command -v firewall-cmd &> /dev/null; then
        if systemctl is-active firewalld &> /dev/null; then
            print_color $BLUE "firewalld is active"
            
            if firewall-cmd --list-services 2>/dev/null | grep -q "http"; then
                print_check "ok" "HTTP service is allowed in firewalld"
            else
                print_check "warning" "HTTP service might be blocked by firewalld"
                print_color $YELLOW "To allow: sudo firewall-cmd --permanent --add-service=http"
            fi
            
            if firewall-cmd --list-services 2>/dev/null | grep -q "https"; then
                print_check "ok" "HTTPS service is allowed in firewalld"
            else
                print_check "warning" "HTTPS service might be blocked by firewalld"
                print_color $YELLOW "To allow: sudo firewall-cmd --permanent --add-service=https"
            fi
        fi
    fi
}

# Check sites configuration
check_sites() {
    print_header "CHECKING NGINX SITES"
    
    local sites_available="/etc/nginx/sites-available"
    local sites_enabled="/etc/nginx/sites-enabled"
    
    if [[ -d "$sites_available" ]]; then
        local available_count=$(ls -1 "$sites_available" 2>/dev/null | wc -l)
        print_color $BLUE "Sites available: $available_count"
        
        if [[ $available_count -gt 0 ]]; then
            for site in "$sites_available"/*; do
                if [[ -f "$site" ]]; then
                    local site_name=$(basename "$site")
                    if [[ -L "$sites_enabled/$site_name" ]]; then
                        print_check "ok" "$site_name (enabled)"
                    else
                        print_check "warning" "$site_name (disabled)"
                    fi
                fi
            done
        fi
    else
        print_check "warning" "sites-available directory not found"
        print_color $YELLOW "nginx might use conf.d directory instead"
    fi
    
    if [[ -d "/etc/nginx/conf.d" ]]; then
        local conf_count=$(ls -1 /etc/nginx/conf.d/*.conf 2>/dev/null | wc -l)
        if [[ $conf_count -gt 0 ]]; then
            print_color $BLUE "Configurations in conf.d: $conf_count"
        fi
    fi
}

# Check DNS resolution
check_dns() {
    print_header "CHECKING DNS RESOLUTION"
    
    read -p "Enter your domain name to test (or press Enter to skip): " domain
    
    if [[ -n "$domain" ]]; then
        print_color $BLUE "Testing DNS resolution for: $domain"
        
        # Check if domain resolves
        if nslookup "$domain" &> /dev/null || dig "$domain" &> /dev/null; then
            local ip=$(nslookup "$domain" 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}' || dig +short "$domain" 2>/dev/null | head -1)
            print_check "ok" "$domain resolves to: $ip"
            
            # Check if it resolves to this server
            local server_ip=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "unknown")
            if [[ "$ip" == "$server_ip" ]]; then
                print_check "ok" "Domain points to this server ($server_ip)"
            else
                print_check "warning" "Domain points to $ip, but this server is $server_ip"
                print_color $YELLOW "The domain might not be pointing to this server"
            fi
        else
            print_check "error" "$domain does not resolve"
            print_color $YELLOW "Check your DNS settings with your domain provider"
        fi
        
        # Test HTTP connection
        print_color $BLUE "Testing HTTP connection..."
        if curl -s -o /dev/null -w "%{http_code}" "http://$domain" --connect-timeout 5 | grep -q "200\|301\|302"; then
            print_check "ok" "HTTP connection successful"
        else
            print_check "error" "HTTP connection failed"
        fi
        
        # Test HTTPS connection
        print_color $BLUE "Testing HTTPS connection..."
        if curl -s -o /dev/null -w "%{http_code}" "https://$domain" --connect-timeout 5 2>/dev/null | grep -q "200\|301\|302"; then
            print_check "ok" "HTTPS connection successful"
        else
            print_check "warning" "HTTPS connection failed (normal if no SSL certificate)"
        fi
    fi
}

# Check system resources
check_resources() {
    print_header "CHECKING SYSTEM RESOURCES"
    
    # Check disk space
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $disk_usage -lt 90 ]]; then
        print_check "ok" "Disk space: ${disk_usage}% used"
    else
        print_check "warning" "Disk space: ${disk_usage}% used (running low)"
    fi
    
    # Check memory
    if command -v free &> /dev/null; then
        local mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
        print_color $BLUE "Memory usage: ${mem_usage}%"
    fi
    
    # Check load average
    if [[ -f /proc/loadavg ]]; then
        local load=$(cat /proc/loadavg | awk '{print $1}')
        print_color $BLUE "Load average (1min): $load"
    fi
}

# Check logs for errors
check_logs() {
    print_header "CHECKING NGINX ERROR LOGS"
    
    local error_log="/var/log/nginx/error.log"
    if [[ -f "$error_log" ]]; then
        print_color $BLUE "Recent nginx errors (last 10 lines):"
        tail -10 "$error_log" 2>/dev/null | sed 's/^/  /' || echo "  No recent errors found"
    else
        print_check "warning" "nginx error log not found at $error_log"
    fi
    
    # Check for permission issues
    print_color $BLUE "Checking for permission errors..."
    if grep -i "permission denied" "$error_log" 2>/dev/null | tail -3; then
        print_check "warning" "Permission errors found in logs"
    else
        print_check "ok" "No permission errors in recent logs"
    fi
}

# Main function
main() {
    print_color $PURPLE "nginx-manager Diagnostic Tool"
    print_color $PURPLE "============================="
    echo
    
    # Run all checks
    check_nginx_installed || exit 1
    check_nginx_running
    check_nginx_config
    check_ports
    check_firewall
    check_sites
    check_dns
    check_resources
    check_logs
    
    print_header "DIAGNOSTIC COMPLETE"
    print_color $YELLOW "Common solutions for 'This site can't be reached':"
    echo "1. Start nginx: sudo systemctl start nginx"
    echo "2. Enable nginx: sudo systemctl enable nginx"
    echo "3. Check firewall: sudo ufw allow 80 && sudo ufw allow 443"
    echo "4. Verify domain DNS points to this server"
    echo "5. Test configuration: sudo nginx -t"
    echo "6. Reload nginx: sudo systemctl reload nginx"
    echo
    print_color $CYAN "Need more help? Check the README.md file for detailed troubleshooting."
}

# Run the diagnostic
main "$@"
