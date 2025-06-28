# frozen_string_literal: true

class Sermon < ApplicationRecord
  include BusinessActivityLogging
  include AuditLoggingConcern
  include SensitiveDataConcern
  include SermonBusinessLogic
  
  # Associations
  has_many :videos, dependent: :destroy

  # Enhanced security and business parameter validations
  validates :title, presence: true, length: { maximum: 255 }, 
            security: { type: :content },
            business_parameter: { parameter_type: :sermon_title }
            
  validates :source_url, presence: true, uniqueness: true, 
            security: { type: :url }
            
  validates :church, presence: true, length: { maximum: 100 }, 
            security: { type: :content },
            business_parameter: { parameter_type: :church_name }
            
  validates :pastor, length: { maximum: 100 }, 
            security: { type: :content },
            business_parameter: { parameter_type: :pastor_name }
            
  validates :scripture, length: { maximum: 1000 }, 
            security: { type: :scripture_reference },
            business_parameter: { parameter_type: :scripture_reference }
            
  validates :interpretation, length: { maximum: 5000 }, 
            security: { type: :content },
            business_parameter: { parameter_type: :interpretation_content }
            
  validates :action_points, length: { maximum: 2000 }, 
            security: { type: :content },
            business_parameter: { parameter_type: :action_points }
            
  validates :denomination, length: { maximum: 50 }, 
            security: { type: :content },
            business_parameter: { parameter_type: :denomination }
            
  validates :audience_count, numericality: { greater_than: 0, allow_nil: true },
            business_parameter: { parameter_type: :audience_count }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_date, -> { order(sermon_date: :desc) }
  scope :by_church, ->(church_name) { where(church: church_name) }
  scope :by_pastor, ->(pastor_name) { where(pastor: pastor_name) }
  scope :by_denomination, ->(denomination) { where(denomination: denomination) }
  scope :with_videos, -> { joins(:videos) }
  scope :without_videos, -> { left_joins(:videos).where(videos: { id: nil }) }

  # Callbacks
  before_save :normalize_fields
  after_create :log_creation

  # Class methods
  def self.search(query)
    return none if query.blank?

    # Cache search results for common queries
    cache_key = "sermon_search_#{Digest::MD5.hexdigest(query.to_s.downcase)}"
    
    Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
      sanitized_query = "%#{sanitize_sql_like(query)}%"
      
      # Optimize search with better indexing utilization
      results = where(
        "title ILIKE ? OR scripture ILIKE ? OR pastor ILIKE ? OR interpretation ILIKE ?",
        sanitized_query, sanitized_query, sanitized_query, sanitized_query
      )
      
      # Convert to array to cache the actual results
      results.includes(:videos).to_a
    end
  end

  def self.recent_sermons(limit = 10)
    cache_key = "recent_sermons_#{limit}"
    
    Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      recent.includes(:videos).limit(limit).to_a
    end
  end
  
  # Cache frequently accessed statistics
  def self.cached_counts
    Rails.cache.fetch("sermon_counts", expires_in: 5.minutes) do
      {
        total: count,
        with_videos: with_videos.count,
        without_videos: without_videos.count,
        recent_30_days: recent.count
      }
    end
  end

  # Instance methods
  def has_video?
    videos.exists?
  end

  def pending_videos_count
    videos.pending.count
  end

  def approved_videos_count
    videos.approved.count
  end

  def uploaded_videos_count
    videos.uploaded.count
  end

  def display_date
    sermon_date&.strftime("%B %d, %Y") || "Date not available"
  end

  def display_title
    title.presence || "Untitled Sermon"
  end

  def short_description
    return scripture if scripture.present?
    return interpretation.truncate(100) if interpretation.present?

    "Sermon by #{pastor}" if pastor.present?
  end

  private

  def normalize_fields
    self.title = title&.strip
    self.pastor = pastor&.strip
    self.church = church&.strip
    self.denomination = denomination&.strip
    self.scripture = scripture&.strip
    self.interpretation = interpretation&.strip
    self.action_points = action_points&.strip
  end

  def log_creation
    Rails.logger.info "Created new sermon: #{title} by #{pastor} from #{church}"
  end
end
