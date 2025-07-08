# frozen_string_literal: true

# Rate limiting and attack protection configuration
class Rack::Attack
  # Enable in production and staging
  Rack::Attack.enabled = !Rails.env.development?

  # Cache store for rate limiting
  Rack::Attack.cache.store = Rails.cache

  # Throttle requests by IP
  throttle('req/ip', limit: 300, period: 5.minutes) do |req|
    req.ip
  end

  # Throttle login attempts
  throttle('logins/ip', limit: 10, period: 20.minutes) do |req|
    if req.path == '/auth/google_oauth2' && req.post?
      req.ip
    end
  end

  # Throttle API calls
  throttle('api/ip', limit: 100, period: 1.hour) do |req|
    req.ip if req.path.start_with?('/api/')
  end

  # Throttle text note creation
  throttle('text_notes/ip', limit: 50, period: 1.hour) do |req|
    req.ip if req.path == '/text_notes' && req.post?
  end

  # Block suspicious requests
  blocklist('block suspicious IPs') do |req|
    # Block requests with suspicious user agents
    suspicious_agents = [
      'sqlmap',
      'nikto',
      'dirbuster',
      'nmap',
      'masscan'
    ]
    
    user_agent = req.get_header('HTTP_USER_AGENT')&.downcase
    suspicious_agents.any? { |agent| user_agent&.include?(agent) }
  end

  # Block path traversal attempts
  blocklist('block path traversal') do |req|
    req.path.include?('..') || req.path.include?('//')
  end

  # Custom response for blocked requests
  self.blocklisted_response = lambda do |env|
    [
      429,
      { 'Content-Type' => 'application/json' },
      [{ error: 'Request blocked due to suspicious activity' }.to_json]
    ]
  end

  # Custom response for throttled requests
  self.throttled_response = lambda do |env|
    [
      429,
      { 'Content-Type' => 'application/json' },
      [{ error: 'Rate limit exceeded. Please try again later.' }.to_json]
    ]
  end

  # Logging for security events
  ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, req|
    Rails.logger.warn "Rack::Attack #{req.env['rack.attack.match_type']}: #{req.ip} - #{req.path}"
  end
end