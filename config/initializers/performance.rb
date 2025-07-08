# frozen_string_literal: true

# Performance optimization configuration
Rails.application.configure do
  # Database query optimization
  config.active_record.strict_loading_by_default = true if Rails.env.development?
  
  # Cache configuration
  if Rails.env.production?
    # Use Redis for caching in production
    config.cache_store = :redis_cache_store, {
      url: ENV['REDIS_URL'] || 'redis://localhost:6379/1',
      namespace: 'wordsoftruth_cache',
      expires_in: 1.hour,
      compress: true,
      compression_threshold: 1024
    }
  elsif Rails.env.development?
    # Use memory store in development with size limit
    config.cache_store = :memory_store, {
      size: 64.megabytes,
      expires_in: 5.minutes
    }
  end
  
  # Asset optimization
  if Rails.env.production?
    # Enable asset compression
    config.assets.compress = true
    config.assets.js_compressor = :terser
    config.assets.css_compressor = :sass
    
    # Enable asset digest and caching
    config.assets.digest = true
    config.public_file_server.headers = {
      'Cache-Control' => 'public, max-age=31536000, immutable'
    }
  end
end

# Performance monitoring in development
if Rails.env.development?
  # Track database queries
  ActiveSupport::Notifications.subscribe 'sql.active_record' do |name, start, finish, id, payload|
    duration = ((finish - start) * 1000).round(2)
    
    if duration > 100 # Log slow queries (> 100ms)
      Rails.logger.warn "🐌 Slow Query (#{duration}ms): #{payload[:sql]}"
    end
  end
  
  # Track view rendering
  ActiveSupport::Notifications.subscribe 'render_template.action_view' do |name, start, finish, id, payload|
    duration = ((finish - start) * 1000).round(2)
    
    if duration > 50 # Log slow views (> 50ms)
      Rails.logger.info "🎨 View Render (#{duration}ms): #{payload[:identifier]}"
    end
  end
  
  # Track cache operations
  ActiveSupport::Notifications.subscribe 'cache_read.active_support' do |name, start, finish, id, payload|
    duration = ((finish - start) * 1000).round(2)
    hit = payload[:hit] ? 'HIT' : 'MISS'
    Rails.logger.debug "💾 Cache #{hit} (#{duration}ms): #{payload[:key]}"
  end
end

# Background job performance
if defined?(Sidekiq)
  # Monitor job performance
  Sidekiq.configure_server do |config|
    config.server_middleware do |chain|
      chain.add PerformanceMiddleware if defined?(PerformanceMiddleware)
    end
  end
end

# Memory optimization
if Rails.env.production?
  # Configure garbage collection for better performance
  GC::Profiler.enable
  
  # Ruby performance tuning
  ENV['RUBY_GC_HEAP_INIT_SLOTS'] ||= '600000'
  ENV['RUBY_GC_HEAP_FREE_SLOTS'] ||= '600000'
  ENV['RUBY_GC_HEAP_GROWTH_FACTOR'] ||= '1.25'
  ENV['RUBY_GC_HEAP_GROWTH_MAX_SLOTS'] ||= '300000'
end

# Performance-related middleware
Rails.application.config.middleware.insert_before ActionDispatch::Static, Rack::Deflater if Rails.env.production?

# Content Security Policy optimization
Rails.application.config.content_security_policy do |policy|
  # Allow specific domains for better performance
  policy.font_src :self, 'https://fonts.gstatic.com', 'data:'
  policy.style_src :self, 'https://fonts.googleapis.com', :unsafe_inline
  policy.script_src :self, 'https://cdn.jsdelivr.net'
  
  # Enable report-to for monitoring
  if Rails.env.production?
    policy.report_uri '/csp-violation-report-endpoint/'
  end
end