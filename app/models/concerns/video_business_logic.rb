# Business logic specific to Video operations with comprehensive logging
module VideoBusinessLogic
  extend ActiveSupport::Concern
  
  included do
    # Business state transition callbacks
    after_update :track_status_transitions, if: :saved_change_to_status?
    after_update :track_processing_metrics, if: :saved_change_to_processing_started_at?
    after_update :track_upload_completion, if: :saved_change_to_youtube_id?
    
    # Quality and performance tracking
    after_create :log_video_creation_request
    after_update :track_processing_performance, if: :processing_completed?
  end
  
  class_methods do
    def track_batch_processing_metrics(batch_id, processed_count, failed_count, duration_ms)
      log_business_metric('batch_video_processing', processed_count, {
        batch_id: batch_id,
        failed_count: failed_count,
        success_rate: (processed_count.to_f / (processed_count + failed_count) * 100).round(2),
        total_duration_ms: duration_ms,
        avg_processing_time_ms: duration_ms / (processed_count + failed_count)
      })
    end
    
    def analyze_processing_pipeline_performance(period = 7.days)
      start_time = period.ago
      videos = where(created_at: start_time..Time.current)
      
      {
        period: "#{start_time.to_date} to #{Date.current}",
        total_videos_processed: videos.where.not(status: 'pending').count,
        success_rate: calculate_success_rate(videos),
        average_processing_time: calculate_average_processing_time(videos),
        bottleneck_analysis: identify_processing_bottlenecks(videos),
        quality_metrics: analyze_output_quality(videos)
      }
    end
    
    def compliance_processing_report(period = 30.days)
      start_time = period.ago
      
      {
        period: "#{start_time.to_date} to #{Date.current}",
        total_videos: where(created_at: start_time..Time.current).count,
        automated_processing: count_automated_processing(start_time),
        manual_interventions: count_manual_interventions(start_time),
        failed_processing_analysis: analyze_processing_failures(start_time),
        data_retention_compliance: check_retention_compliance(start_time)
      }
    end
  end
  
  # Video-specific business operations
  def approve_for_processing!(approver_id, approval_context = {})
    log_business_operation('approve_video_processing') do
      update!(
        status: 'approved',
        approved_at: Time.current,
        approved_by: approver_id
      )
      
      log_state_transition('pending', 'approved', approval_context.merge({
        approver_id: approver_id,
        approval_type: 'manual'
      }))
      
      # Track approval metrics
      self.class.log_business_metric('video_approval', 1, {
        approver_id: approver_id,
        sermon_church: sermon.church,
        sermon_denomination: sermon.denomination,
        approval_time_hours: ((approved_at - created_at) / 1.hour).round(2)
      })
      
      true
    end
  end
  
  def start_processing!(processor_id = 'system')
    log_business_operation('start_video_processing') do
      update!(
        status: 'processing',
        processing_started_at: Time.current,
        processed_by: processor_id
      )
      
      log_state_transition('approved', 'processing', {
        processor_id: processor_id,
        processing_queue: determine_processing_queue,
        estimated_duration_minutes: estimate_processing_duration
      })
      
      # Track processing queue metrics
      track_processing_queue_metrics
      
      true
    end
  end
  
  def complete_processing!(completion_data = {})
    log_business_operation('complete_video_processing') do
      processing_duration = Time.current - processing_started_at if processing_started_at
      
      update!(
        status: 'uploaded',
        processing_completed_at: Time.current,
        youtube_id: completion_data[:youtube_id],
        video_file_path: completion_data[:video_path],
        thumbnail_path: completion_data[:thumbnail_path],
        processing_duration_seconds: processing_duration&.to_i
      )
      
      log_state_transition('processing', 'uploaded', completion_data.merge({
        processing_duration_seconds: processing_duration&.to_i,
        output_quality: assess_output_quality(completion_data)
      }))
      
      # Track successful processing metrics
      track_successful_processing_metrics(processing_duration, completion_data)
      
      true
    end
  end
  
  def fail_processing!(error_details = {})
    log_business_operation('fail_video_processing') do
      processing_duration = Time.current - processing_started_at if processing_started_at
      
      update!(
        status: 'failed',
        processing_failed_at: Time.current,
        error_message: error_details[:error_message],
        retry_count: (retry_count || 0) + 1
      )
      
      log_state_transition('processing', 'failed', error_details.merge({
        processing_duration_seconds: processing_duration&.to_i,
        retry_count: retry_count,
        error_category: categorize_error(error_details[:error_message])
      }))
      
      # Track failure metrics
      track_processing_failure_metrics(error_details)
      
      # Determine if retry is warranted
      log_business_rule_execution('processing_retry_eligibility', 
                                  retry_eligible?, {
        input: { 
          retry_count: retry_count, 
          error_category: categorize_error(error_details[:error_message]),
          processing_duration: processing_duration 
        },
        output: { 
          retry_eligible: retry_eligible?,
          next_retry_at: calculate_next_retry_time
        }
      })
      
      true
    end
  end
  
  def track_user_engagement(user_id, engagement_type, engagement_data = {})
    log_user_interaction(user_id, engagement_type, engagement_data.merge({
      video_status: status,
      sermon_church: sermon.church,
      content_type: 'video',
      engagement_category: 'media_consumption'
    }))
    
    # Track specific engagement metrics
    case engagement_type.to_s
    when 'play'
      track_video_play_metrics(user_id, engagement_data)
    when 'complete'
      track_video_completion_metrics(user_id, engagement_data)
    when 'share'
      track_video_sharing_metrics(user_id, engagement_data)
    end
  end
  
  def analyze_content_accessibility
    accessibility_metrics = {
      has_captions: video_file_path.present?, # Simplified check
      script_readability: calculate_script_readability,
      duration_appropriateness: assess_duration_appropriateness,
      visual_clarity_score: assess_visual_clarity
    }
    
    overall_score = calculate_accessibility_score(accessibility_metrics)
    
    log_business_rule_execution('video_accessibility_assessment', overall_score, {
      input: accessibility_metrics,
      output: {
        accessibility_score: overall_score,
        accessibility_grade: grade_accessibility(overall_score),
        improvement_recommendations: generate_accessibility_recommendations(accessibility_metrics)
      }
    })
    
    accessibility_metrics.merge(overall_score: overall_score)
  end
  
  def archive_for_retention!(archival_reason = 'retention_policy')
    log_business_operation('archive_video') do
      update!(
        status: 'archived',
        archived_at: Time.current,
        archival_reason: archival_reason
      )
      
      log_state_transition(status_was, 'archived', {
        archival_reason: archival_reason,
        compliance_driven: retention_policy_triggered?,
        data_preserved: archive_data_preservation_status
      })
      
      # Track archival metrics
      self.class.log_business_metric('video_archived', 1, {
        archival_reason: archival_reason,
        age_days: (Time.current - created_at) / 1.day,
        had_youtube_upload: youtube_id.present?
      })
      
      true
    end
  end
  
  private
  
  def log_video_creation_request
    log_business_operation('video_creation_requested', {
      sermon_id: sermon.id,
      sermon_church: sermon.church,
      sermon_denomination: sermon.denomination,
      script_length: script&.length || 0,
      request_source: determine_request_source,
      automated_request: automated_creation?
    })
    
    # Track video creation metrics
    self.class.log_business_metric('video_creation_request', 1, {
      church: sermon.church,
      denomination: sermon.denomination,
      script_length_category: categorize_script_length,
      automated: automated_creation?
    })
  end
  
  def track_status_transitions
    from_status = status_was
    to_status = status
    
    log_state_transition(from_status, to_status, {
      transition_duration_hours: calculate_transition_duration(from_status),
      business_context: determine_business_context
    })
    
    # Track specific transition metrics
    case "#{from_status}_to_#{to_status}"
    when 'pending_to_approved'
      track_approval_metrics
    when 'approved_to_processing'
      track_processing_start_metrics
    when 'processing_to_uploaded'
      track_upload_success_metrics
    when 'processing_to_failed'
      track_processing_failure_metrics
    end
  end
  
  def track_processing_metrics
    return unless processing_started_at && processing_started_at_changed?
    
    queue_wait_time = processing_started_at - (approved_at || created_at)
    
    log_business_operation('processing_queue_metrics', {
      queue_wait_time_minutes: (queue_wait_time / 1.minute).round(2),
      queue_position_estimated: estimate_queue_position,
      processing_priority: determine_processing_priority
    })
  end
  
  def track_upload_completion
    return unless youtube_id && youtube_id_changed?
    
    total_duration = Time.current - created_at
    processing_duration = processing_completed_at ? (processing_completed_at - processing_started_at) : nil
    
    log_business_operation('video_upload_completed', {
      total_duration_hours: (total_duration / 1.hour).round(2),
      processing_duration_minutes: processing_duration ? (processing_duration / 1.minute).round(2) : nil,
      youtube_id: youtube_id,
      upload_success: true
    })
  end
  
  def processing_completed?
    saved_change_to_processing_completed_at? && processing_completed_at.present?
  end
  
  def track_processing_performance
    return unless processing_started_at && processing_completed_at
    
    processing_time = processing_completed_at - processing_started_at
    script_length = script&.length || 0
    
    # Performance analysis
    performance_score = calculate_processing_performance_score(processing_time, script_length)
    
    log_business_rule_execution('processing_performance_analysis', performance_score, {
      input: {
        processing_time_minutes: (processing_time / 1.minute).round(2),
        script_length: script_length,
        complexity_factors: identify_complexity_factors
      },
      output: {
        performance_score: performance_score,
        performance_grade: grade_performance(performance_score),
        optimization_opportunities: identify_optimization_opportunities(processing_time)
      }
    })
  end
  
  def track_processing_queue_metrics
    self.class.log_business_metric('processing_queue_entry', 1, {
      queue_name: determine_processing_queue,
      estimated_wait_time_minutes: estimate_queue_wait_time,
      priority_level: determine_processing_priority
    })
  end
  
  def track_successful_processing_metrics(duration, completion_data)
    self.class.log_business_metric('video_processing_success', 1, {
      processing_duration_minutes: duration ? (duration / 1.minute).round(2) : nil,
      output_quality_score: assess_output_quality(completion_data),
      script_length: script&.length || 0,
      church: sermon.church
    })
  end
  
  def track_processing_failure_metrics(error_details = {})
    self.class.log_business_metric('video_processing_failure', 1, {
      error_category: categorize_error(error_details[:error_message]),
      retry_count: retry_count || 0,
      script_length: script&.length || 0,
      church: sermon.church
    })
  end
  
  def track_video_play_metrics(user_id, engagement_data)
    self.class.log_business_metric('video_play', 1, {
      user_id: user_id,
      video_duration_seconds: engagement_data[:duration],
      platform: engagement_data[:platform] || 'web',
      church: sermon.church
    })
  end
  
  def track_video_completion_metrics(user_id, engagement_data)
    self.class.log_business_metric('video_completion', 1, {
      user_id: user_id,
      completion_percentage: engagement_data[:completion_percentage] || 100,
      watch_time_seconds: engagement_data[:watch_time],
      church: sermon.church
    })
  end
  
  def track_video_sharing_metrics(user_id, engagement_data)
    self.class.log_business_metric('video_share', 1, {
      user_id: user_id,
      platform: engagement_data[:platform],
      church: sermon.church,
      denomination: sermon.denomination
    })
  end
  
  def determine_processing_queue
    return 'priority' if sermon.church == 'Priority Church'
    return 'express' if script&.length && script.length < 1000
    'standard'
  end
  
  def estimate_processing_duration
    base_time = 5 # 5 minutes base
    script_factor = (script&.length || 0) / 1000.0
    complexity_factor = identify_complexity_factors.length * 0.5
    
    (base_time + script_factor + complexity_factor).round
  end
  
  def assess_output_quality(completion_data)
    quality_score = 70 # Base score
    
    quality_score += 10 if completion_data[:video_path].present?
    quality_score += 10 if completion_data[:thumbnail_path].present?
    quality_score += 10 if completion_data[:youtube_id].present?
    
    quality_score.clamp(0, 100)
  end
  
  def categorize_error(error_message)
    return 'timeout' if error_message&.include?('timeout')
    return 'memory' if error_message&.include?('memory')
    return 'network' if error_message&.include?('network') || error_message&.include?('connection')
    return 'validation' if error_message&.include?('validation') || error_message&.include?('invalid')
    'unknown'
  end
  
  def retry_eligible?
    return false if retry_count && retry_count >= 3
    return false if error_message&.include?('permanent')
    true
  end
  
  def calculate_next_retry_time
    return nil unless retry_eligible?
    
    base_delay = 15.minutes
    exponential_backoff = base_delay * (2 ** (retry_count || 0))
    Time.current + exponential_backoff
  end
  
  def calculate_script_readability
    return 0 unless script.present?
    
    # Simplified readability calculation
    words = script.split.length
    sentences = script.split(/[.!?]/).length
    
    return 90 if sentences == 0
    (206.835 - (1.015 * words / sentences)).clamp(0, 100)
  end
  
  def assess_duration_appropriateness
    # Assess if video duration is appropriate for content
    script_length = script&.length || 0
    estimated_duration = script_length / 150 # Rough words per minute
    
    case estimated_duration
    when 0..5 then 100
    when 5..15 then 90
    when 15..30 then 70
    else 50
    end
  end
  
  def assess_visual_clarity
    # Simplified visual clarity assessment
    return 0 unless video_file_path.present?
    
    # Could be enhanced with actual video analysis
    80 # Placeholder score
  end
  
  def calculate_accessibility_score(metrics)
    weights = {
      has_captions: 0.3,
      script_readability: 0.3,
      duration_appropriateness: 0.2,
      visual_clarity_score: 0.2
    }
    
    score = 0
    metrics.each do |key, value|
      next unless weights[key]
      
      normalized_value = value.is_a?(TrueClass) ? 100 : (value.is_a?(FalseClass) ? 0 : value)
      score += (normalized_value * weights[key])
    end
    
    score.round
  end
  
  def grade_accessibility(score)
    case score
    when 90..100 then 'A'
    when 80..89 then 'B'
    when 70..79 then 'C'
    when 60..69 then 'D'
    else 'F'
    end
  end
  
  def generate_accessibility_recommendations(metrics)
    recommendations = []
    
    recommendations << "Add captions or subtitles" unless metrics[:has_captions]
    recommendations << "Simplify script language" if metrics[:script_readability] < 70
    recommendations << "Consider breaking into shorter segments" if metrics[:duration_appropriateness] < 70
    recommendations << "Improve visual quality" if metrics[:visual_clarity_score] < 70
    
    recommendations
  end
  
  def retention_policy_triggered?
    created_at < 7.years.ago
  end
  
  def archive_data_preservation_status
    {
      video_file_preserved: video_file_path.present?,
      metadata_preserved: true,
      youtube_link_preserved: youtube_id.present?
    }
  end
  
  def determine_request_source
    # Could be enhanced to track actual source
    'web_interface'
  end
  
  def automated_creation?
    # Logic to determine if this was an automated request
    false # Placeholder
  end
  
  def categorize_script_length
    length = script&.length || 0
    
    case length
    when 0..500 then 'short'
    when 501..2000 then 'medium'
    when 2001..5000 then 'long'
    else 'very_long'
    end
  end
  
  def calculate_transition_duration(from_status)
    case from_status
    when 'pending'
      approved_at ? ((approved_at - created_at) / 1.hour).round(2) : nil
    when 'approved'
      processing_started_at ? ((processing_started_at - approved_at) / 1.hour).round(2) : nil
    when 'processing'
      processing_completed_at ? ((processing_completed_at - processing_started_at) / 1.hour).round(2) : nil
    end
  end
  
  def determine_business_context
    {
      sermon_church: sermon.church,
      sermon_denomination: sermon.denomination,
      script_length_category: categorize_script_length,
      processing_queue: determine_processing_queue
    }
  end
  
  def track_approval_metrics
    approval_time = approved_at ? (approved_at - created_at) : nil
    
    self.class.log_business_metric('video_approval_time', approval_time ? (approval_time / 1.hour).round(2) : nil, {
      church: sermon.church,
      script_length_category: categorize_script_length
    }) if approval_time
  end
  
  def track_processing_start_metrics
    queue_wait_time = processing_started_at && approved_at ? (processing_started_at - approved_at) : nil
    
    self.class.log_business_metric('processing_queue_wait_time', queue_wait_time ? (queue_wait_time / 1.minute).round(2) : nil, {
      processing_queue: determine_processing_queue,
      church: sermon.church
    }) if queue_wait_time
  end
  
  def track_upload_success_metrics
    if youtube_id.present?
      self.class.log_business_metric('youtube_upload_success', 1, {
        church: sermon.church,
        processing_duration_minutes: processing_duration_seconds ? (processing_duration_seconds / 60.0).round(2) : nil
      })
    end
  end
  
  def estimate_queue_position
    # Simplified queue position estimation
    Video.where(status: 'approved', created_at: ..created_at).count + 1
  end
  
  def determine_processing_priority
    return 'high' if sermon.church == 'Priority Church'
    return 'medium' if created_at > 1.day.ago
    'low'
  end
  
  def estimate_queue_wait_time
    queue_position = estimate_queue_position
    average_processing_time = 10 # minutes
    
    queue_position * average_processing_time
  end
  
  def identify_complexity_factors
    factors = []
    factors << 'long_script' if script&.length && script.length > 3000
    factors << 'special_characters' if script&.match?(/[^\w\s\.,!?;:]/)
    factors << 'multiple_languages' if script&.match?(/[가-힣]/) # Korean characters
    factors
  end
  
  def calculate_processing_performance_score(processing_time, script_length)
    # Performance scoring based on processing efficiency
    expected_time = estimate_processing_duration * 60 # Convert to seconds
    efficiency_ratio = expected_time / processing_time.to_f
    
    (efficiency_ratio * 100).clamp(0, 150).round
  end
  
  def grade_performance(score)
    case score
    when 120..150 then 'Excellent'
    when 100..119 then 'Good'
    when 80..99 then 'Average'
    when 60..79 then 'Below Average'
    else 'Poor'
    end
  end
  
  def identify_optimization_opportunities(processing_time)
    opportunities = []
    
    if processing_time > 20.minutes
      opportunities << 'Consider parallel processing'
    end
    
    if script&.length && script.length > 4000
      opportunities << 'Script segmentation could improve processing'
    end
    
    opportunities << 'Caching optimization' if identify_complexity_factors.include?('special_characters')
    
    opportunities
  end
  
  def self.calculate_success_rate(videos)
    total = videos.where.not(status: 'pending').count
    return 0 if total == 0
    
    successful = videos.where(status: 'uploaded').count
    (successful.to_f / total * 100).round(2)
  end
  
  def self.calculate_average_processing_time(videos)
    processing_times = videos.where.not(processing_duration_seconds: nil)
                            .pluck(:processing_duration_seconds)
    
    return 0 if processing_times.empty?
    (processing_times.sum / processing_times.length / 60.0).round(2) # Convert to minutes
  end
  
  def self.identify_processing_bottlenecks(videos)
    {
      approval_bottleneck: videos.where(status: 'pending').count,
      processing_bottleneck: videos.where(status: 'processing').count,
      upload_bottleneck: videos.where(status: 'failed').count
    }
  end
  
  def self.analyze_output_quality(videos)
    uploaded_videos = videos.where(status: 'uploaded')
    
    {
      videos_with_youtube_links: uploaded_videos.where.not(youtube_id: nil).count,
      videos_with_thumbnails: uploaded_videos.where.not(thumbnail_path: nil).count,
      average_processing_duration: calculate_average_processing_time(uploaded_videos)
    }
  end
  
  def self.count_automated_processing(start_time)
    # Count videos that went through automated processing
    where(created_at: start_time..Time.current)
      .where(processed_by: 'system')
      .count
  end
  
  def self.count_manual_interventions(start_time)
    # Count videos that required manual intervention
    where(created_at: start_time..Time.current)
      .where.not(processed_by: 'system')
      .count
  end
  
  def self.analyze_processing_failures(start_time)
    failed_videos = where(status: 'failed', created_at: start_time..Time.current)
    
    {
      total_failures: failed_videos.count,
      failure_rate: calculate_failure_rate(start_time),
      common_error_categories: categorize_failures(failed_videos),
      retry_analysis: analyze_retry_patterns(failed_videos)
    }
  end
  
  def self.check_retention_compliance(start_time)
    old_videos = where('created_at < ?', 7.years.ago)
    
    {
      videos_subject_to_retention: old_videos.count,
      videos_archived: old_videos.where(status: 'archived').count,
      compliance_percentage: old_videos.count > 0 ? (old_videos.where(status: 'archived').count.to_f / old_videos.count * 100).round(2) : 100
    }
  end
  
  def self.calculate_failure_rate(start_time)
    total = where(created_at: start_time..Time.current).where.not(status: 'pending').count
    return 0 if total == 0
    
    failed = where(status: 'failed', created_at: start_time..Time.current).count
    (failed.to_f / total * 100).round(2)
  end
  
  def self.categorize_failures(failed_videos)
    categories = Hash.new(0)
    
    failed_videos.pluck(:error_message).compact.each do |error|
      category = case error
                 when /timeout/ then 'timeout'
                 when /memory/ then 'memory'
                 when /network/ then 'network'
                 when /validation/ then 'validation'
                 else 'unknown'
                 end
      categories[category] += 1
    end
    
    categories
  end
  
  def self.analyze_retry_patterns(failed_videos)
    retry_counts = failed_videos.pluck(:retry_count).compact
    
    {
      videos_with_retries: retry_counts.count { |count| count > 0 },
      average_retry_count: retry_counts.any? ? (retry_counts.sum.to_f / retry_counts.length).round(2) : 0,
      max_retries_reached: retry_counts.count { |count| count >= 3 }
    }
  end
end