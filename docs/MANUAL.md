# Words of Truth - User Manual

## Table of Contents

1. [Introduction](#introduction)
2. [System Architecture](#system-architecture)
3. [Installation Guide](#installation)
4. [Configuration](#configuration)
5. [User Interface](#user-interface)
6. [Content Management](#content-management)
7. [Video Generation](#video-generation)
8. [Publishing & Distribution](#publishing-distribution)
9. [Analytics & Reporting](#analytics-reporting)
10. [Administration](#administration)
11. [Security](#security)
12. [API Reference](#api-reference)
13. [Troubleshooting](#troubleshooting)
14. [Best Practices](#best-practices)
15. [Glossary](#glossary)
16. [Monitoring & Logging](#monitoring-logging)
17. [Scaling Guide](#scaling-guide)
18. [Advanced Configuration](#advanced-configuration)
19. [Security Hardening](#security-hardening)
20. [Performance Optimization](#performance-optimization)

## Introduction

Words of Truth is an AI-powered platform that transforms sermon content into engaging YouTube Shorts. This manual provides comprehensive documentation for all aspects of the system.

### Purpose
- Automate video content creation
- Reach younger audiences
- Maximize sermon impact
- Scale ministry outreach

### Key Benefits
- Time savings
- Consistent quality
- Wider reach
- Measurable impact
- Cost-effective

## System Architecture

### Components
1. **Frontend Layer**
   - React.js components
   - Tailwind CSS styling
   - Hotwire/Turbo integration
   - Service worker for offline support

2. **Backend Services**
   - Ruby on Rails API
   - Sidekiq job processing
   - Redis caching
   - SQLite database
   - FFmpeg media processing

3. **AI Services**
   - OpenAI for content analysis
   - Custom ML models for video generation
   - Speech synthesis engine
   - Natural language processing

4. **External Integrations**
   - YouTube API
   - AWS S3 storage
   - Email delivery
   - Analytics services

### Data Flow
1. Content Ingestion
2. Processing Pipeline
3. Quality Assurance
4. Distribution
5. Analytics Collection

## Installation

### System Requirements

#### Hardware
- CPU: Intel/AMD 64-bit processor
  - Minimum: 2 cores
  - Recommended: 4+ cores
- RAM:
  - Minimum: 4GB
  - Recommended: 8GB+
- Storage:
  - System: 20GB
  - Media: 100GB+
- Network: 10Mbps+

#### Software
- Operating System:
  - macOS 12+
  - Ubuntu 20.04+
  - Windows 10/11
- Runtime Environment:
  - Ruby 3.2.2
  - Node.js 18+
  - Python 3.8+
- Databases:
  - Redis 6.0+
  - SQLite 3.x
- Dependencies:
  - FFmpeg 4.4+
  - ImageMagick
  - System libraries

### Installation Steps

#### 1. Base System
```bash
# Clone repository
git clone https://github.com/yourusername/wordsoftruth.git
cd wordsoftruth

# Install system dependencies
## macOS
brew install redis ffmpeg imagemagick python@3.8

## Ubuntu
sudo apt-get update
sudo apt-get install redis-server ffmpeg imagemagick python3.8
```

#### 2. Application Setup
```bash
# Install Ruby dependencies
bundle install

# Install Node.js dependencies
yarn install

# Install Python dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your settings
```

#### 3. Database Setup
```bash
# Initialize database
rails db:create db:migrate

# Load seed data
rails db:seed

# Verify installation
rails test
```

## Configuration

### Environment Variables

#### Core Settings
```bash
# Application
RAILS_ENV=development
SECRET_KEY_BASE=your_secret_key

# Redis
REDIS_URL=redis://localhost:6379/0

# External Services
YOUTUBE_API_KEY=your_youtube_key
AWS_ACCESS_KEY_ID=your_aws_key
AWS_SECRET_ACCESS_KEY=your_aws_secret
OPENAI_API_KEY=your_openai_key
```

#### Optional Settings
```bash
# Email
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your_email
SMTP_PASSWORD=your_password

# Storage
S3_BUCKET=your_bucket_name
MEDIA_STORAGE_PATH=/path/to/storage

# Processing
MAX_CONCURRENT_JOBS=5
VIDEO_QUALITY=1080p
```

### Application Settings

#### Sidekiq Configuration
```yaml
# config/sidekiq.yml
:concurrency: 5
:queues:
  - critical
  - default
  - low
```

#### Schedule Configuration
```yaml
# config/schedule.yml
sermon_crawler:
  cron: '0 */4 * * *'
  class: SermonCrawlingJob
  
video_processor:
  cron: '*/15 * * * *'
  class: VideoProcessingJob
```

## User Interface

### Dashboard Layout
- Header
  - Navigation menu
  - User profile
  - Notifications
- Sidebar
  - Quick actions
  - Status indicators
- Main Content
  - Statistics
  - Recent items
  - Action buttons
- Footer
  - System status
  - Support links

### Key Sections
1. Content Management
2. Video Processing
3. Publishing Queue
4. Analytics
5. Settings

## Content Management

### Sermon Management
- Adding sermons
- Editing content
- Categorization
- Batch operations
- Version control

### Media Library
- Asset organization
- File formats
- Storage quotas
- Backup system

## Video Generation

### Processing Pipeline
1. Content Analysis
2. Script Generation
3. Visual Assembly
4. Audio Processing
5. Final Rendering

### Quality Control
- Automated checks
- Manual review
- Error handling
- Performance optimization

## Publishing & Distribution

### YouTube Integration
- Channel setup
- Upload automation
- Metadata management
- Engagement tracking

### Multi-platform Distribution
- Social media sharing
- Email newsletters
- Website embedding
- RSS feeds

## Analytics & Reporting

### Performance Metrics
- View counts
- Engagement rates
- Conversion tracking
- Audience demographics

### System Metrics
- Processing times
- Success rates
- Resource usage
- Error tracking

## Administration

### User Management
- Role-based access
- Team collaboration
- Activity logging
- Security policies

### System Maintenance
- Backup procedures
- Update process
- Monitoring
- Optimization

## Security

### Authentication
- User authentication
- API authentication
- OAuth integration
- 2FA support

### Data Protection
- Encryption
- Access control
- Audit logging
- Compliance

## API Reference

### REST API
- Endpoints
- Authentication
- Rate limiting
- Error handling

### WebSocket API
- Real-time updates
- Event handling
- Connection management

## Troubleshooting

### Common Issues
- Processing errors
- Integration failures
- Performance problems
- Data inconsistencies

### Diagnostics
- Log analysis
- Error tracking
- Performance profiling
- Debug tools

## Best Practices

### Content Creation
- Optimal formats
- Style guidelines
- Quality standards
- SEO optimization

### System Usage
- Resource management
- Workflow optimization
- Security measures
- Backup strategies

## Glossary

- **Sermon**: Original content source
- **Short**: Generated video content
- **Pipeline**: Processing workflow
- **Queue**: Job management system
- **Worker**: Processing unit
- **Template**: Video style preset

## Monitoring & Logging

### Log Management
- Application Logs: `/log/production.log`
- Sidekiq Logs: `/log/sidekiq.log`
- Video Processing Logs: `/log/video_processing.log`

### Monitoring Tools
- Health Checks: `/health`
- Sidekiq Dashboard: `/sidekiq`
- Resource Usage: `/admin/metrics`
- Job Queue Status: `/admin/queues`

### Alert Configuration
```yaml
# config/alerts.yml
critical:
  cpu_usage: 90%
  memory_usage: 85%
  disk_space: 90%
  job_queue: 1000
warning:
  cpu_usage: 75%
  memory_usage: 70%
  disk_space: 75%
  job_queue: 500
```

## Scaling Guide

### Horizontal Scaling
1. Load Balancing
   - Nginx configuration
   - SSL termination
   - Static asset serving

2. Database Sharding
   - Partition strategy
   - Migration process
   - Rebalancing data

3. Job Processing
   - Multiple Sidekiq processes
   - Queue prioritization
   - Resource allocation

### Vertical Scaling
1. Resource Optimization
   - Memory management
   - CPU utilization
   - I/O optimization

2. Performance Tuning
   - Database indexing
   - Query optimization
   - Cache strategies

## Advanced Configuration

### Custom Video Templates
```ruby
# app/services/video_templates/custom.rb
module VideoTemplates
  class Custom < Base
    def initialize(options = {})
      @duration = options[:duration] || 60
      @resolution = options[:resolution] || '1080p'
      @effects = options[:effects] || []
      @transitions = options[:transitions] || []
    end

    def render
      # Template rendering logic
    end
  end
end
```

### Job Scheduling
```yaml
# config/schedule.yml
sermon_crawler:
  cron: "0 */4 * * *"  # Every 4 hours
  class: "SermonCrawlingJob"
  queue: "default"

video_processor:
  cron: "*/15 * * * *"  # Every 15 minutes
  class: "VideoProcessingJob"
  queue: "default"
```

### Error Handling
```ruby
# config/initializers/error_handling.rb
Rails.application.config.middleware.use(
  ExceptionNotification::Rack,
  email: {
    email_prefix: '[ERROR] ',
    sender_address: 'errors@wordsoftruth.com',
    exception_recipients: ['admin@wordsoftruth.com']
  },
  slack: {
    webhook_url: ENV['SLACK_WEBHOOK_URL'],
    channel: '#errors',
    additional_parameters: {
      mrkdwn: true
    }
  }
)
```

## Security Hardening

### Authentication
- OAuth2 implementation
- Two-factor authentication
- Session management
- API token security

### Authorization
- Role-based access control
- Resource permissions
- API scope limitations
- Audit logging

### Data Protection
- Encryption at rest
- Secure file storage
- Personal data handling
- Backup strategies

## Performance Optimization

### Caching Strategy
1. Application Level
   - Fragment caching
   - Russian doll caching
   - Cache invalidation

2. Database Level
   - Query caching
   - Index optimization
   - Connection pooling

3. Frontend Level
   - Asset compilation
   - CDN integration
   - Browser caching

### Background Jobs
1. Queue Management
   - Priority queues
   - Rate limiting
   - Retry strategies

2. Resource Allocation
   - Worker scaling
   - Memory limits
   - CPU constraints

3. Monitoring
   - Job metrics
   - Error tracking
   - Performance profiling 