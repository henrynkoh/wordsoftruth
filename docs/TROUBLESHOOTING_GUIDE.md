# Words of Truth Troubleshooting Guide

## Overview

This guide provides comprehensive troubleshooting procedures for common issues in the Words of Truth application, including performance problems, deployment issues, and system failures.

## Table of Contents

1. [Quick Diagnostics](#quick-diagnostics)
2. [Application Issues](#application-issues)
3. [Database Problems](#database-problems)
4. [Background Job Issues](#background-job-issues)
5. [Performance Problems](#performance-problems)
6. [Deployment Issues](#deployment-issues)
7. [Security Incidents](#security-incidents)
8. [Monitoring and Logging](#monitoring-and-logging)
9. [Emergency Procedures](#emergency-procedures)
10. [Frequently Asked Questions](#frequently-asked-questions)

## Quick Diagnostics

### System Health Check

```bash
#!/bin/bash
# Quick system health diagnostic

echo "=== Words of Truth System Health Check ==="
echo "Timestamp: $(date)"
echo

# Check application status
echo "1. Application Status:"
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health | grep -q "200"; then
    echo "   ✅ Application is responding"
else
    echo "   ❌ Application is not responding"
fi

# Check database connectivity
echo "2. Database Status:"
if rails runner "ActiveRecord::Base.connection.execute('SELECT 1')" 2>/dev/null; then
    echo "   ✅ Database is accessible"
else
    echo "   ❌ Database connection failed"
fi

# Check Redis connectivity
echo "3. Redis Status:"
if redis-cli ping 2>/dev/null | grep -q "PONG"; then
    echo "   ✅ Redis is responding"
else
    echo "   ❌ Redis connection failed"
fi

# Check background jobs
echo "4. Background Jobs:"
active_jobs=$(redis-cli llen "queue:default" 2>/dev/null || echo "0")
echo "   📊 Active jobs in queue: $active_jobs"

# Check disk space
echo "5. Disk Usage:"
disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$disk_usage" -lt 80 ]; then
    echo "   ✅ Disk usage: ${disk_usage}%"
else
    echo "   ⚠️  Disk usage: ${disk_usage}% (High)"
fi

# Check memory usage
echo "6. Memory Usage:"
memory_usage=$(free | awk 'NR==2{printf "%.1f", $3*100/$2}')
echo "   📊 Memory usage: ${memory_usage}%"

# Check load average
echo "7. System Load:"
load_avg=$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f1 | xargs)
echo "   📊 Load average: $load_avg"

echo
echo "=== End Health Check ==="
```

### Log Analysis Tool

```bash
#!/bin/bash
# Quick log analysis for common issues

echo "=== Recent Error Analysis ==="

# Check for application errors in the last hour
echo "Application Errors (last hour):"
grep -i "error\|exception\|fatal" /var/www/wordsoftruth/log/production.log | \
  awk -v since="$(date -d '1 hour ago' '+%Y-%m-%d %H:%M')" '$0 > since' | \
  tail -10

echo
echo "Database Errors (last hour):"
grep -i "PG::\|ActiveRecord::" /var/www/wordsoftruth/log/production.log | \
  awk -v since="$(date -d '1 hour ago' '+%Y-%m-%d %H:%M')" '$0 > since' | \
  tail -5

echo
echo "High Response Times (>5s):"
grep "Completed.*in [5-9][0-9][0-9][0-9]ms\|Completed.*in [0-9][0-9][0-9][0-9][0-9]ms" \
  /var/www/wordsoftruth/log/production.log | tail -5
```

## Application Issues

### Application Won't Start

**Symptoms:**
- Server returns 500 errors
- Application logs show startup failures
- Process exits immediately

**Diagnostic Steps:**

1. **Check environment variables:**
```bash
# Verify required environment variables
echo $RAILS_ENV
echo $SECRET_KEY_BASE
echo $DATABASE_URL
echo $REDIS_URL

# Check for missing variables
rails runner "puts ENV['SECRET_KEY_BASE'].present?" RAILS_ENV=production
```

2. **Check dependencies:**
```bash
# Verify gem dependencies
bundle check

# Check for missing system libraries
ldd $(which ruby)
```

3. **Check file permissions:**
```bash
# Ensure application user can read files
ls -la /var/www/wordsoftruth/
chown -R deploy:deploy /var/www/wordsoftruth/
chmod 755 /var/www/wordsoftruth/
```

**Common Solutions:**

```bash
# Fix 1: Regenerate secret key base
export SECRET_KEY_BASE=$(rails secret)

# Fix 2: Reinstall dependencies
bundle install --deployment

# Fix 3: Precompile assets
RAILS_ENV=production rails assets:precompile

# Fix 4: Fix database connection
rails db:migrate RAILS_ENV=production
```

### 500 Internal Server Errors

**Diagnostic Commands:**

```bash
# Check recent errors
tail -f /var/www/wordsoftruth/log/production.log | grep -i error

# Check for specific error patterns
grep -A 10 -B 5 "ActionController::RoutingError" log/production.log | tail -20
grep -A 10 -B 5 "NoMethodError" log/production.log | tail -20
```

**Common Causes and Fixes:**

1. **Missing routes:**
```ruby
# Check routes
rails routes | grep problematic_path

# Fix: Update config/routes.rb
Rails.application.routes.draw do
  # Add missing routes
end
```

2. **Database connection issues:**
```bash
# Test database connection
rails dbconsole RAILS_ENV=production
# Try: SELECT 1;

# Fix connection pool issues
# In config/database.yml, increase pool size:
pool: <%= ENV["DB_POOL"] || 25 %>
```

3. **Memory issues:**
```bash
# Check memory usage
free -m
ps aux | grep "ruby\|rails" | sort -nrk 4

# Restart application if memory usage is high
sudo systemctl restart wordsoftruth-app
```

### Slow Response Times

**Performance Diagnostic:**

```bash
#!/bin/bash
# Performance analysis script

echo "=== Performance Analysis ==="

# Check slow queries
rails runner "
puts 'Slow Queries (>1000ms):'
ActiveRecord::Base.connection.execute(\"
  SELECT query, mean_time, calls, total_time
  FROM pg_stat_statements 
  WHERE mean_time > 1000 
  ORDER BY mean_time DESC 
  LIMIT 10
\").each { |row| puts row.values.join(' | ') }
" RAILS_ENV=production

# Check memory usage by process
echo "Memory Usage by Process:"
ps aux | grep -E "(ruby|rails|sidekiq)" | awk '{print $11 " " $4 "% " $6/1024 "MB"}' | sort -nrk2

# Check database connections
echo "Database Connections:"
rails runner "puts ActiveRecord::Base.connection_pool.stat" RAILS_ENV=production

# Check cache hit rate
echo "Cache Statistics:"
redis-cli info stats | grep -E "(hits|misses)"
```

**Performance Fixes:**

```ruby
# Fix 1: Add database indexes
# Generate migration:
rails generate migration AddIndexesToSermons
# Add in migration:
class AddIndexesToSermons < ActiveRecord::Migration[7.0]
  def change
    add_index :sermons, [:church, :created_at]
    add_index :sermons, :pastor
    add_index :business_activity_logs, [:performed_at, :activity_type]
  end
end

# Fix 2: Optimize N+1 queries
# Before:
Sermon.all.each { |sermon| puts sermon.videos.count }
# After:
Sermon.includes(:videos).each { |sermon| puts sermon.videos.count }

# Fix 3: Add caching
# In controllers:
def index
  @sermons = Rails.cache.fetch("sermons_recent_#{params[:page]}", expires_in: 5.minutes) do
    Sermon.recent.page(params[:page])
  end
end
```

## Database Problems

### Database Connection Failures

**Symptoms:**
- "could not connect to server" errors
- "FATAL: database does not exist" errors
- Connection timeouts

**Diagnostic Steps:**

```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Check database existence
psql -h localhost -U postgres -l

# Test connection with application credentials
psql "$DATABASE_URL"

# Check connection limits
psql -c "SELECT * FROM pg_stat_activity;" "$DATABASE_URL"
psql -c "SHOW max_connections;" "$DATABASE_URL"
```

**Solutions:**

```bash
# Fix 1: Restart PostgreSQL
sudo systemctl restart postgresql

# Fix 2: Create missing database
createdb wordsoftruth_production

# Fix 3: Increase connection limits
# Edit /etc/postgresql/15/main/postgresql.conf
max_connections = 200
shared_buffers = 256MB

# Restart PostgreSQL
sudo systemctl restart postgresql

# Fix 4: Kill hanging connections
psql -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='wordsoftruth_production' AND state='idle';" "$DATABASE_URL"
```

### Database Migration Issues

**Common Migration Problems:**

```bash
# Check migration status
rails db:migrate:status RAILS_ENV=production

# Identify pending migrations
rails db:migrate:status RAILS_ENV=production | grep "down"

# Check for migration conflicts
rails db:migrate:status RAILS_ENV=production | grep "NO FILE"
```

**Migration Fixes:**

```bash
# Fix 1: Run pending migrations
rails db:migrate RAILS_ENV=production

# Fix 2: Rollback and retry
rails db:rollback RAILS_ENV=production
rails db:migrate RAILS_ENV=production

# Fix 3: Force specific migration version
rails db:migrate:up VERSION=20240615120000 RAILS_ENV=production

# Fix 4: Reset migration if safe
# ⚠️  Only in development/staging
rails db:drop db:create db:migrate RAILS_ENV=staging
```

### Database Performance Issues

**Performance Diagnostics:**

```sql
-- Check slow queries
SELECT query, mean_time, calls, total_time
FROM pg_stat_statements 
WHERE mean_time > 1000 
ORDER BY mean_time DESC 
LIMIT 10;

-- Check database size
SELECT pg_size_pretty(pg_database_size('wordsoftruth_production'));

-- Check table sizes
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Check index usage
SELECT 
  schemaname,
  tablename,
  attname,
  n_distinct,
  correlation
FROM pg_stats
WHERE schemaname = 'public'
ORDER BY n_distinct DESC;
```

**Performance Solutions:**

```sql
-- Add missing indexes
CREATE INDEX CONCURRENTLY idx_sermons_church_date ON sermons(church, created_at);
CREATE INDEX CONCURRENTLY idx_business_logs_performed_at ON business_activity_logs(performed_at);

-- Update table statistics
ANALYZE sermons;
ANALYZE business_activity_logs;

-- Vacuum tables
VACUUM ANALYZE sermons;
VACUUM ANALYZE business_activity_logs;
```

## Background Job Issues

### Sidekiq Not Processing Jobs

**Diagnostic Commands:**

```bash
# Check Sidekiq status
sudo systemctl status sidekiq

# Check Sidekiq web interface
curl http://localhost:4567/

# Check job queues
redis-cli llen "queue:default"
redis-cli llen "queue:critical"

# Check failed jobs
redis-cli llen "failed"

# Monitor Sidekiq in real-time
tail -f /var/www/wordsoftruth/log/sidekiq.log
```

**Common Issues and Fixes:**

1. **Sidekiq not running:**
```bash
# Start Sidekiq
sudo systemctl start sidekiq

# Check logs for startup issues
journalctl -u sidekiq -f

# Restart if needed
sudo systemctl restart sidekiq
```

2. **Jobs stuck in queue:**
```bash
# Clear stuck jobs (be careful!)
redis-cli del "queue:default"

# Restart workers
sudo systemctl restart sidekiq

# Check worker threads
rails runner "puts Sidekiq::ProcessSet.new.map(&:busy)" RAILS_ENV=production
```

3. **Memory issues:**
```bash
# Check Sidekiq memory usage
ps aux | grep sidekiq

# Restart if memory usage is high (>1GB)
sudo systemctl restart sidekiq

# Add memory limits to systemd service
# In /etc/systemd/system/sidekiq.service:
[Service]
MemoryMax=1G
MemoryHigh=800M
```

### Failed Jobs

**Analyzing Failed Jobs:**

```ruby
# Rails console commands to inspect failed jobs
rails console RAILS_ENV=production

# Check failed jobs
Sidekiq::RetrySet.new.size
Sidekiq::DeadSet.new.size

# Inspect specific failed job
retry_set = Sidekiq::RetrySet.new
job = retry_set.first
puts job['error_message']
puts job['error_backtrace']

# Retry all failed jobs
Sidekiq::RetrySet.new.retry_all

# Clear dead jobs
Sidekiq::DeadSet.new.clear
```

**Common Failed Job Fixes:**

```ruby
# Fix 1: Update job with error handling
class VideoProcessingJob < ApplicationJob
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  def perform(video_id)
    video = Video.find(video_id)
    # Add proper error handling
    begin
      process_video(video)
    rescue => e
      Rails.logger.error "Video processing failed: #{e.message}"
      video.mark_failed!(e.message)
      raise e
    end
  end
end

# Fix 2: Add timeout protection
class LongRunningJob < ApplicationJob
  def perform
    Timeout::timeout(300) do  # 5 minute timeout
      # Job logic here
    end
  end
end
```

## Performance Problems

### High CPU Usage

**Diagnostic Steps:**

```bash
# Check CPU usage by process
top -p $(pgrep -f "rails\|ruby\|sidekiq" | tr '\n' ',' | sed 's/,$//')

# Check for infinite loops or inefficient code
# Profile specific processes
sudo strace -p <PID> -c

# Check for high-frequency database queries
rails runner "
ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
  puts '#{payload[:sql]}' if finish - start > 0.1
end
" RAILS_ENV=production
```

**Solutions:**

```ruby
# Fix 1: Add query limits and pagination
def index
  @sermons = Sermon.page(params[:page]).per(25)  # Limit results
end

# Fix 2: Optimize eager loading
# Before:
sermons.each { |sermon| sermon.videos.count }
# After:
sermons.includes(:videos).each { |sermon| sermon.videos.size }

# Fix 3: Add background processing for heavy tasks
# Move expensive operations to background jobs
VideoProcessingJob.perform_later(video.id)
```

### Memory Leaks

**Memory Diagnostic:**

```bash
#!/bin/bash
# Memory leak detection script

echo "=== Memory Usage Analysis ==="

# Track memory usage over time
for i in {1..10}; do
  echo "Sample $i:"
  ps aux | grep -E "(rails|ruby|sidekiq)" | awk '{sum+=$6} END {print "Total Memory: " sum/1024 "MB"}'
  sleep 30
done

# Check for memory growth pattern
echo "Memory growth pattern:"
journalctl -u wordsoftruth-app --since "1 hour ago" | grep -i "memory\|oom"
```

**Memory Fixes:**

```ruby
# Fix 1: Add pagination to large datasets
def export_data
  Sermon.find_in_batches(batch_size: 1000) do |batch|
    process_batch(batch)
    # Memory is freed after each batch
  end
end

# Fix 2: Use select to limit loaded attributes
def lightweight_index
  @sermons = Sermon.select(:id, :title, :church, :created_at)
end

# Fix 3: Add memory monitoring
# In config/initializers/memory_monitor.rb
Rails.application.config.after_initialize do
  Thread.new do
    loop do
      memory_usage = `ps -o rss= -p #{Process.pid}`.to_i / 1024
      Rails.logger.warn "High memory usage: #{memory_usage}MB" if memory_usage > 1000
      sleep 60
    end
  end
end
```

## Deployment Issues

### Failed Deployments

**Rollback Procedure:**

```bash
#!/bin/bash
# Emergency rollback script

echo "Starting emergency rollback..."

# Kamal rollback
kamal rollback

# Manual rollback if needed
PREVIOUS_RELEASE=$(ls -1t /var/www/wordsoftruth/releases | head -2 | tail -1)
echo "Rolling back to: $PREVIOUS_RELEASE"

# Update symlink
ln -nfs "/var/www/wordsoftruth/releases/$PREVIOUS_RELEASE" /var/www/wordsoftruth/current

# Restart services
sudo systemctl restart wordsoftruth-app
sudo systemctl restart sidekiq

# Verify rollback
curl -f http://localhost:3000/health

echo "Rollback completed"
```

### Asset Compilation Issues

**Asset Problems:**

```bash
# Clear compiled assets
rails assets:clobber RAILS_ENV=production

# Precompile with verbose output
RAILS_ENV=production rails assets:precompile --trace

# Check for missing dependencies
npm audit
bundle outdated

# Fix Node.js/npm issues
rm -rf node_modules package-lock.json
npm install
```

### Database Migration Failures

**Migration Recovery:**

```bash
# Check current schema version
rails runner "puts ActiveRecord::Migrator.current_version" RAILS_ENV=production

# Manually set schema version if needed
rails runner "ActiveRecord::SchemaMigration.create!(version: '20240615120000')" RAILS_ENV=production

# Skip problematic migration temporarily
rails db:migrate:up VERSION=20240615120001 RAILS_ENV=production

# Force migration completion
rails db:schema:load RAILS_ENV=production  # ⚠️  Only for clean environments
```

## Security Incidents

### Suspected Security Breach

**Immediate Response:**

```bash
#!/bin/bash
# Security incident response

echo "=== SECURITY INCIDENT RESPONSE ==="

# 1. Isolate the system
echo "1. Isolating system..."
# Block external traffic if needed
# sudo ufw deny in

# 2. Preserve evidence
echo "2. Preserving evidence..."
cp -r /var/www/wordsoftruth/log /tmp/incident_logs_$(date +%Y%m%d_%H%M%S)

# 3. Check for suspicious activity
echo "3. Checking for suspicious activity..."
grep -i "unauthorized\|breach\|attack\|injection" /var/www/wordsoftruth/log/production.log | tail -20

# 4. Check system integrity
echo "4. Checking system integrity..."
find /var/www/wordsoftruth -name "*.rb" -newer /tmp/last_deployment -ls

# 5. Check active sessions
echo "5. Checking active sessions..."
rails runner "puts User.where('last_sign_in_at > ?', 1.hour.ago).count" RAILS_ENV=production

# 6. Generate security report
echo "6. Generating security report..."
# Custom security analysis
```

### Suspicious Database Activity

**Database Security Check:**

```sql
-- Check for suspicious queries
SELECT query, calls, total_time
FROM pg_stat_statements
WHERE query ILIKE '%DROP%' 
   OR query ILIKE '%DELETE%'
   OR query ILIKE '%UPDATE%users%'
   OR query ILIKE '%INSERT%'
ORDER BY calls DESC;

-- Check login attempts
SELECT user_id, sign_in_ip, sign_in_at
FROM users
WHERE sign_in_at > NOW() - INTERVAL '1 hour'
ORDER BY sign_in_at DESC;

-- Check for data modifications
SELECT table_name, n_tup_ins, n_tup_upd, n_tup_del
FROM pg_stat_user_tables
WHERE n_tup_del > 0 OR n_tup_upd > 100;
```

## Monitoring and Logging

### Log Analysis Commands

```bash
# Most common errors
grep -i "error\|exception" /var/www/wordsoftruth/log/production.log | \
  awk '{print $4}' | sort | uniq -c | sort -nr | head -10

# Response time analysis
grep "Completed" /var/www/wordsoftruth/log/production.log | \
  awk '{print $(NF-1)}' | sed 's/ms//' | \
  awk '{sum+=$1; count++} END {print "Avg response time: " sum/count "ms"}'

# Find memory leaks
grep -i "memory" /var/www/wordsoftruth/log/production.log | tail -20

# Database query analysis
grep "ActiveRecord" /var/www/wordsoftruth/log/production.log | \
  grep -o "[0-9]\+\.[0-9]\+ms" | sort -nr | head -10
```

### Setting Up Log Alerts

```bash
#!/bin/bash
# Log monitoring script for alerts

LOG_FILE="/var/www/wordsoftruth/log/production.log"
ALERT_EMAIL="admin@wordsoftruth.com"

# Monitor for critical errors
tail -f "$LOG_FILE" | while read line; do
  if echo "$line" | grep -qi "fatal\|critical\|emergency"; then
    echo "CRITICAL ERROR: $line" | mail -s "Critical Error Alert" "$ALERT_EMAIL"
  fi
  
  if echo "$line" | grep -qi "disk.*full\|no space"; then
    echo "DISK SPACE ALERT: $line" | mail -s "Disk Space Alert" "$ALERT_EMAIL"
  fi
done &
```

## Emergency Procedures

### Complete System Failure

**Emergency Recovery Steps:**

```bash
#!/bin/bash
# Emergency system recovery

echo "=== EMERGENCY SYSTEM RECOVERY ==="

# Step 1: Check system status
echo "1. Checking system status..."
systemctl is-active postgresql
systemctl is-active redis
systemctl is-active nginx

# Step 2: Start critical services
echo "2. Starting critical services..."
sudo systemctl start postgresql
sudo systemctl start redis
sudo systemctl start nginx

# Step 3: Restore from backup if needed
echo "3. Checking if restore is needed..."
if ! rails runner "Sermon.count" RAILS_ENV=production 2>/dev/null; then
  echo "Database appears corrupted, initiating restore..."
  # /path/to/restore_script.sh
fi

# Step 4: Start application
echo "4. Starting application..."
sudo systemctl start wordsoftruth-app
sudo systemctl start sidekiq

# Step 5: Verify recovery
echo "5. Verifying recovery..."
sleep 30
curl -f http://localhost:3000/health

echo "Recovery procedure completed"
```

### Data Corruption Recovery

```bash
#!/bin/bash
# Data corruption recovery

echo "=== DATA CORRUPTION RECOVERY ==="

# Stop all services
sudo systemctl stop wordsoftruth-app
sudo systemctl stop sidekiq

# Check database integrity
psql "$DATABASE_URL" -c "SELECT pg_size_pretty(pg_database_size(current_database()));"

# Restore from latest backup
LATEST_BACKUP=$(aws s3 ls s3://wordsoftruth-backups/database/ | sort | tail -1 | awk '{print $4}')
aws s3 cp "s3://wordsoftruth-backups/database/$LATEST_BACKUP" /tmp/

# Restore database
gunzip "/tmp/$LATEST_BACKUP"
psql "$DATABASE_URL" < "/tmp/${LATEST_BACKUP%.gz}"

# Run integrity checks
rails db:migrate RAILS_ENV=production
rails runner "puts 'Sermons: #{Sermon.count}, Videos: #{Video.count}'" RAILS_ENV=production

# Restart services
sudo systemctl start wordsoftruth-app
sudo systemctl start sidekiq
```

## Frequently Asked Questions

### Q: Why is the application slow after deployment?

**A:** Common causes and solutions:

1. **Asset compilation issues:**
   ```bash
   rails assets:precompile RAILS_ENV=production
   sudo systemctl restart nginx
   ```

2. **Database connection pool exhaustion:**
   ```yaml
   # config/database.yml
   production:
     pool: <%= ENV["DB_POOL"] || 25 %>
   ```

3. **Missing database indexes:**
   ```bash
   rails db:migrate RAILS_ENV=production
   ```

### Q: Background jobs are not processing

**A:** Check these common issues:

1. **Sidekiq not running:**
   ```bash
   sudo systemctl status sidekiq
   sudo systemctl start sidekiq
   ```

2. **Redis connection issues:**
   ```bash
   redis-cli ping
   # Should return PONG
   ```

3. **Memory issues:**
   ```bash
   # Check memory usage
   ps aux | grep sidekiq
   # Restart if usage is high
   sudo systemctl restart sidekiq
   ```

### Q: How to handle database migration failures?

**A:** Follow this process:

1. **Check migration status:**
   ```bash
   rails db:migrate:status RAILS_ENV=production
   ```

2. **Rollback if safe:**
   ```bash
   rails db:rollback RAILS_ENV=production
   ```

3. **Fix the migration and retry:**
   ```bash
   rails db:migrate RAILS_ENV=production
   ```

4. **Force completion if needed:**
   ```bash
   rails db:migrate:up VERSION=specific_version RAILS_ENV=production
   ```

### Q: Application shows 500 errors

**A:** Debug steps:

1. **Check logs:**
   ```bash
   tail -100 /var/www/wordsoftruth/log/production.log
   ```

2. **Check environment variables:**
   ```bash
   echo $SECRET_KEY_BASE
   echo $DATABASE_URL
   ```

3. **Restart application:**
   ```bash
   sudo systemctl restart wordsoftruth-app
   ```

### Q: How to recover from a failed deployment?

**A:** Rollback procedure:

1. **Use Kamal for quick rollback:**
   ```bash
   kamal rollback
   ```

2. **Manual rollback:**
   ```bash
   # Switch to previous release
   cd /var/www/wordsoftruth
   ln -nfs releases/previous current
   sudo systemctl restart wordsoftruth-app
   ```

3. **Verify rollback:**
   ```bash
   curl -f http://localhost:3000/health
   ```

## Support Contacts

- **Emergency Hotline**: +1-800-WORDS-OF-TRUTH
- **Technical Support**: support@wordsoftruth.com
- **DevOps Team**: devops@wordsoftruth.com
- **Security Team**: security@wordsoftruth.com

## Additional Resources

- **System Status**: https://status.wordsoftruth.com
- **Documentation**: https://docs.wordsoftruth.com
- **Monitoring Dashboard**: https://monitor.wordsoftruth.com
- **Log Aggregation**: https://logs.wordsoftruth.com

Remember to always test recovery procedures in staging before applying them to production!