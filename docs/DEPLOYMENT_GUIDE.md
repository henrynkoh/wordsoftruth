# Words of Truth Deployment Guide

## Overview

This guide provides comprehensive instructions for deploying the Words of Truth application across different environments including development, staging, and production.

## Table of Contents

1. [System Requirements](#system-requirements)
2. [Environment Setup](#environment-setup)
3. [Configuration Management](#configuration-management)
4. [Database Setup](#database-setup)
5. [Application Deployment](#application-deployment)
6. [Background Jobs Configuration](#background-jobs-configuration)
7. [Security Configuration](#security-configuration)
8. [Monitoring Setup](#monitoring-setup)
9. [Performance Optimization](#performance-optimization)
10. [Backup and Recovery](#backup-and-recovery)

## System Requirements

### Minimum Requirements

**Application Server:**
- **CPU**: 2 cores (4 cores recommended)
- **RAM**: 4GB (8GB recommended)
- **Storage**: 20GB SSD (50GB recommended)
- **OS**: Ubuntu 20.04 LTS or later

**Database Server:**
- **CPU**: 2 cores (4 cores recommended)
- **RAM**: 4GB (8GB recommended)
- **Storage**: 50GB SSD with backup capability
- **OS**: Ubuntu 20.04 LTS or later

**Redis Server:**
- **CPU**: 1 core (2 cores recommended)
- **RAM**: 2GB (4GB recommended)
- **Storage**: 10GB SSD

### Production Requirements

**Application Server (Load Balanced):**
- **Instances**: 2-3 application servers
- **CPU**: 4-8 cores per instance
- **RAM**: 16-32GB per instance
- **Storage**: 100GB SSD per instance

**Database Server:**
- **CPU**: 8+ cores
- **RAM**: 32GB+
- **Storage**: 500GB+ SSD with automated backups
- **Replication**: Primary-replica setup recommended

**Load Balancer:**
- AWS Application Load Balancer or Nginx
- SSL termination capability
- Health check configuration

## Environment Setup

### Development Environment

#### Prerequisites Installation

```bash
# Install Ruby version manager (rbenv)
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc

# Install Ruby 3.2.2
rbenv install 3.2.2
rbenv global 3.2.2

# Install Node.js (for asset compilation)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PostgreSQL
sudo apt-get update
sudo apt-get install -y postgresql postgresql-contrib libpq-dev

# Install Redis
sudo apt-get install -y redis-server

# Install system dependencies
sudo apt-get install -y build-essential libssl-dev libyaml-dev libreadline-dev \
  openssl curl git-core zlib1g-dev bison libxml2-dev libxslt1-dev \
  libcurl4-openssl-dev libffi-dev imagemagick
```

#### Application Setup

```bash
# Clone the repository
git clone https://github.com/your-org/wordsoftruth.git
cd wordsoftruth

# Install Ruby dependencies
gem install bundler
bundle install

# Install JavaScript dependencies
npm install

# Set up environment variables
cp .env.example .env.development
# Edit .env.development with your configuration

# Set up the database
rails db:create
rails db:migrate
rails db:seed

# Precompile assets
rails assets:precompile

# Start the development server
rails server
```

### Staging Environment

#### Infrastructure Setup with Docker

```dockerfile
# Dockerfile
FROM ruby:3.2.2-alpine

# Install system dependencies
RUN apk add --no-cache \
  build-base \
  postgresql-dev \
  redis \
  nodejs \
  npm \
  imagemagick \
  curl

WORKDIR /app

# Copy Gemfile and install gems
COPY Gemfile Gemfile.lock ./
RUN bundle config --global frozen 1 && \
    bundle install --deployment --without development test

# Copy package.json and install node modules
COPY package*.json ./
RUN npm ci --only=production

# Copy application code
COPY . .

# Precompile assets
RUN rails assets:precompile

# Expose port
EXPOSE 3000

# Start command
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
```

```yaml
# docker-compose.staging.yml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - RAILS_ENV=staging
      - DATABASE_URL=postgresql://postgres:password@db:5432/wordsoftruth_staging
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - db
      - redis
    volumes:
      - ./storage:/app/storage
      - ./log:/app/log

  db:
    image: postgres:15
    environment:
      POSTGRES_DB: wordsoftruth_staging
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backups:/backups

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data

  sidekiq:
    build: .
    command: bundle exec sidekiq
    environment:
      - RAILS_ENV=staging
      - DATABASE_URL=postgresql://postgres:password@db:5432/wordsoftruth_staging
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - db
      - redis
    volumes:
      - ./storage:/app/storage
      - ./log:/app/log

volumes:
  postgres_data:
  redis_data:
```

#### Staging Deployment

```bash
# Build and deploy staging environment
docker-compose -f docker-compose.staging.yml build
docker-compose -f docker-compose.staging.yml up -d

# Run database migrations
docker-compose -f docker-compose.staging.yml exec app rails db:migrate

# Seed staging data
docker-compose -f docker-compose.staging.yml exec app rails db:seed
```

### Production Environment

#### AWS Infrastructure Setup

```yaml
# infrastructure/cloudformation/wordsoftruth-infrastructure.yml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Words of Truth Production Infrastructure'

Parameters:
  Environment:
    Type: String
    Default: production
  
  InstanceType:
    Type: String
    Default: t3.large
    
  DatabaseInstanceClass:
    Type: String
    Default: db.t3.large

Resources:
  # VPC Configuration
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.0.0.0/16
      EnableDnsHostnames: true
      EnableDnsSupport: true
      Tags:
        - Key: Name
          Value: !Sub ${Environment}-wordsoftruth-vpc

  # Public Subnets
  PublicSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Select [0, !GetAZs '']
      CidrBlock: 10.0.1.0/24
      MapPublicIpOnLaunch: true

  PublicSubnet2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Select [1, !GetAZs '']
      CidrBlock: 10.0.2.0/24
      MapPublicIpOnLaunch: true

  # Private Subnets
  PrivateSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Select [0, !GetAZs '']
      CidrBlock: 10.0.3.0/24

  PrivateSubnet2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Select [1, !GetAZs '']
      CidrBlock: 10.0.4.0/24

  # Application Load Balancer
  ApplicationLoadBalancer:
    Type: AWS::ElasticLoadBalancingV2::LoadBalancer
    Properties:
      Name: !Sub ${Environment}-wordsoftruth-alb
      Scheme: internet-facing
      Type: application
      Subnets:
        - !Ref PublicSubnet1
        - !Ref PublicSubnet2
      SecurityGroups:
        - !Ref ALBSecurityGroup

  # RDS Database
  Database:
    Type: AWS::RDS::DBInstance
    Properties:
      DBInstanceIdentifier: !Sub ${Environment}-wordsoftruth-db
      DBInstanceClass: !Ref DatabaseInstanceClass
      Engine: postgres
      EngineVersion: '15.4'
      AllocatedStorage: 100
      StorageType: gp2
      DBName: wordsoftruth_production
      MasterUsername: !Ref DatabaseUsername
      MasterUserPassword: !Ref DatabasePassword
      VPCSecurityGroups:
        - !Ref DatabaseSecurityGroup
      DBSubnetGroupName: !Ref DatabaseSubnetGroup
      BackupRetentionPeriod: 30
      MultiAZ: true
      StorageEncrypted: true

  # ElastiCache Redis
  RedisCluster:
    Type: AWS::ElastiCache::ReplicationGroup
    Properties:
      ReplicationGroupId: !Sub ${Environment}-wordsoftruth-redis
      Description: Redis cluster for Words of Truth
      CacheNodeType: cache.t3.medium
      Engine: redis
      NumCacheClusters: 2
      Port: 6379
      SecurityGroupIds:
        - !Ref RedisSecurityGroup
      SubnetGroupName: !Ref RedisSubnetGroup
```

#### Kamal Deployment Configuration

```yaml
# config/deploy.yml
service: wordsoftruth
image: wordsoftruth/app

servers:
  web:
    hosts:
      - 10.0.1.10
      - 10.0.1.11
    options:
      add-host: host.docker.internal:host-gateway
    labels:
      traefik.http.routers.wordsoftruth.rule: Host(`wordsoftruth.com`)
      traefik.http.routers.wordsoftruth.tls: true
      traefik.http.routers.wordsoftruth.tls.certresolver: letsencrypt

  worker:
    hosts:
      - 10.0.1.12
    cmd: bundle exec sidekiq
    options:
      add-host: host.docker.internal:host-gateway

registry:
  server: registry.digitalocean.com/wordsoftruth
  username: your-registry-username
  password:
    - KAMAL_REGISTRY_PASSWORD

env:
  clear:
    RAILS_ENV: production
    RAILS_LOG_TO_STDOUT: true
    RAILS_SERVE_STATIC_FILES: true
  secret:
    - SECRET_KEY_BASE
    - DATABASE_URL
    - REDIS_URL
    - ENCRYPTION_KEY
    - AWS_ACCESS_KEY_ID
    - AWS_SECRET_ACCESS_KEY

volumes:
  - "wordsoftruth_storage:/app/storage"

accessories:
  db:
    image: postgres:15
    host: 10.0.3.10
    port: 5432
    env:
      POSTGRES_DB: wordsoftruth_production
      POSTGRES_USER: wordsoftruth
      POSTGRES_PASSWORD:
        - DATABASE_PASSWORD
    volumes:
      - "wordsoftruth_postgres:/var/lib/postgresql/data"

  redis:
    image: redis:7
    host: 10.0.3.11
    port: 6379
    volumes:
      - "wordsoftruth_redis:/data"

traefik:
  options:
    publish:
      - "443:443"
    volume:
      - "/letsencrypt/acme.json:/letsencrypt/acme.json"
  args:
    entrypoints.web.address: ":80"
    entrypoints.websecure.address: ":443"
    certificatesresolvers.letsencrypt.acme.tlschallenge: true
    certificatesresolvers.letsencrypt.acme.email: admin@wordsoftruth.com
    certificatesresolvers.letsencrypt.acme.storage: /letsencrypt/acme.json
```

#### Production Deployment Commands

```bash
# Initial setup
kamal setup

# Deploy application
kamal deploy

# Check application status
kamal app status

# View logs
kamal app logs --follow

# Execute database migrations
kamal app exec "rails db:migrate"

# Rollback deployment
kamal rollback
```

## Configuration Management

### Environment Variables

```bash
# .env.production
RAILS_ENV=production
SECRET_KEY_BASE=your_secret_key_base_here
DATABASE_URL=postgresql://username:password@host:5432/wordsoftruth_production
REDIS_URL=redis://redis-host:6379/0

# Encryption keys
ENCRYPTION_PRIMARY_KEY=32_character_encryption_key
ENCRYPTION_DETERMINISTIC_KEY=32_character_deterministic_key
ENCRYPTION_KEY_DERIVATION_SALT=32_character_salt

# AWS Configuration
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_REGION=us-east-1
S3_BUCKET=wordsoftruth-production-storage

# External Services
YOUTUBE_API_KEY=your_youtube_api_key
YOUTUBE_CLIENT_ID=your_youtube_client_id
YOUTUBE_CLIENT_SECRET=your_youtube_client_secret

# Monitoring
NEW_RELIC_LICENSE_KEY=your_new_relic_key
SENTRY_DSN=your_sentry_dsn

# Email Configuration
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=notifications@wordsoftruth.com
SMTP_PASSWORD=your_smtp_password

# Performance
RAILS_MAX_THREADS=5
WEB_CONCURRENCY=2
SIDEKIQ_CONCURRENCY=25
```

### Rails Credentials

```bash
# Edit production credentials
EDITOR=nano rails credentials:edit --environment production

# Example credentials structure:
# secret_key_base: generated_secret_key
# database:
#   username: wordsoftruth
#   password: secure_database_password
# redis:
#   url: redis://redis-host:6379/0
# aws:
#   access_key_id: your_aws_access_key
#   secret_access_key: your_aws_secret_key
#   region: us-east-1
#   s3_bucket: wordsoftruth-production-storage
# youtube:
#   api_key: your_youtube_api_key
#   client_id: your_youtube_client_id
#   client_secret: your_youtube_client_secret
```

## Database Setup

### PostgreSQL Configuration

```sql
-- Create production database
CREATE DATABASE wordsoftruth_production;
CREATE USER wordsoftruth WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE wordsoftruth_production TO wordsoftruth;

-- Enable required extensions
\c wordsoftruth_production;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "unaccent";
```

### Database Migrations and Indexing

```bash
# Run migrations in production
rails db:migrate RAILS_ENV=production

# Create performance indexes
rails db:migrate:up VERSION=20240615120000 RAILS_ENV=production  # Performance indexes migration

# Verify migrations
rails db:migrate:status RAILS_ENV=production
```

### Database Performance Tuning

```postgresql
-- postgresql.conf optimizations for production
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 4MB
min_wal_size = 1GB
max_wal_size = 4GB
```

## Application Deployment

### Pre-deployment Checklist

```bash
#!/bin/bash
# scripts/pre_deployment_check.sh

echo "Starting pre-deployment checks..."

# Check environment variables
required_vars=(
  "SECRET_KEY_BASE"
  "DATABASE_URL"
  "REDIS_URL"
  "ENCRYPTION_PRIMARY_KEY"
)

for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    echo "ERROR: $var is not set"
    exit 1
  fi
done

# Check database connectivity
rails runner "ActiveRecord::Base.connection.execute('SELECT 1')" RAILS_ENV=production
if [ $? -ne 0 ]; then
  echo "ERROR: Database connection failed"
  exit 1
fi

# Check Redis connectivity
rails runner "Redis.new.ping" RAILS_ENV=production
if [ $? -ne 0 ]; then
  echo "ERROR: Redis connection failed"
  exit 1
fi

# Run tests
rails test RAILS_ENV=test
if [ $? -ne 0 ]; then
  echo "ERROR: Tests failed"
  exit 1
fi

# Check asset compilation
rails assets:precompile RAILS_ENV=production
if [ $? -ne 0 ]; then
  echo "ERROR: Asset compilation failed"
  exit 1
fi

echo "All pre-deployment checks passed!"
```

### Deployment Script

```bash
#!/bin/bash
# scripts/deploy.sh

set -e

echo "Starting deployment..."

# Pull latest code
git pull origin main

# Install dependencies
bundle install --deployment --without development test
npm ci --only=production

# Run database migrations
rails db:migrate RAILS_ENV=production

# Precompile assets
rails assets:precompile RAILS_ENV=production

# Restart application servers
sudo systemctl restart wordsoftruth-app
sudo systemctl restart wordsoftruth-sidekiq

# Warm up application
curl -f http://localhost:3000/health || exit 1

echo "Deployment completed successfully!"
```

### Zero-Downtime Deployment

```bash
#!/bin/bash
# scripts/zero_downtime_deploy.sh

# Use Kamal for zero-downtime deployments
kamal deploy

# Or manual blue-green deployment
./scripts/blue_green_deploy.sh
```

## Background Jobs Configuration

### Sidekiq Configuration

```ruby
# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.redis = {
    url: ENV['REDIS_URL'],
    network_timeout: 5,
    pool_timeout: 5,
    size: 25
  }
  
  config.average_scheduled_poll_interval = 15
  config.periodic_gc_count = 10_000
  config.memory_killer_max_memory = 1_000_000_000  # 1GB
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: ENV['REDIS_URL'],
    network_timeout: 5,
    pool_timeout: 5,
    size: 5
  }
end
```

### Systemd Service Configuration

```ini
# /etc/systemd/system/sidekiq.service
[Unit]
Description=Sidekiq
After=network.target

[Service]
Type=simple
User=deploy
WorkingDirectory=/var/www/wordsoftruth
ExecStart=/home/deploy/.rbenv/shims/bundle exec sidekiq -e production
Restart=always
RestartSec=1

# Graceful shutdown
KillMode=process
TimeoutStopSec=300

# Resource limits
LimitNOFILE=65536
LimitNPROC=65536

[Install]
WantedBy=multi-user.target
```

## Security Configuration

### SSL/TLS Setup

```nginx
# /etc/nginx/sites-available/wordsoftruth
server {
    listen 80;
    server_name wordsoftruth.com www.wordsoftruth.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name wordsoftruth.com www.wordsoftruth.com;

    ssl_certificate /etc/letsencrypt/live/wordsoftruth.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/wordsoftruth.com/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options DENY always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Firewall Configuration

```bash
# UFW firewall setup
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# Application-specific rules
sudo ufw allow from 10.0.0.0/16 to any port 5432  # Database access
sudo ufw allow from 10.0.0.0/16 to any port 6379  # Redis access
```

## Monitoring Setup

### Application Performance Monitoring

```ruby
# config/initializers/monitoring.rb

# New Relic
if Rails.env.production?
  require 'newrelic_rpm'
end

# Sentry for error tracking
Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.environment = Rails.env
  config.release = ENV['HEROKU_SLUG_COMMIT'] || ENV['GIT_COMMIT'] || 'unknown'
end
```

### Health Check Endpoints

```ruby
# config/routes.rb
Rails.application.routes.draw do
  get '/health', to: 'health#check'
  get '/health/detailed', to: 'health#detailed'
end

# app/controllers/health_controller.rb
class HealthController < ApplicationController
  def check
    render json: { status: 'ok', timestamp: Time.current }
  end
  
  def detailed
    checks = {
      database: check_database,
      redis: check_redis,
      storage: check_storage,
      sidekiq: check_sidekiq
    }
    
    overall_status = checks.values.all? { |check| check[:status] == 'ok' } ? 'ok' : 'error'
    
    render json: {
      status: overall_status,
      checks: checks,
      timestamp: Time.current
    }
  end
  
  private
  
  def check_database
    ActiveRecord::Base.connection.execute('SELECT 1')
    { status: 'ok', response_time: measure_time { ActiveRecord::Base.connection.execute('SELECT 1') } }
  rescue => e
    { status: 'error', error: e.message }
  end
  
  def check_redis
    Redis.new.ping
    { status: 'ok', response_time: measure_time { Redis.new.ping } }
  rescue => e
    { status: 'error', error: e.message }
  end
end
```

### Log Management

```ruby
# config/environments/production.rb
Rails.application.configure do
  # Structured logging
  config.log_formatter = proc do |severity, timestamp, progname, msg|
    {
      timestamp: timestamp.iso8601,
      level: severity,
      message: msg,
      service: 'wordsoftruth',
      environment: Rails.env
    }.to_json + "\n"
  end
  
  # Log rotation
  config.logger = ActiveSupport::Logger.new(
    Rails.root.join('log', 'production.log'),
    'daily', # Rotate daily
    50.megabytes # Keep max 50MB per file
  )
end
```

## Performance Optimization

### Database Connection Pooling

```ruby
# config/database.yml
production:
  adapter: postgresql
  pool: <%= ENV["DB_POOL"] || 25 %>
  timeout: 5000
  checkout_timeout: 5
  reaping_frequency: 10
  dead_connection_timeout: 30
```

### Asset Optimization

```ruby
# config/environments/production.rb
Rails.application.configure do
  # Asset compilation and caching
  config.assets.compile = false
  config.assets.digest = true
  config.assets.css_compressor = :sass
  config.assets.js_compressor = :terser
  
  # CDN configuration
  config.asset_host = ENV['CDN_HOST'] if ENV['CDN_HOST'].present?
  
  # Gzip compression
  config.middleware.use Rack::Deflater
end
```

### Caching Configuration

```ruby
# config/environments/production.rb
Rails.application.configure do
  config.cache_store = :redis_cache_store, {
    url: ENV['REDIS_URL'],
    pool_size: 5,
    pool_timeout: 5,
    namespace: 'wordsoftruth',
    expires_in: 1.hour
  }
  
  config.action_controller.perform_caching = true
  config.action_controller.enable_fragment_cache_logging = true
end
```

## Backup and Recovery

### Database Backup Strategy

```bash
#!/bin/bash
# scripts/backup_database.sh

BACKUP_DIR="/backups/database"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="wordsoftruth_${TIMESTAMP}.sql"

# Create backup directory
mkdir -p $BACKUP_DIR

# Create database backup
pg_dump $DATABASE_URL > "$BACKUP_DIR/$BACKUP_FILE"

# Compress backup
gzip "$BACKUP_DIR/$BACKUP_FILE"

# Upload to S3
aws s3 cp "$BACKUP_DIR/${BACKUP_FILE}.gz" s3://wordsoftruth-backups/database/

# Cleanup old backups (keep last 30 days)
find $BACKUP_DIR -name "*.gz" -type f -mtime +30 -delete

echo "Database backup completed: ${BACKUP_FILE}.gz"
```

### Automated Backup Scheduling

```bash
# Add to crontab (crontab -e)
# Daily database backup at 2 AM
0 2 * * * /var/www/wordsoftruth/scripts/backup_database.sh

# Weekly full system backup at 3 AM on Sundays
0 3 * * 0 /var/www/wordsoftruth/scripts/backup_system.sh
```

### Disaster Recovery Plan

```bash
#!/bin/bash
# scripts/restore_from_backup.sh

BACKUP_FILE=$1

if [ -z "$BACKUP_FILE" ]; then
  echo "Usage: $0 <backup_file>"
  exit 1
fi

echo "Starting disaster recovery..."

# Download backup from S3
aws s3 cp "s3://wordsoftruth-backups/database/$BACKUP_FILE" /tmp/

# Decompress backup
gunzip "/tmp/$BACKUP_FILE"

# Stop application
sudo systemctl stop wordsoftruth-app
sudo systemctl stop sidekiq

# Restore database
psql $DATABASE_URL < "/tmp/${BACKUP_FILE%.gz}"

# Start application
sudo systemctl start wordsoftruth-app
sudo systemctl start sidekiq

echo "Disaster recovery completed"
```

## Deployment Verification

### Post-Deployment Checklist

```bash
#!/bin/bash
# scripts/post_deployment_check.sh

echo "Running post-deployment verification..."

# Check application health
curl -f http://localhost:3000/health || exit 1

# Check database migrations
rails db:migrate:status RAILS_ENV=production | grep -q "down" && exit 1

# Check background jobs
curl -f http://localhost:3000/sidekiq || exit 1

# Check critical functionality
rails runner "Sermon.count" RAILS_ENV=production || exit 1
rails runner "Video.count" RAILS_ENV=production || exit 1

# Check performance
response_time=$(curl -o /dev/null -s -w '%{time_total}' http://localhost:3000/)
if (( $(echo "$response_time > 2.0" | bc -l) )); then
  echo "WARNING: Response time is ${response_time}s (> 2.0s)"
fi

echo "All post-deployment checks passed!"
```

This comprehensive deployment guide provides everything needed to successfully deploy the Words of Truth application across different environments with proper security, monitoring, and backup strategies.