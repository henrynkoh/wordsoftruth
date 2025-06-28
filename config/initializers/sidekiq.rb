require 'sidekiq'
require 'sidekiq-scheduler'

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }

  # Load scheduler configuration
  if File.exist?(schedule_file = "config/schedule.yml")
    Sidekiq::Scheduler.enabled = true
    Sidekiq::Scheduler.dynamic = true
    Sidekiq.schedule = YAML.load_file(schedule_file)
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end 