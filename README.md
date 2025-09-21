# nginx-manager

A comprehensive nginx configuration management tool that makes it easy to create and manage nginx configurations for different types of websites and applications.

## Features

- 🚀 **Interactive CLI** - Easy-to-use command-line interface
- 📝 **Multiple Templates** - Pre-configured templates for different site types
- 🔒 **SSL Support** - Automatic SSL certificate generation with Let's Encrypt
- ⚡ **Performance Optimized** - Best practices for speed and security
- 🛡️ **Security Focused** - Built-in security headers and protections
- 🧪 **Configuration Testing** - Built-in nginx config validation

## Supported Site Types

- **Laravel PHP Applications** - Complete PHP-FPM setup with Laravel-specific optimizations
- **Static Websites** - HTML/CSS/JS sites with aggressive caching
- **Node.js Applications** - Reverse proxy configuration with WebSocket support
- **WordPress Sites** - WordPress-specific security and optimization rules
- **Single Page Applications (SPA)** - React/Vue/Angular with proper routing
- **Reverse Proxy** - Generic reverse proxy configuration

## Installation

1. Clone or download this repository:
```bash
git clone <repository-url>
cd nginx-config
```

2. Make the script executable:
```bash
chmod +x nginx-manager.sh
```

3. Ensure nginx is installed:
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install nginx

# CentOS/RHEL
sudo yum install nginx
# or
sudo dnf install nginx

# macOS
brew install nginx
```

## Usage

### Interactive Mode

Run the script without arguments for interactive mode:

```bash
sudo ./nginx-manager.sh
```

This will present you with a menu where you can:
1. Create new site configurations
2. List existing sites
3. Remove sites
4. Test nginx configuration
5. Reload nginx
6. Install/Update templates

### Command Line Mode

You can also use specific commands:

```bash
# Create a new site (interactive)
sudo ./nginx-manager.sh create

# List all sites
./nginx-manager.sh list

# Test nginx configuration
sudo ./nginx-manager.sh test

# Reload nginx
sudo ./nginx-manager.sh reload

# Install templates
sudo ./nginx-manager.sh install-templates
```

## Quick Start Examples

### 1. Laravel Application

```bash
sudo ./nginx-manager.sh create
# Select: 1) Laravel PHP Application
# Domain: myapp.com
# Root path: /var/www/myapp.com
# PHP version: 8.2
# SSL: yes
# Email: your@email.com
```

### 2. Static Website

```bash
sudo ./nginx-manager.sh create
# Select: 2) Static HTML/CSS/JS Website
# Domain: mysite.com
# Root path: /var/www/mysite.com
# SSL: yes
# Email: your@email.com
```

### 3. Node.js Application

```bash
sudo ./nginx-manager.sh create
# Select: 3) Node.js Application
# Domain: myapi.com
# Port: 3000
# SSL: yes
# Email: your@email.com
```

## Configuration Templates

### Laravel Template Features
- PHP-FPM integration
- Laravel-specific URL rewriting
- Security headers
- Static file caching
- Gzip compression
- Error handling

### Static Website Template Features
- Aggressive static file caching
- Security headers
- Gzip compression
- Custom error pages
- SEO-friendly configuration

### Node.js Template Features
- Reverse proxy setup
- WebSocket support
- Health check endpoint
- Load balancing ready
- Static file handling

### WordPress Template Features
- WordPress-specific security rules
- PHP-FPM integration
- XMLRPC protection
- Rate limiting for admin/login
- Upload directory protection
- SEO optimizations

### SPA Template Features
- Client-side routing support
- Aggressive static asset caching
- Service worker support
- Progressive Web App ready
- API proxy configuration (optional)

### Reverse Proxy Template Features
- Load balancing support
- Health checks
- Flexible backend configuration
- Rate limiting support
- Static file serving

## nginx.conf Best Practices

The included `nginx.conf` file includes:

### Performance Optimizations
- Worker process auto-scaling
- Optimized buffer sizes
- Keep-alive connections
- File caching
- Gzip compression
- Efficient event handling

### Security Features
- Hidden server tokens
- Security headers
- Rate limiting zones
- SSL/TLS best practices
- Malicious request blocking
- Bot protection

### Monitoring & Logging
- Detailed access logs
- Error logging
- Performance metrics
- Request timing

## SSL Certificate Management

The tool supports automatic SSL certificate generation using Let's Encrypt:

1. **Automatic Setup**: When creating a site with SSL enabled, certificates are automatically generated
2. **Manual Setup**: If certbot is not available, manual SSL instructions are provided
3. **Certificate Renewal**: Use `certbot renew` for automatic renewal

### Prerequisites for SSL
- Domain must point to your server
- Port 80 and 443 must be open
- Certbot must be installed:

```bash
# Ubuntu/Debian
sudo apt install certbot python3-certbot-nginx

# CentOS/RHEL
sudo yum install certbot python3-certbot-nginx
```

## Directory Structure

```
nginx-config/
├── nginx-manager.sh          # Main script
├── nginx.conf                # Best practices nginx.conf
├── templates/                # Site templates
│   ├── laravel.conf
│   ├── static.conf
│   ├── nodejs.conf
│   ├── wordpress.conf
│   ├── spa.conf
│   └── proxy.conf
└── README.md                 # This file
```

## Customization

### Modifying Templates

Templates are located in the `templates/` directory. Each template uses variable substitution:

- `{{DOMAIN}}` - Site domain name
- `{{ROOT_PATH}}` - Document root path
- `{{PHP_VERSION}}` - PHP version (for PHP sites)
- `{{PORT}}` - Application port (for proxy configurations)
- `{{SSL_*}}` - SSL-related configurations

### Adding New Templates

1. Create a new `.conf` file in the `templates/` directory
2. Use the variable substitution format
3. Add the new template option to the main script

## Diagnostic Tool

The package includes a comprehensive diagnostic tool to help troubleshoot "This site can't be reached" and other common nginx issues.

### Using the Diagnostic Tool

```bash
# Make the diagnostic script executable
chmod +x diagnose.sh

# Run the diagnostic tool
sudo ./diagnose.sh
```

The diagnostic tool will check:
- ✅ nginx installation and version
- ✅ nginx service status (running/stopped)
- ✅ nginx configuration validity
- ✅ Listening ports (80, 443)
- ✅ Firewall settings (UFW, iptables, firewalld)
- ✅ Available and enabled sites
- ✅ DNS resolution for your domain
- ✅ HTTP/HTTPS connectivity tests
- ✅ System resources (disk, memory, load)
- ✅ Recent nginx error logs

### Remote Server Troubleshooting

If your nginx is running on a remote server:

1. **Upload the tools to your server:**
   ```bash
   # Copy the entire nginx-config directory to your server
   scp -r nginx-config/ user@your-server:~/
   
   # Or copy individual files
   scp nginx-manager.sh diagnose.sh user@your-server:~/
   scp -r templates/ user@your-server:~/
   ```

2. **Connect to your server and run diagnostics:**
   ```bash
   # SSH to your server
   ssh user@your-server
   
   # Run the diagnostic tool
   sudo ./diagnose.sh
   ```

3. **Common remote server issues:**
   - Domain not pointing to server IP
   - Firewall blocking ports 80/443
   - nginx not running or misconfigured
   - DNS propagation delays
   - SSL certificate issues

## Troubleshooting

### Common Issues

1. **"This site can't be reached" Error**
   
   Run the diagnostic tool first:
   ```bash
   sudo ./diagnose.sh
   ```
   
   Common causes and solutions:
   - **nginx not running:** `sudo systemctl start nginx`
   - **Firewall blocking ports:** `sudo ufw allow 80 && sudo ufw allow 443`
   - **Domain not pointing to server:** Check DNS settings with your domain provider
   - **nginx misconfigured:** `sudo nginx -t` to check for errors

2. **Permission Denied**
   ```bash
   # Make sure to run with sudo for system operations
   sudo ./nginx-manager.sh
   ```

3. **nginx: configuration file test failed**
   ```bash
   # Check nginx configuration
   sudo nginx -t
   
   # Check error logs
   sudo tail -f /var/log/nginx/error.log
   ```

4. **SSL Certificate Issues**
   ```bash
   # Ensure domain points to server
   nslookup yourdomain.com
   
   # Check certbot logs
   sudo tail -f /var/log/letsencrypt/letsencrypt.log
   ```

5. **PHP-FPM Not Found**
   ```bash
   # Install PHP-FPM
   sudo apt install php8.2-fpm  # Ubuntu/Debian
   sudo yum install php82-php-fpm  # CentOS/RHEL
   
   # Start PHP-FPM service
   sudo systemctl start php8.2-fpm
   sudo systemctl enable php8.2-fpm
   ```

6. **Site Shows nginx Default Page**
   ```bash
   # Remove default site
   sudo rm /etc/nginx/sites-enabled/default
   
   # Reload nginx
   sudo systemctl reload nginx
   ```

### Testing Configurations

Always test configurations before deploying:

```bash
# Test nginx configuration
sudo nginx -t

# Test specific site configuration
sudo nginx -t -c /etc/nginx/sites-available/yourdomain.com

# Reload nginx if tests pass
sudo systemctl reload nginx
```

### DNS and Connectivity Testing

```bash
# Test if domain resolves
nslookup yourdomain.com

# Test if domain points to your server
dig yourdomain.com

# Test HTTP connectivity
curl -I http://yourdomain.com

# Test HTTPS connectivity  
curl -I https://yourdomain.com

# Check what's listening on ports
sudo netstat -tlnp | grep nginx
# or
sudo ss -tlnp | grep nginx
```

## Security Considerations

### Rate Limiting
The configurations include rate limiting for:
- Login endpoints (1 request/second)
- API endpoints (10 requests/second)
- WordPress admin (10 requests/second)
- WordPress login (1 request/second)
- XMLRPC (1 request/second)

### Security Headers
All configurations include:
- X-Frame-Options
- X-Content-Type-Options
- X-XSS-Protection
- Referrer-Policy
- Content-Security-Policy

### File Protection
- Hidden files (`.htaccess`, `.env`) are blocked
- PHP execution in upload directories is disabled
- Sensitive file extensions are blocked

## Performance Tips

1. **Enable Gzip**: All templates include gzip compression
2. **Static File Caching**: Aggressive caching for static assets
3. **Keep-Alive**: Optimized connection reuse
4. **Buffer Tuning**: Optimized buffer sizes for different workloads
5. **Worker Processes**: Auto-scaled based on CPU cores

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is open source and available under the MIT License.

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review nginx error logs
3. Test configurations step by step
4. Check the nginx documentation for specific directives

---

**Note**: Always backup your existing nginx configurations before making changes. Test all configurations in a development environment first.
