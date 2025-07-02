# YouTube 자동 업로드 설정 가이드

## 🔧 환경 변수 설정

YouTube API를 통한 자동 업로드를 위해 다음 환경 변수들을 설정해야 합니다:

### 1. Google Cloud Console 설정

1. **Google Cloud Console** 방문: https://console.cloud.google.com/
2. **새 프로젝트 생성** 또는 기존 프로젝트 선택
3. **YouTube Data API v3** 활성화:
   - API 및 서비스 → 라이브러리
   - "YouTube Data API v3" 검색 후 활성화

### 2. OAuth 2.0 클라이언트 설정

1. **사용자 인증 정보** → **사용자 인증 정보 만들기** → **OAuth 클라이언트 ID**
2. **애플리케이션 유형**: 웹 애플리케이션
3. **승인된 리디렉션 URI**: `http://localhost:3000/auth/callback`
4. **클라이언트 ID**와 **클라이언트 보안 비밀**을 복사

### 3. 환경 변수 설정

`.env` 파일을 생성하고 다음 내용을 추가하세요:

```bash
# Google OAuth 설정
GOOGLE_CLIENT_ID=your_google_client_id_here
GOOGLE_CLIENT_SECRET=your_google_client_secret_here

# YouTube API 키 (선택사항)
YOUTUBE_API_KEY=your_youtube_api_key_here

# OAuth 토큰 (초기 설정 후 자동으로 생성됨)
YOUTUBE_ACCESS_TOKEN=
YOUTUBE_REFRESH_TOKEN=
```

### 4. 기존 API 키 사용

이미 제공해주신 API 정보를 사용하려면:

```bash
# 제공해주신 정보 사용
YOUTUBE_API_KEY=AIzaSyBNpH5KRQKvqV2qm4P3qwQL2hSc_PvuVuQ
GOOGLE_CLIENT_ID=YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=YOUR_GOOGLE_CLIENT_SECRET
```

## 🔐 OAuth 인증 프로세스

### 1. 자동 인증 URL 생성

Rails 콘솔에서 다음 명령을 실행하세요:

```bash
rails runner "
require 'google/auth'
require 'google/auth/stores/file_token_store'

client_id = Google::Auth::ClientId.new(
  ENV['GOOGLE_CLIENT_ID'], 
  ENV['GOOGLE_CLIENT_SECRET']
)

scope = 'https://www.googleapis.com/auth/youtube.upload'
token_store = Google::Auth::Stores::FileTokenStore.new(file: 'tmp/youtube_tokens.yaml')
authorizer = Google::Auth::UserAuthorizer.new(client_id, scope, token_store)

puts '다음 URL을 방문하여 인증하세요:'
puts authorizer.get_authorization_url(base_url: 'urn:ietf:wg:oauth:2.0:oob')
"
```

### 2. 인증 코드 입력

생성된 URL을 방문하여 Google 계정으로 로그인하고, 권한을 부여한 후 받은 코드를 다음 명령으로 입력하세요:

```bash
rails runner "
# 위에서 받은 인증 코드를 입력하세요
auth_code = 'YOUR_AUTHORIZATION_CODE_HERE'

require 'google/auth'
require 'google/auth/stores/file_token_store'

client_id = Google::Auth::ClientId.new(
  ENV['GOOGLE_CLIENT_ID'], 
  ENV['GOOGLE_CLIENT_SECRET']
)

scope = 'https://www.googleapis.com/auth/youtube.upload'
token_store = Google::Auth::Stores::FileTokenStore.new(file: 'tmp/youtube_tokens.yaml')
authorizer = Google::Auth::UserAuthorizer.new(client_id, scope, token_store)

credentials = authorizer.get_and_store_credentials_from_code(
  user_id: 'default',
  code: auth_code,
  base_url: 'urn:ietf:wg:oauth:2.0:oob'
)

puts 'YouTube 인증이 완료되었습니다!'
puts '액세스 토큰: ' + credentials.access_token if credentials.access_token
puts '리프레시 토큰: ' + credentials.refresh_token if credentials.refresh_token
"
```

### 3. 환경 변수 업데이트

받은 토큰들을 `.env` 파일에 추가하세요:

```bash
YOUTUBE_ACCESS_TOKEN=received_access_token
YOUTUBE_REFRESH_TOKEN=received_refresh_token
```

## 🚀 테스트 방법

### 1. 인증 테스트

```bash
rails runner "
service = YoutubeUploadService.new
puts service.send(:valid_credentials?) ? '✅ 인증 성공' : '❌ 인증 실패'
"
```

### 2. 업로드 테스트

```bash
rails runner "
# 기존 생성된 비디오로 테스트
video_path = 'storage/generated_videos/direct_video_1751257224.mp4'

if File.exist?(video_path)
  result = YoutubeUploadService.upload_shorts(video_path, {
    title: '테스트 YouTube Shorts',
    content: '자동화 시스템 테스트 영상입니다.',
    church: 'Words of Truth'
  })
  
  if result[:success]
    puts '✅ 업로드 성공!'
    puts '📺 YouTube URL: ' + result[:youtube_url]
  else
    puts '❌ 업로드 실패: ' + result[:error]
  end
else
  puts '❌ 테스트 비디오 파일이 없습니다.'
end
"
```

## 🔧 문제 해결

### 자주 발생하는 오류

1. **인증 오류**: 
   - 환경 변수가 올바르게 설정되었는지 확인
   - OAuth 토큰이 만료되었다면 리프레시 토큰으로 갱신

2. **업로드 실패**: 
   - 비디오 파일이 존재하는지 확인
   - 파일 크기가 YouTube 제한을 초과하지 않는지 확인

3. **API 제한**: 
   - YouTube API 할당량 확인
   - 요청 빈도 제한 준수

## 📱 YouTube Studio 확인

업로드된 Shorts는 다음 위치에서 확인할 수 있습니다:

- **YouTube Studio**: https://studio.youtube.com/channel/UCdYIuVDuZsRd-G2jkGBxB4w/videos/short
- **채널 Shorts**: https://www.youtube.com/@your-channel-name/shorts

## 🔄 자동화 완료!

모든 설정이 완료되면 YouTube 자동화 시스템이 다음과 같이 작동합니다:

1. **URL 입력** → **콘텐츠 추출** → **비디오 생성** → **YouTube 자동 업로드**
2. **실시간 진행 상황 추적**
3. **업로드 완료 시 YouTube URL 제공**

🎉 이제 YouTube Shorts가 완전 자동으로 업로드됩니다!