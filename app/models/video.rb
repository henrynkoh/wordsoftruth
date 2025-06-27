class Video < ApplicationRecord
  belongs_to :sermon

  validates :script, presence: true
  validates :status, presence: true

  # Define status as a string enum
  enum :status, {
    pending: "pending",
    approved: "approved",
    processing: "processing",
    uploaded: "uploaded",
    failed: "failed"
  }, default: "pending"

  # Define scopes for each status
  scope :pending, -> { where(status: "pending") }
  scope :approved, -> { where(status: "approved") }
  scope :processing, -> { where(status: "processing") }
  scope :uploaded, -> { where(status: "uploaded") }
  scope :failed, -> { where(status: "failed") }

  def youtube_url
    "https://www.youtube.com/watch?v=#{youtube_id}" if youtube_id.present?
  end
end
