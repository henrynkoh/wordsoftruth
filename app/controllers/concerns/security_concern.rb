# Security concern for enhanced XSS protection and input sanitization
module SecurityConcern
  extend ActiveSupport::Concern
  
  included do
    # Enhanced CSRF protection
    protect_from_forgery with: :exception, prepend: true
    
    # Security headers
    before_action :set_security_headers
    before_action :sanitize_params
    before_action :check_content_type
    
    # Rate limiting (if using Rack::Attack)
    # protect_from_forgery with: :exception
  end

  private

  def set_security_headers
    # Content Security Policy
    response.headers['Content-Security-Policy'] = content_security_policy
    
    # XSS Protection
    response.headers['X-XSS-Protection'] = '1; mode=block'
    
    # Content Type Options
    response.headers['X-Content-Type-Options'] = 'nosniff'
    
    # Frame Options
    response.headers['X-Frame-Options'] = 'DENY'
    
    # Referrer Policy
    response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    
    # Permissions Policy
    response.headers['Permissions-Policy'] = 'geolocation=(), microphone=(), camera=()'
    
    # HSTS (if HTTPS)
    if request.ssl?
      response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains; preload'
    end
  end

  def content_security_policy
    policy = [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://cdn.jsdelivr.net",
      "style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net",
      "img-src 'self' data: https: http:",
      "font-src 'self' https://fonts.gstatic.com",
      "connect-src 'self' https:",
      "media-src 'self'",
      "object-src 'none'",
      "base-uri 'self'",
      "form-action 'self'",
      "frame-ancestors 'none'",
      "upgrade-insecure-requests"
    ]
    
    policy.join('; ')
  end

  def sanitize_params
    # Recursively sanitize all string parameters
    sanitize_hash(params) if params.present?
  end

  def sanitize_hash(hash)
    hash.each do |key, value|
      case value
      when String
        # Remove potentially dangerous HTML tags and attributes
        hash[key] = sanitize_html_input(value)
      when Hash
        sanitize_hash(value)
      when Array
        value.map! { |v| v.is_a?(String) ? sanitize_html_input(v) : v }
      end
    end
  end

  def sanitize_html_input(input)
    return input if input.blank?
    
    # Allow basic formatting tags but strip dangerous ones
    allowed_tags = %w[strong b em i u p br]
    allowed_attributes = %w[href]
    
    # Use Rails sanitize helper with strict whitelist
    ActionController::Base.helpers.sanitize(
      input,
      tags: allowed_tags,
      attributes: allowed_attributes,
      remove_contents: %w[script style],
      whitespace: :remove
    )
  end

  def check_content_type
    # Ensure JSON requests have proper content type
    if request.format.json? && request.post?
      unless request.content_type&.include?('application/json')
        render json: { error: 'Invalid content type' }, status: :bad_request
        return false
      end
    end
  end

  # Enhanced parameter validation
  def validate_required_params(required_keys)
    missing_keys = required_keys.select { |key| params[key].blank? }
    
    if missing_keys.any?
      render json: { 
        error: 'Missing required parameters', 
        missing: missing_keys 
      }, status: :bad_request
      return false
    end
    
    true
  end

  # Secure redirect helper
  def safe_redirect_to(url_or_path, fallback_path = root_path)
    # Only allow redirects to same origin or relative paths
    if url_or_path.is_a?(String)
      uri = URI.parse(url_or_path)
      
      # Check if it's a relative path or same host
      if uri.relative? || uri.host == request.host
        redirect_to url_or_path
      else
        Rails.logger.warn "Blocked redirect to external host: #{uri.host}"
        redirect_to fallback_path
      end
    else
      redirect_to url_or_path
    end
  rescue URI::InvalidURIError
    Rails.logger.warn "Invalid redirect URL: #{url_or_path}"
    redirect_to fallback_path
  end

  # File upload security
  def validate_file_upload(file, allowed_types: [], max_size: 10.megabytes)
    return { valid: false, error: 'No file provided' } unless file.present?
    
    # Check file size
    if file.size > max_size
      return { valid: false, error: 'File size exceeds limit' }
    end
    
    # Check file type
    if allowed_types.any? && !allowed_types.include?(file.content_type)
      return { valid: false, error: 'Invalid file type' }
    end
    
    # Check for embedded malicious content
    if contains_malicious_content?(file)
      return { valid: false, error: 'File contains suspicious content' }
    end
    
    { valid: true }
  end

  def contains_malicious_content?(file)
    # Basic check for executable content in files
    dangerous_patterns = [
      /<script/i,
      /javascript:/i,
      /vbscript:/i,
      /onload=/i,
      /onerror=/i,
      /<iframe/i,
      /<object/i,
      /<embed/i
    ]
    
    file.rewind
    content_sample = file.read(1024) # Read first 1KB
    file.rewind
    
    dangerous_patterns.any? { |pattern| content_sample.match?(pattern) }
  rescue
    # If we can't read the file, consider it suspicious
    true
  end

  # Rate limiting helper
  def check_rate_limit(key, limit: 60, period: 1.hour)
    cache_key = "rate_limit:#{key}:#{request.remote_ip}"
    current_requests = Rails.cache.read(cache_key) || 0
    
    if current_requests >= limit
      render json: { error: 'Rate limit exceeded' }, status: :too_many_requests
      return false
    end
    
    Rails.cache.write(cache_key, current_requests + 1, expires_in: period)
    true
  end
end