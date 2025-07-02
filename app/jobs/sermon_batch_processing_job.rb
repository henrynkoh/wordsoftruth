require 'ostruct'
require 'net/http'
require 'nokogiri'

class SermonBatchProcessingJob < ApplicationJob
  queue_as :default
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(batch_id)
    Rails.logger.info "Starting batch processing for batch #{batch_id}"
    
    batch_data = Rails.cache.read("sermon_batch_#{batch_id}")
    unless batch_data
      Rails.logger.error "Batch #{batch_id} not found"
      return
    end

    batch = OpenStruct.new(batch_data)
    
    begin
      update_batch_status(batch_id, 'processing')
      log_batch_activity(batch_id, "배치 처리 시작: #{batch.total_urls}개 URL")
      
      process_sermon_urls(batch)
      
      update_batch_status(batch_id, 'completed')
      log_batch_activity(batch_id, "배치 처리 완료: #{batch.successful_videos}개 YouTube Shorts 업로드됨")
      
      Rails.logger.info "Completed batch processing for batch #{batch_id}"
      
    rescue => e
      Rails.logger.error "Error in batch processing #{batch_id}: #{e.message}"
      update_batch_status(batch_id, 'failed')
      log_batch_activity(batch_id, "오류 발생: #{e.message}")
      raise
    end
  end

  private

  def process_sermon_urls(batch)
    batch.urls.each_with_index do |url, index|
      begin
        Rails.logger.info "Processing URL #{index + 1}/#{batch.total_urls}: #{url}"
        log_batch_activity(batch.id, "처리 중: #{url}")
        
        # Step 1: Extract sermon content from URL
        sermon_data = extract_sermon_from_url(url)
        
        if sermon_data
          # Step 2: Create sermon record
          sermon = create_sermon_from_data(sermon_data)
          increment_batch_counter(batch.id, :successful_sermons)
          log_batch_activity(batch.id, "설교 생성됨: #{sermon.title}")
          
          # Step 3: Generate and process video
          video = create_and_process_video(sermon)
          
          if video && video.status == 'uploaded'
            increment_batch_counter(batch.id, :successful_videos)
            log_batch_activity(batch.id, "YouTube 업로드 완료: #{video.youtube_url}")
          else
            log_batch_activity(batch.id, "비디오 처리 실패: #{url}")
          end
        else
          increment_batch_counter(batch.id, :failed_urls)
          log_batch_activity(batch.id, "콘텐츠 추출 실패: #{url}")
        end
        
      rescue => e
        Rails.logger.error "Error processing URL #{url}: #{e.message}"
        increment_batch_counter(batch.id, :failed_urls)
        log_batch_activity(batch.id, "오류: #{url} - #{e.message}")
      ensure
        increment_batch_counter(batch.id, :processed_urls)
      end
      
      # Add a small delay between requests to be respectful
      sleep(2)
    end
  end

  def extract_sermon_from_url(url)
    # Use the existing SermonCrawlerService but adapt for single URL
    begin
      response = fetch_url_content(url)
      return nil unless response
      
      doc = Nokogiri::HTML(response)
      
      # Extract content using multiple strategies
      sermon_data = {
        title: extract_title(doc, url),
        content: extract_main_content(doc),
        scripture: extract_scripture_reference(doc),
        pastor: extract_pastor_name(doc),
        church: extract_church_name(doc, url),
        source_url: url
      }
      
      # Validate that we have minimum required content
      if sermon_data[:title].present? && sermon_data[:content].present?
        sermon_data
      else
        nil
      end
      
    rescue => e
      Rails.logger.error "Failed to extract content from #{url}: #{e.message}"
      nil
    end
  end

  def fetch_url_content(url)
    uri = URI.parse(url)
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.open_timeout = 10
    http.read_timeout = 30
    
    request = Net::HTTP::Get.new(uri.request_uri)
    request['User-Agent'] = 'Words of Truth Sermon Processor/1.0'
    
    response = http.request(request)
    
    if response.is_a?(Net::HTTPSuccess)
      response.body
    else
      Rails.logger.warn "HTTP error for #{url}: #{response.code}"
      nil
    end
  end

  def extract_title(doc, url)
    # Try multiple selectors for title
    title_selectors = [
      'h1.sermon-title',
      'h1.entry-title', 
      'h1.post-title',
      '.sermon-header h1',
      'article h1',
      'h1',
      'title'
    ]
    
    title_selectors.each do |selector|
      element = doc.css(selector).first
      if element
        title = element.text.strip
        return title if title.present? && title.length > 5
      end
    end
    
    # Fallback to page title
    page_title = doc.css('title').first&.text&.strip
    page_title.present? ? page_title : "Sermon from #{URI.parse(url).host}"
  end

  def extract_main_content(doc)
    # Try multiple selectors for main content
    content_selectors = [
      '.sermon-content',
      '.entry-content',
      '.post-content',
      'article .content',
      '.main-content',
      'main',
      '.content'
    ]
    
    content_selectors.each do |selector|
      element = doc.css(selector).first
      if element
        # Remove script and style tags
        element.css('script, style').remove
        content = element.text.strip
        return content if content.length > 100
      end
    end
    
    # Fallback: try to get text from body
    body = doc.css('body').first
    if body
      body.css('script, style, nav, footer, header, aside').remove
      content = body.text.strip
      return content if content.length > 100
    end
    
    nil
  end

  def extract_scripture_reference(doc)
    # Look for scripture references
    scripture_selectors = [
      '.scripture',
      '.bible-verse',
      '.verse',
      '.reference'
    ]
    
    scripture_selectors.each do |selector|
      element = doc.css(selector).first
      if element
        scripture = element.text.strip
        return scripture if scripture.match?(/\d*\s*[가-힣A-Za-z]+\s+\d+/i)
      end
    end
    
    # Try to find scripture in content using pattern matching
    content = doc.text
    scripture_pattern = /(요한복음|마태복음|마가복음|누가복음|로마서|고린도전서|고린도후서|갈라디아서|에베소서|빌립보서|골로새서|데살로니가전서|데살로니가후서|디모데전서|디모데후서|디도서|빌레몬서|히브리서|야고보서|베드로전서|베드로후서|요한일서|요한이서|요한삼서|유다서|요한계시록|창세기|출애굽기|레위기|민수기|신명기|여호수아|사사기|룻기|사무엘상|사무엘하|열왕기상|열왕기하|역대상|역대하|에스라|느헤미야|에스더|욥기|시편|잠언|전도서|아가|이사야|예레미야|예레미야애가|에스겔|다니엘|호세아|요엘|아모스|오바댜|요나|미가|나훔|하박국|스바냐|학개|스가랴|말라기)\s+\d+:\d+/
    
    match = content.match(scripture_pattern)
    match ? match[0] : nil
  end

  def extract_pastor_name(doc)
    # Look for pastor name
    pastor_selectors = [
      '.pastor',
      '.author',
      '.speaker',
      '.preacher'
    ]
    
    pastor_selectors.each do |selector|
      element = doc.css(selector).first
      if element
        pastor = element.text.strip
        return pastor if pastor.present? && pastor.length < 50
      end
    end
    
    # Look in meta tags
    meta_author = doc.css('meta[name="author"]').first
    if meta_author
      author = meta_author['content']&.strip
      return author if author.present? && author.length < 50
    end
    
    nil
  end

  def extract_church_name(doc, url)
    # Try to extract church name from various sources
    church_selectors = [
      '.church-name',
      '.site-title',
      '.organization'
    ]
    
    church_selectors.each do |selector|
      element = doc.css(selector).first
      if element
        church = element.text.strip
        return church if church.present? && church.length < 100
      end
    end
    
    # Try from URL hostname
    host = URI.parse(url).host
    if host
      # Remove common prefixes and suffixes
      church_name = host.gsub(/^(www\.|m\.)/, '').gsub(/\.(com|org|net|kr)$/, '')
      church_name = church_name.split('.').first
      return church_name.humanize if church_name.present?
    end
    
    "Unknown Church"
  end

  def create_sermon_from_data(sermon_data)
    # Extract interpretation and action points from content
    content = sermon_data[:content]
    
    # Simple content splitting - in production, you might use AI for better extraction
    interpretation = content.truncate(2000)
    action_points = extract_action_points(content)
    
    sermon = Sermon.new(
      title: sermon_data[:title].truncate(255),
      scripture: sermon_data[:scripture]&.truncate(1000),
      pastor: sermon_data[:pastor]&.truncate(100),
      church: sermon_data[:church]&.truncate(100),
      interpretation: interpretation,
      action_points: action_points,
      source_url: sermon_data[:source_url]
    )
    
    # Save without strict validation for automated processing
    if sermon.save
      sermon
    else
      # Force save if validation fails
      sermon.save(validate: false)
      sermon
    end
  end

  def extract_action_points(content)
    # Look for action points, practical applications, etc.
    action_indicators = ['실천', '적용', '행동', '실행', '방법', '단계']
    
    sentences = content.split(/[.!?]/)
    action_sentences = sentences.select do |sentence|
      action_indicators.any? { |indicator| sentence.include?(indicator) }
    end
    
    if action_sentences.any?
      action_sentences.first(3).join('. ').truncate(500)
    else
      "1. 말씀 묵상하기\n2. 기도로 적용하기\n3. 실천하며 살아가기"
    end
  end

  def create_and_process_video(sermon)
    return nil unless sermon
    
    # Generate script
    script = generate_video_script(sermon)
    
    # Create video record
    video = Video.new(
      sermon: sermon,
      script: script,
      status: 'pending'
    )
    
    if video.save(validate: false)
      # Approve and process
      video.update(status: 'approved', validate: false)
      
      # Process video (this will generate and upload to YouTube)
      begin
        VideoProcessingJob.perform_now([video.id])
        video.reload
        video
      rescue => e
        Rails.logger.error "Video processing failed for sermon #{sermon.id}: #{e.message}"
        video.update(status: 'failed', validate: false)
        nil
      end
    else
      nil
    end
  end

  def generate_video_script(sermon)
    script_parts = []
    script_parts << "제목: #{sermon.title}" if sermon.title.present?
    script_parts << "성경: #{sermon.scripture}" if sermon.scripture.present?
    script_parts << "목사: #{sermon.pastor}" if sermon.pastor.present?
    script_parts << ""
    script_parts << sermon.interpretation if sermon.interpretation.present?
    script_parts << ""
    script_parts << "실천사항:" if sermon.action_points.present?
    script_parts << sermon.action_points if sermon.action_points.present?
    
    script_parts.join("\n").truncate(5000)
  end

  def update_batch_status(batch_id, status)
    batch_data = Rails.cache.read("sermon_batch_#{batch_id}")
    return unless batch_data
    
    batch_data[:status] = status
    batch_data[:updated_at] = Time.current
    
    Rails.cache.write("sermon_batch_#{batch_id}", batch_data, expires_in: 24.hours)
  end

  def increment_batch_counter(batch_id, counter)
    batch_data = Rails.cache.read("sermon_batch_#{batch_id}")
    return unless batch_data
    
    batch_data[counter] = (batch_data[counter] || 0) + 1
    batch_data[:updated_at] = Time.current
    
    Rails.cache.write("sermon_batch_#{batch_id}", batch_data, expires_in: 24.hours)
  end

  def log_batch_activity(batch_id, message)
    activity_key = "batch_activity_#{batch_id}"
    activities = Rails.cache.read(activity_key) || []
    
    activities.unshift({
      timestamp: Time.current,
      message: message
    })
    
    # Keep only last 50 activities
    activities = activities.first(50)
    
    Rails.cache.write(activity_key, activities, expires_in: 24.hours)
  end
end