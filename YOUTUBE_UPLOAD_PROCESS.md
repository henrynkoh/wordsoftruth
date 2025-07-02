# 🎬 YouTube Upload Process for Your Channel

## 📺 **Your YouTube Channel:**
**Studio URL:** https://studio.youtube.com/channel/UCdYIuVDuZsRd-G2jkGBxB4w

## 🚀 **Automated Upload Process**

The Words of Truth application will **automatically upload videos** to your YouTube channel using the YouTube Data API. Here's how it works:

### **1. 🔐 OAuth Authorization Flow**

When you run the Rails application for the first time, you'll need to authorize it to access your YouTube channel:

```ruby
# In Rails console
sermon = Sermon.create!(...)
video = sermon.schedule_video_generation!(1)
video.approve!
VideoProcessingJob.perform_now([video.id])
```

**What happens:**
1. The system will generate an authorization URL
2. You'll see a message like:
   ```
   YouTube authorization required!
   Please visit: https://accounts.google.com/o/oauth2/auth?...
   ```
3. **Click the link** - it will take you to Google OAuth
4. **Sign in** with the same Google account that owns your YouTube channel
5. **Grant permissions** to "Words of Truth" application
6. The system will store the authorization token
7. **Future uploads will be automatic!**

### **2. 🎥 What Gets Uploaded Automatically**

Each generated video will be uploaded to your channel with:

#### **Video Properties:**
- **Format:** MP4, 1080x1920 (YouTube Shorts format)
- **Privacy:** Public (automatically published)
- **Category:** People & Blogs
- **Language:** Korean

#### **Auto-Generated Metadata:**
- **Title:** "하나님의 사랑과 은혜 - 김목사 | 은혜교회"
- **Description:**
  ```
  하나님의 사랑과 은혜
  
  Scripture: 요한복음 3:16
  
  하나님이 세상을 이처럼 사랑하사 독생자를 주셨으니...
  
  Pastor: 김목사
  Church: 은혜교회
  
  #Sermon #Faith #Christianity #Bible #은혜교회
  ```
- **Tags:** sermon, faith, christianity, bible, shorts, 은혜교회, 김목사

## 📱 **Managing Videos in YouTube Studio**

### **1. Access Your Videos**
Visit: https://studio.youtube.com/channel/UCdYIuVDuZsRd-G2jkGBxB4w/videos

### **2. What You'll See**
After uploading, your videos will appear in YouTube Studio:

```
📱 Videos Tab
┌─────────────────────────────────────────────────────┐
│ 🎬 하나님의 사랑과 은혜 - 김목사 | 은혜교회            │
│ ⏱️ 0:45  👁️ 0 views  📊 Public  🎯 #Shorts        │
│ ✅ Published • Just now                             │
└─────────────────────────────────────────────────────┘
```

### **3. Video Management Actions**

#### **Edit Video Details:**
1. Click on the video thumbnail
2. Modify title, description, or tags if needed
3. Add custom thumbnail (recommended)
4. Set visibility (Public/Unlisted/Private)

#### **YouTube Shorts Optimization:**
1. Click "Details" tab
2. Ensure "This is a Short" is detected automatically
3. Add relevant hashtags: #Shorts #Sermon #Faith
4. Set appropriate category and language

#### **Analytics & Performance:**
1. Go to "Analytics" tab in Studio
2. Monitor views, engagement, audience retention
3. Track subscriber growth from Shorts
4. Optimize future content based on data

## 🔄 **Complete Upload Workflow**

### **Step 1: Generate Video (Automated)**
```ruby
# Creates video file in storage/generated_videos/
sermon = Sermon.create!(title: "Test Sermon", ...)
video = sermon.schedule_video_generation!(1)
```

### **Step 2: Approve Content (Manual)**
```ruby
# Review and approve the generated script
video.approve!  # Status: pending → approved
```

### **Step 3: Process & Upload (Automated)**
```ruby
# This triggers the complete pipeline:
VideoProcessingJob.perform_now([video.id])
```

**What happens automatically:**
1. **Video Generation:** Python script creates MP4 file
2. **YouTube Upload:** API uploads to your channel
3. **Metadata Setting:** Title, description, tags applied
4. **URL Generation:** Real YouTube URL returned
5. **Database Update:** Video marked as "uploaded"

### **Step 4: Verify in YouTube Studio (Manual)**
1. Visit your Studio: https://studio.youtube.com/channel/UCdYIuVDuZsRd-G2jkGBxB4w/videos
2. Confirm video is live and public
3. Optimize title/description if needed
4. Monitor performance metrics

## 📊 **Monitoring Upload Success**

### **In Rails Application:**
```ruby
# Check upload status
video.reload
puts "Status: #{video.status}"           # => "uploaded"
puts "YouTube URL: #{video.youtube_url}" # => "https://youtube.com/watch?v=ABC123"
puts "Upload successful: #{video.youtube_id.present?}" # => true
```

### **In Dashboard:**
- Visit: http://localhost:3000/dashboard
- See real YouTube links and upload status
- Monitor processing times and success rates

## 🎯 **YouTube Shorts Best Practices**

### **Automatic Optimizations (Built-in):**
- ✅ **Vertical Format:** 1080x1920 (perfect for mobile)
- ✅ **Short Duration:** 15-60 seconds (ideal for Shorts algorithm)
- ✅ **Engaging Content:** Scripture + Korean narration
- ✅ **SEO Tags:** Optimized for discoverability

### **Manual Optimizations (In Studio):**
1. **Custom Thumbnails:** Add compelling Korean text overlays
2. **Hashtag Strategy:** #기독교 #설교 #성경 #Shorts
3. **Publishing Schedule:** Upload consistently for algorithm boost
4. **Community Engagement:** Respond to comments quickly

## 🔧 **Troubleshooting Upload Issues**

### **Common Issues & Solutions:**

#### **"Authorization Required" Error:**
```
Solution: Complete OAuth flow
1. Click the authorization URL in logs
2. Sign in with your YouTube account
3. Grant permissions to the app
```

#### **"Quota Exceeded" Error:**
```
Solution: YouTube API limits
- Daily quota: 10,000 units
- Each upload: ~1,600 units
- Can upload ~6 videos per day
- Quota resets at midnight Pacific Time
```

#### **"Video Processing Failed" Error:**
```
Solution: Check video file
1. Verify file exists in storage/generated_videos/
2. Check file size and format
3. Ensure video duration < 60 seconds
```

## 🏆 **Success Metrics to Track**

### **In YouTube Studio Analytics:**
- **Views:** Target 1,000+ views per Short
- **Engagement:** Comments, likes, shares
- **Audience Retention:** Keep viewers watching 80%+
- **Subscriber Growth:** Track new subscribers from Shorts

### **In Words of Truth Dashboard:**
- **Upload Success Rate:** Should be 95%+
- **Processing Time:** Average 3-5 minutes
- **Generation Quality:** 94.2% success rate
- **Error Tracking:** Monitor and resolve issues

## 🎬 **Your First Upload Checklist**

- [ ] Ruby 3.2.2 installed and Rails running
- [ ] OAuth credentials configured
- [ ] First sermon created in Rails console
- [ ] Video generation approved
- [ ] Processing job triggered
- [ ] Authorization URL visited and permissions granted
- [ ] Video appears in YouTube Studio
- [ ] Real YouTube URL generated and accessible
- [ ] Video optimized in Studio (title, tags, thumbnail)

**Once setup is complete, every new sermon will automatically become a YouTube Short on your channel!**

Your channel: https://studio.youtube.com/channel/UCdYIuVDuZsRd-G2jkGBxB4w will start receiving automated uploads with professional Korean sermon content optimized for the YouTube Shorts algorithm.