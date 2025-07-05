class TextNote < ApplicationRecord
  validates :content, presence: true, length: { minimum: 10, maximum: 800 }
  validates :title, length: { maximum: 100 }
  
  enum :theme, {
    auto_detect: 0,
    golden_light: 1,     # 찬양과 경배
    peaceful_blue: 2,    # 기도와 묵상  
    sunset_worship: 3,   # 저녁 경건시간
    cross_pattern: 4,    # 성경과 믿음
    mountain_majesty: 5, # 힘과 인내
    flowing_river: 6,    # 새로운 생명
    wheat_field: 7,      # 풍성한 축복
    shepherd_field: 8,   # 인도하심
    temple_light: 9,     # 예배와 경배
    city_lights: 10      # 전도와 선교
  }
  
  enum :status, {
    draft: 0,
    processing: 1,
    completed: 2,
    failed: 3
  }
  
  enum :note_type, {
    personal_reflection: 0,  # 개인 묵상
    prayer_request: 1,       # 기도 제목
    bible_study: 2,          # 성경 공부
    daily_devotion: 3,       # 일일 경건
    testimony: 4,            # 간증
    sermon_note: 5          # 설교 노트
  }
  
  before_save :detect_theme_and_type, if: :content_changed?
  before_save :enhance_korean_text, if: :content_changed?
  
  scope :recent, -> { order(created_at: :desc) }
  scope :completed, -> { where(status: :completed) }
  scope :by_theme, lambda { |theme_value| where(theme: theme_value) }
  
  def estimated_duration
    # Estimate video duration based on Korean text length
    # Korean TTS averages ~3-4 characters per second
    content_length = content.gsub(/\s+/, '').length
    base_duration = [content_length / 3.5, 60].min  # Max 60 seconds
    [base_duration, 10].max  # Min 10 seconds
  end
  
  def korean_character_count
    content.gsub(/[^\p{Hangul}]/, '').length
  end
  
  def has_spiritual_keywords?
    spiritual_keywords = %w[하나님 주님 예수 그리스도 성령 기도 찬양 성경 교회 믿음 사랑 은혜 축복 평안 구원]
    spiritual_keywords.any? { |keyword| content.include?(keyword) }
  end
  
  private
  
  def detect_theme_and_type
    return unless theme == 'auto_detect'
    
    # Theme detection based on keywords
    if content.match?(/찬양|경배|할렐루야|영광|찬송/)
      self.theme = :golden_light
    elsif content.match?(/기도|묵상|평안|고요|조용/)
      self.theme = :peaceful_blue
    elsif content.match?(/저녁|감사|하루|마감|소망/)
      self.theme = :sunset_worship
    elsif content.match?(/십자가|믿음|구원|성경|말씀/)
      self.theme = :cross_pattern
    elsif content.match?(/힘|인내|산|견디|강함/)
      self.theme = :mountain_majesty
    elsif content.match?(/새로운|생명|세례|거듭|새롭/)
      self.theme = :flowing_river
    elsif content.match?(/축복|풍성|감사|추수|열매/)
      self.theme = :wheat_field
    elsif content.match?(/인도|목자|보호|양|이끌/)
      self.theme = :shepherd_field
    elsif content.match?(/예배|성전|거룩|경배|예배/)
      self.theme = :temple_light
    elsif content.match?(/전도|선교|빛|증거|복음/)
      self.theme = :city_lights
    else
      self.theme = :golden_light  # Default fallback
    end
    
    # Type detection
    if content.match?(/기도|간구|간절|구하/)
      self.note_type = :prayer_request
    elsif content.match?(/성경|말씀|구절|장|절/)
      self.note_type = :bible_study
    elsif content.match?(/간증|경험|감사|은혜/)
      self.note_type = :testimony
    elsif content.match?(/오늘|아침|저녁|하루/)
      self.note_type = :daily_devotion
    elsif content.match?(/설교|목사|말씀|교회/)
      self.note_type = :sermon_note
    else
      self.note_type = :personal_reflection
    end
  end
  
  def enhance_korean_text
    return unless content.present?
    
    # Basic Korean spiritual text enhancement
    enhanced = content.dup
    
    # Add proper spiritual greetings if missing
    unless enhanced.match?(/(하나님|주님|예수)/)
      case note_type
      when 'prayer_request'
        enhanced = "하나님께 간구합니다. #{enhanced}"
      when 'daily_devotion'
        enhanced = "오늘 하루도 주님과 함께합니다. #{enhanced}"
      when 'testimony'
        enhanced = "하나님의 은혜를 간증합니다. #{enhanced}"
      else
        enhanced = "주님께 감사드립니다. #{enhanced}"
      end
    end
    
    # Add proper closing if missing
    unless enhanced.match?(/(습니다|아멘|기도합니다)\.?\s*$/)
      case note_type
      when 'prayer_request'
        enhanced += " 예수님의 이름으로 기도합니다. 아멘."
      when 'testimony'
        enhanced += " 모든 영광을 하나님께 돌립니다."
      else
        enhanced += " 주님께 감사드립니다."
      end
    end
    
    self.enhanced_content = enhanced
  end
end