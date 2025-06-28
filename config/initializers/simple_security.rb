# Simple security configuration for development
if defined?(SecureHeaders)
  SecureHeaders::Configuration.default do |config|
    config.csp = {
      default_src: %w['self'],
      script_src: %w['self' 'unsafe-inline'],
      style_src: %w['self' 'unsafe-inline']
    }
  end
end