#!/usr/bin/env python3

import os
import json
import requests
import numpy as np
from moviepy.editor import *
from gtts import gTTS
import tempfile
from requests_toolbelt.multipart.encoder import MultipartEncoder

def create_sunset_worship_background(duration, size=(1080, 1920)):
    """Create warm sunset colors for evening devotion"""
    def make_frame(t):
        img = np.zeros((size[1], size[0], 3), dtype=np.uint8)
        
        for y in range(size[1]):
            # Create sunset gradient from warm orange to deep purple
            gradient_position = y / size[1]
            
            # Sunset color transition
            if gradient_position < 0.3:  # Top - warm yellow/orange
                base_color = [255, 200, 100]  # Warm yellow
            elif gradient_position < 0.6:  # Middle - orange/red
                base_color = [255, 120, 60]   # Sunset orange
            else:  # Bottom - deep purple/blue
                base_color = [120, 60, 140]   # Evening purple
            
            # Add gentle wave movement
            wave = int(25 * np.sin(t * 0.4 + y / 80))
            
            # Apply color with wave effect
            final_color = [
                min(255, max(0, base_color[0] + wave)),
                min(255, max(0, base_color[1] + wave // 2)),
                min(255, max(0, base_color[2] + wave // 3))
            ]
            
            img[y, :] = final_color
            
        return img
    
    return VideoClip(make_frame, duration=duration)

def create_cross_pattern_background(duration, size=(1080, 1920)):
    """Create cross pattern with divine light"""
    def make_frame(t):
        img = np.zeros((size[1], size[0], 3), dtype=np.uint8)
        
        # Base golden background
        base_intensity = int(150 + 30 * np.sin(t * 0.5))
        base_color = [base_intensity, int(base_intensity * 0.8), int(base_intensity * 0.4)]
        img[:, :] = base_color
        
        # Cross dimensions
        cross_width = size[0] // 8
        cross_height = size[1] // 8
        center_x, center_y = size[0] // 2, size[1] // 2
        
        # Vertical cross bar
        vertical_left = center_x - cross_width // 2
        vertical_right = center_x + cross_width // 2
        
        # Horizontal cross bar
        horizontal_top = center_y - cross_height // 2
        horizontal_bottom = center_y + cross_height // 2
        
        # Divine light intensity (pulsing)
        light_intensity = int(255 * (0.7 + 0.3 * np.sin(t * 2)))
        light_color = [light_intensity, light_intensity, int(light_intensity * 0.9)]
        
        # Draw vertical bar of cross
        img[:, vertical_left:vertical_right] = light_color
        
        # Draw horizontal bar of cross
        img[horizontal_top:horizontal_bottom, :] = light_color
        
        # Add radiating light effect
        for i in range(0, size[1], 20):
            for j in range(0, size[0], 20):
                distance = np.sqrt((j - center_x)**2 + (i - center_y)**2)
                if distance < 200:
                    glow = int(50 * (1 - distance / 200) * np.sin(t * 3))
                    img[i, j] = [
                        min(255, img[i, j, 0] + glow),
                        min(255, img[i, j, 1] + glow),
                        min(255, img[i, j, 2] + glow // 2)
                    ]
        
        return img
    
    return VideoClip(make_frame, duration=duration)

def create_themed_video(theme_name, korean_script, title_text, subtitle_text):
    print(f"🎨 CREATING {theme_name.upper()} THEME VIDEO")
    print("=" * 50)
    
    print(f"📝 Korean script: {len(korean_script)} characters")
    
    # Generate Korean TTS
    print("🎤 Generating Korean audio...")
    tts = gTTS(text=korean_script, lang='ko', slow=False)
    
    with tempfile.NamedTemporaryFile(delete=False, suffix='.mp3') as audio_file:
        tts.save(audio_file.name)
        audio = AudioFileClip(audio_file.name)
        duration = audio.duration
        print(f"   Audio duration: {duration:.1f} seconds")
    
    # Create theme-specific background
    print(f"🎨 Creating {theme_name} background...")
    if theme_name == "sunset_worship":
        background = create_sunset_worship_background(duration)
    elif theme_name == "cross_pattern":
        background = create_cross_pattern_background(duration)
    
    # Add text overlays
    print("📝 Adding text overlay...")
    
    title_clip = TextClip(
        title_text,
        fontsize=60,
        color='white',
        font='Arial-Bold',
        stroke_color='black',
        stroke_width=3
    ).set_position(('center', 300)).set_duration(duration)
    
    subtitle_clip = TextClip(
        subtitle_text,
        fontsize=40,
        color='lightyellow',
        font='Arial',
        stroke_color='darkred',
        stroke_width=2
    ).set_position(('center', 1400)).set_duration(duration)
    
    # Compose final video
    print("🎬 Composing final video...")
    final_video = CompositeVideoClip([
        background,
        title_clip,
        subtitle_clip
    ]).set_audio(audio)
    
    # Export video
    output_file = f"fresh_{theme_name}.mp4"
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

def upload_to_youtube(video_file, metadata, access_token):
    print(f"🚀 UPLOADING {video_file.upper()} TO YOUTUBE...")
    
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
                
                print("🎉 SUCCESS!")
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
    access_token = "YOUR_ACCESS_TOKEN"
    
    # Theme definitions
    themes = [
        {
            "name": "sunset_worship",
            "korean_script": "하루를 마감하며 주님께 감사드리는 시간입니다. 오늘 하루를 돌아보며, 주님의 은혜를 기억합니다. 저녁 노을처럼 아름다운 주님의 사랑을 묵상하며, 내일도 주님과 함께 걸어갈 소망을 품습니다. 주님의 사랑으로 하루를 마무리합니다.",
            "title_text": "진리의 말씀\n저녁 경건시간",
            "subtitle_text": "감사와 소망",
            "youtube_title": "🌅 진리의 말씀 - 저녁 경건시간 | 감사와 소망",
            "youtube_description": "하루를 마감하며 주님께 감사드리는 시간입니다. 저녁 노을처럼 아름다운 주님의 사랑을 묵상하며, 내일도 주님과 함께 걸어갈 소망을 품습니다.\n\n🌅 Sunset Worship Theme - 저녁 경건시간\n📺 BibleStartup Channel\n🙏 Words of Truth",
            "tags": ["저녁기도", "감사", "소망", "한국어", "spiritual", "evening", "worship", "korean", "shorts", "진리의말씀"]
        },
        {
            "name": "cross_pattern",
            "korean_script": "십자가의 사랑을 기억하며 말씀을 나눕니다. 예수님께서 우리를 위해 십자가에서 보여주신 그 크신 사랑을 묵상합니다. 주님의 희생으로 우리가 구원받았음을 기억하며, 믿음으로 살아가는 하루가 되시기 바랍니다.",
            "title_text": "진리의 말씀\n십자가의 사랑",
            "subtitle_text": "성경과 믿음",
            "youtube_title": "✝️ 진리의 말씀 - 십자가의 사랑 | 성경과 믿음",
            "youtube_description": "십자가의 사랑을 기억하며 말씀을 나눕니다. 예수님께서 우리를 위해 십자가에서 보여주신 그 크신 사랑을 묵상합니다. 주님의 희생으로 우리가 구원받았음을 기억하며, 믿음으로 살아가는 하루가 되시기 바랍니다.\n\n✝️ Cross Pattern Theme - 십자가의 사랑\n📺 BibleStartup Channel\n🙏 Words of Truth",
            "tags": ["십자가", "사랑", "믿음", "한국어", "spiritual", "cross", "faith", "korean", "shorts", "진리의말씀"]
        }
    ]
    
    uploaded_videos = []
    
    for theme in themes:
        print(f"\n{'='*60}")
        print(f"CREATING THEME: {theme['name'].upper()}")
        print(f"{'='*60}")
        
        # Create video
        video_file = create_themed_video(
            theme['name'],
            theme['korean_script'],
            theme['title_text'],
            theme['subtitle_text']
        )
        
        # Prepare metadata
        metadata = {
            "snippet": {
                "title": theme['youtube_title'],
                "description": theme['youtube_description'],
                "tags": theme['tags'],
                "categoryId": "22"
            },
            "status": {
                "privacyStatus": "public",
                "selfDeclaredMadeForKids": False
            }
        }
        
        # Upload to YouTube
        result = upload_to_youtube(video_file, metadata, access_token)
        
        if result['success']:
            uploaded_videos.append({
                'theme': theme['name'],
                'title': theme['youtube_title'],
                'youtube_id': result['youtube_id'],
                'youtube_url': result['youtube_url']
            })
        
        # Cleanup video file
        if os.path.exists(video_file):
            os.remove(video_file)
        
        print(f"\n🎯 {theme['name'].upper()} COMPLETE!")
    
    # Final summary
    print(f"\n{'='*60}")
    print("🎉 ALL SPIRITUAL THEMES COMPLETE!")
    print(f"{'='*60}")
    
    print("\n📱 COMPLETE SPIRITUAL THEME SHOWCASE:")
    print("   🌟 Golden Light (Worship): https://youtu.be/6Bugm87RFQo")
    print("   🕯️ Peaceful Blue (Prayer): https://youtu.be/atgC2FW5ZO0")
    
    for video in uploaded_videos:
        emoji = "🌅" if "sunset" in video['theme'] else "✝️"
        print(f"   {emoji} {video['theme'].title().replace('_', ' ')}: {video['youtube_url']}")
    
    print(f"\n🏠 BibleStartup Channel: https://www.youtube.com/@BibleStartup")
    print("📊 Studio: https://studio.youtube.com/channel/UC4o3W-snviJWkgZLB xtkAeA/videos")
    print("\n✨ Complete spiritual theme collection ready for invitees! 🚀")

if __name__ == "__main__":
    main()