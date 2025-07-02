#!/usr/bin/env ruby

puts "🎬 CREATING FRESH YOUTUBE SHORT FROM SCRATCH"
puts "=" * 60

# Step 1: Get the random sermon we found
sermon = Sermon.find(455)
puts "📖 Using Sermon ID: #{sermon.id}"
puts "   Title: #{sermon.title}"
puts "   Scripture: #{sermon.scripture}"
puts "   Pastor: #{sermon.pastor}"
puts ""

# Step 2: Create a meaningful Korean script based on the sermon
korean_script = "안녕하세요, 진리의 말씀입니다. 오늘은 #{sermon.scripture}의 말씀을 함께 나누겠습니다. 하나님의 말씀은 우리의 삶에 빛이 되고 소망이 됩니다. #{sermon.pastor} 목사님께서 전해주신 귀한 말씀을 통해 하나님의 사랑을 깊이 묵상해보시기 바랍니다. 주님의 은혜가 여러분과 함께하시기를 기도합니다. 아멘."

puts "📝 Generated Korean script:"
puts "   Length: #{korean_script.length} characters"
puts "   Content: #{korean_script[0..100]}..."
puts ""

# Step 3: Create video configuration
timestamp = Time.now.to_i
video_filename = "fresh_youtube_short_#{timestamp}.mp4"
config_filename = "video_config_#{timestamp}.json"

video_config = {
  script_text: korean_script,
  scripture_text: "#{sermon.scripture}\n진리의 말씀",
  background_video: "storage/background_videos/simple_navy.mp4",
  output_file: "storage/generated_videos/#{video_filename}"
}

puts "🎥 Video configuration:"
puts "   Output file: #{video_config[:output_file]}"
puts "   Scripture overlay: #{video_config[:scripture_text]}"
puts ""

# Step 4: Save configuration file
File.write(config_filename, JSON.pretty_generate(video_config))
puts "✅ Configuration saved: #{config_filename}"
puts ""

# Step 5: Generate the video using Python script
puts "🐍 Generating video with Python..."
system("python3 scripts/generate_video.py #{config_filename}")

if File.exist?(video_config[:output_file])
  file_size = File.size(video_config[:output_file]) / 1024 / 1024
  puts "✅ Video generated successfully!"
  puts "   File: #{video_config[:output_file]}"
  puts "   Size: #{file_size}MB"
  puts ""
  
  # Step 6: Prepare YouTube metadata
  youtube_metadata = {
    title: "진리의 말씀 - #{sermon.scripture} | #{sermon.pastor}",
    scripture: sermon.scripture,
    content: korean_script,
    church: sermon.church,
    pastor: sermon.pastor,
    source_url: "https://wordsoftruth.com/sermon/#{sermon.id}"
  }
  
  puts "📋 YouTube metadata prepared:"
  puts "   Title: #{youtube_metadata[:title]}"
  puts "   Scripture: #{youtube_metadata[:scripture]}"
  puts "   Church: #{youtube_metadata[:church]}"
  puts ""
  
  # Step 7: Upload to YouTube
  puts "🚀 Uploading to BibleStartup YouTube channel..."
  
  begin
    upload_result = YoutubeUploadService.upload_shorts(video_config[:output_file], youtube_metadata)
    
    if upload_result[:success]
      puts "🎉 SUCCESS! YouTube Short uploaded!"
      puts "   YouTube ID: #{upload_result[:youtube_id]}"
      puts "   YouTube URL: #{upload_result[:youtube_url]}"
      puts "   BibleStartup Studio: https://studio.youtube.com/channel/UC4o3W-snviJWkgZLBxtkAeA/videos"
      puts ""
      puts "📱 SHAREABLE LINKS:"
      puts "   Watch: #{upload_result[:youtube_url]}"
      puts "   Short URL: https://youtu.be/#{upload_result[:youtube_id]}"
      puts "   Channel: https://www.youtube.com/@BibleStartup"
      puts ""
      puts "🎯 Video is now LIVE and ready for invitees to view!"
      
    else
      puts "❌ Upload failed: #{upload_result[:error]}"
      puts "   Video file created but not uploaded"
      puts "   Manual upload needed"
    end
    
  rescue => e
    puts "❌ Upload error: #{e.message}"
    puts "   Video file created: #{video_config[:output_file]}"
    puts "   You can manually upload this file to YouTube"
  end
  
else
  puts "❌ Video generation failed"
  puts "   Check Python script and dependencies"
end

# Cleanup
File.delete(config_filename) if File.exist?(config_filename)

puts ""
puts "🎬 Fresh YouTube Short creation complete!"
puts "📊 Summary:"
puts "- Sermon: #{sermon.title} (ID: #{sermon.id})"
puts "- Scripture: #{sermon.scripture}"
puts "- Pastor: #{sermon.pastor}"
puts "- Video file: #{video_filename}"
puts "- Ready for sharing with invitees!"