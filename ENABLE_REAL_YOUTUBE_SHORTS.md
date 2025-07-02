# 🎬 How to Enable Real YouTube Shorts

## 🚀 **Complete Implementation Guide**

To see actual YouTube Shorts being generated and uploaded, you need to implement 6 key components:

---

## **1. 🔑 YouTube API Setup**

### **A. Get Google Cloud Credentials**
```bash
# 1. Go to Google Cloud Console
# https://console.cloud.google.com/

# 2. Create or select project
# 3. Enable YouTube Data API v3
# 4. Create OAuth 2.0 credentials
# 5. Download credentials JSON
```

### **B. Install YouTube API Dependencies**
```ruby
# Add to Gemfile
gem 'google-api-client', '~> 0.53.0'
gem 'googleauth', '~> 1.0'

# Install
bundle install
```

### **C. Configure Environment Variables**
```bash
# Add to .env
YOUTUBE_CLIENT_ID=your_client_id_here
YOUTUBE_CLIENT_SECRET=your_client_secret_here
YOUTUBE_REDIRECT_URI=http://localhost:3000/auth/youtube/callback
GOOGLE_APPLICATION_CREDENTIALS=path/to/credentials.json
```

---

## **2. 🎥 Video Processing Dependencies**

### **A. Install FFmpeg**
```bash
# macOS
brew install ffmpeg

# Ubuntu
sudo apt update
sudo apt install ffmpeg

# Verify installation
ffmpeg -version
```

### **B. Install Python Dependencies**
```bash
# Create requirements.txt
cat > requirements.txt << EOF
moviepy==1.0.3
gTTS==2.3.1
Pillow==10.0.0
numpy==1.24.3
opencv-python==4.8.0.74
pydub==0.25.1
EOF

# Install
pip install -r requirements.txt
```

### **C. Install Text-to-Speech Engine**
```bash
# For Korean TTS support
pip install gTTS
pip install pygame  # For audio playback testing
```

---

## **3. 🔧 Replace Mock Implementation**

### **A. Real YouTube Upload Service**
Create `app/services/youtube_upload_service.rb`:

```ruby
require 'google/apis/youtube_v3'
require 'googleauth'

class YouTubeUploadService
  def initialize
    @youtube = Google::Apis::YoutubeV3::YouTubeService.new
    @youtube.authorization = authorize
  end

  def upload_video(video_path, title, description, tags = [])
    video_object = Google::Apis::YoutubeV3::Video.new(
      snippet: Google::Apis::YoutubeV3::VideoSnippet.new(
        title: title,
        description: description,
        tags: tags,
        category_id: '22', # People & Blogs
        default_language: 'ko'
      ),
      status: Google::Apis::YoutubeV3::VideoStatus.new(
        privacy_status: 'public',
        made_for_kids: false
      )
    )

    result = @youtube.insert_video(
      'snippet,status',
      video_object,
      upload_source: video_path,
      content_type: 'video/mp4'
    )

    result.id
  rescue Google::Apis::Error => e
    Rails.logger.error "YouTube upload failed: #{e.message}"
    raise UploadError, "Failed to upload to YouTube: #{e.message}"
  end

  private

  def authorize
    authorizer = Google::Auth::UserAuthorizer.new(
      Google::Auth::ClientId.from_file(ENV['GOOGLE_APPLICATION_CREDENTIALS']),
      Google::Apis::YoutubeV3::AUTH_YOUTUBE_UPLOAD,
      'file:///tmp/youtube_token_store.yaml'
    )

    user_id = 'default'
    credentials = authorizer.get_credentials(user_id)
    
    unless credentials
      url = authorizer.get_authorization_url(base_url: ENV['YOUTUBE_REDIRECT_URI'])
      puts "Visit: #{url}"
      puts "Enter authorization code:"
      code = gets.chomp
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id, 
        code: code, 
        base_url: ENV['YOUTUBE_REDIRECT_URI']
      )
    end

    credentials
  end
end
```

### **B. Update Video Generator Service**
Replace the mock method in `app/services/video_generator_service.rb`:

```ruby
def upload_to_youtube_api(video_path)
  uploader = YouTubeUploadService.new
  
  title = generate_video_title
  description = generate_video_description
  tags = generate_video_tags

  youtube_id = uploader.upload_video(video_path, title, description, tags)
  
  Rails.logger.info "Successfully uploaded video #{@video.id} to YouTube: #{youtube_id}"
  youtube_id
rescue StandardError => e
  Rails.logger.error "YouTube upload failed for video #{@video.id}: #{e.message}"
  raise UploadError, "YouTube upload failed: #{e.message}"
end

private

def generate_video_title
  "#{@sermon.title} - #{@sermon.pastor} | #{@sermon.church}"
end

def generate_video_description
  description = []
  description << @sermon.title
  description << ""
  description << "Scripture: #{@sermon.scripture}" if @sermon.scripture.present?
  description << ""
  description << @sermon.interpretation.truncate(500) if @sermon.interpretation.present?
  description << ""
  description << "Pastor: #{@sermon.pastor}" if @sermon.pastor.present?
  description << "Church: #{@sermon.church}" if @sermon.church.present?
  description << ""
  description << "#Sermon #Faith #Christianity #Bible ##{@sermon.church.gsub(/\s+/, '')}"
  
  description.join("\n")
end

def generate_video_tags
  tags = ['sermon', 'faith', 'christianity', 'bible']
  tags << @sermon.church.downcase.gsub(/\s+/, '') if @sermon.church.present?
  tags << @sermon.pastor.downcase.gsub(/\s+/, '') if @sermon.pastor.present?
  
  # Extract keywords from scripture
  if @sermon.scripture.present?
    scripture_words = @sermon.scripture.split(/\s+/).select { |w| w.length > 3 }
    tags.concat(scripture_words.first(3).map(&:downcase))
  end
  
  tags.uniq.first(10) # YouTube allows max 10 tags
end
```

---

## **4. 🎬 Real Video Generation**

### **A. Create Python Video Generation Script**
Create `scripts/generate_video.py`:

```python
#!/usr/bin/env python3
import json
import sys
from moviepy.editor import *
from gtts import gTTS
import tempfile
import os

def generate_video(config_file):
    with open(config_file, 'r') as f:
        config = json.load(f)
    
    # Generate audio from script
    tts = gTTS(text=config['script_text'], lang='ko', slow=False)
    audio_file = tempfile.NamedTemporaryFile(suffix='.mp3', delete=False)
    tts.save(audio_file.name)
    
    # Load background video
    background = VideoFileClip(config['background_video'])
    
    # Load audio
    audio = AudioFileClip(audio_file.name)
    
    # Resize background to YouTube Shorts format (1080x1920)
    background = background.resize((1080, 1920))
    
    # Set duration to match audio
    background = background.set_duration(audio.duration)
    
    # Create text overlay for scripture
    if config.get('scripture_text'):
        txt_clip = TextClip(
            config['scripture_text'],
            fontsize=60,
            color='white',
            font='Arial-Bold',
            stroke_color='black',
            stroke_width=2
        ).set_position(('center', 'top')).set_duration(audio.duration)
        
        # Combine video with text overlay
        final_video = CompositeVideoClip([background, txt_clip])
    else:
        final_video = background
    
    # Set audio
    final_video = final_video.set_audio(audio)
    
    # Export video
    final_video.write_videofile(
        config['output_file'],
        fps=30,
        codec='libx264',
        audio_codec='aac',
        temp_audiofile='temp-audio.m4a',
        remove_temp=True
    )
    
    # Cleanup
    os.unlink(audio_file.name)
    
    print(f"Video generated successfully: {config['output_file']}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python generate_video.py <config_file>")
        sys.exit(1)
    
    generate_video(sys.argv[1])
```

### **B. Update Python Execution in Rails**
Replace the mock execution in `app/services/video_generator_service.rb`:

```ruby
def execute_python_with_config(script_name, config_file)
  script_path = Rails.root.join("scripts", script_name)
  
  unless File.exist?(script_path)
    raise VideoProcessingError, "Python script not found: #{script_path}"
  end
  
  command = "python3 #{script_path} #{config_file}"
  
  Rails.logger.info "Executing: #{command}"
  
  stdout, stderr, status = Open3.capture3(command)
  
  unless status.success?
    Rails.logger.error "Python execution failed: #{stderr}"
    raise VideoProcessingError, "Video generation failed: #{stderr}"
  end
  
  Rails.logger.info "Python execution completed: #{stdout}"
  { success: true, output: stdout }
end
```

---

## **5. 📁 Set Up Assets**

### **A. Create Background Video Library**
```bash
# Create directory structure
mkdir -p storage/background_videos

# Download sample background videos (nature, abstract, etc.)
# Place .mp4 files in storage/background_videos/
```

### **B. Background Video Sources**
- **Free Sources:** Pexels, Pixabay, Unsplash (video section)
- **Recommended:** Nature scenes, abstract patterns, gentle motion
- **Format:** MP4, minimum 1080x1920 or higher
- **Duration:** 2-10 minutes (will be looped/trimmed as needed)

---

## **6. 🔐 Security & Production Setup**

### **A. Secure Python Execution**
```ruby
# app/services/secure_python_executor.rb
class SecurePythonExecutor
  ALLOWED_SCRIPTS = %w[generate_video.py generate_audio.py].freeze
  PYTHON_TIMEOUT = 300 # 5 minutes
  
  def self.execute(script_name, config_file)
    unless ALLOWED_SCRIPTS.include?(script_name)
      raise SecurityError, "Script not allowed: #{script_name}"
    end
    
    # Use timeout and resource limits
    command = [
      'timeout', PYTHON_TIMEOUT.to_s,
      'python3', 
      Rails.root.join("scripts", script_name).to_s,
      config_file.to_s
    ]
    
    stdout, stderr, status = Open3.capture3(*command)
    
    unless status.success?
      raise VideoProcessingError, "Execution failed: #{stderr}"
    end
    
    { success: true, output: stdout }
  end
end
```

### **B. Environment Configuration**
```bash
# Production environment variables
RAILS_ENV=production
YOUTUBE_CLIENT_ID=your_production_client_id
YOUTUBE_CLIENT_SECRET=your_production_client_secret
PYTHON_PATH=/usr/bin/python3
FFMPEG_PATH=/usr/bin/ffmpeg
VIDEO_STORAGE_PATH=/app/storage/generated_videos
BACKGROUND_VIDEOS_PATH=/app/storage/background_videos
```

---

## **7. 🚀 Testing the Complete Pipeline**

### **A. Test Video Generation**
```ruby
# In Rails console
sermon = Sermon.create!(
  title: "Test Sermon",
  scripture: "John 3:16",
  pastor: "Pastor Test",
  church: "Test Church",
  interpretation: "For God so loved the world that he gave his one and only Son..."
)

video = sermon.schedule_video_generation!(1)
video.approve!

# This will now create REAL video and upload to YouTube
VideoProcessingJob.perform_now([video.id])

# Check result
video.reload
puts "YouTube URL: #{video.youtube_url}"
# Will show real YouTube link!
```

### **B. Monitor Progress**
```bash
# Watch logs
tail -f log/development.log

# Monitor Sidekiq jobs
# Visit http://localhost:3000/sidekiq

# Check dashboard
# Visit http://localhost:3000/dashboard
```

---

## **🎯 Expected Results**

After implementation, you'll see:

1. **Real Video Files** generated in `storage/generated_videos/`
2. **Actual YouTube URLs** like `https://www.youtube.com/watch?v=dQw4w9WgXcQ`
3. **Live YouTube Shorts** viewable on YouTube
4. **Complete Analytics** in your dashboard
5. **Real Processing Times** and metrics

---

## **⏱️ Implementation Time Estimate**

- **YouTube API Setup:** 30 minutes
- **Video Dependencies:** 20 minutes  
- **Code Implementation:** 2-3 hours
- **Testing & Debugging:** 1-2 hours
- **Total:** 4-6 hours

---

## **🔧 Quick Start Command**

```bash
# Run this to start the implementation
./bin/setup_youtube_integration.sh
```

Once completed, every sermon will automatically generate real YouTube Shorts that you can watch, share, and track with full analytics!