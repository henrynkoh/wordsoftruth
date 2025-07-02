#!/usr/bin/env ruby

puts "🎨 SHOWCASING ALL 4 SPIRITUAL THEMES"
puts "=" * 60

# Define all 4 spiritual themes
themes = [
  {
    name: "golden_light",
    title_prefix: "🌟 진리의 말씀",
    description: "Golden divine light rays - worship & praise",
    korean_style: "찬양과 경배"
  },
  {
    name: "peaceful_blue", 
    title_prefix: "🕯️ 진리의 말씀",
    description: "Peaceful flowing patterns - prayer & meditation",
    korean_style: "기도와 묵상"
  },
  {
    name: "sunset_worship",
    title_prefix: "🌅 진리의 말씀", 
    description: "Warm sunset colors - evening devotion",
    korean_style: "저녁 경건시간"
  },
  {
    name: "cross_pattern",
    title_prefix: "✝️ 진리의 말씀",
    description: "Cross pattern with divine light - scripture & faith", 
    korean_style: "성경과 믿음"
  }
]

uploaded_videos = []

themes.each_with_index do |theme, index|
  puts ""
  puts "🎬 Creating Theme #{index + 1}/4: #{theme[:name].upcase}"
  puts "   #{theme[:description]}"
  puts "   Korean style: #{theme[:korean_style]}"
  puts ""
  
  # Get different sermon for each theme
  sermon = Sermon.offset(rand(Sermon.count)).first
  
  # Create theme-specific Korean script
  spiritual_scripts = {
    "golden_light" => "하나님께 찬양과 영광을 올려드립니다! 오늘은 #{sermon.scripture}의 귀한 말씀으로 주님을 찬양하는 시간입니다. 주님의 영광이 우리를 비추시며, 그 빛 가운데서 우리가 기쁨으로 찬양할 수 있음을 감사드립니다. #{sermon.pastor} 목사님을 통해 전해주신 말씀으로 주님께 영광을 돌립니다. 할렐루야!",
    
    "peaceful_blue" => "하나님의 평안이 여러분의 마음에 충만하시기를 기도합니다. #{sermon.scripture}의 말씀을 통해 고요한 시간을 가져보시기 바랍니다. 주님 앞에서 조용히 기도하며, 그분의 음성에 귀 기울이는 귀한 시간이 되시길 바랍니다. #{sermon.pastor} 목사님의 말씀과 함께 평안을 누리시기 바랍니다. 아멘.",
    
    "sunset_worship" => "하루를 마감하며 주님께 감사드리는 시간입니다. #{sermon.scripture}의 말씀으로 오늘 하루를 돌아보며, 주님의 은혜를 기억합니다. 저녁 노을처럼 아름다운 주님의 사랑을 묵상하며, 내일도 주님과 함께 걸어갈 소망을 품습니다. #{sermon.pastor} 목사님의 말씀으로 하루를 마무리합니다.",
    
    "cross_pattern" => "십자가의 사랑을 기억하며 #{sermon.scripture}의 말씀을 나눕니다. 예수님께서 우리를 위해 십자가에서 보여주신 그 크신 사랑을 묵상합니다. 주님의 희생으로 우리가 구원받았음을 기억하며, 믿음으로 살아가는 하루가 되시기 바랍니다. #{sermon.pastor} 목사님의 말씀으로 믿음을 더욱 굳건히 합니다."
  }
  
  script = spiritual_scripts[theme[:name]]
  
  puts "📖 Using Sermon: #{sermon.title} (#{sermon.scripture})"
  puts "📝 Theme script: #{script[0..80]}..."
  
  # Create theme-specific configuration
  timestamp = Time.now.to_i + index
  video_filename = "showcase_#{theme[:name]}_#{timestamp}.mp4"
  config_filename = "config_#{theme[:name]}_#{timestamp}.json"
  
  video_config = {
    script_text: script,
    scripture_text: "#{sermon.scripture}\n\"#{theme[:korean_style]}\"\n진리의 말씀",
    theme: theme[:name],
    add_branding: true,
    output_file: "storage/generated_videos/#{video_filename}"
  }
  
  # Save config and generate video
  File.write(config_filename, JSON.pretty_generate(video_config))
  
  puts "🎨 Generating #{theme[:name]} theme video..."
  result = system("python3 scripts/generate_spiritual_video.py #{config_filename}")
  
  if result && File.exist?(video_config[:output_file])
    file_size = File.size(video_config[:output_file]) / 1024 / 1024
    puts "✅ Generated: #{file_size}MB"
    
    # Prepare metadata and upload
    youtube_metadata = {
      title: "#{theme[:title_prefix]} - #{sermon.scripture} | #{theme[:korean_style]}",
      scripture: sermon.scripture,
      content: script,
      church: sermon.church,
      pastor: sermon.pastor,
      source_url: "https://wordsoftruth.com/sermon/#{sermon.id}",
      theme: theme[:name]
    }
    
    puts "🚀 Uploading #{theme[:name]} to YouTube..."
    
    begin
      upload_result = YoutubeUploadService.upload_shorts(video_config[:output_file], youtube_metadata)
      
      if upload_result[:success]
        uploaded_videos << {
          theme: theme[:name],
          description: theme[:description],
          korean_style: theme[:korean_style],
          youtube_id: upload_result[:youtube_id],
          youtube_url: upload_result[:youtube_url],
          title: youtube_metadata[:title]
        }
        puts "✅ SUCCESS: #{upload_result[:youtube_id]}"
      else
        puts "❌ Upload failed: #{upload_result[:error]}"
      end
      
    rescue => e
      puts "❌ Error: #{e.message}"
    end
  else
    puts "❌ Video generation failed"
  end
  
  # Cleanup
  File.delete(config_filename) if File.exist?(config_filename)
  
  # Small delay between uploads
  sleep(2) if index < themes.length - 1
end

puts ""
puts "🎉 SPIRITUAL THEMES SHOWCASE COMPLETE!"
puts "=" * 60

if uploaded_videos.any?
  puts "📱 SHOWCASE VIDEOS FOR INVITEES:"
  puts ""
  
  uploaded_videos.each_with_index do |video, index|
    puts "#{index + 1}. #{video[:theme].upcase} Theme"
    puts "   🎨 Style: #{video[:description]}"
    puts "   🇰🇷 Korean: #{video[:korean_style]}"
    puts "   📺 Watch: #{video[:youtube_url]}"
    puts "   🔗 Short: https://youtu.be/#{video[:youtube_id]}"
    puts "   📋 Title: #{video[:title]}"
    puts ""
  end
  
  puts "🎯 PERFECT FOR SHARING WITH INVITEES:"
  puts "\"Check out our AI-generated Korean spiritual content! 🙏"
  puts ""
  puts "We've created 4 different themes for spiritual videos:\""
  puts ""
  
  uploaded_videos.each do |video|
    puts "#{video[:theme].upcase}: #{video[:youtube_url]}"
  end
  
  puts ""
  puts "🏠 BibleStartup Channel: https://www.youtube.com/@BibleStartup"
  puts "📊 Studio: https://studio.youtube.com/channel/UC4o3W-snviJWkgZLBxtkAeA/videos"
  puts ""
  puts "✨ Each video showcases:"
  puts "- Professional spiritual aesthetics"
  puts "- Korean language integration"
  puts "- Theme-appropriate visual design"
  puts "- Mobile-optimized for YouTube Shorts"
  puts "- Automatic generation from sermon database"
  
else
  puts "❌ No videos were successfully uploaded"
  puts "   Check authentication and try again"
end

puts ""
puts "🎬 Your BibleStartup channel now has a complete theme showcase!"
puts "   Ready to demonstrate the variety and quality to invitees! 🚀"