# Quick Start Guide - Words of Truth

This comprehensive guide will help you get started with Words of Truth and have your first video generated within 30 minutes.

## 1. Dashboard Overview

The dashboard is your command center for managing sermon content and video generation. Here's what you'll find:

### Key Metrics
- **Pending Videos**: Content ready for processing
- **Processing Videos**: Currently being generated
- **Uploaded Videos**: Successfully published to YouTube

### Navigation
- Top Bar: Quick actions and notifications
- Side Menu: Main navigation sections
- Content Area: Dynamic data display
- Footer: System status and support links

## 2. Adding Your First Sermon

### Manual Entry
1. Click the "+" button in the top navigation
2. Select "Add New Sermon"
3. Fill in the required fields:
   - Title (max 100 characters)
   - Scripture Reference (e.g., "John 3:16")
   - Church Name
   - Pastor Name
   - Sermon Date
   - Sermon Content (full text or key points)
   - Tags (for categorization)
   - Language (for TTS)

### Bulk Import
1. Prepare your CSV file with columns:
   - sermon_title
   - scripture_ref
   - church_name
   - pastor_name
   - sermon_date
   - content
   - tags
2. Click "Import" in the sermon section
3. Upload your CSV file
4. Review and confirm the import

## 3. Video Generation Process

### Automatic Processing
After adding a sermon:
1. The system analyzes the content
2. Extracts key messages (30-60 seconds)
3. Generates a script
4. Creates visual elements
5. Adds background music
6. Renders the final video

### Processing Options
- **Quality**: Standard (720p) or HD (1080p)
- **Duration**: 30s, 60s, or custom length
- **Style**: Modern, Classic, or Dynamic
- **Music**: Choose from library or upload custom
- **Captions**: Auto-generated in multiple languages

## 4. Review and Publishing

### Video Review
1. Access the "Pending Videos" section
2. Click on a video thumbnail to preview
3. Review:
   - Content accuracy
   - Visual quality
   - Audio sync
   - Caption timing
   - Overall impact

### Publishing Options
1. **Approve**:
   - Click "Approve" for immediate processing
   - Schedule for later publication
   - Set target audience and tags
   
2. **Reject**:
   - Click "Reject" to discard
   - Provide feedback for improvement
   - Request re-generation with different settings

### Post-Publishing
- Monitor video performance
- View engagement metrics
- Manage comments
- Schedule social sharing

## 5. Advanced Features

### Content Management
- Batch processing
- Template creation
- Style presets
- Custom thumbnails
- Multi-language support

### Automation
- Scheduled crawling
- Auto-publishing rules
- Email notifications
- Performance reports
- Error handling

## 6. Troubleshooting

Common issues and solutions:
- Video processing stuck
- Audio quality issues
- Upload failures
- API rate limits
- Storage space alerts

## 7. Next Steps

- Explore advanced settings
- Set up automated workflows
- Create custom templates
- Join our community
- Subscribe to updates

## 8. Resources

- [Full Documentation](../docs/MANUAL.md)
- [API Guide](../docs/API.md)
- [Video Tutorials](https://youtube.com/wordsoftruth)
- [Community Forum](https://community.wordsoftruth.com)
- [Support Chat](https://discord.gg/wordsoftruth)

## 9. Common Workflows

### Sermon Series Processing
1. Create Series Template
   ```json
   {
     "name": "Summer Series 2025",
     "style": "modern",
     "duration": 45,
     "music": "upbeat",
     "transitions": ["fade", "slide"],
     "branding": {
       "colors": ["#FF5733", "#33FF57"],
       "logo": "path/to/logo.png",
       "font": "Montserrat"
     }
   }
   ```

2. Batch Upload
   ```csv
   sermon_title,scripture_ref,church_name,pastor_name,sermon_date,content,tags
   "Finding Peace",John 14:27,Grace Church,Pastor Smith,2025-06-01,"Full sermon text here",peace|faith
   "Living Hope",1 Peter 1:3,Grace Church,Pastor Smith,2025-06-08,"Full sermon text here",hope|faith
   ```

3. Monitor Progress
   - Track in dashboard
   - Review notifications
   - Check analytics

### Content Optimization

#### Title Formats
Good:
- "Finding Peace in Chaos | 60 Sec Devotional"
- "3 Steps to Stronger Faith 🙏"
- "Transform Your Prayer Life Today!"

Avoid:
- "Sermon Excerpt June 1"
- "Pastor Smith Teaching"
- "Church Video #123"

#### Description Templates
```
🎯 Key Message:
[One sentence summary]

📖 Scripture:
[Reference]

🙏 Prayer Point:
[Related prayer focus]

👉 Full Sermon:
[Link]

#[Church Name] #Faith #[Topic]
```

### Automation Examples

#### Scheduled Crawling
```yaml
# Daily morning sermons
morning_sermons:
  url: "https://church.com/sermons"
  schedule: "0 9 * * *"
  filters:
    - category: "morning"
    - duration: ">30"

# Weekly youth service
youth_service:
  url: "https://church.com/youth"
  schedule: "0 19 * * 3"
  filters:
    - category: "youth"
    - language: "english"
```

#### Publishing Rules
```yaml
# YouTube publishing settings
youtube:
  schedule:
    - time: "10:00"
      days: ["Mon", "Wed", "Fri"]
      category: "devotional"
    - time: "15:00"
      days: ["Tue", "Thu"]
      category: "teaching"
  tags:
    default: ["faith", "christian", "inspiration"]
    devotional: ["daily devotion", "prayer"]
    teaching: ["bible study", "scripture"]
```

## 10. Integration Examples

### YouTube Integration
```javascript
// Sample webhook handler
app.post('/webhooks/youtube', (req, res) => {
  const { videoId, status } = req.body;
  
  if (status === 'published') {
    notifyTeam(videoId);
    updateAnalytics(videoId);
    scheduleSharing(videoId);
  }
});
```

### Social Media Sharing
```ruby
# Automated sharing setup
Video.after_upload do |video|
  SocialShare.create(
    platforms: ['facebook', 'instagram', 'twitter'],
    schedule: 1.hour.from_now,
    content: video.social_template,
    media: video.thumbnail_url
  )
end
```

## 11. Customization Tips

### Custom Thumbnails
1. Size: 1280x720px
2. Format: JPG, PNG
3. Elements:
   - Clear title
   - Engaging image
   - Church branding
   - Call-to-action

### Video Templates
1. Modern Style
   ```css
   .modern-template {
     font-family: 'Poppins', sans-serif;
     background: linear-gradient(45deg, #2B2D42, #8D99AE);
     text-align: center;
     padding: 2rem;
   }
   ```

2. Classic Style
   ```css
   .classic-template {
     font-family: 'Playfair Display', serif;
     background: #F8F9FA;
     text-align: left;
     padding: 1.5rem;
   }
   ```

## 12. Performance Tips

### Optimization Checklist
- [ ] Compress source videos
- [ ] Use appropriate resolution
- [ ] Optimize thumbnail images
- [ ] Cache rendered templates
- [ ] Schedule during off-peak

### Resource Management
- Video storage cleanup
- Template caching
- Background job queues
- API rate limiting 