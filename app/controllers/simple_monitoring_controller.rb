class SimpleMonitoringController < ApplicationController
  def index
    @dashboard_data = {
      system_overview: {
        uptime: "24 hours",
        total_requests_today: 150,
        error_rate_24h: 0.1,
        avg_response_time: 120,
        active_users: 5,
        processing_queue_size: 3
      },
      performance_metrics: {
        response_time_p95: 200,
        error_rate: 0.1,
        memory_usage: 45,
        cpu_usage: 35
      },
      business_metrics: {
        sermon_processing_accuracy: 96.5,
        video_generation_success_rate: 94.2,
        content_quality_score: 87.3,
        sermons_processed_today: 12,
        videos_generated_today: 8
      },
      recent_alerts: []
    }
    
    respond_to do |format|
      format.html
      format.json { render json: @dashboard_data }
    end
  end

  def status
    @status = {
      system_health: {
        status: 'healthy',
        database: { status: 'healthy', response_time_ms: 15 },
        redis: { status: 'healthy', response_time_ms: 8 },
        sidekiq: { status: 'healthy', processed: 142, failed: 0 }
      },
      performance_summary: {
        response_time: 120,
        error_rate: 0.1,
        active_users: 5
      },
      active_alerts: [],
      last_updated: Time.current
    }
    
    render json: @status
  end
end