/**
 * Observability Dashboard Logic
 * Symmetric Host (Windows) + Guest (WSL) Monitoring
 */

// State for Rate Calculations
let previousState = {
    win: { timestamp: null, net: {}, rx: 0, tx: 0 },
    wsl: { timestamp: null, net: {}, rx: 0, tx: 0 }
};

document.addEventListener('DOMContentLoaded', () => {
    fetchData();
    setInterval(fetchData, 2000); // 2s polling
});

async function fetchData() {
    try {
        const response = await fetch('/api/metrics/dual');
        const data = await response.json();
        if (data.success) {
            console.log('Fetched data:', {
                win: data.native ? 'Available' : 'Missing',
                wsl: data.legacy ? 'Available' : 'Missing',
                winNetwork: data.native?.network?.length || 0,
                wslNetwork: data.legacy?.network?.length || 0
            });
            updateObservabilityGrid(data.native, data.legacy);
        } else {
            console.error('API returned success=false:', data);
        }
    } catch (e) {
        console.error("Fetch failed", e);
    }
}

function updateObservabilityGrid(winData, wslData) {
    if (winData) renderHostColumn(winData);
    if (wslData) renderGuestColumn(wslData);
}

// 🧮 NETWORK RATE VALIDATION & CALCULATION (PER INTERFACE)
function calculateNetworkRates(key, currentNets) {
    const now = new Date();
    const prev = previousState[key];

    let globalRxRate = 0;
    let globalTxRate = 0;
    let interfaceRates = {};

    // Map current for easy lookup & Global Sum
    const currentMap = {};
    let totalRx = 0;
    let totalTx = 0;

    if (currentNets) {
        currentNets.forEach(n => {
            currentMap[n.iface] = n;
            totalRx += n.rx_bytes;
            totalTx += n.tx_bytes;
        });
    }
    
    console.log(`[${key}] Network calc:`, {
        totalRx: (totalRx / 1024 / 1024).toFixed(2) + ' MB',
        totalTx: (totalTx / 1024 / 1024).toFixed(2) + ' MB',
        hasPrev: !!prev.timestamp,
        interfaces: Object.keys(currentMap).join(', ')
    });

    // 1. Persistence Check: If global match, hold stats
    if (prev.timestamp && prev.rx === totalRx && prev.tx === totalTx) {
        return {
            globalRxRate: prev.lastGlobalRx || 0,
            globalTxRate: prev.lastGlobalTx || 0,
            interfaceRates: prev.lastInterfaceRates || {}
        };
    }

    if (prev.timestamp) {
        const timeDelta = (now - prev.timestamp) / 1000;
        
        console.log(`[${key}] Time delta: ${timeDelta.toFixed(2)}s`);

        if (timeDelta > 0 && timeDelta < 20) {
            // Global Rate
            const gRxDiff = totalRx - prev.rx;
            const gTxDiff = totalTx - prev.tx;
            if (gRxDiff >= 0) globalRxRate = gRxDiff / timeDelta;
            if (gTxDiff >= 0) globalTxRate = gTxDiff / timeDelta;
            
            console.log(`[${key}] Rates calculated:`, {
                rxRate: formatRate(globalRxRate),
                txRate: formatRate(globalTxRate),
                rxDiff: (gRxDiff / 1024).toFixed(2) + ' KB',
                txDiff: (gTxDiff / 1024).toFixed(2) + ' KB'
            });

            // Per-Interface Rate
            if (prev.net) {
                for (const [iface, n] of Object.entries(currentMap)) {
                    const old = prev.net[iface];
                    if (old) {
                        const rxDiff = n.rx_bytes - old.rx_bytes;
                        const txDiff = n.tx_bytes - old.tx_bytes;
                        interfaceRates[iface] = {
                            rx: rxDiff >= 0 ? rxDiff / timeDelta : 0,
                            tx: txDiff >= 0 ? txDiff / timeDelta : 0
                        };
                    }
                }
            }
        }
    }

    // Update State
    previousState[key] = {
        timestamp: now,
        rx: totalRx,
        tx: totalTx,
        net: currentMap,
        lastGlobalRx: globalRxRate,
        lastGlobalTx: globalTxRate,
        lastInterfaceRates: interfaceRates
    };

    return { globalRxRate, globalTxRate, interfaceRates };
}

// ============================================
// WINDOWS HOST RENDERER
// ============================================
function renderHostColumn(data) {
    // CPU
    const cpuName = data.cpu.model || data.cpu.brand || 'Unknown CPU';
    setText('win-cpu-model', cpuName);
    setText('win-cpu-val', `${(data.cpu.usage_percent || 0).toFixed(1)}%`);

    // Show both physical and logical cores
    const logicalCores = data.cpu.logical_processors || 8;
    const physicalCores = data.cpu.physical_processors || Math.floor(logicalCores / 2);
    setText('win-cpu-cores', `${physicalCores} Physical | ${logicalCores} Logical`);
    
    // CPU Temperature (from temperature section)
    if (data.temperature && data.temperature.cpu_celsius > 0) {
        setText('win-cpu-temp', `${data.temperature.cpu_celsius}°C`);
    } else {
        setText('win-cpu-temp', 'N/A');
    }

    // Memory
    setText('win-mem-val', `${(data.memory.usage_percent || 0).toFixed(1)}%`);
    setText('win-mem-detail', `${(data.memory.used_mb / 1024).toFixed(1)} / ${(data.memory.total_mb / 1024).toFixed(1)} GB`);

    // Storage
    const validDisks = (data.disk || []).filter(d => /^[CDE]:/.test(d.device));
    renderDiskList('win-disk-list', validDisks);

    // Network (Calculated Rates)
    const { globalRxRate, globalTxRate, interfaceRates } = calculateNetworkRates('win', data.network);
    setText('win-net-rx', formatRate(globalRxRate));
    setText('win-net-tx', formatRate(globalTxRate));
    renderNetworkList('win-net-list', data.network, interfaceRates);

    // GPU
    renderGPUList('win-gpu-list', data.gpu);

    setText('win-host', data.system.hostname);
    setText('win-os', data.system.os);
    setText('win-uptime', formatUptime(data.system.uptime_seconds));
    setText('win-kernel', data.system.kernel);
}

// ============================================
// WSL GUEST RENDERER
// ============================================
function renderGuestColumn(data) {
    // CPU
    const cpuName = data.cpu.model || data.cpu.brand || 'Unknown CPU';
    setText('wsl-cpu-model', cpuName);
    setText('wsl-cpu-val', `${(data.cpu.usage_percent || 0).toFixed(1)}%`);

    let load = 'N/A';
    if (data.cpu.load_1 !== undefined) {
        load = `${data.cpu.load_1.toFixed(2)} / ${data.cpu.load_5.toFixed(2)} / ${data.cpu.load_15.toFixed(2)}`;
    }
    setText('wsl-load', `Load: ${load}`);
        // Show logical cores
    const cores = data.cpu.logical_processors || '?';
    setText('wsl-cpu-cores', `${cores} vCPUs`);
        // CPU Temperature (from temperature section)
    if (data.temperature && data.temperature.cpu_celsius > 0) {
        setText('wsl-cpu-temp', `${data.temperature.cpu_celsius}°C`);
    } else {
        setText('wsl-cpu-temp', 'N/A');
    }

    setText('wsl-mem-val', `${(data.memory.usage_percent || 0).toFixed(1)}%`);
    setText('wsl-mem-detail', `${(data.memory.used_mb / 1024).toFixed(1)} / ${(data.memory.total_mb / 1024).toFixed(1)} GB`);

    // Storage
    const wslDisks = (data.disk || []).filter(d =>
        d.device === '/' ||
        (d.device.startsWith('/mnt/') && !d.device.includes('docker') && !d.device.includes('wslg'))
    );
    renderDiskList('wsl-disk-list', wslDisks);

    // Network
    const { globalRxRate, globalTxRate, interfaceRates } = calculateNetworkRates('wsl', data.network);
    setText('wsl-net-rx', formatRate(globalRxRate));
    setText('wsl-net-tx', formatRate(globalTxRate));
    renderNetworkList('wsl-net-list', data.network, interfaceRates);

    renderGPUList('wsl-gpu-list', data.gpu);

    setText('wsl-host', data.system.hostname);
    setText('wsl-os', data.system.os);
    setText('wsl-uptime', formatUptime(data.system.uptime_seconds));
    setText('wsl-kernel', data.system.kernel);
}

// ============================================
// HELPER FUNCTIONS
// ============================================

function renderDiskList(containerId, disks) {
    const el = document.getElementById(containerId);
    if (!el) return;
    el.innerHTML = disks.map(d => {
        const color = d.used_percent > 90 ? '#ef4444' : (d.used_percent > 70 ? '#f59e0b' : '#6366f1');
        return `
        <div class="list-item" style="display:block;">
            <div style="display:flex; justify-content:space-between;">
                <span style="color:#e2e8f0; font-weight:500;">${d.device}</span>
                <span style="color:${color}; font-weight:bold;">${d.used_percent.toFixed(1)}%</span>
            </div>
            <div class="disk-bar-bg"><div class="disk-bar-fill" style="width:${d.used_percent}%; background:${color};"></div></div>
            <div style="font-size:0.75rem; color:#64748b; margin-top:2px;">${d.used_gb.toFixed(1)} GB used of ${d.total_gb.toFixed(1)} GB</div>
        </div>`;
    }).join('');
}

function renderGPUList(containerId, gpuData) {
    const el = document.getElementById(containerId);
    if (!el) return;
    if (!gpuData || !gpuData.devices || gpuData.devices.length === 0) {
        el.innerHTML = '<div style="color:#64748b; padding:5px;">No GPU Detected</div>';
        return;
    }
    el.innerHTML = gpuData.devices.map(g => {
        const temp = (g.temperature_celsius && g.temperature_celsius > 0) ? `${g.temperature_celsius}°C` : 'N/A';
        const tempColor = g.temperature_celsius > 80 ? '#ef4444' : (g.temperature_celsius > 60 ? '#f59e0b' : '#22c55e');
        const mem = g.memory_total_mb ? `${(g.memory_used_mb || 0)}/${g.memory_total_mb} MB` : 'N/A';
        return `
        <div class="list-item">
            <div>
                <div style="color:#cbd5e1; font-weight:600;">${g.model || g.vendor || 'GPU'}</div>
                <div style="color:#64748b; font-size:0.75rem;">
                    ${g.vendor} • Load: ${g.utilization_percent || 0}% • Mem: ${mem}
                </div>
            </div>
            <div style="color:${tempColor}; font-weight:bold; font-size:1.1rem;">${temp}</div>
        </div>`;
    }).join('');
}

function renderNetworkList(containerId, nets, rates) {
    const el = document.getElementById(containerId);
    if (!el) return;
    if (!nets) return;

    // Filter active interfaces only (bytes > 0)
    const active = nets.filter(n => (n.rx_bytes + n.tx_bytes) > 0)
        .sort((a, b) => (b.rx_bytes + b.tx_bytes) - (a.rx_bytes + a.tx_bytes));

    el.innerHTML = active.map(n => {
        const r = rates && rates[n.iface] ? rates[n.iface] : { rx: 0, tx: 0 };
        // Clean display (don't show 0.00 B/s if truly idle, just show 0 MB/s or similar? 
        // User asked for Actual Numbers, so we show what we calc.)

        return `
        <div class="list-item">
            <div>
                <span style="color:#e2e8f0; font-weight:500;">${n.iface}</span>
            </div>
            <div style="font-size: 0.75rem; color: #94a3b8; text-align: right;">
                <span style="color:#22c55e;">↓ ${formatBytes(r.rx)}/s</span> 
                <span style="margin:0 4px; color:#475569;">|</span>
                <span style="color:#3b82f6;">↑ ${formatBytes(r.tx)}/s</span>
            </div>
        </div>`;
    }).join('');
}

// UTILS
function setText(id, txt) {
    const el = document.getElementById(id);
    if (el) el.textContent = txt;
}

function formatRate(bytesPerSec) {
    if (!bytesPerSec || bytesPerSec === 0) return '0.0 MB/s';
    const kb = bytesPerSec / 1024;
    if (kb < 1024) {
        return kb.toFixed(1) + ' KB/s';
    }
    const mb = bytesPerSec / (1024 * 1024);
    return mb.toFixed(2) + ' MB/s';
}

function formatBytes(b) {
    if (b === 0) return '0';
    const i = Math.floor(Math.log(b) / Math.log(1024));
    return (b / Math.pow(1024, i)).toFixed(1) + ['B', 'KB', 'MB', 'GB'][i];
}

function formatUptime(s) {
    if (!s) return '0h 0m';
    const h = Math.floor(s / 3600);
    const m = Math.floor((s % 3600) / 60);
    return `${h}h ${m}m`;
}

// Generate Report Function
async function generateReport() {
    try {
        const btn = event.target.closest('button');
        const originalText = btn.innerHTML;
        btn.disabled = true;
        btn.innerHTML = '<i class="bx bx-loader bx-spin"></i> Generating...';
        
        const response = await fetch('/api/reports/generate', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        });
        
        const result = await response.json();
        
        if (result.success) {
            alert('Report generated successfully!\n\nHTML: ' + result.files.html + '\nMarkdown: ' + result.files.markdown);
        } else {
            alert('Failed to generate report: ' + (result.error || 'Unknown error'));
        }
        
        btn.disabled = false;
        btn.innerHTML = originalText;
    } catch (error) {
        console.error('Report generation error:', error);
        alert('Error generating report: ' + error.message);
    }
}
