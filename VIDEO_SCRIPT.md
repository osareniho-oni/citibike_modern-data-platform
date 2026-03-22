# 🎥 5-Minute Video Presentation Script
## NYC Citibike Analytics Platform - Data Engineering Zoomcamp Final Project

---

## 📋 Pre-Recording Checklist

- [ ] Kestra server running (`http://localhost:8080`)
- [ ] Have BigQuery console open
- [ ] Have Looker Studio dashboards open
- [ ] Have GitHub repo open (README.md)
- [ ] Test screen recording software
- [ ] Close unnecessary tabs/applications
- [ ] Mute notifications

---

## 🎬 SCRIPT (5 Minutes Total)

### **[0:00-0:45] INTRODUCTION & PROBLEM STATEMENT** (45 seconds)

**[Show: GitHub README.md - Project Title]**

> "Hi! I'm presenting my Data Engineering Zoomcamp final project: the NYC Citibike Analytics Platform - a production-grade, real-time data platform for urban mobility analytics.

**[Show: README.md - Business Problems section]**

> "The problem: Urban bike-share operations need real-time insights, but face challenges. APIs only provide snapshots with no historical retention. There's no data quality monitoring, and state changes are lost between API calls.

> "My solution: A streaming-first architecture that captures every state change, validates data quality at ingestion, and provides both real-time operational dashboards and historical analytics."

---

### **[0:45-2:00] ARCHITECTURE OVERVIEW** (1 minute 15 seconds)

**[Show: README.md - Architecture Diagram]**

> "Let me walk you through the architecture. This is a modern, event-driven data platform with three main data flows:

> "First, the streaming pipeline: Every 5 minutes, Kestra fetches station status from the Citibike GBFS API. My Python script validates timestamps - filtering out invalid 1970 dates - then publishes valid messages to Google Pub/Sub. From there, a BigQuery subscription automatically streams data into a partitioned table with 30 to 90 second latency. This is true streaming ingestion, not batch.

**[Show: terraform-gcp folder structure]**

> "Second, batch pipelines: Monthly trip data and daily weather data flow through Kestra, get converted to Parquet for 85% storage savings, and land in BigQuery.

> "Third, transformations: dbt processes everything through staging, intermediate, and marts layers, creating a star schema with dimension and fact tables optimized for analytics.

**[Show: README.md - Technology Stack]**

> "The entire infrastructure is defined as code with Terraform - BigQuery, GCS, Pub/Sub, IAM - everything is reproducible. Kestra orchestrates all workflows, and dbt handles transformations."

---

### **[2:00-3:30] LIVE DEMO** (1 minute 30 seconds)

**[Show: Kestra UI - Flows page]**

> "Let me show you the live system. Here's Kestra - you can see all my workflows. The station status publisher runs every 5 minutes.

**[Click on citibike_station_status_publisher, show recent execution]**

> "Looking at a recent execution - it fetched 2,000+ stations, validated timestamps, and published messages to Pub/Sub. You can see it skipped a few stations with invalid timestamps - that's data quality in action.

**[Show: BigQuery Console - station_status_streaming table]**

> "Now in BigQuery, here's the streaming table. Notice the last_reported timestamps - this data is from just minutes ago. The table is partitioned by day and clustered by station_id for query performance.

**[Run a quick query]**

```sql
SELECT 
  station_id,
  num_bikes_available,
  last_reported,
  TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), last_reported, MINUTE) as minutes_old
FROM `project.dataset.station_status_streaming`
ORDER BY last_reported DESC
LIMIT 5;
```

> "See? Data is less than 10 minutes old. That's real-time streaming.

**[Show: Looker Studio - Station Operations Dashboard]**

> "Now the dashboards. This is the Station Operations dashboard - real-time bike availability, utilization rates, geographic distribution.

**[Quickly flip through other dashboards]**

> "Daily Trip Analytics - hourly patterns, user types, bike preferences. Popular Routes - top station pairs and route analysis. And Weather Impact - showing how temperature and precipitation affect ridership. All four dashboards are fully interactive with filters and drill-downs."

---

### **[3:30-4:15] TECHNICAL HIGHLIGHTS** (45 seconds)

**[Show: README.md - Key Architectural Decisions section]**

> "What makes this project stand out? 

> "One: True streaming architecture with Pub/Sub, not just scheduled batch jobs. 30 to 90 second latency from API to dashboard.

> "Two: Data quality at ingestion. Timestamp validation prevents bad data from entering the warehouse.

> "Three: Cost optimization. Parquet conversion saves 85% on storage. Partitioning and clustering reduce query costs by 90%.

> "Four: Complete infrastructure as code. Everything is Terraform modules - storage, BigQuery, Pub/Sub, IAM. You can deploy this entire platform with terraform apply.

> "Five: Production-grade observability. Every pipeline logs execution metrics, skipped records, and errors for monitoring."

---

### **[4:15-5:00] REPRODUCIBILITY & CLOSING** (45 seconds)

**[Show: GitHub repo - setup.md]**

> "How can you reproduce this? I've documented everything. The setup.md file has step-by-step instructions - from GCP project creation to Kestra deployment to dbt configuration.

**[Show: scripts/ folder]**

> "I've also created deployment scripts for automation. Deploy.sh handles the full deployment. There's monitoring, teardown, everything you need.

**[Show: docs/ folder]**

> "The docs folder has detailed guides for deployment, automation strategies, and Zoomcamp-specific recommendations.

**[Show: looker-studio-dashboards/ folder]**

> "And the dashboard implementation guide shows exactly how to recreate all four Looker Studio dashboards.

**[Show: README.md - top]**

> "This project demonstrates production-grade data engineering: streaming ingestion, infrastructure as code, data quality, cost optimization, and complete reproducibility. 

> "The GitHub repo has everything - code, documentation, dashboards, and this video. Thank you for watching, and I'm happy to answer any questions!"

---

## 🎬 RECORDING TIPS

### Before Recording:
1. **Practice 2-3 times** - get comfortable with the flow
2. **Time yourself** - adjust if over/under 5 minutes
3. **Prepare all screens** - have everything open in tabs
4. **Test audio** - use a good microphone if possible
5. **Clean desktop** - close unnecessary apps

### During Recording:
1. **Speak clearly and confidently**
2. **Don't rush** - 5 minutes is plenty of time
3. **Show, don't just tell** - live demos are powerful
4. **If you make a mistake** - pause, then continue (edit later)
5. **Smile** - enthusiasm is contagious!

### Screen Recording Settings:
- **Resolution**: 1920x1080 (1080p)
- **Frame rate**: 30 fps
- **Audio**: Enable microphone
- **Cursor**: Show cursor highlights
- **Zoom**: Use zoom feature for small text

### What to Show:
- ✅ GitHub README (architecture, features)
- ✅ Kestra UI (workflows, executions)
- ✅ BigQuery console (tables, queries)
- ✅ Looker Studio dashboards (all 4)
- ✅ Project structure (folders, files)

### What NOT to Show:
- ❌ Service account keys
- ❌ .env files
- ❌ Personal information
- ❌ Billing information
- ❌ Long loading times (edit them out)

---

## 📝 Alternative 3-Minute Version (If Needed)

If you need a shorter version:

**[0:00-0:30]** Problem + Solution (30s)
**[0:30-1:15]** Architecture Overview (45s)
**[1:15-2:15]** Live Demo (1 min)
**[2:15-2:45]** Technical Highlights (30s)
**[2:45-3:00]** Reproducibility + Close (15s)

---

## 🎯 Key Messages to Emphasize

1. **"Real-time streaming, not just batch"** - Pub/Sub architecture
2. **"Data quality at ingestion"** - Timestamp validation
3. **"Production-grade infrastructure"** - Terraform, monitoring
4. **"Cost-optimized"** - Parquet, partitioning, clustering
5. **"Fully reproducible"** - Complete documentation + scripts

---

## 📤 After Recording

1. **Review the video** - watch it once
2. **Edit if needed** - cut long pauses, mistakes
3. **Add title slide** (optional) - "NYC Citibike Analytics Platform"
4. **Export** - MP4 format, 1080p
5. **Upload** - YouTube (unlisted) or Loom
6. **Get link** - shareable URL
7. **Update README.md** - add video link
8. **Submit** - course form with GitHub + video URLs

---

## 🏆 You've Got This!

This script is designed to showcase your project's strengths while staying within 5 minutes. Practice it a few times, and you'll nail it!

**Remember**: The goal is to demonstrate your technical skills and the production-grade nature of your platform. Show confidence in what you've built - it's impressive! 🚀

Good luck! 🎬