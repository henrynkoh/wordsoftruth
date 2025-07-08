# frozen_string_literal: true

class ProgressTrackingJob < ApplicationJob
  queue_as :monitoring

  def perform(trackable_type, trackable_id, operation_type, metadata = {})
    Rails.logger.info "📊 Tracking progress for #{trackable_type}##{trackable_id}: #{operation_type}"

    begin
      # Create progress tracking record
      progress_data = {
        trackable_type: trackable_type,
        trackable_id: trackable_id,
        operation_type: operation_type,
        status: metadata[:status] || "in_progress",
        progress_percentage: metadata[:progress_percentage] || 0,
        current_step: metadata[:current_step],
        total_steps: metadata[:total_steps],
        message: metadata[:message],
        error_message: metadata[:error_message],
        started_at: metadata[:started_at] || Time.current,
        updated_at: Time.current,
        metadata: metadata
      }

      # Store in cache with expiration
      cache_key = "progress_#{trackable_type}_#{trackable_id}"
      Rails.cache.write(cache_key, progress_data, expires_in: 24.hours)

      # Log to business activity log
      BusinessActivityLog.log_progress_update(
        trackable_type.constantize.find(trackable_id),
        operation_type,
        progress_data[:progress_percentage],
        progress_data[:message]
      )

      # Trigger real-time updates via ActionCable (if implemented)
      broadcast_progress_update(progress_data)

      Rails.logger.info "✅ Progress tracked: #{operation_type} - #{progress_data[:progress_percentage]}%"

    rescue => e
      Rails.logger.error "❌ Progress tracking failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end

  # Track video generation progress
  def self.track_video_generation(text_note_id, step, progress_percentage, message = nil)
    perform_later(
      "TextNote",
      text_note_id,
      "video_generation",
      {
        current_step: step,
        total_steps: 5,
        progress_percentage: progress_percentage,
        message: message || "Processing step #{step}/5",
        status: progress_percentage >= 100 ? "completed" : "in_progress"
      }
    )
  end

  # Track YouTube upload progress
  def self.track_youtube_upload(text_note_id, progress_percentage, message = nil)
    perform_later(
      "TextNote",
      text_note_id,
      "youtube_upload", 
      {
        current_step: "Uploading to YouTube",
        progress_percentage: progress_percentage,
        message: message || "Uploading to YouTube...",
        status: progress_percentage >= 100 ? "completed" : "in_progress"
      }
    )
  end

  # Track sermon batch processing
  def self.track_batch_processing(batch_id, processed_count, total_count, message = nil)
    progress_percentage = total_count > 0 ? (processed_count.to_f / total_count * 100).round(1) : 0
    
    perform_later(
      "SermonBatch",
      batch_id,
      "batch_processing",
      {
        current_step: "Processing sermons",
        progress_percentage: progress_percentage,
        processed_count: processed_count,
        total_count: total_count,
        message: message || "Processing sermon #{processed_count}/#{total_count}",
        status: progress_percentage >= 100 ? "completed" : "in_progress"
      }
    )
  end

  # Get current progress
  def self.get_progress(trackable_type, trackable_id)
    cache_key = "progress_#{trackable_type}_#{trackable_id}"
    Rails.cache.read(cache_key)
  end

  # Clear progress tracking
  def self.clear_progress(trackable_type, trackable_id)
    cache_key = "progress_#{trackable_type}_#{trackable_id}"
    Rails.cache.delete(cache_key)
  end

  # Get all active progress items
  def self.get_all_active_progress
    progress_items = []
    
    # This is a simplified approach - in production you might want to use Redis SCAN
    # or maintain a separate index of active progress items
    cache_keys = Rails.cache.instance_variable_get(:@data)&.keys || []
    progress_keys = cache_keys.select { |key| key.to_s.start_with?("progress_") }
    
    progress_keys.each do |key|
      progress_data = Rails.cache.read(key)
      progress_items << progress_data if progress_data
    end
    
    progress_items.sort_by { |item| item[:updated_at] }.reverse
  end

  private

  def broadcast_progress_update(progress_data)
    # Prepare data for real-time broadcast
    broadcast_data = {
      trackable_type: progress_data[:trackable_type],
      trackable_id: progress_data[:trackable_id],
      operation_type: progress_data[:operation_type],
      progress_percentage: progress_data[:progress_percentage],
      current_step: progress_data[:current_step],
      message: progress_data[:message],
      status: progress_data[:status],
      updated_at: progress_data[:updated_at]
    }

    # Broadcast to specific channels
    case progress_data[:trackable_type]
    when "TextNote"
      # ActionCable.server.broadcast(
      #   "text_note_#{progress_data[:trackable_id]}",
      #   { type: 'progress_update', data: broadcast_data }
      # )
      
      # Also broadcast to general progress channel
      # ActionCable.server.broadcast(
      #   "progress_updates", 
      #   { type: 'progress_update', data: broadcast_data }
      # )
      
      Rails.logger.info "📡 Progress broadcast: TextNote##{progress_data[:trackable_id]} - #{progress_data[:progress_percentage]}%"
      
    when "SermonBatch"
      # ActionCable.server.broadcast(
      #   "batch_#{progress_data[:trackable_id]}",
      #   { type: 'progress_update', data: broadcast_data }
      # )
      
      Rails.logger.info "📡 Progress broadcast: SermonBatch##{progress_data[:trackable_id]} - #{progress_data[:progress_percentage]}%"
    end

  rescue => e
    Rails.logger.warn "⚠️ Failed to broadcast progress update: #{e.message}"
  end
end