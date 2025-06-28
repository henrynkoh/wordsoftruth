# Optimized bulk operations service for video processing
class BulkVideoOperationsService
  include ActiveModel::Validations
  
  attr_reader :operation_stats, :errors
  
  def initialize(options = {})
    @batch_size = options[:batch_size] || 50
    @parallel_workers = options[:parallel_workers] || 3
    @operation_stats = { processed: 0, failed: 0, skipped: 0 }
    @errors = []
  end

  # Bulk approve videos
  def bulk_approve(video_ids, options = {})
    return false if video_ids.empty?

    Rails.logger.info "Starting bulk approval for #{video_ids.size} videos"
    
    # Validate videos exist and are approvable
    videos = Video.where(id: video_ids, status: ['pending'])
    if videos.count != video_ids.size
      @errors << "Some videos not found or not in pending status"
    end

    # Process in batches
    videos.find_in_batches(batch_size: @batch_size) do |video_batch|
      process_approval_batch(video_batch, options)
    end

    Rails.logger.info "Bulk approval completed: #{@operation_stats}"
    clear_video_caches
    true
  rescue => e
    Rails.logger.error "Bulk approval failed: #{e.message}"
    @errors << "Bulk approval failed: #{e.message}"
    false
  end

  # Bulk reject videos
  def bulk_reject(video_ids, rejection_reason = nil)
    return false if video_ids.empty?

    Rails.logger.info "Starting bulk rejection for #{video_ids.size} videos"
    
    videos = Video.where(id: video_ids, status: ['pending', 'approved'])
    
    videos.find_in_batches(batch_size: @batch_size) do |video_batch|
      process_rejection_batch(video_batch, rejection_reason)
    end

    Rails.logger.info "Bulk rejection completed: #{@operation_stats}"
    clear_video_caches
    true
  rescue => e
    Rails.logger.error "Bulk rejection failed: #{e.message}"
    @errors << "Bulk rejection failed: #{e.message}"
    false
  end

  # Bulk cleanup of failed/old videos
  def bulk_cleanup(criteria = {})
    Rails.logger.info "Starting bulk video cleanup"
    
    # Default cleanup criteria
    criteria = {
      older_than: 30.days.ago,
      statuses: ['failed'],
      cleanup_files: true
    }.merge(criteria)

    videos_to_cleanup = build_cleanup_query(criteria)
    total_count = videos_to_cleanup.count
    
    return true if total_count == 0

    Rails.logger.info "Found #{total_count} videos for cleanup"

    videos_to_cleanup.find_in_batches(batch_size: @batch_size) do |video_batch|
      process_cleanup_batch(video_batch, criteria)
    end

    Rails.logger.info "Bulk cleanup completed: #{@operation_stats}"
    clear_video_caches
    true
  rescue => e
    Rails.logger.error "Bulk cleanup failed: #{e.message}"
    @errors << "Bulk cleanup failed: #{e.message}"
    false
  end

  # Bulk retry failed video processing
  def bulk_retry_failed(max_retries = 3)
    Rails.logger.info "Starting bulk retry of failed videos"
    
    # Find videos that have failed but haven't exceeded retry limit
    failed_videos = Video.where(status: 'failed')
                         .where('retry_count < ? OR retry_count IS NULL', max_retries)
    
    total_count = failed_videos.count
    return true if total_count == 0

    Rails.logger.info "Found #{total_count} failed videos to retry"

    failed_videos.find_in_batches(batch_size: @batch_size) do |video_batch|
      process_retry_batch(video_batch)
    end

    Rails.logger.info "Bulk retry completed: #{@operation_stats}"
    clear_video_caches
    true
  rescue => e
    Rails.logger.error "Bulk retry failed: #{e.message}"
    @errors << "Bulk retry failed: #{e.message}"
    false
  end

  # Bulk update video metadata
  def bulk_update_metadata(video_ids, metadata_updates)
    return false if video_ids.empty? || metadata_updates.empty?

    Rails.logger.info "Starting bulk metadata update for #{video_ids.size} videos"
    
    # Validate allowed metadata fields
    allowed_fields = [:title, :description, :tags, :duration, :resolution]
    metadata_updates = metadata_updates.slice(*allowed_fields)
    
    return false if metadata_updates.empty?

    videos = Video.where(id: video_ids)
    
    videos.find_in_batches(batch_size: @batch_size) do |video_batch|
      process_metadata_batch(video_batch, metadata_updates)
    end

    Rails.logger.info "Bulk metadata update completed: #{@operation_stats}"
    clear_video_caches
    true
  rescue => e
    Rails.logger.error "Bulk metadata update failed: #{e.message}"
    @errors << "Bulk metadata update failed: #{e.message}"
    false
  end

  private

  def process_approval_batch(video_batch, options)
    Video.transaction do
      video_batch.each do |video|
        begin
          video.update!(
            status: 'approved',
            approved_at: Time.current,
            approved_by: options[:approved_by]
          )
          
          # Enqueue for processing if auto_process is enabled
          if options[:auto_process]
            OptimizedVideoProcessingJob.perform_later(video.id)
          end
          
          @operation_stats[:processed] += 1
        rescue => e
          @operation_stats[:failed] += 1
          Rails.logger.error "Failed to approve video #{video.id}: #{e.message}"
        end
      end
    end
  end

  def process_rejection_batch(video_batch, rejection_reason)
    Video.transaction do
      video_batch.each do |video|
        begin
          video.update!(
            status: 'rejected',
            rejected_at: Time.current,
            rejection_reason: rejection_reason
          )
          @operation_stats[:processed] += 1
        rescue => e
          @operation_stats[:failed] += 1
          Rails.logger.error "Failed to reject video #{video.id}: #{e.message}"
        end
      end
    end
  end

  def process_cleanup_batch(video_batch, criteria)
    video_batch.each do |video|
      begin
        # Cleanup files if requested
        if criteria[:cleanup_files]
          cleanup_video_files(video)
        end
        
        # Delete or archive the video record
        if criteria[:archive_instead_of_delete]
          video.update!(status: 'archived', archived_at: Time.current)
        else
          video.destroy!
        end
        
        @operation_stats[:processed] += 1
      rescue => e
        @operation_stats[:failed] += 1
        Rails.logger.error "Failed to cleanup video #{video.id}: #{e.message}"
      end
    end
  end

  def process_retry_batch(video_batch)
    video_batch.each do |video|
      begin
        # Reset video status and increment retry count
        retry_count = (video.retry_count || 0) + 1
        
        video.update!(
          status: 'pending',
          retry_count: retry_count,
          error_message: nil,
          last_retry_at: Time.current
        )
        
        # Enqueue for processing
        OptimizedVideoProcessingJob.perform_later(video.id)
        
        @operation_stats[:processed] += 1
      rescue => e
        @operation_stats[:failed] += 1
        Rails.logger.error "Failed to retry video #{video.id}: #{e.message}"
      end
    end
  end

  def process_metadata_batch(video_batch, metadata_updates)
    Video.transaction do
      video_batch.each do |video|
        begin
          video.update!(metadata_updates.merge(updated_at: Time.current))
          @operation_stats[:processed] += 1
        rescue => e
          @operation_stats[:failed] += 1
          Rails.logger.error "Failed to update metadata for video #{video.id}: #{e.message}"
        end
      end
    end
  end

  def build_cleanup_query(criteria)
    query = Video.all
    
    if criteria[:older_than]
      query = query.where('created_at < ?', criteria[:older_than])
    end
    
    if criteria[:statuses].present?
      query = query.where(status: criteria[:statuses])
    end
    
    if criteria[:no_files]
      query = query.where(video_file_path: [nil, ''])
    end
    
    query
  end

  def cleanup_video_files(video)
    files_to_cleanup = [
      video.video_file_path,
      video.thumbnail_path,
      video.audio_file_path
    ].compact

    files_to_cleanup.each do |file_path|
      next unless file_path.present? && File.exist?(file_path)
      
      begin
        File.delete(file_path)
        Rails.logger.debug "Cleaned up file: #{file_path}"
      rescue => e
        Rails.logger.warn "Failed to cleanup file #{file_path}: #{e.message}"
      end
    end
  end

  def clear_video_caches
    Rails.cache.delete("video_status_counts")
    Rails.cache.delete("dashboard_stats")
    Rails.cache.delete_matched("recent_videos_*")
  end
end