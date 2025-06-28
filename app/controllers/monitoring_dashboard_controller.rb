# System Health and Performance Dashboard Controller
class MonitoringDashboardController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_time_range, only: [:index, :performance, :business_metrics]
  
  # Main monitoring dashboard
  def index
    @dashboard_data = {
      system_overview: gather_system_overview,
      performance_metrics: gather_performance_metrics,
      business_metrics: gather_business_metrics,
      recent_alerts: gather_recent_alerts,
      real_time_status: gather_real_time_status
    }
    
    respond_to do |format|
      format.html
      format.json { render json: @dashboard_data }
    end
  end
  
  # Performance monitoring dashboard
  def performance
    @performance_data = {
      response_times: get_response_time_chart_data,
      error_rates: get_error_rate_chart_data,
      throughput: get_throughput_chart_data,
      resource_usage: get_resource_usage_chart_data,
      database_performance: get_database_performance_data,
      cache_performance: get_cache_performance_data
    }
    
    respond_to do |format|
      format.html
      format.json { render json: @performance_data }
    end
  end
  
  # Business accuracy dashboard
  def business_metrics
    @business_data = {
      content_extraction: get_content_extraction_metrics,
      theological_validation: get_theological_validation_metrics,
      video_generation: get_video_generation_metrics,
      content_quality: get_content_quality_metrics,
      user_satisfaction: get_user_satisfaction_metrics,
      business_kpis: get_business_kpis
    }
    
    respond_to do |format|
      format.html
      format.json { render json: @business_data }
    end
  end
  
  # Real-time system status
  def status
    @status = {
      system_health: SystemHealthChecker.check_all,
      business_health: BusinessHealthChecker.check_all,
      active_alerts: Alert.active.limit(10),
      performance_summary: get_performance_summary,
      last_updated: Time.current
    }
    
    render json: @status
  end
  
  # Alerts management
  def alerts
    @alerts = Alert.includes(:alert_type)
                  .order(triggered_at: :desc)
                  .page(params[:page])
                  .per(25)
    
    @alert_summary = {
      total_active: Alert.active.count,
      critical_count: Alert.active.critical.count,
      high_count: Alert.active.high.count,
      resolved_today: Alert.resolved.where(resolved_at: Date.current.all_day).count
    }
    
    respond_to do |format|
      format.html
      format.json { render json: { alerts: @alerts, summary: @alert_summary } }
    end
  end
  
  # Export monitoring data
  def export
    export_format = params[:format] || 'json'
    export_type = params[:type] || 'performance'
    
    case export_type
    when 'performance'
      data = export_performance_data
    when 'business'
      data = export_business_data
    when 'alerts'
      data = export_alerts_data
    else
      data = export_all_data
    end
    
    case export_format
    when 'csv'
      send_data generate_csv(data), filename: "monitoring_export_#{Date.current}.csv"
    when 'xlsx'
      send_data generate_xlsx(data), filename: "monitoring_export_#{Date.current}.xlsx"
    else
      render json: data
    end
  end
  
  private
  
  def set_time_range
    @time_range = case params[:range]
                  when '1h' then 1.hour
                  when '6h' then 6.hours
                  when '24h' then 24.hours
                  when '7d' then 7.days
                  when '30d' then 30.days
                  else 24.hours
                  end
  end
  
  def gather_system_overview
    {
      uptime: get_system_uptime,
      total_requests_today: get_total_requests(Date.current.all_day),
      error_rate_24h: calculate_error_rate(24.hours),
      avg_response_time: calculate_avg_response_time(1.hour),
      active_users: get_active_users_count,
      processing_queue_size: get_processing_queue_size,
      system_load: get_system_load,
      deployment_info: get_deployment_info
    }
  end
  
  def gather_performance_metrics
    {
      response_time_p50: get_percentile_response_time(0.5, @time_range),
      response_time_p95: get_percentile_response_time(0.95, @time_range),
      response_time_p99: get_percentile_response_time(0.99, @time_range),
      error_rate: calculate_error_rate(@time_range),
      throughput: calculate_throughput(@time_range),
      memory_usage: get_memory_usage_percent,
      cpu_usage: get_cpu_usage_percent,
      disk_usage: get_disk_usage_percent
    }
  end
  
  def gather_business_metrics
    {
      sermon_processing_accuracy: calculate_sermon_processing_accuracy(@time_range),
      video_generation_success_rate: calculate_video_generation_success_rate(@time_range),
      content_quality_score: calculate_content_quality_score(@time_range),
      theological_validation_accuracy: calculate_theological_validation_accuracy(@time_range),
      user_satisfaction_score: calculate_user_satisfaction_score(@time_range),
      sermons_processed_today: Sermon.where(created_at: Date.current.all_day).count,
      videos_generated_today: Video.where(status: 'uploaded', updated_at: Date.current.all_day).count
    }
  end
  
  def gather_recent_alerts
    Alert.order(triggered_at: :desc)
         .limit(10)
         .map do |alert|
      {
        id: alert.id,
        type: alert.alert_type,
        severity: alert.severity,
        message: alert.message,
        triggered_at: alert.triggered_at,
        status: alert.status
      }
    end
  end
  
  def gather_real_time_status
    {
      database_status: check_database_status,
      redis_status: check_redis_status,
      sidekiq_status: check_sidekiq_status,
      external_services_status: check_external_services_status,
      last_deployment: get_last_deployment_info,
      current_version: ENV['APP_VERSION'] || 'unknown'
    }
  end
  
  def get_response_time_chart_data
    # Generate time series data for response times
    end_time = Time.current
    start_time = end_time - @time_range
    
    intervals = generate_time_intervals(start_time, end_time, interval_size(@time_range))
    
    intervals.map do |interval_start|
      interval_end = interval_start + interval_size(@time_range)
      avg_response_time = calculate_avg_response_time_for_period(interval_start, interval_end)
      
      {
        timestamp: interval_start.to_i * 1000, # JavaScript timestamp
        value: avg_response_time || 0
      }
    end
  end
  
  def get_error_rate_chart_data
    end_time = Time.current
    start_time = end_time - @time_range
    
    intervals = generate_time_intervals(start_time, end_time, interval_size(@time_range))
    
    intervals.map do |interval_start|
      interval_end = interval_start + interval_size(@time_range)
      error_rate = calculate_error_rate_for_period(interval_start, interval_end)
      
      {
        timestamp: interval_start.to_i * 1000,
        value: (error_rate * 100).round(2) # Convert to percentage
      }
    end
  end
  
  def get_throughput_chart_data
    end_time = Time.current
    start_time = end_time - @time_range
    
    intervals = generate_time_intervals(start_time, end_time, interval_size(@time_range))
    
    intervals.map do |interval_start|
      interval_end = interval_start + interval_size(@time_range)
      request_count = get_request_count_for_period(interval_start, interval_end)
      throughput = request_count / (interval_size(@time_range) / 1.minute)
      
      {
        timestamp: interval_start.to_i * 1000,
        value: throughput.round(2)
      }
    end
  end
  
  def get_content_extraction_metrics
    {
      total_extractions: Sermon.where(created_at: @time_range.ago..Time.current).count,
      successful_extractions: successful_sermon_extractions(@time_range),
      failed_extractions: failed_sermon_extractions(@time_range),
      accuracy_rate: calculate_extraction_accuracy_rate(@time_range),
      avg_processing_time: calculate_avg_extraction_time(@time_range),
      accuracy_trend: get_extraction_accuracy_trend(@time_range)
    }
  end
  
  def get_theological_validation_metrics
    validations = BusinessActivityLog.where(
      activity_type: 'theological_validation',
      performed_at: @time_range.ago..Time.current
    )
    
    total_validations = validations.count
    passed_validations = validations.where("context->>'result' = 'passed'").count
    
    {
      total_validations: total_validations,
      passed_validations: passed_validations,
      failed_validations: total_validations - passed_validations,
      accuracy_rate: total_validations > 0 ? (passed_validations.to_f / total_validations * 100).round(2) : 0,
      common_failure_reasons: get_common_validation_failures(@time_range)
    }
  end
  
  def get_video_generation_metrics
    videos = Video.where(created_at: @time_range.ago..Time.current)
    
    {
      total_videos: videos.count,
      successful_generations: videos.where(status: 'uploaded').count,
      failed_generations: videos.where(status: 'failed').count,
      processing_videos: videos.where(status: 'processing').count,
      success_rate: videos.count > 0 ? (videos.where(status: 'uploaded').count.to_f / videos.count * 100).round(2) : 0,
      avg_processing_time: calculate_avg_video_processing_time(@time_range),
      processing_time_trend: get_video_processing_trend(@time_range)
    }
  end
  
  def get_business_kpis
    {
      daily_active_users: get_daily_active_users,
      weekly_active_users: get_weekly_active_users,
      monthly_active_users: get_monthly_active_users,
      user_retention_rate: calculate_user_retention_rate,
      content_completion_rate: calculate_content_completion_rate,
      customer_satisfaction_score: get_customer_satisfaction_score,
      revenue_impact_metrics: get_revenue_impact_metrics
    }
  end
  
  def check_database_status
    start_time = Time.current
    ActiveRecord::Base.connection.execute('SELECT 1')
    response_time = ((Time.current - start_time) * 1000).round(2)
    
    {
      status: 'healthy',
      response_time_ms: response_time,
      connection_pool: ActiveRecord::Base.connection_pool.stat
    }
  rescue => e
    {
      status: 'unhealthy',
      error: e.message,
      last_check: Time.current
    }
  end
  
  def check_redis_status
    start_time = Time.current
    Redis.current.ping
    response_time = ((Time.current - start_time) * 1000).round(2)
    
    {
      status: 'healthy',
      response_time_ms: response_time,
      info: Redis.current.info('memory')
    }
  rescue => e
    {
      status: 'unhealthy',
      error: e.message,
      last_check: Time.current
    }
  end
  
  def check_sidekiq_status
    stats = Sidekiq::Stats.new
    
    {
      status: stats.failed > 100 ? 'degraded' : 'healthy',
      processed: stats.processed,
      failed: stats.failed,
      busy: stats.workers_size,
      enqueued: stats.enqueued,
      queues: Sidekiq::Queue.all.map { |q| { name: q.name, size: q.size } }
    }
  rescue => e
    {
      status: 'unhealthy',
      error: e.message,
      last_check: Time.current
    }
  end
  
  def interval_size(time_range)
    case time_range
    when 0..1.hour then 1.minute
    when 1.hour..6.hours then 5.minutes
    when 6.hours..24.hours then 15.minutes
    when 24.hours..7.days then 1.hour
    else 1.day
    end
  end
  
  def generate_time_intervals(start_time, end_time, interval)
    intervals = []
    current_time = start_time
    
    while current_time < end_time
      intervals << current_time
      current_time += interval
    end
    
    intervals
  end
  
  def authenticate_admin!
    # Implement admin authentication
    redirect_to root_path unless current_user&.admin?
  end
  
  # Helper methods for calculating various metrics
  def calculate_error_rate(time_range)
    total_requests = get_total_requests(time_range.ago..Time.current)
    return 0 if total_requests == 0
    
    error_requests = get_error_requests(time_range.ago..Time.current)
    (error_requests.to_f / total_requests * 100).round(2)
  end
  
  def calculate_avg_response_time(time_range)
    # Implementation depends on how you store response time logs
    # This is a placeholder implementation
    response_times = get_response_times(time_range.ago..Time.current)
    return 0 if response_times.empty?
    
    response_times.sum / response_times.length
  end
  
  def get_performance_summary
    {
      status: determine_overall_performance_status,
      response_time: calculate_avg_response_time(5.minutes),
      error_rate: calculate_error_rate(5.minutes),
      throughput: calculate_throughput(5.minutes),
      alerts_count: Alert.active.count
    }
  end
  
  def determine_overall_performance_status
    error_rate = calculate_error_rate(5.minutes)
    avg_response_time = calculate_avg_response_time(5.minutes)
    
    if error_rate > 5 || avg_response_time > 2000
      'critical'
    elsif error_rate > 2 || avg_response_time > 1000
      'warning'
    else
      'healthy'
    end
  end
end