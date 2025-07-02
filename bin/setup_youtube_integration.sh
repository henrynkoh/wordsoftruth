#!/bin/bash

echo "🎬 Setting up Real YouTube Shorts Integration"
echo "=============================================="

# Check if running on macOS or Linux
OS="$(uname)"
echo "Detected OS: $OS"

echo ""
echo "📋 Step 1: Installing Video Processing Dependencies..."

# Install FFmpeg
if command -v ffmpeg &> /dev/null; then
    echo "✅ FFmpeg already installed"
else
    echo "📦 Installing FFmpeg..."
    if [[ "$OS" == "Darwin" ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install ffmpeg
        else
            echo "❌ Homebrew not found. Please install Homebrew first:"
            echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            exit 1
        fi
    elif [[ "$OS" == "Linux" ]]; then
        # Linux
        sudo apt update
        sudo apt install -y ffmpeg
    else
        echo "❌ Unsupported OS. Please install FFmpeg manually."
        exit 1
    fi
fi

echo ""
echo "📦 Step 2: Installing Python Dependencies..."

# Create Python requirements file
cat > requirements.txt << 'EOF'
moviepy==1.0.3
gTTS==2.3.1
Pillow==10.0.0
numpy==1.24.3
opencv-python==4.8.0.74
pydub==0.25.1
EOF

# Install Python packages
if command -v pip3 &> /dev/null; then
    pip3 install -r requirements.txt
elif command -v pip &> /dev/null; then
    pip install -r requirements.txt
else
    echo "❌ pip not found. Please install Python 3 and pip first."
    exit 1
fi

echo ""
echo "💎 Step 3: Installing Ruby Gems..."

# Add YouTube API gems to Gemfile if not present
if ! grep -q "google-api-client" Gemfile; then
    echo "" >> Gemfile
    echo "# YouTube API integration" >> Gemfile
    echo "gem 'google-api-client', '~> 0.53.0'" >> Gemfile
    echo "gem 'googleauth', '~> 1.0'" >> Gemfile
    bundle install
else
    echo "✅ YouTube API gems already in Gemfile"
fi

echo ""
echo "📁 Step 4: Creating Directory Structure..."

# Create necessary directories
mkdir -p storage/background_videos
mkdir -p storage/generated_videos
mkdir -p scripts
mkdir -p tmp/video_processing

echo ""
echo "🐍 Step 5: Creating Python Video Generation Script..."

# Create the Python video generation script
cat > scripts/generate_video.py << 'EOF'
#!/usr/bin/env python3
import json
import sys
from moviepy.editor import *
from gtts import gTTS
import tempfile
import os

def generate_video(config_file):
    try:
        with open(config_file, 'r', encoding='utf-8') as f:
            config = json.load(f)
        
        print(f"Generating video with config: {config_file}")
        
        # Generate audio from script
        tts = gTTS(text=config['script_text'], lang='ko', slow=False)
        audio_file = tempfile.NamedTemporaryFile(suffix='.mp3', delete=False)
        tts.save(audio_file.name)
        print("✅ Audio generated")
        
        # Load background video
        background = VideoFileClip(config['background_video'])
        print("✅ Background video loaded")
        
        # Load audio
        audio = AudioFileClip(audio_file.name)
        print(f"✅ Audio loaded (duration: {audio.duration}s)")
        
        # Resize background to YouTube Shorts format (1080x1920)
        background = background.resize((1080, 1920))
        
        # Set duration to match audio (or max 5 minutes)
        duration = min(audio.duration, 300)  # Max 5 minutes
        background = background.set_duration(duration).loop(duration=duration)
        audio = audio.set_duration(duration)
        
        # Create text overlay for scripture
        if config.get('scripture_text'):
            txt_clip = TextClip(
                config['scripture_text'],
                fontsize=50,
                color='white',
                font='Arial-Bold',
                stroke_color='black',
                stroke_width=2,
                size=(1000, None),
                method='caption'
            ).set_position(('center', 200)).set_duration(duration)
            
            # Combine video with text overlay
            final_video = CompositeVideoClip([background, txt_clip])
            print("✅ Text overlay added")
        else:
            final_video = background
        
        # Set audio
        final_video = final_video.set_audio(audio)
        print("✅ Audio attached to video")
        
        # Export video
        print("🎬 Rendering final video...")
        final_video.write_videofile(
            config['output_file'],
            fps=30,
            codec='libx264',
            audio_codec='aac',
            temp_audiofile='temp-audio.m4a',
            remove_temp=True,
            verbose=False,
            logger=None
        )
        
        # Cleanup
        os.unlink(audio_file.name)
        
        print(f"✅ Video generated successfully: {config['output_file']}")
        
    except Exception as e:
        print(f"❌ Error generating video: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python generate_video.py <config_file>")
        sys.exit(1)
    
    generate_video(sys.argv[1])
EOF

# Make script executable
chmod +x scripts/generate_video.py

echo ""
echo "🎥 Step 6: Creating Sample Background Video..."

# Create a simple background video using FFmpeg if no backgrounds exist
if [ ! "$(ls -A storage/background_videos)" ]; then
    echo "Creating sample background video..."
    ffmpeg -f lavfi -i "color=c=blue:size=1080x1920:duration=60" \
           -f lavfi -i "noise=alls=20:allf=t+u" \
           -filter_complex "[0][1]overlay=0:0:eval=frame" \
           -c:v libx264 -t 60 -pix_fmt yuv420p \
           storage/background_videos/sample_blue.mp4 -y 2>/dev/null || \
    echo "⚠️ Could not create sample background. Please add .mp4 files to storage/background_videos/"
fi

echo ""
echo "📝 Step 7: Creating Environment Template..."

# Create .env template if it doesn't exist
if [ ! -f .env ]; then
    cat > .env << 'EOF'
# YouTube API Configuration
YOUTUBE_CLIENT_ID=your_client_id_here
YOUTUBE_CLIENT_SECRET=your_client_secret_here
YOUTUBE_REDIRECT_URI=http://localhost:3000/auth/youtube/callback
GOOGLE_APPLICATION_CREDENTIALS=config/youtube_credentials.json

# Video Processing
PYTHON_PATH=/usr/bin/python3
FFMPEG_PATH=/usr/bin/ffmpeg
VIDEO_STORAGE_PATH=storage/generated_videos
BACKGROUND_VIDEOS_PATH=storage/background_videos
EOF
    echo "📝 Created .env template - please update with your YouTube API credentials"
else
    echo "✅ .env file already exists"
fi

echo ""
echo "✅ Setup Complete!"
echo ""
echo "🔑 Next Steps:"
echo "1. Get YouTube API credentials from Google Cloud Console:"
echo "   https://console.cloud.google.com/"
echo ""
echo "2. Update .env file with your credentials"
echo ""
echo "3. Add background videos (.mp4) to storage/background_videos/"
echo ""
echo "4. Test the integration:"
echo "   rails console"
echo "   > sermon = Sermon.create!(title: 'Test', scripture: 'John 3:16', ...)"
echo "   > video = sermon.schedule_video_generation!(1)"
echo "   > video.approve!"
echo "   > VideoProcessingJob.perform_now([video.id])"
echo ""
echo "🎬 Your sermons will now generate REAL YouTube Shorts!"