# Words of Truth - Claude Code Memory

## Project Overview
Rails 8.0.2 SaaS application that converts sermons and spiritual content into Korean YouTube Shorts using AI automation.

## Key Technologies
- **Backend**: Rails 8.0.2, Ruby 3.2.2
- **Frontend**: Tailwind CSS, JavaScript, Mobile-first design
- **Video Generation**: Python 3.x with optimized algorithms
- **AI Integration**: Korean TTS, content analysis, theme detection
- **Background Jobs**: Sidekiq for processing
- **Database**: ActiveRecord with text_notes, processing metadata

## Current Architecture

### Input Modes (3 Unified Systems)
1. **Sermon Automation** (`/`) - URL-based sermon content extraction
2. **Text Entry** (`/text_notes`) - Personal spiritual content creation  
3. **YouTube Automation** - Batch upload and scheduling

### Key Performance Metrics
- **Video Generation**: Optimized from 120s to 10-16s (7-12x improvement)
- **Processing Pipeline**: 3-step automation (Analysis → Enhancement → Generation)
- **Korean Text Support**: Full Unicode support with TTS integration

## Development Commands

### Rails Commands
```bash
# Start development server
rails server

# Run migrations
rails db:migrate

# Access Rails console  
rails console

# Run tests (framework TBD - check README)
# npm test OR bundle exec rspec OR rails test
```

### Video Generation Commands
```bash
# Run optimized video generation
python3 scripts/generate_spiritual_video_optimized.py <config_file>

# Test video generation performance
python3 scripts/test_video_generation.py
```

### Monitoring & Queue Management
```bash
# Access Sidekiq web interface
open http://localhost:3000/sidekiq

# Check system monitoring
open http://localhost:3000/monitoring

# View application logs
tail -f log/development.log
```

## Recent Major Improvements

### Performance Optimization (Complete ✅)
- Achieved 7-12x video generation speed improvement
- Optimized Python video generation algorithms
- Reduced FPS to 12, implemented pre-computed frames
- Fixed Ruby environment conflicts (RVM/rbenv)

### Text Entry System (Complete ✅)
- Built complete CRUD interface for Korean spiritual content
- AI theme detection with 10+ spiritual themes
- Real-time character counting and duration estimation
- Mobile-responsive design with templates
- Background job integration with optimized pipeline

### Unified Landing Page (Complete ✅)
- Combined all 3 input modes into single interface
- Real-time progress tracking with percentage completion
- Individual step progress bars with ETA
- Fixed readability issues with improved contrast
- Enhanced error handling and CSP configuration

## Current Status
- **Text Entry System**: 100% Complete - All views, controller, model, jobs implemented
- **Progress Dashboard**: 100% Complete - Real-time tracking with animations
- **Performance**: Optimized - 60-second average processing time
- **UI/UX**: Complete - Mobile-first, accessible, charming design

## Known Issues & Technical Debt
- YouTube quota approval pending for live uploads
- Some font loading CSP warnings (mostly resolved)
- Ruby version warnings (non-blocking)
- Golden light theme occasional memory allocation issues (documented)

## File Structure
```
app/
├── controllers/text_notes_controller.rb (Full REST + API)
├── models/text_note.rb (Korean processing + AI detection)
├── jobs/text_note_video_job.rb (Background processing)
├── views/text_notes/ (Complete CRUD views)
└── views/sermon_automation/index.html.erb (Unified landing)

scripts/
├── generate_spiritual_video_optimized.py (7-12x faster)
└── test_optimization_results.rb (Performance testing)

config/
├── routes.rb (Text notes + API routes)
└── initializers/content_security_policy.rb (Enhanced CSP)
```

## Priority Next Steps
1. **YouTube Quota Approval** - Submit application for production quota
2. **Integration Testing** - Test full pipeline with various content types
3. **Documentation** - User guides for each input mode
4. **Scaling** - Prepare for production deployment

## Development Notes
- Always run lint/typecheck commands after changes
- Use mobile-first approach for all new UI
- Test with Korean text inputs for proper Unicode handling
- Monitor performance with optimized video generation scripts
- Check Sidekiq queue status regularly during development