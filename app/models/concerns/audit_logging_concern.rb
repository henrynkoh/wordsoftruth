# Concern for comprehensive audit logging and compliance tracking
module AuditLoggingConcern
  extend ActiveSupport::Concern
  
  included do
    # Track changes for compliance
    has_paper_trail if defined?(PaperTrail)
    
    # Audit log callbacks
    after_create :log_creation_audit
    after_update :log_update_audit
    after_destroy :log_destruction_audit
    
    # Sensitive operation tracking
    after_update :log_sensitive_changes, if: :sensitive_attributes_changed?
  end

  class_methods do
    def audit_trail_for(record_id, days_back: 90)
      # Get audit trail for a specific record
      versions = if defined?(PaperTrail)
                   PaperTrail::Version.where(
                     item_type: name,
                     item_id: record_id,
                     created_at: days_back.days.ago..Time.current
                   ).order(:created_at)
                 else
                   []
                 end
      
      {
        record_type: name,
        record_id: record_id,
        versions: versions.map(&:serialize_for_audit),
        generated_at: Time.current.iso8601
      }
    end
    
    def compliance_report(start_date, end_date)
      # Generate compliance report for date range
      {
        period: "#{start_date} to #{end_date}",
        total_records: where(created_at: start_date..end_date).count,
        modifications: audit_modifications_count(start_date, end_date),
        data_exports: audit_data_exports(start_date, end_date),
        anonymizations: audit_anonymizations(start_date, end_date),
        deletions: audit_deletions(start_date, end_date),
        generated_at: Time.current.iso8601
      }
    end

    private

    def audit_modifications_count(start_date, end_date)
      return 0 unless defined?(PaperTrail)
      
      PaperTrail::Version.where(
        item_type: name,
        event: 'update',
        created_at: start_date..end_date
      ).count
    end

    def audit_data_exports(start_date, end_date)
      AuditLog.where(
        auditable_type: name,
        action: 'data_export',
        created_at: start_date..end_date
      ).count
    rescue NameError
      0 # AuditLog model doesn't exist yet
    end

    def audit_anonymizations(start_date, end_date)
      where(
        anonymized_at: start_date..end_date
      ).count
    rescue NoMethodError
      0 # anonymized_at field doesn't exist
    end

    def audit_deletions(start_date, end_date)
      return 0 unless defined?(PaperTrail)
      
      PaperTrail::Version.where(
        item_type: name,
        event: 'destroy',
        created_at: start_date..end_date
      ).count
    end
  end

  # Instance methods for audit logging
  def log_sensitive_access(accessor_id, access_type, context = {})
    audit_data = {
      record_type: self.class.name,
      record_id: id,
      accessor_id: accessor_id,
      access_type: access_type,
      context: context,
      timestamp: Time.current.iso8601,
      ip_address: context[:ip_address],
      user_agent: context[:user_agent]
    }
    
    Rails.logger.info "AUDIT: Sensitive data access - #{audit_data.to_json}"
    
    # Store in audit log table if available
    create_audit_log_entry('sensitive_access', audit_data)
  end

  def log_data_export(requester_id, export_type, context = {})
    audit_data = {
      record_type: self.class.name,
      record_id: id,
      requester_id: requester_id,
      export_type: export_type,
      context: context,
      timestamp: Time.current.iso8601
    }
    
    Rails.logger.info "AUDIT: Data export - #{audit_data.to_json}"
    create_audit_log_entry('data_export', audit_data)
  end

  def log_anonymization(requester_id, reason, context = {})
    audit_data = {
      record_type: self.class.name,
      record_id: id,
      requester_id: requester_id,
      reason: reason,
      context: context,
      timestamp: Time.current.iso8601
    }
    
    Rails.logger.info "AUDIT: Data anonymization - #{audit_data.to_json}"
    create_audit_log_entry('anonymization', audit_data)
  end

  private

  def log_creation_audit
    audit_data = {
      action: 'create',
      record_type: self.class.name,
      record_id: id,
      timestamp: Time.current.iso8601,
      changes: attributes
    }
    
    Rails.logger.info "AUDIT: Record creation - #{audit_data.to_json}"
    create_audit_log_entry('create', audit_data)
  end

  def log_update_audit
    return unless saved_changes.any?
    
    # Filter out sensitive attributes from logs
    safe_changes = saved_changes.except(
      'encrypted_email', 
      'encrypted_phone_number', 
      'encrypted_personal_notes',
      'password_digest'
    )
    
    audit_data = {
      action: 'update',
      record_type: self.class.name,
      record_id: id,
      timestamp: Time.current.iso8601,
      changes: safe_changes
    }
    
    Rails.logger.info "AUDIT: Record update - #{audit_data.to_json}"
    create_audit_log_entry('update', audit_data)
  end

  def log_destruction_audit
    audit_data = {
      action: 'destroy',
      record_type: self.class.name,
      record_id: id,
      timestamp: Time.current.iso8601,
      final_attributes: attributes.except(
        'encrypted_email', 
        'encrypted_phone_number', 
        'encrypted_personal_notes'
      )
    }
    
    Rails.logger.info "AUDIT: Record destruction - #{audit_data.to_json}"
    create_audit_log_entry('destroy', audit_data)
  end

  def log_sensitive_changes
    sensitive_changes = saved_changes.select do |attr, _|
      sensitive_attributes.include?(attr.to_s)
    end
    
    return if sensitive_changes.empty?
    
    audit_data = {
      action: 'sensitive_data_change',
      record_type: self.class.name,
      record_id: id,
      timestamp: Time.current.iso8601,
      changed_attributes: sensitive_changes.keys,
      change_count: sensitive_changes.size
    }
    
    Rails.logger.warn "AUDIT: Sensitive data change - #{audit_data.to_json}"
    create_audit_log_entry('sensitive_change', audit_data)
  end

  def sensitive_attributes_changed?
    (saved_changes.keys & sensitive_attributes).any?
  end

  def sensitive_attributes
    # Define which attributes are considered sensitive
    %w[
      email encrypted_email
      phone_number encrypted_phone_number  
      personal_notes encrypted_personal_notes
      password_digest
    ]
  end

  def create_audit_log_entry(action, data)
    # Create audit log entry if AuditLog model exists
    return unless defined?(AuditLog)
    
    AuditLog.create!(
      auditable_type: self.class.name,
      auditable_id: id,
      action: action,
      audit_data: data,
      created_at: Time.current
    )
  rescue => e
    Rails.logger.error "Failed to create audit log entry: #{e.message}"
  end
end