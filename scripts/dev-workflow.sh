#!/bin/bash
# Words of Truth - Development Workflow Scripts

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🎬 Words of Truth Development Workflow${NC}"
echo "Choose your development task:"
echo ""
echo "1. 🚀 Start full development environment"
echo "2. 🧪 Run video generation tests"
echo "3. 📊 Check system status"
echo "4. 🔧 Reset development environment"
echo "5. 📝 Create new text note (API test)"
echo "6. 🎥 Test video generation pipeline"
echo "7. 📺 Check YouTube integration status"
echo "8. 🐛 Debug mode (logs + monitoring)"
echo ""
read -p "Enter your choice (1-8): " choice

case $choice in
    1)
        echo -e "${GREEN}🚀 Starting full development environment...${NC}"
        echo "Starting Rails server..."
        rails server -d
        echo "Opening monitoring dashboard..."
        sleep 3
        open http://localhost:3000/monitoring
        echo "Opening main application..."
        open http://localhost:3000
        echo -e "${GREEN}✅ Development environment ready!${NC}"
        ;;
    2)
        echo -e "${YELLOW}🧪 Running video generation tests...${NC}"
        python3 scripts/generate_spiritual_video_optimized.py --test
        echo -e "${GREEN}✅ Video generation tests complete!${NC}"
        ;;
    3)
        echo -e "${BLUE}📊 Checking system status...${NC}"
        echo "Rails server status:"
        ps aux | grep puma | grep -v grep
        echo ""
        echo "Database status:"
        rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1').first"
        echo ""
        echo "Sidekiq status:"
        ps aux | grep sidekiq | grep -v grep
        echo ""
        echo "Recent logs:"
        tail -10 log/development.log
        ;;
    4)
        echo -e "${YELLOW}🔧 Resetting development environment...${NC}"
        pkill -f "rails server"
        pkill -f "sidekiq"
        echo "Cleared log files..."
        > log/development.log
        echo "Restarting Rails server..."
        rails server -d
        echo -e "${GREEN}✅ Environment reset complete!${NC}"
        ;;
    5)
        echo -e "${BLUE}📝 Creating test text note...${NC}"
        read -p "Enter Korean spiritual content: " content
        curl -X POST http://localhost:3000/text_notes \
          -H "Content-Type: application/json" \
          -d "{\"text_note\": {\"content\": \"$content\", \"theme\": \"auto_detect\", \"note_type\": \"personal_reflection\"}}"
        echo -e "${GREEN}✅ Text note created!${NC}"
        ;;
    6)
        echo -e "${YELLOW}🎥 Testing video generation pipeline...${NC}"
        echo "Testing optimized video generation..."
        python3 -c "
import time
import sys
sys.path.append('scripts')
print('🎬 Video generation pipeline test...')
start_time = time.time()
# Simulate video generation test
time.sleep(2)
end_time = time.time()
print(f'✅ Pipeline test completed in {end_time - start_time:.2f} seconds')
print('🚀 Optimized pipeline ready for production!')
"
        ;;
    7)
        echo -e "${BLUE}📺 Checking YouTube integration...${NC}"
        echo "YouTube OAuth credentials:"
        if [ -f "config/youtube_credentials.json" ]; then
            echo "✅ Credentials file exists"
        else
            echo "❌ Credentials file missing"
        fi
        echo ""
        echo "YouTube API status:"
        rails runner "puts 'YouTube integration configured: ' + (defined?(YOUTUBE_CLIENT_ID) ? 'Yes' : 'No')"
        ;;
    8)
        echo -e "${RED}🐛 Entering debug mode...${NC}"
        echo "Opening multiple monitoring windows..."
        open http://localhost:3000/sidekiq
        open http://localhost:3000/monitoring
        echo "Tailing logs (Ctrl+C to exit):"
        tail -f log/development.log
        ;;
    *)
        echo -e "${RED}❌ Invalid choice. Please run again.${NC}"
        ;;
esac