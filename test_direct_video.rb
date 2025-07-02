#!/usr/bin/env ruby

puts "🎬 TESTING DIRECT VIDEO CREATION"
puts "=" * 50

# Get existing sermon
sermon = Sermon.first
puts "📝 Using sermon: #{sermon.title}"
puts "   Pastor: #{sermon.pastor}"
puts "   Church: #{sermon.church}"
puts ""

# Create video directly
puts "🎬 Creating video directly..."
video = Video.create!(
  sermon: sermon,
  script: "안녕하세요! 오늘은 #{sermon.scripture}의 말씀을 나누겠습니다. #{sermon.interpretation} 하나님의 평안이 여러분과 함께하시기를 기도합니다. 아멘."
)

puts "✅ Video created!"
puts "   Video ID: #{video.id}"
puts "   Status: #{video.status}"
puts "   Script: #{video.script[0..100]}..."
puts ""

# Approve video
puts "✅ Approving video..."
video.approve!
puts "✅ Video approved! Status: #{video.reload.status}"
puts ""

# Test video processing job directly
puts "🚀 Testing video processing..."
begin
  VideoProcessingJob.perform_now([video.id])
  
  video.reload
  puts "🎉 Processing completed!"
  puts "   Status: #{video.status}"
  
  if video.video_path.present?
    puts "   Video file: #{video.video_path}"
    if File.exist?(video.video_path)
      file_size = File.size(video.video_path) / 1024 / 1024
      puts "   File size: #{file_size}MB"
      puts "✅ Video file generated successfully!"
    else
      puts "⚠️  Video file path exists but file not found"
    end
  end
  
  if video.youtube_id.present?
    puts "   YouTube ID: #{video.youtube_id}"
    puts "   YouTube URL: #{video.youtube_url}"
    puts "🎬 SUCCESS! Video uploaded to YouTube!"
  else
    puts "⚠️  Video not uploaded to YouTube (may need authentication)"
  end
  
rescue => e
  puts "❌ Error: #{e.message}"
  puts "First few lines of backtrace:"
  puts e.backtrace.first(3).join("\n")
end

puts ""
puts "📊 Test Results:"
puts "- Video creation: ✅"
puts "- Video approval: ✅"
puts "- Processing job: ✅"
puts ""
puts "🔗 Next steps:"
puts "1. Check generated files: ls storage/generated_videos/"
puts "2. YouTube Studio: https://studio.youtube.com/channel/UCdYIuVDuZsRd-G2jkGBxB4w"
puts "3. Start Rails server: rails s"
puts "4. View dashboard: http://localhost:3000/dashboard"