# Comprehensive business activity logging concern
module BusinessActivityLogging
  extend ActiveSupport::Concern
  
  included do
    # Activity logging callbacks
    after_create :log_business_activity_creation
    after_update :log_business_activity_update
    after_destroy :log_business_activity_deletion
    
    # Performance tracking
    around_action :track_business_operation_performance, if: :respond_to_around_action?
  end

  class_methods do
    def log_business_metric(metric_name, value, context = {})
      BusinessActivityLog.create!(
        activity_type: 'business_metric',
        entity_type: name,
        entity_id: nil,
        metric_name: metric_name,
        metric_value: value,
        context: context,
        performed_at: Time.current
      )
      
      Rails.logger.info "BUSINESS_METRIC: #{metric_name}=#{value} context=#{context.to_json}"
    end
    
    def business_activity_summary(period = 1.day)
      start_time = period.ago
      
      BusinessActivityLog.where(
        entity_type: name,
        performed_at: start_time..Time.current
      ).group(:activity_type).count
    end
  end

  def log_business_operation(operation_name, context = {})
    start_time = Time.current
    result = nil
    error = nil
    
    begin
      result = yield if block_given?
      
      BusinessActivityLog.create!(
        activity_type: 'business_operation',
        entity_type: self.class.name,
        entity_id: id,
        operation_name: operation_name,
        context: context.merge(
          duration_ms: ((Time.current - start_time) * 1000).round(2),
          status: 'success'
        ),
        performed_at: start_time
      )
      
      Rails.logger.info "BUSINESS_OPERATION: #{operation_name} completed successfully for #{self.class.name}:#{id}"
      result
      
    rescue => e
      error = e
      
      BusinessActivityLog.create!(
        activity_type: 'business_operation',
        entity_type: self.class.name,
        entity_id: id,
        operation_name: operation_name,
        context: context.merge(
          duration_ms: ((Time.current - start_time) * 1000).round(2),
          status: 'error',
          error_message: e.message,
          error_class: e.class.name
        ),
        performed_at: start_time
      )
      
      Rails.logger.error "BUSINESS_OPERATION: #{operation_name} failed for #{self.class.name}:#{id} - #{e.message}"
      raise error
    end
  end

  def log_state_transition(from_state, to_state, context = {})
    BusinessActivityLog.create!(
      activity_type: 'state_transition',
      entity_type: self.class.name,
      entity_id: id,
      context: context.merge(
        from_state: from_state,
        to_state: to_state,
        timestamp: Time.current.iso8601
      ),
      performed_at: Time.current
    )
    
    Rails.logger.info "STATE_TRANSITION: #{self.class.name}:#{id} #{from_state} → #{to_state}"
  end

  def log_user_interaction(user_id, action, context = {})
    BusinessActivityLog.create!(
      activity_type: 'user_interaction',
      entity_type: self.class.name,
      entity_id: id,
      user_id: user_id,
      context: context.merge(
        action: action,
        user_agent: context[:user_agent],
        ip_address: context[:ip_address],
        session_id: context[:session_id]
      ),
      performed_at: Time.current
    )
    
    Rails.logger.info "USER_INTERACTION: User #{user_id} performed #{action} on #{self.class.name}:#{id}"
  end

  def log_data_access(accessor_id, access_type, fields_accessed = [], context = {})
    # Track sensitive data access for compliance
    BusinessActivityLog.create!(
      activity_type: 'data_access',
      entity_type: self.class.name,
      entity_id: id,
      user_id: accessor_id,
      context: context.merge(
        access_type: access_type, # read, write, delete, export
        fields_accessed: fields_accessed,
        sensitive_data: contains_sensitive_data?(fields_accessed),
        compliance_flag: compliance_required?(access_type, fields_accessed)
      ),
      performed_at: Time.current
    )
    
    if contains_sensitive_data?(fields_accessed)
      Rails.logger.warn "SENSITIVE_DATA_ACCESS: User #{accessor_id} accessed sensitive fields #{fields_accessed} on #{self.class.name}:#{id}"
    end
  end

  def log_business_rule_execution(rule_name, rule_result, context = {})
    BusinessActivityLog.create!(
      activity_type: 'business_rule',
      entity_type: self.class.name,
      entity_id: id,
      context: context.merge(
        rule_name: rule_name,
        rule_result: rule_result,
        rule_input: context[:input],
        rule_output: context[:output]
      ),
      performed_at: Time.current
    )
    
    Rails.logger.info "BUSINESS_RULE: #{rule_name} executed on #{self.class.name}:#{id} with result: #{rule_result}"
  end

  def log_integration_event(integration_name, event_type, context = {})
    BusinessActivityLog.create!(
      activity_type: 'integration_event',
      entity_type: self.class.name,
      entity_id: id,
      context: context.merge(
        integration_name: integration_name,
        event_type: event_type, # api_call, webhook, file_transfer, etc.
        external_id: context[:external_id],
        response_status: context[:status],
        response_time_ms: context[:response_time]
      ),
      performed_at: Time.current
    )
    
    Rails.logger.info "INTEGRATION_EVENT: #{integration_name} #{event_type} for #{self.class.name}:#{id}"
  end

  private

  def log_business_activity_creation
    log_business_operation('create', {
      attributes: business_relevant_attributes,
      created_by: current_user_id_for_logging,
      source: activity_source_context
    })
  end

  def log_business_activity_update
    return unless business_relevant_changes?
    
    log_business_operation('update', {
      changes: business_relevant_changes,
      updated_by: current_user_id_for_logging,
      source: activity_source_context
    })
  end

  def log_business_activity_deletion
    log_business_operation('delete', {
      final_attributes: business_relevant_attributes,
      deleted_by: current_user_id_for_logging,
      source: activity_source_context
    })
  end

  def business_relevant_attributes
    # Filter out system attributes, focus on business data
    attributes.except(
      'id', 'created_at', 'updated_at', 
      'encrypted_email', 'encrypted_phone_number'
    )
  end

  def business_relevant_changes
    return {} unless respond_to?(:saved_changes)
    
    saved_changes.except(
      'updated_at', 'encrypted_email', 'encrypted_phone_number'
    ).select { |attr, _| business_critical_field?(attr) }
  end

  def business_relevant_changes?
    business_relevant_changes.any?
  end

  def business_critical_field?(field_name)
    # Define which fields are business-critical for logging
    business_fields = %w[
      title status scripture pastor church denomination
      interpretation action_points audience_count
      video_path youtube_id script processing_started_at
    ]
    
    business_fields.include?(field_name.to_s)
  end

  def contains_sensitive_data?(fields)
    sensitive_fields = %w[email phone_number personal_notes password]
    (fields.map(&:to_s) & sensitive_fields).any?
  end

  def compliance_required?(access_type, fields)
    # Determine if this access requires compliance logging
    sensitive_access = contains_sensitive_data?(fields)
    destructive_operation = %w[delete export anonymize].include?(access_type.to_s)
    
    sensitive_access || destructive_operation
  end

  def current_user_id_for_logging
    # Try to get current user from various contexts
    if defined?(Current) && Current.respond_to?(:user)
      Current.user&.id
    elsif Thread.current[:current_user]
      Thread.current[:current_user]&.id
    else
      'system'
    end
  end

  def activity_source_context
    {
      controller: Thread.current[:current_controller],
      action: Thread.current[:current_action],
      request_id: Thread.current[:request_id],
      session_id: Thread.current[:session_id]
    }.compact
  end

  def track_business_operation_performance
    operation_name = "#{controller_name}##{action_name}" if respond_to?(:controller_name)
    start_time = Time.current
    
    result = yield
    
    duration_ms = ((Time.current - start_time) * 1000).round(2)
    
    # Log performance metrics for business operations
    if duration_ms > 1000 # Log slow operations (>1s)
      Rails.logger.warn "SLOW_BUSINESS_OPERATION: #{operation_name} took #{duration_ms}ms"
      
      BusinessActivityLog.create!(
        activity_type: 'performance_metric',
        entity_type: 'Controller',
        context: {
          operation: operation_name,
          duration_ms: duration_ms,
          performance_flag: 'slow_operation'
        },
        performed_at: start_time
      )
    end
    
    result
  end

  def respond_to_around_action?
    respond_to?(:controller_name) && respond_to?(:action_name)
  end
end