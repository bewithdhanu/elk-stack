#!/bin/bash

# ELK Stack Setup Script for Ubuntu 22.04
# This script prepares the system and starts the ELK stack

set -e

echo "🔍 ELK Stack Setup for Ubuntu 22.04"
echo "======================================"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to create directory with proper permissions
create_log_dir() {
    local dir="$1"
    local owner="$2"
    local group="$3"
    
    if [ ! -d "$dir" ]; then
        echo "📁 Creating directory: $dir"
        sudo mkdir -p "$dir"
        if [ -n "$owner" ] && [ -n "$group" ]; then
            sudo chown "$owner:$group" "$dir"
        fi
        sudo chmod 755 "$dir"
    else
        echo "✅ Directory already exists: $dir"
    fi
}

# Check if running on Ubuntu 22.04
echo "🔎 Checking Ubuntu version..."
if ! grep -q "Ubuntu 22.04" /etc/os-release; then
    echo "⚠️  Warning: This script is designed for Ubuntu 22.04"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check for Docker
echo "🐳 Checking Docker installation..."
if ! command_exists docker; then
    echo "❌ Docker not found. Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    echo "✅ Docker installed. Please log out and back in to use Docker without sudo."
fi

# Check for Docker Compose
echo "📦 Checking Docker Compose installation..."
if ! command_exists docker-compose; then
    echo "❌ Docker Compose not found. Installing..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "✅ Docker Compose installed"
fi

# Set up system parameters for Elasticsearch
echo "⚙️  Configuring system parameters for Elasticsearch..."
if ! grep -q "vm.max_map_count=262144" /etc/sysctl.conf; then
    echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
fi

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp env.example .env
    echo "✅ .env file created. Please edit it to match your configuration."
else
    echo "✅ .env file already exists"
fi

# Create log directories
echo "📁 Setting up log directories..."

# Apache logs (usually exist by default)
create_log_dir "/var/log/apache2" "root" "adm"

# PHP logs
create_log_dir "/var/log/php" "www-data" "www-data"

# Check if Laravel directory exists
LARAVEL_LOG_PATH="/var/www/html/storage/logs"
if [ -d "/var/www/html/storage" ]; then
    create_log_dir "$LARAVEL_LOG_PATH" "www-data" "www-data"
    echo "✅ Laravel log directory configured"
else
    echo "⚠️  Laravel directory not found at /var/www/html/storage"
    echo "   Update LARAVEL_LOG_PATH in .env if your Laravel app is elsewhere"
fi

# PM2 logs directory (for current user)
PM2_LOG_DIR="$HOME/.pm2/logs"
if [ ! -d "$PM2_LOG_DIR" ]; then
    echo "📁 Creating PM2 logs directory: $PM2_LOG_DIR"
    mkdir -p "$PM2_LOG_DIR"
else
    echo "✅ PM2 logs directory exists: $PM2_LOG_DIR"
fi

# Create empty directories for custom logs to prevent mount errors
sudo mkdir -p /tmp/empty

# Set appropriate permissions for log files
echo "🔐 Setting log file permissions..."
sudo chmod -R 755 /var/log/apache2 2>/dev/null || true
# Ensure gzipped Apache logs are readable
sudo chmod 644 /var/log/apache2/*.gz 2>/dev/null || true
sudo chmod -R 755 /var/log/php 2>/dev/null || true
if [ -d "$LARAVEL_LOG_PATH" ]; then
    sudo chown -R www-data:www-data "$LARAVEL_LOG_PATH" 2>/dev/null || true
    sudo chmod -R 755 "$LARAVEL_LOG_PATH" 2>/dev/null || true
fi

# Check disk space
echo "💾 Checking disk space..."
AVAILABLE_SPACE=$(df / | awk 'NR==2 {print $4}')
if [ "$AVAILABLE_SPACE" -lt 10485760 ]; then  # 10GB in KB
    echo "⚠️  Warning: Less than 10GB free space available"
    echo "   ELK stack requires significant disk space for indices"
fi

# Check memory
echo "🧠 Checking available memory..."
TOTAL_MEM=$(free -m | awk 'NR==2{print $2}')
if [ "$TOTAL_MEM" -lt 4096 ]; then
    echo "⚠️  Warning: Less than 4GB RAM detected"
    echo "   Consider reducing heap sizes in .env file"
    echo "   Recommended: ES_HEAP_SIZE=1g, LOGSTASH_HEAP_SIZE=512m"
fi

# Validate .env configuration
echo "✅ Configuration validation..."
source .env 2>/dev/null || true

# Check if configured log paths exist
check_log_path() {
    local path="$1"
    local name="$2"
    if [ -n "$path" ] && [ "$path" != "/tmp/empty" ] && [ ! -d "$path" ]; then
        echo "⚠️  Warning: $name path doesn't exist: $path"
        echo "   Update the path in .env or create the directory"
    fi
}

check_log_path "$APACHE_LOG_PATH" "Apache logs"
check_log_path "$LARAVEL_LOG_PATH" "Laravel logs"
check_log_path "$PM2_LOG_PATH" "PM2 logs"
check_log_path "$PHP_LOG_PATH" "PHP logs"

echo ""
echo "🚀 Setup complete! Next steps:"
echo "1. Edit .env file to match your configuration:"
echo "   nano .env"
echo ""
echo "2. Start the ELK stack:"
echo "   docker-compose up -d"
echo ""
echo "3. Or start with Filebeat for better performance:"
echo "   docker-compose --profile filebeat up -d"
echo ""
echo "4. Access Kibana at: http://localhost:5601"
echo ""
echo "📚 See README.md for detailed configuration and usage instructions" 