# Security configuration for Words of Truth application
Rails.application.configure do
  # Force SSL in production
  config.force_ssl = true if Rails.env.production?
  
  # Configure session security
  config.session_store :cookie_store,
    key: '_wordsoftruth_session',
    secure: Rails.env.production?,
    httponly: true,
    same_site: :strict,
    expire_after: 4.hours
  
  # Configure cookies security
  config.cookies.same_site_protection = :strict
  config.cookies.secure = Rails.env.production?
  
  # Content Security Policy
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, 'https://fonts.gstatic.com'
    policy.img_src     :self, :https, :data
    policy.object_src  :none
    policy.script_src  :self, 'https://cdn.jsdelivr.net'
    policy.style_src   :self, 'https://fonts.googleapis.com', 'https://cdn.jsdelivr.net', :unsafe_inline
    policy.connect_src :self, :https
    policy.frame_ancestors :none
    policy.base_uri :self
    policy.form_action :self
    
    # Specify URI for violation reports
    # policy.report_uri "/csp-violation-report-endpoint"
  end
  
  # Configure CSP nonce generation
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
  
  # Report CSP violations in development
  config.content_security_policy_report_only = true if Rails.env.development?
  
  # Configure Permissions Policy (Feature Policy)
  config.permissions_policy do |policy|
    policy.camera      :none
    policy.gyroscope   :none
    policy.microphone  :none
    policy.usb         :none
    policy.fullscreen  :self
    policy.payment     :none
    policy.geolocation :none
    policy.clipboard_read :self
    policy.clipboard_write :self
  end
end

# Additional security configurations
module Security
  # Rate limiting configuration
  RATE_LIMITS = {
    search: { limit: 100, period: 1.hour },
    api_requests: { limit: 1000, period: 1.hour },
    login_attempts: { limit: 5, period: 15.minutes },
    password_reset: { limit: 3, period: 1.hour }
  }.freeze
  
  # File upload restrictions
  FILE_UPLOAD = {
    max_size: 10.megabytes,
    allowed_types: %w[
      image/jpeg
      image/png
      image/gif
      text/plain
      application/pdf
    ].freeze,
    scan_for_viruses: Rails.env.production?
  }.freeze
  
  # Password policy
  PASSWORD_POLICY = {
    min_length: 12,
    require_uppercase: true,
    require_lowercase: true,
    require_numbers: true,
    require_special_chars: true,
    max_age_days: 90,
    history_count: 12
  }.freeze
  
  # Session configuration
  SESSION_CONFIG = {
    timeout_minutes: 240, # 4 hours
    extend_on_activity: true,
    force_logout_on_ip_change: Rails.env.production?,
    max_concurrent_sessions: 3
  }.freeze
  
  # API security
  API_SECURITY = {
    require_authentication: true,
    rate_limit_per_minute: 60,
    allowed_origins: Rails.env.production? ? ['https://wordsoftruth.com'] : ['http://localhost:3000'],
    require_https: Rails.env.production?
  }.freeze
end

# Initialize security components
if defined?(Rack::Attack)
  # Rate limiting with Rack::Attack
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  
  # Throttle general requests
  Rack::Attack.throttle('requests by ip', limit: 300, period: 5.minutes) do |request|
    request.ip unless request.path.start_with?('/assets')
  end
  
  # Throttle login attempts
  Rack::Attack.throttle('logins by ip', limit: 5, period: 20.minutes) do |request|
    if request.path == '/users/sign_in' && request.post?
      request.ip
    end
  end
  
  # Throttle API requests
  Rack::Attack.throttle('api requests', limit: 100, period: 1.hour) do |request|
    if request.path.start_with?('/api/')
      request.ip
    end
  end
  
  # Block suspicious patterns
  Rack::Attack.blocklist('block scrapers') do |request|
    # Block requests with suspicious user agents
    request.user_agent =~ /scrapy|mechanize|crawler|spider/i
  end
  
  # Safelist legitimate traffic
  Rack::Attack.safelist('allow local traffic') do |request|
    request.ip == '127.0.0.1' || request.ip == '::1'
  end
end

# Security headers middleware
class SecurityHeadersMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)
    
    # Add security headers
    headers['X-Frame-Options'] = 'DENY'
    headers['X-XSS-Protection'] = '1; mode=block'
    headers['X-Content-Type-Options'] = 'nosniff'
    headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    headers['X-Permitted-Cross-Domain-Policies'] = 'none'
    
    # HSTS header for HTTPS
    if env['HTTPS'] == 'on' || env['HTTP_X_FORWARDED_PROTO'] == 'https'
      headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains; preload'
    end
    
    [status, headers, response]
  end
end

# Configure security logging
Rails.application.configure do
  # Security event logging
  config.after_initialize do
    ActiveSupport::Notifications.subscribe('security.authentication_failure') do |name, start, finish, id, payload|
      Rails.logger.warn "SECURITY: Authentication failure - IP: #{payload[:ip]}, User: #{payload[:user]}, Reason: #{payload[:reason]}"
    end
    
    ActiveSupport::Notifications.subscribe('security.suspicious_activity') do |name, start, finish, id, payload|
      Rails.logger.error "SECURITY: Suspicious activity detected - #{payload[:details]}"
    end
    
    ActiveSupport::Notifications.subscribe('security.data_access') do |name, start, finish, id, payload|
      Rails.logger.info "SECURITY: Sensitive data access - User: #{payload[:user]}, Resource: #{payload[:resource]}"
    end
  end
end