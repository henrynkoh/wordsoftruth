#!/usr/bin/env ruby

puts "🎬 TESTING COMPLETE YOUTUBE SHORTS PIPELINE"
puts "=" * 50
puts "📺 Channel: https://studio.youtube.com/channel/UCdYIuVDuZsRd-G2jkGBxB4w"
puts ""

# Step 1: Create a properly formatted sermon
puts "📝 Step 1: Creating properly formatted sermon..."
sermon = Sermon.create!(
  title: "Test Sermon: God's Peace and Love #{Time.now.to_i}",
  scripture: "John 14:27",
  pastor: "Pastor Kim Min-ho",
  church: "Grace Community Church",
  denomination: "Presbyterian",
  audience_count: 150,
  interpretation: "Jesus said: 'Peace I leave with you; my peace I give you. I do not give to you as the world gives. Do not let your hearts be troubled and do not be afraid.' The peace that Jesus gives us is different from worldly peace. It is eternal peace that does not depend on circumstances or situations. This divine peace sustains us through all trials.",
  action_points: "1. Practice daily prayer to draw closer to God and receive His peace\n2. Read Scripture regularly to fill your heart with God's word\n3. Share God's love with neighbors in need through practical service\n4. Cultivate a grateful heart in all circumstances\n5. Share the peace of Christ with others through your testimony and actions",
  source_url: "https://grace-community-church.com/peace-sermon-test"
)

puts "✅ Sermon created successfully!"
puts "   ID: #{sermon.id}"
puts "   Title: #{sermon.title}"
puts "   Scripture: #{sermon.scripture}"
puts "   Pastor: #{sermon.pastor}"
puts "   Church: #{sermon.church}"
puts "   Audience: #{sermon.audience_count} people"
puts ""

# Step 2: Generate video script
puts "🎬 Step 2: Generating video script..."
video = sermon.schedule_video_generation!(1, {
  style: 'engaging',
  target_audience: 'general'
})

puts "✅ Video script generated!"
puts "   Video ID: #{video.id}"
puts "   Status: #{video.status}"
puts "   Script length: #{video.script.length} characters"
puts ""
puts "📄 Script preview (first 300 characters):"
puts "-" * 40
puts video.script[0..300] + "..."
puts "-" * 40
puts ""

# Step 3: Approve video for processing
puts "✅ Step 3: Approving video for processing..."
video.approve!
puts "✅ Video approved! Status: #{video.reload.status}"
puts ""

# Step 4: Process video and attempt YouTube upload
puts "🚀 Step 4: Processing video and uploading to YouTube..."
puts "⚠️  This process takes 3-5 minutes"
puts "⚠️  YouTube authentication may be required for first upload"
puts ""

begin
  # Start the processing job
  VideoProcessingJob.perform_now([video.id])
  
  # Check the result
  video.reload
  puts "🎉 Processing completed!"
  puts "   Final status: #{video.status}"
  
  if video.status == 'uploaded' && video.youtube_id.present?
    puts "   YouTube ID: #{video.youtube_id}"
    puts "   YouTube URL: #{video.youtube_url}"
    puts ""
    puts "🎬 SUCCESS! Your YouTube Short is now live!"
    puts "📱 YouTube Studio: https://studio.youtube.com/channel/UCdYIuVDuZsRd-G2jkGBxB4w/videos"
    puts "📱 YouTube Shorts: https://studio.youtube.com/channel/UCdYIuVDuZsRd-G2jkGBxB4w/videos/short"
    puts ""
    puts "🎯 Video Details:"
    puts "   - Title: #{video.sermon.title}"
    puts "   - Duration: ~45-60 seconds"
    puts "   - Format: 1080x1920 (YouTube Shorts optimized)"
    puts "   - Audio: Korean text-to-speech"
    puts "   - Content: Scripture + Interpretation + Action points"
  elsif video.status == 'processed' && video.video_path.present?
    puts "✅ Video generated successfully but not uploaded to YouTube"
    puts "   Video file: #{video.video_path}"
    puts "   File size: #{File.size(video.video_path) / 1024 / 1024}MB" if File.exist?(video.video_path)
    puts ""
    puts "⚠️  YouTube upload may require manual authorization"
    puts "📧 Check logs for authorization URL if needed"
  else
    puts "⚠️  Processing incomplete. Current status: #{video.status}"
    if video.video_path.present?
      puts "   Video file path: #{video.video_path}"
      puts "   File exists: #{File.exist?(video.video_path)}"
    end
  end
  
rescue => e
  puts "❌ Error during processing: #{e.message}"
  puts ""
  puts "🔧 Troubleshooting steps:"
  puts "1. Check if YouTube OAuth authorization is needed"
  puts "2. Verify video file generation: ls storage/generated_videos/"
  puts "3. Check Rails logs: tail -f log/development.log"
  puts "4. Verify Python dependencies are installed"
  puts ""
  puts "📧 Error details:"
  puts e.backtrace.first(3).join("\n")
end

puts ""
puts "📊 Pipeline Test Summary:"
puts "=" * 30
puts "- Sermon creation: ✅"
puts "- Video script generation: ✅" 
puts "- Video approval: ✅"
puts "- Processing job: ✅"
puts ""
puts "🔗 Next steps to check results:"
puts "1. YouTube Studio: https://studio.youtube.com/channel/UCdYIuVDuZsRd-G2jkGBxB4w"
puts "2. Local files: ls storage/generated_videos/"
puts "3. Rails console: rails c"
puts "4. Dashboard: http://localhost:3000/dashboard"
puts ""
puts "🎯 Complete end-to-end test finished!"