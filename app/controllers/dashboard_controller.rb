class DashboardController < ApplicationController
  def index
    @recent_sermons = Sermon.order(created_at: :desc).limit(5)
  end

  def job_progress
    render json: {
      pending_count: Video.pending.count,
      processing_count: Video.processing.count,
      uploaded_count: Video.uploaded.count
    }
  end

  def approve_video
    video = Video.find(params[:id])
    video.update(status: :approved)
    redirect_to dashboard_index_path, notice: 'Video approved successfully'
  end

  def reject_video
    video = Video.find(params[:id])
    video.update(status: :failed)
    redirect_to dashboard_index_path, notice: 'Video rejected'
  end
end
