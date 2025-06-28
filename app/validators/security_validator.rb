# Custom validators for enhanced security and input validation
class SecurityValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?
    
    case options[:type]
    when :url
      validate_url(record, attribute, value)
    when :scripture_reference
      validate_scripture_reference(record, attribute, value)
    when :content
      validate_content_security(record, attribute, value)
    when :filename
      validate_filename_security(record, attribute, value)
    when :email
      validate_email_security(record, attribute, value)
    end
  end

  private

  def validate_url(record, attribute, value)
    # Parse and validate URL
    begin
      uri = URI.parse(value)
      
      # Must be HTTP or HTTPS
      unless %w[http https].include?(uri.scheme&.downcase)
        record.errors.add(attribute, 'must be a valid HTTP or HTTPS URL')
        return
      end
      
      # Check for suspicious patterns
      if suspicious_url?(value)
        record.errors.add(attribute, 'contains suspicious content')
        return
      end
      
      # Check for SSRF vulnerabilities
      if ssrf_vulnerable?(uri)
        record.errors.add(attribute, 'targets internal/private network')
        return
      end
      
    rescue URI::InvalidURIError
      record.errors.add(attribute, 'is not a valid URL')
    end
  end

  def validate_scripture_reference(record, attribute, value)
    # Validate scripture reference format
    # Expected formats: "John 3:16", "1 Corinthians 13:1-13", "Psalm 23"
    
    scripture_pattern = /\A\d*\s*[A-Za-z]+(?:\s+\d+)?(?::\d+(?:-\d+)?)?\z/
    
    unless value.match?(scripture_pattern)
      record.errors.add(attribute, 'is not a valid scripture reference format')
    end
    
    # Check for potential injection attempts
    if contains_injection_patterns?(value)
      record.errors.add(attribute, 'contains invalid characters')
    end
  end

  def validate_content_security(record, attribute, value)
    # Check for various security threats in content
    
    # XSS patterns
    xss_patterns = [
      /<script[^>]*>/i,
      /javascript:/i,
      /vbscript:/i,
      /onload\s*=/i,
      /onerror\s*=/i,
      /onclick\s*=/i,
      /<iframe[^>]*>/i,
      /<object[^>]*>/i,
      /<embed[^>]*>/i,
      /<link[^>]*>/i,
      /<meta[^>]*>/i
    ]
    
    if xss_patterns.any? { |pattern| value.match?(pattern) }
      record.errors.add(attribute, 'contains potentially malicious content')
      return
    end
    
    # SQL injection patterns
    sql_patterns = [
      /union\s+select/i,
      /drop\s+table/i,
      /delete\s+from/i,
      /insert\s+into/i,
      /update\s+set/i,
      /;\s*--/,
      /'\s*or\s*'1'\s*=\s*'1/i
    ]
    
    if sql_patterns.any? { |pattern| value.match?(pattern) }
      record.errors.add(attribute, 'contains suspicious SQL patterns')
      return
    end
    
    # Check content length for DoS protection
    if value.length > 50_000 # 50KB limit
      record.errors.add(attribute, 'exceeds maximum length limit')
    end
  end

  def validate_filename_security(record, attribute, value)
    # Validate filename for path traversal and other attacks
    
    # Path traversal patterns
    if value.include?('..') || value.include?('/') || value.include?('\\')
      record.errors.add(attribute, 'contains invalid path characters')
      return
    end
    
    # Dangerous file extensions
    dangerous_extensions = %w[
      .exe .bat .cmd .com .pif .scr .vbs .js .jar .app .deb .pkg .dmg
      .php .asp .aspx .jsp .py .rb .pl .sh .bash .ps1
    ]
    
    if dangerous_extensions.any? { |ext| value.downcase.end_with?(ext) }
      record.errors.add(attribute, 'has a potentially dangerous file extension')
      return
    end
    
    # Check for null bytes and control characters
    if value.match?(/[\x00-\x1f\x7f-\x9f]/)
      record.errors.add(attribute, 'contains invalid control characters')
    end
  end

  def validate_email_security(record, attribute, value)
    # Enhanced email validation beyond format
    
    # Check for email injection patterns
    injection_patterns = [
      /\r|\n/,  # CRLF injection
      /%0a|%0d/i,  # URL encoded CRLF
      /bcc:/i,
      /cc:/i,
      /to:/i,
      /from:/i,
      /subject:/i,
      /content-type:/i
    ]
    
    if injection_patterns.any? { |pattern| value.match?(pattern) }
      record.errors.add(attribute, 'contains email injection patterns')
      return
    end
    
    # Check for suspicious domains
    if suspicious_email_domain?(value)
      record.errors.add(attribute, 'uses a suspicious domain')
    end
  end

  def suspicious_url?(url)
    # Check for various suspicious URL patterns
    suspicious_patterns = [
      /data:/i,          # Data URLs can contain malicious code
      /javascript:/i,    # JavaScript URLs
      /vbscript:/i,      # VBScript URLs
      /file:/i,          # File URLs
      /ftp:/i,           # FTP URLs might be suspicious in this context
      /@.*@/,            # Double @ signs (phishing technique)
      /[%][0-9a-f]{2}/i, # URL encoded characters (potential obfuscation)
    ]
    
    suspicious_patterns.any? { |pattern| url.match?(pattern) }
  end

  def ssrf_vulnerable?(uri)
    return false unless uri.host
    
    # Check for private/internal IP ranges
    begin
      ip = IPAddr.new(uri.host)
      
      # Private IP ranges
      private_ranges = [
        IPAddr.new('10.0.0.0/8'),
        IPAddr.new('172.16.0.0/12'),
        IPAddr.new('192.168.0.0/16'),
        IPAddr.new('127.0.0.0/8'),     # Loopback
        IPAddr.new('169.254.0.0/16'),  # Link-local
        IPAddr.new('::1/128'),         # IPv6 loopback
        IPAddr.new('fc00::/7'),        # IPv6 private
      ]
      
      private_ranges.any? { |range| range.include?(ip) }
      
    rescue IPAddr::InvalidAddressError
      # If it's not an IP address, check for localhost/internal hostnames
      internal_hosts = %w[localhost internal local intranet admin test staging dev]
      internal_hosts.any? { |host| uri.host.downcase.include?(host) }
    end
  end

  def contains_injection_patterns?(value)
    # Check for common injection patterns
    injection_patterns = [
      /<[^>]*>/,        # HTML tags
      /[;&|`$()]/,      # Command injection characters
      /['"]/,           # SQL injection quotes (in scripture context)
      /[{}]/,           # Template injection
    ]
    
    injection_patterns.any? { |pattern| value.match?(pattern) }
  end

  def suspicious_email_domain?(email)
    domain = email.split('@').last&.downcase
    return false unless domain
    
    # List of suspicious TLDs or domains
    suspicious_domains = %w[
      guerrillamail.com
      10minutemail.com
      mailinator.com
      tempmail.org
      throwaways.email
    ]
    
    # Check for suspicious patterns
    suspicious_patterns = [
      /^\d+\./,           # Domains starting with numbers
      /[.-]{2,}/,         # Multiple consecutive dots or dashes
      /^[.-]/,            # Starting with dot or dash
      /[.-]$/,            # Ending with dot or dash
    ]
    
    suspicious_domains.include?(domain) || 
      suspicious_patterns.any? { |pattern| domain.match?(pattern) }
  end
end

# Additional specific validators
class UrlSecurityValidator < SecurityValidator
  def validate_each(record, attribute, value)
    super(record, attribute, value) if options[:type] == :url
  end
end

class ContentSecurityValidator < SecurityValidator
  def validate_each(record, attribute, value)
    super(record, attribute, value) if options[:type] == :content
  end
end