# Words of Truth API Documentation

## Overview

The Words of Truth API provides comprehensive endpoints for managing sermons, videos, business activity monitoring, and compliance reporting. This documentation covers all public and administrative endpoints.

## Base URL

```
Production: https://wordsoftruth.com/api
Development: http://localhost:3000/api
```

## Authentication

All API endpoints require authentication. The system supports multiple authentication methods:

- **Session-based**: Web application sessions
- **Token-based**: API tokens for programmatic access
- **Admin access**: Enhanced permissions for administrative endpoints

### Headers

```http
Content-Type: application/json
Accept: application/json
Authorization: Bearer <token>  # For token-based auth
X-API-Version: v1
```

## Core Business Endpoints

### Sermons API

#### GET /api/sermons
List all sermons with filtering and pagination.

**Parameters:**
- `page` (integer): Page number (default: 1)
- `per_page` (integer): Records per page (default: 25, max: 100)
- `church` (string): Filter by church name
- `pastor` (string): Filter by pastor name
- `denomination` (string): Filter by denomination
- `search` (string): Full-text search across title, scripture, interpretation
- `date_from` (date): Start date filter (YYYY-MM-DD)
- `date_to` (date): End date filter (YYYY-MM-DD)

**Response:**
```json
{
  "sermons": [
    {
      "id": 123,
      "title": "Faith in Action",
      "church": "Grace Community Church",
      "pastor": "Pastor John Smith",
      "denomination": "Baptist",
      "scripture": "James 2:14-26",
      "sermon_date": "2024-06-15",
      "interpretation": "This sermon explores the relationship between faith and works...",
      "action_points": "1. Volunteer at local food bank\n2. Practice daily prayer",
      "audience_count": 150,
      "created_at": "2024-06-15T10:30:00Z",
      "updated_at": "2024-06-15T10:30:00Z",
      "videos": [
        {
          "id": 456,
          "status": "uploaded",
          "youtube_id": "dQw4w9WgXcQ",
          "youtube_url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        }
      ]
    }
  ],
  "meta": {
    "current_page": 1,
    "per_page": 25,
    "total_pages": 5,
    "total_count": 120
  }
}
```

#### POST /api/sermons
Create a new sermon.

**Request Body:**
```json
{
  "sermon": {
    "title": "Faith in Action",
    "source_url": "https://example.com/sermon-123",
    "church": "Grace Community Church",
    "pastor": "Pastor John Smith",
    "denomination": "Baptist",
    "scripture": "James 2:14-26",
    "sermon_date": "2024-06-15",
    "interpretation": "This sermon explores...",
    "action_points": "1. Volunteer at local food bank",
    "audience_count": 150
  }
}
```

**Response:** Returns created sermon object with status 201.

#### GET /api/sermons/:id
Retrieve a specific sermon.

#### PUT /api/sermons/:id
Update a sermon (requires appropriate permissions).

#### DELETE /api/sermons/:id
Delete a sermon (admin only).

### Videos API

#### GET /api/videos
List all videos with filtering.

**Parameters:**
- `status` (string): Filter by status (pending, approved, processing, uploaded, failed)
- `sermon_id` (integer): Filter by sermon ID
- `page`, `per_page`: Pagination parameters

**Response:**
```json
{
  "videos": [
    {
      "id": 456,
      "sermon_id": 123,
      "status": "uploaded",
      "script": "Welcome to today's sermon on Faith in Action...",
      "youtube_id": "dQw4w9WgXcQ",
      "youtube_url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
      "youtube_embed_url": "https://www.youtube.com/embed/dQw4w9WgXcQ",
      "video_path": "/storage/videos/video_123.mp4",
      "thumbnail_path": "/storage/thumbnails/thumb_123.jpg",
      "file_size": "125.5 MB",
      "processing_time": 1800,
      "created_at": "2024-06-15T11:00:00Z",
      "updated_at": "2024-06-15T12:30:00Z",
      "sermon": {
        "id": 123,
        "title": "Faith in Action",
        "church": "Grace Community Church"
      }
    }
  ]
}
```

#### POST /api/videos
Create a new video for processing.

**Request Body:**
```json
{
  "video": {
    "sermon_id": 123,
    "script": "Welcome to today's sermon...",
    "processing_priority": "medium"
  }
}
```

#### PUT /api/videos/:id/approve
Approve a video for processing (admin only).

#### PUT /api/videos/:id/reject
Reject a video with reason (admin only).

**Request Body:**
```json
{
  "reason": "Inappropriate content detected"
}
```

#### PUT /api/videos/:id/start_processing
Begin video processing (system endpoint).

#### PUT /api/videos/:id/complete_upload
Mark video as uploaded with YouTube ID.

**Request Body:**
```json
{
  "youtube_id": "dQw4w9WgXcQ"
}
```

## Business Activity Monitoring API

### GET /api/monitoring/dashboard
Retrieve comprehensive dashboard data.

**Parameters:**
- `period` (string): Time period (1h, 24h, 7d, 30d) (default: 7d)
- `entity` (string): Entity filter (sermons, videos, all) (default: all)

**Response:**
```json
{
  "dashboard": {
    "system_overview": {
      "total_activities_today": 245,
      "active_users_today": 12,
      "processing_queue_status": {
        "pending_approvals": 5,
        "processing": 2,
        "failed": 1
      },
      "system_health_score": 92.5
    },
    "recent_activities": [
      {
        "id": 1001,
        "activity_type": "business_operation",
        "entity_type": "Video",
        "entity_id": 456,
        "operation_name": "video_approved",
        "user_id": "admin_123",
        "performed_at": "2024-06-15T14:30:00Z",
        "context": {
          "video_title": "Faith in Action",
          "approval_reason": "Content approved"
        }
      }
    ],
    "performance_indicators": {
      "daily_sermon_processing": 8,
      "video_success_rate": 94.2,
      "average_processing_time": 1650,
      "user_satisfaction_score": 85.0
    }
  },
  "metrics": {
    "current_active_sessions": 15,
    "processing_queue_lengths": {
      "video_processing": 3,
      "background_jobs": 8
    },
    "recent_error_rate": 1.2,
    "cache_hit_rate": 95.5,
    "database_query_performance": {
      "avg_query_time_ms": 15.2,
      "slow_queries": 2
    }
  },
  "alerts": []
}
```

### GET /api/monitoring/metrics
Retrieve detailed metrics by type.

**Parameters:**
- `type` (string): Metric type (business_operations, user_interactions, performance, security, compliance, all)
- `period` (string): Time period (1h, 24h, 7d, 30d)

### GET /api/monitoring/compliance
Generate compliance reports.

**Parameters:**
- `report_type` (string): Report type (audit_trail, data_access, retention_compliance, security_events, gdpr_compliance, summary)
- `period` (string): Time period (7d, 30d, 90d, 1y)

**Response:**
```json
{
  "report_period": "2024-05-15 to 2024-06-15",
  "audit_trail": [
    {
      "activity_id": 1001,
      "timestamp": "2024-06-15T14:30:00Z",
      "activity_type": "business_operation",
      "entity": "Video:456",
      "user": "admin_123",
      "operation": "video_approved",
      "compliance_relevant": true,
      "data_retention_category": "business_operations"
    }
  ],
  "data_access_summary": {
    "total_access_events": 1250,
    "unique_users": 25,
    "sensitive_data_access": 45,
    "export_requests": 3
  },
  "gdpr_compliance": {
    "data_subject_requests": 2,
    "data_exports": 1,
    "anonymization_activities": 0,
    "consent_management": {
      "status": "compliant",
      "consent_rate": 95.0
    }
  }
}
```

### POST /api/monitoring/export
Export business activity data.

**Request Body:**
```json
{
  "format": "json",  // json, csv, xlsx
  "period": "7d",
  "activity_types": ["business_operation", "user_interaction"]
}
```

### GET /api/monitoring/activity_stream
Real-time activity stream.

**Parameters:**
- `limit` (integer): Number of activities (max: 500)
- `types` (string): Comma-separated activity types

### GET /api/monitoring/health
System health and performance overview.

**Response:**
```json
{
  "database_performance": {
    "status": "healthy",
    "avg_response_time": "12ms"
  },
  "application_performance": {
    "status": "healthy",
    "avg_response_time": "150ms"
  },
  "background_job_status": {
    "status": "healthy",
    "queue_size": 5,
    "failed_jobs": 0
  },
  "cache_performance": {
    "status": "healthy",
    "hit_rate": "95%"
  },
  "error_rates": {
    "application_errors": "0.1%",
    "database_errors": "0.05%"
  },
  "resource_utilization": {
    "cpu": "45%",
    "memory": "60%",
    "disk": "30%"
  }
}
```

## Search and Analytics API

### GET /api/search
Unified search across sermons and videos.

**Parameters:**
- `q` (string): Search query
- `type` (string): Search type (sermons, videos, all)
- `filters` (object): Additional filters

**Response:**
```json
{
  "results": {
    "sermons": [
      {
        "id": 123,
        "title": "Faith in Action",
        "relevance_score": 0.95,
        "highlight": "This sermon explores the relationship between <em>faith</em> and works"
      }
    ],
    "videos": [],
    "total_results": 15,
    "search_time_ms": 25
  }
}
```

## Background Jobs API

### GET /api/jobs/status
Check background job processing status.

### POST /api/jobs/video_processing
Queue video for processing.

### POST /api/jobs/bulk_sermon_processing
Queue bulk sermon processing.

## Error Responses

All error responses follow this format:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "details": {
      "title": ["can't be blank"],
      "church": ["is too short (minimum is 2 characters)"]
    },
    "timestamp": "2024-06-15T14:30:00Z",
    "request_id": "req_123456"
  }
}
```

### Common HTTP Status Codes

- `200 OK`: Successful GET request
- `201 Created`: Successful POST request
- `204 No Content`: Successful DELETE request
- `400 Bad Request`: Invalid request data
- `401 Unauthorized`: Authentication required
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: Resource not found
- `422 Unprocessable Entity`: Validation errors
- `429 Too Many Requests`: Rate limit exceeded
- `500 Internal Server Error`: Server error

## Rate Limiting

API endpoints are rate limited to ensure system stability:

- **Public endpoints**: 100 requests per minute
- **Authenticated endpoints**: 1000 requests per minute
- **Admin endpoints**: 2000 requests per minute

Rate limit headers:
```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 950
X-RateLimit-Reset: 1624567890
```

## Webhooks

The system supports webhooks for real-time notifications:

### Video Processing Events
- `video.approved`: Video approved for processing
- `video.processing_started`: Video processing began
- `video.processing_completed`: Video processing finished
- `video.upload_completed`: Video uploaded to YouTube
- `video.processing_failed`: Video processing failed

### Webhook Payload
```json
{
  "event": "video.processing_completed",
  "timestamp": "2024-06-15T14:30:00Z",
  "data": {
    "video_id": 456,
    "sermon_id": 123,
    "status": "uploaded",
    "youtube_id": "dQw4w9WgXcQ",
    "processing_time": 1800
  }
}
```

## SDK and Libraries

Official SDKs are available for:
- **JavaScript/Node.js**: `npm install wordsoftruth-api`
- **Python**: `pip install wordsoftruth-api`
- **Ruby**: `gem install wordsoftruth-api`

### JavaScript Example
```javascript
import { WordsOfTruthAPI } from 'wordsoftruth-api';

const api = new WordsOfTruthAPI({
  apiKey: 'your-api-key',
  baseUrl: 'https://wordsoftruth.com/api'
});

// List sermons
const sermons = await api.sermons.list({
  church: 'Grace Community Church',
  page: 1
});

// Create video
const video = await api.videos.create({
  sermon_id: 123,
  script: 'Welcome to today\'s sermon...'
});
```

## Testing

### Test Environment
```
Base URL: https://test.wordsoftruth.com/api
Test API Key: test_key_123456789
```

### Postman Collection
A Postman collection is available at: `docs/postman/WordsOfTruth_API.json`

## Support

For API support, contact:
- **Email**: api-support@wordsoftruth.com
- **Documentation**: https://docs.wordsoftruth.com
- **Status Page**: https://status.wordsoftruth.com