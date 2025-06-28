# frozen_string_literal: true

class DashboardController < ApplicationController
  before_action :set_video, only: [ :approve_video, :reject_video ]

  rescue_from ActiveRecord::RecordNotFound, with: :video_not_found

  def index
    @recent_sermons = Sermon.includes(:videos).recent_sermons(5)
    @dashboard_stats = calculate_dashboard_stats
  end

  def job_progress
    render json: build_job_progress_response
  end

  def approve_video
    if @video.approve!
      redirect_to dashboard_index_path, notice: "Video approved successfully"
    else
      redirect_to dashboard_index_path, alert: "Failed to approve video: #{@video.errors.full_messages.join(', ')}"
    end
  end

  def reject_video
    reason = params[:reason]

    if @video.reject!(reason)
      message = "Video rejected"
      message += " (Reason: #{reason})" if reason.present?
      redirect_to dashboard_index_path, notice: message
    else
      redirect_to dashboard_index_path, alert: "Failed to reject video: #{@video.errors.full_messages.join(', ')}"
    end
  end

  private

  def set_video
    @video = Video.find(params[:id])
  end

  def video_not_found
    redirect_to dashboard_index_path, alert: "Video not found"
  end

  def build_job_progress_response
    {
      pending_count: Video.pending.count,
      approved_count: Video.approved.count,
      processing_count: Video.processing.count,
      uploaded_count: Video.uploaded.count,
      failed_count: Video.failed.count,
      total_videos: Video.count,
      last_updated: Time.current.iso8601,
    }
  end

  def calculate_dashboard_stats
    Rails.cache.fetch("dashboard_stats", expires_in: 5.minutes) do
      # Use single queries with GROUP BY for better performance
      video_counts = Video.group(:status).count
      sermon_video_counts = Sermon.left_joins(:videos)
                                  .group("CASE WHEN videos.id IS NOT NULL THEN 'with_videos' ELSE 'without_videos' END")
                                  .count
      
      {
        total_sermons: Sermon.count,
        sermons_with_videos: sermon_video_counts['with_videos'] || 0,
        sermons_without_videos: sermon_video_counts['without_videos'] || 0,
        total_videos: Video.count,
        pending_videos: video_counts['pending'] || 0,
        approved_videos: video_counts['approved'] || 0,
        processing_videos: video_counts['processing'] || 0,
        uploaded_videos: video_counts['uploaded'] || 0,
        failed_videos: video_counts['failed'] || 0,
        videos_with_youtube_links: Video.where.not(youtube_id: [nil, '']).count,
      }
    end
  end
end
