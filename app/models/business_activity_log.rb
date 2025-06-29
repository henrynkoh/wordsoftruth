class BusinessActivityLog < ApplicationRecord
  # Serialization for context data
  serialize :context, coder: JSON
  
  # Validations
  validates :activity_type, presence: true
  validates :performed_at, presence: true
  
  # Scopes for querying
  scope :recent, -> { order(performed_at: :desc) }
  scope :for_entity, ->(type, id) { where(entity_type: type, entity_id: id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :for_activity_type, ->(type) { where(activity_type: type) }
  scope :in_time_range, ->(start_time, end_time) { where(performed_at: start_time..end_time) }
  scope :business_operations, -> { where(activity_type: 'business_operation') }
  scope :user_interactions, -> { where(activity_type: 'user_interaction') }
  scope :data_access, -> { where(activity_type: 'data_access') }
  scope :state_transitions, -> { where(activity_type: 'state_transition') }
  scope :business_metrics, -> { where(activity_type: 'business_metric') }
  scope :performance_metrics, -> { where(activity_type: 'performance_metric') }
  scope :integration_events, -> { where(activity_type: 'integration_event') }
  
  # Activity type constants
  ACTIVITY_TYPES = %w[
    business_operation
    user_interaction  
    data_access
    state_transition
    business_metric
    performance_metric
    integration_event
    business_rule
  ].freeze
  
  validates :activity_type, inclusion: { in: ACTIVITY_TYPES }
  
  # Business intelligence and reporting methods
  def self.activity_summary(period = 1.day)
    start_time = period.ago
    
    {
      period: "#{start_time.to_date} to #{Date.current}",
      total_activities: in_time_range(start_time, Time.current).count,
      by_type: in_time_range(start_time, Time.current).group(:activity_type).count,
      by_entity: in_time_range(start_time, Time.current).group(:entity_type).count,
      unique_users: in_time_range(start_time, Time.current).distinct.count(:user_id),
      hourly_distribution: hourly_activity_distribution(start_time, Time.current)
    }
  end
  
  def self.business_performance_metrics(period = 1.day)
    start_time = period.ago
    
    performance_logs = performance_metrics.in_time_range(start_time, Time.current)
    
    {
      slow_operations: performance_logs.where("context LIKE ?", "%slow_operation%").count,
      average_response_time: calculate_average_response_time(performance_logs),
      peak_activity_hour: find_peak_activity_hour(start_time, Time.current),
      error_rate: calculate_error_rate(start_time, Time.current)
    }
  end
  
  def self.compliance_audit_trail(entity_type, entity_id, days_back = 90)
    start_time = days_back.days.ago
    
    activities = for_entity(entity_type, entity_id)
                 .in_time_range(start_time, Time.current)
                 .order(:performed_at)
    
    {
      entity: "#{entity_type}:#{entity_id}",
      audit_period: "#{start_time.to_date} to #{Date.current}",
      total_activities: activities.count,
      data_access_events: activities.data_access.count,
      state_changes: activities.state_transitions.count,
      user_interactions: activities.user_interactions.count,
      sensitive_data_access: count_sensitive_data_access(activities),
      timeline: activities.map(&:compliance_summary)
    }
  end
  
  def self.user_activity_profile(user_id, period = 30.days)
    start_time = period.ago
    user_activities = for_user(user_id).in_time_range(start_time, Time.current)
    
    {
      user_id: user_id,
      period: "#{start_time.to_date} to #{Date.current}",
      total_activities: user_activities.count,
      activity_breakdown: user_activities.group(:activity_type).count,
      entities_accessed: user_activities.group(:entity_type).count,
      daily_activity: daily_activity_pattern(user_activities),
      compliance_flags: identify_compliance_concerns(user_activities)
    }
  end
  
  def self.security_events(period = 7.days)
    start_time = period.ago
    
    suspicious_activities = in_time_range(start_time, Time.current)
                           .where("context LIKE ? OR context LIKE ? OR context LIKE ?", 
                                  "%sensitive_data%", "%error%", "%failed%")
    
    {
      period: "#{start_time.to_date} to #{Date.current}",
      total_security_events: suspicious_activities.count,
      sensitive_data_access: suspicious_activities.data_access.count,
      failed_operations: count_failed_operations(suspicious_activities),
      unusual_patterns: detect_unusual_patterns(start_time, Time.current)
    }
  end
  
  def compliance_summary
    {
      timestamp: performed_at.iso8601,
      activity: activity_type,
      entity: "#{entity_type}:#{entity_id}",
      user: user_id,
      operation: operation_name,
      sensitive_data_involved: sensitive_data_involved?,
      compliance_relevant: compliance_relevant?
    }
  end
  
  def sensitive_data_involved?
    return false unless context.is_a?(Hash)
    
    context['sensitive_data'] == true ||
      context['fields_accessed']&.any? { |field| sensitive_field?(field) }
  end
  
  def compliance_relevant?
    return true if sensitive_data_involved?
    return true if %w[data_access state_transition].include?(activity_type)
    return true if context.is_a?(Hash) && context['compliance_flag'] == true
    
    false
  end
  
  private
  
  def self.hourly_activity_distribution(start_time, end_time)
    in_time_range(start_time, end_time)
      .group("EXTRACT(hour FROM performed_at)")
      .count
      .transform_keys { |hour| "#{hour}:00" }
  end
  
  def self.calculate_average_response_time(performance_logs)
    durations = performance_logs.where("context LIKE ?", "%duration_ms%")
                               .filter_map do |log|
                                 log.context.dig('duration_ms') if log.context.is_a?(Hash)
                               end
    
    durations.any? ? (durations.sum / durations.size).round(2) : 0
  end
  
  def self.find_peak_activity_hour(start_time, end_time)
    hourly_dist = hourly_activity_distribution(start_time, end_time)
    hourly_dist.max_by { |_, count| count }&.first || "N/A"
  end
  
  def self.calculate_error_rate(start_time, end_time)
    total_ops = business_operations.in_time_range(start_time, end_time).count
    error_ops = business_operations.in_time_range(start_time, end_time)
                                  .where("context LIKE ?", "%error%").count
    
    return 0 if total_ops == 0
    ((error_ops.to_f / total_ops) * 100).round(2)
  end
  
  def self.count_sensitive_data_access(activities)
    activities.select(&:sensitive_data_involved?).count
  end
  
  def self.daily_activity_pattern(user_activities)
    user_activities.group("DATE(performed_at)").count
  end
  
  def self.identify_compliance_concerns(user_activities)
    concerns = []
    
    # High volume of sensitive data access
    sensitive_access_count = user_activities.select(&:sensitive_data_involved?).count
    if sensitive_access_count > 50
      concerns << "high_volume_sensitive_access"
    end
    
    # Unusual activity patterns
    daily_counts = daily_activity_pattern(user_activities).values
    if daily_counts.any? { |count| count > daily_counts.sum / daily_counts.size * 3 }
      concerns << "unusual_activity_spike"
    end
    
    concerns
  end
  
  def self.count_failed_operations(activities)
    activities.business_operations
              .where("context LIKE ?", "%status\":\"error%")
              .count
  end
  
  def self.detect_unusual_patterns(start_time, end_time)
    patterns = []
    
    # Detect unusual time patterns
    hourly_dist = hourly_activity_distribution(start_time, end_time)
    night_activity = (0..5).sum { |hour| hourly_dist["#{hour}:00"] || 0 }
    total_activity = hourly_dist.values.sum
    
    if total_activity > 0 && (night_activity.to_f / total_activity) > 0.2
      patterns << "unusual_night_activity"
    end
    
    # Detect bulk operations
    bulk_operations = in_time_range(start_time, end_time)
                     .group(:user_id)
                     .having("COUNT(*) > ?", 1000)
                     .count
    
    if bulk_operations.any?
      patterns << "bulk_operations_detected"
    end
    
    patterns
  end
  
  def sensitive_field?(field_name)
    sensitive_fields = %w[email phone_number personal_notes password encrypted_]
    sensitive_fields.any? { |sf| field_name.to_s.include?(sf) }
  end
end