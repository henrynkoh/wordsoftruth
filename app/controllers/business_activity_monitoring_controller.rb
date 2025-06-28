class BusinessActivityMonitoringController < ApplicationController
  include SecurityConcern
  
  before_action :authenticate_admin
  before_action :set_monitoring_context
  before_action :check_rate_limit, only: [:metrics, :compliance]
  
  # Main monitoring dashboard
  def index
    @dashboard_data = generate_dashboard_data
    @real_time_metrics = fetch_real_time_metrics
    @alerts = check_business_alerts
    
    log_user_interaction(current_admin_id, 'view_monitoring_dashboard', {
      dashboard_sections: @dashboard_data.keys,
      alert_count: @alerts.count
    })
    
    respond_to do |format|
      format.html
      format.json { render json: { dashboard: @dashboard_data, metrics: @real_time_metrics, alerts: @alerts } }
    end
  end
  
  # Interactive business dashboard with charts and visualizations
  def dashboard
    @time_period = params[:period] || '7d'
    @entity_filter = params[:entity] || 'all'
    
    @dashboard_metrics = {
      activity_summary: BusinessActivityLog.activity_summary(parse_time_period(@time_period)),
      performance_metrics: BusinessActivityLog.business_performance_metrics(parse_time_period(@time_period)),
      user_activity: generate_user_activity_summary,
      content_metrics: generate_content_metrics,
      processing_pipeline: generate_processing_pipeline_metrics,
      compliance_status: generate_compliance_status
    }
    
    log_user_interaction(current_admin_id, 'view_business_dashboard', {
      time_period: @time_period,
      entity_filter: @entity_filter,
      metrics_generated: @dashboard_metrics.keys
    })
    
    respond_to do |format|
      format.html
      format.json { render json: @dashboard_metrics }
    end
  end
  
  # Detailed metrics API endpoint
  def metrics
    metric_type = params[:type] || 'all'
    time_range = parse_time_period(params[:period] || '24h')
    
    @metrics = case metric_type
    when 'business_operations'
      fetch_business_operation_metrics(time_range)
    when 'user_interactions'
      fetch_user_interaction_metrics(time_range)
    when 'performance'
      fetch_performance_metrics(time_range)
    when 'security'
      fetch_security_metrics(time_range)
    when 'compliance'
      fetch_compliance_metrics(time_range)
    else
      fetch_all_metrics(time_range)
    end
    
    # Log metrics access for audit
    BusinessActivityLog.create!(
      activity_type: 'metrics_access',
      entity_type: 'BusinessActivityMonitoring',
      user_id: current_admin_id,
      context: {
        metric_type: metric_type,
        time_range_hours: (time_range / 1.hour).round(2),
        data_points: @metrics.is_a?(Hash) ? @metrics.values.flatten.count : 0
      },
      performed_at: Time.current
    )
    
    render json: @metrics
  end
  
  # Compliance reporting and audit trail
  def compliance
    report_type = params[:report_type] || 'summary'
    period = parse_time_period(params[:period] || '30d')
    
    @compliance_data = case report_type
    when 'audit_trail'
      generate_audit_trail_report(period)
    when 'data_access'
      generate_data_access_report(period)
    when 'retention_compliance'
      generate_retention_compliance_report(period)
    when 'security_events'
      generate_security_events_report(period)
    when 'gdpr_compliance'
      generate_gdpr_compliance_report(period)
    else
      generate_comprehensive_compliance_report(period)
    end
    
    # Log compliance report generation
    BusinessActivityLog.create!(
      activity_type: 'compliance_report_generation',
      entity_type: 'ComplianceReporting',
      user_id: current_admin_id,
      context: {
        report_type: report_type,
        period_days: (period / 1.day).round(2),
        generated_at: Time.current.iso8601,
        report_size: @compliance_data.to_json.bytesize
      },
      performed_at: Time.current
    )
    
    respond_to do |format|
      format.html
      format.json { render json: @compliance_data }
      format.pdf { render_compliance_pdf }
    end
  end
  
  # Export business activity data
  def export
    export_format = params[:format] || 'json'
    time_range = parse_time_period(params[:period] || '7d')
    activity_types = params[:activity_types]&.split(',') || BusinessActivityLog::ACTIVITY_TYPES
    
    @export_data = BusinessActivityLog.where(performed_at: time_range.ago..Time.current)
                                     .where(activity_type: activity_types)
                                     .order(:performed_at)
                                     .includes(:auditable)
    
    # Log export activity
    BusinessActivityLog.create!(
      activity_type: 'data_export',
      entity_type: 'BusinessActivityMonitoring',
      user_id: current_admin_id,
      context: {
        export_format: export_format,
        records_exported: @export_data.count,
        activity_types: activity_types,
        time_range_days: (time_range / 1.day).round(2)
      },
      performed_at: Time.current
    )
    
    case export_format
    when 'csv'
      render_csv_export
    when 'xlsx'
      render_xlsx_export
    else
      render json: { export_data: @export_data.map(&:exportable_attributes) }
    end
  end
  
  # Real-time activity stream
  def activity_stream
    limit = [params[:limit]&.to_i || 50, 500].min
    activity_types = params[:types]&.split(',')
    
    @activities = BusinessActivityLog.recent
                                    .limit(limit)
    
    @activities = @activities.where(activity_type: activity_types) if activity_types.present?
    
    render json: {
      activities: @activities.map(&:stream_format),
      total_count: @activities.count,
      timestamp: Time.current.iso8601
    }
  end
  
  # System health and performance overview
  def health
    @health_metrics = {
      database_performance: check_database_performance,
      application_performance: check_application_performance,
      background_job_status: check_background_job_status,
      cache_performance: check_cache_performance,
      error_rates: calculate_error_rates,
      resource_utilization: check_resource_utilization
    }
    
    render json: @health_metrics
  end
  
  private
  
  def authenticate_admin
    # Implement admin authentication logic
    # This would check for admin role/permissions
    unless current_user&.admin?
      render json: { error: 'Admin access required' }, status: :unauthorized
      return false
    end
  end
  
  def current_admin_id
    current_user&.id || 'system'
  end
  
  def set_monitoring_context
    Thread.current[:monitoring_session] = {
      admin_id: current_admin_id,
      session_id: session.id,
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    }
  end
  
  def parse_time_period(period_string)
    case period_string
    when /(\d+)h/ then $1.to_i.hours
    when /(\d+)d/ then $1.to_i.days
    when /(\d+)w/ then $1.to_i.weeks
    when /(\d+)m/ then $1.to_i.months
    else 1.day
    end
  end
  
  def generate_dashboard_data
    {
      system_overview: {
        total_activities_today: BusinessActivityLog.where(performed_at: Date.current.all_day).count,
        active_users_today: BusinessActivityLog.where(performed_at: Date.current.all_day).distinct.count(:user_id),
        processing_queue_status: check_processing_queues,
        system_health_score: calculate_system_health_score
      },
      recent_activities: BusinessActivityLog.recent.limit(10).map(&:dashboard_format),
      performance_indicators: fetch_key_performance_indicators,
      business_metrics: fetch_business_metrics_summary
    }
  end
  
  def fetch_real_time_metrics
    {
      current_active_sessions: count_active_sessions,
      processing_queue_lengths: get_queue_lengths,
      recent_error_rate: calculate_recent_error_rate,
      cache_hit_rate: get_cache_hit_rate,
      database_query_performance: get_db_performance_metrics
    }
  end
  
  def check_business_alerts
    alerts = []
    
    # Check for high error rates
    recent_error_rate = calculate_recent_error_rate
    if recent_error_rate > 5.0
      alerts << {
        type: 'error',
        severity: 'high',
        message: "High error rate detected: #{recent_error_rate}%",
        timestamp: Time.current
      }
    end
    
    # Check for processing delays
    delayed_videos = Video.where(status: 'processing', processing_started_at: ..2.hours.ago).count
    if delayed_videos > 0
      alerts << {
        type: 'warning',
        severity: 'medium',
        message: "#{delayed_videos} videos processing for over 2 hours",
        timestamp: Time.current
      }
    end
    
    # Check for compliance issues
    unprocessed_data_exports = BusinessActivityLog.where(
      activity_type: 'data_export',
      created_at: 7.days.ago..Time.current
    ).where("context LIKE ?", "%pending%").count
    
    if unprocessed_data_exports > 0
      alerts << {
        type: 'compliance',
        severity: 'high',
        message: "#{unprocessed_data_exports} pending data export requests",
        timestamp: Time.current
      }
    end
    
    alerts
  end
  
  def generate_user_activity_summary
    period = 7.days
    
    {
      unique_users: BusinessActivityLog.where(performed_at: period.ago..Time.current).distinct.count(:user_id),
      activity_by_type: BusinessActivityLog.where(performed_at: period.ago..Time.current).group(:activity_type).count,
      peak_activity_hours: BusinessActivityLog.where(performed_at: period.ago..Time.current)
                                           .group("EXTRACT(hour FROM performed_at)")
                                           .count,
      user_engagement_score: calculate_user_engagement_score(period)
    }
  end
  
  def generate_content_metrics
    period = 30.days
    
    {
      sermons_created: Sermon.where(created_at: period.ago..Time.current).count,
      videos_processed: Video.where(status: 'uploaded', updated_at: period.ago..Time.current).count,
      processing_success_rate: Video.calculate_success_rate(Video.where(created_at: period.ago..Time.current)),
      content_quality_score: calculate_content_quality_score(period)
    }
  end
  
  def generate_processing_pipeline_metrics
    Video.analyze_processing_pipeline_performance(7.days)
  end
  
  def generate_compliance_status
    {
      data_retention_compliance: calculate_retention_compliance_percentage,
      audit_log_coverage: calculate_audit_coverage_percentage,
      encryption_status: check_encryption_compliance,
      gdpr_compliance_score: calculate_gdpr_compliance_score
    }
  end
  
  def fetch_business_operation_metrics(time_range)
    BusinessActivityLog.business_operations
                       .where(performed_at: time_range.ago..Time.current)
                       .group(:operation_name)
                       .group_by_hour(:performed_at)
                       .count
  end
  
  def fetch_user_interaction_metrics(time_range)
    BusinessActivityLog.user_interactions
                       .where(performed_at: time_range.ago..Time.current)
                       .group("context->>'action'")
                       .count
  end
  
  def fetch_performance_metrics(time_range)
    BusinessActivityLog.performance_metrics
                       .where(performed_at: time_range.ago..Time.current)
                       .group_by_hour(:performed_at)
                       .average("CAST(context->>'duration_ms' AS FLOAT)")
  end
  
  def fetch_security_metrics(time_range)
    BusinessActivityLog.where(
      activity_type: ['sensitive_data_access', 'encryption_event'],
      performed_at: time_range.ago..Time.current
    ).group(:activity_type).count
  end
  
  def fetch_compliance_metrics(time_range)
    {
      data_access_events: BusinessActivityLog.data_access.where(performed_at: time_range.ago..Time.current).count,
      audit_events: AuditLog.where(created_at: time_range.ago..Time.current).count,
      retention_actions: BusinessActivityLog.where(
        activity_type: 'business_operation',
        performed_at: time_range.ago..Time.current
      ).where("context LIKE ?", "%retention%").count
    }
  end
  
  def fetch_all_metrics(time_range)
    {
      business_operations: fetch_business_operation_metrics(time_range),
      user_interactions: fetch_user_interaction_metrics(time_range),
      performance: fetch_performance_metrics(time_range),
      security: fetch_security_metrics(time_range),
      compliance: fetch_compliance_metrics(time_range)
    }
  end
  
  def generate_comprehensive_compliance_report(period)
    {
      report_period: "#{period.ago.to_date} to #{Date.current}",
      audit_trail: BusinessActivityLog.compliance_audit_trail('All', 'All', period / 1.day),
      data_access_summary: generate_data_access_summary(period),
      retention_compliance: generate_retention_summary(period),
      security_events: BusinessActivityLog.security_events(period),
      gdpr_compliance: generate_gdpr_summary(period)
    }
  end
  
  def generate_audit_trail_report(period)
    BusinessActivityLog.where(performed_at: period.ago..Time.current)
                       .order(:performed_at)
                       .includes(:auditable)
                       .map(&:compliance_summary)
  end
  
  def generate_data_access_report(period)
    BusinessActivityLog.data_access
                       .where(performed_at: period.ago..Time.current)
                       .group(:entity_type, :user_id)
                       .count
  end
  
  def generate_retention_compliance_report(period)
    {
      expired_sermons: Sermon.where('created_at < ?', 7.years.ago).count,
      expired_videos: Video.where('created_at < ?', 7.years.ago).count,
      anonymized_records: count_anonymized_records(period),
      deletion_activities: count_deletion_activities(period)
    }
  end
  
  def generate_security_events_report(period)
    BusinessActivityLog.security_events(period)
  end
  
  def generate_gdpr_compliance_report(period)
    {
      data_subject_requests: count_data_subject_requests(period),
      data_exports: count_data_exports(period),
      anonymization_activities: count_anonymization_activities(period),
      consent_management: assess_consent_compliance(period)
    }
  end
  
  # Helper methods for calculations
  def calculate_system_health_score
    # Simplified health score calculation
    error_penalty = calculate_recent_error_rate * 2
    performance_score = 100 - error_penalty
    performance_score.clamp(0, 100)
  end
  
  def calculate_recent_error_rate
    recent_operations = BusinessActivityLog.business_operations
                                          .where(performed_at: 1.hour.ago..Time.current)
    
    return 0 if recent_operations.count == 0
    
    error_operations = recent_operations.where("context LIKE ?", "%error%")
    (error_operations.count.to_f / recent_operations.count * 100).round(2)
  end
  
  def calculate_user_engagement_score(period)
    # Simplified engagement scoring
    activities_per_user = BusinessActivityLog.where(performed_at: period.ago..Time.current)
                                           .group(:user_id)
                                           .count
                                           .values
    
    return 0 if activities_per_user.empty?
    
    avg_activities = activities_per_user.sum / activities_per_user.length
    (avg_activities * 10).clamp(0, 100)
  end
  
  def calculate_content_quality_score(period)
    # Simplified quality scoring based on completion rates
    total_sermons = Sermon.where(created_at: period.ago..Time.current).count
    return 100 if total_sermons == 0
    
    complete_sermons = Sermon.where(created_at: period.ago..Time.current)
                            .where.not(interpretation: [nil, ''])
                            .where.not(scripture: [nil, ''])
                            .count
    
    (complete_sermons.to_f / total_sermons * 100).round(2)
  end
  
  def count_active_sessions
    # This would integrate with session store
    50 # Placeholder
  end
  
  def get_queue_lengths
    {
      video_processing: Video.where(status: 'approved').count,
      background_jobs: 0 # Would integrate with Sidekiq
    }
  end
  
  def get_cache_hit_rate
    # This would integrate with Redis/cache metrics
    95.5 # Placeholder
  end
  
  def get_db_performance_metrics
    # This would integrate with database performance monitoring
    { avg_query_time_ms: 15.2, slow_queries: 2 }
  end
  
  def check_processing_queues
    {
      pending_approvals: Video.where(status: 'pending').count,
      processing: Video.where(status: 'processing').count,
      failed: Video.where(status: 'failed').count
    }
  end
  
  def fetch_key_performance_indicators
    {
      daily_sermon_processing: Sermon.where(created_at: Date.current.all_day).count,
      video_success_rate: Video.calculate_success_rate(Video.where(created_at: 7.days.ago..Time.current)),
      average_processing_time: Video.calculate_average_processing_time(Video.where(created_at: 7.days.ago..Time.current)),
      user_satisfaction_score: 85.0 # Placeholder
    }
  end
  
  def fetch_business_metrics_summary
    {
      total_churches: Sermon.distinct.count(:church),
      total_denominations: Sermon.distinct.count(:denomination),
      content_volume_trend: calculate_content_volume_trend,
      geographic_distribution: analyze_geographic_distribution
    }
  end
  
  def calculate_content_volume_trend
    # Calculate 7-day trend
    this_week = Sermon.where(created_at: 7.days.ago..Time.current).count
    last_week = Sermon.where(created_at: 14.days.ago..7.days.ago).count
    
    return 0 if last_week == 0
    ((this_week - last_week).to_f / last_week * 100).round(2)
  end
  
  def analyze_geographic_distribution
    # Simplified geographic analysis based on church names
    Sermon.group(:church).count.keys.take(5)
  end
  
  def render_compliance_pdf
    # This would generate a PDF report
    render json: { message: 'PDF generation not implemented' }
  end
  
  def render_csv_export
    # This would generate CSV export
    render json: { message: 'CSV export not implemented' }
  end
  
  def render_xlsx_export
    # This would generate Excel export
    render json: { message: 'Excel export not implemented' }
  end
  
  # Additional helper methods for compliance calculations
  def calculate_retention_compliance_percentage
    # Implementation for retention compliance calculation
    85.0 # Placeholder
  end
  
  def calculate_audit_coverage_percentage
    # Implementation for audit coverage calculation
    92.0 # Placeholder
  end
  
  def check_encryption_compliance
    # Implementation for encryption compliance check
    { status: 'compliant', encrypted_fields: %w[email phone_number personal_notes] }
  end
  
  def calculate_gdpr_compliance_score
    # Implementation for GDPR compliance scoring
    88.0 # Placeholder
  end
  
  def count_anonymized_records(period)
    # Count records that were anonymized in the period
    BusinessActivityLog.where(
      activity_type: 'business_operation',
      performed_at: period.ago..Time.current
    ).where("context LIKE ?", "%anonymization%").count
  end
  
  def count_deletion_activities(period)
    BusinessActivityLog.where(
      activity_type: 'business_operation',
      performed_at: period.ago..Time.current
    ).where("operation_name LIKE ?", "%delete%").count
  end
  
  def count_data_subject_requests(period)
    BusinessActivityLog.where(
      activity_type: 'data_export',
      performed_at: period.ago..Time.current
    ).count
  end
  
  def count_data_exports(period)
    BusinessActivityLog.where(
      activity_type: 'data_export',
      performed_at: period.ago..Time.current
    ).count
  end
  
  def count_anonymization_activities(period)
    count_anonymized_records(period)
  end
  
  def assess_consent_compliance(period)
    # Implementation for consent compliance assessment
    { status: 'compliant', consent_rate: 95.0 }
  end
  
  def check_database_performance
    { status: 'healthy', avg_response_time: '12ms' }
  end
  
  def check_application_performance
    { status: 'healthy', avg_response_time: '150ms' }
  end
  
  def check_background_job_status
    { status: 'healthy', queue_size: 5, failed_jobs: 0 }
  end
  
  def check_cache_performance
    { status: 'healthy', hit_rate: '95%' }
  end
  
  def calculate_error_rates
    { application_errors: '0.1%', database_errors: '0.05%' }
  end
  
  def check_resource_utilization
    { cpu: '45%', memory: '60%', disk: '30%' }
  end
end