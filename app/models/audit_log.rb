class AuditLog < ApplicationRecord
  # Polymorphic association to any auditable model
  belongs_to :auditable, polymorphic: true, optional: true
  
  # JSON serialization for audit data
  serialize :audit_data, coder: JSON
  
  # Validations
  validates :action, presence: true
  validates :auditable_type, presence: true
  
  # Scopes for querying
  scope :recent, -> { order(created_at: :desc) }
  scope :for_model, ->(model_type) { where(auditable_type: model_type) }
  scope :for_action, ->(action) { where(action: action) }
  scope :in_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }
  
  # Index for performance
  # add_index :audit_logs, [:auditable_type, :auditable_id]
  # add_index :audit_logs, :created_at
  # add_index :audit_logs, :action
  
  def self.compliance_summary(days_back: 30)
    end_date = Time.current
    start_date = days_back.days.ago
    
    {
      period: "#{start_date.to_date} to #{end_date.to_date}",
      total_events: in_date_range(start_date, end_date).count,
      events_by_action: in_date_range(start_date, end_date).group(:action).count,
      events_by_model: in_date_range(start_date, end_date).group(:auditable_type).count,
      daily_activity: daily_activity_summary(start_date, end_date)
    }
  end
  
  def self.security_events(days_back: 7)
    security_actions = %w[sensitive_access sensitive_change failed_login data_export]
    
    in_date_range(days_back.days.ago, Time.current)
      .where(action: security_actions)
      .order(created_at: :desc)
  end
  
  private
  
  def self.daily_activity_summary(start_date, end_date)
    in_date_range(start_date, end_date)
      .group("DATE(created_at)")
      .group(:action)
      .count
  end
end
