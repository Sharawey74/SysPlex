# Stage 3 Terminal Dashboard - Quick Start Guide

## 🚀 Get Started in 3 Steps

### Step 1: Install Dependencies (1 minute)

```powershell
cd c:\Users\DELL\Desktop\system-monitor-project
pip install -r requirements.txt
```

**Expected output:**
```
Successfully installed rich-13.x.x psutil-5.x.x pytest-7.x.x ...
```

---

### Step 2: Start Monitoring (Terminal 1)

```powershell
# Generate metrics data
.\scripts\main_monitor.ps1
```

**This creates:** `data/metrics/current.json`

---

### Step 3: Launch Dashboard (Terminal 2)

```powershell
python dashboard_tui.py
```

**You'll see:**
```
┌─────────────────────────────────────────────────────────────┐
│ SYSTEM MONITOR DASHBOARD - [your-pc] [timestamp]           │
├─────────────────────────────────────────────────────────────┤
│ CPU: 45.2% [████████░░]    │  MEMORY: 8.5 GB / 16 GB       │
│ ...                         │  ...                           │
└─────────────────────────────────────────────────────────────┘
```

**Press Ctrl+C to exit.**

---

## ✅ Verify Installation

```powershell
# Run verification script
python verify_stage3.py
```

**Expected result:** 97.1% success rate (34/35 checks pass)

---

## 🧪 Run Tests

```powershell
# Run all tests
pytest tests/python/ -v

# With coverage
pytest tests/python/ --cov=core --cov=display
```

**Expected result:** 74 passed, 1 skipped

---

## 📖 Full Documentation

- **README:** `DASHBOARD_README.md` - Complete usage guide
- **Summary:** `STAGE3_SUMMARY.md` - Implementation details
- **API Docs:** Docstrings in each module

---

## 🆘 Troubleshooting

### Dashboard shows "N/A" for everything
**Solution:** Run `.\scripts\main_monitor.ps1` first to generate metrics

### "Module not found" errors
**Solution:** Ensure you're in the project root directory:
```powershell
cd c:\Users\DELL\Desktop\system-monitor-project
```

### Dependencies not installing
**Solution:** Update pip first:
```powershell
python -m pip install --upgrade pip
pip install -r requirements.txt
```

---

## 🎯 Success Criteria Checklist

- ✅ Dashboard updates every 2 seconds
- ✅ Progress bars show CPU/Memory/Disk usage
- ✅ Colors change: Green → Yellow → Red
- ✅ Alerts display at bottom
- ✅ Ctrl+C exits cleanly
- ✅ Tests pass (74/75)

---

## 📞 Support

For issues or questions, see:
- `DASHBOARD_README.md` - Detailed documentation
- `STAGE3_SUMMARY.md` - Implementation details
- Test files for usage examples

---

**That's it! You're ready to monitor your system in style. 🎉**
