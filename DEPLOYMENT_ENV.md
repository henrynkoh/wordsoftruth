# Environment Variables for Production Deployment

This document outlines the environment variables required for deploying the Words of Truth application to production.

## Required Environment Variables

### Core Rails Configuration
- `RAILS_ENV=production`
- `SECRET_KEY_BASE` - Generate with `rails secret`
- `RAILS_LOG_LEVEL=info`
- `RAILS_MAX_THREADS=5`
- `RAILS_HOST` - Your production domain (e.g., wordsoftruth.com)

### Database Configuration
- `DATABASE_URL` - PostgreSQL connection string for production
  - Format: `postgresql://username:password@host:port/database_name`

### Redis Configuration (for Sidekiq)
- `REDIS_URL` - Redis connection string
  - Format: `redis://localhost:6379/0`

### Google/YouTube API Configuration
- `GOOGLE_CLIENT_ID` - OAuth 2.0 client ID from Google Cloud Console
- `GOOGLE_CLIENT_SECRET` - OAuth 2.0 client secret
- `GOOGLE_OAUTH_REDIRECT_URI` - Must match your production domain
- `YOUTUBE_API_KEY` - YouTube Data API key
- `YOUTUBE_ACCESS_TOKEN` - Obtained through OAuth flow
- `YOUTUBE_REFRESH_TOKEN` - Obtained through OAuth flow

### Video Processing Configuration
- `PYTHON_PATH=/usr/bin/python3`
- `FFMPEG_PATH=/usr/bin/ffmpeg`
- `VIDEO_STORAGE_PATH=storage/generated_videos`
- `BACKGROUND_VIDEOS_PATH=storage/background_videos`

### Email Configuration (Optional)
- `SMTP_USERNAME` - SMTP server username
- `SMTP_PASSWORD` - SMTP server password
- `SMTP_ADDRESS` - SMTP server address
- `SMTP_PORT` - SMTP server port (default: 587)
- `SMTP_DOMAIN` - Your domain name
- `FROM_EMAIL` - Default from email address

### Security Configuration
- `FORCE_SSL=true`
- `ASSUME_SSL=true`
- `RAILS_SERVE_STATIC_FILES=true`
- `RAILS_LOG_TO_STDOUT=true`

### Optional Monitoring/Analytics
- `SENTRY_DSN` - Sentry error tracking (if using)
- `GOOGLE_ANALYTICS_ID` - Google Analytics tracking ID

### Cloud Storage (Optional)
- `AWS_ACCESS_KEY_ID` - If using S3 for file storage
- `AWS_SECRET_ACCESS_KEY` - S3 secret key
- `AWS_REGION` - S3 region
- `AWS_BUCKET` - S3 bucket name

## Setup Instructions

1. **Copy the environment template:**
   ```bash
   cp .env.production .env
   ```

2. **Generate a secret key:**
   ```bash
   rails secret
   ```

3. **Set up Google OAuth:**
   - Go to Google Cloud Console
   - Create OAuth 2.0 credentials
   - Add your production domain to authorized redirect URIs
   - Copy client ID and secret

4. **Configure database:**
   - Set up PostgreSQL database
   - Update DATABASE_URL with connection details

5. **Set up Redis:**
   - Install Redis on your server
   - Update REDIS_URL if not using default

6. **Configure email (optional):**
   - Set up SMTP provider (Gmail, SendGrid, etc.)
   - Update SMTP configuration variables

## Deployment Checklist

- [ ] All required environment variables are set
- [ ] Database is created and accessible
- [ ] Redis is running and accessible
- [ ] Google OAuth is configured with production domain
- [ ] YouTube API quotas are sufficient
- [ ] SMTP is configured (if using email)
- [ ] SSL certificates are set up
- [ ] Domain DNS is configured
- [ ] File storage paths are writable
- [ ] Python3 and FFmpeg are installed on server

## Security Notes

- Never commit actual environment variable values to version control
- Use secure methods to deploy environment variables (e.g., platform-specific environment variable management)
- Regularly rotate API keys and secrets
- Use strong passwords for database and Redis connections
- Keep your OAuth credentials secure and never expose them in client-side code

## Platform-Specific Notes

### Railway
- Most environment variables can be set in the Railway dashboard
- DATABASE_URL is automatically provided
- Redis add-on available

### Heroku
- Use `heroku config:set` to set environment variables
- DATABASE_URL is automatically provided with Postgres add-on
- Redis add-on available

### AWS/DigitalOcean
- Use platform-specific environment variable management
- Set up managed databases and Redis instances
- Configure load balancers and SSL certificates

## Troubleshooting

- **Database connection issues:** Check DATABASE_URL format and network connectivity
- **Redis connection issues:** Verify REDIS_URL and Redis server status
- **YouTube API errors:** Check API quotas and OAuth configuration
- **Email delivery issues:** Verify SMTP settings and provider configuration
- **SSL issues:** Ensure FORCE_SSL and ASSUME_SSL are properly configured