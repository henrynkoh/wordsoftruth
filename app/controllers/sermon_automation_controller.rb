require 'ostruct'

class SermonAutomationController < ApplicationController
  before_action :set_default_stats

  def index
    # Landing page with URL input form
    @recent_batches = SermonBatch.recent.limit(5) if defined?(SermonBatch)
    @processing_stats = calculate_processing_stats
  end

  def start_automation
    urls = params[:sermon_urls].to_s.split(/\r?\n/).map(&:strip).reject(&:blank?)
    
    if urls.empty?
      redirect_to root_path, alert: "최소 하나의 URL을 입력해주세요."
      return
    end

    # Validate URLs
    invalid_urls = []
    valid_urls = []

    urls.each do |url|
      if valid_sermon_url?(url)
        valid_urls << url
      else
        invalid_urls << url
      end
    end

    if valid_urls.empty?
      error_message = "유효한 설교 URL이 없습니다."
      if invalid_urls.any?
        error_message += " 무효한 URL: #{invalid_urls.join(', ')}"
      end
      redirect_to root_path, alert: error_message
      return
    end

    # Create batch processing record
    batch = create_sermon_batch(valid_urls, invalid_urls)
    
    # Start background processing
    SermonBatchProcessingJob.perform_later(batch.id)
    
    flash[:notice] = "설교 자동화가 시작되었습니다! #{valid_urls.size}개의 URL을 처리합니다."
    if invalid_urls.any?
      flash[:warning] = "무효한 URL #{invalid_urls.size}개는 건너뛰었습니다."
    end
    
    redirect_to batch_progress_path(batch.id)
  end

  def batch_progress
    @batch = find_sermon_batch(params[:id])
    
    unless @batch
      redirect_to root_path, alert: "배치를 찾을 수 없습니다."
      return
    end

    @progress_data = calculate_batch_progress(@batch)
    
    respond_to do |format|
      format.html
      format.json { render json: @progress_data }
    end
  end

  def batch_status
    batch = find_sermon_batch(params[:id])
    
    if batch
      render json: calculate_batch_progress(batch)
    else
      render json: { error: "Batch not found" }, status: 404
    end
  end

  private

  def valid_sermon_url?(url)
    return false if url.blank?
    
    begin
      uri = URI.parse(url)
      
      # Must be HTTP or HTTPS
      return false unless %w[http https].include?(uri.scheme&.downcase)
      
      # Must have a host
      return false unless uri.host
      
      # Basic domain validation
      return false if uri.host.include?('localhost') || uri.host.match?(/^\d+\.\d+\.\d+\.\d+$/)
      
      # Should look like a sermon URL (basic heuristics)
      sermon_indicators = %w[sermon message teaching preaching homily board read gospel jesus]
      url_lower = url.downcase
      
      sermon_indicators.any? { |indicator| url_lower.include?(indicator) } ||
        url_lower.match?(/church|ministry|pastor|bible|christian|jesus|festival|god|faith/i)
        
    rescue URI::InvalidURIError
      false
    end
  end

  def create_sermon_batch(valid_urls, invalid_urls)
    # Create a simple batch record using a hash or database table
    batch_data = {
      id: SecureRandom.uuid,
      urls: valid_urls,
      invalid_urls: invalid_urls,
      status: 'started',
      created_at: Time.current,
      total_urls: valid_urls.size,
      processed_urls: 0,
      successful_sermons: 0,
      successful_videos: 0,
      failed_urls: 0
    }
    
    # Store in Rails cache for now (in production, use database)
    Rails.cache.write("sermon_batch_#{batch_data[:id]}", batch_data, expires_in: 24.hours)
    
    # Return a simple object that behaves like a model
    OpenStruct.new(batch_data)
  end

  def find_sermon_batch(id)
    batch_data = Rails.cache.read("sermon_batch_#{id}")
    return nil unless batch_data
    
    OpenStruct.new(batch_data)
  end

  def calculate_batch_progress(batch)
    # Refresh batch data from cache
    fresh_data = Rails.cache.read("sermon_batch_#{batch.id}")
    batch = OpenStruct.new(fresh_data) if fresh_data

    progress_percentage = batch.total_urls > 0 ? (batch.processed_urls.to_f / batch.total_urls * 100).round(1) : 0
    
    {
      id: batch.id,
      status: batch.status,
      total_urls: batch.total_urls,
      processed_urls: batch.processed_urls,
      successful_sermons: batch.successful_sermons,
      successful_videos: batch.successful_videos,
      failed_urls: batch.failed_urls,
      progress_percentage: progress_percentage,
      created_at: batch.created_at,
      estimated_completion: calculate_estimated_completion(batch),
      recent_activity: get_recent_batch_activity(batch.id)
    }
  end

  def calculate_estimated_completion(batch)
    return nil if batch.processed_urls == 0 || batch.status == 'completed'
    
    elapsed_time = Time.current - batch.created_at
    rate = batch.processed_urls / elapsed_time.to_f
    remaining = batch.total_urls - batch.processed_urls
    
    if rate > 0
      estimated_seconds = remaining / rate
      Time.current + estimated_seconds
    else
      nil
    end
  end

  def get_recent_batch_activity(batch_id)
    # Get recent activity for this batch
    activity_key = "batch_activity_#{batch_id}"
    Rails.cache.read(activity_key) || []
  end

  def calculate_processing_stats
    {
      total_sermons_today: Sermon.where(created_at: Date.current.beginning_of_day..Time.current).count,
      total_videos_today: Video.where(created_at: Date.current.beginning_of_day..Time.current).count,
      videos_uploaded_today: Video.where(created_at: Date.current.beginning_of_day..Time.current, status: 'uploaded').count,
      success_rate: calculate_daily_success_rate
    }
  rescue
    { total_sermons_today: 0, total_videos_today: 0, videos_uploaded_today: 0, success_rate: 0 }
  end

  def calculate_daily_success_rate
    today_videos = Video.where(created_at: Date.current.beginning_of_day..Time.current)
    return 0 if today_videos.count == 0
    
    successful = today_videos.where(status: 'uploaded').count
    (successful.to_f / today_videos.count * 100).round(1)
  rescue
    0
  end

  def set_default_stats
    @stats = {
      total_sermons: Sermon.count,
      total_videos: Video.count,
      uploaded_videos: Video.where(status: 'uploaded').count,
      processing_videos: Video.where(status: ['pending', 'approved', 'processing']).count
    }
  rescue
    @stats = { total_sermons: 0, total_videos: 0, uploaded_videos: 0, processing_videos: 0 }
  end
end