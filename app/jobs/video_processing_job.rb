# frozen_string_literal: true

class VideoProcessingJob < ApplicationJob
  queue_as :default

  # Retry failed jobs with exponential backoff, but limit attempts for video processing
  retry_on StandardError, wait: :exponentially_longer, attempts: 2

  # Discard jobs that fail due to validation or configuration issues
  discard_on ActiveRecord::RecordNotFound, ArgumentError
  discard_on VideoGeneratorService::ScriptTooLongError if defined?(VideoGeneratorService::ScriptTooLongError)

  def perform(video_ids = nil, batch_size = 5)
    start_time = Time.current
    Rails.logger.info "Starting video processing job at #{start_time}"

    videos_to_process = determine_videos_to_process(video_ids)

    if videos_to_process.empty?
      Rails.logger.info "No videos ready for processing"
      return
    end

    results = process_videos_in_batches(videos_to_process, batch_size)
    log_processing_results(results, start_time)
  end

  private

  def determine_videos_to_process(video_ids)
    if video_ids.present?
      # Process specific videos
      Video.where(id: video_ids).approved
    else
      # Process all approved videos that are ready
      Video.ready_for_processing
    end
  end

  def process_videos_in_batches(videos, batch_size)
    results = {
      success: [],
      failed: [],
      skipped: [],
      total_processed: 0,
    }

    videos.find_in_batches(batch_size: batch_size) do |video_batch|
      video_batch.each do |video|
        result = process_single_video(video)

        case result[:status]
        when :success
          results[:success] << video.id
        when :failed
          results[:failed] << { id: video.id, error: result[:error] }
        when :skipped
          results[:skipped] << { id: video.id, reason: result[:reason] }
        end

        results[:total_processed] += 1
      end
    end

    results
  end

  def process_single_video(video)
    # Double-check the video is still in the right state
    unless video.can_process?
      return {
        status: :skipped,
        reason: "Video #{video.id} is not in processable state (#{video.status})",
      }
    end

    Rails.logger.info "Processing video #{video.id} for sermon '#{video.sermon.title}'"

    generator = VideoGeneratorService.new(video)
    generator.generate

    Rails.logger.info "Successfully processed video #{video.id}"
    { status: :success }

  rescue VideoGeneratorService::VideoGenerationError => e
    Rails.logger.error "Video generation failed for video #{video.id}: #{e.message}"
    video.mark_failed!(e.message)
    { status: :failed, error: e.message }

  rescue StandardError => e
    Rails.logger.error "Unexpected error processing video #{video.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    video.mark_failed!("Unexpected error: #{e.message}")
    { status: :failed, error: e.message }
  end

  def log_processing_results(results, start_time)
    duration = Time.current - start_time

    Rails.logger.info "Completed video processing job in #{duration.round(2)} seconds"
    Rails.logger.info "Total processed: #{results[:total_processed]}"
    Rails.logger.info "Successful: #{results[:success].size}"
    Rails.logger.info "Failed: #{results[:failed].size}"
    Rails.logger.info "Skipped: #{results[:skipped].size}"

    if results[:failed].any?
      Rails.logger.warn "Failed video IDs: #{results[:failed].map { |f| f[:id] }.join(', ')}"
    end

    if results[:skipped].any?
      Rails.logger.info "Skipped video IDs: #{results[:skipped].map { |s| s[:id] }.join(', ')}"
    end
  end
end
