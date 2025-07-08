# frozen_string_literal: true

# Load custom error classes for the application
require_relative '../../app/errors/application_errors'

# Configure error monitoring in production
if Rails.env.production?
  # Example configuration for external error monitoring
  # Replace with your preferred service (Sentry, Rollbar, etc.)
  
  # Sentry example:
  # Sentry.configure do |config|
  #   config.dsn = ENV['SENTRY_DSN']
  #   config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  #   config.environment = Rails.env
  # end
  
  # Add custom error contexts
  Rails.application.config.after_initialize do
    # Add custom error handling for specific scenarios
    
    # Log all application errors to structured logging
    ActiveSupport::Notifications.subscribe 'application.error' do |name, start, finish, id, payload|
      Rails.logger.error({
        event: 'application_error',
        error_class: payload[:exception_object]&.class&.name,
        error_message: payload[:exception_object]&.message,
        error_id: payload[:error_id],
        user_id: payload[:user_id],
        request_id: payload[:request_id],
        duration: finish - start,
        timestamp: Time.current.iso8601
      }.to_json)
    end
  end
end

# Development and testing configurations
unless Rails.env.production?
  # In development, show detailed error information
  Rails.application.config.consider_all_requests_local = true
  
  # Enable detailed error pages in development
  Rails.application.config.debug_exception_response_format = :default
end

# Configure error handling for background jobs
if defined?(Sidekiq)
  Sidekiq.configure_server do |config|
    config.error_handlers << proc do |exception, context|
      Rails.logger.error({
        event: 'sidekiq_error',
        error_class: exception.class.name,
        error_message: exception.message,
        job_class: context[:job]&.[]('class'),
        job_args: context[:job]&.[]('args'),
        queue: context[:job]&.[]('queue'),
        retry_count: context[:job]&.[]('retry_count'),
        timestamp: Time.current.iso8601
      }.to_json)
    end
  end
end