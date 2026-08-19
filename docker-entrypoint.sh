#!/bin/bash
set -e

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 System Monitor Dashboard - Starting Up"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Configuration:"
echo "   • Dashboard Port: 5000"
echo "   • Host API: ${HOST_API_URL:-http://host.docker.internal:8888}"
echo "   • JSON Logging: ${JSON_LOGGING_ENABLED:-false}"
echo "   • Log Interval: ${JSON_LOG_INTERVAL:-10}s"
echo ""
echo "🌡️  GPU Detection:"

# Check NVIDIA
if command -v nvidia-smi &> /dev/null; then
    echo "   ✓ NVIDIA GPU tools available"
else
    echo "   ✗ NVIDIA tools not found"
fi

# Check AMD
if command -v radeontop &> /dev/null; then
    echo "   ✓ AMD GPU tools (radeontop) available"
else
    echo "   ✗ AMD tools not found"
fi

# Check Intel
if command -v intel_gpu_top &> /dev/null; then
    echo "   ✓ Intel GPU tools available"
else
    echo "   ✗ Intel tools not found"
fi

# Check sensors
if command -v sensors &> /dev/null; then
    echo "   ✓ lm-sensors available"
else
    echo "   ✗ lm-sensors not found"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 Web Dashboard: http://localhost:5000"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ Starting Flask Application..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# If command is provided, execute it; otherwise start Flask
if [ $# -eq 0 ]; then
    exec python3 -m flask --app web.app run --host 0.0.0.0 --port 5000
else
    exec "$@"
fi
