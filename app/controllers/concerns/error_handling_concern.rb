# frozen_string_literal: true

# Comprehensive error handling and user feedback concern
module ErrorHandlingConcern
  extend ActiveSupport::Concern

  included do
    # Enhanced error handling with user-friendly Korean messages
    rescue_from StandardError, with: :handle_standard_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
    rescue_from ActionController::InvalidAuthenticityToken, with: :handle_csrf_error
    rescue_from ActionController::UnpermittedParameters, with: :handle_unpermitted_parameters
    rescue_from Timeout::Error, with: :handle_timeout_error
    rescue_from JSON::ParserError, with: :handle_json_parse_error
    rescue_from ArgumentError, with: :handle_argument_error
    
    # Application-specific errors
    rescue_from YouTubeUploadError, with: :handle_youtube_error if defined?(YouTubeUploadError)
    rescue_from VideoGenerationError, with: :handle_video_generation_error if defined?(VideoGenerationError)
    rescue_from AuthenticationError, with: :handle_authentication_error if defined?(AuthenticationError)
  end

  private

  def handle_standard_error(exception)
    error_id = generate_error_id
    log_error(exception, error_id, "standard_error")
    
    error_message = if Rails.env.production?
      "죄송합니다. 시스템 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
    else
      "개발 오류: #{exception.message}"
    end

    respond_to do |format|
      format.html do
        if request.xhr?
          render_error_response(error_message, :internal_server_error, error_id)
        else
          flash.now[:error] = error_message
          flash.now[:error_id] = error_id
          render_error_page(500, error_message, error_id)
        end
      end
      
      format.json do
        render_error_response(error_message, :internal_server_error, error_id)
      end
      
      format.all do
        render_error_page(500, error_message, error_id)
      end
    end
  end

  def handle_record_not_found(exception)
    error_id = generate_error_id
    log_error(exception, error_id, "record_not_found")
    
    resource_name = extract_resource_name(exception)
    error_message = "요청하신 #{resource_name}을(를) 찾을 수 없습니다."

    respond_to do |format|
      format.html do
        if request.xhr?
          render_error_response(error_message, :not_found, error_id)
        else
          flash[:alert] = error_message
          redirect_back(fallback_location: root_path) and return
        end
      end
      
      format.json do
        render_error_response(error_message, :not_found, error_id)
      end
      
      format.all do
        render_error_page(404, error_message, error_id)
      end
    end
    return
  end

  def handle_record_invalid(exception)
    error_id = generate_error_id
    log_error(exception, error_id, "record_invalid")
    
    record = exception.record
    errors = format_validation_errors(record.errors)
    
    respond_to do |format|
      format.html do
        if request.xhr?
          render json: {
            success: false,
            error: "입력 데이터에 오류가 있습니다",
            errors: errors,
            error_id: error_id
          }, status: :unprocessable_entity
        else
          flash.now[:error] = "입력하신 정보를 확인해주세요."
          flash.now[:validation_errors] = errors
          render_previous_action_or_redirect
        end
      end
      
      format.json do
        render json: {
          success: false,
          error: "입력 데이터에 오류가 있습니다",
          errors: errors,
          error_id: error_id
        }, status: :unprocessable_entity
      end
    end
  end

  def handle_parameter_missing(exception)
    error_id = generate_error_id
    log_error(exception, error_id, "parameter_missing")
    
    param_name = korean_parameter_name(exception.param)
    error_message = "필수 항목이 누락되었습니다: #{param_name}"

    respond_to do |format|
      format.html do
        flash[:alert] = error_message
        redirect_back(fallback_location: root_path) and return
      end
      
      format.json do
        render_error_response(error_message, :bad_request, error_id)
      end
    end
    return
  end

  def handle_csrf_error(exception)
    error_id = generate_error_id
    log_error(exception, error_id, "csrf_error")
    
    error_message = "보안 토큰이 만료되었습니다. 페이지를 새로고침하고 다시 시도해주세요."

    respond_to do |format|
      format.html do
        flash[:alert] = error_message
        redirect_to request.referer || root_path and return
      end
      
      format.json do
        render_error_response(error_message, :unprocessable_entity, error_id)
      end
    end
    return
  end

  def handle_unpermitted_parameters(exception)
    error_id = generate_error_id
    log_error(exception, error_id, "unpermitted_parameters")
    
    # In production, silently ignore unpermitted parameters
    # In development, show detailed error
    if Rails.env.development?
      error_message = "허용되지 않은 파라미터: #{exception.params.join(', ')}"
      flash[:warning] = error_message
    end
    
    # Continue with normal flow in production
    return if Rails.env.production?
    
    respond_to do |format|
      format.html { redirect_back(fallback_location: root_path) and return }
      format.json { render_error_response(error_message, :bad_request, error_id) }
    end
    return
  end

  def handle_timeout_error(exception)
    error_id = generate_error_id
    log_error(exception, error_id, "timeout_error")
    
    error_message = "요청 처리 시간이 초과되었습니다. 잠시 후 다시 시도해주세요."

    respond_to do |format|
      format.html do
        if request.xhr?
          render_error_response(error_message, :request_timeout, error_id)
        else
          flash[:alert] = error_message
          redirect_back(fallback_location: root_path) and return
        end
      end
      
      format.json do
        render_error_response(error_message, :request_timeout, error_id)
      end
    end
    return
  end

  def handle_json_parse_error(exception)
    error_id = generate_error_id
    log_error(exception, error_id, "json_parse_error")
    
    error_message = "잘못된 데이터 형식입니다. 올바른 형식으로 다시 시도해주세요."

    respond_to do |format|
      format.html do
        flash[:alert] = error_message
        redirect_back(fallback_location: root_path) and return
      end
      
      format.json do
        render_error_response(error_message, :bad_request, error_id)
      end
    end
  end

  def handle_argument_error(exception)
    error_id = generate_error_id
    log_error(exception, error_id, "argument_error")
    
    error_message = "잘못된 입력값입니다. 입력 내용을 확인하고 다시 시도해주세요."

    respond_to do |format|
      format.html do
        flash[:alert] = error_message
        redirect_back(fallback_location: root_path)
      end
      
      format.json do
        render_error_response(error_message, :bad_request, error_id)
      end
    end
  end

  def handle_youtube_error(exception)
    error_id = generate_error_id
    log_error(exception, error_id, "youtube_error")
    
    error_message = case exception.message
    when /quota/i
      "YouTube 업로드 할당량이 초과되었습니다. 내일 다시 시도해주세요."
    when /authentication/i
      "YouTube 인증이 만료되었습니다. 다시 로그인해주세요."
    when /upload/i
      "YouTube 업로드 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
    else
      "YouTube 서비스 연동 중 오류가 발생했습니다."
    end

    respond_to do |format|
      format.html do
        flash[:alert] = error_message
        redirect_back(fallback_location: root_path)
      end
      
      format.json do
        render_error_response(error_message, :service_unavailable, error_id)
      end
    end
  end

  def handle_video_generation_error(exception)
    error_id = generate_error_id
    log_error(exception, error_id, "video_generation_error")
    
    error_message = case exception.message
    when /timeout/i
      "영상 생성 시간이 초과되었습니다. 텍스트를 줄이거나 나중에 다시 시도해주세요."
    when /memory/i
      "시스템 리소스가 부족합니다. 잠시 후 다시 시도해주세요."
    when /format/i
      "지원하지 않는 형식입니다. 텍스트 내용을 확인해주세요."
    else
      "영상 생성 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
    end

    respond_to do |format|
      format.html do
        flash[:alert] = error_message
        redirect_back(fallback_location: root_path)
      end
      
      format.json do
        render_error_response(error_message, :unprocessable_entity, error_id)
      end
    end
  end

  def handle_authentication_error(exception)
    error_id = generate_error_id
    log_error(exception, error_id, "authentication_error")
    
    error_message = "인증이 필요합니다. 다시 로그인해주세요."

    respond_to do |format|
      format.html do
        session[:return_to] = request.fullpath
        flash[:alert] = error_message
        redirect_to sign_in_path
      end
      
      format.json do
        render_error_response(error_message, :unauthorized, error_id, {
          redirect_to: sign_in_path
        })
      end
    end
  end

  # Helper methods
  def render_error_response(message, status, error_id, additional_data = {})
    render json: {
      success: false,
      error: message,
      error_id: error_id,
      timestamp: Time.current.iso8601,
      status: Rack::Utils::SYMBOL_TO_STATUS_CODE[status]
    }.merge(additional_data), status: status
  end

  def render_error_page(status_code, message, error_id)
    @error_message = message
    @error_id = error_id
    @status_code = status_code
    
    render template: "errors/generic", 
           status: status_code, 
           layout: "application"
  rescue ActionView::MissingTemplate
    render file: "public/#{status_code}.html", 
           status: status_code, 
           layout: false
  end

  def render_previous_action_or_redirect
    # Try to render the previous action (e.g., 'new' for failed 'create')
    action_name = case action_name
    when 'create' then 'new'
    when 'update' then 'edit'
    else 'index'
    end
    
    render action_name, status: :unprocessable_entity
  rescue ActionView::MissingTemplate
    redirect_back(fallback_location: root_path)
  end

  def generate_error_id
    "ERR-#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.hex(4).upcase}"
  end

  def log_error(exception, error_id, error_type)
    Rails.logger.error <<~LOG
      [#{error_id}] #{error_type.upcase} Error:
      Message: #{exception.message}
      Class: #{exception.class}
      User: #{current_user&.email || 'anonymous'}
      IP: #{request.remote_ip}
      User Agent: #{request.user_agent}
      URL: #{request.fullpath}
      Params: #{params.except(:password, :password_confirmation).inspect}
      Backtrace:
      #{exception.backtrace&.first(10)&.join("\n")}
    LOG

    # Log to external service in production
    if Rails.env.production?
      # Example: Sentry, Rollbar, etc.
      # ExternalLogger.error(exception, {
      #   error_id: error_id,
      #   user_id: current_user&.id,
      #   request_data: request_metadata
      # })
    end
  end

  def extract_resource_name(exception)
    # Extract model name from exception message
    model_name = exception.message.match(/Couldn't find (\w+)/i)&.captures&.first
    return "리소스" unless model_name
    
    korean_model_names = {
      'User' => '사용자',
      'TextNote' => '텍스트 노트',
      'Video' => '영상',
      'Sermon' => '설교',
      'Batch' => '배치 작업'
    }
    
    korean_model_names[model_name] || model_name
  end

  def korean_parameter_name(param)
    korean_params = {
      'content' => '내용',
      'title' => '제목',
      'email' => '이메일',
      'name' => '이름',
      'theme' => '테마',
      'note_type' => '노트 유형',
      'url' => 'URL',
      'urls' => 'URL 목록'
    }
    
    korean_params[param.to_s] || param.to_s
  end

  def format_validation_errors(errors)
    errors.full_messages.map do |message|
      # Translate common validation messages to Korean
      case message
      when /can't be blank/i
        message.gsub(/can't be blank/i, '을(를) 입력해주세요')
      when /is too short/i
        message.gsub(/is too short.*/, '이(가) 너무 짧습니다')
      when /is too long/i
        message.gsub(/is too long.*/, '이(가) 너무 깁니다')
      when /is invalid/i
        message.gsub(/is invalid/i, '형식이 올바르지 않습니다')
      when /has already been taken/i
        message.gsub(/has already been taken/i, '이(가) 이미 사용 중입니다')
      else
        message
      end
    end
  end

  def request_metadata
    {
      ip: request.remote_ip,
      user_agent: request.user_agent,
      referer: request.referer,
      method: request.method,
      path: request.fullpath,
      format: request.format.to_s,
      xhr: request.xhr?
    }
  end
end