# 📊 System Monitor Report

**Generated:** {{ generated_at }}

---

## 📋 System Information

| Property | Value |
|----------|-------|
| **Hostname** | {{ metrics.system.hostname | default('N/A') }} |
| **Platform** | {{ metrics.platform | upper | default('N/A') }} |
| **OS** | {{ metrics.system.os | default('N/A') }} |
| **Kernel** | {{ metrics.system.kernel | default('N/A') }} |
| **Manufacturer** | {{ metrics.system.manufacturer | default('N/A') }} |
| **Model** | {{ metrics.system.model | default('N/A') }} |
| **Uptime** | {{ ((metrics.system.uptime_seconds | default(0) | int) / 3600) | round(1) }} hours |

---

## 🖥️ CPU Metrics

**Usage:** {{ metrics.cpu.usage_percent | default(0) }}% {% if (metrics.cpu.usage_percent | default(0)) >= 80 %}🔴{% elif (metrics.cpu.usage_percent | default(0)) >= 60 %}🟡{% else %}🟢{% endif %}

| Property | Value |
|----------|-------|
| **Vendor** | {{ metrics.cpu.vendor | default('N/A') }} |
| **Model** | {{ metrics.cpu.model | default('N/A') }} |
| **Logical Processors** | {{ metrics.cpu.logical_processors | default('N/A') }} |
| **Load Average (1m)** | {{ metrics.cpu.load_1 | default('N/A') }} |
| **Load Average (5m)** | {{ metrics.cpu.load_5 | default('N/A') }} |
| **Load Average (15m)** | {{ metrics.cpu.load_15 | default('N/A') }} |

---

## 🧠 Memory Metrics

{% set mem_percent = ((metrics.memory.used_mb | default(0) | float / metrics.memory.total_mb | default(1) | float) * 100) | round(1) if metrics.memory.total_mb else 0 %}
**Usage:** {{ mem_percent }}% {% if mem_percent >= 80 %}🔴{% elif mem_percent >= 60 %}🟡{% else %}🟢{% endif %}

| Property | Value |
|----------|-------|
| **Total** | {{ metrics.memory.total_mb | default(0) }} MB |
| **Used** | {{ metrics.memory.used_mb | default(0) }} MB |
| **Free** | {{ metrics.memory.free_mb | default(0) }} MB |
| **Available** | {{ metrics.memory.available_mb | default('N/A') }} MB |

---

## 💾 Disk Usage

| Device | Filesystem | Total | Used | Usage % | Status |
|--------|-----------|-------|------|---------|--------|
{% for disk in metrics.disk | default([]) -%}
| {{ disk.device | default('N/A') }} | {{ disk.filesystem | default('N/A') }} | {{ (disk.total_gb | default(0)) | round(2) }} GB | {{ (disk.used_gb | default(0)) | round(2) }} GB | {{ (disk.used_percent | default(0)) | round(1) }}% | {% if (disk.used_percent | default(0)) >= 80 %}🔴{% elif (disk.used_percent | default(0)) >= 60 %}🟡{% else %}🟢{% endif %} |
{% endfor %}

---

## 🌐 Network Statistics

| Property | Value |
|----------|-------|
| **Total RX** | {{ ((metrics.network.total_rx_bytes | default(0) | int) * 1) | format_bytes }} |
| **Total TX** | {{ ((metrics.network.total_tx_bytes | default(0) | int) * 1) | format_bytes }} |
| **Active Interfaces** | {{ (metrics.network.interfaces | default([])) | length }} |

### Network Interfaces

{% for iface in metrics.network.interfaces | default([]) %}
#### {{ iface.name | default('Unknown') }}

| Property | Value |
|----------|-------|
| **RX Bytes** | {{ ((iface.rx_bytes | default(0) | int) * 1) | format_bytes }} |
| **TX Bytes** | {{ ((iface.tx_bytes | default(0) | int) * 1) | format_bytes }} |
| **RX Packets** | {{ iface.rx_packets | default('N/A') }} |
| **TX Packets** | {{ iface.tx_packets | default('N/A') }} |

{% endfor %}

---

## 🌡️ Temperature Monitoring

| Component | Temperature | Status |
|-----------|-------------|--------|
| **CPU** | {{ metrics.temperature.cpu_celsius | default('N/A') }}°C | {% if metrics.temperature.cpu_celsius %}{% if metrics.temperature.cpu_celsius >= 80 %}🔴{% elif metrics.temperature.cpu_celsius >= 60 %}🟡{% else %}🟢{% endif %}{% else %}-{% endif %} |
{% for gpu in metrics.temperature.gpus | default([]) -%}
| **GPU {{ loop.index }}** ({{ gpu.vendor | default('Unknown') }} {{ gpu.model | default('Unknown') }}) | {{ gpu.temperature_celsius | default('N/A') }}°C | {% if (gpu.temperature_celsius | default(0)) >= 80 %}🔴{% elif (gpu.temperature_celsius | default(0)) >= 60 %}🟡{% else %}🟢{% endif %} |
{% endfor %}

---

## 🎮 GPU Information

{% if metrics.temperature.gpus %}
{% for gpu in metrics.temperature.gpus %}
### GPU {{ loop.index }}: {{ gpu.vendor | default('Unknown') }} {{ gpu.model | default('Unknown') }}

| Property | Value |
|----------|-------|
| **Vendor** | {{ gpu.vendor | default('N/A') }} |
| **Model** | {{ gpu.model | default('N/A') }} |
| **Type** | {{ gpu.type | default('N/A') }} |
| **Temperature** | {{ gpu.temperature_celsius | default('N/A') }}°C |
| **VRAM Used** | {{ gpu.vram_used_mb | default('N/A') }} MB |
| **VRAM Total** | {{ gpu.vram_total_mb | default('N/A') }} MB |

{% endfor %}
{% else %}
*No GPU information available*
{% endif %}

---

## 🚨 Recent Alerts

**Alert Summary:**
- 🔴 Critical: {{ alert_counts.critical }}
- 🟡 Warning: {{ alert_counts.warning }}
- 🔵 Info: {{ alert_counts.info }}

{% if alerts %}
{% for alert in alerts %}
### {{ loop.index }}. [{{ (alert.level | default('info')) | upper }}] {{ alert.metric | default('Unknown') }}

- **Message:** {{ alert.message | default('No message') }}
{% if alert.value -%}
- **Value:** {{ alert.value }}
{% endif -%}
{% if alert.threshold -%}
- **Threshold:** {{ alert.threshold }}
{% endif -%}
- **Timestamp:** {{ alert.timestamp | format_timestamp }}

{% endfor %}
{% else %}
*No alerts recorded*
{% endif %}

---

## 📊 Summary Statistics

| Metric | Value | Status |
|--------|-------|--------|
| **CPU Usage** | {{ summary.cpu_usage | default(0) }}% | {% if (summary.cpu_usage | default(0)) >= 80 %}🔴{% elif (summary.cpu_usage | default(0)) >= 60 %}🟡{% else %}🟢{% endif %} |
| **Memory Usage** | {{ summary.memory_usage | default(0) }}% | {% if (summary.memory_usage | default(0)) >= 80 %}🔴{% elif (summary.memory_usage | default(0)) >= 60 %}🟡{% else %}🟢{% endif %} |
| **Disk Count** | {{ summary.disk_count | default(0) }} | - |
| **Network Interfaces** | {{ summary.network_interfaces | default(0) }} | - |
| **GPU Count** | {{ summary.gpu_count | default(0) }} | - |
| **Max Temperature** | {{ summary.temperature_max | default(0) }}°C | {% if (summary.temperature_max | default(0)) >= 80 %}🔴{% elif (summary.temperature_max | default(0)) >= 60 %}🟡{% else %}🟢{% endif %} |

---

*Report generated by System Monitor v4.0 - Stage 4: Web Dashboard + Reports*
