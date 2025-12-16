# Quick HTML Integration Guide

This file shows exactly what to add to `templates/dashboard.html` to complete the Chart.js integration.

---

## STEP 1: Add Chart.js CDN

**Location**: In the `<head>` section, after the `styles.css` link

**Add this line**:
```html
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
```

**Full context**:
```html
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>System Monitor - Web Dashboard</title>
    <link rel="stylesheet" href="{{ url_for('static', filename='css/styles.css') }}">
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
    <link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>📊</text></svg>">
</head>
```

---

## STEP 2: Replace JavaScript File

**Location**: At the bottom of the file, before `</body>`

**Find this**:
```html
<script src="{{ url_for('static', filename='js/dashboard.js') }}"></script>
```

**Replace with**:
```html
<script src="{{ url_for('static', filename='js/dashboard-enhanced.js') }}"></script>
```

---

## STEP 3: Add Chart Canvases

Add `<canvas>` elements inside each panel. Here are the exact locations:

### CPU Chart

**Location**: Inside the CPU panel, after the `.metric-details` div

**Add**:
```html
                </div>  <!-- End of metric-details -->
            </div>  <!-- End of panel-body -->
            
            <!-- ADD THIS: -->
            <div class="chart-container">
                <canvas id="cpuChart"></canvas>
            </div>
            
        </div>  <!-- End of panel -->
```

### Memory Chart

**Location**: Inside the Memory panel, after the `.metric-details` div

**Add**:
```html
                </div>  <!-- End of metric-details -->
            </div>  <!-- End of panel-body -->
            
            <!-- ADD THIS: -->
            <div class="chart-container">
                <canvas id="memoryChart"></canvas>
            </div>
            
        </div>  <!-- End of panel -->
```

### Disk Chart

**Location**: Inside the Disk panel, after disk list

**Add**:
```html
                </div>  <!-- End of disk list -->
            </div>  <!-- End of panel-body -->
            
            <!-- ADD THIS: -->
            <div class="chart-container">
                <canvas id="diskChart"></canvas>
            </div>
            
        </div>  <!-- End of panel -->
```

### Network Chart

**Location**: Inside the Network panel, after network details

**Add**:
```html
                </div>  <!-- End of metric-details -->
            </div>  <!-- End of panel-body -->
            
            <!-- ADD THIS: -->
            <div class="chart-container">
                <canvas id="networkChart"></canvas>
            </div>
            
        </div>  <!-- End of panel -->
```

### Temperature Chart (NEW PANEL)

**Location**: Add as a new panel in the grid (after GPU panel or wherever fits)

**Add**:
```html
            <!-- Temperature Panel -->
            <div class="panel">
                <div class="panel-header">
                    <h2>🌡️ Temperature</h2>
                </div>
                <div class="panel-body">
                    <div class="metric-details">
                        <div class="detail-item">
                            <span class="detail-label">CPU Temp:</span>
                            <span class="detail-value" id="tempCPU">-</span>
                        </div>
                        <div class="detail-item">
                            <span class="detail-label">GPU Temp:</span>
                            <span class="detail-value" id="tempGPU">-</span>
                        </div>
                        <div class="detail-item">
                            <span class="detail-label">CPU Vendor:</span>
                            <span class="detail-value" id="tempCPUVendor">-</span>
                        </div>
                        <div class="detail-item">
                            <span class="detail-label">GPU Vendor:</span>
                            <span class="detail-value" id="tempGPUVendor">-</span>
                        </div>
                    </div>
                </div>
                <div class="chart-container">
                    <canvas id="temperatureChart"></canvas>
                </div>
            </div>
```

---

## STEP 4: Add CSS Styles

**Location**: Add to `static/css/styles.css` at the end

**Add**:
```css
/* Chart container styling */
.chart-container {
    position: relative;
    height: 250px;
    width: 100%;
    padding: 15px;
    margin-top: 15px;
    background: rgba(31, 41, 55, 0.5);
    border-radius: 8px;
}

/* Refresh button animation */
@keyframes rotate {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
}

.rotating {
    animation: rotate 1s linear;
}

/* Status indicator styles */
.status-indicator {
    display: flex;
    align-items: center;
    font-size: 0.9rem;
    color: #9ca3af;
}

.status-dot {
    display: inline-block;
    width: 10px;
    height: 10px;
    border-radius: 50%;
    margin-right: 8px;
}

.status-connected {
    background-color: #10b981;
    box-shadow: 0 0 10px #10b981;
}

.status-error {
    background-color: #ef4444;
    box-shadow: 0 0 10px #ef4444;
}

.status-connecting {
    background-color: #f59e0b;
    box-shadow: 0 0 10px #f59e0b;
    animation: pulse 2s infinite;
}

@keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.5; }
}

/* Progress bar color classes */
.progress-low {
    background: linear-gradient(90deg, #10b981, #34d399);
}

.progress-medium {
    background: linear-gradient(90deg, #f59e0b, #fbbf24);
}

.progress-high {
    background: linear-gradient(90deg, #ef4444, #f87171);
}
```

---

## Testing After Integration

1. **Build and start**:
   ```bash
   docker-compose down
   docker-compose up --build -d
   ```

2. **Start JSON logger**:
   ```bash
   python3 web/json_logger.py &
   ```

3. **Open dashboard**:
   ```bash
   open http://localhost:5000
   ```

4. **Verify**:
   - ✅ 5 Chart.js graphs visible
   - ✅ Auto-refresh every 30 seconds
   - ✅ Refresh button works and rotates
   - ✅ Status indicator shows "Connected"
   - ✅ Temperature data displays
   - ✅ No console errors

---

## Troubleshooting

### Charts not showing
- Check browser console for errors
- Verify Chart.js CDN loaded: `typeof Chart !== 'undefined'`
- Check canvas IDs match exactly

### Auto-refresh not working
- Check dashboard-enhanced.js is loaded
- Verify `/api/metrics` endpoint responds
- Check browser console for errors

### Temperature shows "N/A"
- Run: `bash Host/scripts/temperature_monitor.sh`
- Check if nvidia-smi, lm-sensors available
- Review temperature detection fallback methods

---

## Summary

**Total changes**: 4 steps
- Add 1 CDN link
- Replace 1 JS file reference
- Add 5 canvas elements
- Add ~50 lines of CSS

**Time estimate**: 10-15 minutes

See `DASHBOARD_ENHANCEMENT_GUIDE.md` for full documentation.
