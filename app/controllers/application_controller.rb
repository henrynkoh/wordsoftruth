# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include SecurityConcern
  
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  # Security configurations
  protect_from_forgery with: :exception, prepend: true
  
  # Global error handling
  rescue_from StandardError, with: :handle_standard_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
  
  private
  
  def handle_standard_error(exception)
    Rails.logger.error "Application Error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")
    
    if Rails.env.production?
      render file: 'public/500.html', status: :internal_server_error, layout: false
    else
      raise exception
    end
  end
  
  def handle_not_found
    render file: 'public/404.html', status: :not_found, layout: false
  end
  
  def handle_parameter_missing(exception)
    render json: { error: "Missing parameter: #{exception.param}" }, status: :bad_request
  end
end
