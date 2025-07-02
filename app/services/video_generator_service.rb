# frozen_string_literal: true

require "open3"
require "fileutils"
require "securerandom"
require "json"

class VideoGeneratorService
  # Configuration constants
  BACKGROUND_VIDEOS_DIR = Rails.root.join("storage", "background_videos").freeze
  OUTPUT_DIR = Rails.root.join("storage", "generated_videos").freeze
  TEMP_DIR = Rails.root.join("tmp", "video_processing").freeze

  # Video processing constants
  MAX_SCRIPT_LENGTH = 5000
  MAX_AUDIO_DURATION = 300 # 5 minutes
  VIDEO_WIDTH = 1080
  VIDEO_HEIGHT = 1920
  VIDEO_FPS = 30

  # Error classes
  class VideoGenerationError < StandardError; end
  class ScriptTooLongError < VideoGenerationError; end
  class AudioGenerationError < VideoGenerationError; end
  class VideoProcessingError < VideoGenerationError; end
  class UploadError < VideoGenerationError; end

  def initialize(video)
    @video = video
    @sermon = video.sermon
    @unique_id = SecureRandom.hex(8)
    validate_inputs!
    setup_directories
  end

  def generate
    Rails.logger.info "Starting video generation for video #{@video.id}"

    @video.start_processing!

    audio_file = generate_audio
    video_file = generate_video(audio_file)
    youtube_id = upload_to_youtube(video_file)

    @video.complete_upload!(youtube_id)

    Rails.logger.info "Video generation completed for video #{@video.id}"
  rescue StandardError => e
    Rails.logger.error "Error generating video #{@video.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    @video.mark_failed!(e.message)
    raise e
  ensure
    cleanup_temp_files
  end

  private

  def validate_inputs!
    raise ArgumentError, "Video is required" unless @video
    raise ArgumentError, "Sermon is required" unless @sermon
    raise ScriptTooLongError, "Script too long" if @video.script.length > MAX_SCRIPT_LENGTH
    raise ArgumentError, "Script cannot be empty" if @video.script.blank?
  end

  def setup_directories
    [ BACKGROUND_VIDEOS_DIR, OUTPUT_DIR, TEMP_DIR ].each do |dir|
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
    end
  end

  def generate_audio
    Rails.logger.info "Generating audio for video #{@video.id}"

    audio_file = TEMP_DIR.join("audio_#{@unique_id}.mp3")
    config_file = create_audio_config

    # Use a secure approach with configuration file instead of direct script injection
    execute_python_with_config("generate_audio.py", config_file)

    unless File.exist?(audio_file)
      raise AudioGenerationError, "Audio file was not created"
    end

    audio_file
  end

  def generate_video(audio_file)
    Rails.logger.info "Generating video for video #{@video.id}"

    background_video = select_background_video
    output_path = OUTPUT_DIR.join("video_#{@unique_id}.mp4")
    config_file = create_video_config(background_video, audio_file, output_path)

    # Use secure configuration-based approach
    execute_python_with_config("generate_video.py", config_file)

    unless File.exist?(output_path)
      raise VideoProcessingError, "Video file was not created"
    end

    @video.update(video_path: output_path.to_s)
    output_path
  end

  def upload_to_youtube(video_file)
    Rails.logger.info "Uploading video #{@video.id} to YouTube"

    return upload_to_youtube_api(video_file) if File.exist?(video_file)

    raise UploadError, "Video file does not exist for upload"
  end

  def select_background_video
    video_files = Dir.glob(BACKGROUND_VIDEOS_DIR.join("*.{mp4,avi,mov}"))

    if video_files.empty?
      raise VideoProcessingError, "No background videos available"
    end

    # Select a random background video or implement more sophisticated logic
    video_files.sample
  end

  def create_audio_config
    config = {
      script_text: sanitize_script(@video.script),
      output_file: TEMP_DIR.join("audio_#{@unique_id}.mp3").to_s,
      language: "ko",
      max_duration: MAX_AUDIO_DURATION,
    }

    config_file = TEMP_DIR.join("audio_config_#{@unique_id}.json")
    File.write(config_file, JSON.pretty_generate(config))
    config_file
  end

  def create_video_config(background_video, audio_file, output_path)
    config = {
      background_video: background_video.to_s,
      audio_file: audio_file.to_s,
      output_file: output_path.to_s,
      width: VIDEO_WIDTH,
      height: VIDEO_HEIGHT,
      fps: VIDEO_FPS,
      scripture_text: sanitize_scripture(@sermon.scripture),
      font: "Arial",
      text_color: "white",
      text_size: [ 900, nil ],
      text_position: [ "center", "center" ],
    }

    config_file = TEMP_DIR.join("video_config_#{@unique_id}.json")
    File.write(config_file, JSON.pretty_generate(config))
    config_file
  end

  def sanitize_script(script)
    # Remove potentially dangerous content and normalize
    sanitized = script.to_s.strip
    sanitized = sanitized.gsub(/[^\w\s\p{L}\p{P}]/, "") # Keep only word chars, spaces, letters, punctuation
    sanitized = sanitized.truncate(MAX_SCRIPT_LENGTH)
    sanitized
  end

  def sanitize_scripture(scripture)
    # Extra sanitization for scripture text that goes into video overlay
    return "" if scripture.blank?

    sanitized = scripture.to_s.strip
    sanitized = sanitized.gsub(/[<>\"'&]/, "") # Remove HTML/script dangerous chars
    sanitized = sanitized.truncate(200) # Limit length for overlay
    sanitized
  end

  def execute_python_with_config(script_name, config_file)
    script_path = Rails.root.join("scripts", script_name)
    
    unless File.exist?(script_path)
      raise VideoProcessingError, "Python script not found: #{script_path}"
    end
    
    unless File.exist?(config_file)
      raise VideoProcessingError, "Config file not found: #{config_file}"
    end
    
    # Use secure command execution with timeout
    command = [
      'timeout', '300', # 5 minute timeout
      'python3', 
      script_path.to_s,
      config_file.to_s
    ]
    
    Rails.logger.info "Executing: #{command.join(' ')}"
    
    stdout, stderr, status = Open3.capture3(*command)
    
    unless status.success?
      Rails.logger.error "Python execution failed: #{stderr}"
      raise VideoProcessingError, "Video generation failed: #{stderr}"
    end
    
    Rails.logger.info "Python execution completed successfully"
    Rails.logger.info "Output: #{stdout}" if stdout.present?
    
    { success: true, output: stdout }
  rescue Errno::ENOENT => e
    Rails.logger.error "Command not found: #{e.message}"
    raise VideoProcessingError, "Python or timeout command not available"
  rescue StandardError => e
    Rails.logger.error "Unexpected error in Python execution: #{e.message}"
    raise VideoProcessingError, "Video generation failed: #{e.message}"
  end

  def cleanup_temp_files
    Rails.logger.info "Cleaning up temp files for video #{@video.id}"

    pattern = TEMP_DIR.join("*#{@unique_id}*")
    Dir.glob(pattern).each do |file|
      File.delete(file)
      Rails.logger.debug "Deleted temp file: #{file}"
    rescue StandardError => e
      Rails.logger.error "Failed to delete temp file #{file}: #{e.message}"
    end
  end

  def upload_to_youtube_api(video_path)
    Rails.logger.info "Uploading video #{@video.id} to YouTube Shorts"
    
    # Prepare metadata for YouTube upload
    video_metadata = {
      title: generate_video_title,
      content: @sermon.interpretation,
      scripture: @sermon.scripture,
      church: @sermon.church,
      pastor: @sermon.pastor,
      source_url: @sermon.source_url
    }
    
    # Use the new YouTube upload service
    result = YoutubeUploadService.upload_shorts(video_path, video_metadata)
    
    if result[:success]
      # Update video record with YouTube information
      @video.update!(
        youtube_id: result[:youtube_id],
        youtube_url: result[:youtube_url],
        status: 'uploaded'
      )
      
      Rails.logger.info "Successfully uploaded video #{@video.id} to YouTube: #{result[:youtube_url]}"
      return result[:youtube_id]
    else
      # Handle upload failure
      error_message = result[:error] || "Unknown upload error"
      
      if result[:auth_required]
        Rails.logger.error "YouTube authentication required for video #{@video.id}"
        @video.update!(status: 'auth_required', error_message: error_message)
      else
        Rails.logger.error "YouTube upload failed for video #{@video.id}: #{error_message}"
        @video.update!(status: 'upload_failed', error_message: error_message)
      end
      
      raise UploadError, "YouTube upload failed: #{error_message}"
    end
    
  rescue => e
    Rails.logger.error "Unexpected YouTube upload error for video #{@video.id}: #{e.message}"
    @video.update!(status: 'upload_failed', error_message: e.message)
    raise UploadError, "Upload failed: #{e.message}"
  end

  private

  def generate_video_title
    title_parts = []
    title_parts << @sermon.title if @sermon.title.present?
    title_parts << @sermon.pastor if @sermon.pastor.present?
    title_parts << @sermon.church if @sermon.church.present?
    
    title = title_parts.join(" - ")
    title.truncate(100) # YouTube title limit
  end

  def generate_video_description
    description = []
    description << @sermon.title if @sermon.title.present?
    description << ""
    description << "Scripture: #{@sermon.scripture}" if @sermon.scripture.present?
    description << ""
    
    if @sermon.interpretation.present?
      description << @sermon.interpretation.truncate(500)
      description << ""
    end
    
    description << "Pastor: #{@sermon.pastor}" if @sermon.pastor.present?
    description << "Church: #{@sermon.church}" if @sermon.church.present?
    description << ""
    description << "#Sermon #Faith #Christianity #Bible"
    
    if @sermon.church.present?
      church_tag = @sermon.church.gsub(/\s+/, '').gsub(/[^a-zA-Z0-9]/, '')
      description << "##{church_tag}" if church_tag.present?
    end
    
    description.join("\n").truncate(5000) # YouTube description limit
  end

  def generate_video_tags
    tags = ['sermon', 'faith', 'christianity', 'bible', 'shorts']
    
    if @sermon.church.present?
      church_tag = @sermon.church.downcase.gsub(/\s+/, '').gsub(/[^a-z0-9]/, '')
      tags << church_tag if church_tag.present? && church_tag.length > 2
    end
    
    if @sermon.pastor.present?
      pastor_tag = @sermon.pastor.downcase.gsub(/\s+/, '').gsub(/[^a-z0-9]/, '')
      tags << pastor_tag if pastor_tag.present? && pastor_tag.length > 2
    end
    
    # Extract keywords from scripture
    if @sermon.scripture.present?
      scripture_words = @sermon.scripture.split(/\s+/)
                                        .select { |w| w.length > 3 }
                                        .map { |w| w.downcase.gsub(/[^a-z]/, '') }
                                        .select { |w| w.length > 2 }
      tags.concat(scripture_words.first(3))
    end
    
    tags.uniq.first(10) # YouTube allows max 10 tags
  end
end
