# 🔐 OAuth Setup Guide for YouTube Upload

## ✅ **Current Status:**
- ✅ API Key configured: `AIzaSyBNpH5KRQKvqV2qm4P3qwQL2hSc_PvuVuQ`
- ✅ Dependencies installed (FFmpeg, Python packages)
- ✅ Project structure created
- ⏳ **Missing:** OAuth credentials for video uploads

## 🔑 **Getting OAuth Credentials**

### **Step 1: Go to Google Cloud Console**
Visit: https://console.cloud.google.com/apis/credentials

### **Step 2: Look for OAuth 2.0 Client IDs**
You should see a section like this:
```
OAuth 2.0 Client IDs
┌─────────────────────────────────────────┐
│ Name: Web client 1                      │
│ Client ID: 123456789-abc...             │
│ [Edit] [Download] [Delete]              │
└─────────────────────────────────────────┘
```

### **Step 3: If No OAuth Client Exists, Create One**
1. Click "Create Credentials" → "OAuth 2.0 Client ID"
2. Choose "Web application"
3. Name: "Words of Truth YouTube Integration"
4. Authorized redirect URIs: `http://localhost:3000/auth/youtube/callback`
5. Click "Create"

### **Step 4: Download JSON Credentials**
Click the **Download** button (⬇️) to get a file like:
```json
{
  "web": {
    "client_id": "123456789-abcdefghijk.apps.googleusercontent.com",
    "project_id": "your-project-name",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_secret": "YOUR_GOOGLE_CLIENT_SECRET",
    "redirect_uris": ["http://localhost:3000/auth/youtube/callback"]
  }
}
```

### **Step 5: Update Configuration**
From the downloaded JSON, extract:
- **client_id**: `123456789-abcdefghijk.apps.googleusercontent.com`
- **client_secret**: `YOUR_GOOGLE_CLIENT_SECRET`

Update your `.env` file:
```bash
YOUTUBE_CLIENT_ID=123456789-abcdefghijk.apps.googleusercontent.com
YOUTUBE_CLIENT_SECRET=YOUR_GOOGLE_CLIENT_SECRET
```

### **Step 6: Save Credentials File**
Save the downloaded JSON as: `config/youtube_credentials.json`

## 🎬 **What Each Credential Type Does:**

### **API Key (You Have This):**
- **Purpose:** Read-only access
- **Can do:** Search videos, get video metadata
- **Cannot do:** Upload videos

### **OAuth Credentials (You Need This):**
- **Purpose:** Write access to YOUR YouTube channel
- **Can do:** Upload videos, modify playlists
- **Requires:** User authorization flow

## 🚀 **Testing After Setup**

Once you have OAuth credentials:

```bash
# Start Rails (need Ruby 3.2.2 first)
rvm install ruby-3.2.2
bundle install
bin/dev

# Test the pipeline
rails console
```

```ruby
# This will now upload REAL videos to YouTube!
sermon = Sermon.create!(
  title: "Test Sermon Upload",
  scripture: "John 3:16",
  pastor: "Pastor Test",
  church: "Test Church",
  interpretation: "For God so loved the world...",
  source_url: "https://test.com/sermon1"
)

video = sermon.schedule_video_generation!(1)
video.approve!
VideoProcessingJob.perform_now([video.id])

# Check result - should be real YouTube URL!
video.reload
puts video.youtube_url
```

## 📋 **Current Next Steps:**

1. **Get OAuth credentials** from Google Cloud Console
2. **Update .env** with client_id and client_secret  
3. **Install Ruby 3.2.2** (`rvm install ruby-3.2.2`)
4. **Test video upload** with the code above

**You're almost there!** Just need the OAuth credentials to unlock real YouTube uploads.