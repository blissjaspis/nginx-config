# Nginx Configuration Manager

A bash script to automate nginx configuration creation and management for different types of web applications.

## Features

- **Laravel Support**: Optimized configuration for Laravel applications with PHP-FPM
- **Static Sites**: Configuration for static websites with proper caching headers
- **Node.js Apps**: Reverse proxy configuration for Node.js applications
- **Site Management**: Easy enable/disable of sites with symbolic links
- **Security Headers**: Includes security headers by default
- **Gzip Compression**: Optimized compression settings
- **Caching**: Smart caching rules for different file types

## Installation

1. Clone or download this repository
2. Make the script executable:
   ```bash
   chmod +x nginx-manager.sh
   ```

3. Run as root or with sudo (required for nginx configuration):
   ```bash
   sudo ./nginx-manager.sh
   ```

## Usage

### Creating a Laravel Application

```bash
sudo ./nginx-manager.sh create-laravel example.com /var/www/laravel-app
```

With custom PHP version:
```bash
sudo ./nginx-manager.sh create-laravel example.com /var/www/laravel-app --php-version 8.2
```

### Creating a Static Website

```bash
sudo ./nginx-manager.sh create-static static.example.com /var/www/static-site
```

### Creating a Node.js Application

```bash
sudo ./nginx-manager.sh create-nodejs api.example.com 3000
```

### Fixing Permissions

Nginx needs read access to your website files. Fix permissions after creating a site:

```bash
# Fix permissions using group method (recommended)
sudo ./nginx-manager.sh fix-permissions /var/www/myapp

# Check permissions without fixing
sudo ./nginx-manager.sh fix-permissions --check-only /var/www/myapp

# Use custom nginx user (if different from default)
sudo ./nginx-manager.sh fix-permissions --nginx-user www-data /var/www/myapp
```

**Permission Methods:**
- `group` (default): Adds nginx user to file owner's group
- `owner`: Changes file ownership to nginx user
- `world`: Makes files world-readable (less secure)

### Managing Sites

Enable a site:
```bash
sudo ./nginx-manager.sh enable example.com
```

Disable a site:
```bash
sudo ./nginx-manager.sh disable example.com
```

### Testing and Reloading

Test configuration:
```bash
sudo ./nginx-manager.sh test
```

Reload nginx:
```bash
sudo ./nginx-manager.sh reload
```

Test and reload in one command:
```bash
sudo ./nginx-manager.sh test && sudo ./nginx-manager.sh reload
```

### Listing Sites

View available and enabled sites:
```bash
sudo ./nginx-manager.sh list
```

## Configuration Details

### Laravel Configuration Features

- PHP-FPM integration with configurable version
- Laravel-specific routing (`/index.php?$query_string`)
- Storage directory access
- Security headers (X-Frame-Options, CSP, etc.)
- Static file caching for assets
- Hidden file protection

### Static Website Features

- Optimized caching for different file types
- HTML files with 1-hour cache
- Static assets with 1-year cache
- Security headers
- Gzip compression

### Node.js Configuration Features

- Reverse proxy to localhost with configurable port
- WebSocket support
- Keep-alive connections
- Proper header forwarding
- Static file caching

## Security Features

All configurations include:
- `X-Frame-Options: SAMEORIGIN`
- `X-Content-Type-Options: nosniff`
- `X-XSS-Protection: 1; mode=block`
- `Referrer-Policy: no-referrer-when-downgrade`
- Hidden file protection (`.htaccess`, `.env`, etc.)
- Secure caching headers

## Examples

### Complete Laravel Setup

```bash
# 1. Create the configuration
sudo ./nginx-manager.sh create-laravel myapp.com /var/www/my-laravel-app

# 2. Test the configuration
sudo ./nginx-manager.sh test

# 3. Reload nginx
sudo ./nginx-manager.sh reload

# 4. Verify the site is working
curl -I http://myapp.com
```

### Complete Static Site Setup

```bash
# 1. Create the static site directory
sudo mkdir -p /var/www/portfolio

# 2. Add your static files (index.html, CSS, JS, etc.)
sudo cp -r ./dist/* /var/www/portfolio/

# 3. Create nginx configuration
sudo ./nginx-manager.sh create-static portfolio.com /var/www/portfolio

# 4. Test and reload
sudo ./nginx-manager.sh test && sudo ./nginx-manager.sh reload
```

### Node.js API Setup

```bash
# 1. Create nginx configuration (assuming your Node.js app runs on port 3000)
sudo ./nginx-manager.sh create-nodejs api.example.com 3000

# 2. Make sure your Node.js app is running on the specified port
# node server.js  # or however you start your app

# 3. Test and reload
sudo ./nginx-manager.sh test && sudo ./nginx-manager.sh reload
```

## Directory Structure

```
/etc/nginx/sites-available/  # Configuration files
/etc/nginx/sites-enabled/    # Symbolic links to enabled sites
```

## Permissions

### Nginx User and File Access

Nginx typically runs as user `nginx` (or `www-data` on Ubuntu/Debian). If your website files are owned by a different user (like your development user), nginx won't be able to read them.

**The issue:** `user nginx;` in nginx.conf vs. file owner `jaspis`

**Solutions:**
1. **Group method (recommended):** Add nginx user to your file owner's group
2. **Ownership method:** Change file ownership to nginx user
3. **World-readable:** Make files readable by everyone (less secure)

Use the `fix-permissions` command to resolve this automatically.

### Example Permission Fix

```bash
# Your files are owned by 'jaspis'
ls -la /var/www/myapp
# drwxr-xr-x  jaspis jaspis ...

# Nginx runs as 'nginx' user
ps aux | grep nginx
# nginx: master process ...

# Fix permissions
sudo ./nginx-manager.sh fix-permissions /var/www/myapp
# This adds 'nginx' user to 'jaspis' group and sets proper permissions
```

## Requirements

- nginx installed and running
- PHP-FPM (for Laravel configurations)
- Root or sudo access
- Bash shell

## Troubleshooting

### Common Issues

1. **Permission Denied**: Make sure you're running with sudo
2. **PHP Socket Not Found**: Check that PHP-FPM is installed and running
3. **Port Already in Use**: Verify the port isn't being used by another service
4. **Domain Resolution**: Make sure DNS points to your server

### Checking Logs

```bash
# Nginx error log
sudo tail -f /var/log/nginx/error.log

# Nginx access log
sudo tail -f /var/log/nginx/access.log

# PHP-FPM log (if using Laravel)
sudo tail -f /var/log/php8.1-fpm.log
```

### Manual Configuration

If you need to modify configurations manually:
```bash
# Edit the configuration
sudo nano /etc/nginx/sites-available/example.com

# Test and reload
sudo nginx -t && sudo systemctl reload nginx
```

## Contributing

Feel free to submit issues and enhancement requests!

## License

This project is open source. Use at your own risk.
