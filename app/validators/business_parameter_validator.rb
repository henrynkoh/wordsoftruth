# Comprehensive business parameter validation for all Words of Truth operations
class BusinessParameterValidator < ActiveModel::EachValidator
  
  # Business-specific validation rules
  VALIDATION_RULES = {
    sermon_title: {
      min_length: 5,
      max_length: 255,
      required_elements: [],
      forbidden_patterns: [/\b(test|sample|lorem)\b/i],
      business_rules: [:title_uniqueness_per_church, :appropriate_language]
    },
    
    scripture_reference: {
      format: /\A\d*\s*[A-Za-z]+(?:\s+\d+)?(?::\d+(?:-\d+)?)?\z/,
      valid_books: %w[Genesis Exodus Leviticus Numbers Deuteronomy Joshua Judges Ruth Samuel Kings Chronicles Ezra Nehemiah Esther Job Psalms Proverbs Ecclesiastes Song Isaiah Jeremiah Lamentations Ezekiel Daniel Hosea Joel Amos Obadiah Jonah Micah Nahum Habakkuk Zephaniah Haggai Zechariah Malachi Matthew Mark Luke John Acts Romans Corinthians Galatians Ephesians Philippians Colossians Thessalonians Timothy Titus Philemon Hebrews James Peter Jude Revelation],
      business_rules: [:canonical_book_validation, :chapter_verse_validation]
    },
    
    church_name: {
      min_length: 2,
      max_length: 100,
      format: /\A[A-Za-z\s\-'\.]+\z/,
      business_rules: [:church_name_standards, :duplicate_prevention]
    },
    
    pastor_name: {
      min_length: 2,
      max_length: 100,
      format: /\A[A-Za-z\s\-'\.]+\z/,
      business_rules: [:name_formatting, :title_validation]
    },
    
    denomination: {
      allowed_values: %w[Presbyterian Baptist Methodist Lutheran Pentecostal Episcopal Catholic Orthodox Non-denominational Other],
      business_rules: [:denomination_consistency]
    },
    
    interpretation_content: {
      min_length: 100,
      max_length: 10000,
      forbidden_patterns: [
        /<script[^>]*>/i,
        /javascript:/i,
        /\bon(load|error|click)\s*=/i
      ],
      business_rules: [:theological_appropriateness, :content_quality, :language_appropriateness]
    },
    
    action_points: {
      min_length: 20,
      max_length: 2000,
      business_rules: [:actionable_content, :practical_application]
    },
    
    audience_count: {
      min_value: 1,
      max_value: 100000,
      business_rules: [:realistic_count, :consistent_reporting]
    },
    
    video_script: {
      min_length: 50,
      max_length: 10000,
      business_rules: [:script_completeness, :appropriate_length, :content_alignment]
    },
    
    processing_priority: {
      allowed_values: %w[low medium high urgent],
      business_rules: [:priority_justification]
    },
    
    moderation_status: {
      allowed_values: %w[pending approved rejected flagged],
      business_rules: [:status_transition_validation]
    }
  }.freeze
  
  def validate_each(record, attribute, value)
    parameter_type = options[:parameter_type] || attribute.to_s
    
    # Get validation rules for this parameter type
    rules = VALIDATION_RULES[parameter_type.to_sym]
    return unless rules
    
    # Basic validations
    validate_basic_rules(record, attribute, value, rules)
    
    # Business rule validations
    validate_business_rules(record, attribute, value, rules[:business_rules] || [])
    
    # Log validation activity
    log_validation_activity(record, attribute, parameter_type, value)
  end

  private

  def validate_basic_rules(record, attribute, value, rules)
    # Length validations
    if rules[:min_length] && value.to_s.length < rules[:min_length]
      record.errors.add(attribute, "must be at least #{rules[:min_length]} characters")
    end
    
    if rules[:max_length] && value.to_s.length > rules[:max_length]
      record.errors.add(attribute, "must not exceed #{rules[:max_length]} characters")
    end
    
    # Format validation
    if rules[:format] && value.present? && !value.match?(rules[:format])
      record.errors.add(attribute, "format is invalid")
    end
    
    # Allowed values validation
    if rules[:allowed_values] && value.present? && !rules[:allowed_values].include?(value.to_s)
      record.errors.add(attribute, "must be one of: #{rules[:allowed_values].join(', ')}")
    end
    
    # Numeric validations
    if rules[:min_value] && value.to_i < rules[:min_value]
      record.errors.add(attribute, "must be at least #{rules[:min_value]}")
    end
    
    if rules[:max_value] && value.to_i > rules[:max_value]
      record.errors.add(attribute, "must not exceed #{rules[:max_value]}")
    end
    
    # Forbidden patterns
    if rules[:forbidden_patterns] && value.present?
      rules[:forbidden_patterns].each do |pattern|
        if value.match?(pattern)
          record.errors.add(attribute, "contains inappropriate content")
          break
        end
      end
    end
  end

  def validate_business_rules(record, attribute, value, business_rules)
    business_rules.each do |rule|
      case rule
      when :title_uniqueness_per_church
        validate_title_uniqueness_per_church(record, attribute, value)
      when :appropriate_language
        validate_appropriate_language(record, attribute, value)
      when :canonical_book_validation
        validate_canonical_book(record, attribute, value)
      when :chapter_verse_validation
        validate_chapter_verse(record, attribute, value)
      when :church_name_standards
        validate_church_name_standards(record, attribute, value)
      when :duplicate_prevention
        validate_duplicate_prevention(record, attribute, value)
      when :name_formatting
        validate_name_formatting(record, attribute, value)
      when :title_validation
        validate_title_validation(record, attribute, value)
      when :denomination_consistency
        validate_denomination_consistency(record, attribute, value)
      when :theological_appropriateness
        validate_theological_appropriateness(record, attribute, value)
      when :content_quality
        validate_content_quality(record, attribute, value)
      when :language_appropriateness
        validate_language_appropriateness(record, attribute, value)
      when :actionable_content
        validate_actionable_content(record, attribute, value)
      when :practical_application
        validate_practical_application(record, attribute, value)
      when :realistic_count
        validate_realistic_count(record, attribute, value)
      when :consistent_reporting
        validate_consistent_reporting(record, attribute, value)
      when :script_completeness
        validate_script_completeness(record, attribute, value)
      when :appropriate_length
        validate_appropriate_length(record, attribute, value)
      when :content_alignment
        validate_content_alignment(record, attribute, value)
      when :priority_justification
        validate_priority_justification(record, attribute, value)
      when :status_transition_validation
        validate_status_transition(record, attribute, value)
      end
    end
  end

  # Business rule implementations
  def validate_title_uniqueness_per_church(record, attribute, value)
    return unless value.present? && record.respond_to?(:church)
    
    if record.class.where(church: record.church, title: value)
                   .where.not(id: record.id).exists?
      record.errors.add(attribute, "must be unique within the church")
    end
  end

  def validate_appropriate_language(record, attribute, value)
    return unless value.present?
    
    inappropriate_words = %w[
      damn hell shit fuck crap
    ] # This would be expanded with a comprehensive list
    
    if inappropriate_words.any? { |word| value.downcase.include?(word) }
      record.errors.add(attribute, "contains inappropriate language")
    end
  end

  def validate_canonical_book(record, attribute, value)
    return unless value.present?
    
    # Extract book name from scripture reference
    book_match = value.match(/\A\d*\s*([A-Za-z]+)/)
    return unless book_match
    
    book_name = book_match[1]
    valid_books = VALIDATION_RULES[:scripture_reference][:valid_books]
    
    # Check for partial matches (e.g., "Gen" for "Genesis")
    unless valid_books.any? { |book| book.downcase.start_with?(book_name.downcase) }
      record.errors.add(attribute, "references an invalid or unrecognized book")
    end
  end

  def validate_chapter_verse(record, attribute, value)
    return unless value.present?
    
    # Validate chapter:verse format
    if value.include?(':')
      chapter_verse = value.split(':').last
      if chapter_verse.include?('-')
        # Range validation (e.g., "1-5")
        start_verse, end_verse = chapter_verse.split('-')
        if start_verse.to_i >= end_verse.to_i
          record.errors.add(attribute, "verse range is invalid")
        end
      end
    end
  end

  def validate_church_name_standards(record, attribute, value)
    return unless value.present?
    
    # Check for common church naming standards
    church_indicators = %w[church chapel cathedral temple fellowship assembly]
    
    unless church_indicators.any? { |indicator| value.downcase.include?(indicator) }
      record.errors.add(attribute, "should include a church-type identifier (Church, Chapel, etc.)")
    end
  end

  def validate_duplicate_prevention(record, attribute, value)
    return unless value.present?
    
    # Fuzzy matching for similar church names
    similar_churches = record.class.where(
      "LOWER(#{attribute}) LIKE ?", 
      "%#{value.downcase.gsub(/\s+/, '%')}%"
    ).where.not(id: record.id)
    
    if similar_churches.exists?
      record.errors.add(attribute, "is very similar to an existing church name")
    end
  end

  def validate_name_formatting(record, attribute, value)
    return unless value.present?
    
    # Check for proper name capitalization
    words = value.split
    properly_capitalized = words.all? do |word|
      word == word.capitalize || %w[of the and].include?(word.downcase)
    end
    
    unless properly_capitalized
      record.errors.add(attribute, "should be properly capitalized")
    end
  end

  def validate_title_validation(record, attribute, value)
    return unless value.present?
    
    # Check for appropriate pastoral titles
    titles = %w[Pastor Rev Reverend Dr Elder Bishop]
    has_title = titles.any? { |title| value.include?(title) }
    
    if value.length > 10 && !has_title
      record.errors.add(attribute, "should include an appropriate title (Pastor, Rev, Dr, etc.)")
    end
  end

  def validate_denomination_consistency(record, attribute, value)
    return unless value.present? && record.respond_to?(:church)
    
    # Check for consistency with other records from the same church
    if record.church.present?
      existing_denomination = record.class.where(church: record.church)
                                         .where.not(denomination: [nil, ''])
                                         .where.not(id: record.id)
                                         .pluck(:denomination)
                                         .first
      
      if existing_denomination && existing_denomination != value
        record.errors.add(attribute, "conflicts with existing denomination for this church")
      end
    end
  end

  def validate_theological_appropriateness(record, attribute, value)
    return unless value.present?
    
    # Check for controversial or problematic theological content
    concerning_phrases = [
      'prosperity gospel', 'send money', 'financial blessing',
      'curse', 'hex', 'spell', 'magic'
    ]
    
    if concerning_phrases.any? { |phrase| value.downcase.include?(phrase) }
      record.errors.add(attribute, "may contain theologically inappropriate content")
    end
  end

  def validate_content_quality(record, attribute, value)
    return unless value.present?
    
    # Basic content quality checks
    sentences = value.split(/[.!?]/).length
    words = value.split.length
    
    # Check for reasonable sentence structure
    if words > 100 && sentences < 3
      record.errors.add(attribute, "lacks proper sentence structure")
    end
    
    # Check for repetitive content
    word_frequency = value.downcase.split.tally
    most_common_count = word_frequency.values.max
    
    if most_common_count > words * 0.1
      record.errors.add(attribute, "contains excessive repetition")
    end
  end

  def validate_language_appropriateness(record, attribute, value)
    return unless value.present?
    
    # Check reading level (simplified)
    words = value.split.length
    sentences = value.split(/[.!?]/).length
    
    if sentences > 0
      avg_words_per_sentence = words.to_f / sentences
      if avg_words_per_sentence > 30
        record.errors.add(attribute, "may be too complex (very long sentences)")
      end
    end
  end

  def validate_actionable_content(record, attribute, value)
    return unless value.present?
    
    # Check for actionable language
    action_words = %w[pray read study attend give serve help volunteer share]
    
    unless action_words.any? { |word| value.downcase.include?(word) }
      record.errors.add(attribute, "should contain actionable guidance")
    end
  end

  def validate_practical_application(record, attribute, value)
    return unless value.present?
    
    # Check for practical application indicators
    practical_indicators = %w[daily weekly practice apply implement consider reflect]
    
    unless practical_indicators.any? { |indicator| value.downcase.include?(indicator) }
      record.errors.add(attribute, "should include practical application guidance")
    end
  end

  def validate_realistic_count(record, attribute, value)
    return unless value.present?
    
    count = value.to_i
    
    # Business logic for realistic audience counts
    if record.respond_to?(:church) && record.church.present?
      # Check against historical data for this church
      if record.class.respond_to?(:where)
        recent_counts = record.class.where(church: record.church)
                                   .where('created_at > ?', 3.months.ago)
                                   .where.not(audience_count: nil)
                                   .pluck(:audience_count)
        
        if recent_counts.any?
          avg_count = recent_counts.sum / recent_counts.length
          if count > avg_count * 3
            record.errors.add(attribute, "is unusually high compared to recent averages")
          end
        end
      end
    end
    
    # General reasonableness checks
    if count > 10000
      record.errors.add(attribute, "seems unrealistically high for a typical service")
    end
  end

  def validate_consistent_reporting(record, attribute, value)
    # This could check for consistency in reporting patterns
    # Implementation would depend on specific business requirements
  end

  def validate_script_completeness(record, attribute, value)
    return unless value.present?
    
    # Check for essential script elements
    required_elements = ['title', 'scripture']
    missing_elements = required_elements.reject do |element|
      value.downcase.include?(element) || 
      (record.respond_to?(:sermon) && record.sermon.send(element).present?)
    end
    
    if missing_elements.any?
      record.errors.add(attribute, "should reference essential elements: #{missing_elements.join(', ')}")
    end
  end

  def validate_appropriate_length(record, attribute, value)
    return unless value.present?
    
    # Business rule: script length should correlate with interpretation length
    if record.respond_to?(:sermon) && record.sermon.interpretation.present?
      interpretation_length = record.sermon.interpretation.length
      script_length = value.length
      
      expected_ratio = 0.8 # Script should be about 80% of interpretation
      min_expected = interpretation_length * (expected_ratio - 0.2)
      max_expected = interpretation_length * (expected_ratio + 0.2)
      
      unless script_length.between?(min_expected, max_expected)
        record.errors.add(attribute, "length doesn't align well with sermon interpretation")
      end
    end
  end

  def validate_content_alignment(record, attribute, value)
    return unless value.present?
    
    if record.respond_to?(:sermon) && record.sermon.present?
      sermon = record.sermon
      
      # Check if script includes key elements from sermon
      script_lower = value.downcase
      
      if sermon.scripture.present? && !script_lower.include?(sermon.scripture.split.first.downcase)
        record.errors.add(attribute, "should reference the sermon's scripture")
      end
      
      if sermon.title.present?
        title_words = sermon.title.downcase.split
        key_words = title_words.reject { |word| %w[a an the and or but].include?(word) }
        
        unless key_words.any? { |word| script_lower.include?(word) }
          record.errors.add(attribute, "should align with the sermon title themes")
        end
      end
    end
  end

  def validate_priority_justification(record, attribute, value)
    return unless value.present?
    
    if value == 'urgent' || value == 'high'
      # Check if high priority is justified
      if record.respond_to?(:created_at) && record.created_at && record.created_at < 1.day.ago
        record.errors.add(attribute, "high priority not justified for older content")
      end
    end
  end

  def validate_status_transition(record, attribute, value)
    return unless value.present? && record.respond_to?(:status_was)
    
    # Define valid status transitions
    valid_transitions = {
      'pending' => %w[approved rejected],
      'approved' => %w[processing rejected],
      'processing' => %w[uploaded failed],
      'rejected' => %w[pending],
      'failed' => %w[pending processing],
      'uploaded' => %w[archived]
    }
    
    old_status = record.status_was
    if old_status && valid_transitions[old_status] && !valid_transitions[old_status].include?(value)
      record.errors.add(attribute, "invalid status transition from #{old_status} to #{value}")
    end
  end

  def log_validation_activity(record, attribute, parameter_type, value)
    # Log business parameter validation for audit trail
    BusinessActivityLog.create!(
      activity_type: 'parameter_validation',
      entity_type: record.class.name,
      entity_id: record.id,
      context: {
        parameter_name: attribute.to_s,
        parameter_type: parameter_type,
        value_length: value.to_s.length,
        validation_timestamp: Time.current.iso8601,
        has_errors: record.errors[attribute].any?
      },
      performed_at: Time.current
    )
  rescue => e
    Rails.logger.error "Failed to log validation activity: #{e.message}"
  end
end

# Specific validators for different business parameters
# Note: These validators are now integrated into the main BusinessParameterValidator class
# Use BusinessParameterValidator with the appropriate :parameter_type option instead
# ChurchParameterValidator is now integrated into the main BusinessParameterValidator class