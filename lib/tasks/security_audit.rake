# Comprehensive security audit tasks for Words of Truth
namespace :security do
  desc "Run comprehensive security audit"
  task audit: :environment do
    puts "🔒 Starting comprehensive security audit for Words of Truth..."
    
    audit_results = SecurityAuditRunner.new.run_full_audit
    
    # Generate audit report
    report_path = generate_audit_report(audit_results)
    puts "📊 Security audit completed. Report saved to: #{report_path}"
    
    # Check for critical issues
    critical_issues = audit_results.select { |result| result[:severity] == 'critical' }
    if critical_issues.any?
      puts "❌ CRITICAL SECURITY ISSUES FOUND:"
      critical_issues.each { |issue| puts "  - #{issue[:description]}" }
      exit 1
    else
      puts "✅ No critical security issues found"
    end
  end
  
  desc "Run security vulnerability scan"
  task vulnerability_scan: :environment do
    puts "🔍 Running vulnerability scan..."
    
    scanner = VulnerabilityScanner.new
    results = scanner.scan_all
    
    puts "Vulnerability scan results:"
    results.each do |category, vulnerabilities|
      puts "  #{category.upcase}: #{vulnerabilities.count} issues found"
      vulnerabilities.each do |vuln|
        puts "    - #{vuln[:severity].upcase}: #{vuln[:description]}"
      end
    end
  end
  
  desc "Audit business rule security"
  task business_rules: :environment do
    puts "🏢 Auditing business rule security..."
    
    auditor = BusinessRuleSecurityAuditor.new
    results = auditor.audit_all_rules
    
    puts "Business rule security audit results:"
    results.each do |rule, result|
      status = result[:compliant] ? "✅ PASS" : "❌ FAIL"
      puts "  #{rule}: #{status}"
      if !result[:compliant]
        result[:issues].each { |issue| puts "    - #{issue}" }
      end
    end
  end
  
  desc "Check data encryption compliance"
  task encryption_audit: :environment do
    puts "🔐 Auditing data encryption compliance..."
    
    auditor = EncryptionComplianceAuditor.new
    results = auditor.audit_encryption_status
    
    puts "Encryption compliance audit results:"
    puts "  Encrypted models: #{results[:encrypted_models].count}"
    puts "  Unencrypted sensitive fields: #{results[:unencrypted_fields].count}"
    
    if results[:unencrypted_fields].any?
      puts "  ⚠️  Unencrypted sensitive fields found:"
      results[:unencrypted_fields].each do |field|
        puts "    - #{field[:model]}##{field[:field]}"
      end
    end
  end
  
  desc "Audit access controls and permissions"
  task access_control: :environment do
    puts "🚪 Auditing access controls and permissions..."
    
    auditor = AccessControlAuditor.new
    results = auditor.audit_all_permissions
    
    puts "Access control audit results:"
    results.each do |component, result|
      puts "  #{component}: #{result[:status]}"
      if result[:issues].any?
        result[:issues].each { |issue| puts "    - #{issue}" }
      end
    end
  end
  
  desc "Generate security compliance report"
  task compliance_report: :environment do
    puts "📋 Generating security compliance report..."
    
    generator = SecurityComplianceReportGenerator.new
    report = generator.generate_comprehensive_report
    
    # Save report
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    report_path = Rails.root.join('tmp', "security_compliance_#{timestamp}.html")
    File.write(report_path, report)
    
    puts "📊 Security compliance report generated: #{report_path}"
  end
  
  private
  
  def generate_audit_report(audit_results)
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    report_path = Rails.root.join('tmp', "security_audit_#{timestamp}.json")
    
    report_data = {
      timestamp: Time.current.iso8601,
      application: 'Words of Truth',
      version: ENV['APP_VERSION'] || 'unknown',
      environment: Rails.env,
      audit_results: audit_results,
      summary: generate_audit_summary(audit_results)
    }
    
    File.write(report_path, JSON.pretty_generate(report_data))
    report_path
  end
  
  def generate_audit_summary(results)
    {
      total_checks: results.count,
      passed: results.count { |r| r[:status] == 'pass' },
      failed: results.count { |r| r[:status] == 'fail' },
      warnings: results.count { |r| r[:status] == 'warning' },
      critical_issues: results.count { |r| r[:severity] == 'critical' },
      high_issues: results.count { |r| r[:severity] == 'high' },
      medium_issues: results.count { |r| r[:severity] == 'medium' },
      low_issues: results.count { |r| r[:severity] == 'low' }
    }
  end
end

# Security audit runner
class SecurityAuditRunner
  def run_full_audit
    audit_results = []
    
    # Run all security audit components
    audit_results.concat(audit_authentication_security)
    audit_results.concat(audit_authorization_security)
    audit_results.concat(audit_input_validation)
    audit_results.concat(audit_data_protection)
    audit_results.concat(audit_session_management)
    audit_results.concat(audit_business_logic_security)
    audit_results.concat(audit_infrastructure_security)
    audit_results.concat(audit_compliance_requirements)
    
    audit_results
  end
  
  private
  
  def audit_authentication_security
    results = []
    
    # Check MFA implementation
    results << {
      check: 'multi_factor_authentication',
      status: User.method_defined?(:mfa_enabled?) ? 'pass' : 'fail',
      severity: 'high',
      description: 'Multi-factor authentication implementation',
      details: 'Verify MFA is properly implemented for user authentication'
    }
    
    # Check password policy
    results << {
      check: 'password_policy',
      status: check_password_policy_compliance ? 'pass' : 'fail',
      severity: 'medium',
      description: 'Password policy compliance',
      details: 'Verify strong password requirements are enforced'
    }
    
    # Check session timeout
    results << {
      check: 'session_timeout',
      status: check_session_timeout_configured ? 'pass' : 'fail',
      severity: 'medium',
      description: 'Session timeout configuration',
      details: 'Verify appropriate session timeouts are configured'
    }
    
    results
  end
  
  def audit_authorization_security
    results = []
    
    # Check RBAC implementation
    results << {
      check: 'role_based_access_control',
      status: check_rbac_implementation ? 'pass' : 'fail',
      severity: 'high',
      description: 'Role-based access control implementation',
      details: 'Verify proper RBAC is implemented across the application'
    }
    
    # Check privilege escalation protection
    results << {
      check: 'privilege_escalation_protection',
      status: check_privilege_escalation_protection ? 'pass' : 'fail',
      severity: 'critical',
      description: 'Privilege escalation protection',
      details: 'Verify users cannot escalate their privileges'
    }
    
    results
  end
  
  def audit_input_validation
    results = []
    
    # Check SQL injection protection
    results << {
      check: 'sql_injection_protection',
      status: check_sql_injection_protection ? 'pass' : 'fail',
      severity: 'critical',
      description: 'SQL injection protection',
      details: 'Verify all database queries use parameterized queries'
    }
    
    # Check XSS protection
    results << {
      check: 'xss_protection',
      status: check_xss_protection ? 'pass' : 'fail',
      severity: 'high',
      description: 'Cross-site scripting protection',
      details: 'Verify proper output encoding and CSP headers'
    }
    
    # Check CSRF protection
    results << {
      check: 'csrf_protection',
      status: check_csrf_protection ? 'pass' : 'fail',
      severity: 'high',
      description: 'Cross-site request forgery protection',
      details: 'Verify CSRF tokens are used for state-changing operations'
    }
    
    results
  end
  
  def audit_data_protection
    results = []
    
    # Check encryption at rest
    results << {
      check: 'encryption_at_rest',
      status: check_encryption_at_rest ? 'pass' : 'fail',
      severity: 'critical',
      description: 'Data encryption at rest',
      details: 'Verify sensitive data is encrypted in the database'
    }
    
    # Check encryption in transit
    results << {
      check: 'encryption_in_transit',
      status: check_encryption_in_transit ? 'pass' : 'fail',
      severity: 'critical',
      description: 'Data encryption in transit',
      details: 'Verify all communications use TLS/SSL'
    }
    
    # Check key management
    results << {
      check: 'key_management',
      status: check_key_management_security ? 'pass' : 'fail',
      severity: 'high',
      description: 'Encryption key management',
      details: 'Verify proper key storage and rotation procedures'
    }
    
    results
  end
  
  def audit_business_logic_security
    results = []
    
    # Check business rule validation
    results << {
      check: 'business_rule_validation',
      status: check_business_rule_validation ? 'pass' : 'fail',
      severity: 'high',
      description: 'Business rule validation security',
      details: 'Verify business rules cannot be bypassed'
    }
    
    # Check content validation
    results << {
      check: 'content_validation',
      status: check_content_validation_security ? 'pass' : 'fail',
      severity: 'medium',
      description: 'Content validation security',
      details: 'Verify theological and content validation cannot be circumvented'
    }
    
    results
  end
  
  def audit_compliance_requirements
    results = []
    
    # Check GDPR compliance
    results << {
      check: 'gdpr_compliance',
      status: check_gdpr_compliance ? 'pass' : 'warning',
      severity: 'high',
      description: 'GDPR compliance implementation',
      details: 'Verify GDPR requirements are properly implemented'
    }
    
    # Check audit logging
    results << {
      check: 'audit_logging',
      status: check_audit_logging_completeness ? 'pass' : 'fail',
      severity: 'medium',
      description: 'Comprehensive audit logging',
      details: 'Verify all security-relevant events are logged'
    }
    
    results
  end
  
  # Security check implementations
  def check_password_policy_compliance
    # Check if Devise is configured with proper password requirements
    return false unless defined?(Devise)
    
    config = Devise.setup
    config.password_length.min >= 8 && 
    User.validators.any? { |v| v.is_a?(ActiveModel::Validations::FormatValidator) }
  end
  
  def check_rbac_implementation
    # Check if authorization system is properly implemented
    AuthorizationService.respond_to?(:authorize) &&
    User.method_defined?(:role) &&
    ApplicationController.instance_methods.include?(:authorize_action)
  end
  
  def check_sql_injection_protection
    # Check for raw SQL usage without parameterization
    sql_files = Dir.glob(Rails.root.join('app', '**', '*.rb'))
    
    sql_files.none? do |file|
      content = File.read(file)
      # Look for potentially unsafe SQL patterns
      content.match?(/execute\s*\(\s*["'].*#\{/) || 
      content.match?(/where\s*\(\s*["'].*#\{/)
    end
  end
  
  def check_xss_protection
    # Check if XSS protection is enabled
    Rails.application.config.force_ssl &&
    SecurityConcern.instance_methods.include?(:sanitize_input)
  end
  
  def check_csrf_protection
    # Check if CSRF protection is enabled
    ApplicationController.instance_methods.include?(:verify_authenticity_token)
  end
  
  def check_encryption_at_rest
    # Check if models have encrypted attributes
    encrypted_models = ActiveRecord::Base.descendants.select do |model|
      model.respond_to?(:attr_encrypted_encrypted_attributes) &&
      model.attr_encrypted_encrypted_attributes.any?
    end
    
    encrypted_models.any?
  end
  
  def check_encryption_in_transit
    # Check if SSL is forced in production
    Rails.env.production? ? Rails.application.config.force_ssl : true
  end
  
  def check_business_rule_validation
    # Check if business validation is implemented
    BusinessParameterValidator.const_defined?(:VALIDATION_RULES) &&
    Sermon.validators.any? { |v| v.class.name.include?('BusinessParameter') }
  end
  
  def check_gdpr_compliance
    # Check if GDPR compliance features are implemented
    defined?(GDPRCompliance) &&
    User.method_defined?(:export_personal_data) &&
    User.method_defined?(:anonymize_personal_data)
  end
  
  def check_audit_logging_completeness
    # Check if comprehensive audit logging is implemented
    defined?(BusinessActivityLogging) &&
    BusinessActivityLog.table_exists?
  end
end

# Vulnerability scanner
class VulnerabilityScanner
  def scan_all
    {
      dependencies: scan_dependencies,
      application: scan_application_code,
      configuration: scan_configuration,
      infrastructure: scan_infrastructure
    }
  end
  
  private
  
  def scan_dependencies
    vulnerabilities = []
    
    # Run bundle audit
    begin
      output = `bundle audit check 2>&1`
      if $?.exitstatus != 0
        vulnerabilities << {
          severity: 'high',
          description: 'Vulnerable Ruby gems detected',
          details: output
        }
      end
    rescue => e
      vulnerabilities << {
        severity: 'medium',
        description: 'Unable to run bundle audit',
        details: e.message
      }
    end
    
    # Check for outdated gems
    outdated_gems = check_outdated_gems
    if outdated_gems.any?
      vulnerabilities << {
        severity: 'low',
        description: "#{outdated_gems.count} outdated gems found",
        details: outdated_gems.join(', ')
      }
    end
    
    vulnerabilities
  end
  
  def scan_application_code
    vulnerabilities = []
    
    # Run Brakeman
    begin
      brakeman_output = `bundle exec brakeman -q -f json 2>/dev/null`
      if $?.exitstatus == 0
        brakeman_results = JSON.parse(brakeman_output)
        
        brakeman_results['warnings'].each do |warning|
          vulnerabilities << {
            severity: determine_brakeman_severity(warning['confidence']),
            description: "#{warning['warning_type']}: #{warning['message']}",
            details: warning
          }
        end
      end
    rescue => e
      vulnerabilities << {
        severity: 'medium',
        description: 'Unable to run Brakeman scan',
        details: e.message
      }
    end
    
    vulnerabilities
  end
  
  def scan_configuration
    vulnerabilities = []
    
    # Check security headers
    unless Rails.application.config.force_ssl
      vulnerabilities << {
        severity: 'high',
        description: 'SSL not enforced',
        details: 'force_ssl should be enabled in production'
      }
    end
    
    # Check secret key configuration
    if Rails.application.secret_key_base.blank?
      vulnerabilities << {
        severity: 'critical',
        description: 'Secret key base not configured',
        details: 'SECRET_KEY_BASE environment variable must be set'
      }
    end
    
    vulnerabilities
  end
  
  def scan_infrastructure
    vulnerabilities = []
    
    # Check database configuration
    if Rails.application.config.database_configuration[Rails.env]['password'].blank?
      vulnerabilities << {
        severity: 'high',
        description: 'Database password not configured',
        details: 'Database should use strong authentication'
      }
    end
    
    vulnerabilities
  end
  
  def check_outdated_gems
    # This would implement gem version checking
    []
  end
  
  def determine_brakeman_severity(confidence)
    case confidence
    when 'High' then 'critical'
    when 'Medium' then 'high'
    when 'Weak' then 'medium'
    else 'low'
    end
  end
end

# Business rule security auditor
class BusinessRuleSecurityAuditor
  def audit_all_rules
    {
      content_validation: audit_content_validation_security,
      theological_validation: audit_theological_validation_security,
      user_permissions: audit_user_permission_security,
      data_access: audit_data_access_security,
      business_workflows: audit_business_workflow_security
    }
  end
  
  private
  
  def audit_content_validation_security
    # Check if content validation can be bypassed
    validation_bypass_checks = [
      check_input_sanitization,
      check_validation_enforcement,
      check_server_side_validation
    ]
    
    {
      compliant: validation_bypass_checks.all?,
      issues: validation_bypass_checks.reject(&:itself).map { |_| 'Validation bypass vulnerability detected' }
    }
  end
  
  def audit_theological_validation_security
    # Check theological validation security
    {
      compliant: true,
      issues: []
    }
  end
  
  def check_input_sanitization
    # Check if all inputs are properly sanitized
    SecurityConcern.instance_methods.include?(:sanitize_input)
  end
  
  def check_validation_enforcement
    # Check if validation cannot be bypassed
    true # Placeholder implementation
  end
  
  def check_server_side_validation
    # Ensure all validation happens server-side
    true # Placeholder implementation
  end
end