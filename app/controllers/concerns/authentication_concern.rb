# frozen_string_literal: true

# Authentication concern for session management and route protection
module AuthenticationConcern
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :user_signed_in?, :authenticate_user!
    
    # Security headers for authentication
    before_action :update_last_activity
  end

  private

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  rescue ActiveRecord::RecordNotFound
    session[:user_id] = nil
    nil
  end

  def user_signed_in?
    current_user.present?
  end

  def authenticate_user!
    unless user_signed_in?
      store_location_for_later_redirect
      redirect_to_login_with_message("Please sign in to continue.")
      return false
    end

    unless current_user.active?
      sign_out_user
      redirect_to_login_with_message("Your account has been deactivated.")
      return false
    end

    true
  end

  def authenticate_admin!
    authenticate_user! && verify_admin_access!
  end

  def verify_admin_access!
    unless current_user&.admin?
      Rails.logger.warn "Non-admin user attempted to access admin area: #{current_user&.email}"
      redirect_to root_path, alert: "Access denied."
      return false
    end
    true
  end

  def sign_in_user(user)
    if user && user.active?
      session[:user_id] = user.id
      session[:signed_in_at] = Time.current
      user.update!(last_sign_in_at: Time.current)
      
      Rails.logger.info "User signed in: #{user.email}"
      true
    else
      Rails.logger.warn "Sign in attempt failed for user: #{user&.email}"
      false
    end
  end

  def sign_out_user
    user_email = current_user&.email
    session[:user_id] = nil
    session[:signed_in_at] = nil
    reset_session
    
    Rails.logger.info "User signed out: #{user_email}"
    @current_user = nil
  end

  def require_youtube_auth
    authenticate_user! || return
    
    unless current_user.youtube_authenticated?
      redirect_to auth_google_oauth2_path, alert: "Please connect your YouTube account first."
      return false
    end
    
    if current_user.youtube_token_expired?
      # Attempt to refresh the token
      unless refresh_youtube_token
        redirect_to auth_google_oauth2_path, alert: "Your YouTube authentication has expired. Please reconnect."
        return false
      end
    end
    
    true
  end

  def store_location_for_later_redirect
    if request.get? && !request.xhr? && !request.path.include?('/auth/')
      session[:return_to] = request.fullpath
    end
  end

  def redirect_after_sign_in
    path = session.delete(:return_to) || root_path
    redirect_to path, notice: "Successfully signed in!"
  end

  def redirect_to_login_with_message(message)
    if request.xhr? || request.format.json?
      render json: { error: message, redirect_to: sign_in_path }, status: :unauthorized
    else
      redirect_to sign_in_path, alert: message
    end
  end

  def update_last_activity
    if user_signed_in?
      # Update last activity every 5 minutes to avoid too many database writes
      last_update = session[:last_activity_update]&.to_time
      if last_update.nil? || last_update < 5.minutes.ago
        current_user.update_column(:last_sign_in_at, Time.current)
        session[:last_activity_update] = Time.current.to_s
      end
    end
  end

  def check_session_timeout
    if user_signed_in?
      signed_in_at = session[:signed_in_at]&.to_time
      if signed_in_at && signed_in_at < 24.hours.ago
        sign_out_user
        redirect_to_login_with_message("Your session has expired. Please sign in again.")
        return false
      end
    end
    true
  end

  def refresh_youtube_token
    return false unless current_user.youtube_refresh_token.present?

    begin
      # This would typically use a service to refresh the token
      # For now, we'll just mark it as needing re-authentication
      current_user.update!(
        youtube_access_token: nil,
        youtube_refresh_token: nil,
        youtube_token_expires_at: nil
      )
      false
    rescue => e
      Rails.logger.error "Failed to refresh YouTube token: #{e.message}"
      false
    end
  end

  # Rate limiting for authentication endpoints
  def check_auth_rate_limit
    check_rate_limit("auth", limit: 10, period: 1.hour)
  end

  # Security logging for authentication events
  def log_authentication_event(event_type, details = {})
    Rails.logger.info "Auth Event: #{event_type} - User: #{current_user&.email} - IP: #{request.remote_ip} - Details: #{details}"
  end

  # Check if user should be redirected to setup
  def check_user_setup_required
    if user_signed_in? && current_user.name.blank?
      redirect_to setup_profile_path, notice: "Please complete your profile setup."
      return false
    end
    true
  end

  # Helper for requiring specific permissions
  def require_permission(permission)
    authenticate_user! || return
    
    unless current_user.has_permission?(permission)
      render json: { error: "Insufficient permissions" }, status: :forbidden
      return false
    end
    
    true
  end
end