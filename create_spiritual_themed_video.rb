#!/usr/bin/env ruby

puts "🎨 CREATING SPIRITUAL-THEMED YOUTUBE SHORT"
puts "=" * 60

# Available spiritual themes
themes = [
  {
    name: "golden_light",
    description: "Golden gradient with divine light rays - perfect for worship and praise content",
    best_for: "Worship, praise, divine blessing themes"
  },
  {
    name: "peaceful_blue", 
    description: "Peaceful flowing blue patterns - ideal for prayer and meditation content",
    best_for: "Prayer, meditation, peace, comfort themes"
  },
  {
    name: "sunset_worship",
    description: "Warm sunset colors transitioning to purple - great for evening devotion",
    best_for: "Evening devotions, reflection, hope themes"
  },
  {
    name: "cross_pattern",
    description: "Subtle cross pattern with soft divine lighting - universal Christian theme",
    best_for: "Scripture reading, salvation, faith themes"
  }
]

puts "🎨 Available Spiritual Themes:"
themes.each_with_index do |theme, index|
  puts "#{index + 1}. #{theme[:name].upcase}"
  puts "   #{theme[:description]}"
  puts "   Best for: #{theme[:best_for]}"
  puts ""
end

# Select a random theme for demonstration
selected_theme = themes.sample
puts "🎯 Selected theme for demo: #{selected_theme[:name].upcase}"
puts "   #{selected_theme[:description]}"
puts ""

# Get a fresh sermon
sermon = Sermon.offset(rand(Sermon.count)).first
puts "📖 Using Sermon ID: #{sermon.id}"
puts "   Title: #{sermon.title}"
puts "   Scripture: #{sermon.scripture}"
puts "   Pastor: #{sermon.pastor}"
puts ""

# Create enhanced Korean script with spiritual language
spiritual_script = "하나님의 평안이 여러분과 함께하시기를 기도합니다. 오늘은 #{sermon.scripture}의 귀한 말씀을 함께 묵상하겠습니다. 주님의 말씀은 우리 영혼에 생명과 소망을 주시며, 어둠 가운데서도 빛이 되어주십니다. #{sermon.pastor} 목사님을 통해 전해주신 이 말씀이 여러분의 마음에 깊이 새겨지시기를 바랍니다. 주님의 사랑과 은혜가 충만하시기를 축복합니다. 아멘."

puts "📝 Enhanced spiritual script:"
puts "   Length: #{spiritual_script.length} characters"
puts "   Theme: Spiritual blessing and scripture meditation"
puts ""

# Create video configuration with spiritual theme
timestamp = Time.now.to_i
video_filename = "spiritual_#{selected_theme[:name]}_#{timestamp}.mp4"
config_filename = "spiritual_config_#{timestamp}.json"

# Enhanced scripture text with Korean translation hint
scripture_display = "#{sermon.scripture}\n\"하나님의 말씀\"\n진리의 말씀"

video_config = {
  script_text: spiritual_script,
  scripture_text: scripture_display,
  theme: selected_theme[:name],
  add_branding: true,
  output_file: "storage/generated_videos/#{video_filename}"
}

puts "🎥 Spiritual video configuration:"
puts "   Theme: #{selected_theme[:name]}"
puts "   Output file: #{video_config[:output_file]}"
puts "   Scripture display: #{scripture_display.split('\n').first}"
puts "   Branding: Enabled"
puts ""

# Save configuration file
File.write(config_filename, JSON.pretty_generate(video_config))
puts "✅ Spiritual configuration saved: #{config_filename}"
puts ""

# Generate the video using enhanced spiritual script
puts "🎨 Generating spiritual-themed video..."
puts "   Theme: #{selected_theme[:name].upcase}"
puts "   Style: #{selected_theme[:description]}"
puts ""

result = system("python3 scripts/generate_spiritual_video.py #{config_filename}")

if result && File.exist?(video_config[:output_file])
  file_size = File.size(video_config[:output_file]) / 1024 / 1024
  puts "✅ Spiritual video generated successfully!"
  puts "   File: #{video_config[:output_file]}"
  puts "   Size: #{file_size}MB"
  puts "   Theme: #{selected_theme[:name]}"
  puts ""
  
  # Prepare enhanced YouTube metadata
  youtube_metadata = {
    title: "진리의 말씀 - #{sermon.scripture} | #{selected_theme[:name]} 테마",
    scripture: sermon.scripture,
    content: spiritual_script,
    church: sermon.church,
    pastor: sermon.pastor,
    source_url: "https://wordsoftruth.com/sermon/#{sermon.id}",
    theme: selected_theme[:name]
  }
  
  puts "📋 Enhanced YouTube metadata:"
  puts "   Title: #{youtube_metadata[:title]}"
  puts "   Theme indicator: #{selected_theme[:name]} 테마"
  puts "   Spiritual content: Enhanced with blessings"
  puts ""
  
  # Upload to YouTube with spiritual theme
  puts "🙏 Uploading spiritual video to BibleStartup channel..."
  
  begin
    upload_result = YoutubeUploadService.upload_shorts(video_config[:output_file], youtube_metadata)
    
    if upload_result[:success]
      puts "🎉 SUCCESS! Spiritual YouTube Short uploaded!"
      puts "   YouTube ID: #{upload_result[:youtube_id]}"
      puts "   YouTube URL: #{upload_result[:youtube_url]}"
      puts "   Theme: #{selected_theme[:name].upcase}"
      puts "   BibleStartup Studio: https://studio.youtube.com/channel/UC4o3W-snviJWkgZLBxtkAeA/videos"
      puts ""
      puts "📱 ENHANCED SHAREABLE LINKS:"
      puts "   Watch: #{upload_result[:youtube_url]}"
      puts "   Short URL: https://youtu.be/#{upload_result[:youtube_id]}"
      puts "   Channel: https://www.youtube.com/@BibleStartup"
      puts ""
      puts "🎨 Theme Features:"
      puts "   - #{selected_theme[:description]}"
      puts "   - Enhanced typography with spiritual colors"
      puts "   - Fade-in effects for scripture verses"
      puts "   - Channel branding with Korean text"
      puts "   - High-quality rendering (8000k bitrate)"
      puts ""
      puts "🎯 Perfect for: #{selected_theme[:best_for]}"
      puts ""
      puts "✨ Video includes spiritual enhancements:"
      puts "   - Divine blessing language in Korean"
      puts "   - Multi-line scripture display with Korean"
      puts "   - Theme-specific color schemes"
      puts "   - Smooth fade-in animations"
      puts "   - Professional spiritual branding"
      
    else
      puts "❌ Upload failed: #{upload_result[:error]}"
      puts "   Spiritual video created but upload issue occurred"
      puts "   File: #{video_config[:output_file]}"
    end
    
  rescue => e
    puts "❌ Upload error: #{e.message}"
    puts "   Spiritual video file: #{video_config[:output_file]}"
    puts "   Theme: #{selected_theme[:name]}"
  end
  
else
  puts "❌ Spiritual video generation failed"
  puts "   Check Python dependencies and spiritual video script"
end

# Cleanup
File.delete(config_filename) if File.exist?(config_filename)

puts ""
puts "🎨 SPIRITUAL THEME SHOWCASE COMPLETE!"
puts "=" * 50
puts "📊 Enhanced Features Summary:"
puts "- 4 unique spiritual themes with divine aesthetics"
puts "- Enhanced Korean script with spiritual blessings"
puts "- Multi-line scripture display with Korean translation"
puts "- Theme-specific typography and color schemes"
puts "- Smooth animations and fade-in effects"
puts "- Professional channel branding"
puts "- High-quality rendering for better visual appeal"
puts ""
puts "🎯 Each theme is optimized for different spiritual content:"
themes.each do |theme|
  puts "- #{theme[:name].upcase}: #{theme[:best_for]}"
end
puts ""
puts "✨ Ready to create beautiful spiritual content for your audience!"