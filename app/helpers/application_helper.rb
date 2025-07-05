# frozen_string_literal: true

module ApplicationHelper
  # Text Note helper methods
  def get_theme_display(theme)
    case theme.to_s
    when 'golden_light'
      '🌟 찬양과 경배'
    when 'peaceful_blue'
      '🕯️ 기도와 묵상'
    when 'sunset_worship'
      '🌅 저녁 경건'
    when 'cross_pattern'
      '✝️ 성경과 믿음'
    when 'mountain_majesty'
      '⛰️ 힘과 인내'
    when 'flowing_river'
      '🌊 새로운 생명'
    when 'wheat_field'
      '🌾 풍성한 축복'
    when 'shepherd_field'
      '🐑 인도하심'
    when 'temple_light'
      '🏛️ 거룩한 성전'
    when 'city_lights'
      '🌃 세상의 빛'
    when 'auto_detect'
      '🤖 AI 자동 선택'
    else
      theme.to_s.humanize
    end
  end

  def get_theme_emoji(theme)
    case theme.to_s
    when 'golden_light' then '🌟'
    when 'peaceful_blue' then '🕯️'
    when 'sunset_worship' then '🌅'
    when 'cross_pattern' then '✝️'
    when 'mountain_majesty' then '⛰️'
    when 'flowing_river' then '🌊'
    when 'wheat_field' then '🌾'
    when 'shepherd_field' then '🐑'
    when 'temple_light' then '🏛️'
    when 'city_lights' then '🌃'
    when 'auto_detect' then '🤖'
    else '🎨'
    end
  end

  def get_note_type_display(note_type)
    case note_type.to_s
    when 'personal_reflection'
      '개인 묵상'
    when 'prayer_request'
      '기도 제목'
    when 'bible_study'
      '성경 공부'
    when 'daily_devotion'
      '일일 경건'
    when 'testimony'
      '간증'
    when 'sermon_note'
      '설교 노트'
    else
      note_type.to_s.humanize
    end
  end

  def get_note_type_emoji(note_type)
    case note_type.to_s
    when 'personal_reflection' then '💭'
    when 'prayer_request' then '🙏'
    when 'bible_study' then '📖'
    when 'daily_devotion' then '🌅'
    when 'testimony' then '✨'
    when 'sermon_note' then '📝'
    else '📄'
    end
  end

  def get_status_display(status)
    case status.to_s
    when 'draft'
      '📝 초안'
    when 'processing'
      '⚙️ 처리 중'
    when 'completed'
      '✅ 완료'
    when 'failed'
      '❌ 실패'
    else
      status.to_s.humanize
    end
  end
end
