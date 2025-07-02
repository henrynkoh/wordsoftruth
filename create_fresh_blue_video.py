#!/usr/bin/env python3

import os
import json
import requests
import numpy as np
from moviepy.editor import *
from gtts import gTTS
import tempfile
from requests_toolbelt.multipart.encoder import MultipartEncoder

def create_peaceful_blue_background(duration, size=(1080, 1920)):
    """Create a peaceful blue flowing background"""
    def make_frame(t):
        # Create base blue gradient
        img = np.zeros((size[1], size[0], 3), dtype=np.uint8)
        
        # Create flowing blue patterns
        for y in range(size[1]):
            # Base blue intensity
            base_intensity = int(180 + 50 * np.sin(y / size[1] * 2 * np.pi))
            
            # Add flowing wave effect
            wave_offset = int(20 * np.sin(t * 0.3 + y / 100))
            
            # Peaceful blue color palette
            blue_intensity = min(255, base_intensity + wave_offset)
            peaceful_blue = [
                int(blue_intensity * 0.2),  # Low red
                int(blue_intensity * 0.4),  # Medium green  
                blue_intensity               # High blue
            ]
            
            img[y, :] = peaceful_blue
            
        # Add gentle horizontal flow
        flow = int(15 * np.sin(t * 0.5))
        img = np.roll(img, flow, axis=1)
        
        return img
    
    return VideoClip(make_frame, duration=duration)

def create_fresh_blue_video():
    print("🕯️ CREATING FRESH PEACEFUL BLUE VIDEO")
    print("=" * 50)
    
    # Korean script for peaceful meditation
    korean_script = """하나님의 평안이 여러분과 함께하시기를 축복합니다. 
    오늘은 조용한 묵상의 시간을 가져보겠습니다. 
    마음을 고요히 하고 주님 앞에 나아가며, 그분의 음성에 귀 기울이는 시간이 되시기 바랍니다. 
    주님의 평안이 여러분의 마음과 생각을 지키시기를 기도합니다."""
    
    print(f"📝 Korean script: {len(korean_script)} characters")
    
    # Generate Korean TTS
    print("🎤 Generating Korean audio...")
    tts = gTTS(text=korean_script, lang='ko', slow=False)
    
    with tempfile.NamedTemporaryFile(delete=False, suffix='.mp3') as audio_file:
        tts.save(audio_file.name)
        audio = AudioFileClip(audio_file.name)
        duration = audio.duration
        print(f"   Audio duration: {duration:.1f} seconds")
    
    # Create peaceful blue background
    print("🎨 Creating peaceful blue background...")
    background = create_peaceful_blue_background(duration)
    
    # Add Korean text overlay
    print("📝 Adding text overlay...")
    title_text = "진리의 말씀\n평안한 기도시간"
    subtitle_text = "묵상과 기도"
    
    title_clip = TextClip(
        title_text,
        fontsize=60,
        color='white',
        font='Arial-Bold',
        stroke_color='navy',
        stroke_width=2
    ).set_position(('center', 300)).set_duration(duration)
    
    subtitle_clip = TextClip(
        subtitle_text,
        fontsize=40,
        color='lightblue',
        font='Arial',
        stroke_color='darkblue',
        stroke_width=1
    ).set_position(('center', 1400)).set_duration(duration)
    
    # Compose final video
    print("🎬 Composing final video...")
    final_video = CompositeVideoClip([
        background,
        title_clip,
        subtitle_clip
    ]).set_audio(audio)
    
    # Export video
    output_file = "fresh_peaceful_blue.mp4"
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

def upload_to_youtube(video_file, access_token):
    print("🚀 UPLOADING TO YOUTUBE...")
    
    # Video metadata
    metadata = {
        "snippet": {
            "title": "🕯️ 진리의 말씀 - 평안한 기도시간 | 묵상과 기도",
            "description": "하나님의 평안이 여러분과 함께하시기를 축복합니다. 조용한 묵상의 시간을 가져보시기 바랍니다. 마음을 고요히 하고 주님 앞에 나아가며, 그분의 음성에 귀 기울이는 시간이 되시기 바랍니다.\n\n🕯️ Peaceful Blue Theme - 평안한 기도\n📺 BibleStartup Channel\n🙏 Words of Truth",
            "tags": ["기도", "묵상", "평안", "한국어", "spiritual", "meditation", "prayer", "korean", "shorts", "진리의말씀"],
            "categoryId": "22"
        },
        "status": {
            "privacyStatus": "public",
            "selfDeclaredMadeForKids": False
        }
    }
    
    # Upload parameters
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
                
                print("🎉 SUCCESS! Fresh Peaceful Blue uploaded!")
                print(f"   YouTube ID: {youtube_id}")
                print(f"   YouTube URL: {youtube_url}")
                print(f"   Short URL: https://youtu.be/{youtube_id}")
                
                return {
                    'success': True,
                    'youtube_id': youtube_id,
                    'youtube_url': youtube_url
                }
            else:
                print(f"❌ Upload failed: {response.status_code}")
                print(f"   Error: {response.text}")
                return {'success': False, 'error': response.text}
                
    except Exception as e:
        print(f"❌ Upload error: {str(e)}")
        return {'success': False, 'error': str(e)}

def main():
    print("Please get fresh tokens from:")
    print("https://accounts.google.com/o/oauth2/auth?client_id=YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com&redirect_uri=http://localhost:3000/auth/youtube/callback&scope=https://www.googleapis.com/auth/youtube.upload&response_type=code&access_type=offline&prompt=consent")
    print()
    
    access_token = input("Enter your fresh access token: ").strip()
    
    if not access_token:
        print("❌ No access token provided")
        return
    
    # Create fresh video
    video_file = create_fresh_blue_video()
    
    # Upload to YouTube
    result = upload_to_youtube(video_file, access_token)
    
    if result['success']:
        print("\n🎯 COMPLETE! Check your YouTube Studio!")
        print("📱 Both themes now available:")
        print("   🌟 Golden Light: https://youtu.be/6Bugm87RFQo")
        print(f"   🕯️ Peaceful Blue: {result['youtube_url']}")
    
    # Cleanup
    if os.path.exists(video_file):
        os.remove(video_file)

if __name__ == "__main__":
    main()