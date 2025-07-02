#!/usr/bin/env ruby

puts "🕯️ RETRYING PEACEFUL_BLUE THEME UPLOAD"
puts "=" * 50

# Check if the blue theme video exists
blue_video_file = "storage/generated_videos/showcase_peaceful_blue_1751427620.mp4"

if File.exist?(blue_video_file)
  file_size = File.size(blue_video_file) / 1024 / 1024
  puts "📹 Found Peaceful Blue video:"
  puts "   File: #{blue_video_file}"
  puts "   Size: #{file_size}MB"
  puts ""
  
  # Enhanced metadata for blue theme
  youtube_metadata = {
    title: "🕯️ 진리의 말씀 - 평안한 기도시간 | 묵상과 기도",
    scripture: "시편 23편",
    content: "하나님의 평안이 여러분의 마음에 충만하시기를 기도합니다. 고요한 시간을 가지며 주님 앞에서 기도하고 묵상하는 귀한 시간이 되시기 바랍니다. 평안한 마음으로 하나님의 음성에 귀 기울여보시기 바랍니다.",
    church: "진리의 교회",
    pastor: "평안의 목사",
    source_url: "https://wordsoftruth.com/peaceful-meditation"
  }
  
  puts "📋 Enhanced metadata for Peaceful Blue:"
  puts "   Title: #{youtube_metadata[:title]}"
  puts "   Theme: Prayer & Meditation with peaceful blue aesthetics"
  puts ""
  
  puts "🚀 Uploading Peaceful Blue theme to YouTube..."
  
  begin
    upload_result = YoutubeUploadService.upload_shorts(blue_video_file, youtube_metadata)
    
    if upload_result[:success]
      puts "🎉 SUCCESS! Peaceful Blue theme uploaded!"
      puts ""
      puts "🕯️ PEACEFUL BLUE THEME - NOW LIVE:"
      puts "   YouTube ID: #{upload_result[:youtube_id]}"
      puts "   YouTube URL: #{upload_result[:youtube_url]}"
      puts "   Short URL: https://youtu.be/#{upload_result[:youtube_id]}"
      puts ""
      puts "🎨 Features of this theme:"
      puts "   - Peaceful flowing blue patterns"
      puts "   - Perfect for prayer and meditation content"
      puts "   - Calming color scheme with soft animations"
      puts "   - Korean spiritual language for meditation"
      puts "   - Professional channel branding"
      puts ""
      puts "📱 Now you have 2 spiritual themes to share:"
      puts "   🌟 Golden Light (Worship): https://youtu.be/6Bugm87RFQo"
      puts "   🕯️ Peaceful Blue (Prayer): https://youtu.be/#{upload_result[:youtube_id]}"
      puts ""
      puts "✅ Both themes are now live on your BibleStartup channel!"
      
    else
      puts "❌ Upload failed: #{upload_result[:error]}"
      
      if upload_result[:error].include?("401") || upload_result[:error].include?("Unauthorized")
        puts ""
        puts "🔐 The access token may have expired."
        puts "   Please get fresh tokens from:"
        puts "   https://accounts.google.com/o/oauth2/auth?client_id=YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com&redirect_uri=http://localhost:3000/auth/youtube/callback&scope=https://www.googleapis.com/auth/youtube.upload&response_type=code&access_type=offline&prompt=consent"
      end
    end
    
  rescue => e
    puts "❌ Upload error: #{e.message}"
    puts ""
    puts "📧 Error details:"
    puts e.backtrace.first(3).join("\n")
  end
  
else
  puts "❌ Peaceful Blue video file not found: #{blue_video_file}"
  puts ""
  puts "🎨 Available videos in storage:"
  Dir.glob("storage/generated_videos/showcase_*.mp4").each do |file|
    size_mb = File.size(file) / 1024 / 1024
    puts "   #{File.basename(file)} (#{size_mb}MB)"
  end
end

puts ""
puts "🎯 Current status: Check your YouTube Studio to see if the video appears!"
puts "   Sometimes it takes a few minutes for videos to show up in the interface."