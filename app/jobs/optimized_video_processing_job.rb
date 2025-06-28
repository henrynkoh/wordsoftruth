class OptimizedVideoProcessingJob < ApplicationJob
  queue_as :video_processing
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
  discard_on ActiveJob::DeserializationError
  
  # Memory-optimized batch processing for videos
  def perform(batch_size = 20, status_filter = 'approved')
    Rails.logger.info "Starting optimized video processing batch (size: #{batch_size})"
    
    start_time = Time.current
    processed_count = 0
    failed_count = 0
    
    # Use find_each for memory efficiency with large datasets
    Video.where(status: status_filter)
         .includes(:sermon) # Eager load to avoid N+1 queries
         .find_each(batch_size: batch_size) do |video|
      
      result = process_video_with_memory_management(video)
      
      if result[:success]
        processed_count += 1
      else
        failed_count += 1
        Rails.logger.error "Video processing failed for ID #{video.id}: #{result[:error]}"
      end
      
      # Garbage collect every 10 videos to manage memory
      GC.start if (processed_count + failed_count) % 10 == 0
    end
    
    duration = Time.current - start_time
    Rails.logger.info "Batch processing completed: #{processed_count} processed, #{failed_count} failed in #{duration.round(2)}s"
    
    # Clear relevant caches
    clear_video_caches
  end

  private

  def process_video_with_memory_management(video)
    # Create isolated processing environment
    temp_dir = create_isolated_temp_directory(video.id)
    
    begin
      # Update status atomically
      video.update!(status: 'processing', processing_started_at: Time.current)
      
      # Use streaming approach for large scripts
      result = generate_video_with_streaming(video, temp_dir)
      
      if result[:success]
        video.update!(
          status: 'uploaded',
          youtube_id: result[:youtube_id],
          video_file_path: result[:video_path],
          processing_completed_at: Time.current
        )
        { success: true }
      else
        video.update!(status: 'failed', error_message: result[:error])
        { success: false, error: result[:error] }
      end
      
    rescue => e
      video.update!(status: 'failed', error_message: e.message)
      { success: false, error: e.message }
    ensure
      # Always clean up temporary resources
      cleanup_temp_directory(temp_dir)
    end
  end

  def generate_video_with_streaming(video, temp_dir)
    service = VideoGeneratorService.new(video)
    
    # Configure service for memory-optimized processing
    service.configure_for_batch_processing(
      temp_directory: temp_dir,
      memory_limit: 512.megabytes,
      enable_streaming: true,
      cleanup_intermediate_files: true
    )
    
    result = service.generate
    
    if result.success?
      {
        success: true,
        youtube_id: result.youtube_id,
        video_path: result.video_file_path
      }
    else
      {
        success: false,
        error: result.error
      }
    end
  end

  def create_isolated_temp_directory(video_id)
    temp_dir = Rails.root.join('tmp', 'video_processing', "video_#{video_id}_#{Time.current.to_i}")
    FileUtils.mkdir_p(temp_dir)
    temp_dir
  end

  def cleanup_temp_directory(temp_dir)
    return unless temp_dir && Dir.exist?(temp_dir)
    
    begin
      FileUtils.rm_rf(temp_dir)
    rescue => e
      Rails.logger.warn "Failed to cleanup temp directory #{temp_dir}: #{e.message}"
    end
  end

  def clear_video_caches
    # Clear dashboard stats cache since video counts changed
    Rails.cache.delete("dashboard_stats")
    
    # Clear any video-specific caches
    Rails.cache.delete_matched("video_status_counts_*")
    Rails.cache.delete_matched("recent_videos_*")
  end
end
