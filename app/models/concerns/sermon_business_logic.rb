# Business logic specific to Sermon operations with comprehensive logging
module SermonBusinessLogic
  extend ActiveSupport::Concern
  
  included do
    # Business rule callbacks
    after_create :log_sermon_creation_business_impact
    after_update :track_sermon_content_changes
    before_destroy :log_sermon_deletion_compliance
    
    # Business state transitions
    after_update :track_publication_status_change, if: :saved_change_to_published?
    after_update :track_denomination_change, if: :saved_change_to_denomination?
  end
  
  class_methods do
    def log_content_moderation_action(sermon_id, action, moderator_id, reason = nil)
      sermon = find(sermon_id)
      
      sermon.log_business_operation('content_moderation', {
        moderation_action: action,
        moderator_id: moderator_id,
        reason: reason,
        content_type: 'sermon',
        compliance_action: true
      })
      
      # Also log as user interaction
      sermon.log_user_interaction(moderator_id, "moderate_#{action}", {
        reason: reason,
        automated: false
      })
    end
    
    def track_bulk_import_metrics(import_session_id, imported_count, failed_count, source)
      log_business_metric('bulk_sermon_import', imported_count, {
        import_session_id: import_session_id,
        failed_count: failed_count,
        success_rate: (imported_count.to_f / (imported_count + failed_count) * 100).round(2),
        source: source
      })
    end
    
    def analyze_content_quality_trends(period = 30.days)
      start_time = period.ago
      
      {
        period: "#{start_time.to_date} to #{Date.current}",
        total_sermons: where(created_at: start_time..Time.current).count,
        average_interpretation_length: average_interpretation_length(start_time),
        scripture_coverage: analyze_scripture_coverage(start_time),
        denomination_distribution: analyze_denomination_trends(start_time),
        quality_metrics: calculate_quality_metrics(start_time)
      }
    end
  end
  
  # Sermon-specific business operations
  def publish_sermon!(publisher_id, publication_context = {})
    log_business_operation('publish_sermon') do
      update!(
        published: true,
        published_at: Time.current,
        published_by: publisher_id
      )
      
      log_state_transition('draft', 'published', publication_context.merge({
        publisher_id: publisher_id,
        publication_type: 'manual'
      }))
      
      track_publication_metrics
      
      true
    end
  end
  
  def schedule_video_generation!(requester_id, generation_options = {})
    log_business_operation('schedule_video_generation') do
      # Create video record for processing
      video = videos.create!(
        script: generate_video_script,
        status: 'pending',
        requested_by: requester_id,
        generation_options: generation_options
      )
      
      log_business_rule_execution('auto_video_generation_eligibility', 
                                  eligible_for_auto_generation?, {
        input: { sermon_id: id, content_length: interpretation&.length },
        output: { eligible: eligible_for_auto_generation?, video_id: video.id }
      })
      
      # Enqueue video processing job
      VideoProcessingJob.perform_later(video.id)
      
      video
    end
  end
  
  def moderate_content!(moderator_id, action, reason = nil)
    log_business_operation('content_moderation') do
      case action.to_s
      when 'approve'
        update!(moderation_status: 'approved', moderated_by: moderator_id, moderated_at: Time.current)
      when 'reject'
        update!(moderation_status: 'rejected', moderated_by: moderator_id, moderated_at: Time.current, rejection_reason: reason)
      when 'flag'
        update!(moderation_status: 'flagged', moderated_by: moderator_id, moderated_at: Time.current, flag_reason: reason)
      end
      
      log_state_transition(moderation_status_was, moderation_status, {
        moderator_id: moderator_id,
        reason: reason,
        compliance_action: true
      })
      
      # Track content moderation metrics
      self.class.log_business_metric('content_moderation_action', 1, {
        action: action,
        moderator_id: moderator_id,
        entity_type: 'sermon',
        automated: false
      })
    end
  end
  
  def track_engagement_metrics(user_id, engagement_type, context = {})
    log_user_interaction(user_id, engagement_type, context.merge({
      engagement_category: 'content_consumption',
      content_type: 'sermon'
    }))
    
    # Track specific engagement metrics
    case engagement_type.to_s
    when 'view'
      increment_view_count
    when 'share'
      track_sharing_metrics(context)
    when 'bookmark'
      track_bookmark_metrics(user_id, context)
    end
  end
  
  def analyze_content_accessibility
    accessibility_score = calculate_accessibility_score
    
    log_business_rule_execution('content_accessibility_check', accessibility_score, {
      input: {
        scripture_complexity: scripture_complexity_score,
        interpretation_readability: interpretation_readability_score,
        language_clarity: language_clarity_score
      },
      output: {
        accessibility_score: accessibility_score,
        recommendations: generate_accessibility_recommendations
      }
    })
    
    accessibility_score
  end
  
  def export_for_compliance(requester_id, export_format = 'json')
    log_data_access(requester_id, 'export', exportable_fields, {
      export_format: export_format,
      compliance_export: true,
      full_data_export: true
    })
    
    export_data = {
      sermon_id: id,
      exported_at: Time.current.iso8601,
      exported_by: requester_id,
      format: export_format,
      data: exportable_attributes
    }
    
    log_business_operation('compliance_data_export', {
      requester_id: requester_id,
      export_format: export_format,
      data_size_bytes: export_data.to_json.bytesize
    })
    
    export_data
  end
  
  private
  
  def log_sermon_creation_business_impact
    log_business_operation('sermon_content_created', {
      church: church,
      denomination: denomination,
      scripture_reference: scripture,
      content_length: interpretation&.length || 0,
      has_action_points: action_points.present?,
      audience_size: audience_count
    })
    
    # Track business metrics
    self.class.log_business_metric('new_sermon_created', 1, {
      church: church,
      denomination: denomination,
      content_category: categorize_content
    })
  end
  
  def track_sermon_content_changes
    return unless business_relevant_changes?
    
    log_business_operation('sermon_content_updated', {
      changed_fields: business_relevant_changes.keys,
      content_impact: assess_content_impact_level,
      requires_reprocessing: requires_video_reprocessing?
    })
    
    # Track significant content changes
    if significant_content_change?
      log_business_rule_execution('content_change_significance', true, {
        input: { changed_fields: business_relevant_changes.keys },
        output: { requires_moderation: requires_moderation_review? }
      })
    end
  end
  
  def log_sermon_deletion_compliance
    log_business_operation('sermon_deletion', {
      deletion_reason: 'user_requested', # Could be enhanced with actual reason
      had_videos: videos.exists?,
      content_preserved: false, # Could be enhanced with preservation logic
      compliance_retention_met: created_at < 7.years.ago
    })
    
    # Log compliance-relevant deletion
    if videos.exists?
      log_business_rule_execution('cascade_deletion_rule', true, {
        input: { has_dependent_videos: true },
        output: { videos_deleted: videos.count }
      })
    end
  end
  
  def track_publication_status_change
    return unless saved_change_to_published?
    
    if published?
      track_publication_metrics
    else
      log_state_transition('published', 'unpublished', {
        unpublish_reason: 'manual_action'
      })
    end
  end
  
  def track_denomination_change
    log_business_operation('denomination_reclassification', {
      from_denomination: denomination_was,
      to_denomination: denomination,
      requires_content_review: requires_denominational_content_review?
    })
  end
  
  def track_publication_metrics
    self.class.log_business_metric('sermon_published', 1, {
      church: church,
      denomination: denomination,
      time_to_publish: published_at ? (published_at - created_at) / 1.hour : nil
    })
  end
  
  def generate_video_script
    script_parts = []
    script_parts << "Title: #{title}" if title.present?
    script_parts << "Scripture: #{scripture}" if scripture.present?
    script_parts << "Pastor: #{pastor}" if pastor.present?
    script_parts << ""
    script_parts << interpretation if interpretation.present?
    script_parts << ""
    script_parts << "Action Points:" if action_points.present?
    script_parts << action_points if action_points.present?
    
    script_parts.join("\n").truncate(8000)
  end
  
  def eligible_for_auto_generation?
    interpretation.present? && 
      interpretation.length >= 500 &&
      scripture.present? &&
      moderation_status == 'approved'
  end
  
  def categorize_content
    return 'doctrinal' if interpretation&.include?('doctrine') || interpretation&.include?('theology')
    return 'practical' if action_points.present?
    return 'evangelistic' if interpretation&.include?('salvation') || interpretation&.include?('gospel')
    'general'
  end
  
  def assess_content_impact_level
    changed_fields = business_relevant_changes.keys
    
    return 'high' if changed_fields.include?('interpretation') || changed_fields.include?('scripture')
    return 'medium' if changed_fields.include?('title') || changed_fields.include?('action_points')
    'low'
  end
  
  def requires_video_reprocessing?
    business_relevant_changes.keys.intersect?(%w[interpretation scripture action_points title])
  end
  
  def significant_content_change?
    interpretation_changed = business_relevant_changes.key?('interpretation')
    scripture_changed = business_relevant_changes.key?('scripture')
    
    interpretation_changed || scripture_changed
  end
  
  def requires_moderation_review?
    # Enhanced business rule - could include AI content analysis
    significant_content_change? && published?
  end
  
  def requires_denominational_content_review?
    # Business rule for denomination changes
    denomination_was != denomination && published?
  end
  
  def increment_view_count
    # Implement view counting logic
    increment(:view_count) if respond_to?(:view_count)
  end
  
  def track_sharing_metrics(context)
    self.class.log_business_metric('sermon_shared', 1, {
      platform: context[:platform],
      church: church,
      denomination: denomination
    })
  end
  
  def track_bookmark_metrics(user_id, context)
    log_user_interaction(user_id, 'bookmark', context.merge({
      content_category: categorize_content
    }))
  end
  
  def calculate_accessibility_score
    # Simplified accessibility scoring
    score = 0
    score += 20 if scripture.present?
    score += 30 if interpretation.present? && interpretation.length.between?(500, 3000)
    score += 25 if action_points.present?
    score += 25 if title.present? && title.length < 100
    score
  end
  
  def scripture_complexity_score
    # Implement scripture complexity analysis
    return 0 unless scripture.present?
    scripture.split(/[,;]/).length * 10 # Simplified scoring
  end
  
  def interpretation_readability_score
    # Implement readability analysis (could use gem like textstat)
    return 0 unless interpretation.present?
    
    words = interpretation.split.length
    sentences = interpretation.split(/[.!?]/).length
    
    # Simplified Flesch Reading Ease approximation
    return 90 if sentences == 0
    (206.835 - (1.015 * words / sentences)).clamp(0, 100)
  end
  
  def language_clarity_score
    # Implement language clarity analysis
    return 0 unless interpretation.present?
    
    # Check for complex theological terms
    complex_terms = %w[eschatology soteriology ecclesiology pneumatology].count do |term|
      interpretation.downcase.include?(term)
    end
    
    100 - (complex_terms * 20)
  end
  
  def generate_accessibility_recommendations
    recommendations = []
    
    recommendations << "Add scripture reference" unless scripture.present?
    recommendations << "Expand interpretation" if interpretation.blank? || interpretation.length < 500
    recommendations << "Add practical action points" unless action_points.present?
    recommendations << "Simplify title" if title.present? && title.length > 100
    
    recommendations
  end
  
  def exportable_fields
    %w[title scripture pastor interpretation action_points church denomination audience_count]
  end
  
  def self.average_interpretation_length(start_time)
    where(created_at: start_time..Time.current)
      .where.not(interpretation: [nil, ''])
      .average('LENGTH(interpretation)')&.to_i || 0
  end
  
  def self.analyze_scripture_coverage(start_time)
    # Analyze which books of the Bible are being covered
    sermons = where(created_at: start_time..Time.current).where.not(scripture: [nil, ''])
    
    scripture_books = sermons.pluck(:scripture).map do |ref|
      ref.split(/\s+/).first if ref.present?
    end.compact.tally
    
    {
      unique_books: scripture_books.keys.count,
      most_referenced: scripture_books.max_by { |_, count| count }&.first,
      distribution: scripture_books
    }
  end
  
  def self.analyze_denomination_trends(start_time)
    where(created_at: start_time..Time.current)
      .where.not(denomination: [nil, ''])
      .group(:denomination)
      .count
  end
  
  def self.calculate_quality_metrics(start_time)
    sermons = where(created_at: start_time..Time.current)
    
    {
      completeness_score: calculate_completeness_score(sermons),
      has_action_points_percentage: percentage_with_action_points(sermons),
      average_content_length: sermons.average('LENGTH(interpretation)')&.to_i || 0
    }
  end
  
  def self.calculate_completeness_score(sermons)
    return 0 if sermons.count == 0
    
    complete_sermons = sermons.where.not(
      title: [nil, ''],
      scripture: [nil, ''],
      interpretation: [nil, ''],
      pastor: [nil, '']
    ).count
    
    (complete_sermons.to_f / sermons.count * 100).round(2)
  end
  
  def self.percentage_with_action_points(sermons)
    return 0 if sermons.count == 0
    
    with_action_points = sermons.where.not(action_points: [nil, '']).count
    (with_action_points.to_f / sermons.count * 100).round(2)
  end
end