#!/usr/bin/env ruby

puts "🎨 UPLOADING SPIRITUAL-THEMED YOUTUBE SHORT"
puts "=" * 50

# Video file that was generated
video_file = "storage/generated_videos/spiritual_peaceful_blue_1751424807.mp4"
sermon = Sermon.find(174)

puts "📹 Spiritual video details:"
puts "   File: #{video_file}"
puts "   Theme: PEACEFUL_BLUE"
puts "   Size: #{File.size(video_file) / 1024 / 1024}MB"
puts "   Sermon: #{sermon.title}"
puts "   Scripture: #{sermon.scripture}"
puts ""

# Enhanced spiritual metadata
youtube_metadata = {
  title: "🙏 진리의 말씀 - #{sermon.scripture} | 평안한 묵상",
  scripture: sermon.scripture,
  content: "하나님의 평안이 여러분과 함께하시기를 기도합니다. #{sermon.scripture}의 귀한 말씀을 통해 주님의 사랑을 묵상하는 시간입니다. 평안한 마음으로 하나님의 말씀에 귀 기울여보시기 바랍니다.",
  church: sermon.church,
  pastor: sermon.pastor,
  source_url: "https://wordsoftruth.com/sermon/#{sermon.id}",
  theme: "peaceful_blue"
}

puts "📋 Enhanced spiritual metadata:"
puts "   Title: #{youtube_metadata[:title]}"
puts "   Theme: Peaceful Blue (meditation & prayer)"
puts "   Enhanced with: Spiritual emojis and Korean blessings"
puts ""

puts "🙏 Uploading to BibleStartup YouTube channel..."

begin
  upload_result = YoutubeUploadService.upload_shorts(video_file, youtube_metadata)
  
  if upload_result[:success]
    puts "🎉 SUCCESS! Spiritual YouTube Short uploaded!"
    puts ""
    puts "🎨 NEW SPIRITUAL FEATURES SHOWCASE:"
    puts "✨ Theme: PEACEFUL_BLUE"
    puts "   - Flowing blue patterns for meditation atmosphere"
    puts "   - Enhanced typography with spiritual colors"
    puts "   - Multi-line scripture display with Korean"
    puts "   - Smooth fade-in animations"
    puts "   - Professional channel branding"
    puts ""
    puts "📱 SHAREABLE LINKS:"
    puts "   YouTube URL: #{upload_result[:youtube_url]}"
    puts "   Short URL: https://youtu.be/#{upload_result[:youtube_id]}"
    puts "   Channel: https://www.youtube.com/@BibleStartup"
    puts "   Studio: https://studio.youtube.com/channel/UC4o3W-snviJWkgZLBxtkAeA/videos"
    puts ""
    puts "🎯 Perfect for sharing with invitees who appreciate:"
    puts "   - Peaceful meditation content"
    puts "   - Korean spiritual content"
    puts "   - Professional religious media"
    puts "   - Mobile-optimized devotional videos"
    
  else
    puts "❌ Upload failed: #{upload_result[:error]}"
  end
  
rescue => e
  puts "❌ Upload error: #{e.message}"
end