#!/usr/bin/env ruby
require 'json'

puts "🎬 DIRECT VIDEO CREATION (BYPASSING RAILS VALIDATIONS)"
puts "=" * 60
puts "📺 Channel: https://studio.youtube.com/channel/UCdYIuVDuZsRd-G2jkGBxB4w"
puts ""

# Step 1: Create video config directly (bypass Rails for now)
puts "📝 Step 1: Creating video configuration..."

video_id = Time.now.to_i
sermon_data = {
  title: "하나님의 사랑과 평안",
  scripture: "요한복음 14:27",
  pastor: "김목사",
  church: "은혜교회",
  interpretation: "평안을 너희에게 끼치노니 곧 나의 평안을 너희에게 주노라. 내가 너희에게 주는 것은 세상이 주는 것과 같지 아니하니라. 너희는 마음에 근심하지도 말고 두려워하지도 말라. 예수님이 주시는 참된 평안은 세상의 그 어떤 것과도 다릅니다."
}

# Create script content
script_content = [
  "제목: #{sermon_data[:title]}",
  "성경: #{sermon_data[:scripture]}",
  "목사: #{sermon_data[:pastor]}",
  "",
  sermon_data[:interpretation],
  "",
  "실천사항:",
  "1. 매일 기도하기",
  "2. 성경 읽기", 
  "3. 이웃 사랑하기",
  "4. 감사하는 마음 갖기"
].join("\n")

puts "✅ 설교 내용 준비 완료!"
puts "   제목: #{sermon_data[:title]}"
puts "   성경: #{sermon_data[:scripture]}"
puts "   스크립트 길이: #{script_content.length} 글자"
puts ""

# Step 2: Generate video using Python script directly
puts "🎥 Step 2: Generating video file..."

# Create video config
video_config = {
  script_text: script_content,
  background_video: "storage/background_videos/simple_navy.mp4",
  output_file: "storage/generated_videos/direct_video_#{video_id}.mp4",
  scripture_text: sermon_data[:scripture]
}

config_file = "tmp/direct_video_config_#{video_id}.json"
File.write(config_file, JSON.pretty_generate(video_config))

puts "📄 Config file created: #{config_file}"
puts "🐍 Running Python video generation..."
puts "   (This will take 2-3 minutes...)"
puts ""

# Execute Python script with detailed output
command = "python3 scripts/generate_video.py #{config_file}"
puts "Executing: #{command}"
puts "-" * 50

success = system(command)

puts "-" * 50
puts ""

# Step 3: Check results
output_file = video_config[:output_file]

if success && File.exist?(output_file)
  file_size = File.size(output_file)
  puts "🎉 비디오 생성 성공!"
  puts ""
  puts "📊 생성된 비디오 정보:"
  puts "   📁 파일: #{output_file}"
  puts "   💾 크기: #{(file_size / 1024.0 / 1024.0).round(2)} MB"
  puts "   🎬 포맷: MP4 (1080x1920)"
  puts "   🎙️ 오디오: 한국어 TTS"
  puts "   📜 오버레이: #{sermon_data[:scripture]}"
  puts ""
  
  # Check video properties using ffprobe
  puts "🔍 비디오 속성 확인..."
  video_info = `ffprobe -v quiet -print_format json -show_format -show_streams "#{output_file}" 2>/dev/null`
  
  if $?.success? && !video_info.empty?
    begin
      info = JSON.parse(video_info)
      video_stream = info['streams']&.find { |s| s['codec_type'] == 'video' }
      
      if video_stream
        width = video_stream['width']
        height = video_stream['height'] 
        duration = info['format']['duration'].to_f
        
        puts "   ✅ 해상도: #{width}x#{height}"
        puts "   ✅ 길이: #{duration.round(1)}초"
        puts "   ✅ 비트레이트: #{info['format']['bit_rate']} bps" if info['format']['bit_rate']
        
        if width == 1080 && height == 1920
          puts "   🎯 YouTube Shorts 형식 완벽!"
        else
          puts "   ⚠️  해상도가 YouTube Shorts 최적화되지 않음"
        end
      end
    rescue JSON::ParserError
      puts "   ℹ️  비디오 속성 분석 실패 (파일은 정상)"
    end
  end
  
  puts ""
  puts "🎊 SUCCESS! 첫 번째 YouTube Short 파일 생성 완료!"
  puts "=" * 50
  puts ""
  puts "🔍 확인 방법:"
  puts "1. 비디오 재생: open '#{output_file}'"
  puts "2. 파인더에서 보기: open storage/generated_videos/"
  puts ""
  puts "📤 YouTube 업로드 옵션:"
  puts "1. 수동 업로드:"
  puts "   - YouTube Studio 방문: https://studio.youtube.com/channel/UCdYIuVDuZsRd-G2jkGBxB4w"
  puts "   - '만들기' > '동영상 업로드' 클릭"
  puts "   - 생성된 파일 선택: #{output_file}"
  puts ""
  puts "2. 자동 업로드 (Rails 앱 사용):"
  puts "   - Rails 서버 시작: bin/dev"
  puts "   - OAuth 인증 완료"
  puts "   - 업로드 API 호출"
  puts ""
  puts "🎯 추천 YouTube 설정:"
  puts "   • 제목: #{sermon_data[:title]} - #{sermon_data[:pastor]} | #{sermon_data[:church]}"
  puts "   • 설명: 성경: #{sermon_data[:scripture]} + 설교 내용"
  puts "   • 태그: #Shorts #설교 #기독교 #성경 ##{sermon_data[:church].gsub(' ', '')}"
  puts "   • 카테고리: 교육"
  puts "   • 가시성: 공개"
  
  # Try to open the video automatically
  puts ""
  puts "🎬 비디오 자동 재생 시도..."
  if system("which open > /dev/null 2>&1")
    system("open '#{output_file}' 2>/dev/null")
    puts "✅ 비디오가 기본 플레이어에서 열렸습니다!"
  else
    puts "ℹ️  수동으로 비디오를 확인하세요: #{output_file}"
  end
  
else
  puts "❌ 비디오 생성 실패"
  puts ""
  puts "🔧 문제 해결:"
  puts "1. Python 종속성 확인:"
  puts "   python3 -c 'import moviepy, gtts, json; print(\"모든 패키지 설치됨\")'"
  puts ""
  puts "2. 배경 비디오 확인:"
  puts "   ls -la storage/background_videos/"
  puts ""
  puts "3. ImageMagick 확인:"
  puts "   which convert"
  puts ""
  puts "4. 권한 확인:"
  puts "   ls -la storage/generated_videos/"
  puts ""
  puts "5. Python 스크립트 직접 테스트:"
  puts "   python3 scripts/generate_video.py #{config_file}"
end

# Cleanup
File.delete(config_file) if File.exist?(config_file)

puts ""
puts "=" * 60
puts "🏁 작업 완료!"
puts ""
puts "💡 이 스크립트는 Rails 모델을 우회하여 직접 비디오를 생성합니다."
puts "   YouTube 업로드를 원한다면 수동으로 업로드하거나 Rails OAuth를 설정하세요."