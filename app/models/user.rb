# frozen_string_literal: true

class User < ApplicationRecord
  include SensitiveDataConcern
  
  # Validations
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :provider, presence: true, inclusion: { in: %w[google_oauth2] }
  validates :uid, presence: true, uniqueness: { scope: :provider }
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :admin, -> { where(admin: true) }
  
  # Associations
  has_many :text_notes, dependent: :destroy
  has_many :audit_logs, dependent: :destroy
  
  # Callbacks
  before_create :set_defaults
  after_create :log_user_creation
  
  # Class methods
  def self.find_or_create_by_omniauth(auth_hash)
    provider = auth_hash["provider"]
    uid = auth_hash["uid"]
    info = auth_hash["info"]
    
    user = find_by(provider: provider, uid: uid)
    
    if user
      # Update existing user info
      user.update!(
        email: info["email"],
        name: info["name"],
        avatar_url: info["image"],
        last_sign_in_at: Time.current
      )
    else
      # Create new user
      user = create!(
        provider: provider,
        uid: uid,
        email: info["email"],
        name: info["name"],
        avatar_url: info["image"],
        last_sign_in_at: Time.current
      )
    end
    
    user
  end
  
  # Instance methods
  def admin?
    admin
  end
  
  def active?
    active
  end
  
  def display_name
    name.presence || email.split("@").first
  end
  
  def youtube_tokens
    {
      access_token: youtube_access_token,
      refresh_token: youtube_refresh_token,
      expires_at: youtube_token_expires_at
    }
  end
  
  def youtube_authenticated?
    youtube_access_token.present? && youtube_refresh_token.present?
  end
  
  def youtube_token_expired?
    return true if youtube_token_expires_at.blank?
    youtube_token_expires_at < Time.current
  end
  
  def update_youtube_tokens!(access_token, refresh_token, expires_in)
    update!(
      youtube_access_token: access_token,
      youtube_refresh_token: refresh_token,
      youtube_token_expires_at: Time.current + expires_in.seconds
    )
  end
  
  private
  
  def set_defaults
    self.active = true if active.nil?
    self.admin = false if admin.nil?
  end
  
  def log_user_creation
    Rails.logger.info "New user created: #{email} (#{provider})"
  end
end