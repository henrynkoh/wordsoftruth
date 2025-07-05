class TextNoteVideoJob < ApplicationJob
  queue_as :video_generation
  
  def perform(text_note_id)
    text_note = TextNote.find(text_note_id)
    
    Rails.logger.info "🎬 Starting video generation for TextNote ##{text_note_id}"
    
    begin
      text_note.update!(status: :processing)
      
      # Generate video from text note
      video_path = generate_video_from_text_note(text_note)
      
      if video_path && File.exist?(video_path)
        text_note.update!(
          status: :completed,
          video_file_path: video_path,
          processing_metadata: {
            generated_at: Time.current,
            file_size: File.size(video_path),
            generation_method: 'text_to_video',
            theme_used: text_note.theme,
            enhanced_content_used: text_note.enhanced_content.present?
          }
        )
        
        Rails.logger.info "✅ Video generation completed for TextNote ##{text_note_id}: #{video_path}"
      else
        raise "Video file not generated or not found"
      end
      
    rescue => e
      Rails.logger.error "❌ Video generation failed for TextNote ##{text_note_id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      text_note.update!(
        status: :failed,
        processing_metadata: {
          error: e.message,
          failed_at: Time.current,
          generation_method: 'text_to_video'
        }
      )
      
      # Could add notification/alert system here
      raise e
    end
  end
  
  private
  
  def generate_video_from_text_note(text_note)
    # Create configuration for video generation
    timestamp = Time.now.to_i
    output_filename = "text_note_#{text_note.id}_#{timestamp}.mp4"
    output_path = "storage/generated_videos/#{output_filename}"
    
    # Ensure output directory exists
    FileUtils.mkdir_p(File.dirname(output_path))
    
    # Use enhanced content if available, otherwise original content
    script_text = text_note.enhanced_content.presence || text_note.content
    
    # Create scripture text based on note type and theme
    scripture_text = generate_scripture_text(text_note)
    
    # Create video configuration
    video_config = {
      script_text: script_text,
      scripture_text: scripture_text,
      theme: text_note.theme,
      add_branding: true,
      output_file: output_path,
      source_type: 'text_note',
      source_id: text_note.id
    }
    
    # Save temporary config file
    config_file = "tmp/text_note_config_#{text_note.id}_#{timestamp}.json"
    File.write(config_file, JSON.pretty_generate(video_config))
    
    begin
      # Use optimized video generation
      result = system("python3 scripts/generate_spiritual_video_optimized.py #{config_file}")
      
      if result && File.exist?(output_path)
        Rails.logger.info "✅ Video generated successfully: #{output_path}"
        return output_path
      else
        Rails.logger.error "❌ Video generation command failed or file not created"
        return nil
      end
      
    ensure
      # Cleanup config file
      File.delete(config_file) if File.exist?(config_file)
    end
  end
  
  def generate_scripture_text(text_note)
    case text_note.note_type
    when 'personal_reflection'
      "개인 묵상\n\"마음의 기록\"\n진리의 말씀"
    when 'prayer_request'
      "기도 제목\n\"간구의 시간\"\n진리의 말씀"
    when 'bible_study'
      "성경 공부\n\"말씀 묵상\"\n진리의 말씀"
    when 'daily_devotion'
      if Time.current.hour < 12
        "아침 경건\n\"새로운 하루\"\n진리의 말씀"
      else
        "저녁 경건\n\"하루 마감\"\n진리의 말씀"
      end
    when 'testimony'
      "간증\n\"하나님의 은혜\"\n진리의 말씀"
    when 'sermon_note'
      "설교 노트\n\"말씀의 은혜\"\n진리의 말씀"
    else
      case text_note.theme
      when 'golden_light'
        "찬양과 경배\n\"주님께 영광\"\n진리의 말씀"
      when 'peaceful_blue'
        "기도와 묵상\n\"평안한 시간\"\n진리의 말씀"
      when 'sunset_worship'
        "저녁 경건\n\"감사의 시간\"\n진리의 말씀"
      when 'cross_pattern'
        "성경과 믿음\n\"십자가 사랑\"\n진리의 말씀"
      when 'mountain_majesty'
        "힘과 인내\n\"산의 위엄\"\n진리의 말씀"
      when 'flowing_river'
        "새로운 생명\n\"생명의 강\"\n진리의 말씀"
      when 'wheat_field'
        "풍성한 축복\n\"추수의 기쁨\"\n진리의 말씀"
      when 'shepherd_field'
        "인도하심\n\"선한 목자\"\n진리의 말씀"
      when 'temple_light'
        "예배와 경배\n\"거룩한 성전\"\n진리의 말씀"
      when 'city_lights'
        "전도와 선교\n\"세상의 빛\"\n진리의 말씀"
      else
        "영적 묵상\n\"진리의 길\"\n진리의 말씀"
      end
    end
  end
end