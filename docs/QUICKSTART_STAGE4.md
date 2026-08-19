# 🚀 Stage 4 Quick Start Guide

Get the web dashboard running in under 2 minutes!

## Step 1: Install Dependencies

```bash
pip install Flask Jinja2
```

## Step 2: Generate Metrics

```powershell
# Windows - Run once to create metrics
.\scripts\main_monitor.ps1
```

```bash
# Linux/macOS
bash scripts/main_monitor.sh
```

## Step 3: Start Web Dashboard

```bash
python dashboard_web.py
```

You should see:
```
============================================================
   System Monitor - Web Dashboard (Stage 4)
============================================================

🌐 Starting System Monitor Web Dashboard...
📊 Dashboard: http://localhost:5000
🔌 API Metrics: http://localhost:5000/api/metrics
🚨 API Alerts: http://localhost:5000/api/alerts
📄 API Reports: http://localhost:5000/api/reports
```

## Step 4: Open Browser

Visit: **http://localhost:5000**

## 🎉 That's It!

### What You Can Do:

✅ **View live metrics** - Auto-updates every 3 seconds  
✅ **Generate reports** - Click the "Generate Report" button  
✅ **Access API** - Use endpoints for automation  
✅ **Monitor remotely** - Access from any device on your network  

### Quick Tests:

```powershell
# Test API (PowerShell)
Invoke-RestMethod http://localhost:5000/api/metrics
Invoke-RestMethod http://localhost:5000/api/alerts

# Generate report via API
Invoke-RestMethod -Uri http://localhost:5000/api/reports/generate -Method POST
```

### Common Options:

```bash
# Use different port
python dashboard_web.py --port 8080

# Enable debug mode
python dashboard_web.py --debug

# Allow network access
python dashboard_web.py --host 0.0.0.0
```

## 📚 Need More Details?

See: `docs/STAGE4_COMPLETE.md` for comprehensive documentation

## ✅ Verify Installation

```bash
python verify_stage4.py
```

Should show: `✅ Stage 4 verification: COMPLETE`

---

**Enjoy your web dashboard!** 🎊
