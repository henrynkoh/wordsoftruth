# 🚀 Quick Deploy to Railway

## Step 1: Install Railway CLI
```bash
npm install -g @railway/cli
```

## Step 2: Deploy
```bash
# Login to Railway
railway login

# Initialize project
railway init --name wordsoftruth

# Deploy
railway up
```

## Step 3: Set Environment Variables (in Railway dashboard)
```
SECRET_KEY_BASE=generate_this_with_rails_secret
RAILS_ENV=production
RAILS_SERVE_STATIC_FILES=true
```

## Step 4: Access Your App
- **Main App**: https://wordsoftruth-production.up.railway.app
- **Monitoring Dashboard**: https://wordsoftruth-production.up.railway.app/monitoring
- **Health Check**: https://wordsoftruth-production.up.railway.app/health

## 🎉 Your monitoring system will be live!

Railway automatically provides:
- ✅ PostgreSQL database
- ✅ Custom domain
- ✅ SSL certificate  
- ✅ Environment variables
- ✅ Automatic deployments from GitHub

## Alternative: Render.com
1. Push to GitHub
2. Go to render.com
3. Connect repo
4. Deploy (free tier)