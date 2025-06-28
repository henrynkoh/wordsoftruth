# frozen_string_literal: true

class Video < ApplicationRecord
  include BusinessActivityLogging
  include AuditLoggingConcern
  include SensitiveDataConcern
  include VideoBusinessLogic
  
  # Associations
  belongs_to :sermon

  # Enhanced business parameter validations
  validates :script, presence: true, length: { minimum: 10, maximum: 10_000 },
            security: { type: :content },
            business_parameter: { parameter_type: :video_script }
            
  validates :status, presence: true, inclusion: { in: %w[pending approved processing uploaded failed] },
            business_parameter: { parameter_type: :moderation_status }
  validates :youtube_id, uniqueness: true, allow_nil: true
  validates :video_path, length: { maximum: 500 }
  validates :thumbnail_path, length: { maximum: 500 }

  # Define status as a string enum
  enum :status, {
    pending: "pending",
    approved: "approved",
    processing: "processing",
    uploaded: "uploaded",
    failed: "failed",
  }, default: "pending"

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :with_youtube_id, -> { where.not(youtube_id: nil) }
  scope :without_youtube_id, -> { where(youtube_id: nil) }
  scope :ready_for_processing, -> { approved.where(video_path: nil) }
  scope :ready_for_upload, -> { processing.where.not(video_path: nil) }
  
  # Cache frequently accessed counts
  def self.cached_status_counts
    Rails.cache.fetch("video_status_counts", expires_in: 5.minutes) do
      group(:status).count
    end
  end
  
  def self.cached_recent_videos(limit = 10)
    cache_key = "recent_videos_#{limit}"
    
    Rails.cache.fetch(cache_key, expires_in: 3.minutes) do
      recent.includes(:sermon).limit(limit).to_a
    end
  end

  # Callbacks
  before_save :sanitize_script
  after_update :log_status_change, if: :saved_change_to_status?
  before_destroy :cleanup_files

  # State machine methods
  def can_approve?
    pending?
  end

  def can_reject?
    pending? || approved?
  end

  def can_process?
    approved?
  end

  def can_upload?
    processing? && video_path.present?
  end

  def approve!
    return false unless can_approve?

    update(status: :approved)
  end

  def reject!(reason = nil)
    return false unless can_reject?

    Rails.logger.info "Video #{id} rejected: #{reason}" if reason
    update(status: :failed)
  end

  def start_processing!
    return false unless can_process?

    update(status: :processing)
  end

  def complete_upload!(youtube_id)
    return false unless can_upload?
    return false if youtube_id.blank?

    update(status: :uploaded, youtube_id: youtube_id)
  end

  def mark_failed!(error_message = nil)
    Rails.logger.error "Video #{id} failed: #{error_message}" if error_message
    update(status: :failed)
  end

  # Helper methods
  def youtube_url
    return nil if youtube_id.blank?

    "https://www.youtube.com/watch?v=#{youtube_id}"
  end

  def youtube_embed_url
    return nil if youtube_id.blank?

    "https://www.youtube.com/embed/#{youtube_id}"
  end

  def has_video_file?
    video_path.present? && File.exist?(video_path)
  end

  def has_thumbnail?
    thumbnail_path.present? && File.exist?(thumbnail_path)
  end

  def file_size
    return 0 unless has_video_file?

    File.size(video_path)
  end

  def display_file_size
    return "N/A" unless has_video_file?

    file_size_mb = file_size / 1_048_576.0 # Convert to MB
    "#{file_size_mb.round(2)} MB"
  end

  def processing_time
    return nil unless uploaded?

    updated_at - created_at
  end

  def display_status
    status.humanize
  end

  def status_badge_class
    case status
    when "pending" then "badge-warning"
    when "approved" then "badge-info"
    when "processing" then "badge-primary"
    when "uploaded" then "badge-success"
    when "failed" then "badge-danger"
    else "badge-secondary"
    end
  end

  def can_be_deleted?
    failed? || (uploaded? && youtube_id.present?)
  end

  private

  def sanitize_script
    return if script.blank?

    # Remove potentially dangerous HTML/script tags
    self.script = ActionController::Base.helpers.strip_tags(script)

    # Normalize whitespace
    self.script = script.gsub(/\s+/, " ").strip
  end

  def log_status_change
    old_status = saved_changes["status"][0]
    new_status = saved_changes["status"][1]

    Rails.logger.info "Video #{id} status changed from #{old_status} to #{new_status}"
  end

  def cleanup_files
    cleanup_video_file
    cleanup_thumbnail_file
  end

  def cleanup_video_file
    return unless video_path.present? && File.exist?(video_path)

    File.delete(video_path)
    Rails.logger.info "Deleted video file: #{video_path}"
  rescue StandardError => e
    Rails.logger.error "Failed to delete video file #{video_path}: #{e.message}"
  end

  def cleanup_thumbnail_file
    return unless thumbnail_path.present? && File.exist?(thumbnail_path)

    File.delete(thumbnail_path)
    Rails.logger.info "Deleted thumbnail file: #{thumbnail_path}"
  rescue StandardError => e
    Rails.logger.error "Failed to delete thumbnail file #{thumbnail_path}: #{e.message}"
  end
end
