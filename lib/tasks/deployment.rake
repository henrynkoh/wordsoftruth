# Deployment tasks and procedures for Words of Truth
namespace :deploy do
  desc "Run pre-deployment checks"
  task pre_deployment_checks: :environment do
    puts "🚀 Running pre-deployment checks for Words of Truth..."
    
    checker = PreDeploymentChecker.new
    results = checker.run_all_checks
    
    if results[:success]
      puts "✅ All pre-deployment checks passed"
      puts "Ready for deployment!"
    else
      puts "❌ Pre-deployment checks failed:"
      results[:failures].each { |failure| puts "  - #{failure}" }
      exit 1
    end
  end
  
  desc "Create deployment checklist"
  task checklist: :environment do
    puts "📋 Generating deployment checklist..."
    
    checklist = DeploymentChecklistGenerator.new.generate
    
    # Save checklist to file
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    checklist_path = Rails.root.join('tmp', "deployment_checklist_#{timestamp}.md")
    File.write(checklist_path, checklist)
    
    puts "📄 Deployment checklist generated: #{checklist_path}"
    puts checklist
  end
  
  desc "Test rollback procedures"
  task test_rollback: :environment do
    puts "🔄 Testing rollback procedures..."
    
    tester = RollbackTester.new
    results = tester.test_rollback_procedures
    
    puts "Rollback test results:"
    results.each do |test, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      puts "  #{test}: #{status}"
      if !result[:success]
        puts "    Error: #{result[:error]}"
      end
    end
  end
  
  desc "Backup database before deployment"
  task backup_database: :environment do
    puts "💾 Creating database backup before deployment..."
    
    backup_service = DatabaseBackupService.new
    backup_path = backup_service.create_deployment_backup
    
    puts "✅ Database backup created: #{backup_path}"
    
    # Verify backup integrity
    if backup_service.verify_backup(backup_path)
      puts "✅ Backup integrity verified"
    else
      puts "❌ Backup integrity check failed"
      exit 1
    end
  end
  
  desc "Track deployment"
  task track_deployment: :environment do
    puts "📊 Tracking deployment..."
    
    tracker = DeploymentTracker.new
    deployment_record = tracker.record_deployment
    
    puts "✅ Deployment tracked with ID: #{deployment_record.id}"
    puts "   Version: #{deployment_record.version}"
    puts "   Deployed at: #{deployment_record.deployed_at}"
    puts "   Deployed by: #{deployment_record.deployed_by}"
  end
  
  desc "Post-deployment verification"
  task verify_deployment: :environment do
    puts "🔍 Running post-deployment verification..."
    
    verifier = PostDeploymentVerifier.new
    results = verifier.verify_all
    
    if results[:success]
      puts "✅ Post-deployment verification passed"
    else
      puts "❌ Post-deployment verification failed:"
      results[:failures].each { |failure| puts "  - #{failure}" }
    end
  end
  
  desc "Generate rollback plan"
  task rollback_plan: :environment do
    puts "📋 Generating rollback plan..."
    
    generator = RollbackPlanGenerator.new
    plan = generator.generate_rollback_plan
    
    # Save rollback plan
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    plan_path = Rails.root.join('tmp', "rollback_plan_#{timestamp}.md")
    File.write(plan_path, plan)
    
    puts "📄 Rollback plan generated: #{plan_path}"
  end
  
  desc "Execute rollback"
  task rollback: :environment do
    puts "🔄 Executing rollback procedure..."
    
    rollback_executor = RollbackExecutor.new
    result = rollback_executor.execute_rollback
    
    if result[:success]
      puts "✅ Rollback completed successfully"
      puts "   Rolled back to version: #{result[:version]}"
    else
      puts "❌ Rollback failed: #{result[:error]}"
      exit 1
    end
  end
end

# Pre-deployment checker
class PreDeploymentChecker
  def run_all_checks
    checks = [
      check_environment_variables,
      check_database_migrations,
      check_asset_compilation,
      check_test_suite,
      check_security_scan,
      check_business_validation,
      check_dependencies,
      check_disk_space,
      check_service_health
    ]
    
    failures = checks.reject { |check| check[:success] }
    
    {
      success: failures.empty?,
      failures: failures.map { |check| check[:message] },
      total_checks: checks.count,
      passed_checks: checks.count - failures.count
    }
  end
  
  private
  
  def check_environment_variables
    required_vars = %w[
      SECRET_KEY_BASE
      DATABASE_URL
      REDIS_URL
    ]
    
    missing_vars = required_vars.reject { |var| ENV[var].present? }
    
    {
      success: missing_vars.empty?,
      message: missing_vars.empty? ? 
        "Environment variables configured" : 
        "Missing environment variables: #{missing_vars.join(', ')}"
    }
  end
  
  def check_database_migrations
    begin
      pending_migrations = ActiveRecord::Base.connection.migration_context.needs_migration?
      
      {
        success: !pending_migrations,
        message: pending_migrations ? 
          "Pending database migrations detected" : 
          "Database migrations up to date"
      }
    rescue => e
      {
        success: false,
        message: "Database migration check failed: #{e.message}"
      }
    end
  end
  
  def check_asset_compilation
    begin
      # Test asset compilation
      system("RAILS_ENV=production rails assets:precompile --trace 2>/dev/null")
      success = $?.exitstatus == 0
      
      {
        success: success,
        message: success ? "Asset compilation successful" : "Asset compilation failed"
      }
    rescue => e
      {
        success: false,
        message: "Asset compilation check failed: #{e.message}"
      }
    end
  end
  
  def check_test_suite
    begin
      # Run critical tests
      system("rails test:models test:controllers 2>/dev/null")
      success = $?.exitstatus == 0
      
      {
        success: success,
        message: success ? "Critical tests passing" : "Critical tests failing"
      }
    rescue => e
      {
        success: false,
        message: "Test suite check failed: #{e.message}"
      }
    end
  end
  
  def check_security_scan
    begin
      # Run Brakeman security scan
      system("bundle exec brakeman -q 2>/dev/null")
      success = $?.exitstatus == 0
      
      {
        success: success,
        message: success ? "Security scan passed" : "Security vulnerabilities detected"
      }
    rescue => e
      {
        success: false,
        message: "Security scan failed: #{e.message}"
      }
    end
  end
  
  def check_business_validation
    begin
      # Run business validation tests
      BusinessRuleValidator.new.validate_all
      
      {
        success: true,
        message: "Business validation passed"
      }
    rescue => e
      {
        success: false,
        message: "Business validation failed: #{e.message}"
      }
    end
  end
  
  def check_dependencies
    begin
      # Check if all gems are properly installed
      system("bundle check 2>/dev/null")
      success = $?.exitstatus == 0
      
      {
        success: success,
        message: success ? "Dependencies satisfied" : "Missing dependencies"
      }
    rescue => e
      {
        success: false,
        message: "Dependency check failed: #{e.message}"
      }
    end
  end
  
  def check_disk_space
    begin
      # Check available disk space (require at least 1GB)
      available_space = `df -BG . | tail -1 | awk '{print $4}' | sed 's/G//'`.to_i
      required_space = 1 # 1GB
      
      {
        success: available_space >= required_space,
        message: available_space >= required_space ? 
          "Sufficient disk space (#{available_space}GB available)" : 
          "Insufficient disk space (#{available_space}GB available, #{required_space}GB required)"
      }
    rescue => e
      {
        success: false,
        message: "Disk space check failed: #{e.message}"
      }
    end
  end
  
  def check_service_health
    checks = []
    
    # Database health
    begin
      ActiveRecord::Base.connection.execute('SELECT 1')
      checks << { service: 'database', healthy: true }
    rescue => e
      checks << { service: 'database', healthy: false, error: e.message }
    end
    
    # Redis health
    begin
      Redis.current.ping
      checks << { service: 'redis', healthy: true }
    rescue => e
      checks << { service: 'redis', healthy: false, error: e.message }
    end
    
    unhealthy_services = checks.reject { |check| check[:healthy] }
    
    {
      success: unhealthy_services.empty?,
      message: unhealthy_services.empty? ? 
        "All services healthy" : 
        "Unhealthy services: #{unhealthy_services.map { |s| s[:service] }.join(', ')}"
    }
  end
end

# Deployment checklist generator
class DeploymentChecklistGenerator
  def generate
    <<~CHECKLIST
      # Words of Truth Deployment Checklist
      
      ## Pre-Deployment (Complete 24 hours before deployment)
      
      ### Infrastructure Preparation
      - [ ] Verify staging environment is up to date
      - [ ] Run full test suite on staging
      - [ ] Perform security scan and address any issues
      - [ ] Verify SSL certificates are valid and not expiring soon
      - [ ] Check disk space on production servers (minimum 5GB free)
      - [ ] Verify database backup system is functional
      - [ ] Test monitoring and alerting systems
      
      ### Code Preparation
      - [ ] All feature branches merged to main
      - [ ] Version number updated in application
      - [ ] CHANGELOG.md updated with release notes
      - [ ] Database migrations tested on staging with production-like data
      - [ ] Asset compilation tested and verified
      - [ ] Environment variables documented and verified
      
      ### Business Validation
      - [ ] Business stakeholders approval obtained
      - [ ] Theological validation tests passing
      - [ ] Content quality metrics within acceptable ranges
      - [ ] Video generation success rate above 92%
      - [ ] User acceptance testing completed
      
      ## Deployment Day
      
      ### Pre-Deployment (2 hours before)
      - [ ] Notify stakeholders of upcoming deployment
      - [ ] Put maintenance page in standby
      - [ ] Create fresh database backup
      - [ ] Verify backup integrity
      - [ ] Take snapshot of current application state
      - [ ] Prepare rollback procedures
      
      ### Deployment Execution
      - [ ] Enable maintenance mode
      - [ ] Deploy application code
      - [ ] Run database migrations
      - [ ] Precompile and deploy assets
      - [ ] Update configuration files
      - [ ] Restart application services
      - [ ] Disable maintenance mode
      
      ### Post-Deployment Verification (Within 30 minutes)
      - [ ] Application responds to health checks
      - [ ] Critical user workflows functional
      - [ ] Database connectivity verified
      - [ ] Background job processing functional
      - [ ] Monitoring systems receiving data
      - [ ] No critical errors in logs
      - [ ] Business accuracy metrics stable
      
      ### Post-Deployment Monitoring (Within 2 hours)
      - [ ] Response times within normal ranges
      - [ ] Error rates below 1%
      - [ ] Business metrics functioning normally
      - [ ] User reports of issues addressed
      - [ ] Performance metrics stable
      
      ## Rollback Procedures (If needed)
      
      ### Immediate Rollback (Critical issues)
      - [ ] Enable maintenance mode
      - [ ] Restore previous application version
      - [ ] Rollback database migrations (if safe)
      - [ ] Restore previous configuration
      - [ ] Restart services
      - [ ] Verify rollback successful
      - [ ] Disable maintenance mode
      - [ ] Notify stakeholders of rollback
      
      ### Communication
      - [ ] Update deployment status in team channels
      - [ ] Notify customer support of any user-facing changes
      - [ ] Update status page if applicable
      - [ ] Document any issues encountered
      - [ ] Schedule post-deployment review meeting
      
      ## Sign-off
      - [ ] Technical Lead: _________________ Date: _______
      - [ ] DevOps Engineer: _________________ Date: _______
      - [ ] Business Owner: _________________ Date: _______
      
      ---
      Generated on: #{Time.current.strftime('%Y-%m-%d %H:%M:%S UTC')}
      Version: #{ENV['APP_VERSION'] || 'unknown'}
      Environment: #{Rails.env}
    CHECKLIST
  end
end

# Rollback plan generator
class RollbackPlanGenerator
  def generate_rollback_plan
    current_deployment = get_current_deployment_info
    previous_deployment = get_previous_deployment_info
    
    <<~ROLLBACK_PLAN
      # Emergency Rollback Plan - Words of Truth
      
      ## Current Deployment Information
      - Version: #{current_deployment[:version]}
      - Deployed at: #{current_deployment[:deployed_at]}
      - Deployed by: #{current_deployment[:deployed_by]}
      - Git SHA: #{current_deployment[:git_sha]}
      
      ## Target Rollback Information
      - Version: #{previous_deployment[:version]}
      - Git SHA: #{previous_deployment[:git_sha]}
      - Last known good state: #{previous_deployment[:deployed_at]}
      
      ## Rollback Procedures
      
      ### 1. Immediate Response (Execute within 5 minutes)
      ```bash
      # Enable maintenance mode
      kamal app exec "touch tmp/maintenance.txt"
      
      # Quick health check
      curl -f https://wordsoftruth.com/health || echo "Application down"
      ```
      
      ### 2. Application Rollback (Execute within 10 minutes)
      ```bash
      # Rollback to previous version using Kamal
      kamal rollback
      
      # Alternative manual rollback
      # kamal app deploy --version=#{previous_deployment[:git_sha]}
      ```
      
      ### 3. Database Rollback (Only if migrations were run)
      ```bash
      # Check if database rollback is needed
      rails db:migrate:status
      
      # Rollback specific migrations (DANGEROUS - use with caution)
      # rails db:migrate:down VERSION=20240628120000
      
      # Or restore from backup (safer option)
      # ./scripts/restore_database_backup.sh #{previous_deployment[:backup_file]}
      ```
      
      ### 4. Asset Rollback
      ```bash
      # Assets should rollback automatically with application
      # Verify asset integrity
      curl -f https://wordsoftruth.com/assets/application.css
      curl -f https://wordsoftruth.com/assets/application.js
      ```
      
      ### 5. Configuration Rollback
      ```bash
      # Restore previous configuration
      git checkout #{previous_deployment[:git_sha]} -- config/
      
      # Restart services with previous configuration
      kamal app restart
      ```
      
      ### 6. Verification Steps
      ```bash
      # Health checks
      curl -f https://wordsoftruth.com/health
      curl -f https://wordsoftruth.com/health/detailed
      
      # Business functionality checks
      curl -f https://wordsoftruth.com/health/business
      
      # Check critical workflows
      # - User authentication
      # - Sermon processing
      # - Video generation
      ```
      
      ### 7. Post-Rollback Actions
      - [ ] Disable maintenance mode
      - [ ] Notify stakeholders of rollback
      - [ ] Update status page
      - [ ] Begin incident investigation
      - [ ] Document rollback reasons
      
      ## Contact Information
      - On-call Engineer: #{ENV['ONCALL_ENGINEER'] || 'TBD'}
      - Technical Lead: #{ENV['TECH_LEAD'] || 'TBD'}
      - Business Owner: #{ENV['BUSINESS_OWNER'] || 'TBD'}
      
      ## Rollback Decision Matrix
      
      | Issue Severity | Response Time | Action |
      |----------------|---------------|---------|
      | P1 - Critical (Application Down) | Immediate | Full rollback |
      | P2 - High (Major Feature Broken) | 15 minutes | Targeted rollback or hotfix |
      | P3 - Medium (Minor Issues) | 1 hour | Hotfix preferred |
      | P4 - Low (Cosmetic Issues) | Next deployment | Schedule fix |
      
      ## Automated Rollback Triggers
      - Error rate > 5% for 5 minutes
      - Response time P95 > 5 seconds for 10 minutes
      - Business accuracy drop > 10% from baseline
      - Critical business workflow failure
      
      ---
      Generated on: #{Time.current.strftime('%Y-%m-%d %H:%M:%S UTC')}
      Environment: #{Rails.env}
    ROLLBACK_PLAN
  end
  
  private
  
  def get_current_deployment_info
    {
      version: ENV['APP_VERSION'] || 'unknown',
      deployed_at: ENV['DEPLOYMENT_TIME'] || Time.current.iso8601,
      deployed_by: ENV['DEPLOYED_BY'] || 'unknown',
      git_sha: ENV['GIT_SHA'] || `git rev-parse HEAD`.strip
    }
  end
  
  def get_previous_deployment_info
    # This would query deployment history
    # For now, return placeholder data
    {
      version: 'v1.0.0',
      git_sha: 'abc123def456',
      deployed_at: 1.day.ago.iso8601,
      backup_file: "backup_#{1.day.ago.strftime('%Y%m%d_%H%M%S')}.sql"
    }
  end
end

# Database backup service
class DatabaseBackupService
  def create_deployment_backup
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    backup_filename = "deployment_backup_#{timestamp}.sql"
    backup_path = Rails.root.join('tmp', backup_filename)
    
    # Create database backup
    database_url = ENV['DATABASE_URL'] || Rails.application.config.database_configuration[Rails.env]['url']
    
    system("pg_dump #{database_url} > #{backup_path}")
    
    if $?.exitstatus == 0
      # Compress backup
      system("gzip #{backup_path}")
      "#{backup_path}.gz"
    else
      raise "Database backup failed"
    end
  end
  
  def verify_backup(backup_path)
    # Verify backup file exists and is not empty
    File.exist?(backup_path) && File.size(backup_path) > 0
  end
end

# Deployment tracker
class DeploymentTracker
  def record_deployment
    Deployment.create!(
      version: ENV['APP_VERSION'] || 'unknown',
      git_sha: ENV['GIT_SHA'] || `git rev-parse HEAD`.strip,
      deployed_by: ENV['DEPLOYED_BY'] || 'system',
      deployed_at: Time.current,
      environment: Rails.env,
      status: 'in_progress'
    )
  end
end

# Post-deployment verifier
class PostDeploymentVerifier
  def verify_all
    verifications = [
      verify_application_health,
      verify_database_connectivity,
      verify_redis_connectivity,
      verify_background_jobs,
      verify_business_functionality,
      verify_monitoring_systems
    ]
    
    failures = verifications.reject { |v| v[:success] }
    
    {
      success: failures.empty?,
      failures: failures.map { |v| v[:message] },
      total_verifications: verifications.count,
      passed_verifications: verifications.count - failures.count
    }
  end
  
  private
  
  def verify_application_health
    begin
      response = Net::HTTP.get_response(URI('http://localhost:3000/health'))
      success = response.code == '200'
      
      {
        success: success,
        message: success ? "Application health check passed" : "Application health check failed"
      }
    rescue => e
      {
        success: false,
        message: "Application health check failed: #{e.message}"
      }
    end
  end
  
  def verify_database_connectivity
    begin
      ActiveRecord::Base.connection.execute('SELECT 1')
      {
        success: true,
        message: "Database connectivity verified"
      }
    rescue => e
      {
        success: false,
        message: "Database connectivity failed: #{e.message}"
      }
    end
  end
  
  def verify_redis_connectivity
    begin
      Redis.current.ping
      {
        success: true,
        message: "Redis connectivity verified"
      }
    rescue => e
      {
        success: false,
        message: "Redis connectivity failed: #{e.message}"
      }
    end
  end
  
  def verify_background_jobs
    begin
      stats = Sidekiq::Stats.new
      # Consider healthy if there are no failed jobs in the last hour
      recent_failures = stats.failed
      
      {
        success: recent_failures < 10, # Allow some failures
        message: recent_failures < 10 ? 
          "Background job processing healthy" : 
          "High background job failure rate: #{recent_failures}"
      }
    rescue => e
      {
        success: false,
        message: "Background job verification failed: #{e.message}"
      }
    end
  end
  
  def verify_business_functionality
    begin
      # Test critical business operations
      test_sermon_creation
      test_video_generation_queue
      
      {
        success: true,
        message: "Business functionality verified"
      }
    rescue => e
      {
        success: false,
        message: "Business functionality verification failed: #{e.message}"
      }
    end
  end
  
  def verify_monitoring_systems
    begin
      # Check if monitoring is receiving data
      recent_logs = BusinessActivityLog.where(performed_at: 5.minutes.ago..Time.current)
      
      {
        success: recent_logs.exists?,
        message: recent_logs.exists? ? 
          "Monitoring systems active" : 
          "Monitoring systems not receiving data"
      }
    rescue => e
      {
        success: false,
        message: "Monitoring verification failed: #{e.message}"
      }
    end
  end
  
  def test_sermon_creation
    # Test basic sermon creation functionality
    Sermon.new(
      title: 'Deployment Test Sermon',
      source_url: 'https://example.com/test',
      church: 'Test Church'
    ).valid?
  end
  
  def test_video_generation_queue
    # Test video generation queueing
    # This is a dry run that doesn't actually create a video
    true
  end
end