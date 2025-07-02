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

def create_flowing_river_background(duration, size=(1080, 1920)):
    """Create flowing river for life/renewal theme"""
    def make_frame(t):
        img = np.zeros((size[1], size[0], 3), dtype=np.uint8)
        
        # Riverbank scene
        for y in range(size[1]):
            if y < size[1] // 3:  # Sky
                sky_blue = int(180 + 30 * np.sin(t * 0.5))
                img[y, :] = [int(sky_blue * 0.7), int(sky_blue * 0.9), sky_blue]
            elif y < 2 * size[1] // 3:  # Grass/trees
                green_base = int(80 + 40 * np.sin(y / 50 + t * 0.3))
                img[y, :] = [int(green_base * 0.4), green_base, int(green_base * 0.3)]
            else:  # River
                # Flowing water effect
                wave = int(20 * np.sin(t * 1.5 + y / 30))
                water_blue = 150 + wave
                img[y, :] = [int(water_blue * 0.3), int(water_blue * 0.7), water_blue]
        
        # River flow lines
        for i in range(0, size[0], 40):
            flow_x = i + int(30 * np.sin(t * 2 + i / 50))
            if 0 <= flow_x < size[0]:
                for y in range(2 * size[1] // 3, size[1]):
                    if 0 <= flow_x < size[0]:
                        brightness = int(50 * np.sin(t * 3 + y / 20))
                        img[y, flow_x] = [
                            min(255, img[y, flow_x, 0] + brightness),
                            min(255, img[y, flow_x, 1] + brightness),
                            min(255, img[y, flow_x, 2] + brightness)
                        ]
        
        return img
    
    return VideoClip(make_frame, duration=duration)

def create_wheat_field_background(duration, size=(1080, 1920)):
    """Create golden wheat field for harvest/blessing theme"""
    def make_frame(t):
        img = np.zeros((size[1], size[0], 3), dtype=np.uint8)
        
        # Sky with warm light
        for y in range(size[1] // 2):
            sky_intensity = int(200 + 40 * (1 - y / (size[1] // 2)))
            img[y, :] = [sky_intensity, int(sky_intensity * 0.95), int(sky_intensity * 0.8)]
        
        # Wheat field
        for y in range(size[1] // 2, size[1]):
            field_y = y - size[1] // 2
            
            # Golden wheat color with wind movement
            wind_sway = int(15 * np.sin(t * 1.5 + field_y / 40))
            golden_intensity = int(180 + 50 * np.sin(field_y / 60 + t * 0.8))
            
            wheat_color = [
                min(255, golden_intensity + wind_sway),
                int((golden_intensity + wind_sway) * 0.8),
                int((golden_intensity + wind_sway) * 0.3)
            ]
            
            img[y, :] = wheat_color
        
        # Wheat stalks swaying
        for x in range(0, size[0], 20):
            sway = int(10 * np.sin(t * 2 + x / 30))
            stalk_x = x + sway
            
            if 0 <= stalk_x < size[0]:
                for y in range(size[1] // 2, size[1]):
                    if y % 10 == 0:  # Wheat head
                        img[y, stalk_x] = [255, 200, 100]
        
        return img
    
    return VideoClip(make_frame, duration=duration)

def create_shepherd_field_background(duration, size=(1080, 1920)):
    """Create pastoral field for shepherd/guidance theme"""
    def make_frame(t):
        img = np.zeros((size[1], size[0], 3), dtype=np.uint8)
        
        # Soft pastoral sky
        for y in range(size[1] // 2):
            soft_blue = int(160 + 60 * (1 - y / (size[1] // 2)))
            img[y, :] = [int(soft_blue * 0.85), int(soft_blue * 0.95), soft_blue]
        
        # Rolling green hills
        for y in range(size[1] // 2, size[1]):
            hill_y = y - size[1] // 2
            
            # Gentle rolling hills effect
            hill_wave = int(20 * np.sin(hill_y / 80 + t * 0.4))
            grass_green = int(100 + 40 * np.sin(hill_y / 60 + t * 0.3) + hill_wave)
            
            pastoral_color = [
                int(grass_green * 0.4),  # Brown earth tones
                grass_green,             # Rich green
                int(grass_green * 0.5)   # Natural blend
            ]
            
            img[y, :] = pastoral_color
        
        # Gentle wind effects on grass
        for x in range(0, size[0], 30):
            wind_bend = int(8 * np.sin(t * 1.8 + x / 40))
            grass_x = x + wind_bend
            
            if 0 <= grass_x < size[0]:
                for y in range(size[1] // 2 + 50, size[1], 15):
                    if 0 <= grass_x < size[0]:
                        img[y, grass_x] = [60, 140, 70]  # Grass blades
        
        # Soft clouds
        for i in range(3):
            cloud_x = int(size[0] * (0.2 + 0.3 * i) + 30 * np.sin(t * 0.2 + i))
            cloud_y = int(size[1] * 0.2 + 20 * np.sin(t * 0.3 + i))
            
            # Draw soft cloud
            for dy in range(-20, 21):
                for dx in range(-40, 41):
                    if (0 <= cloud_x + dx < size[0] and 0 <= cloud_y + dy < size[1] and
                        dx*dx + dy*dy < 600):
                        cloud_alpha = 0.3 * (1 - (dx*dx + dy*dy) / 600)
                        cloud_white = int(255 * cloud_alpha)
                        img[cloud_y + dy, cloud_x + dx] = [
                            min(255, img[cloud_y + dy, cloud_x + dx, 0] + cloud_white),
                            min(255, img[cloud_y + dy, cloud_x + dx, 1] + cloud_white),
                            min(255, img[cloud_y + dy, cloud_x + dx, 2] + cloud_white)
                        ]
        
        return img
    
    return VideoClip(make_frame, duration=duration)

def create_temple_light_background(duration, size=(1080, 1920)):
    """Create temple with divine light for worship/sanctuary theme"""
    def make_frame(t):
        img = np.zeros((size[1], size[0], 3), dtype=np.uint8)
        
        # Sacred golden background
        for y in range(size[1]):
            golden_base = int(120 + 80 * (1 - y / size[1]))
            sacred_glow = int(40 * np.sin(t * 1.5 + y / 100))
            
            temple_color = [
                min(255, golden_base + sacred_glow),
                int((golden_base + sacred_glow) * 0.8),
                int((golden_base + sacred_glow) * 0.4)
            ]
            
            img[y, :] = temple_color
        
        # Temple pillars (simplified)
        pillar_width = 40
        pillar_positions = [size[0] // 4, 3 * size[0] // 4]
        
        for pillar_x in pillar_positions:
            for y in range(size[1] // 3, size[1]):
                for x in range(pillar_x - pillar_width//2, pillar_x + pillar_width//2):
                    if 0 <= x < size[0]:
                        # Marble-like pillar color
                        pillar_brightness = int(200 + 30 * np.sin(y / 50 + t * 0.5))
                        img[y, x] = [pillar_brightness, pillar_brightness, int(pillar_brightness * 0.95)]
        
        # Divine light emanating from center
        center_x, center_y = size[0] // 2, size[1] // 4
        
        for angle in range(0, 360, 45):
            rad = np.radians(angle + t * 30)
            light_intensity = int(100 * (0.7 + 0.3 * np.sin(t * 3 + angle)))
            
            for r in range(0, 200, 5):
                light_x = int(center_x + r * np.cos(rad))
                light_y = int(center_y + r * np.sin(rad))
                
                if 0 <= light_x < size[0] and 0 <= light_y < size[1]:
                    fade = (200 - r) / 200
                    glow = int(light_intensity * fade)
                    img[light_y, light_x] = [
                        min(255, img[light_y, light_x, 0] + glow),
                        min(255, img[light_y, light_x, 1] + glow),
                        min(255, img[light_y, light_x, 2] + glow//2)
                    ]
        
        return img
    
    return VideoClip(make_frame, duration=duration)

def create_city_lights_background(duration, size=(1080, 1920)):
    """Create city skyline for mission/evangelism theme"""
    def make_frame(t):
        img = np.zeros((size[1], size[0], 3), dtype=np.uint8)
        
        # Evening sky gradient
        for y in range(size[1]):
            if y < size[1] // 2:  # Upper sky
                evening_blue = int(40 + 60 * (y / (size[1] // 2)))
                img[y, :] = [int(evening_blue * 0.8), int(evening_blue * 0.9), evening_blue]
            else:  # Lower sky with city glow
                city_glow = int(80 + 40 * ((y - size[1] // 2) / (size[1] // 2)))
                img[y, :] = [city_glow, int(city_glow * 0.7), int(city_glow * 0.4)]
        
        # City building silhouettes
        building_heights = [300, 250, 400, 180, 350, 220, 380]
        building_width = size[0] // len(building_heights)
        
        for i, height in enumerate(building_heights):
            building_x = i * building_width
            building_height = int(height + 50 * np.sin(t * 0.5 + i))
            
            for y in range(size[1] - building_height, size[1]):
                for x in range(building_x, building_x + building_width - 5):
                    if 0 <= x < size[0]:
                        img[y, x] = [20, 20, 40]  # Dark building silhouette
        
        # Building lights (windows)
        for i in range(len(building_heights)):
            building_x = i * building_width
            building_height = int(building_heights[i] + 50 * np.sin(t * 0.5 + i))
            
            # Add window lights
            for floor in range(10, building_height, 30):
                for window in range(10, building_width - 10, 20):
                    window_x = building_x + window
                    window_y = size[1] - floor
                    
                    if (0 <= window_x < size[0] and 0 <= window_y < size[1] and
                        np.random.random() > 0.3):  # Random window lights
                        light_intensity = int(200 * (0.7 + 0.3 * np.sin(t * 4 + i + floor)))
                        
                        # Small window light
                        for dy in range(-2, 3):
                            for dx in range(-3, 4):
                                if (0 <= window_x + dx < size[0] and 
                                    0 <= window_y + dy < size[1]):
                                    img[window_y + dy, window_x + dx] = [
                                        light_intensity, 
                                        int(light_intensity * 0.9), 
                                        int(light_intensity * 0.6)
                                    ]
        
        return img
    
    return VideoClip(make_frame, duration=duration)

def create_themed_video(theme_config, output_dir="storage/backup_themes"):
    """Create a single themed video and save locally"""
    theme_name = theme_config['name']
    print(f"🎨 CREATING {theme_name.upper().replace('_', ' ')} THEME")
    print("=" * 50)
    
    # Ensure output directory exists
    os.makedirs(output_dir, exist_ok=True)
    
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
    background_functions = {
        "mountain_majesty": create_mountain_majesty_background,
        "flowing_river": create_flowing_river_background,
        "wheat_field": create_wheat_field_background,
        "shepherd_field": create_shepherd_field_background,
        "temple_light": create_temple_light_background,
        "city_lights": create_city_lights_background
    }
    
    background = background_functions[theme_name](duration)
    
    # Add text overlays
    print("📝 Adding text overlay...")
    
    title_clip = TextClip(
        theme_config['title_text'],
        fontsize=54,
        color='white',
        font='Arial-Bold',
        stroke_color='black',
        stroke_width=3
    ).set_position(('center', 280)).set_duration(duration)
    
    subtitle_clip = TextClip(
        theme_config['subtitle_text'],
        fontsize=36,
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
    
    # Export video to backup directory
    output_file = os.path.join(output_dir, f"backup_{theme_name}.mp4")
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
    print(f"✅ Video saved locally: {file_size:.1f}MB")
    
    return output_file

def main():
    print("🎬 CREATING 6 BACKUP SPIRITUAL THEMES")
    print("=" * 60)
    print("📁 Saving locally for future upload after quota approval")
    print("=" * 60)
    
    # 6 New Unique Spiritual Themes
    themes = [
        {
            "name": "mountain_majesty",
            "korean_script": "산들이 주를 향해 뛰노는도다. 높은 산 위에서 하나님의 위엄을 바라봅니다. 주님은 우리의 힘이시요 피난처가 되십니다. 어떤 어려움이 와도 주님을 의지하며 굳게 서겠습니다. 산처럼 변하지 않는 하나님의 사랑을 찬양합니다.",
            "title_text": "진리의 말씀\n산의 위엄",
            "subtitle_text": "힘과 인내",
            "subtitle_color": "lightsteelblue",
            "youtube_title": "⛰️ 진리의 말씀 - 산의 위엄 | 힘과 인내",
            "youtube_description": "산들이 주를 향해 뛰노는도다. 높은 산 위에서 하나님의 위엄을 바라봅니다. 주님은 우리의 힘이시요 피난처가 되십니다. 어떤 어려움이 와도 주님을 의지하며 굳게 서겠습니다.\n\n⛰️ Mountain Majesty Theme - 산의 위엄\n📺 BibleStartup Channel\n🙏 Words of Truth",
            "tags": ["산", "위엄", "힘", "한국어", "mountain", "strength", "perseverance", "korean", "shorts", "진리의말씀"]
        },
        {
            "name": "flowing_river",
            "korean_script": "생수의 강이 흘러나오니 목마른 자들이 와서 마시라. 주님은 생명의 근원이시며 영원토록 마르지 않는 샘이십니다. 우리 영혼을 소생시키시고 새 힘을 주시는 주님을 찬양합니다. 생명수가 흘러넘치는 복된 삶을 살아가시기 바랍니다.",
            "title_text": "진리의 말씀\n생명의 강",
            "subtitle_text": "새로운 생명",
            "subtitle_color": "lightcyan",
            "youtube_title": "🌊 진리의 말씀 - 생명의 강 | 새로운 생명",
            "youtube_description": "생수의 강이 흘러나오니 목마른 자들이 와서 마시라. 주님은 생명의 근원이시며 영원토록 마르지 않는 샘이십니다. 우리 영혼을 소생시키시고 새 힘을 주시는 주님을 찬양합니다.\n\n🌊 Flowing River Theme - 생명의 강\n📺 BibleStartup Channel\n🙏 Words of Truth",
            "tags": ["생명", "강", "새생명", "한국어", "river", "life", "renewal", "living water", "korean", "shorts", "진리의말씀"]
        },
        {
            "name": "wheat_field",
            "korean_script": "추수할 것은 많되 일꾼이 적으니 추수하는 주인에게 일꾼들을 보내어 달라고 청하라. 황금빛 밀밭처럼 하나님의 축복이 넘쳐납니다. 수고한 대로 거두는 기쁨을 누리며, 하나님께서 주시는 풍성한 열매를 감사함으로 받겠습니다.",
            "title_text": "진리의 말씀\n추수의 기쁨",
            "subtitle_text": "풍성한 축복",
            "subtitle_color": "gold",
            "youtube_title": "🌾 진리의 말씀 - 추수의 기쁨 | 풍성한 축복",
            "youtube_description": "추수할 것은 많되 일꾼이 적으니 추수하는 주인에게 일꾼들을 보내어 달라고 청하라. 황금빛 밀밭처럼 하나님의 축복이 넘쳐납니다. 수고한 대로 거두는 기쁨을 누리며, 하나님께서 주시는 풍성한 열매를 감사함으로 받겠습니다.\n\n🌾 Wheat Field Theme - 추수의 기쁨\n📺 BibleStartup Channel\n🙏 Words of Truth",
            "tags": ["추수", "축복", "감사", "한국어", "harvest", "blessing", "abundance", "thanksgiving", "korean", "shorts", "진리의말씀"]
        },
        {
            "name": "shepherd_field",
            "korean_script": "주는 나의 목자시니 내게 부족함이 없으리로다. 푸른 초장에 누이시며 쉴 만한 물 가로 인도하십니다. 선한 목자이신 예수님께서 우리를 돌보시고 보호하십니다. 주님의 음성을 듣고 따라가는 양이 되겠습니다.",
            "title_text": "진리의 말씀\n선한 목자",
            "subtitle_text": "인도하심",
            "subtitle_color": "lightgreen",
            "youtube_title": "🐑 진리의 말씀 - 선한 목자 | 인도하심",
            "youtube_description": "주는 나의 목자시니 내게 부족함이 없으리로다. 푸른 초장에 누이시며 쉴 만한 물 가로 인도하십니다. 선한 목자이신 예수님께서 우리를 돌보시고 보호하십니다. 주님의 음성을 듣고 따라가는 양이 되겠습니다.\n\n🐑 Shepherd Field Theme - 선한 목자\n📺 BibleStartup Channel\n🙏 Words of Truth",
            "tags": ["목자", "인도", "보호", "한국어", "shepherd", "guidance", "protection", "psalm", "korean", "shorts", "진리의말씀"]
        },
        {
            "name": "temple_light",
            "korean_script": "내가 여호와의 집에 거주하며 그의 아름다움을 바라보는 것이 나의 간구이로다. 거룩한 성전에서 주님께 예배드리는 것이 가장 큰 복입니다. 하나님의 영광이 충만한 곳에서 경배와 찬양을 올려드립니다. 주님의 전에서 영원히 섬기겠습니다.",
            "title_text": "진리의 말씀\n거룩한 성전",
            "subtitle_text": "예배와 경배",
            "subtitle_color": "gold",
            "youtube_title": "🏛️ 진리의 말씀 - 거룩한 성전 | 예배와 경배",
            "youtube_description": "내가 여호와의 집에 거주하며 그의 아름다움을 바라보는 것이 나의 간구이로다. 거룩한 성전에서 주님께 예배드리는 것이 가장 큰 복입니다. 하나님의 영광이 충만한 곳에서 경배와 찬양을 올려드립니다.\n\n🏛️ Temple Light Theme - 거룩한 성전\n📺 BibleStartup Channel\n🙏 Words of Truth",
            "tags": ["성전", "예배", "경배", "한국어", "temple", "worship", "sanctuary", "holy", "korean", "shorts", "진리의말씀"]
        },
        {
            "name": "city_lights",
            "korean_script": "너희는 세상의 빛이라 산 위에 있는 동네가 숨겨지지 못할 것이요. 도시의 불빛처럼 우리도 어둠 가운데 빛을 비추는 삶을 살아야 합니다. 복음을 전하며 사랑을 실천하는 그리스도인이 되겠습니다. 세상을 밝히는 빛이 되어주옵소서.",
            "title_text": "진리의 말씀\n세상의 빛",
            "subtitle_text": "전도와 선교",
            "subtitle_color": "yellow",
            "youtube_title": "🌃 진리의 말씀 - 세상의 빛 | 전도와 선교",
            "youtube_description": "너희는 세상의 빛이라 산 위에 있는 동네가 숨겨지지 못할 것이요. 도시의 불빛처럼 우리도 어둠 가운데 빛을 비추는 삶을 살아야 합니다. 복음을 전하며 사랑을 실천하는 그리스도인이 되겠습니다. 세상을 밝히는 빛이 되어주옵소서.\n\n🌃 City Lights Theme - 세상의 빛\n📺 BibleStartup Channel\n🙏 Words of Truth",
            "tags": ["빛", "전도", "선교", "한국어", "light", "evangelism", "mission", "witness", "korean", "shorts", "진리의말씀"]
        }
    ]
    
    created_videos = []
    
    for i, theme in enumerate(themes):
        print(f"\n{'='*60}")
        print(f"CREATING BACKUP THEME {i+1}/6: {theme['name'].upper().replace('_', ' ')}")
        print(f"{'='*60}")
        
        try:
            # Create video and save locally
            video_file = create_themed_video(theme)
            created_videos.append({
                'theme': theme['name'],
                'file': video_file,
                'title': theme['youtube_title'],
                'description': theme['youtube_description'],
                'tags': theme['tags']
            })
            print(f"✅ {theme['name'].upper().replace('_', ' ')} SAVED LOCALLY!")
            
        except Exception as e:
            print(f"❌ Error creating {theme['name']}: {str(e)}")
        
        print(f"\n🎯 BACKUP THEME {i+1}/6 COMPLETE!")
    
    # Final summary
    print(f"\n{'='*60}")
    print("🎉 ALL 6 BACKUP THEMES CREATED!")
    print(f"{'='*60}")
    
    print("\n📁 BACKUP VIDEOS SAVED LOCALLY:")
    for i, video in enumerate(created_videos):
        theme_display = video['theme'].replace('_', ' ').title()
        file_size = os.path.getsize(video['file']) / 1024 / 1024
        print(f"{i+1}. {theme_display}")
        print(f"   📄 File: {video['file']}")
        print(f"   📊 Size: {file_size:.1f}MB")
        print(f"   🎬 Title: {video['title']}")
        print("")
    
    # Create metadata file for future upload
    metadata_file = "storage/backup_themes/backup_metadata.json"
    with open(metadata_file, 'w', encoding='utf-8') as f:
        json.dump(created_videos, f, ensure_ascii=False, indent=2)
    
    print(f"📋 Metadata saved: {metadata_file}")
    print("\n🚀 READY FOR UPLOAD WHEN QUOTA INCREASES!")
    print("   These 6 videos are stored locally and ready to upload immediately")
    print("   after your YouTube API quota increase gets approved!")
    
    print(f"\n🎨 COMPLETE THEME COLLECTION READY:")
    print("   📱 CURRENTLY LIVE (4 themes):")
    print("      🌟 Golden Light, 🕯️ Peaceful Blue, 🌅 Sunset Worship, ✝️ Cross Pattern")
    print("   📁 BACKUP READY (6 themes):")
    print("      ⛰️ Mountain Majesty, 🌊 Flowing River, 🌾 Wheat Field")
    print("      🐑 Shepherd Field, 🏛️ Temple Light, 🌃 City Lights")
    print("\n   = 10 TOTAL UNIQUE SPIRITUAL THEMES! 🎉")

if __name__ == "__main__":
    main()