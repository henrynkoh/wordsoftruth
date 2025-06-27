require 'open3'
require 'fileutils'

class VideoGeneratorService
  BACKGROUND_VIDEOS_DIR = Rails.root.join('storage', 'background_videos')
  OUTPUT_DIR = Rails.root.join('storage', 'generated_videos')
  TEMP_DIR = Rails.root.join('tmp', 'video_processing')

  def initialize(video)
    @video = video
    @sermon = video.sermon
    setup_directories
  end

  def generate
    @video.update(status: :processing)

    generate_audio
    generate_video
    upload_to_youtube

    @video.update(status: :uploaded)
  rescue StandardError => e
    Rails.logger.error "Error generating video: #{e.message}"
    @video.update(status: :failed)
    raise e
  ensure
    cleanup_temp_files
  end

  private

  def setup_directories
    [BACKGROUND_VIDEOS_DIR, OUTPUT_DIR, TEMP_DIR].each do |dir|
      FileUtils.mkdir_p(dir)
    end
  end

  def generate_audio
    script_file = TEMP_DIR.join("script_#{@video.id}.txt")
    audio_file = TEMP_DIR.join("audio_#{@video.id}.mp3")

    File.write(script_file, @video.script)

    command = <<~PYTHON
      import sys
      from gtts import gTTS
      
      text = open('#{script_file}', 'r').read()
      tts = gTTS(text=text, lang='ko')
      tts.save('#{audio_file}')
    PYTHON

    execute_python(command)
  end

  def generate_video
    background_video = select_background_video
    output_path = OUTPUT_DIR.join("video_#{@video.id}.mp4")
    audio_file = TEMP_DIR.join("audio_#{@video.id}.mp3")

    command = <<~PYTHON
      import sys
      from moviepy.editor import *
      
      # Load the background video and audio
      background = VideoFileClip('#{background_video}')
      audio = AudioFileClip('#{audio_file}')
      
      # Resize background video to vertical format (9:16 aspect ratio)
      background = background.resize(height=1920)
      background = background.crop(x_center=background.w/2, width=1080)
      
      # Loop the background video if needed
      if background.duration < audio.duration:
          background = background.loop(duration=audio.duration)
      else:
          background = background.subclip(0, audio.duration)
      
      # Add audio to video
      final = background.set_audio(audio)
      
      # Add text overlay
      txt = TextClip(
          "#{@sermon.scripture}",
          font='Arial',
          color='white',
          size=(900, None),
          method='caption'
      ).set_position(('center', 'center'))
      
      final = CompositeVideoClip([final, txt])
      
      # Write the result
      final.write_videofile(
          '#{output_path}',
          codec='libx264',
          audio_codec='aac',
          temp_audiofile='temp-audio.m4a',
          remove_temp=True,
          fps=30
      )
    PYTHON

    execute_python(command)
    @video.update(video_path: output_path.to_s)
  end

  def upload_to_youtube
    return unless @video.video_path && File.exist?(@video.video_path)

    # Implement YouTube upload logic here using the YouTube Data API
    # This is a placeholder - you'll need to implement the actual upload logic
    youtube_id = upload_to_youtube_api(@video.video_path)
    @video.update(youtube_id: youtube_id) if youtube_id
  end

  def select_background_video
    # Implement logic to select an appropriate background video
    # For now, just return the first video in the directory
    Dir.glob(BACKGROUND_VIDEOS_DIR.join('*.mp4')).first
  end

  def execute_python(command)
    temp_script = TEMP_DIR.join("script_#{Time.now.to_i}_#{rand(1000)}.py")
    File.write(temp_script, command)

    stdout, stderr, status = Open3.capture3("python3", temp_script.to_s)

    unless status.success?
      Rails.logger.error "Python script error: #{stderr}"
      raise "Python script failed: #{stderr}"
    end

    File.delete(temp_script)
  end

  def cleanup_temp_files
    Dir.glob(TEMP_DIR.join("*_#{@video.id}.*")).each do |file|
      File.delete(file)
    end
  end

  def upload_to_youtube_api(video_path)
    # TODO: Implement actual YouTube upload logic
    # This is a placeholder that should be replaced with actual YouTube API integration
    "dummy_youtube_id_#{Time.now.to_i}"
  end
end 