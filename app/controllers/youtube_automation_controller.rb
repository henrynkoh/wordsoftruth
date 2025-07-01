require 'ostruct'
require 'net/http'
require 'uri'

class YoutubeAutomationController < ApplicationController
  before_action :set_default_stats

  def index
    # YouTube video processing landing page
    @recent_batches = YoutubeVideoBatch.recent.limit(5) if defined?(YoutubeVideoBatch)
    @processing_stats = calculate_processing_stats
  end

  def start_automation
    # Parse URLs with better handling for concatenated URLs
    raw_input = params[:youtube_urls].to_s
    
    # First split by newlines
    video_urls = raw_input.split(/\r?\n/).map(&:strip).reject(&:blank?)
    
    # If we only got one "URL" but it contains multiple YouTube patterns, split them
    if video_urls.size == 1 && video_urls.first.scan(/https?:\/\//).size > 1
      # Use a more robust approach to split concatenated URLs
      concatenated_url = video_urls.first
      video_urls = []
      
      # Find all starting points of URLs
      url_starts = []
      (0...concatenated_url.length).each do |i|
        if concatenated_url[i..-1].start_with?('http')
          url_starts << i
        end
      end
      
      # Extract each URL between start points
      url_starts.each_with_index do |start_pos, index|
        end_pos = url_starts[index + 1] || concatenated_url.length
        url = concatenated_url[start_pos...end_pos]
        video_urls << url if url.include?('youtube.com') || url.include?('youtu.be')
      end
    end
    
    if video_urls.empty?
      redirect_to youtube_automation_path, alert: "최소 하나의 YouTube URL을 입력해주세요."
      return
    end

    # Validate YouTube URLs
    invalid_urls = []
    valid_urls = []

    video_urls.each do |url|
      if valid_youtube_url?(url)
        valid_urls << url
      else
        invalid_urls << url
      end
    end

    if valid_urls.empty?
      error_message = "유효한 YouTube URL이 없습니다."
      if invalid_urls.any?
        error_message += " 무효한 URL: #{invalid_urls.join(', ')}"
      end
      redirect_to youtube_automation_path, alert: error_message
      return
    end

    # Create batch processing record
    batch = create_youtube_batch(valid_urls, invalid_urls)
    
    # Start background processing
    YoutubeVideoProcessingJob.perform_later(batch.id)
    
    flash[:notice] = "YouTube 동영상 자동화가 시작되었습니다! #{valid_urls.size}개의 동영상을 처리합니다."
    if invalid_urls.any?
      flash[:warning] = "무효한 URL #{invalid_urls.size}개는 건너뛰었습니다."
    end
    
    redirect_to youtube_batch_progress_path(batch.id)
  end

  def batch_progress
    @batch = find_youtube_batch(params[:id])
    
    unless @batch
      redirect_to youtube_automation_path, alert: "배치를 찾을 수 없습니다."
      return
    end

    @progress_data = calculate_batch_progress(@batch)
    
    respond_to do |format|
      format.html
      format.json { render json: @progress_data }
    end
  end

  def batch_status
    batch = find_youtube_batch(params[:id])
    
    if batch
      render json: calculate_batch_progress(batch)
    else
      render json: { error: "Batch not found" }, status: 404
    end
  end

  private

  def valid_youtube_url?(url)
    return false if url.blank?
    
    begin
      uri = URI.parse(url)
      
      # Must be HTTP or HTTPS
      return false unless %w[http https].include?(uri.scheme&.downcase)
      
      # Must be YouTube domain
      youtube_domains = %w[youtube.com youtu.be www.youtube.com m.youtube.com]
      return false unless youtube_domains.any? { |domain| uri.host&.downcase&.include?(domain) }
      
      # Must have video ID pattern
      if uri.host&.include?('youtu.be')
        # Short URL format: https://youtu.be/VIDEO_ID
        return uri.path.length > 1
      elsif uri.host&.include?('youtube.com')
        # Long URL format: https://youtube.com/watch?v=VIDEO_ID
        query_params = URI.decode_www_form(uri.query || '')
        return query_params.any? { |key, value| key == 'v' && value.present? }
      end
      
      false
    rescue URI::InvalidURIError
      false
    end
  end

  def create_youtube_batch(valid_urls, invalid_urls)
    # Create a simple batch record using cache
    batch_data = {
      id: SecureRandom.uuid,
      urls: valid_urls,
      invalid_urls: invalid_urls,
      status: 'started',
      created_at: Time.current,
      total_urls: valid_urls.size,
      processed_urls: 0,
      successful_extractions: 0,
      successful_videos: 0,
      failed_urls: 0,
      type: 'youtube'
    }
    
    # Store in Rails cache
    Rails.cache.write("youtube_batch_#{batch_data[:id]}", batch_data, expires_in: 24.hours)
    
    # Return a simple object that behaves like a model
    OpenStruct.new(batch_data)
  end

  def find_youtube_batch(id)
    batch_data = Rails.cache.read("youtube_batch_#{id}")
    return nil unless batch_data
    
    OpenStruct.new(batch_data)
  end

  def calculate_batch_progress(batch)
    # Refresh batch data from cache
    fresh_data = Rails.cache.read("youtube_batch_#{batch.id}")
    batch = OpenStruct.new(fresh_data) if fresh_data

    progress_percentage = batch.total_urls > 0 ? (batch.processed_urls.to_f / batch.total_urls * 100).round(1) : 0
    
    {
      id: batch.id,
      status: batch.status,
      total_urls: batch.total_urls,
      processed_urls: batch.processed_urls,
      successful_extractions: batch.successful_extractions,
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
    activity_key = "youtube_batch_activity_#{batch_id}"
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