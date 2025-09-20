#!/bin/bash

# Example setup script demonstrating the nginx manager
# This script shows how to set up multiple sites quickly

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NGINX_MANAGER="$SCRIPT_DIR/nginx-manager.sh"

echo "=== Nginx Configuration Manager - Quick Setup Example ==="
echo

# Example 1: Laravel Application
echo "Setting up Laravel application..."
echo "Command: sudo $NGINX_MANAGER create-laravel laravel-app.local /var/www/laravel-app"
echo "# sudo $NGINX_MANAGER create-laravel laravel-app.local /var/www/laravel-app"
echo

# Example 2: Static Website
echo "Setting up static website..."
echo "Command: sudo $NGINX_MANAGER create-static portfolio.local /var/www/portfolio"
echo "# sudo $NGINX_MANAGER create-static portfolio.local /var/www/portfolio"
echo

# Example 3: Node.js API
echo "Setting up Node.js API..."
echo "Command: sudo $NGINX_MANAGER create-nodejs api.local 3000"
echo "# sudo $NGINX_MANAGER create-nodejs api.local 3000"
echo

# Example management commands
echo "=== Site Management Examples ==="
echo
echo "# Fix permissions (important after creating sites!):"
echo "sudo $NGINX_MANAGER fix-permissions /var/www/laravel-app"
echo "sudo $NGINX_MANAGER fix-permissions /var/www/portfolio"
echo
echo "# Enable a site:"
echo "sudo $NGINX_MANAGER enable laravel-app.local"
echo
echo "# Disable a site:"
echo "sudo $NGINX_MANAGER disable portfolio.local"
echo
echo "# List all sites:"
echo "sudo $NGINX_MANAGER list"
echo
echo "# Test configuration:"
echo "sudo $NGINX_MANAGER test"
echo
echo "# Reload nginx:"
echo "sudo $NGINX_MANAGER reload"
echo

echo "=== Local Development Setup (Optional) ==="
echo
echo "Add these lines to your /etc/hosts file:"
echo "127.0.0.1    laravel-app.local"
echo "127.0.0.1    portfolio.local"
echo "127.0.0.1    api.local"
echo
echo "Then visit:"
echo "- http://laravel-app.local"
echo "- http://portfolio.local"
echo "- http://api.local"
echo

echo "=== Directory Structure ==="
echo
echo "After setup, your nginx directories will look like:"
echo "/etc/nginx/sites-available/"
echo "├── laravel-app.local"
echo "├── portfolio.local"
echo "└── api.local"
echo
echo "/etc/nginx/sites-enabled/"
echo "├── laravel-app.local -> /etc/nginx/sites-available/laravel-app.local"
echo "├── portfolio.local -> /etc/nginx/sites-available/portfolio.local"
echo "└── api.local -> /etc/nginx/sites-available/api.local"
echo

echo "=== Important Notes ==="
echo
echo "1. Make sure nginx is installed: sudo apt install nginx"
echo "2. For Laravel: Install PHP-FPM: sudo apt install php8.1-fpm"
echo "3. For Node.js: Make sure your app is running on the specified port"
echo "4. Run all commands with sudo"
echo "5. Test configuration after changes: sudo nginx -t"
echo "6. Reload nginx after enabling sites: sudo systemctl reload nginx"
echo

echo "Run this script to see the commands without executing them."
echo "Remove the '#' from the commands above to actually execute them."
