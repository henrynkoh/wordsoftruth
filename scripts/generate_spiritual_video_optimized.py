#!/usr/bin/env python3
import json
import sys
import os
import random
from PIL import Image, ImageDraw, ImageFont
import numpy as np

# Configure ImageMagick path for moviepy
os.environ['IMAGEMAGICK_BINARY'] = '/opt/homebrew/bin/convert'

from moviepy.editor import *
from gtts import gTTS
import tempfile

def create_optimized_spiritual_background(theme, duration, size=(1080, 1920)):
    """Create optimized spiritual-themed background with pre-computed frames"""
    
    # Pre-compute background frames for better performance
    fps = 12  # Reduced from default 24fps for faster processing
    total_frames = int(duration * fps)
    
    print(f"Pre-computing {total_frames} frames for {theme} theme...")
    
    frames = []
    
    for frame_num in range(total_frames):
        t = frame_num / fps
        
        if theme == "golden_light":
            # Optimized golden gradient
            img = np.zeros((size[1], size[0], 3), dtype=np.uint8)
            
            # Vectorized gradient computation
            y_indices = np.arange(size[1])
            intensities = (255 * (0.3 + 0.4 * np.sin(y_indices / size[1] * np.pi))).astype(np.uint8)
            
            # Create golden color array
            img[:, :, 0] = intensities.reshape(-1, 1)  # Red
            img[:, :, 1] = (intensities * 0.8).astype(np.uint8).reshape(-1, 1)  # Green
            img[:, :, 2] = (intensities * 0.3).astype(np.uint8).reshape(-1, 1)  # Blue
            
            # Simple wave animation
            wave = int(20 * np.sin(t * 0.5))
            img = np.roll(img, wave, axis=0)
            
        elif theme == "peaceful_blue":
            # Optimized peaceful blue
            img = np.zeros((size[1], size[0], 3), dtype=np.uint8)
            
            # Simple gradient with minimal computation
            base_intensity = 80 + int(40 * np.sin(t * 0.3))
            for y in range(0, size[1], 20):  # Skip pixels for speed
                for x in range(0, size[0], 20):
                    wave = int(30 * np.sin((x + y + t * 50) / 200))
                    intensity = max(20, min(255, base_intensity + wave))
                    
                    # Fill 20x20 block for speed
                    y_end = min(y + 20, size[1])
                    x_end = min(x + 20, size[0])
                    img[y:y_end, x:x_end] = [10, 30, intensity]
            
        elif theme == "sunset_worship":
            # Optimized sunset colors
            img = np.zeros((size[1], size[0], 3), dtype=np.uint8)
            
            # Simple vertical gradient
            for y in range(size[1]):
                gradient_pos = y / size[1]
                wave = int(15 * np.sin(t * 0.4 + y / 100))
                
                if gradient_pos < 0.3:  # Top - orange
                    color = [255, 165 + wave, 50 + wave//2]
                elif gradient_pos < 0.7:  # Middle - red
                    color = [255, 100 + wave, 30 + wave//3]
                else:  # Bottom - purple
                    color = [150 + wave//2, 50 + wave//3, 100 + wave]
                
                img[y, :] = [max(0, min(255, c)) for c in color]
                
        elif theme == "cross_pattern":
            # Optimized cross pattern
            img = np.zeros((size[1], size[0], 3), dtype=np.uint8)
            
            # Simple golden base
            base_color = int(120 + 30 * np.sin(t * 0.5))
            img[:, :] = [base_color, int(base_color * 0.8), int(base_color * 0.4)]
            
            # Simple cross
            center_x, center_y = size[0] // 2, size[1] // 2
            cross_width = 80
            
            # Vertical bar
            img[:, center_x-cross_width//2:center_x+cross_width//2] = [255, 255, 220]
            # Horizontal bar  
            img[center_y-cross_width//2:center_y+cross_width//2, :] = [255, 255, 220]
        
        else:
            # Default theme - simple gradient
            img = np.zeros((size[1], size[0], 3), dtype=np.uint8)
            for y in range(size[1]):
                intensity = int(150 + 50 * np.sin(y / size[1] * np.pi + t))
                img[y, :] = [intensity, intensity, intensity]
        
        frames.append(img)
    
    print(f"✅ Pre-computed {len(frames)} frames")
    
    # Create video from pre-computed frames
    def make_frame(t):
        frame_index = min(int(t * fps), len(frames) - 1)
        return frames[frame_index]
    
    return VideoClip(make_frame, duration=duration).set_fps(fps)

def generate_optimized_video(config_file):
    """Generate spiritual video with optimizations"""
    
    print("🚀 OPTIMIZED SPIRITUAL VIDEO GENERATOR")
    print("=" * 50)
    
    # Load configuration
    with open(config_file, 'r', encoding='utf-8') as f:
        config = json.load(f)
    
    script_text = config['script_text']
    scripture_text = config.get('scripture_text', '')
    theme = config.get('theme', 'golden_light')
    output_file = config.get('output_file', 'output.mp4')
    add_branding = config.get('add_branding', True)
    
    print(f"📝 Script: {len(script_text)} characters")
    print(f"🎨 Theme: {theme}")
    print(f"📁 Output: {output_file}")
    
    # Ensure output directory exists
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    
    # Generate Korean TTS (this is usually the slowest part)
    print("🎤 Generating Korean TTS...")
    tts_start = time.time()
    
    tts = gTTS(text=script_text, lang='ko', slow=False)
    
    with tempfile.NamedTemporaryFile(delete=False, suffix='.mp3') as temp_audio:
        tts.save(temp_audio.name)
        audio_clip = AudioFileClip(temp_audio.name)
        duration = audio_clip.duration
    
    tts_time = time.time() - tts_start
    print(f"   ✅ TTS generated in {tts_time:.1f}s, duration: {duration:.1f}s")
    
    # Create optimized background
    print("🎨 Creating optimized background...")
    bg_start = time.time()
    
    background = create_optimized_spiritual_background(theme, duration)
    
    bg_time = time.time() - bg_start
    print(f"   ✅ Background created in {bg_time:.1f}s")
    
    # Create text overlays with simplified styling
    print("📝 Adding text overlays...")
    text_start = time.time()
    
    # Main title (simplified styling)
    if '\n' in scripture_text:
        title_lines = scripture_text.split('\n')
        main_title = title_lines[0]
        subtitle = title_lines[1] if len(title_lines) > 1 else ""
    else:
        main_title = scripture_text
        subtitle = ""
    
    title_clip = TextClip(
        main_title,
        fontsize=58,
        color='white',
        font='Arial-Bold',
        stroke_color='black',
        stroke_width=2
    ).set_position(('center', 300)).set_duration(duration)
    
    clips = [background, title_clip]
    
    if subtitle:
        subtitle_clip = TextClip(
            subtitle,
            fontsize=40,
            color='lightyellow',
            font='Arial',
            stroke_color='darkblue',
            stroke_width=1
        ).set_position(('center', 1450)).set_duration(duration)
        clips.append(subtitle_clip)
    
    text_time = time.time() - text_start
    print(f"   ✅ Text overlays created in {text_time:.1f}s")
    
    # Compose and export with optimized settings
    print("🎬 Composing and exporting...")
    export_start = time.time()
    
    final_video = CompositeVideoClip(clips).set_audio(audio_clip)
    
    # Optimized export settings for speed
    final_video.write_videofile(
        output_file,
        fps=12,  # Reduced FPS for speed
        codec='libx264',
        audio_codec='aac',
        preset='ultrafast',  # Fastest encoding preset
        temp_audiofile='temp-audio.m4a',
        remove_temp=True,
        verbose=False,
        logger=None,
        bitrate='1000k'  # Lower bitrate for speed
    )
    
    export_time = time.time() - export_start
    total_time = tts_time + bg_time + text_time + export_time
    
    # Cleanup
    final_video.close()
    audio_clip.close()
    os.unlink(temp_audio.name)
    
    file_size = os.path.getsize(output_file) / 1024 / 1024
    
    print("\n🎯 PERFORMANCE SUMMARY:")
    print(f"   TTS Generation: {tts_time:.1f}s")
    print(f"   Background Creation: {bg_time:.1f}s") 
    print(f"   Text Overlays: {text_time:.1f}s")
    print(f"   Video Export: {export_time:.1f}s")
    print(f"   TOTAL TIME: {total_time:.1f}s (vs ~120s before)")
    print(f"   File Size: {file_size:.1f}MB")
    print(f"   🚀 Speed Improvement: {120/total_time:.1f}x faster!")

if __name__ == "__main__":
    import time
    
    if len(sys.argv) != 2:
        print("Usage: python3 generate_spiritual_video_optimized.py <config_file>")
        sys.exit(1)
    
    config_file = sys.argv[1]
    
    if not os.path.exists(config_file):
        print(f"Error: Config file {config_file} not found")
        sys.exit(1)
    
    try:
        generate_optimized_video(config_file)
        print("✅ Optimized video generation complete!")
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        sys.exit(1)