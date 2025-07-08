# frozen_string_literal: true

# Flash messaging helper for comprehensive user feedback
module FlashHelper
  # Flash message types with Korean labels and styling
  FLASH_TYPES = {
    notice: { 
      label: '성공', 
      icon: 'check-circle', 
      class: 'bg-green-50 border-green-200 text-green-800',
      icon_class: 'text-green-400'
    },
    success: { 
      label: '성공', 
      icon: 'check-circle', 
      class: 'bg-green-50 border-green-200 text-green-800',
      icon_class: 'text-green-400'
    },
    alert: { 
      label: '주의', 
      icon: 'exclamation-triangle', 
      class: 'bg-yellow-50 border-yellow-200 text-yellow-800',
      icon_class: 'text-yellow-400'
    },
    warning: { 
      label: '경고', 
      icon: 'exclamation-triangle', 
      class: 'bg-yellow-50 border-yellow-200 text-yellow-800',
      icon_class: 'text-yellow-400'
    },
    error: { 
      label: '오류', 
      icon: 'x-circle', 
      class: 'bg-red-50 border-red-200 text-red-800',
      icon_class: 'text-red-400'
    },
    info: { 
      label: '정보', 
      icon: 'information-circle', 
      class: 'bg-blue-50 border-blue-200 text-blue-800',
      icon_class: 'text-blue-400'
    }
  }.freeze

  def render_flash_messages
    return unless flash.any?

    content_tag :div, class: "flash-messages-container fixed top-4 right-4 z-50 space-y-2 max-w-md", 
                      data: { controller: "flash-messages" } do
      flash.map do |type, message|
        next if message.blank?
        render_flash_message(type.to_sym, message)
      end.compact.join.html_safe
    end
  end

  def render_flash_message(type, message, options = {})
    type = normalize_flash_type(type)
    config = FLASH_TYPES[type] || FLASH_TYPES[:info]
    
    auto_dismiss = options.fetch(:auto_dismiss, type != :error)
    dismissible = options.fetch(:dismissible, true)
    show_icon = options.fetch(:show_icon, true)
    
    content_tag :div, 
                class: "flash-message border rounded-lg p-4 shadow-lg #{config[:class]} #{options[:class]}",
                data: { 
                  flash_type: type,
                  auto_dismiss: auto_dismiss,
                  dismiss_delay: options[:dismiss_delay] || 5000
                } do
      content_tag :div, class: "flex items-start" do
        flash_content = []
        
        # Icon
        if show_icon
          flash_content << content_tag(:div, class: "flex-shrink-0") do
            render_flash_icon(config[:icon], config[:icon_class])
          end
        end
        
        # Message content
        flash_content << content_tag(:div, class: "ml-3 flex-1") do
          message_content = []
          
          # Label and message
          message_content << content_tag(:div, class: "text-sm font-medium") do
            if options[:show_label] != false
              content_tag(:span, config[:label] + ': ', class: "font-semibold") + 
              (message.is_a?(Array) ? message.first : message).to_s
            else
              (message.is_a?(Array) ? message.first : message).to_s
            end
          end
          
          # Additional details (for validation errors, etc.)
          if message.is_a?(Array) && message.length > 1
            message_content << content_tag(:ul, class: "mt-2 text-sm list-disc list-inside") do
              message[1..-1].map do |detail|
                content_tag(:li, detail)
              end.join.html_safe
            end
          end
          
          # Validation errors from flash
          if flash[:validation_errors].present?
            message_content << content_tag(:ul, class: "mt-2 text-sm list-disc list-inside") do
              flash[:validation_errors].map do |error|
                content_tag(:li, error)
              end.join.html_safe
            end
          end
          
          # Error ID
          if flash[:error_id].present?
            message_content << content_tag(:div, class: "mt-2 text-xs opacity-75") do
              "오류 ID: #{flash[:error_id]}"
            end
          end
          
          message_content.join.html_safe
        end
        
        # Dismiss button
        if dismissible
          flash_content << content_tag(:div, class: "ml-4 flex-shrink-0") do
            content_tag :button, 
                        class: "inline-flex text-gray-400 hover:text-gray-600 focus:outline-none",
                        data: { action: "click->flash-messages#dismiss" } do
              content_tag :span, "닫기", class: "sr-only"
              render_flash_icon("x", "w-5 h-5")
            end
          end
        end
        
        flash_content.join.html_safe
      end
    end
  end

  def flash_success(message, **options)
    flash[:success] = message
    options
  end

  def flash_error(message, **options)
    flash[:error] = message
    flash[:error_id] = options[:error_id] if options[:error_id]
    options
  end

  def flash_warning(message, **options)
    flash[:warning] = message
    options
  end

  def flash_info(message, **options)
    flash[:info] = message
    options
  end

  def flash_with_details(type, message, details = [])
    flash[type] = [message] + Array(details)
  end

  def flash_validation_errors(record)
    return unless record&.errors&.any?
    
    flash[:error] = "입력하신 정보에 오류가 있습니다."
    flash[:validation_errors] = format_validation_errors(record.errors)
  end

  private

  def normalize_flash_type(type)
    case type.to_s
    when 'notice', 'success'
      :success
    when 'alert', 'warning'
      :warning
    when 'error', 'danger'
      :error
    when 'info', 'information'
      :info
    else
      :info
    end
  end

  def render_flash_icon(icon_name, css_class = "w-5 h-5")
    icon_paths = {
      'check-circle' => "M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z",
      'exclamation-triangle' => "M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z",
      'x-circle' => "M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z",
      'information-circle' => "M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z",
      'x' => "M6 18L18 6M6 6l12 12"
    }

    path = icon_paths[icon_name] || icon_paths['information-circle']
    
    content_tag :svg, 
                class: css_class,
                fill: "none", 
                stroke: "currentColor", 
                viewBox: "0 0 24 24" do
      content_tag :path, "", 
                  "stroke-linecap": "round", 
                  "stroke-linejoin": "round", 
                  "stroke-width": "2", 
                  d: path
    end
  end

  def format_validation_errors(errors)
    errors.full_messages.map do |message|
      # Translate common Rails validation messages to Korean
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
      when /must be accepted/i
        message.gsub(/must be accepted/i, '을(를) 동의해주세요')
      when /is not included in the list/i
        message.gsub(/is not included in the list/i, '이(가) 유효하지 않습니다')
      when /must be equal to/i
        message.gsub(/must be equal to/i, '이(가) 일치하지 않습니다')
      when /must be greater than/i
        message.gsub(/must be greater than/i, '이(가) 다음보다 커야 합니다:')
      when /must be less than/i
        message.gsub(/must be less than/i, '이(가) 다음보다 작아야 합니다:')
      else
        message
      end
    end
  end
end