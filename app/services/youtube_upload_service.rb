require 'net/http'
require 'json'
require 'uri'

class YoutubeUploadService
  
  def initialize
    @api_key = ENV['YOUTUBE_API_KEY'] || Rails.application.credentials.dig(:youtube, :api_key)
    @client_id = ENV['GOOGLE_CLIENT_ID'] || Rails.application.credentials.dig(:google, :client_id)
    @client_secret = ENV['GOOGLE_CLIENT_SECRET'] || Rails.application.credentials.dig(:google, :client_secret)
    @access_token = ENV['YOUTUBE_ACCESS_TOKEN']
    @refresh_token = ENV['YOUTUBE_REFRESH_TOKEN']
  end

  def upload_shorts_video(video_file_path, video_metadata = {})
    begin
      Rails.logger.info "Starting YouTube Shorts upload: #{video_file_path}"
      
      # Check if file exists
      unless File.exist?(video_file_path)
        return {
          success: false,
          error: "비디오 파일을 찾을 수 없습니다: #{video_file_path}"
        }
      end

      # Check credentials
      unless valid_credentials?
        return {
          success: false,
          error: "YouTube API 인증 정보가 없습니다. 환경 변수를 설정해주세요.",
          auth_required: true
        }
      end

      # Refresh access token if needed
      token_result = ensure_valid_access_token
      unless token_result[:success]
        return token_result
      end

      # Prepare video metadata
      video_data = prepare_video_metadata(video_metadata)
      
      # Upload video to YouTube
      upload_result = perform_upload(video_file_path, video_data)
      
      if upload_result[:success]
        video_url = "https://www.youtube.com/watch?v=#{upload_result[:video_id]}"
        
        Rails.logger.info "YouTube upload successful: #{video_url}"
        
        return {
          success: true,
          youtube_id: upload_result[:video_id],
          youtube_url: video_url,
          message: "성공적으로 YouTube Shorts에 업로드되었습니다."
        }
      else
        return upload_result
      end
      
    rescue => e
      Rails.logger.error "YouTube upload error: #{e.message}"
      return {
        success: false,
        error: "업로드 오류: #{e.message}"
      }
    end
  end

  def upload_video_with_auto_retry(video_file_path, video_metadata = {}, max_retries = 3)
    retries = 0
    
    loop do
      begin
        result = upload_shorts_video(video_file_path, video_metadata)
        
        if result[:success]
          return result
        elsif result[:auth_required] && retries < max_retries
          Rails.logger.info "Retrying YouTube upload due to auth error (#{retries + 1}/#{max_retries})"
          retries += 1
          sleep(2)
          next
        else
          return result
        end
        
      rescue => e
        if retries < max_retries
          retries += 1
          Rails.logger.warn "YouTube upload retry #{retries}/#{max_retries}: #{e.message}"
          sleep(5)
          next
        else
          return {
            success: false,
            error: "최대 재시도 횟수 초과: #{e.message}"
          }
        end
      end
    end
  end

  private

  def valid_credentials?
    @client_id.present? && @client_secret.present? && (@access_token.present? || @refresh_token.present?)
  end

  def ensure_valid_access_token
    return { success: true } if @access_token.present?

    if @refresh_token.present?
      return refresh_access_token
    end

    {
      success: false,
      error: "액세스 토큰과 리프레시 토큰이 모두 없습니다.",
      auth_required: true
    }
  end

  def refresh_access_token
    begin
      uri = URI('https://oauth2.googleapis.com/token')
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/x-www-form-urlencoded'
      
      params = {
        'client_id' => @client_id,
        'client_secret' => @client_secret,
        'refresh_token' => @refresh_token,
        'grant_type' => 'refresh_token'
      }
      
      request.body = URI.encode_www_form(params)
      
      response = http.request(request)
      
      if response.code == '200'
        data = JSON.parse(response.body)
        @access_token = data['access_token']
        
        Rails.logger.info "Access token refreshed successfully"
        return { success: true }
      else
        Rails.logger.error "Token refresh failed: #{response.body}"
        return {
          success: false,
          error: "토큰 갱신 실패: #{response.body}",
          auth_required: true
        }
      end
      
    rescue => e
      Rails.logger.error "Token refresh error: #{e.message}"
      return {
        success: false,
        error: "토큰 갱신 오류: #{e.message}",
        auth_required: true
      }
    end
  end

  def prepare_video_metadata(metadata)
    title = metadata[:title] || "Words of Truth - 자동 생성 Shorts"
    description = build_description(metadata)
    tags = build_tags(metadata)

    {
      'snippet' => {
        'title' => title.truncate(100),
        'description' => description,
        'tags' => tags,
        'categoryId' => '22', # People & Blogs
        'defaultLanguage' => 'ko',
        'defaultAudioLanguage' => 'ko'
      },
      'status' => {
        'privacyStatus' => 'public',
        'madeForKids' => false,
        'selfDeclaredMadeForKids' => false
      }
    }
  end

  def build_description(metadata)
    description_parts = []
    
    if metadata[:scripture].present?
      description_parts << "📖 성경: #{metadata[:scripture]}"
      description_parts << ""
    end
    
    if metadata[:content].present?
      description_parts << metadata[:content].truncate(1000)
      description_parts << ""
    end
    
    if metadata[:church].present?
      description_parts << "⛪ 교회: #{metadata[:church]}"
    end
    
    if metadata[:pastor].present? && metadata[:pastor] != "YouTube 콘텐츠"
      description_parts << "👨‍💼 목사: #{metadata[:pastor]}"
    end
    
    description_parts << ""
    description_parts << "#Shorts #설교 #기독교 #성경 #한국어"
    description_parts << ""
    description_parts << "🤖 이 영상은 Words of Truth 자동화 시스템으로 생성되었습니다."
    description_parts << "원본 출처: #{metadata[:source_url]}" if metadata[:source_url].present?
    
    description_parts.join("\n").truncate(5000)
  end

  def build_tags(metadata)
    tags = %w[Shorts 설교 기독교 성경 한국어 자동화]
    
    # Add church-specific tags
    if metadata[:church].present?
      church_name = metadata[:church].gsub(/[^\w\s가-힣]/, '').strip
      tags << church_name unless church_name.blank?
    end
    
    # Add scripture-specific tags
    if metadata[:scripture].present?
      scripture_parts = metadata[:scripture].split(/[\s,]+/)
      scripture_parts.each do |part|
        clean_part = part.gsub(/[^\w가-힣]/, '').strip
        tags << clean_part if clean_part.length > 2 && clean_part.length < 20
      end
    end
    
    tags.uniq.first(10) # YouTube allows max 10 tags
  end

  def perform_upload(video_file_path, video_data)
    begin
      # Use multipart upload for video files
      boundary = "----RubyFormBoundary#{SecureRandom.hex(16)}"
      
      uri = URI('https://www.googleapis.com/upload/youtube/v3/videos?uploadType=multipart&part=snippet,status')
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 300 # 5 minutes
      
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{@access_token}"
      request['Content-Type'] = "multipart/related; boundary=#{boundary}"
      
      # Build multipart body
      body = build_multipart_body(boundary, video_data, video_file_path)
      request.body = body
      
      Rails.logger.info "Uploading video to YouTube..."
      response = http.request(request)
      
      if response.code == '200'
        data = JSON.parse(response.body)
        video_id = data['id']
        
        return {
          success: true,
          video_id: video_id
        }
      else
        Rails.logger.error "YouTube upload failed: #{response.code} - #{response.body}"
        return {
          success: false,
          error: "YouTube 업로드 실패: #{response.code} - #{response.body}"
        }
      end
      
    rescue => e
      Rails.logger.error "Upload request error: #{e.message}"
      return {
        success: false,
        error: "업로드 요청 오류: #{e.message}"
      }
    end
  end

  def build_multipart_body(boundary, video_data, video_file_path)
    body = "".force_encoding('BINARY')
    
    # Add JSON metadata part
    body << "--#{boundary}\r\n".force_encoding('BINARY')
    body << "Content-Type: application/json; charset=UTF-8\r\n".force_encoding('BINARY')
    body << "\r\n".force_encoding('BINARY')
    body << video_data.to_json.force_encoding('BINARY')
    body << "\r\n".force_encoding('BINARY')
    
    # Add video file part
    body << "--#{boundary}\r\n".force_encoding('BINARY')
    body << "Content-Type: video/mp4\r\n".force_encoding('BINARY')
    body << "\r\n".force_encoding('BINARY')
    body << File.binread(video_file_path)
    body << "\r\n".force_encoding('BINARY')
    body << "--#{boundary}--\r\n".force_encoding('BINARY')
    
    body
  end

  # Class method for easy access
  def self.upload_shorts(video_file_path, video_metadata = {})
    service = new
    service.upload_video_with_auto_retry(video_file_path, video_metadata)
  end
end