class VideoProcessingJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting video processing job at #{Time.current}"

    Video.approved.find_each do |video|
      begin
        VideoGeneratorService.new(video).generate
        Rails.logger.info "Successfully processed video #{video.id} for sermon '#{video.sermon.title}'"
      rescue StandardError => e
        Rails.logger.error "Failed to process video #{video.id}: #{e.message}"
        next
      end
    end

    Rails.logger.info "Completed video processing job at #{Time.current}"
  end
end 