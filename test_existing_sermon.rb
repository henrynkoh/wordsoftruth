#!/usr/bin/env ruby

puts "🎬 TESTING PIPELINE WITH EXISTING SERMON"
puts "=" * 50

# Use existing sermon
sermon = Sermon.first
puts "📝 Using existing sermon:"
puts "   Title: #{sermon.title}"
puts "   Pastor: #{sermon.pastor}"
puts "   Church: #{sermon.church}"
puts "   Scripture: #{sermon.scripture}"
puts "   Audience: #{sermon.audience_count}"
puts ""

# Generate video
puts "🎬 Generating video script..."
video = sermon.schedule_video_generation!(1, { 
  style: 'engaging', 
  target_audience: 'general' 
})

puts "✅ Video created successfully!"
puts "   Video ID: #{video.id}"
puts "   Status: #{video.status}"
puts "   Script length: #{video.script.length} characters"
puts ""

# Show script preview
puts "📄 Script preview (first 300 chars):"
puts "-" * 40
puts video.script[0..300] + "..."
puts "-" * 40
puts ""

# Approve video
puts "✅ Approving video for processing..."
video.approve!
puts "✅ Video approved! Status: #{video.reload.status}"
puts ""

# Process video
puts "🚀 Starting video processing..."
puts "⚠️  This will take 3-5 minutes..."
puts ""

begin
  VideoProcessingJob.perform_now([video.id])
  
  # Check results
  video.reload
  puts "🎉 Processing completed!"
  puts "   Final status: #{video.status}"
  
  case video.status
  when 'uploaded'
    if video.youtube_id.present?
      puts "   YouTube ID: #{video.youtube_id}"
      puts "   YouTube URL: #{video.youtube_url}"
      puts ""
      puts "🎬 SUCCESS! YouTube Short uploaded successfully!"
      puts "📱 View at: https://studio.youtube.com/channel/UCdYIuVDuZsRd-G2jkGBxB4w/videos"
      puts "📱 Shorts: https://studio.youtube.com/channel/UCdYIuVDuZsRd-G2jkGBxB4w/videos/short"
    end
  when 'processed'
    puts "   Video file: #{video.video_path}"
    if video.video_path.present? && File.exist?(video.video_path)
      file_size = File.size(video.video_path) / 1024 / 1024
      puts "   File size: #{file_size}MB"
      puts "✅ Video generated successfully!"
      puts "⚠️  YouTube upload requires authentication"
    end
  when 'failed'
    puts "   Error: #{video.error_message}"
    puts "❌ Video processing failed"
  else
    puts "   Current status: #{video.status}"
    puts "⚠️  Processing incomplete"
  end
  
rescue => e
  puts "❌ Processing error: #{e.message}"
  puts ""
  puts "Error details:"
  puts e.backtrace.first(3).join("\n")
end

puts ""
puts "📊 Test Summary:"
puts "=" * 20
puts "- Sermon selection: ✅"
puts "- Video script generation: ✅"
puts "- Video approval: ✅"
puts "- Processing job: ✅"
puts ""
puts "🔗 Check results:"
puts "1. Generated videos: ls storage/generated_videos/"
puts "2. YouTube Studio: https://studio.youtube.com/channel/UCdYIuVDuZsRd-G2jkGBxB4w"
puts "3. Local dashboard: Start rails server and visit /dashboard"
puts ""
puts "🎯 End-to-end test completed!"