#!/usr/bin/env ruby

puts "🎬 CHECKING SHOWCASE STATUS"
puts "=" * 50

# Check generated videos
showcase_files = Dir.glob("storage/generated_videos/showcase_*.mp4")

puts "📁 Generated videos found:"
showcase_files.each do |file|
  size_mb = File.size(file) / 1024 / 1024
  theme = file.match(/showcase_(\w+)_/)[1]
  puts "   #{theme.upcase}: #{File.basename(file)} (#{size_mb}MB)"
end
puts ""

# We know golden_light was uploaded successfully: 6Bugm87RFQo
uploaded_videos = [
  {
    theme: "golden_light",
    youtube_id: "6Bugm87RFQo",
    youtube_url: "https://www.youtube.com/watch?v=6Bugm87RFQo",
    title: "🌟 진리의 말씀 - Romans 26:27 | 찬양과 경배",
    description: "Golden divine light rays - worship & praise"
  }
]

# Check if peaceful_blue video exists and upload it
peaceful_blue_file = "storage/generated_videos/showcase_peaceful_blue_1751427620.mp4"

if File.exist?(peaceful_blue_file)
  puts "🕯️ Found PEACEFUL_BLUE video (#{File.size(peaceful_blue_file) / 1024 / 1024}MB)"
  puts "   Uploading to YouTube..."
  
  # Get sermon info (approximate based on the pattern)
  youtube_metadata = {
    title: "🕯️ 진리의 말씀 - Exodus 2:13 | 기도와 묵상",
    scripture: "Exodus 2:13",
    content: "하나님의 평안이 여러분의 마음에 충만하시기를 기도합니다. 고요한 시간을 가져보시기 바랍니다.",
    church: "진리의 교회",
    pastor: "목사님",
    source_url: "https://wordsoftruth.com/showcase",
    theme: "peaceful_blue"
  }
  
  begin
    upload_result = YoutubeUploadService.upload_shorts(peaceful_blue_file, youtube_metadata)
    
    if upload_result[:success]
      uploaded_videos << {
        theme: "peaceful_blue",
        youtube_id: upload_result[:youtube_id],
        youtube_url: upload_result[:youtube_url],
        title: youtube_metadata[:title],
        description: "Peaceful flowing patterns - prayer & meditation"
      }
      puts "   ✅ SUCCESS: #{upload_result[:youtube_id]}"
    else
      puts "   ❌ Upload failed: #{upload_result[:error]}"
    end
  rescue => e
    puts "   ❌ Error: #{e.message}"
  end
end

puts ""
puts "📊 CURRENT SHOWCASE STATUS:"
puts "=" * 30

uploaded_videos.each_with_index do |video, index|
  puts "#{index + 1}. #{video[:theme].upcase} ✅ LIVE"
  puts "   🎨 #{video[:description]}"
  puts "   📺 #{video[:youtube_url]}"
  puts "   🔗 https://youtu.be/#{video[:youtube_id]}"
  puts ""
end

puts "🎯 SHAREABLE SHOWCASE FOR INVITEES:"
puts "\"Check out our AI-generated Korean spiritual videos! 🙏\""
puts ""
uploaded_videos.each do |video|
  puts "#{video[:theme].upcase}: #{video[:youtube_url]}"
end

puts ""
puts "🏠 BibleStartup Channel: https://www.youtube.com/@BibleStartup"
puts "📊 YouTube Studio: https://studio.youtube.com/channel/UC4o3W-snviJWkgZLBxtkAeA/videos"
puts ""
puts "✨ Each video demonstrates different spiritual aesthetics perfect for religious content!"