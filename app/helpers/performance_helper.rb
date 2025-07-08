# frozen_string_literal: true

# Performance optimization helper for caching and loading states
module PerformanceHelper
  # Cache key generation
  def cache_key_for_user_data(user, data_type, *args)
    base_key = "user_#{user.id}_#{data_type}"
    args_hash = args.any? ? "_#{Digest::MD5.hexdigest(args.join('_'))}" : ""
    "#{base_key}#{args_hash}_v1"
  end

  def cache_key_for_model(model, method_name = nil)
    key_parts = [
      model.class.name.underscore,
      model.id,
      model.updated_at.to_i
    ]
    key_parts << method_name if method_name
    key_parts.join('_')
  end

  # Fragment caching helpers
  def cache_unless_editing(cache_key, expires_in: 5.minutes, &block)
    if action_name.in?(['edit', 'new'])
      yield
    else
      cache(cache_key, expires_in: expires_in, &block)
    end
  end

  def user_specific_cache(cache_key, user = current_user, expires_in: 5.minutes, &block)
    full_key = "#{cache_key}_user_#{user&.id}"
    cache(full_key, expires_in: expires_in, &block)
  end

  # Loading state helpers
  def loading_container(type: 'spinner', message: '로딩 중...', css_class: '', data: {}, &block)
    default_data = {
      controller: 'loading-state',
      'loading-state-type-value': type,
      'loading-state-message-value': message
    }
    
    content_tag :div, 
                class: "loading-container #{css_class}",
                data: default_data.merge(data) do
      if block_given?
        content_tag(:div, capture(&block), data: { 'loading-state-target': 'content' })
      else
        # Empty container for dynamic loading
        ''
      end
    end
  end

  def skeleton_placeholder(type: 'default', css_class: '')
    content_tag :div, 
                class: "skeleton-placeholder #{css_class}",
                data: { 
                  controller: 'loading-state',
                  'loading-state-type-value': 'skeleton',
                  'skeleton-type': type
                }
  end

  def progress_tracker(job_id = nil, css_class: '', **options)
    content_tag :div, 
                class: "progress-tracker #{css_class}",
                data: {
                  controller: 'progress-tracker',
                  'progress-tracker-job-id-value': job_id,
                  **options.transform_keys { |k| "progress-tracker-#{k.to_s.dasherize}-value" }
                } do
      content_tag(:div, class: 'progress-content') do
        safe_join([
          content_tag(:div, class: 'mb-2 flex justify-between items-center') do
            safe_join([
              content_tag(:span, '처리 중...', class: 'text-sm font-medium text-gray-700', data: { 'progress-tracker-target': 'statusMessage' }),
              content_tag(:span, '0%', class: 'text-sm text-gray-500', data: { 'progress-tracker-target': 'progressText' })
            ])
          end,
          content_tag(:div, class: 'w-full bg-gray-200 rounded-full h-2.5') do
            content_tag(:div, '', class: 'bg-blue-600 h-2.5 rounded-full transition-all duration-300 ease-out', 
                       style: 'width: 0%', data: { 'progress-tracker-target': 'progressBar' })
          end,
          content_tag(:div, '', class: 'mt-2 text-xs text-gray-500', data: { 'progress-tracker-target': 'eta' })
        ])
      end
    end
  end

  # Async content loading
  def async_content(url, fallback_content = nil, css_class: '', **options)
    fallback = fallback_content || skeleton_placeholder
    
    content_tag :div, 
                class: "async-content #{css_class}",
                data: {
                  controller: 'async-content',
                  'async-content-url-value': url,
                  **options.transform_keys { |k| "async-content-#{k.to_s.dasherize}-value" }
                } do
      fallback
    end
  end

  # Performance monitoring helpers
  def time_block(description = 'Block execution', &block)
    if Rails.env.development?
      start_time = Time.current
      result = yield
      elapsed = ((Time.current - start_time) * 1000).round(2)
      Rails.logger.info "⏱️ #{description}: #{elapsed}ms"
      result
    else
      yield
    end
  end

  def measure_database_queries(&block)
    if Rails.env.development?
      queries_before = ActiveRecord::Base.connection.query_cache.size
      start_time = Time.current
      result = yield
      elapsed = ((Time.current - start_time) * 1000).round(2)
      queries_after = ActiveRecord::Base.connection.query_cache.size
      query_count = queries_after - queries_before
      
      Rails.logger.info "📊 DB Queries: #{query_count}, Time: #{elapsed}ms"
      result
    else
      yield
    end
  end

  # Image optimization helpers
  def optimized_image_tag(source, alt: nil, css_class: '', loading: 'lazy', **options)
    default_options = {
      class: "optimized-image #{css_class}",
      alt: alt,
      loading: loading,
      decoding: 'async'
    }
    
    # Add responsive srcset for different screen sizes if not provided
    unless options[:srcset]
      if source.is_a?(String) && source.include?('.')
        base_name = File.basename(source, '.*')
        extension = File.extname(source)
        base_path = source.chomp(File.basename(source))
        
        # Generate responsive srcset
        srcset_sizes = [320, 640, 768, 1024, 1280]
        srcset = srcset_sizes.map do |size|
          "#{base_path}#{base_name}_#{size}w#{extension} #{size}w"
        end.join(', ')
        
        default_options[:srcset] = srcset
        default_options[:sizes] = '(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 33vw'
      end
    end
    
    image_tag(source, **default_options.merge(options))
  end

  # Video optimization helpers  
  def video_thumbnail(video_path, css_class: '', **options)
    if video_path.present?
      # Generate thumbnail path (assuming thumbnails are generated)
      thumbnail_path = video_path.gsub(/\.(mp4|mov|avi)$/i, '_thumb.jpg')
      
      optimized_image_tag(thumbnail_path, 
                         alt: 'Video thumbnail',
                         css_class: "video-thumbnail #{css_class}",
                         **options)
    else
      # Placeholder thumbnail
      content_tag :div, 
                  class: "video-placeholder bg-gray-200 flex items-center justify-center #{css_class}" do
        content_tag :span, '🎬', class: 'text-4xl text-gray-400'
      end
    end
  end

  # Lazy loading helpers
  def lazy_component(partial_path, locals = {}, css_class: '', trigger: 'visible')
    wrapper_id = "lazy_#{SecureRandom.hex(4)}"
    
    content_tag :div, 
                id: wrapper_id,
                class: "lazy-component #{css_class}",
                data: {
                  controller: 'lazy-load',
                  'lazy-load-trigger-value': trigger,
                  'lazy-load-partial-value': partial_path,
                  'lazy-load-locals-value': locals.to_json
                } do
      skeleton_placeholder
    end
  end

  # Cache warming helpers
  def warm_cache_async(cache_keys)
    return unless Rails.env.production?
    
    # Queue cache warming job
    CacheWarmingJob.perform_later(cache_keys) if defined?(CacheWarmingJob)
  end

  # Memory optimization
  def with_memory_monitoring(description = 'Memory usage', &block)
    if Rails.env.development?
      # Simple memory monitoring
      gc_before = GC.stat
      memory_before = `ps -o rss= -p #{Process.pid}`.to_i
      
      result = yield
      
      memory_after = `ps -o rss= -p #{Process.pid}`.to_i
      gc_after = GC.stat
      
      memory_diff = memory_after - memory_before
      gc_diff = gc_after[:count] - gc_before[:count]
      
      Rails.logger.info "🧠 #{description} - Memory: #{memory_diff}KB, GC runs: #{gc_diff}"
      result
    else
      yield
    end
  end

  # CDN helpers
  def cdn_asset_url(asset_path)
    if Rails.env.production? && ENV['CDN_HOST'].present?
      "#{ENV['CDN_HOST']}/#{asset_path}"
    else
      asset_url(asset_path)
    end
  end

  def preload_critical_assets
    critical_assets = %w[
      application.css
      application.js
    ]
    
    content_for :head do
      safe_join(critical_assets.map do |asset|
        case File.extname(asset)
        when '.css'
          preload_link_tag(asset_path(asset), as: :style)
        when '.js'
          preload_link_tag(asset_path(asset), as: :script)
        end
      end.compact)
    end
  end

  # Bundle optimization
  def javascript_include_tags_optimized(*sources)
    if Rails.env.production?
      # In production, use bundled and minified assets
      javascript_include_tag(*sources, defer: true)
    else
      # In development, load individually for better debugging
      javascript_include_tag(*sources)
    end
  end

  def stylesheet_link_tags_optimized(*sources)
    if Rails.env.production?
      # In production, use bundled and minified assets with preload
      safe_join(sources.map do |source|
        preload_link_tag(asset_path(source), as: :style) +
        stylesheet_link_tag(source, media: 'print', onload: "this.media='all'")
      end)
    else
      stylesheet_link_tag(*sources)
    end
  end
end