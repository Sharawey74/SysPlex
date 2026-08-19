# 🌐 Stage 4: Web Dashboard + Reports - Complete Guide

## 📋 Overview

Stage 4 adds a browser-based web dashboard with real-time monitoring, RESTful API endpoints, and automated report generation in both HTML and Markdown formats.

## 🎯 What Was Built

### New Components

```
project/
├── web/                        # Web application module
│   ├── __init__.py            # Module initialization
│   ├── app.py                 # Flask web server + API routes
│   └── report_generator.py   # HTML/MD report generation
│
├── templates/                  # Jinja2 templates
│   ├── dashboard.html         # Main web dashboard UI
│   ├── report_template.html   # HTML report template
│   └── report_template.md     # Markdown report template
│
├── static/                     # Static assets
│   ├── css/
│   │   └── styles.css         # Dashboard styling
│   └── js/
│       └── dashboard.js       # Frontend logic + auto-refresh
│
├── reports/                    # Generated reports
│   ├── html/                  # HTML reports
│   └── markdown/              # Markdown reports
│
├── dashboard_web.py           # Web launcher script
└── verify_stage4.py           # Stage 4 verification
```

## 🚀 Quick Start

### 1. Install Dependencies

```bash
# Install Flask and web dependencies
pip install Flask Jinja2 Werkzeug MarkupSafe

# Or install all requirements
pip install -r requirements.txt
```

### 2. Generate Metrics (if not running)

```powershell
# Windows
.\scripts\main_monitor.ps1

# Unix/Linux/macOS
bash scripts/main_monitor.sh
```

### 3. Start Web Dashboard

```bash
python dashboard_web.py
```

### 4. Access Dashboard

Open your browser to:
- **Dashboard**: http://localhost:5000
- **API Metrics**: http://localhost:5000/api/metrics
- **API Alerts**: http://localhost:5000/api/alerts
- **API Reports**: http://localhost:5000/api/reports

## 🔌 API Endpoints

### GET /api/metrics
Returns current system metrics as JSON.

**Response:**
```json
{
  "success": true,
  "timestamp": "2025-12-08T11:23:45Z",
  "data": {
    "cpu": { "usage_percent": 15, ... },
    "memory": { "used_mb": 8192, ... },
    "disk": [...],
    "network": {...},
    "temperature": {...}
  }
}
```

### GET /api/alerts
Returns recent alerts (last 50).

**Response:**
```json
{
  "success": true,
  "timestamp": "2025-12-08T11:23:45Z",
  "count": 5,
  "data": [
    {
      "level": "warning",
      "metric": "cpu",
      "message": "High CPU usage",
      "value": 85,
      "timestamp": "2025-12-08T11:20:00Z"
    }
  ]
}
```

### GET /api/reports
Lists all generated reports.

**Response:**
```json
{
  "success": true,
  "count": 10,
  "data": [
    {
      "type": "html",
      "filename": "report_20251208_112345.html",
      "size": 15678,
      "created": "2025-12-08T11:23:45Z",
      "path": "reports/html/report_20251208_112345.html"
    }
  ]
}
```

### POST /api/reports/generate
Generate a new report (HTML + Markdown).

**Response:**
```json
{
  "success": true,
  "message": "Report generated successfully",
  "files": {
    "html": "reports/html/report_20251208_112345.html",
    "markdown": "reports/markdown/report_20251208_112345.md"
  }
}
```

### GET /api/reports/download/{type}/{filename}
Download a specific report file.

**Parameters:**
- `type`: "html" or "markdown"
- `filename`: Report filename

### GET /api/health
Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "service": "system-monitor-web",
  "timestamp": "2025-12-08T11:23:45Z"
}
```

## 📊 Dashboard Features

### Real-Time Monitoring
- **Auto-refresh**: Updates every 3 seconds via JavaScript polling
- **Live metrics**: CPU, Memory, Disk, Network, Temperature, GPU
- **Color coding**: 
  - 🟢 Green: < 60% (Good)
  - 🟡 Yellow: 60-80% (Warning)
  - 🔴 Red: > 80% (Critical)

### Panels

1. **System Info Bar**
   - Hostname, OS, Uptime, Platform

2. **CPU Panel**
   - Usage percentage with progress bar
   - Model, vendor, core count
   - Temperature

3. **Memory Panel**
   - Usage percentage with progress bar
   - Used, total, free, available

4. **Disk Panel**
   - All disk devices with progress bars
   - Device, filesystem, capacity, usage

5. **Network Panel**
   - Total RX/TX statistics
   - Top 3 active interfaces table

6. **Temperature Panel**
   - CPU temperature
   - GPU temperatures (if available)

7. **GPU Panel**
   - GPU vendor, model, type
   - Temperature and VRAM usage

8. **Alerts Section**
   - Recent 10 alerts
   - Color-coded by level (Critical, Warning, Info)
   - Alert count badges

### Interactive Features
- **Generate Report Button**: Creates HTML + MD reports
- **Refresh Button**: Manual refresh
- **Status Indicator**: Connection status with auto-update timestamp
- **Toast Notifications**: Success/error messages

## 📄 Report Generation

### Generating Reports

**Via Web UI:**
1. Click "📄 Generate Report" button
2. Reports are created in `reports/` directory
3. Toast notification confirms success

**Via API:**
```bash
# Using curl
curl -X POST http://localhost:5000/api/reports/generate

# Using PowerShell
Invoke-RestMethod -Uri http://localhost:5000/api/reports/generate -Method POST
```

### Report Contents

Both HTML and Markdown reports include:
- System information (OS, hostname, uptime)
- CPU metrics (usage, model, cores)
- Memory metrics (usage, total, free)
- Disk usage (all devices with progress)
- Network statistics (RX/TX, interfaces)
- Temperature monitoring (CPU, GPUs)
- GPU information (vendor, model, VRAM)
- Recent alerts (last 50)
- Summary statistics

### Report Files

**Naming format:** `report_YYYYMMDD_HHMMSS.[html|md]`

**Location:**
- HTML: `reports/html/`
- Markdown: `reports/markdown/`

**Example:**
```
reports/
├── html/
│   ├── report_20251208_112345.html
│   └── report_20251208_153020.html
└── markdown/
    ├── report_20251208_112345.md
    └── report_20251208_153020.md
```

## 🎨 Customization

### Change Port

```bash
python dashboard_web.py --port 8080
```

### Change Host (Network Access)

```bash
# Listen on all interfaces
python dashboard_web.py --host 0.0.0.0

# Listen on specific IP
python dashboard_web.py --host 192.168.1.100
```

### Enable Debug Mode

```bash
python dashboard_web.py --debug
```

### Custom Styling

Edit `static/css/styles.css` to customize:
- Colors and themes
- Panel layouts
- Progress bar styles
- Font sizes

### Custom JavaScript

Edit `static/js/dashboard.js` to modify:
- Refresh rate (default: 3 seconds)
- Data formatting
- UI interactions

## 🔧 Advanced Usage

### Embedding in Other Apps

```python
from web.app import app

# Use Flask app in your application
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

### Custom Report Templates

1. Copy `templates/report_template.html` or `.md`
2. Modify the Jinja2 template
3. Update `web/report_generator.py` to use new template

### Adding Custom Endpoints

Edit `web/app.py`:

```python
@app.route('/api/custom')
def custom_endpoint():
    return jsonify({
        'success': True,
        'data': 'Your custom data'
    })
```

## 🧪 Testing

### Manual Testing

1. **Dashboard**: Visit http://localhost:5000
   - ✅ Dashboard loads without errors
   - ✅ Metrics display correctly
   - ✅ Auto-refresh works (watch timestamp)
   - ✅ All panels populate with data

2. **API Endpoints**:
   ```powershell
   # Test metrics endpoint
   Invoke-RestMethod http://localhost:5000/api/metrics
   
   # Test alerts endpoint
   Invoke-RestMethod http://localhost:5000/api/alerts
   
   # Test health endpoint
   Invoke-RestMethod http://localhost:5000/api/health
   ```

3. **Report Generation**:
   - Click "Generate Report" button
   - Check `reports/html/` and `reports/markdown/`
   - Verify files were created

### Automated Verification

```bash
python verify_stage4.py
```

**Should show:**
- ✅ All file checks pass (11/11)
- ✅ Flask and Jinja2 installed
- ✅ Modules import successfully
- ✅ 100% verification complete

## 📈 Performance

### Metrics
- **Auto-refresh rate**: 3 seconds (configurable in JS)
- **API response time**: < 50ms (typical)
- **Dashboard load time**: < 500ms
- **Memory footprint**: ~50-100 MB (Flask process)

### Optimization Tips
- Increase refresh rate for slower systems: `const REFRESH_RATE = 5000;`
- Limit alert history: `load_alerts(limit=20)` in API
- Enable production WSGI server for better performance

## 🌐 Production Deployment

### Using Gunicorn (Unix/Linux)

```bash
pip install gunicorn
gunicorn -w 4 -b 0.0.0.0:5000 web.app:app
```

### Using Waitress (Windows)

```bash
pip install waitress
waitress-serve --host=0.0.0.0 --port=5000 web.app:app
```

### Reverse Proxy (Nginx)

```nginx
server {
    listen 80;
    server_name monitor.example.com;

    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## 🐛 Troubleshooting

### Dashboard doesn't load
- Check if Flask server is running: `netstat -ano | findstr :5000`
- Verify metrics file exists: `data/metrics/current.json`
- Check browser console for JavaScript errors

### API returns empty data
- Run system monitors first: `python universal.py`
- Check `data/metrics/current.json` exists and has valid JSON
- Verify file permissions

### Reports not generating
- Check `reports/` directory exists and is writable
- Verify Jinja2 templates exist in `templates/`
- Check Flask logs for template errors

### Port already in use
```bash
# Change port
python dashboard_web.py --port 8080

# Or kill existing process (Windows)
netstat -ano | findstr :5000
taskkill /PID <PID> /F
```

## 📚 Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Backend** | Flask 3.1 | Web server + RESTful API |
| **Frontend** | HTML5 + JavaScript | Browser UI |
| **Templating** | Jinja2 | Report generation |
| **Styling** | CSS3 | Dashboard design |
| **Data** | JSON | Metrics storage |
| **Auto-refresh** | JavaScript polling | Real-time updates |

## ✅ Success Criteria

Stage 4 is complete when:

1. ✅ Web dashboard loads at http://localhost:5000
2. ✅ Metrics update automatically every 3 seconds
3. ✅ All API endpoints return valid JSON
4. ✅ Reports generate successfully (HTML + MD)
5. ✅ Dashboard displays all metrics correctly
6. ✅ Alerts show with proper color coding
7. ✅ Verification script passes 100%

## 🎯 Stage Comparison

| Feature | Stage 3 (TUI) | Stage 4 (Web) |
|---------|--------------|---------------|
| **Interface** | Terminal | Browser |
| **Technology** | Rich library | Flask + HTML/JS |
| **Access** | Local SSH only | Network accessible |
| **Updates** | 2 seconds | 3 seconds |
| **Reports** | ❌ No | ✅ Yes (HTML + MD) |
| **API** | ❌ No | ✅ Yes (RESTful) |
| **Multi-client** | ❌ No | ✅ Yes |
| **Responsive** | Terminal-only | ✅ Yes (mobile-friendly) |

## 🚀 Next Steps

Stage 4 is complete! Possible enhancements:
- Add historical data visualization (charts)
- Implement WebSocket for real-time push updates
- Add user authentication
- Create multi-host monitoring aggregation
- Add email/webhook alerting
- Implement data export (CSV, Excel)

## 📝 Files Created

- `web/__init__.py` - Web module init
- `web/app.py` - Flask application (155 lines)
- `web/report_generator.py` - Report generation (212 lines)
- `templates/dashboard.html` - Main dashboard (220 lines)
- `templates/report_template.html` - HTML reports (170 lines)
- `templates/report_template.md` - Markdown reports (151 lines)
- `static/js/dashboard.js` - Frontend logic (391 lines)
- `static/css/styles.css` - Styling (616 lines)
- `dashboard_web.py` - Web launcher (89 lines)
- `verify_stage4.py` - Verification script (125 lines)

**Total:** 2,329 lines of new code for Stage 4! 🎉

---

**Stage 4 Status:** ✅ **COMPLETE**
