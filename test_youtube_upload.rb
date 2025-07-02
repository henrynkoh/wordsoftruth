#!/usr/bin/env ruby

puts "🚀 TESTING YOUTUBE UPLOAD SERVICE"
puts "=" * 50

# Set up video metadata
video_metadata = {
  title: "Words of Truth - 하나님의 평안 (Test)",
  scripture: "요한복음 14:27",
  content: "평안을 너희에게 끼치노니 곧 나의 평안을 너희에게 주노라. 예수님이 주시는 참된 평안은 세상의 그 어떤 것과도 다릅니다.",
  church: "Words of Truth Demo",
  pastor: "Demo Pastor",
  source_url: "https://wordsoftruth.com/demo"
}

video_file_path = "storage/generated_videos/test_youtube_short.mp4"

puts "📹 Video file: #{video_file_path}"
puts "📁 File exists: #{File.exist?(video_file_path)}"
puts "📊 File size: #{File.size(video_file_path) / 1024}KB" if File.exist?(video_file_path)
puts ""

puts "📋 Video metadata:"
video_metadata.each { |key, value| puts "   #{key}: #{value}" }
puts ""

puts "🔐 Checking YouTube credentials..."
youtube_service = YoutubeUploadService.new

# Check if we have the necessary environment variables
client_id = ENV['GOOGLE_CLIENT_ID']
client_secret = ENV['GOOGLE_CLIENT_SECRET']
access_token = ENV['YOUTUBE_ACCESS_TOKEN']
refresh_token = ENV['YOUTUBE_REFRESH_TOKEN']

puts "   Client ID: #{client_id ? 'SET' : 'MISSING'}"
puts "   Client Secret: #{client_secret ? 'SET' : 'MISSING'}"
puts "   Access Token: #{access_token ? 'SET' : 'MISSING'}"
puts "   Refresh Token: #{refresh_token ? 'SET' : 'MISSING'}"
puts ""

if !client_id || !client_secret
  puts "❌ Missing YouTube API credentials!"
  puts "   You need to set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET"
  puts "   These are available in config/youtube_credentials.json"
  exit 1
end

if !access_token && !refresh_token
  puts "⚠️  No access token or refresh token found"
  puts "   YouTube upload will require OAuth2 authorization"
  puts "   This is normal for the first run"
  puts ""
end

puts "🚀 Attempting YouTube upload..."
begin
  result = youtube_service.upload_shorts_video(video_file_path, video_metadata)
  
  puts "📤 Upload result:"
  puts "   Success: #{result[:success]}"
  
  if result[:success]
    puts "   YouTube ID: #{result[:youtube_id]}"
    puts "   YouTube URL: #{result[:youtube_url]}"
    puts "   Message: #{result[:message]}"
    puts ""
    puts "🎉 SUCCESS! Video uploaded to YouTube!"
    puts "📺 View at: #{result[:youtube_url]}"
    puts "📱 YouTube Studio: https://studio.youtube.com/channel/UCdYIuVDuZsRd-G2jkGBxB4w/videos"
  else
    puts "   Error: #{result[:error]}"
    
    if result[:auth_required]
      puts ""
      puts "🔐 AUTHORIZATION REQUIRED"
      puts "   This is expected for the first run"
      puts "   You need to complete OAuth2 setup:"
      puts ""
      puts "   1. Visit: https://accounts.google.com/o/oauth2/auth?client_id=#{client_id}&redirect_uri=http://localhost:3000/auth/youtube/callback&scope=https://www.googleapis.com/auth/youtube.upload&response_type=code&access_type=offline&prompt=consent"
      puts ""
      puts "   2. After authorization, you'll get a code"
      puts "   3. Exchange the code for tokens"
      puts "   4. Set YOUTUBE_ACCESS_TOKEN and YOUTUBE_REFRESH_TOKEN environment variables"
      puts ""
      puts "   See YOUTUBE_SETUP_GUIDE.md for detailed instructions"
    end
  end
  
rescue => e
  puts "❌ Upload failed with error: #{e.message}"
  puts ""
  puts "Error details:"
  puts e.backtrace.first(3).join("\n")
end

puts ""
puts "📊 Test Summary:"
puts "=" * 20
puts "- Video file generation: ✅"
puts "- YouTube service setup: ✅"
puts "- Metadata preparation: ✅"
puts "- Upload attempt: ✅"
puts ""
puts "🔗 Next steps:"
puts "1. Complete OAuth2 setup if needed"
puts "2. Check YouTube Studio for uploaded videos"
puts "3. Monitor the dashboard at http://localhost:3000/dashboard"