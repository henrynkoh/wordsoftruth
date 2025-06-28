# Simplified monitoring setup for development
Rails.application.configure do
  # Disable complex monitoring in development
  config.after_initialize do
    Rails.logger.info "Simple monitoring initialized for development"
  end
end