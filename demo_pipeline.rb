#!/usr/bin/env ruby

puts '🎬 LIVE PIPELINE DEMONSTRATION'
puts '=' * 50

# Step 1: Create a demonstration sermon
puts "\n📝 Step 1: Creating demonstration sermon..."
sermon = Sermon.create!(
  title: 'Walking in Faith During Difficult Times',
  scripture: 'Romans 8:28',
  pastor: 'Pastor Demo',
  church: 'Demo Faith Church',
  interpretation: 'When we face trials and tribulations, we must remember that God works all things together for good for those who love Him. This passage reminds us that even in our darkest moments, God has a plan and purpose. Faith is not the absence of doubt, but the decision to trust God despite our circumstances.',
  action_points: "1. Pray daily for strength and guidance\n2. Study God's promises in Scripture\n3. Fellowship with other believers\n4. Serve others in need\n5. Remember God's faithfulness in the past",
  source_url: 'https://demo.church/sermons/walking-in-faith'
)
puts "✅ Sermon created: ID #{sermon.id}"

# Step 2: Generate video script
puts "\n🎬 Step 2: Generating video script..."
video = sermon.schedule_video_generation!(1, {
  style: 'engaging',
  duration: 'short_form',
  target_audience: 'general'
})
puts "✅ Video created: ID #{video.id}"
puts "📄 Generated script (#{video.script.length} chars):"
puts video.script[0..200] + '...'

# Step 3: Show approval workflow
puts "\n✅ Step 3: Video approval workflow..."
puts "Initial status: #{video.status}"
video.approve!
puts "After approval: #{video.reload.status}"

# Step 4: Show processing simulation
puts "\n⚡ Step 4: Video processing simulation..."
video.start_processing!
puts "Processing status: #{video.reload.status}"

# Step 5: Show metrics and monitoring
puts "\n📊 Step 5: Real-time metrics..."
stats = {
  total_sermons: Sermon.count,
  total_videos: Video.count,
  pending_videos: Video.pending.count,
  approved_videos: Video.approved.count,
  processing_videos: Video.processing.count
}
stats.each { |key, value| puts "#{key.to_s.humanize}: #{value}" }

# Step 6: Show business activity logging
puts "\n📋 Step 6: Business activity summary..."
if defined?(BusinessActivityLog)
  summary = BusinessActivityLog.activity_summary(1.hour)
  puts "Activities in last hour: #{summary[:total_activities]}"
  puts "Activity types: #{summary[:by_type]}"
end

puts "\n🎯 PIPELINE DEMONSTRATION COMPLETE!"
puts "Visit http://localhost:3000/ to see the monitoring dashboard"
puts "Visit http://localhost:3000/dashboard to see the video management interface"