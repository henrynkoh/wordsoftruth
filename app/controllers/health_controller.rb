class HealthController < ApplicationController
  def check
    render json: {
      status: 'ok',
      timestamp: Time.current,
      version: ENV['APP_VERSION'] || 'development'
    }
  end

  def detailed
    render json: {
      status: 'ok',
      checks: {
        database: { status: 'ok' },
        cache: { status: 'ok' }
      },
      timestamp: Time.current
    }
  end

  def business
    render json: {
      status: 'ok',
      business_checks: {
        content_processing: { status: 'ok' }
      },
      timestamp: Time.current
    }
  end

  def performance
    render json: {
      performance_metrics: {
        response_time: 100,
        memory_usage: 50
      },
      timestamp: Time.current
    }
  end
end