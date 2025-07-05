class TextNotesController < ApplicationController
  before_action :set_text_note, only: [:show, :edit, :update, :destroy, :generate_video, :upload_to_youtube]
  
  def index
    @text_notes = TextNote.recent
    @text_notes = @text_notes.by_theme(params[:theme]) if params[:theme].present?
    @text_notes = @text_notes.where(status: params[:status]) if params[:status].present?
    @text_notes = @text_notes.limit(20)
    
    @theme_counts = TextNote.group(:theme).count
    @status_counts = TextNote.group(:status).count
  end
  
  def show
    @video_ready = @text_note.completed? && @text_note.video_file_path.present?
    @youtube_ready = @text_note.youtube_video_id.present?
  end
  
  def new
    @text_note = TextNote.new
    @text_note.theme = params[:theme] if params[:theme].present?
    @text_note.note_type = params[:note_type] if params[:note_type].present?
  end
  
  def create
    @text_note = TextNote.new(text_note_params)
    
    if @text_note.save
      # Process video generation in background
      TextNoteVideoJob.perform_later(@text_note.id)
      
      redirect_to @text_note, notice: '📝 텍스트 노트가 저장되었습니다. 영상 생성이 시작됩니다.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @text_note.update(text_note_params)
      # Re-process if content changed
      if @text_note.saved_change_to_content?
        @text_note.update(status: :draft)
        TextNoteVideoJob.perform_later(@text_note.id)
      end
      
      redirect_to @text_note, notice: '📝 텍스트 노트가 업데이트되었습니다.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    # Clean up video file if exists
    if @text_note.video_file_path.present? && File.exist?(@text_note.video_file_path)
      File.delete(@text_note.video_file_path)
    end
    
    @text_note.destroy
    redirect_to text_notes_path, notice: '📝 텍스트 노트가 삭제되었습니다.'
  end
  
  def generate_video
    if @text_note.completed?
      redirect_to @text_note, alert: '이미 영상이 생성되었습니다.'
      return
    end
    
    @text_note.update(status: :processing)
    TextNoteVideoJob.perform_later(@text_note.id)
    
    redirect_to @text_note, notice: '🎬 영상 생성이 시작되었습니다.'
  end
  
  def upload_to_youtube
    unless @text_note.completed? && @text_note.video_file_path.present?
      redirect_to @text_note, alert: '영상을 먼저 생성해야 합니다.'
      return
    end
    
    if @text_note.youtube_video_id.present?
      redirect_to @text_note, alert: '이미 YouTube에 업로드되었습니다.'
      return
    end
    
    YoutubeTextNoteUploadJob.perform_later(@text_note.id)
    redirect_to @text_note, notice: '📺 YouTube 업로드가 시작되었습니다.'
  end
  
  def quick_create
    # API endpoint for mobile quick creation
    @text_note = TextNote.new(
      content: params[:content],
      note_type: params[:note_type] || 'personal_reflection',
      theme: 'auto_detect'
    )
    
    if @text_note.save
      TextNoteVideoJob.perform_later(@text_note.id)
      
      render json: {
        success: true,
        text_note_id: @text_note.id,
        estimated_duration: @text_note.estimated_duration,
        detected_theme: @text_note.theme,
        message: '영상 생성이 시작되었습니다.'
      }
    else
      render json: {
        success: false,
        errors: @text_note.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
  
  def templates
    # Provide template suggestions for different note types
    @templates = {
      personal_reflection: [
        "오늘 하루를 돌아보며 주님께 감사드립니다...",
        "하나님의 말씀을 묵상하며...",
        "주님과의 시간을 통해 깨달은 것은..."
      ],
      prayer_request: [
        "하나님께 간구합니다...",
        "이 일을 위해 기도합니다...",
        "주님의 도움이 필요합니다..."
      ],
      daily_devotion: [
        "오늘 아침, 주님께서 주신 새로운 하루...",
        "저녁이 되어 하루를 마감하며...",
        "오늘 하루 주님과 함께 걸으며..."
      ],
      bible_study: [
        "오늘 읽은 성경 말씀은...",
        "이 구절을 통해 하나님께서 말씀하시는 것은...",
        "말씀을 묵상하며 깨달은 것은..."
      ],
      testimony: [
        "하나님의 은혜를 간증합니다...",
        "주님께서 행하신 놀라운 일...",
        "믿음을 통해 경험한 하나님의 사랑..."
      ]
    }
    
    render json: @templates
  end
  
  def theme_suggestions
    content = params[:content]
    return render json: { theme: 'golden_light' } unless content.present?
    
    # Simple theme detection for API
    theme = detect_theme_from_content(content)
    
    render json: { 
      theme: theme,
      confidence: calculate_theme_confidence(content, theme),
      alternative_themes: suggest_alternative_themes(content)
    }
  end
  
  private
  
  def set_text_note
    @text_note = TextNote.find(params[:id])
  end
  
  def text_note_params
    params.require(:text_note).permit(:title, :content, :theme, :note_type)
  end
  
  def detect_theme_from_content(content)
    return 'golden_light' unless content.present?
    
    # Theme detection logic (simplified)
    if content.match?(/찬양|경배|할렐루야|영광/)
      'golden_light'
    elsif content.match?(/기도|묵상|평안|고요/)
      'peaceful_blue'
    elsif content.match?(/저녁|감사|하루|마감/)
      'sunset_worship'
    elsif content.match?(/십자가|믿음|구원|성경/)
      'cross_pattern'
    elsif content.match?(/힘|인내|산|견디/)
      'mountain_majesty'
    elsif content.match?(/새로운|생명|세례|거듭/)
      'flowing_river'
    elsif content.match?(/축복|풍성|감사|추수/)
      'wheat_field'
    elsif content.match?(/인도|목자|보호|양/)
      'shepherd_field'
    elsif content.match?(/예배|성전|거룩|경배/)
      'temple_light'
    elsif content.match?(/전도|선교|빛|증거/)
      'city_lights'
    else
      'golden_light'
    end
  end
  
  def calculate_theme_confidence(content, theme)
    # Simple confidence calculation
    keyword_matches = 0
    total_keywords = 0
    
    theme_keywords = {
      'golden_light' => %w[찬양 경배 할렐루야 영광 찬송],
      'peaceful_blue' => %w[기도 묵상 평안 고요 조용],
      'sunset_worship' => %w[저녁 감사 하루 마감 소망],
      'cross_pattern' => %w[십자가 믿음 구원 성경 말씀],
      'mountain_majesty' => %w[힘 인내 산 견디 강함],
      'flowing_river' => %w[새로운 생명 세례 거듭 새롭],
      'wheat_field' => %w[축복 풍성 감사 추수 열매],
      'shepherd_field' => %w[인도 목자 보호 양 이끌],
      'temple_light' => %w[예배 성전 거룩 경배 예배],
      'city_lights' => %w[전도 선교 빛 증거 복음]
    }
    
    keywords = theme_keywords[theme] || []
    total_keywords = keywords.length
    keyword_matches = keywords.count { |keyword| content.include?(keyword) }
    
    return 0.5 if total_keywords == 0
    [keyword_matches.to_f / total_keywords, 1.0].min
  end
  
  def suggest_alternative_themes(content)
    themes = %w[golden_light peaceful_blue sunset_worship cross_pattern]
    themes.map do |theme|
      {
        theme: theme,
        confidence: calculate_theme_confidence(content, theme)
      }
    end.sort_by { |t| -t[:confidence] }.first(3)
  end
end