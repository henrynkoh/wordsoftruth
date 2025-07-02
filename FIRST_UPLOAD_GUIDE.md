# 🎬 Step-by-Step First Upload to Your YouTube Channel

## 📺 **Your Channel:** 
https://studio.youtube.com/channel/UCdYIuVDuZsRd-G2jkGBxB4w

## 🚀 **Complete First Upload Process**

### **Step 1: Start Rails Application**
```bash
# Wait for Ruby compilation to complete, then:
rvm use ruby-3.2.2
bundle install
bin/dev
```

### **Step 2: Open Rails Console**
```bash
# In a new terminal:
rails console
```

### **Step 3: Create Your First Sermon**
```ruby
# Create a sermon that will become a YouTube Short
sermon = Sermon.create!(
  title: "하나님의 사랑과 평안",
  scripture: "요한복음 14:27",
  pastor: "김목사",
  church: "은혜교회",
  interpretation: "평안을 너희에게 끼치노니 곧 나의 평안을 너희에게 주노라. 내가 너희에게 주는 것은 세상이 주는 것과 같지 아니하니라. 너희는 마음에 근심하지도 말고 두려워하지도 말라. 예수님이 주시는 평안은 세상의 그 어떤 것과도 다릅니다.",
  action_points: "1. 매일 기도로 하나님께 가까이 나아가기\n2. 성경 말씀으로 마음을 채우기\n3. 어려운 이웃에게 사랑 나누기\n4. 감사하는 마음으로 살아가기",
  source_url: "https://grace-church.com/peace-sermon"
)

puts "✅ 설교가 생성되었습니다: #{sermon.title}"
```

### **Step 4: Generate Video**
```ruby
# Schedule video generation
video = sermon.schedule_video_generation!(1, {
  style: 'engaging',
  target_audience: 'general'
})

puts "✅ 비디오가 생성되었습니다: ID #{video.id}"
puts "📄 생성된 스크립트:"
puts video.script[0..200] + "..."
```

### **Step 5: Approve the Video**
```ruby
# Review and approve
puts "현재 상태: #{video.status}"  # => "pending"

# Approve for processing
video.approve!
puts "승인 후 상태: #{video.reload.status}"  # => "approved"
```

### **Step 6: Process and Upload to YouTube**
```ruby
# This will create the video file AND upload to your YouTube channel
puts "🎬 비디오 처리 및 YouTube 업로드 시작..."

VideoProcessingJob.perform_now([video.id])

# Check the result
video.reload
puts "최종 상태: #{video.status}"
puts "YouTube URL: #{video.youtube_url}"
```

## ⚠️ **What to Expect During First Upload**

### **OAuth Authorization (One-time Setup)**

During the first upload, you'll see something like:
```
YouTube authorization required!
Please visit: https://accounts.google.com/o/oauth2/auth?client_id=YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com&redirect_uri=http://localhost:3000/auth/youtube/callback&scope=https://www.googleapis.com/auth/youtube.upload&response_type=code&access_type=offline
```

**DO THIS:**
1. **Copy the URL** from the Rails console
2. **Paste it in your browser**
3. **Sign in** with the Google account that owns your YouTube channel
4. **Click "Allow"** to grant permissions to Words of Truth app
5. **You'll be redirected** to localhost:3000/auth/youtube/callback
6. **Return to Rails console** - upload will continue automatically

### **Processing Stages (3-5 minutes total)**

You'll see logs like:
```
🎤 Generating Korean TTS audio...
✅ Audio generated (duration: 45.2s)

🎥 Creating video composition...
✅ Background video loaded
✅ Text overlay added: "요한복음 14:27"
✅ Audio attached to video

🎬 Rendering final video...
✅ Video generated: storage/generated_videos/video_abc123.mp4

📤 Uploading to YouTube...
✅ YouTube upload successful: dQw4w9WgXcQ
✅ Video URL: https://www.youtube.com/watch?v=dQw4w9WgXcQ
```

## 📱 **Verify Upload in YouTube Studio**

### **1. Check Your Videos**
Go to: https://studio.youtube.com/channel/UCdYIuVDuZsRd-G2jkGBxB4w/videos

### **2. You Should See:**
```
📱 Recent Uploads
┌─────────────────────────────────────────────────────┐
│ 🎬 하나님의 사랑과 평안 - 김목사 | 은혜교회            │
│ ⏱️ 0:45  👁️ 0 views  📊 Public  🎯 #Shorts        │
│ ✅ Published • Just now                             │
│ 📝 평안을 너희에게 끼치노니 곧 나의 평안을...        │
└─────────────────────────────────────────────────────┘
```

### **3. Video Details Will Include:**
- **Title:** "하나님의 사랑과 평안 - 김목사 | 은혜교회"
- **Description:** Scripture reference + sermon content + hashtags
- **Tags:** sermon, faith, christianity, bible, shorts
- **Format:** Vertical video (1080x1920) - perfect for Shorts
- **Audio:** Korean TTS narration of the sermon content

## 🎯 **Success Indicators**

### **In Rails Console:**
```ruby
# Check if upload was successful
video.reload
video.status           # => "uploaded"
video.youtube_id       # => "dQw4w9WgXcQ" (real YouTube video ID)
video.youtube_url      # => "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
video.video_path       # => "/path/to/generated/video.mp4"
```

### **In YouTube Studio:**
- ✅ Video appears in your channel
- ✅ Status shows "Published"
- ✅ Format detected as "Short"
- ✅ Video is publicly viewable
- ✅ Korean audio plays correctly

### **In Browser:**
- Visit the generated YouTube URL
- Video should play immediately
- Shows as YouTube Short (vertical format)
- Korean narration with scripture overlay

## 🔄 **For Future Uploads**

After the first successful upload, the process becomes fully automated:

```ruby
# Create sermon
sermon = Sermon.create!(title: "새로운 설교", ...)

# Generate and upload (one command!)
video = sermon.schedule_video_generation!(1)
video.approve!
VideoProcessingJob.perform_now([video.id])

# Result: Automatic YouTube upload!
puts video.youtube_url  # New video on your channel
```

## 📊 **Monitoring Dashboard**

### **Real-time Monitoring:**
- **Main Dashboard:** http://localhost:3000/
- **Video Management:** http://localhost:3000/dashboard
- **Processing Queue:** http://localhost:3000/sidekiq

### **Success Metrics:**
- **Upload Success Rate:** Should reach 98%+ after first setup
- **Processing Time:** 3-5 minutes per video
- **YouTube Compliance:** 100% Shorts format
- **Audio Quality:** Korean TTS clarity

## 🎬 **Your YouTube Channel Impact**

After successful setup, your channel will:
- ✅ **Automatically receive** new sermon content as YouTube Shorts
- ✅ **Reach Korean-speaking audience** through optimized content
- ✅ **Benefit from Shorts algorithm** with vertical format
- ✅ **Scale content production** without manual video editing
- ✅ **Maintain consistent uploads** through automated pipeline

**Your channel URL:** https://studio.youtube.com/channel/UCdYIuVDuZsRd-G2jkGBxB4w

**Ready to create your first automated YouTube Short?** 🚀

The complete sermon-to-YouTube pipeline will transform your ministry's digital reach!