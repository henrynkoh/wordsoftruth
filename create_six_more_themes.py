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

def create_forest_light_background(duration, size=(1080, 1920)):
    """Create forest with divine light rays for nature/creation theme"""
    def make_frame(t):
        img = np.zeros((size[1], size[0], 3), dtype=np.uint8)
        
        # Forest green gradient
        for y in range(size[1]):
            gradient = y / size[1]
            
            # Light rays from top
            light_intensity = int(100 * (1 - gradient) * (0.8 + 0.2 * np.sin(t * 2)))
            
            # Forest colors
            green_base = int(60 + 40 * gradient + light_intensity)
            forest_color = [
                int(green_base * 0.4),  # Brown undertones
                min(255, green_base),   # Green
                int(green_base * 0.3)   # Low blue
            ]
            
            img[y, :] = forest_color
            
        # Add moving light rays
        for x in range(0, size[0], 60):
            ray_x = x + int(20 * np.sin(t * 0.5))
            if 0 <= ray_x < size[0]:
                for y in range(0, size[1] // 2):
                    ray_intensity = int(80 * (1 - y / (size[1] // 2)))
                    img[y, ray_x:ray_x+3] = [
                        min(255, img[y, ray_x, 0] + ray_intensity),
                        min(255, img[y, ray_x, 1] + ray_intensity),
                        min(255, img[y, ray_x, 2] + ray_intensity // 2)
                    ]
        
        return img
    
    return VideoClip(make_frame, duration=duration)

def create_starry_night_background(duration, size=(1080, 1920)):
    """Create starry night for night prayer/reflection theme"""
    def make_frame(t):
        img = np.zeros((size[1], size[0], 3), dtype=np.uint8)
        
        # Dark night sky gradient
        for y in range(size[1]):
            night_intensity = int(20 + 15 * (y / size[1]))
            night_color = [night_intensity, night_intensity, int(night_intensity * 1.5)]
            img[y, :] = night_color
            
        # Add twinkling stars
        np.random.seed(42)  # Fixed seed for consistent stars
        star_positions = [(np.random.randint(0, size[0]), np.random.randint(0, size[1])) 
                         for _ in range(50)]
        
        for i, (sx, sy) in enumerate(star_positions):
            twinkle = 0.5 + 0.5 * np.sin(t * 3 + i * 0.5)
            star_brightness = int(255 * twinkle)
            
            # Draw star with cross pattern
            if 0 <= sx < size[0] and 0 <= sy < size[1]:
                img[sy, sx] = [star_brightness, star_brightness, star_brightness]
                if sx > 0: img[sy, sx-1] = [star_brightness//2, star_brightness//2, star_brightness//2]
                if sx < size[0]-1: img[sy, sx+1] = [star_brightness//2, star_brightness//2, star_brightness//2]
                if sy > 0: img[sy-1, sx] = [star_brightness//2, star_brightness//2, star_brightness//2]
                if sy < size[1]-1: img[sy+1, sx] = [star_brightness//2, star_brightness//2, star_brightness//2]
        
        return img
    
    return VideoClip(make_frame, duration=duration)

def create_flame_background(duration, size=(1080, 1920)):
    """Create holy fire/spirit flame background"""
    def make_frame(t):
        img = np.zeros((size[1], size[0], 3), dtype=np.uint8)
        
        # Flame colors from bottom to top
        for y in range(size[1]):
            flame_pos = (size[1] - y) / size[1]  # Bottom to top
            
            # Flame movement
            flicker = int(30 * np.sin(t * 4 + y / 30) * flame_pos)
            
            if flame_pos > 0.7:  # Bottom - hot red/orange
                flame_color = [255, int(150 + flicker), int(50 + flicker//2)]
            elif flame_pos > 0.4:  # Middle - orange/yellow
                flame_color = [255, int(200 + flicker), int(100 + flicker)]
            else:  # Top - yellow/white
                flame_color = [int(255 - flicker//2), int(255 - flicker//3), int(200 + flicker)]
            
            img[y, :] = flame_color
            
        # Add flame movement
        wave = int(25 * np.sin(t * 2))
        img = np.roll(img, wave, axis=1)
        
        return img
    
    return VideoClip(make_frame, duration=duration)

def create_rainbow_covenant_background(duration, size=(1080, 1920)):
    """Create rainbow for covenant/promise theme"""
    def make_frame(t):
        img = np.zeros((size[1], size[0], 3), dtype=np.uint8)
        
        # Soft sky background
        for y in range(size[1]):
            sky_intensity = int(180 + 30 * (1 - y / size[1]))
            sky_color = [int(sky_intensity * 0.8), int(sky_intensity * 0.9), sky_intensity]
            img[y, :] = sky_color
        
        # Rainbow arc
        center_x, center_y = size[0] // 2, size[1] + 200
        rainbow_colors = [
            [255, 0, 0],     # Red
            [255, 127, 0],   # Orange
            [255, 255, 0],   # Yellow
            [0, 255, 0],     # Green
            [0, 0, 255],     # Blue
            [75, 0, 130],    # Indigo
            [148, 0, 211]    # Violet
        ]
        
        # Draw rainbow bands
        for color_idx, color in enumerate(rainbow_colors):
            radius = 400 + color_idx * 20
            thickness = 15
            
            # Gentle movement
            wave_offset = int(10 * np.sin(t * 0.5 + color_idx * 0.3))
            
            for y in range(size[1]):
                for x in range(size[0]):
                    dist = np.sqrt((x - center_x)**2 + (y - center_y)**2)
                    if radius - thickness <= dist <= radius + thickness:
                        if y < size[1] // 2:  # Only upper part of arc
                            alpha = 0.6 + 0.2 * np.sin(t + color_idx)
                            img[y + wave_offset, x] = [
                                int(img[y + wave_offset, x, 0] * (1-alpha) + color[0] * alpha),
                                int(img[y + wave_offset, x, 1] * (1-alpha) + color[1] * alpha),
                                int(img[y + wave_offset, x, 2] * (1-alpha) + color[2] * alpha)
                            ]
        
        return img
    
    return VideoClip(make_frame, duration=duration)

def create_dove_peace_background(duration, size=(1080, 1920)):
    """Create peaceful dove with olive branch theme"""
    def make_frame(t):
        img = np.zeros((size[1], size[0], 3), dtype=np.uint8)
        
        # Peaceful sky gradient
        for y in range(size[1]):
            gradient = y / size[1]
            peace_intensity = int(200 + 40 * gradient)
            peace_color = [
                int(peace_intensity * 0.9),  # Soft white
                int(peace_intensity * 0.95), # Slightly blue-white
                peace_intensity              # Pure white
            ]
            img[y, :] = peace_color
        
        # Gentle clouds
        cloud_offset = int(20 * np.sin(t * 0.3))
        for y in range(size[1] // 3, 2 * size[1] // 3, 40):
            for x in range(0, size[0], 80):
                cloud_x = x + cloud_offset
                if 0 <= cloud_x < size[0]:
                    # Soft cloud shapes
                    for dy in range(-15, 16):
                        for dx in range(-30, 31):
                            if y + dy >= 0 and y + dy < size[1] and cloud_x + dx >= 0 and cloud_x + dx < size[0]:
                                dist = np.sqrt(dx*dx + dy*dy)
                                if dist < 25:
                                    cloud_alpha = (25 - dist) / 25 * 0.3
                                    cloud_white = int(255 * cloud_alpha)
                                    img[y + dy, cloud_x + dx] = [
                                        min(255, img[y + dy, cloud_x + dx, 0] + cloud_white),
                                        min(255, img[y + dy, cloud_x + dx, 1] + cloud_white),
                                        min(255, img[y + dy, cloud_x + dx, 2] + cloud_white)
                                    ]
        
        # Subtle dove silhouette movement
        dove_y = size[1] // 2 + int(30 * np.sin(t * 0.8))
        dove_x = size[0] // 2 + int(50 * np.sin(t * 0.6))
        
        # Simple dove shape (abstract)
        if 0 <= dove_x < size[0] and 0 <= dove_y < size[1]:
            for dy in range(-5, 6):
                for dx in range(-10, 11):
                    if 0 <= dove_y + dy < size[1] and 0 <= dove_x + dx < size[0]:
                        if abs(dy) <= 2 and abs(dx) <= 8:  # Wing span
                            img[dove_y + dy, dove_x + dx] = [240, 240, 255]
        
        return img
    
    return VideoClip(make_frame, duration=duration)

def create_themed_video(theme_config):
    theme_name = theme_config['name']
    print(f"🎨 CREATING {theme_name.upper().replace('_', ' ')} THEME VIDEO")
    print("=" * 50)
    
    korean_script = theme_config['korean_script']
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
    if theme_name == "ocean_waves":
        background = create_ocean_waves_background(duration)
    elif theme_name == "forest_light":
        background = create_forest_light_background(duration)
    elif theme_name == "starry_night":
        background = create_starry_night_background(duration)
    elif theme_name == "holy_flame":
        background = create_flame_background(duration)
    elif theme_name == "rainbow_covenant":
        background = create_rainbow_covenant_background(duration)
    elif theme_name == "dove_peace":
        background = create_dove_peace_background(duration)
    
    # Add text overlays
    print("📝 Adding text overlay...")
    
    title_clip = TextClip(
        theme_config['title_text'],
        fontsize=55,
        color='white',
        font='Arial-Bold',
        stroke_color='black',
        stroke_width=3
    ).set_position(('center', 280)).set_duration(duration)
    
    subtitle_clip = TextClip(
        theme_config['subtitle_text'],
        fontsize=38,
        color=theme_config.get('subtitle_color', 'lightyellow'),
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
    output_file = f"theme_{theme_name}.mp4"
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
                print(f"   Short URL: https://youtu.be/{youtube_id}")
                
                return {
                    'success': True,
                    'youtube_id': youtube_id,
                    'youtube_url': youtube_url
                }
            else:
                print(f"❌ Upload failed: {response.status_code}")
                return {'success': False, 'error': response.text}
                
    except Exception as e:
        print(f"❌ Upload error: {str(e)}")
        return {'success': False, 'error': str(e)}

def main():
    access_token = "YOUR_ACCESS_TOKEN"
    
    # 6 New Spiritual Themes
    themes = [
        {
            "name": "ocean_waves",
            "korean_script": "주님의 은혜가 바다처럼 넓고 깊습니다. 세례의 물이 우리의 죄를 씻어주시고, 새로운 생명으로 거듭나게 하셨습니다. 파도처럼 밀려오는 주님의 사랑 안에서 우리는 새로워집니다. 매일 주님 안에서 새롭게 태어나는 은혜를 누리시기 바랍니다.",
            "title_text": "진리의 말씀\n세례와 새생명",
            "subtitle_text": "거듭남의 은혜",
            "subtitle_color": "lightcyan",
            "youtube_title": "🌊 진리의 말씀 - 세례와 새생명 | 거듭남의 은혜",
            "youtube_description": "주님의 은혜가 바다처럼 넓고 깊습니다. 세례의 물이 우리의 죄를 씻어주시고, 새로운 생명으로 거듭나게 하셨습니다. 파도처럼 밀려오는 주님의 사랑 안에서 우리는 새로워집니다.\n\n🌊 Ocean Waves Theme - 세례와 새생명\n📺 BibleStartup Channel\n🙏 Words of Truth",
            "tags": ["세례", "새생명", "거듭남", "한국어", "baptism", "renewal", "rebirth", "korean", "shorts", "진리의말씀"]
        },
        {
            "name": "forest_light",
            "korean_script": "하나님께서 창조하신 자연을 통해 그분의 영광을 봅니다. 숲속의 빛줄기처럼 주님의 말씀이 우리 마음을 비춥니다. 모든 피조물이 창조주를 찬양합니다. 자연 속에서 하나님의 놀라운 손길을 발견하며 감사하는 마음을 갖게 됩니다.",
            "title_text": "진리의 말씀\n창조의 영광",
            "subtitle_text": "자연과 하나님",
            "subtitle_color": "lightgreen",
            "youtube_title": "🌲 진리의 말씀 - 창조의 영광 | 자연과 하나님",
            "youtube_description": "하나님께서 창조하신 자연을 통해 그분의 영광을 봅니다. 숲속의 빛줄기처럼 주님의 말씀이 우리 마음을 비춥니다. 모든 피조물이 창조주를 찬양합니다.\n\n🌲 Forest Light Theme - 창조의 영광\n📺 BibleStartup Channel\n🙏 Words of Truth",
            "tags": ["창조", "자연", "영광", "한국어", "creation", "nature", "glory", "korean", "shorts", "진리의말씀"]
        },
        {
            "name": "starry_night",
            "korean_script": "밤하늘의 별들이 하나님의 광대하심을 증거합니다. 고요한 밤에 주님과 교제하며 깊은 묵상의 시간을 갖습니다. 어둠 속에서도 빛나는 별처럼, 우리도 세상의 빛이 되어야 합니다. 주님 앞에서 조용히 기도하는 밤이 되시기 바랍니다.",
            "title_text": "진리의 말씀\n밤의 기도",
            "subtitle_text": "고요한 묵상",
            "subtitle_color": "lightsteelblue",
            "youtube_title": "⭐ 진리의 말씀 - 밤의 기도 | 고요한 묵상",
            "youtube_description": "밤하늘의 별들이 하나님의 광대하심을 증거합니다. 고요한 밤에 주님과 교제하며 깊은 묵상의 시간을 갖습니다. 어둠 속에서도 빛나는 별처럼, 우리도 세상의 빛이 되어야 합니다.\n\n⭐ Starry Night Theme - 밤의 기도\n📺 BibleStartup Channel\n🙏 Words of Truth",
            "tags": ["밤기도", "묵상", "별", "한국어", "night", "prayer", "meditation", "stars", "korean", "shorts", "진리의말씀"]
        },
        {
            "name": "holy_flame",
            "korean_script": "성령의 불이 우리 마음에 임하시기를 기도합니다. 정결케 하시는 거룩한 불로 우리를 깨끗하게 하여 주옵소서. 뜨거운 성령의 역사로 새 힘을 얻고, 주님을 섬기는 열정이 타오르게 하여 주옵소서. 성령충만한 삶을 살아가시기 바랍니다.",
            "title_text": "진리의 말씀\n성령의 불",
            "subtitle_text": "거룩한 열정",
            "subtitle_color": "orange",
            "youtube_title": "🔥 진리의 말씀 - 성령의 불 | 거룩한 열정",
            "youtube_description": "성령의 불이 우리 마음에 임하시기를 기도합니다. 정결케 하시는 거룩한 불로 우리를 깨끗하게 하여 주옵소서. 뜨거운 성령의 역사로 새 힘을 얻고, 주님을 섬기는 열정이 타오르게 하여 주옵소서.\n\n🔥 Holy Flame Theme - 성령의 불\n📺 BibleStartup Channel\n🙏 Words of Truth",
            "tags": ["성령", "불", "열정", "한국어", "holy", "spirit", "fire", "passion", "korean", "shorts", "진리의말씀"]
        },
        {
            "name": "rainbow_covenant",
            "korean_script": "무지개는 하나님의 언약의 표징입니다. 홍수 후에 주신 약속처럼, 주님은 우리와 맺으신 언약을 결코 잊지 않으십니다. 어떤 시험과 어려움이 와도 하나님의 신실하심을 믿고 의지합니다. 언약의 하나님을 찬양합니다.",
            "title_text": "진리의 말씀\n하나님의 언약",
            "subtitle_text": "신실한 약속",
            "subtitle_color": "violet",
            "youtube_title": "🌈 진리의 말씀 - 하나님의 언약 | 신실한 약속",
            "youtube_description": "무지개는 하나님의 언약의 표징입니다. 홍수 후에 주신 약속처럼, 주님은 우리와 맺으신 언약을 결코 잊지 않으십니다. 어떤 시험과 어려움이 와도 하나님의 신실하심을 믿고 의지합니다.\n\n🌈 Rainbow Covenant Theme - 하나님의 언약\n📺 BibleStartup Channel\n🙏 Words of Truth",
            "tags": ["언약", "약속", "신실", "한국어", "covenant", "promise", "faithful", "rainbow", "korean", "shorts", "진리의말씀"]
        },
        {
            "name": "dove_peace",
            "korean_script": "비둘기가 올리브 가지를 물고 온 것처럼, 주님께서 우리에게 참된 평화를 주십니다. 세상이 줄 수 없는 평안을 우리 마음에 허락하여 주옵소서. 성령님이 비둘기같이 온유하게 우리와 함께하시며, 평화의 왕이신 예수님을 닮아가게 하옵소서.",
            "title_text": "진리의 말씀\n평화의 성령",
            "subtitle_text": "온유한 마음",
            "subtitle_color": "white",
            "youtube_title": "🕊️ 진리의 말씀 - 평화의 성령 | 온유한 마음",
            "youtube_description": "비둘기가 올리브 가지를 물고 온 것처럼, 주님께서 우리에게 참된 평화를 주십니다. 세상이 줄 수 없는 평안을 우리 마음에 허락하여 주옵소서. 성령님이 비둘기같이 온유하게 우리와 함께하시며, 평화의 왕이신 예수님을 닮아가게 하옵소서.\n\n🕊️ Dove Peace Theme - 평화의 성령\n📺 BibleStartup Channel\n🙏 Words of Truth",
            "tags": ["평화", "성령", "온유", "한국어", "peace", "spirit", "dove", "gentle", "korean", "shorts", "진리의말씀"]
        }
    ]
    
    uploaded_videos = []
    
    for i, theme in enumerate(themes):
        print(f"\n{'='*60}")
        print(f"CREATING THEME {i+1}/6: {theme['name'].upper().replace('_', ' ')}")
        print(f"{'='*60}")
        
        # Create video
        video_file = create_themed_video(theme)
        
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
        
        print(f"\n✅ {theme['name'].upper().replace('_', ' ')} COMPLETE!")
        
        # Small delay between uploads
        if i < len(themes) - 1:
            print("⏳ Brief pause before next upload...")
            import time
            time.sleep(3)
    
    # Final summary
    print(f"\n{'='*60}")
    print("🎉 ALL 6 NEW SPIRITUAL THEMES COMPLETE!")
    print(f"{'='*60}")
    
    print("\n📱 COMPLETE 10-THEME SPIRITUAL SHOWCASE:")
    print("   🌟 Golden Light (Worship): https://youtu.be/6Bugm87RFQo")
    print("   🕯️ Peaceful Blue (Prayer): https://youtu.be/atgC2FW5ZO0")
    print("   🌅 Sunset Worship (Evening): https://youtu.be/LkM-wYwfjak")
    print("   ✝️ Cross Pattern (Faith): https://youtu.be/Fie5PJ02JYw")
    
    theme_emojis = {
        'ocean_waves': '🌊',
        'forest_light': '🌲',
        'starry_night': '⭐',
        'holy_flame': '🔥',
        'rainbow_covenant': '🌈',
        'dove_peace': '🕊️'
    }
    
    for video in uploaded_videos:
        emoji = theme_emojis.get(video['theme'], '✨')
        theme_display = video['theme'].replace('_', ' ').title()
        print(f"   {emoji} {theme_display}: {video['youtube_url']}")
    
    print(f"\n🏠 BibleStartup Channel: https://www.youtube.com/@BibleStartup")
    print("📊 Studio: https://studio.youtube.com/channel/UC4o3W-snviJWkgZLBxtkAeA/videos")
    print("\n✨ Complete 10-theme spiritual collection - perfect variety for invitees! 🚀")

if __name__ == "__main__":
    main()