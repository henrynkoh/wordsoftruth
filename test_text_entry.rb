#!/usr/bin/env ruby

# Test Korean spiritual text processing and AI theme detection
# This simulates the text entry functionality

require 'json'

class TextNoteTest
  def initialize
    @theme_keywords = {
      'golden_light' => %w[찬양 경배 할렐루야 영광 찬송],
      'peaceful_blue' => %w[기도 묵상 평안 고요 조용],
      'sunset_worship' => %w[저녁 감사 하루 마감 소망],
      'cross_pattern' => %w[십자가 믿음 구원 성경 말씀],
      'mountain_majesty' => %w[힘 인내 산 견디 강함],
      'flowing_river' => %w[새로운 생명 세례 거듭 새롭]
    }
  end
  
  def detect_theme_from_content(content)
    return 'golden_light' unless content.present?
    
    detected_theme = 'golden_light'
    max_matches = 0
    
    @theme_keywords.each do |theme, keywords|
      matches = keywords.count { |keyword| content.include?(keyword) }
      if matches > max_matches
        max_matches = matches
        detected_theme = theme
      end
    end
    
    detected_theme
  end
  
  def detect_note_type(content)
    return 'personal_reflection' unless content.present?
    
    if content.include?('기도') || content.include?('간구')
      'prayer_request'
    elsif content.include?('간증') || content.include?('은혜')
      'testimony'
    elsif content.include?('오늘') || content.include?('하루')
      'daily_devotion'
    elsif content.include?('성경') || content.include?('말씀')
      'bible_study'
    else
      'personal_reflection'
    end
  end
  
  def count_korean_characters(content)
    content.scan(/[\u3131-\u3163\uac00-\ud7a3]/).length
  end
  
  def estimate_duration(content)
    korean_chars = count_korean_characters(content)
    duration = [[[korean_chars / 3.5, 60].min, 10].max].flatten.first
    duration.round(1)
  end
  
  def enhance_korean_text(content)
    # Simple enhancement - add proper punctuation and spacing
    enhanced = content.dup
    enhanced = enhanced.gsub(/([가-힣])([가-힣]{10,})([가-힣])/) { "#{$1}#{$2}#{$3}" }
    enhanced = enhanced.gsub(/\.{3,}/, '...')
    enhanced = enhanced.strip
    enhanced
  end
  
  def test_sample_inputs
    samples = [
      {
        title: "기도 제목 테스트",
        content: "하나님께 간구합니다. 오늘 하루도 주님의 은혜가 함께하시기를 기도드립니다. 어려운 상황에서도 주님을 의지하며 평안을 얻겠습니다."
      },
      {
        title: "찬양 묵상 테스트", 
        content: "주님께 찬양과 경배를 드립니다. 할렐루야! 하나님의 영광이 온 땅에 충만하시기를 소망합니다. 찬송으로 주님을 높여드립니다."
      },
      {
        title: "저녁 경건 테스트",
        content: "저녁이 되어 하루를 마감하며 하나님께 감사드립니다. 오늘 하루 베풀어주신 은혜에 감사하며, 내일도 주님과 함께 걸어가겠습니다."
      },
      {
        title: "성경 묵상 테스트",
        content: "오늘 읽은 성경 말씀을 통해 하나님의 사랑을 깨달았습니다. 십자가의 구원과 믿음의 중요성을 다시 한번 생각해봅니다."
      },
      {
        title: "간증 테스트",
        content: "하나님의 은혜를 간증합니다. 어려운 시기에 주님께서 함께하셨고, 놀라운 방법으로 도우셨습니다. 모든 영광을 하나님께 돌립니다."
      }
    ]
    
    puts "=== 텍스트 노트 AI 분석 테스트 ==="
    puts
    
    samples.each_with_index do |sample, index|
      puts "#{index + 1}. #{sample[:title]}"
      puts "내용: #{sample[:content]}"
      
      detected_theme = detect_theme_from_content(sample[:content])
      detected_type = detect_note_type(sample[:content])
      korean_chars = count_korean_characters(sample[:content])
      duration = estimate_duration(sample[:content])
      enhanced = enhance_korean_text(sample[:content])
      
      puts "✓ 감지된 테마: #{get_theme_display(detected_theme)}"
      puts "✓ 노트 유형: #{get_note_type_display(detected_type)}"
      puts "✓ 한국어 글자수: #{korean_chars}자"
      puts "✓ 예상 영상 길이: #{duration}초"
      puts "✓ 텍스트 향상: #{enhanced != sample[:content] ? '적용됨' : '미적용'}"
      puts "---"
      puts
    end
    
    puts "=== 테스트 완료 ==="
  end
  
  private
  
  def get_theme_display(theme)
    themes = {
      'golden_light' => '🌟 찬양과 경배',
      'peaceful_blue' => '🕯️ 기도와 묵상',
      'sunset_worship' => '🌅 저녁 경건',
      'cross_pattern' => '✝️ 성경과 믿음',
      'mountain_majesty' => '⛰️ 힘과 인내',
      'flowing_river' => '🌊 새로운 생명'
    }
    themes[theme] || theme
  end
  
  def get_note_type_display(type)
    types = {
      'personal_reflection' => '💭 개인 묵상',
      'prayer_request' => '🙏 기도 제목',
      'bible_study' => '📖 성경 공부',
      'daily_devotion' => '🌅 일일 경건',
      'testimony' => '✨ 간증',
      'sermon_note' => '📝 설교 노트'
    }
    types[type] || type
  end
end

# Add presence method for string testing
class String
  def present?
    !self.nil? && !self.empty?
  end
end

class NilClass
  def present?
    false
  end
end

# Run the test
tester = TextNoteTest.new
tester.test_sample_inputs