#!/usr/bin/env ruby

puts "🎬 CREATING YOUR FIRST REAL YOUTUBE SHORT"
puts "=" * 50
puts "📺 Channel: https://studio.youtube.com/channel/UCdYIuVDuZsRd-G2jkGBxB4w"
puts ""

# Step 1: Create a sermon
puts "📝 Step 1: Creating sermon..."
sermon = Sermon.create!(
  title: "하나님의 사랑과 평안",
  scripture: "요한복음 14:27",
  pastor: "김목사",
  church: "은혜교회",
  interpretation: "평안을 너희에게 끼치노니 곧 나의 평안을 너희에게 주노라. 내가 너희에게 주는 것은 세상이 주는 것과 같지 아니하니라. 너희는 마음에 근심하지도 말고 두려워하지도 말라. 예수님이 주시는 참된 평안은 세상의 그 어떤 것과도 다릅니다. 이 평안은 환경이나 상황에 좌우되지 않는 영원한 평안입니다.",
  action_points: "1. 매일 기도로 하나님께 가까이 나아가기\n2. 성경 말씀으로 마음을 채우기\n3. 어려운 이웃에게 사랑 나누기\n4. 감사하는 마음으로 살아가기\n5. 하나님의 평안을 다른 이들과 나누기",
  source_url: "https://grace-church.com/peace-sermon-1"
)

puts "✅ 설교 생성 완료!"
puts "   제목: #{sermon.title}"
puts "   성경: #{sermon.scripture}"
puts "   목사: #{sermon.pastor}"
puts "   교회: #{sermon.church}"
puts ""

# Step 2: Generate video script
puts "🎬 Step 2: Generating video script..."
video = sermon.schedule_video_generation!(1, {
  style: 'engaging',
  target_audience: 'general'
})

puts "✅ 비디오 스크립트 생성 완료!"
puts "   비디오 ID: #{video.id}"
puts "   초기 상태: #{video.status}"
puts "   스크립트 길이: #{video.script.length} 글자"
puts ""
puts "📄 생성된 스크립트 미리보기:"
puts "-" * 40
puts video.script[0..300] + "..."
puts "-" * 40
puts ""

# Step 3: Approve video
puts "✅ Step 3: Approving video for processing..."
video.approve!
puts "✅ 비디오 승인 완료! 상태: #{video.reload.status}"
puts ""

# Step 4: Process and upload to YouTube
puts "🚀 Step 4: Processing video and uploading to YouTube..."
puts "⚠️  이 과정은 3-5분 소요됩니다."
puts "⚠️  첫 번째 업로드시 YouTube 인증이 필요할 수 있습니다."
puts ""

begin
  VideoProcessingJob.perform_now([video.id])
  
  # Check result
  video.reload
  puts "🎉 처리 완료!"
  puts "   최종 상태: #{video.status}"
  
  if video.status == 'uploaded' && video.youtube_id.present?
    puts "   YouTube ID: #{video.youtube_id}"
    puts "   YouTube URL: #{video.youtube_url}"
    puts ""
    puts "🎬 SUCCESS! Your YouTube Short is now live!"
    puts "📱 Visit your channel: https://studio.youtube.com/channel/UCdYIuVDuZsRd-G2jkGBxB4w/videos/short"
    puts ""
    puts "🎯 Video Details:"
    puts "   - Title: #{video.sermon.title} - #{video.sermon.pastor} | #{video.sermon.church}"
    puts "   - Duration: ~45-60 seconds"
    puts "   - Format: 1080x1920 (YouTube Shorts)"
    puts "   - Audio: Korean TTS"
    puts "   - Content: Scripture + Sermon interpretation"
  else
    puts "⚠️  Upload may need authorization. Check logs for authorization URL."
    puts "   Current status: #{video.status}"
    if video.video_path.present?
      puts "   Video file created: #{video.video_path}"
    end
  end
  
rescue => e
  puts "❌ Error during processing: #{e.message}"
  puts ""
  puts "🔧 Troubleshooting:"
  puts "1. Check if YouTube authorization is needed"
  puts "2. Verify video generation worked: ls storage/generated_videos/"
  puts "3. Check Rails logs: tail log/development.log"
  puts "4. Try manual authorization if needed"
  puts ""
  puts "📧 Error details:"
  puts e.backtrace.first(5).join("\n")
end

puts ""
puts "📊 Summary:"
puts "- Sermon created: ✅"
puts "- Video script generated: ✅" 
puts "- Video approved: ✅"
puts "- Processing attempted: ✅"
puts ""
puts "🔗 Check your results:"
puts "1. YouTube Studio: https://studio.youtube.com/channel/UCdYIuVDuZsRd-G2jkGBxB4w/videos"
puts "2. Shorts section: https://studio.youtube.com/channel/UCdYIuVDuZsRd-G2jkGBxB4w/videos/short"
puts "3. Dashboard: http://localhost:3000/dashboard (after starting Rails server)"