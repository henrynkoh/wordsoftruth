#!/usr/bin/env python3
"""
Quick upload script for all 6 backup themes
Use this when your YouTube API quota increase gets approved
"""

import os
import json
import requests
from requests_toolbelt.multipart.encoder import MultipartEncoder

def upload_backup_theme(video_file, metadata, access_token):
    """Upload a single backup theme to YouTube"""
    print(f"🚀 Uploading {os.path.basename(video_file)}...")
    
    if not os.path.exists(video_file):
        print(f"❌ File not found: {video_file}")
        return None
    
    file_size = os.path.getsize(video_file) / 1024 / 1024
    print(f"   📊 File size: {file_size:.1f}MB")
    
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
                
                print(f"   ✅ SUCCESS: {youtube_id}")
                print(f"   🔗 URL: {youtube_url}")
                
                return {
                    'success': True,
                    'youtube_id': youtube_id,
                    'youtube_url': youtube_url,
                    'theme': os.path.basename(video_file).replace('backup_', '').replace('.mp4', '')
                }
            else:
                print(f"   ❌ Upload failed: {response.status_code}")
                print(f"   Error: {response.text}")
                return {'success': False, 'error': response.text}
                
    except Exception as e:
        print(f"   ❌ Upload error: {str(e)}")
        return {'success': False, 'error': str(e)}

def upload_all_backup_themes():
    """Upload all 6 backup themes when quota is approved"""
    print("🎬 UPLOADING ALL 6 BACKUP THEMES")
    print("=" * 60)
    
    # Get fresh access token
    access_token = input("Enter your fresh YouTube access token: ").strip()
    
    if not access_token:
        print("❌ No access token provided")
        return
    
    # Define all 6 backup themes
    backup_themes = [
        {
            "file": "storage/backup_themes/backup_mountain_majesty.mp4",
            "metadata": {
                "snippet": {
                    "title": "⛰️ 진리의 말씀 - 산의 위엄 | 힘과 인내",
                    "description": "산들이 주를 향해 뛰노는도다. 높은 산 위에서 하나님의 위엄을 바라봅니다. 주님은 우리의 힘이시요 피난처가 되십니다. 어떤 어려움이 와도 주님을 의지하며 굳게 서겠습니다.\n\n⛰️ Mountain Majesty Theme - 산의 위엄\n📺 BibleStartup Channel\n🙏 Words of Truth",
                    "tags": ["산", "위엄", "힘", "한국어", "mountain", "strength", "perseverance", "korean", "shorts", "진리의말씀"],
                    "categoryId": "22"
                },
                "status": {
                    "privacyStatus": "public",
                    "selfDeclaredMadeForKids": False
                }
            }
        },
        {
            "file": "storage/backup_themes/backup_flowing_river.mp4",
            "metadata": {
                "snippet": {
                    "title": "🌊 진리의 말씀 - 생명의 강 | 새로운 생명",
                    "description": "생수의 강이 흘러나오니 목마른 자들이 와서 마시라. 주님은 생명의 근원이시며 영원토록 마르지 않는 샘이십니다. 우리 영혼을 소생시키시고 새 힘을 주시는 주님을 찬양합니다.\n\n🌊 Flowing River Theme - 생명의 강\n📺 BibleStartup Channel\n🙏 Words of Truth",
                    "tags": ["생명", "강", "새생명", "한국어", "river", "life", "renewal", "living water", "korean", "shorts", "진리의말씀"],
                    "categoryId": "22"
                },
                "status": {
                    "privacyStatus": "public",
                    "selfDeclaredMadeForKids": False
                }
            }
        },
        {
            "file": "storage/backup_themes/backup_wheat_field.mp4",
            "metadata": {
                "snippet": {
                    "title": "🌾 진리의 말씀 - 추수의 기쁨 | 풍성한 축복",
                    "description": "추수할 것은 많되 일꾼이 적으니 추수하는 주인에게 일꾼들을 보내어 달라고 청하라. 황금빛 밀밭처럼 하나님의 축복이 넘쳐납니다. 수고한 대로 거두는 기쁨을 누리며, 하나님께서 주시는 풍성한 열매를 감사함으로 받겠습니다.\n\n🌾 Wheat Field Theme - 추수의 기쁨\n📺 BibleStartup Channel\n🙏 Words of Truth",
                    "tags": ["추수", "축복", "감사", "한국어", "harvest", "blessing", "abundance", "thanksgiving", "korean", "shorts", "진리의말씀"],
                    "categoryId": "22"
                },
                "status": {
                    "privacyStatus": "public",
                    "selfDeclaredMadeForKids": False
                }
            }
        },
        {
            "file": "storage/backup_themes/backup_shepherd_field.mp4",
            "metadata": {
                "snippet": {
                    "title": "🐑 진리의 말씀 - 선한 목자 | 인도하심",
                    "description": "주는 나의 목자시니 내게 부족함이 없으리로다. 푸른 초장에 누이시며 쉴 만한 물 가로 인도하십니다. 선한 목자이신 예수님께서 우리를 돌보시고 보호하십니다. 주님의 음성을 듣고 따라가는 양이 되겠습니다.\n\n🐑 Shepherd Field Theme - 선한 목자\n📺 BibleStartup Channel\n🙏 Words of Truth",
                    "tags": ["목자", "인도", "보호", "한국어", "shepherd", "guidance", "protection", "psalm", "korean", "shorts", "진리의말씀"],
                    "categoryId": "22"
                },
                "status": {
                    "privacyStatus": "public",
                    "selfDeclaredMadeForKids": False
                }
            }
        },
        {
            "file": "storage/backup_themes/backup_temple_light.mp4",
            "metadata": {
                "snippet": {
                    "title": "🏛️ 진리의 말씀 - 거룩한 성전 | 예배와 경배",
                    "description": "내가 여호와의 집에 거주하며 그의 아름다움을 바라보는 것이 나의 간구이로다. 거룩한 성전에서 주님께 예배드리는 것이 가장 큰 복입니다. 하나님의 영광이 충만한 곳에서 경배와 찬양을 올려드립니다.\n\n🏛️ Temple Light Theme - 거룩한 성전\n📺 BibleStartup Channel\n🙏 Words of Truth",
                    "tags": ["성전", "예배", "경배", "한국어", "temple", "worship", "sanctuary", "holy", "korean", "shorts", "진리의말씀"],
                    "categoryId": "22"
                },
                "status": {
                    "privacyStatus": "public",
                    "selfDeclaredMadeForKids": False
                }
            }
        },
        {
            "file": "storage/backup_themes/backup_city_lights.mp4",
            "metadata": {
                "snippet": {
                    "title": "🌃 진리의 말씀 - 세상의 빛 | 전도와 선교",
                    "description": "너희는 세상의 빛이라 산 위에 있는 동네가 숨겨지지 못할 것이요. 도시의 불빛처럼 우리도 어둠 가운데 빛을 비추는 삶을 살아야 합니다. 복음을 전하며 사랑을 실천하는 그리스도인이 되겠습니다. 세상을 밝히는 빛이 되어주옵소서.\n\n🌃 City Lights Theme - 세상의 빛\n📺 BibleStartup Channel\n🙏 Words of Truth",
                    "tags": ["빛", "전도", "선교", "한국어", "light", "evangelism", "mission", "witness", "korean", "shorts", "진리의말씀"],
                    "categoryId": "22"
                },
                "status": {
                    "privacyStatus": "public",
                    "selfDeclaredMadeForKids": False
                }
            }
        }
    ]
    
    uploaded_videos = []
    
    for i, theme in enumerate(backup_themes):
        print(f"\n📹 UPLOADING BACKUP THEME {i+1}/6")
        print("-" * 40)
        
        result = upload_backup_theme(theme['file'], theme['metadata'], access_token)
        
        if result and result['success']:
            uploaded_videos.append(result)
            print(f"✅ Theme {i+1}/6 uploaded successfully!")
        else:
            print(f"❌ Theme {i+1}/6 upload failed")
        
        # Small delay between uploads
        if i < len(backup_themes) - 1:
            print("⏳ Brief pause before next upload...")
            import time
            time.sleep(3)
    
    # Final summary
    print(f"\n{'='*60}")
    print("🎉 BACKUP UPLOAD COMPLETE!")
    print(f"{'='*60}")
    
    if uploaded_videos:
        print(f"\n✅ Successfully uploaded {len(uploaded_videos)}/6 backup themes:")
        
        for video in uploaded_videos:
            theme_display = video['theme'].replace('_', ' ').title()
            print(f"   📺 {theme_display}: {video['youtube_url']}")
        
        print(f"\n🎯 COMPLETE 10-THEME COLLECTION NOW LIVE:")
        print("   🌟 Golden Light: https://youtu.be/6Bugm87RFQo")
        print("   🕯️ Peaceful Blue: https://youtu.be/atgC2FW5ZO0")
        print("   🌅 Sunset Worship: https://youtu.be/LkM-wYwfjak")
        print("   ✝️ Cross Pattern: https://youtu.be/Fie5PJ02JYw")
        
        for video in uploaded_videos:
            emoji_map = {
                'mountain_majesty': '⛰️',
                'flowing_river': '🌊',
                'wheat_field': '🌾',
                'shepherd_field': '🐑',
                'temple_light': '🏛️',
                'city_lights': '🌃'
            }
            emoji = emoji_map.get(video['theme'], '✨')
            theme_display = video['theme'].replace('_', ' ').title()
            print(f"   {emoji} {theme_display}: {video['youtube_url']}")
        
        print(f"\n🏠 BibleStartup Channel: https://www.youtube.com/@BibleStartup")
        print("📊 Studio: https://studio.youtube.com/channel/UC4o3W-snviJWkgZLBxtkAeA/videos")
        print("\n🚀 Complete spiritual theme showcase ready for church clients!")
        
    else:
        print("❌ No videos were successfully uploaded")
        print("   Please check your access token and try again")

if __name__ == "__main__":
    upload_all_backup_themes()