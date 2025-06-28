class BulkSermonProcessingJob < ApplicationJob
  queue_as :heavy_processing
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  discard_on ActiveJob::DeserializationError

  def perform(church_urls, options = {})
    batch_size = options[:batch_size] || 50
    parallel_workers = options[:parallel_workers] || 3
    
    Rails.logger.info "Starting bulk sermon processing for #{church_urls.size} churches"
    
    # Process churches in batches to manage memory usage
    church_urls.each_slice(batch_size) do |church_batch|
      process_church_batch(church_batch, parallel_workers)
    end
    
    # Clean up temporary files and refresh dashboard cache
    cleanup_and_refresh_cache
    
    Rails.logger.info "Completed bulk sermon processing"
  end

  private

  def process_church_batch(church_urls, parallel_workers)
    # Use Parallel gem for concurrent processing if available, otherwise sequential
    if defined?(Parallel)
      Parallel.each(church_urls, in_threads: parallel_workers) do |church_url|
        process_single_church(church_url)
      end
    else
      church_urls.each { |church_url| process_single_church(church_url) }
    end
  end

  def process_single_church(church_url)
    church_name = extract_church_name(church_url)
    config = build_church_config(church_url)
    
    Rails.logger.info "Processing church: #{church_name}"
    
    # Use existing SermonCrawlerService with enhanced error handling
    service = SermonCrawlerService.new(church_name, config)
    result = service.crawl
    
    if result.success?
      Rails.logger.info "Successfully processed #{result.sermons_processed} sermons for #{church_name}"
      
      # Enqueue video processing for new sermons
      enqueue_video_processing_for_new_sermons(result.new_sermons)
    else
      Rails.logger.error "Failed to process church #{church_name}: #{result.error}"
    end
    
  rescue => e
    Rails.logger.error "Error processing church #{church_name}: #{e.message}"
    # Continue processing other churches even if one fails
  end

  def extract_church_name(church_url)
    URI.parse(church_url).host&.gsub(/^www\./, '')&.split('.')&.first || "unknown_church"
  rescue => e
    "church_#{Digest::MD5.hexdigest(church_url)[0..7]}"
  end

  def build_church_config(church_url)
    {
      'url' => church_url,
      'selectors' => {
        'sermon' => '.sermon, .message, .teaching',
        'title' => '.title, .sermon-title, h1, h2',
        'pastor' => '.pastor, .speaker, .preacher',
        'date' => '.date, .sermon-date, time',
        'scripture' => '.scripture, .passage, .verse',
        'interpretation' => '.content, .description, .summary',
        'audience_count' => '.audience, .attendance'
      },
      'timeout' => 30,
      'max_retries' => 2
    }
  end

  def enqueue_video_processing_for_new_sermons(new_sermons)
    return if new_sermons.blank?
    
    # Create videos for sermons that don't have them
    sermons_without_videos = new_sermons.select { |sermon| sermon.videos.empty? }
    
    sermons_without_videos.each do |sermon|
      video = Video.create!(
        sermon: sermon,
        script: generate_initial_script(sermon),
        status: 'pending'
      )
      
      # Enqueue individual video processing
      VideoProcessingJob.perform_later(video.id)
    end
    
    Rails.logger.info "Enqueued video processing for #{sermons_without_videos.size} new sermons"
  end

  def generate_initial_script(sermon)
    # Generate a basic script template
    script = []
    script << "Title: #{sermon.title}" if sermon.title.present?
    script << "Pastor: #{sermon.pastor}" if sermon.pastor.present?
    script << "Scripture: #{sermon.scripture}" if sermon.scripture.present?
    script << ""
    script << sermon.interpretation.to_s.truncate(4500) if sermon.interpretation.present?
    
    script.join("\n")
  end

  def cleanup_and_refresh_cache
    # Clear dashboard cache to reflect new data
    Rails.cache.delete("dashboard_stats")
    
    # Clean up any temporary files from processing
    temp_dirs = Dir.glob(Rails.root.join('tmp', 'sermon_processing_*'))
    temp_dirs.each do |dir|
      FileUtils.rm_rf(dir) if File.directory?(dir)
    end
    
    Rails.logger.info "Cleanup completed and cache refreshed"
  end
end
