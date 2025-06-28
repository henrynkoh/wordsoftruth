# Sidekiq queue configuration for optimized performance
Sidekiq.configure_server do |config|
  # Configure multiple queues with different priorities and concurrency
  config.queues = %w[
    critical
    heavy_processing 
    video_processing
    default
    low_priority
  ]
  
  # Configure Redis connection pool for better performance
  config.redis = {
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
    network_timeout: 5,
    pool_timeout: 5,
    size: 25
  }
  
  # Configure job middleware for performance monitoring
  config.server_middleware do |chain|
    chain.add Sidekiq::Middleware::Server::RetryJobs, max_retries: 3
  end
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
    network_timeout: 5,
    pool_timeout: 5,
    size: 5
  }
end

# Configure queue priorities and concurrency limits
Sidekiq.default_job_options = {
  'backtrace' => true,
  'retry' => 3
}

# Performance optimizations
Sidekiq.logger.level = Logger::WARN if Rails.env.production?