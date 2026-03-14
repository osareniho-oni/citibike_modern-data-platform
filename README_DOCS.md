# 📚 Documentation Organization

All detailed documentation has been moved to the `docs/` folder for better organization.

## 📁 Documentation Structure

```
citibike_modern-data-platform/
├── README.md                          # Main project overview (keep in root)
├── setup.md                           # Original detailed setup (keep in root)
├── .env.example                       # Configuration template
├── docs/                              # 📂 All automation documentation
│   ├── DEPLOYMENT_GUIDE.md           # ⭐ Complete deployment guide
│   ├── PROJECT_CONFIGURATION.md      # Your project configuration
│   ├── DEPLOYMENT_ANSWERS.md         # Answers to your 3 questions
│   ├── AUTOMATION_STRATEGY.md        # Automation options explained
│   ├── ZOOMCAMP_PROJECT_RECOMMENDATION.md  # Zoomcamp-specific guidance
│   ├── DEPLOYMENT.md                 # Detailed deployment instructions
│   ├── QUICK_START.md                # 15-minute quick start
│   └── README_AUTOMATION.md          # Automation summary
├── scripts/                           # Deployment automation scripts
└── ...
```

## 🚀 Quick Links

### For Quick Deployment
- **Start Here:** [`docs/DEPLOYMENT_GUIDE.md`](docs/DEPLOYMENT_GUIDE.md) - Complete guide with all options
- **Your Config:** [`docs/PROJECT_CONFIGURATION.md`](docs/PROJECT_CONFIGURATION.md) - Your project values
- **Quick Start:** [`docs/QUICK_START.md`](docs/QUICK_START.md) - 15-minute setup

### For Understanding
- **Your Questions:** [`docs/DEPLOYMENT_ANSWERS.md`](docs/DEPLOYMENT_ANSWERS.md) - KV store, backfill, Kestra server
- **Automation Options:** [`docs/AUTOMATION_STRATEGY.md`](docs/AUTOMATION_STRATEGY.md) - 3 automation approaches
- **Zoomcamp Guide:** [`docs/ZOOMCAMP_PROJECT_RECOMMENDATION.md`](docs/ZOOMCAMP_PROJECT_RECOMMENDATION.md) - Evaluation tips

### For Reference
- **Original Setup:** [`setup.md`](setup.md) - Comprehensive manual setup guide
- **Main README:** [`README.md`](README.md) - Project overview and architecture

## 🎯 Recommended Reading Order

### For First-Time Setup
1. [`docs/PROJECT_CONFIGURATION.md`](docs/PROJECT_CONFIGURATION.md) - Understand your configuration
2. [`docs/DEPLOYMENT_GUIDE.md`](docs/DEPLOYMENT_GUIDE.md) - Follow deployment steps
3. [`docs/DEPLOYMENT_ANSWERS.md`](docs/DEPLOYMENT_ANSWERS.md) - Understand KV store, backfill, Kestra

### For Zoomcamp Reviewers
1. [`README.md`](README.md) - Project overview
2. [`docs/ZOOMCAMP_PROJECT_RECOMMENDATION.md`](docs/ZOOMCAMP_PROJECT_RECOMMENDATION.md) - Evaluation guidance
3. [`docs/QUICK_START.md`](docs/QUICK_START.md) - Fast deployment

### For Understanding Automation
1. [`docs/AUTOMATION_STRATEGY.md`](docs/AUTOMATION_STRATEGY.md) - Why shell scripts?
2. [`docs/README_AUTOMATION.md`](docs/README_AUTOMATION.md) - What's automated?
3. [`docs/DEPLOYMENT_GUIDE.md`](docs/DEPLOYMENT_GUIDE.md) - How to use it?

## 📋 Files to Keep in Root

### Essential Files (Root Directory)
- `README.md` - Main project overview (for GitHub)
- `setup.md` - Original comprehensive setup guide
- `.env.example` - Configuration template
- `.gitignore` - Security exclusions

### Why These Stay in Root?
- **README.md** - GitHub displays this automatically
- **setup.md** - Historical reference, comprehensive manual guide
- **.env.example** - Needs to be easily found for configuration
- **.gitignore** - Must be in root to work

## 🗂️ Files Moved to docs/

All automation-related documentation:
- `DEPLOYMENT_GUIDE.md` - Consolidated deployment guide
- `PROJECT_CONFIGURATION.md` - Your project configuration
- `DEPLOYMENT_ANSWERS.md` - Answers to your questions
- `AUTOMATION_STRATEGY.md` - Automation approach analysis
- `ZOOMCAMP_PROJECT_RECOMMENDATION.md` - Zoomcamp-specific
- `DEPLOYMENT.md` - Detailed deployment
- `QUICK_START.md` - Quick start guide
- `README_AUTOMATION.md` - Automation summary

## 🎉 Result

**Before:** 8 documentation files in root (cluttered)  
**After:** 4 essential files in root + organized docs/ folder (clean)

---

## 🚀 Ready to Deploy?

```bash
# Quick deployment
./scripts/deploy.sh dev --full --start-kestra

# See full guide
cat docs/DEPLOYMENT_GUIDE.md
```

---

*Documentation organized: March 14, 2026*