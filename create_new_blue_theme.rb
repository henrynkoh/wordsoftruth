#!/usr/bin/env ruby

puts "🕯️ CREATING NEW PEACEFUL BLUE THEME VIDEO"
puts "=" * 50

# Get a different sermon for this blue theme
sermon = Sermon.offset(rand(Sermon.count)).first
puts "📖 Using fresh sermon: #{sermon.title}"
puts "   Scripture: #{sermon.scripture}"
puts "   Pastor: #{sermon.pastor}"
puts ""

# Create enhanced Korean script for peaceful blue theme
peaceful_script = "하나님의 평안이 여러분과 함께하시기를 축복합니다. 오늘은 #{sermon.scripture}의 말씀으로 조용한 묵상의 시간을 가져보겠습니다. 마음을 고요히 하고 주님 앞에 나아가며, 그분의 음성에 귀 기울이는 시간이 되시기 바랍니다. #{sermon.pastor} 목사님의 말씀과 함께 평안한 기도의 시간을 갖습니다. 주님의 평안이 여러분의 마음과 생각을 지키시기를 기도합니다."

puts "📝 Peaceful Blue script created:"
puts "   Length: #{peaceful_script.length} characters"
puts "   Focus: Prayer, meditation, peaceful reflection"
puts ""

# Create video configuration for peaceful blue theme
timestamp = Time.now.to_i
video_filename = "peaceful_blue_new_#{timestamp}.mp4"
config_filename = "peaceful_config_#{timestamp}.json"

video_config = {
  script_text: peaceful_script,
  scripture_text: "#{sermon.scripture}\n\"평안한 묵상\"\n진리의 말씀",
  theme: "peaceful_blue",
  add_branding: true,
  output_file: "storage/generated_videos/#{video_filename}"
}

puts "🎨 Video configuration:"
puts "   Theme: peaceful_blue (flowing blue patterns)"
puts "   Output: #{video_config[:output_file]}"
puts "   Scripture overlay: #{sermon.scripture} with peaceful meditation theme"
puts ""

# Save configuration and generate video
File.write(config_filename, JSON.pretty_generate(video_config))
puts "✅ Configuration saved: #{config_filename}"

puts "🎨 Generating peaceful blue theme video..."
result = system("python3 scripts/generate_spiritual_video.py #{config_filename}")

if result && File.exist?(video_config[:output_file])
  file_size = File.size(video_config[:output_file]) / 1024 / 1024
  puts "✅ New peaceful blue video generated!"
  puts "   File: #{video_config[:output_file]}"
  puts "   Size: #{file_size}MB"
  puts ""
  
  # Enhanced metadata for the new blue theme
  youtube_metadata = {
    title: "🕯️ 평안한 묵상 - #{sermon.scripture} | 기도와 평안",
    scripture: sermon.scripture,
    content: peaceful_script,
    church: sermon.church,
    pastor: sermon.pastor,
    source_url: "https://wordsoftruth.com/sermon/#{sermon.id}"
  }
  
  puts "📋 Enhanced YouTube metadata:"
  puts "   Title: #{youtube_metadata[:title]}"
  puts "   Theme: Peaceful meditation with flowing blue aesthetics"
  puts ""
  
  puts "🚀 Uploading new peaceful blue theme to YouTube..."
  
  begin
    upload_result = YoutubeUploadService.upload_shorts(video_config[:output_file], youtube_metadata)
    
    if upload_result[:success]
      puts "🎉 SUCCESS! New Peaceful Blue theme uploaded!"
      puts ""
      puts "🕯️ NEW PEACEFUL BLUE THEME - LIVE:"
      puts "   YouTube ID: #{upload_result[:youtube_id]}"
      puts "   YouTube URL: #{upload_result[:youtube_url]}"
      puts "   Short URL: https://youtu.be/#{upload_result[:youtube_id]}"
      puts ""
      puts "📱 NOW YOU HAVE BOTH THEMES:"
      puts "   🌟 Golden Light (Worship): https://youtu.be/6Bugm87RFQo"
      puts "   🕯️ Peaceful Blue (Prayer): https://youtu.be/#{upload_result[:youtube_id]}"
      puts ""
      puts "🎨 This new blue theme features:"
      puts "   - Enhanced peaceful flowing blue patterns"
      puts "   - Perfect for meditation and prayer content"
      puts "   - Calming Korean spiritual narration"
      puts "   - Professional channel branding"
      puts "   - Fresh sermon content (#{sermon.scripture})"
      puts ""
      puts "✅ Ready to share with invitees - both themes now working!"
      
    else
      puts "❌ Upload failed: #{upload_result[:error]}"
    end
    
  rescue => e
    puts "❌ Upload error: #{e.message}"
  end
  
else
  puts "❌ Video generation failed"
end

# Cleanup
File.delete(config_filename) if File.exist?(config_filename)

puts ""
puts "🎯 Check your YouTube Studio in a few minutes to see the new video!"