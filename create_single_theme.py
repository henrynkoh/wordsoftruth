#!/usr/bin/env python3

import os
import json
import requests
import numpy as np
from moviepy.editor import *
from gtts import gTTS
import tempfile
from requests_toolbelt.multipart.encoder import MultipartEncoder

def create_ocean_waves_background(duration, size=(1080, 1920)):
    """Create flowing ocean waves for baptism/renewal theme"""
    def make_frame(t):
        img = np.zeros((size[1], size[0], 3), dtype=np.uint8)
        
        for y in range(size[1]):
            # Ocean blue gradient with waves
            wave1 = int(30 * np.sin(t * 0.8 + y / 50))
            wave2 = int(20 * np.sin(t * 1.2 + y / 80))
            
            base_blue = 120 + wave1 + wave2
            ocean_color = [
                int(base_blue * 0.3),  # Low red
                int(base_blue * 0.6),  # Medium green
                min(255, base_blue)    # Full blue
            ]
            
            img[y, :] = ocean_color
            
        # Add horizontal wave movement
        wave_shift = int(40 * np.sin(t * 0.6))
        img = np.roll(img, wave_shift, axis=1)
        
        return img
    
    return VideoClip(make_frame, duration=duration)

def create_themed_video():
    print("🌊 CREATING OCEAN WAVES THEME - BAPTISM & RENEWAL")
    print("=" * 50)
    
    korean_script = "주님의 은혜가 바다처럼 넓고 깊습니다. 세례의 물이 우리의 죄를 씻어주시고, 새로운 생명으로 거듭나게 하셨습니다. 파도처럼 밀려오는 주님의 사랑 안에서 우리는 새로워집니다."
    
    print(f"📝 Korean script: {len(korean_script)} characters")
    
    # Generate Korean TTS
    print("🎤 Generating Korean audio...")
    tts = gTTS(text=korean_script, lang='ko', slow=False)
    
    with tempfile.NamedTemporaryFile(delete=False, suffix='.mp3') as audio_file:
        tts.save(audio_file.name)
        audio = AudioFileClip(audio_file.name)
        duration = audio.duration
        print(f"   Audio duration: {duration:.1f} seconds")
    
    # Create ocean waves background
    print("🎨 Creating ocean waves background...")
    background = create_ocean_waves_background(duration)
    
    # Add text overlays
    print("📝 Adding text overlay...")
    
    title_clip = TextClip(
        "진리의 말씀\n세례와 새생명",
        fontsize=55,
        color='white',
        font='Arial-Bold',
        stroke_color='darkblue',
        stroke_width=3
    ).set_position(('center', 280)).set_duration(duration)
    
    subtitle_clip = TextClip(
        "거듭남의 은혜",
        fontsize=38,
        color='lightcyan',
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
    
    # Export video
    output_file = "ocean_waves_theme.mp4"
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
    print(f"✅ Video created: {file_size:.1f}MB")
    
    return output_file

def upload_to_youtube(video_file):
    print("🚀 UPLOADING OCEAN WAVES THEME TO YOUTUBE...")
    
    access_token = "YOUR_ACCESS_TOKEN"
    
    metadata = {
        "snippet": {
            "title": "🌊 진리의 말씀 - 세례와 새생명 | 거듭남의 은혜",
            "description": "주님의 은혜가 바다처럼 넓고 깊습니다. 세례의 물이 우리의 죄를 씻어주시고, 새로운 생명으로 거듭나게 하셨습니다. 파도처럼 밀려오는 주님의 사랑 안에서 우리는 새로워집니다.\n\n🌊 Ocean Waves Theme - 세례와 새생명\n📺 BibleStartup Channel\n🙏 Words of Truth",
            "tags": ["세례", "새생명", "거듭남", "한국어", "baptism", "renewal", "rebirth", "korean", "shorts", "진리의말씀"],
            "categoryId": "22"
        },
        "status": {
            "privacyStatus": "public",
            "selfDeclaredMadeForKids": False
        }
    }
    
    url = 'https://www.googleapis.com/upload/youtube/v3/videos'
    params = {
        'part': 'snippet,status',
        'uploadType': 'multipart'
    }
    
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Accept': 'application/json'
    }
    
    try:
        with open(video_file, 'rb') as video_data:
            encoder = MultipartEncoder(
                fields={
                    'metadata': ('metadata', json.dumps(metadata), 'application/json'),
                    'video': ('video.mp4', video_data, 'video/mp4')
                }
            )
            
            headers['Content-Type'] = encoder.content_type
            response = requests.post(url, params=params, headers=headers, data=encoder)
            
            if response.status_code == 200:
                result = response.json()
                youtube_id = result['id']
                youtube_url = f"https://www.youtube.com/watch?v={youtube_id}"
                
                print("🎉 SUCCESS! Ocean Waves theme uploaded!")
                print(f"   YouTube ID: {youtube_id}")
                print(f"   YouTube URL: {youtube_url}")
                print(f"   Short URL: https://youtu.be/{youtube_id}")
                
                return youtube_url
            else:
                print(f"❌ Upload failed: {response.status_code}")
                print(f"   Error: {response.text}")
                return None
                
    except Exception as e:
        print(f"❌ Upload error: {str(e)}")
        return None

def main():
    # Create video
    video_file = create_themed_video()
    
    # Upload to YouTube
    youtube_url = upload_to_youtube(video_file)
    
    if youtube_url:
        print(f"\n🎯 Ocean Waves theme complete: {youtube_url}")
        print("🌊 Theme 5/10 added to your spiritual collection!")
    
    # Cleanup
    if os.path.exists(video_file):
        os.remove(video_file)

if __name__ == "__main__":
    main()