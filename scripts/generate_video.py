#!/usr/bin/env python3
import json
import sys
import os
# Configure ImageMagick path for moviepy
os.environ['IMAGEMAGICK_BINARY'] = '/opt/homebrew/bin/convert'

from moviepy.editor import *
from gtts import gTTS
import tempfile

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
