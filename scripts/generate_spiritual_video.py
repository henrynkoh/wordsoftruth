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

def create_spiritual_background(theme, duration, size=(1080, 1920)):
    """Create spiritual-themed background based on theme selection"""
    
    if theme == "golden_light":
        # Golden gradient with light rays
        def make_frame(t):
            # Create golden gradient
            img = np.zeros((size[1], size[0], 3), dtype=np.uint8)
            for y in range(size[1]):
                intensity = int(255 * (0.3 + 0.4 * np.sin(y / size[1] * np.pi)))
                golden_color = [intensity, int(intensity * 0.8), int(intensity * 0.3)]
                img[y, :] = golden_color
            
            # Add subtle animation
            wave = int(30 * np.sin(t * 0.5))
            img = np.roll(img, wave, axis=0)
            return img
            
    elif theme == "peaceful_blue":
        # Peaceful blue with flowing patterns
        def make_frame(t):
            img = np.zeros((size[1], size[0], 3), dtype=np.uint8)
            for y in range(size[1]):
                for x in range(size[0]):
                    # Create flowing blue pattern
                    wave1 = np.sin((x + t * 50) / 100) * 0.3
                    wave2 = np.cos((y + t * 30) / 150) * 0.2
                    intensity = int(100 + 80 * (wave1 + wave2))
                    img[y, x] = [20, 50, intensity]
            return img
            
    elif theme == "sunset_worship":
        # Warm sunset colors for worship
        def make_frame(t):
            img = np.zeros((size[1], size[0], 3), dtype=np.uint8)
            for y in range(size[1]):
                # Sunset gradient from orange to purple
                ratio = y / size[1]
                r = int(255 * (1 - ratio * 0.7))
                g = int(150 * (1 - ratio))
                b = int(100 + 155 * ratio)
                img[y, :] = [r, g, b]
            
            # Add gentle movement
            shift = int(10 * np.sin(t * 0.3))
            img = np.roll(img, shift, axis=1)
            return img
            
    else:  # "cross_pattern" default
        # Subtle cross pattern with soft lighting
        def make_frame(t):
            img = np.full((size[1], size[0], 3), [40, 60, 100], dtype=np.uint8)
            
            # Add subtle cross pattern
            center_x, center_y = size[0] // 2, size[1] // 2
            cross_width = 80
            cross_alpha = 0.3 + 0.2 * np.sin(t * 0.5)
            
            # Vertical line of cross
            x1, x2 = center_x - cross_width // 2, center_x + cross_width // 2
            img[:, x1:x2] = img[:, x1:x2] * (1 - cross_alpha) + np.array([200, 200, 255]) * cross_alpha
            
            # Horizontal line of cross
            y1, y2 = center_y - cross_width // 2, center_y + cross_width // 2
            img[y1:y2, :] = img[y1:y2, :] * (1 - cross_alpha) + np.array([200, 200, 255]) * cross_alpha
            
            return img.astype(np.uint8)
    
    return VideoClip(make_frame, duration=duration)

def create_enhanced_text_overlay(text, theme, position, duration, size=(1080, 1920)):
    """Create enhanced text overlay with spiritual styling"""
    
    # Theme-based text styling
    if theme == "golden_light":
        font_color = '#FFD700'  # Gold
        stroke_color = '#8B4513'  # Brown
        stroke_width = 3
        font_size = 60
        
    elif theme == "peaceful_blue":
        font_color = '#E6F3FF'  # Light blue
        stroke_color = '#003366'  # Dark blue
        stroke_width = 2
        font_size = 58
        
    elif theme == "sunset_worship":
        font_color = '#FFF8DC'  # Cream
        stroke_color = '#8B0000'  # Dark red
        stroke_width = 3
        font_size = 62
        
    else:  # cross_pattern
        font_color = '#FFFFFF'  # White
        stroke_color = '#000080'  # Navy
        stroke_width = 4
        font_size = 56
    
    # Create text clip with enhanced styling
    txt_clip = TextClip(
        text,
        fontsize=font_size,
        color=font_color,
        font='Arial-Bold',
        stroke_color=stroke_color,
        stroke_width=stroke_width,
        size=(950, None),
        method='caption',
        align='center'
    ).set_position(position).set_duration(duration)
    
    # Add subtle fade-in effect
    txt_clip = txt_clip.crossfadein(0.5)
    
    return txt_clip

def add_bible_verse_styling(scripture_text, theme, duration):
    """Add special styling for Bible verses"""
    
    # Split scripture into reference and text if possible
    lines = scripture_text.split('\n')
    
    clips = []
    
    for i, line in enumerate(lines):
        if i == 0:  # First line (usually scripture reference)
            position = ('center', 250)
            font_size = 48
        else:  # Subsequent lines (verse text)
            position = ('center', 350 + (i-1) * 100)
            font_size = 42
            
        if theme == "golden_light":
            font_color = '#FFE55C' if i == 0 else '#FFED4E'
            stroke_color = '#8B4513'
            
        elif theme == "peaceful_blue":
            font_color = '#B8E6FF' if i == 0 else '#D4EFFF'
            stroke_color = '#003366'
            
        elif theme == "sunset_worship":
            font_color = '#FFE4B5' if i == 0 else '#FFEFD5'
            stroke_color = '#8B0000'
            
        else:  # cross_pattern
            font_color = '#E6E6FA' if i == 0 else '#F0F0FF'
            stroke_color = '#000080'
        
        txt_clip = TextClip(
            line,
            fontsize=font_size,
            color=font_color,
            font='Arial-Bold',
            stroke_color=stroke_color,
            stroke_width=3,
            size=(900, None),
            method='caption',
            align='center'
        ).set_position(position).set_duration(duration)
        
        # Add fade-in effect with slight delay for each line
        txt_clip = txt_clip.crossfadein(0.8).set_start(i * 0.3)
        clips.append(txt_clip)
    
    return clips

def generate_spiritual_video(config_file):
    try:
        with open(config_file, 'r', encoding='utf-8') as f:
            config = json.load(f)
        
        print(f"🎬 Generating spiritual video with config: {config_file}")
        
        # Select theme (can be specified in config or random)
        themes = ["golden_light", "peaceful_blue", "sunset_worship", "cross_pattern"]
        theme = config.get('theme', random.choice(themes))
        print(f"🎨 Using theme: {theme}")
        
        # Generate audio from script
        tts = gTTS(text=config['script_text'], lang='ko', slow=False)
        audio_file = tempfile.NamedTemporaryFile(suffix='.mp3', delete=False)
        tts.save(audio_file.name)
        print("✅ Korean audio generated")
        
        # Load audio
        audio = AudioFileClip(audio_file.name)
        duration = min(audio.duration, 300)  # Max 5 minutes
        audio = audio.set_duration(duration)
        print(f"✅ Audio loaded (duration: {duration}s)")
        
        # Create spiritual background
        background = create_spiritual_background(theme, duration)
        print(f"✅ Spiritual background created ({theme} theme)")
        
        # Create enhanced text overlays
        all_clips = [background]
        
        # Add scripture text with special styling
        if config.get('scripture_text'):
            scripture_clips = add_bible_verse_styling(config['scripture_text'], theme, duration)
            all_clips.extend(scripture_clips)
            print("✅ Enhanced scripture overlay added")
        
        # Add channel branding (optional)
        if config.get('add_branding', True):
            branding_text = "진리의 말씀 | BibleStartup"
            branding_clip = TextClip(
                branding_text,
                fontsize=32,
                color='#FFFFFF',
                font='Arial',
                stroke_color='#000000',
                stroke_width=2
            ).set_position(('center', 1800)).set_duration(duration).crossfadein(1.0)
            all_clips.append(branding_clip)
            print("✅ Channel branding added")
        
        # Combine all clips
        final_video = CompositeVideoClip(all_clips)
        
        # Set audio
        final_video = final_video.set_audio(audio)
        print("✅ Audio attached to spiritual video")
        
        # Export video with high quality settings
        print("🎬 Rendering spiritual video...")
        final_video.write_videofile(
            config['output_file'],
            fps=30,
            codec='libx264',
            audio_codec='aac',
            bitrate='8000k',  # Higher bitrate for better quality
            temp_audiofile='temp-audio.m4a',
            remove_temp=True,
            verbose=False,
            logger=None
        )
        
        # Cleanup
        os.unlink(audio_file.name)
        
        print(f"✅ Spiritual video generated successfully: {config['output_file']}")
        print(f"🎨 Theme used: {theme}")
        
    except Exception as e:
        print(f"❌ Error generating spiritual video: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python generate_spiritual_video.py <config_file>")
        sys.exit(1)
    
    generate_spiritual_video(sys.argv[1])