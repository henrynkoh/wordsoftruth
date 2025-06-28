# Encryption configuration for sensitive data
Rails.application.configure do
  # Configure ActiveRecord encryption
  config.active_record.encryption.primary_key = Rails.application.credentials.dig(:active_record_encryption, :primary_key) || SecureRandom.alphanumeric(32)
  config.active_record.encryption.deterministic_key = Rails.application.credentials.dig(:active_record_encryption, :deterministic_key) || SecureRandom.alphanumeric(32)
  config.active_record.encryption.key_derivation_salt = Rails.application.credentials.dig(:active_record_encryption, :key_derivation_salt) || SecureRandom.alphanumeric(32)
  
  # Configure encryption settings
  config.active_record.encryption.extend_queries = true
  config.active_record.encryption.encrypt_fixtures = false
  config.active_record.encryption.store_key_references = true
  config.active_record.encryption.add_to_filter_parameters = true
  
  # Support for unencrypted data during migration
  config.active_record.encryption.support_unencrypted_data = !Rails.env.production?
  
  # Hash digest class for deterministic encryption
  config.active_record.encryption.hash_digest_class = OpenSSL::Digest::SHA256
end

# Configure attr_encrypted settings
AttrEncrypted.options[:mode] = :per_attribute_iv_and_salt
AttrEncrypted.options[:algorithm] = 'aes-256-gcm'
AttrEncrypted.options[:insecure_mode] = false
AttrEncrypted.options[:encode] = true

# BlindIndex configuration for searchable encryption
BlindIndex.default_options = {
  algorithm: :pbkdf2_sha256,
  iterations: 10_000,
  key: Rails.application.credentials.dig(:blind_index, :master_key) || SecureRandom.hex(32)
}

# Encryption utility class
class EncryptionHelper
  # Field-level encryption for sensitive data
  SENSITIVE_FIELDS = %w[
    email
    phone_number
    personal_notes
    contact_information
    private_comments
    api_keys
    tokens
  ].freeze
  
  # Business data that requires encryption at rest
  BUSINESS_SENSITIVE_FIELDS = %w[
    internal_notes
    moderation_notes
    processing_logs
    error_details
    admin_comments
  ].freeze
  
  def self.sensitive_field?(field_name)
    SENSITIVE_FIELDS.include?(field_name.to_s) || 
      BUSINESS_SENSITIVE_FIELDS.include?(field_name.to_s)
  end
  
  def self.encrypt_business_data(data, context = {})
    return data unless data.is_a?(String) && data.present?
    
    # Use Rails credentials for encryption key
    cipher = OpenSSL::Cipher.new('aes-256-gcm')
    cipher.encrypt
    
    key = encryption_key_for_context(context)
    iv = cipher.random_iv
    
    cipher.key = key
    cipher.iv = iv
    
    encrypted = cipher.update(data) + cipher.final
    auth_tag = cipher.auth_tag
    
    # Encode for storage
    Base64.strict_encode64(iv + auth_tag + encrypted)
  end
  
  def self.decrypt_business_data(encrypted_data, context = {})
    return encrypted_data unless encrypted_data.is_a?(String) && encrypted_data.present?
    
    begin
      decoded = Base64.strict_decode64(encrypted_data)
      
      # Extract components
      iv = decoded[0, 12]
      auth_tag = decoded[12, 16]
      encrypted = decoded[28..-1]
      
      # Decrypt
      decipher = OpenSSL::Cipher.new('aes-256-gcm')
      decipher.decrypt
      
      key = encryption_key_for_context(context)
      decipher.key = key
      decipher.iv = iv
      decipher.auth_tag = auth_tag
      
      decipher.update(encrypted) + decipher.final
    rescue => e
      Rails.logger.error "Decryption failed: #{e.message}"
      "[ENCRYPTED_DATA_ERROR]"
    end
  end
  
  def self.create_secure_token(length = 32)
    SecureRandom.urlsafe_base64(length)
  end
  
  def self.hash_sensitive_identifier(identifier)
    # Create a deterministic hash for sensitive identifiers
    salt = Rails.application.credentials.dig(:encryption, :identifier_salt) || 'default_salt'
    Digest::SHA256.hexdigest("#{salt}:#{identifier}")
  end
  
  private
  
  def self.encryption_key_for_context(context = {})
    # Generate context-specific encryption key
    base_key = Rails.application.credentials.secret_key_base
    context_string = context.sort.to_h.to_json
    
    # Derive key using PBKDF2
    OpenSSL::PKCS5.pbkdf2_hmac_sha256(
      base_key + context_string,
      'wordsoftruth_encryption_salt',
      10_000,
      32
    )
  end
end

# Encryption audit logging
module EncryptionAuditing
  def self.log_encryption_event(operation, field_name, context = {})
    Rails.logger.info "ENCRYPTION_EVENT: #{operation} for field #{field_name}", context
    
    # Create audit log entry
    BusinessActivityLog.create!(
      activity_type: 'encryption_event',
      entity_type: context[:entity_type],
      entity_id: context[:entity_id],
      context: {
        operation: operation,
        field_name: field_name,
        encryption_algorithm: 'aes-256-gcm',
        timestamp: Time.current.iso8601
      }.merge(context),
      performed_at: Time.current
    )
  rescue => e
    Rails.logger.error "Failed to log encryption event: #{e.message}"
  end
  
  def self.log_decryption_access(field_name, accessor_id, context = {})
    Rails.logger.warn "DECRYPTION_ACCESS: Field #{field_name} accessed by #{accessor_id}"
    
    BusinessActivityLog.create!(
      activity_type: 'sensitive_data_access',
      entity_type: context[:entity_type],
      entity_id: context[:entity_id],
      user_id: accessor_id,
      context: {
        field_name: field_name,
        access_type: 'decrypt',
        compliance_relevant: true,
        timestamp: Time.current.iso8601
      }.merge(context),
      performed_at: Time.current
    )
  rescue => e
    Rails.logger.error "Failed to log decryption access: #{e.message}"
  end
end

# Encrypt sensitive fields in models
Rails.application.config.to_prepare do
  # Automatically add encryption to models with sensitive fields
  ActiveRecord::Base.descendants.each do |model|
    next unless model.table_exists?
    
    model.columns.each do |column|
      next unless EncryptionHelper.sensitive_field?(column.name)
      next if column.name.start_with?('encrypted_')
      
      # Add encryption if not already present
      unless model.encrypted_attributes.key?(column.name.to_sym)
        begin
          # Add attr_encrypted to the model
          model.attr_encrypted column.name.to_sym,
                              key: :encryption_key,
                              algorithm: 'aes-256-gcm',
                              mode: :per_attribute_iv_and_salt,
                              encode: true
          
          # Add blind index for searchable fields
          if %w[email phone_number].include?(column.name)
            model.blind_index column.name.to_sym,
                             key: BlindIndex.default_options[:key],
                             algorithm: :pbkdf2_sha256
          end
          
          # Add encryption key method if not present
          unless model.method_defined?(:encryption_key)
            model.define_method(:encryption_key) do
              Rails.application.credentials.secret_key_base[0, 32]
            end
          end
          
          Rails.logger.info "Added encryption to #{model.name}##{column.name}"
        rescue => e
          Rails.logger.warn "Could not add encryption to #{model.name}##{column.name}: #{e.message}"
        end
      end
    end
  end
end