#!/usr/bin/env python3

import os
import json
import requests
import sys
from requests_toolbelt.multipart.encoder import MultipartEncoder

# YouTube API configuration
YOUTUBE_UPLOAD_URL = 'https://www.googleapis.com/upload/youtube/v3/videos'
ACCESS_TOKEN = "YOUR_ACCESS_TOKEN"

def upload_peaceful_blue():
    print("🕯️ UPLOADING PEACEFUL BLUE THEME TO YOUTUBE")
    print("=" * 50)
    
    video_file = "storage/generated_videos/showcase_peaceful_blue_1751427620.mp4"
    
    if not os.path.exists(video_file):
        print(f"❌ Video file not found: {video_file}")
        return
    
    file_size = os.path.getsize(video_file) / 1024 / 1024
    print(f"📹 Found video: {file_size:.1f}MB")
    
    # Metadata for peaceful blue theme
    metadata = {
        "snippet": {
            "title": "🕯️ 진리의 말씀 - 평안한 기도시간 | 묵상과 기도",
            "description": "하나님의 평안이 여러분의 마음에 충만하시기를 기도합니다. 고요한 시간을 가지며 주님 앞에서 기도하고 묵상하는 귀한 시간이 되시기 바랍니다. 평안한 마음으로 하나님의 음성에 귀 기울여보시기 바랍니다.\n\n🎨 Peaceful Blue Theme - Prayer & Meditation\n📺 BibleStartup Channel\n🙏 진리의 교회",
            "tags": ["기도", "묵상", "평안", "한국어", "spiritual", "meditation", "prayer", "korean", "shorts"],
            "categoryId": "22"
        },
        "status": {
            "privacyStatus": "public",
            "selfDeclaredMadeForKids": False
        }
    }
    
    # Upload parameters
    params = {
        'part': 'snippet,status',
        'uploadType': 'multipart'
    }
    
    headers = {
        'Authorization': f'Bearer {ACCESS_TOKEN}',
        'Accept': 'application/json'
    }
    
    print("🚀 Starting upload...")
    
    try:
        with open(video_file, 'rb') as video_data:
            # Create multipart encoder
            encoder = MultipartEncoder(
                fields={
                    'metadata': ('metadata', json.dumps(metadata), 'application/json'),
                    'video': ('video.mp4', video_data, 'video/mp4')
                }
            )
            
            headers['Content-Type'] = encoder.content_type
            
            # Upload the video
            response = requests.post(
                YOUTUBE_UPLOAD_URL,
                params=params,
                headers=headers,
                data=encoder
            )
            
            if response.status_code == 200:
                result = response.json()
                youtube_id = result['id']
                youtube_url = f"https://www.youtube.com/watch?v={youtube_id}"
                
                print("🎉 SUCCESS! Peaceful Blue theme uploaded!")
                print("")
                print("🕯️ PEACEFUL BLUE THEME - NOW LIVE:")
                print(f"   YouTube ID: {youtube_id}")
                print(f"   YouTube URL: {youtube_url}")
                print(f"   Short URL: https://youtu.be/{youtube_id}")
                print("")
                print("📱 Now you have 2 spiritual themes to share:")
                print("   🌟 Golden Light (Worship): https://youtu.be/6Bugm87RFQo")
                print(f"   🕯️ Peaceful Blue (Prayer): https://youtu.be/{youtube_id}")
                print("")
                print("✅ Both themes are now live on your BibleStartup channel!")
                print("🎯 Check YouTube Studio to see both videos!")
                
            else:
                print(f"❌ Upload failed: {response.status_code}")
                print(f"   Error: {response.text}")
                
    except Exception as e:
        print(f"❌ Upload error: {str(e)}")

if __name__ == "__main__":
    upload_peaceful_blue()