#!/usr/bin/env python3

import os
import json
import numpy as np
from moviepy.editor import *
from gtts import gTTS
import tempfile

def create_mountain_majesty_background(duration, size=(1080, 1920)):
    """Create mountain silhouettes with divine light for strength/perseverance theme"""
    def make_frame(t):
        img = np.zeros((size[1], size[0], 3), dtype=np.uint8)
        
        # Sky gradient from purple to gold
        for y in range(size[1]):
            gradient = y / size[1]
            
            if gradient < 0.4:  # Upper sky - deep purple/blue
                sky_color = [
                    int(80 + 40 * gradient),   # Purple to blue
                    int(60 + 80 * gradient),   # Growing lighter
                    int(120 + 100 * gradient)  # Blue base
                ]
            else:  # Lower sky - golden sunrise
                transition = (gradient - 0.4) / 0.6
                sky_color = [
                    int(220 + 35 * transition), # Golden red
                    int(140 + 80 * transition), # Golden yellow
                    int(60 + 40 * transition)   # Warm undertones
                ]
            
            img[y, :] = sky_color
        
        # Mountain silhouettes
        mountain_height = size[1] // 3
        for x in range(size[0]):
            # Multiple mountain layers with movement
            mountain1 = int(mountain_height * (0.8 + 0.2 * np.sin(x / 100 + t * 0.2)))
            mountain2 = int(mountain_height * (0.6 + 0.3 * np.sin(x / 80 + t * 0.15)))
            
            # Draw mountain silhouettes
            max_mountain = max(mountain1, mountain2)
            for y in range(size[1] - max_mountain, size[1]):
                img[y, x] = [40, 40, 60]  # Dark mountain silhouette
        
        # Divine light rays from peak
        for i in range(5):
            ray_x = size[0] // 2 + int(100 * np.sin(t * 0.3 + i))
            ray_intensity = int(100 * (0.5 + 0.5 * np.sin(t * 2 + i)))
            
            for y in range(0, size[1] // 2):
                ray_width = max(1, y // 50)
                for dx in range(-ray_width, ray_width + 1):
                    if 0 <= ray_x + dx < size[0]:
                        img[y, ray_x + dx] = [
                            min(255, img[y, ray_x + dx, 0] + ray_intensity),
                            min(255, img[y, ray_x + dx, 1] + ray_intensity),
                            min(255, img[y, ray_x + dx, 2] + ray_intensity // 2)
                        ]
        
        return img
    
    return VideoClip(make_frame, duration=duration)

def create_mountain_majesty_video():
    print("⛰️ CREATING MOUNTAIN MAJESTY THEME - BACKUP 1/6")
    print("=" * 50)
    
    # Ensure output directory exists
    os.makedirs("storage/backup_themes", exist_ok=True)
    
    korean_script = "산들이 주를 향해 뛰노는도다. 높은 산 위에서 하나님의 위엄을 바라봅니다. 주님은 우리의 힘이시요 피난처가 되십니다. 어떤 어려움이 와도 주님을 의지하며 굳게 서겠습니다."
    
    print(f"📝 Korean script: {len(korean_script)} characters")
    
    # Generate Korean TTS
    print("🎤 Generating Korean audio...")
    tts = gTTS(text=korean_script, lang='ko', slow=False)
    
    with tempfile.NamedTemporaryFile(delete=False, suffix='.mp3') as audio_file:
        tts.save(audio_file.name)
        audio = AudioFileClip(audio_file.name)
        duration = audio.duration
        print(f"   Audio duration: {duration:.1f} seconds")
    
    # Create mountain background
    print("🎨 Creating mountain majesty background...")
    background = create_mountain_majesty_background(duration)
    
    # Add text overlays
    print("📝 Adding text overlay...")
    
    title_clip = TextClip(
        "진리의 말씀\n산의 위엄",
        fontsize=54,
        color='white',
        font='Arial-Bold',
        stroke_color='black',
        stroke_width=3
    ).set_position(('center', 280)).set_duration(duration)
    
    subtitle_clip = TextClip(
        "힘과 인내",
        fontsize=36,
        color='lightsteelblue',
        font='Arial',
        stroke_color='darkblue',
        stroke_width=2
    ).set_position(('center', 1450)).set_duration(duration)
    
    # Compose final video
    print("🎬 Composing final video...")
    final_video = CompositeVideoClip([
        background,
        title_clip,
        subtitle_clip
    ]).set_audio(audio)
    
    # Export video to backup directory
    output_file = "storage/backup_themes/backup_mountain_majesty.mp4"
    print(f"💾 Exporting to {output_file}...")
    
    final_video.write_videofile(
        output_file,
        fps=24,
        codec='libx264',
        audio_codec='aac',
        temp_audiofile='temp-audio.m4a',
        remove_temp=True,
        verbose=False,
        logger=None
    )
    
    # Cleanup
    final_video.close()
    audio.close()
    os.unlink(audio_file.name)
    
    file_size = os.path.getsize(output_file) / 1024 / 1024
    print(f"✅ Mountain Majesty saved: {file_size:.1f}MB")
    
    # Save metadata
    metadata = {
        "theme": "mountain_majesty",
        "file": output_file,
        "title": "⛰️ 진리의 말씀 - 산의 위엄 | 힘과 인내",
        "description": "산들이 주를 향해 뛰노는도다. 높은 산 위에서 하나님의 위엄을 바라봅니다. 주님은 우리의 힘이시요 피난처가 되십니다. 어떤 어려움이 와도 주님을 의지하며 굳게 서겠습니다.\n\n⛰️ Mountain Majesty Theme - 산의 위엄\n📺 BibleStartup Channel\n🙏 Words of Truth",
        "tags": ["산", "위엄", "힘", "한국어", "mountain", "strength", "perseverance", "korean", "shorts", "진리의말씀"],
        "size_mb": file_size
    }
    
    with open("storage/backup_themes/mountain_majesty_metadata.json", 'w', encoding='utf-8') as f:
        json.dump(metadata, f, ensure_ascii=False, indent=2)
    
    print("📋 Metadata saved")
    print("🎯 BACKUP THEME 1/6 COMPLETE!")
    print(f"📁 Ready for upload: {output_file}")
    
    return output_file

if __name__ == "__main__":
    create_mountain_majesty_video()