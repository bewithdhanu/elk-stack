# ELK Stack for Ubuntu 22.04 - Apache, PHP, Laravel, PM2 Logs

This repository contains a fully configurable ELK (Elasticsearch, Logstash, Kibana) stack designed for Ubuntu 22.04 servers running Apache, PHP, Laravel applications, and PM2-managed Node.js processes.

## Features

- **Configurable via environment variables**
- **Support for multiple log types:**
  - Apache access and error logs (including PHP errors)
  - Laravel application logs
  - PM2 process logs
  - PHP-FPM service logs
  - System logs (syslog, auth.log)
  - Custom application logs
- **Optional Filebeat for enhanced log shipping**
- **GeoIP analysis for Apache access logs**
- **Proper log parsing and structuring**
- **Memory-optimized for various server sizes**

## Quick Start

### 1. Prerequisites

- Ubuntu 22.04 server
- Docker and Docker Compose installed
- At least 4GB RAM (8GB recommended)

### 2. Installation

1. Clone this repository:
```bash
git clone https://github.com/bewithdhanu/elk-stack.git
cd elk-stack
```

2. Copy the environment template:
```bash
cp env.example .env
```

3. Edit the `.env` file to match your server configuration:
```bash
nano .env
```

### 3. Configuration

#### Essential Environment Variables

Edit your `.env` file and adjust these key settings:

```bash
# Elastic Stack Version
ELASTIC_VERSION=8.11.0

# Memory allocation (adjust based on your server)
ES_HEAP_SIZE=2g          # For 8GB server, use 3-4g
LOGSTASH_HEAP_SIZE=1g    # For 8GB server, use 2g

# Log paths (verify these match your setup)
APACHE_LOG_PATH=/var/log/apache2
LARAVEL_LOG_PATH=/var/www/html/storage/logs
PM2_LOG_PATH=/home/ubuntu/.pm2/logs
# Note: PHP-FPM logs are at fixed system locations

# Custom log directories (optional)
CUSTOM_LOG_PATH_1=/var/log/myapp1
CUSTOM_LOG_PATH_2=/var/log/myapp2
```

#### Memory Recommendations

| Server RAM | ES_HEAP_SIZE | LOGSTASH_HEAP_SIZE |
|------------|--------------|-------------------|
| 4GB        | 1g           | 512m              |
| 8GB        | 3g           | 2g                |
| 16GB       | 6g           | 4g                |

### 4. Directory Setup

Ensure your log directories exist and have proper permissions:

```bash
# Create PHP log directory if it doesn't exist
sudo mkdir -p /var/log/php
sudo chmod 755 /var/log/php

# Ensure proper permissions for existing directories
sudo chmod -R 755 /var/log/apache2
sudo chmod -R 755 /home/ubuntu/.pm2/logs

# For Laravel logs
sudo chown -R www-data:www-data /var/www/html/storage/logs
sudo chmod -R 755 /var/www/html/storage/logs
```

### 5. Launch the Stack

```bash
# Start with Logstash only
docker-compose up -d

# Or start with Filebeat for enhanced log shipping
docker-compose --profile filebeat up -d
```

### 6. Access Services

- **Kibana**: http://your-server:5601
- **Elasticsearch**: http://your-server:9200
- **Logstash**: http://your-server:5044 (beats input)

## Log Types and Parsing

### Apache Logs

The configuration handles both current and rotated Apache logs:
- **Current logs**: `access.log`, `error.log`
- **Rotated logs**: `access.log.1`, `error.log.1`, etc.
- **Compressed logs**: `access.log.1.gz`, `error.log.2.gz`, etc.

**Features:**
- **Access logs**: Parsed using COMBINEDAPACHELOG pattern
- **Error logs**: Structured with timestamp, log level, client IP, and error message
- **GeoIP**: Geographic information added for client IPs
- **Compression support**: Automatic handling of gzipped rotated logs
- **Log rotation**: Seamless processing of logrotate-managed files

### Laravel Logs

The configuration supports Laravel's daily log rotation with different log types:
- **General Laravel logs**: `laravel-YYYY-MM-DD.log`
- **Error logs**: `error-YYYY-MM-DD.log`  
- **Info logs**: `info-YYYY-MM-DD.log`
- **Mobile logs**: `mobile-YYYY-MM-DD.log` (for mobile-specific logging)

**Format**: `[timestamp] environment.LEVEL: message`  
**Structured fields**: timestamp, environment, level, log_message, log_category

### PM2 Logs

- **Multiple formats supported**: with and without timestamps
- **Fallback parsing**: Captures all log content even if timestamp parsing fails

### PHP-FPM Service Logs

PHP application errors typically appear in Apache error logs. PHP-FPM service logs track the PHP process manager:
- **Current logs**: `php8.1-fpm.log`
- **Rotated logs**: `php8.1-fpm.log.1`, `php8.1-fpm.log.2`, etc.
- **Compressed logs**: `php8.1-fpm.log.1.gz`, `php8.1-fpm.log.2.gz`, etc.

**Format**: `[timestamp] LEVEL: message`  
**Structured fields**: timestamp, level, fpm_message

### System Logs

- **Syslog**: Standard syslog format parsing
- **Auth logs**: Authentication and authorization events

## Kibana Setup

### 1. Create Index Patterns

After starting the stack, create index patterns in Kibana:

1. Go to **Management** → **Stack Management** → **Index Patterns**
2. Create patterns for each log type:
   - `apache_access-*`
   - `apache_error-*`
   - `laravel-*` (general Laravel logs)
   - `laravel_error-*` (Laravel error logs)
   - `laravel_info-*` (Laravel info logs)
   - `laravel_mobile-*` (Laravel mobile logs)
   - `pm2-*`
   - `php_fpm-*` (PHP-FPM service logs)
   - `syslog-*`
   - `auth-*`

### 2. Import Dashboards (Optional)

You can create custom dashboards for:
- Apache access patterns and response codes
- Laravel application monitoring:
  - General application logs
  - Error tracking and analysis
  - Info level events
  - Mobile-specific activity
- PM2 application performance
- System security events

### 3. Useful Kibana Queries

**Filter Laravel logs by category:**
```
log_category: "error"      # Show only Laravel error logs
log_category: "mobile"     # Show only mobile-specific logs
log_category: "info"       # Show only info logs
```

**View all Laravel logs:**
```
tags: "laravel"
```

**Combine filters for specific analysis:**
```
tags: "laravel" AND level: "ERROR" AND log_category: "mobile"
```

## Maintenance

### Log Rotation

The stack automatically creates daily indices. Configure Elasticsearch index lifecycle management:

```bash
# Set up index lifecycle policy for 30-day retention
curl -X PUT "localhost:9200/_ilm/policy/logs-policy" -H 'Content-Type: application/json' -d'
{
  "policy": {
    "phases": {
      "delete": {
        "min_age": "30d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}'
```

### Monitoring

Check service status:
```bash
docker-compose ps
docker-compose logs elasticsearch
docker-compose logs logstash
docker-compose logs kibana
```

### Scaling

For high-volume environments:
1. Increase memory allocation in `.env`
2. Add additional Logstash workers
3. Consider Elasticsearch clustering
4. Use Filebeat for better performance

## Troubleshooting

### Common Issues

1. **Permission Denied Errors**:
   ```bash
   sudo chmod -R 755 /var/log/apache2
   sudo chown -R root:adm /var/log/apache2
   ```

2. **Memory Issues**:
   - Reduce heap sizes in `.env`
   - Check available system memory: `free -h`

3. **Log Files Not Found**:
   - Verify paths in `.env` match your actual log locations
   - Check if services are writing logs: `ls -la /var/log/apache2/`
   - For gzipped logs, ensure Logstash has read permissions: `sudo chmod 644 /var/log/apache2/*.gz`

4. **Elasticsearch Won't Start**:
   - Check memory limits: `docker-compose logs elasticsearch`
   - Increase `vm.max_map_count`: `sudo sysctl -w vm.max_map_count=262144`

### Debug Mode

Enable debug output in Logstash:
```bash
# Uncomment the stdout output in logstash/pipeline/logstash.conf
# stdout { codec => rubydebug }
```

## Security Considerations

- **Network**: Use a reverse proxy with SSL termination
- **Access**: Implement authentication for Kibana
- **Firewall**: Restrict access to ELK ports
- **Logs**: Ensure sensitive data is not logged

## Performance Tuning

### For Production Use

1. **Elasticsearch**:
   - Increase heap size to 50% of available RAM
   - Use SSD storage for data directory
   - Optimize index settings

2. **Logstash**:
   - Increase pipeline workers
   - Tune batch size and delay
   - Use persistent queues for reliability

3. **System**:
   - Set `vm.max_map_count=262144`
   - Optimize disk I/O settings
   - Monitor system resources

## Support

For issues and questions:
1. Check the logs: `docker-compose logs [service]`
2. Verify configuration files
3. Review Elasticsearch and Kibana documentation
4. Check Ubuntu 22.04 specific log locations

## Contributing

1. Fork the repository
2. Create feature branch
3. Test changes thoroughly
4. Submit pull request with detailed description 