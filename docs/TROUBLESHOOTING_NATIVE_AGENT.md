# Native Agent Troubleshooting Guide

## Problem: start-universal.sh Stuck on "Waiting for Native Agent..."

### Quick Diagnosis

Run this diagnostic script:
```bash
bash diagnose_native_agent.sh
```

---

## Most Common Cause: Windows Security Block

When you transfer files to another Windows machine, Windows **automatically blocks executables** for security.

### Solution 1: Unblock via GUI (Easiest)

1. Navigate to `Host2\bin\` folder
2. Right-click `host-agent-windows.exe`
3. Click **Properties**
4. At the bottom, check **"Unblock"** checkbox
5. Click **OK**

![Windows Unblock File](https://learn.microsoft.com/en-us/windows/security/threat-protection/images/unblock-file.png)

### Solution 2: Unblock via PowerShell (Fast)

**Run as Administrator:**
```powershell
# Navigate to project
cd C:\path\to\system-monitor-project-Batch

# Unblock the binary
Unblock-File -Path "Host2\bin\host-agent-windows.exe"

# Verify
Get-Item "Host2\bin\host-agent-windows.exe" | Select-Object *
```

### Solution 3: Unblock Entire Project

If you transferred the whole folder, unblock everything:
```powershell
# Run as Administrator
Get-ChildItem -Path "C:\path\to\system-monitor-project-Batch" -Recurse | Unblock-File
```

---

## Other Possible Causes

### Cause 2: Port 8889 Already in Use

**Check:**
```powershell
netstat -ano | findstr :8889
```

**Solution:**
- Kill the process using that port
- Or change the port in `Host2/main.go` (line 588) and rebuild

### Cause 3: Antivirus Blocking

**Symptoms:**
- Binary starts then immediately closes
- No error messages

**Solution:**
- Add `host-agent-windows.exe` to antivirus exceptions
- Windows Defender: Settings → Virus & threat protection → Exclusions
- Add: `C:\path\to\system-monitor-project-Batch\Host2\bin\host-agent-windows.exe`

### Cause 4: Missing Binary

**Check:**
```bash
ls -lh Host2/bin/host-agent-windows.exe
```

**Solution:**
```bash
cd Host2
bash build.sh  # Requires Go installed
```

OR download pre-built from GitHub releases

### Cause 5: Firewall Blocking Port

**Solution:**
```powershell
# Run as Administrator
New-NetFirewallRule -DisplayName "System Monitor Native Agent" `
  -Direction Inbound -LocalPort 8889 -Protocol TCP -Action Allow
```

---

## Manual Testing

### Test 1: Run Binary Directly

**Windows (CMD):**
```cmd
cd Host2\bin
host-agent-windows.exe
```

**Expected Output:**
```
Starting Native Go Agent on port 8889...
Server running at http://localhost:8889
```

**If it works:** The issue is with start-universal.sh startup logic
**If it fails:** Check the error message

### Test 2: Check Health Endpoint

After starting the binary manually:
```bash
curl http://localhost:8889/health
```

**Expected:**
```json
{"status":"ok","version":"1.0.0"}
```

### Test 3: Check Logs

```bash
cat /tmp/native-agent.log
# Or check Windows Event Viewer for crash logs
```

---

## Emergency Workaround: Skip Native Agent

If you can't fix it and need the dashboard running:

**Edit start-universal.sh** (around line 220):
```bash
# Comment out the Native Agent section
# echo -e "${BLUE}[1.5/4]${NC} Starting Native Go Agent..."
# ... (comment entire Native Agent block)

# Jump straight to Step 2
echo -e "${BLUE}[2/4]${NC} Starting Dashboard..."
```

**Result:** Dashboard will work but only show Host API metrics (no Go agent data)

---

## Checklist for Friend

When sending the project folder, tell your friend to:

1. **Unblock the binary** (Most important!)
   ```powershell
   Unblock-File -Path "Host2\bin\host-agent-windows.exe"
   ```

2. **Install prerequisites:**
   - Docker Desktop
   - Python 3
   - Git

3. **Run diagnostic:**
   ```bash
   bash diagnose_native_agent.sh
   ```

4. **Start system:**
   ```bash
   bash start-universal.sh
   ```

---

## Still Not Working?

1. **Run diagnostic script:**
   ```bash
   bash diagnose_native_agent.sh
   ```

2. **Check the output** and share the error messages

3. **Common final fixes:**
   - Restart Docker Desktop
   - Restart WSL2: `wsl --shutdown`
   - Run as Administrator
   - Rebuild binary: `cd Host2 && bash build.sh`

---

## Contact

If none of these work, provide:
1. Output of `diagnose_native_agent.sh`
2. Screenshot of where it hangs
3. Output of `netstat -ano | findstr :8889`
4. Windows version: `winver`
