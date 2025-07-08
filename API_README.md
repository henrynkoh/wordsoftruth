# Words of Truth API Documentation

## 🎯 개요

Words of Truth API는 한국어 영적 콘텐츠를 AI 기반으로 YouTube Shorts 비디오로 변환하는 완전 자동화된 플랫폼입니다.

### 주요 기능
- **텍스트 노트 관리**: 개인 묵상, 기도 제목, 성경 공부 등 다양한 영적 콘텐츠 관리
- **AI 비디오 생성**: 텍스트를 7-12배 최적화된 속도로 비디오 변환 (평균 60초)
- **YouTube 자동 업로드**: 생성된 비디오를 YouTube Shorts로 자동 업로드
- **실시간 진행 추적**: 모든 작업의 실시간 진행 상태 모니터링
- **일괄 처리**: 여러 설교 URL을 동시에 처리하는 배치 시스템

## 🚀 시작하기

### 기본 정보
- **베이스 URL**: `http://localhost:3000/api/v1`
- **인증**: 현재 버전은 인증 불필요 (추후 API 키 필요)
- **응답 형식**: JSON
- **언어**: 한국어 (Korean)

### 빠른 테스트
```bash
# API 문서 확인
curl http://localhost:3000/api/v1/docs

# 시스템 상태 확인
curl http://localhost:3000/api/v1/system/health

# 텍스트 노트 목록 조회
curl http://localhost:3000/api/v1/text_notes
```

## 📚 API 엔드포인트

### 1. 텍스트 노트 관리

#### 텍스트 노트 목록 조회
```
GET /api/v1/text_notes
```

**쿼리 파라미터:**
- `page`: 페이지 번호 (기본값: 1)
- `per_page`: 페이지당 항목 수 (기본값: 20, 최대: 100)
- `note_type`: 노트 타입 필터
- `theme`: 테마 필터
- `status`: 상태 필터
- `search`: 검색어

**응답 예시:**
```json
{
  "success": true,
  "message": "성공",
  "data": {
    "text_notes": [
      {
        "id": 1,
        "title": "오늘의 묵상",
        "note_type": "personal_reflection",
        "theme": "peaceful_blue",
        "status": "completed",
        "created_at": "2024-01-01T09:00:00Z"
      }
    ],
    "pagination": {
      "current_page": 1,
      "per_page": 20,
      "total_count": 1,
      "total_pages": 1
    }
  }
}
```

#### 새 텍스트 노트 생성
```
POST /api/v1/text_notes
```

**요청 본문:**
```json
{
  "text_note": {
    "title": "아침 경건시간",
    "content": "시편 23편을 묵상하며...",
    "note_type": "daily_devotion",
    "theme": "peaceful_blue",
    "estimated_duration": 45
  }
}
```

**노트 타입:**
- `personal_reflection`: 개인 묵상
- `prayer_request`: 기도 제목
- `bible_study`: 성경 공부
- `daily_devotion`: 일일 경건
- `testimony`: 간증
- `sermon_note`: 설교 노트

**테마:**
- `golden_light`: 찬양과 경배
- `peaceful_blue`: 기도와 묵상
- `sunset_worship`: 저녁 경건시간
- `cross_pattern`: 성경과 믿음
- `mountain_majesty`: 힘과 인내
- `flowing_river`: 새로운 생명
- `wheat_field`: 풍성한 축복
- `shepherd_field`: 인도하심
- `temple_light`: 예배와 경배
- `city_lights`: 전도와 선교

#### 비디오 생성
```
POST /api/v1/text_notes/:id/generate_video
```

비동기로 비디오 생성을 시작합니다. 평균 처리 시간: 60-120초

#### YouTube 업로드
```
POST /api/v1/text_notes/:id/upload_to_youtube
```

생성된 비디오를 YouTube에 업로드합니다. YouTube API 토큰이 설정되어 있어야 합니다.

#### 진행 상태 확인
```
GET /api/v1/text_notes/:id/progress
```

특정 텍스트 노트의 비디오 생성 및 업로드 진행 상태를 확인합니다.

### 2. 비디오 생성 관리

#### 비디오 생성 시작
```
POST /api/v1/videos/generate
```

**요청 본문:**
```json
{
  "text_note_id": 1
}
```

#### 비디오 생성 상태 확인
```
GET /api/v1/videos/status?text_note_id=1
```

#### 비디오 다운로드
```
GET /api/v1/videos/download?text_note_id=1
```

생성된 MP4 비디오 파일을 다운로드합니다.

### 3. YouTube 업로드 관리

#### YouTube 업로드
```
POST /api/v1/youtube/upload
```

**요청 본문:**
```json
{
  "text_note_id": 1
}
```

#### 일괄 YouTube 업로드
```
POST /api/v1/youtube/bulk_upload
```

**요청 본문:**
```json
{
  "text_note_ids": [1, 2, 3]
}
```

최대 5개까지 동시 업로드 가능, 30초 간격으로 처리

#### YouTube OAuth 인증 URL 생성
```
GET /api/v1/youtube/auth_url
```

YouTube API 초기 설정을 위한 OAuth 인증 URL을 생성합니다.

#### OAuth 코드 교환
```
POST /api/v1/youtube/exchange_code
```

OAuth 인증 코드를 액세스 토큰으로 교환합니다.

### 4. 진행 상태 추적

#### 특정 작업 진행 상태
```
GET /api/v1/progress/status?trackable_type=TextNote&trackable_id=1
```

#### 모든 활성 작업 진행 상태
```
GET /api/v1/progress/all_active
```

#### 진행 상태 삭제
```
DELETE /api/v1/progress/clear?trackable_type=TextNote&trackable_id=1
```

#### 진행 통계
```
GET /api/v1/progress/statistics
```

### 5. 설교 일괄 처리

#### 설교 일괄 처리 시작
```
POST /api/v1/sermons/batch_process
```

**요청 본문:**
```json
{
  "urls": [
    "https://example-church.com/sermon/1",
    "https://example-church.com/sermon/2"
  ]
}
```

최대 20개 URL까지 동시 처리 가능

#### 일괄 처리 상태 확인
```
GET /api/v1/sermons/batch_status/:batch_id
```

#### 일괄 처리 목록
```
GET /api/v1/sermons/batches
```

### 6. 시스템 모니터링

#### 시스템 상태 확인
```
GET /api/v1/system/health
```

데이터베이스, 캐시, Sidekiq, 파일 시스템, Python 스크립트, YouTube API 상태를 확인합니다.

#### 성능 지표
```
GET /api/v1/system/performance
```

메모리 사용량, 디스크 사용량, 데이터베이스 성능 등을 확인합니다.

#### 큐 상태
```
GET /api/v1/system/queues
```

Sidekiq 작업 큐의 상태를 확인합니다.

#### 시스템 통계
```
GET /api/v1/system/statistics
```

전체 시스템의 사용 통계를 확인합니다.

## 🔄 워크플로우 예시

### 완전 자동화 워크플로우

1. **텍스트 노트 생성**
```bash
curl -X POST http://localhost:3000/api/v1/text_notes \
  -H "Content-Type: application/json" \
  -d '{
    "text_note": {
      "title": "오늘의 묵상",
      "content": "하나님의 사랑에 대한 깊은 묵상...",
      "note_type": "personal_reflection",
      "theme": "peaceful_blue"
    }
  }'
```

2. **비디오 생성 시작**
```bash
curl -X POST http://localhost:3000/api/v1/videos/generate \
  -H "Content-Type: application/json" \
  -d '{"text_note_id": 1}'
```

3. **진행 상태 모니터링** (반복 폴링)
```bash
curl http://localhost:3000/api/v1/videos/status?text_note_id=1
```

4. **완료 후 YouTube 업로드**
```bash
curl -X POST http://localhost:3000/api/v1/youtube/upload \
  -H "Content-Type: application/json" \
  -d '{"text_note_id": 1}'
```

5. **업로드 상태 확인**
```bash
curl http://localhost:3000/api/v1/youtube/status?text_note_id=1
```

## 📊 응답 형식

### 성공 응답
```json
{
  "success": true,
  "message": "성공 메시지",
  "data": {
    // 실제 데이터
  },
  "timestamp": "2024-01-01T09:00:00Z"
}
```

### 오류 응답
```json
{
  "success": false,
  "message": "오류 메시지",
  "details": ["상세 오류 정보"],
  "timestamp": "2024-01-01T09:00:00Z"
}
```

### HTTP 상태 코드
- `200`: 성공
- `201`: 리소스 생성됨
- `400`: 잘못된 요청
- `404`: 리소스를 찾을 수 없음
- `409`: 충돌 (이미 존재하거나 처리 중)
- `412`: 전제 조건 실패
- `422`: 처리할 수 없는 엔티티
- `500`: 서버 내부 오류
- `503`: 서비스 이용 불가

## 🚦 제한사항

### 처리량 제한
- **일반 요청**: 분당 100회
- **비디오 생성**: 시간당 10회
- **YouTube 업로드**: 일일 5회 (YouTube API 제한)
- **일괄 처리**: 일일 3회

### 파일 크기 제한
- **텍스트 노트**: 최대 5,000자
- **비디오 파일**: 최대 100MB
- **일괄 처리**: 최대 20개 URL

## 🧪 테스트

API 테스트 스크립트를 실행하여 모든 엔드포인트를 테스트할 수 있습니다:

```bash
ruby scripts/api_test.rb
```

또는 특정 서버에 대해:

```bash
ruby scripts/api_test.rb http://your-server.com
```

## 📖 OpenAPI 문서

표준 OpenAPI 3.0 사양은 다음에서 확인할 수 있습니다:

```
GET /api/v1/openapi
```

## 🔧 설정

### YouTube API 설정

YouTube 업로드 기능을 사용하려면 다음 환경 변수를 설정해야 합니다:

```bash
export GOOGLE_CLIENT_ID="your_google_client_id"
export GOOGLE_CLIENT_SECRET="your_google_client_secret"
export YOUTUBE_ACCESS_TOKEN="your_youtube_access_token"
export YOUTUBE_REFRESH_TOKEN="your_youtube_refresh_token"
```

### 토큰 획득 방법

1. **OAuth URL 생성**:
```bash
curl http://localhost:3000/api/v1/youtube/auth_url
```

2. **브라우저에서 인증 완료 후 코드 교환**:
```bash
curl -X POST http://localhost:3000/api/v1/youtube/exchange_code \
  -H "Content-Type: application/json" \
  -d '{
    "code": "authorization_code_from_google",
    "redirect_uri": "your_redirect_uri"
  }'
```

## 🔍 모니터링

### 시스템 상태 모니터링

정기적으로 시스템 상태를 확인하여 서비스 안정성을 보장합니다:

```bash
# 전체 시스템 상태
curl http://localhost:3000/api/v1/system/health

# 성능 지표
curl http://localhost:3000/api/v1/system/performance

# 활성 작업 상태
curl http://localhost:3000/api/v1/progress/all_active
```

## 📞 지원

- **문제 보고**: GitHub Issues
- **API 문서**: `/api/v1/docs`
- **시스템 상태**: `/api/v1/system/health`

## 🔄 버전 정보

- **현재 버전**: v1.0.0
- **API 버전**: v1
- **마지막 업데이트**: 2024년 1월

---

*이 문서는 Words of Truth API v1을 위한 공식 문서입니다. 문의사항이나 개선 제안이 있으시면 언제든 연락주세요.*