#!/bin/bash
# test-data-collection.sh
# Quick test to verify data is being collected

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Testing Data Collection"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

LATEST_FILE="Host/output/latest.json"

if [ ! -f "$LATEST_FILE" ]; then
    echo "❌ File not found: $LATEST_FILE"
    exit 1
fi

# Get initial timestamp
INITIAL_TIME=$(stat -c %Y "$LATEST_FILE" 2>/dev/null || stat -f %m "$LATEST_FILE" 2>/dev/null)
INITIAL_TS=$(grep -o '"timestamp":"[^"]*"' "$LATEST_FILE" | head -1)

echo "📊 Initial State:"
echo "   File: $LATEST_FILE"
echo "   Timestamp: $INITIAL_TS"
echo "   Modified: $(date -d @$INITIAL_TIME 2>/dev/null || date -r $INITIAL_TIME 2>/dev/null)"
echo ""
echo "⏳ Waiting 65 seconds for next collection..."
echo "   (Data collects every 60 seconds)"
echo ""

# Wait and show countdown
for i in {65..1}; do
    echo -ne "   Checking in ${i}s...\r"
    sleep 1
done

echo ""
echo ""

# Check new timestamp
NEW_TIME=$(stat -c %Y "$LATEST_FILE" 2>/dev/null || stat -f %m "$LATEST_FILE" 2>/dev/null)
NEW_TS=$(grep -o '"timestamp":"[^"]*"' "$LATEST_FILE" | head -1)

echo "📊 Current State:"
echo "   Timestamp: $NEW_TS"
echo "   Modified: $(date -d @$NEW_TIME 2>/dev/null || date -r $NEW_TIME 2>/dev/null)"
echo ""

# Compare
if [ "$INITIAL_TIME" -lt "$NEW_TIME" ]; then
    echo "✅ SUCCESS! Data is being collected!"
    echo "   File updated $(($NEW_TIME - $INITIAL_TIME)) seconds ago"
    echo ""
    echo "🎉 Monitor Loop is working correctly!"
else
    echo "❌ FAILED! Data has NOT been updated!"
    echo ""
    echo "Troubleshooting:"
    echo "   1. Check if monitor loop is running:"
    echo "      ps aux | grep host_monitor_loop"
    echo ""
    echo "   2. Check logs:"
    echo "      tail -f /tmp/host-monitor-loop.log"
    echo ""
    echo "   3. Check PID file:"
    echo "      cat /tmp/host-monitor-loop.pid"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
