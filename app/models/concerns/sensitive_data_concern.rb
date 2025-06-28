# Concern for handling sensitive data with encryption and anonymization
module SensitiveDataConcern
  extend ActiveSupport::Concern
  
  included do
    # Attribute encryption for sensitive fields
    encrypts :email if respond_to?(:email)
    encrypts :phone_number if respond_to?(:phone_number)
    encrypts :personal_notes if respond_to?(:personal_notes)
    
    # Blind indexing for searchable encrypted fields
    blind_index :email if respond_to?(:email)
    
    # Data retention policies
    scope :expired_personal_data, -> { where('created_at < ?', 7.years.ago) }
    
    # Validation for sensitive data
    validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
    validates :phone_number, format: { with: /\A[\d\-\s\+\(\)]+\z/ }, allow_blank: true
  end

  class_methods do
    # GDPR compliance - anonymize user data
    def anonymize_expired_data
      expired_personal_data.find_each do |record|
        record.anonymize_personal_data!
      end
    end
    
    # Bulk export for data portability
    def export_user_data(user_identifier)
      data = where(email: user_identifier)
              .or(where(phone_number: user_identifier))
              .includes(:videos, :sermons)
      
      {
        personal_data: data.map(&:exportable_attributes),
        generated_at: Time.current.iso8601,
        format_version: '1.0'
      }
    end
  end

  # Instance methods for data handling
  def anonymize_personal_data!
    anonymized_attributes = {
      email: anonymize_email,
      phone_number: anonymize_phone,
      personal_notes: '[ANONYMIZED]',
      anonymized_at: Time.current
    }
    
    update!(anonymized_attributes.compact)
    Rails.logger.info "Anonymized personal data for record #{id}"
  end

  def exportable_attributes
    # Only export non-sensitive or explicitly allowed attributes
    attributes.except(
      'encrypted_email', 
      'encrypted_phone_number',
      'encrypted_personal_notes',
      'password_digest'
    ).merge(
      'email' => email_safe_for_export,
      'phone_number' => phone_number_safe_for_export
    )
  end

  def contains_pii?
    [email, phone_number, personal_notes].any?(&:present?)
  end

  def data_retention_expired?
    created_at < 7.years.ago
  end

  private

  def anonymize_email
    return nil unless email.present?
    
    # Keep domain for analytics while anonymizing user part
    domain = email.split('@').last
    "anonymized_#{SecureRandom.hex(8)}@#{domain}"
  end

  def anonymize_phone
    return nil unless phone_number.present?
    
    # Keep country code and format, anonymize the rest
    if phone_number.match?(/\A\+/)
      country_code = phone_number[0..2]
      "#{country_code}XXXXXXXXX"
    else
      'XXX-XXX-XXXX'
    end
  end

  def email_safe_for_export
    # For data export, provide the actual email if not anonymized
    anonymized_at? ? '[ANONYMIZED]' : email
  end

  def phone_number_safe_for_export
    # For data export, provide the actual phone if not anonymized
    anonymized_at? ? '[ANONYMIZED]' : phone_number
  end
end