#!/usr/bin/env python3

import requests
import json

# YouTube API configuration
ACCESS_TOKEN = "YOUR_ACCESS_TOKEN"

def check_video_status():
    print("🔍 CHECKING PEACEFUL BLUE VIDEO STATUS")
    print("=" * 50)
    
    video_id = "_KrfsfdDCe0"
    
    # Check if video exists
    url = f"https://www.googleapis.com/youtube/v3/videos"
    params = {
        'part': 'snippet,status,processingDetails',
        'id': video_id
    }
    headers = {
        'Authorization': f'Bearer {ACCESS_TOKEN}',
        'Accept': 'application/json'
    }
    
    try:
        response = requests.get(url, params=params, headers=headers)
        
        if response.status_code == 200:
            data = response.json()
            
            if data.get('items'):
                video = data['items'][0]
                snippet = video.get('snippet', {})
                status = video.get('status', {})
                processing = video.get('processingDetails', {})
                
                print(f"✅ Video Found: {video_id}")
                print(f"   Title: {snippet.get('title', 'N/A')}")
                print(f"   Privacy: {status.get('privacyStatus', 'N/A')}")
                print(f"   Upload Status: {status.get('uploadStatus', 'N/A')}")
                print(f"   Published At: {snippet.get('publishedAt', 'N/A')}")
                
                if processing:
                    print(f"   Processing Status: {processing.get('processingStatus', 'N/A')}")
                    
                print(f"   Channel ID: {snippet.get('channelId', 'N/A')}")
                print("")
                
                # Check if it's a Short
                if snippet.get('tags'):
                    print(f"   Tags: {', '.join(snippet['tags'][:5])}")
                    
                print(f"🔗 Direct URL: https://www.youtube.com/watch?v={video_id}")
                print(f"🔗 Short URL: https://youtu.be/{video_id}")
                
                # Check if there are any restrictions
                if 'rejectionReason' in status:
                    print(f"⚠️  Rejection Reason: {status['rejectionReason']}")
                    
            else:
                print(f"❌ Video {video_id} not found or not accessible")
                print("   This could mean:")
                print("   - Video is still processing")
                print("   - Video was rejected by YouTube")
                print("   - Access token doesn't have permission")
                
        else:
            print(f"❌ API Error: {response.status_code}")
            print(f"   Response: {response.text}")
            
    except Exception as e:
        print(f"❌ Error checking video: {str(e)}")

    # Also check channel videos to see what's actually there
    print("\n📺 CHECKING CHANNEL VIDEOS:")
    print("-" * 30)
    
    try:
        channel_url = "https://www.googleapis.com/youtube/v3/search"
        channel_params = {
            'part': 'snippet',
            'channelId': 'UC4o3W-snviJWkgZLBxtkAeA',
            'order': 'date',
            'maxResults': 10,
            'type': 'video'
        }
        
        channel_response = requests.get(channel_url, params=channel_params, headers=headers)
        
        if channel_response.status_code == 200:
            channel_data = channel_response.json()
            
            print(f"Found {len(channel_data.get('items', []))} recent videos:")
            
            for i, item in enumerate(channel_data.get('items', [])[:5]):
                snippet = item['snippet']
                video_id = item['id']['videoId']
                print(f"{i+1}. {snippet['title'][:50]}...")
                print(f"   ID: {video_id}")
                print(f"   Published: {snippet['publishedAt']}")
                print("")
                
        else:
            print(f"❌ Channel API Error: {channel_response.status_code}")
            
    except Exception as e:
        print(f"❌ Error checking channel: {str(e)}")

if __name__ == "__main__":
    check_video_status()