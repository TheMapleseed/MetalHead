#!/bin/bash

# MetalHead Engine Test Script
# Runs the engine and verifies it's working correctly with measurable outputs

set -e

PROJECT_NAME="MetalHead"
APP_NAME="MetalHead.app"
INSTALL_DIR="/Applications"
APP_PATH="${INSTALL_DIR}/${APP_NAME}"
LOG_DIR="./test-logs"
LOG_FILE="${LOG_DIR}/engine_test_$(date +%Y%m%d_%H%M%S).log"
METRICS_FILE="${LOG_DIR}/metrics_$(date +%Y%m%d_%H%M%S).json"
TEST_DURATION=${1:-10}  # Default 10 seconds, can be overridden

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 MetalHead Engine Test Script${NC}"
echo "=================================="
echo ""

# Create log directory
mkdir -p "$LOG_DIR"

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}❌ Error: ${APP_NAME} not found in ${INSTALL_DIR}${NC}"
    echo "   Run: ./scripts/install.sh first"
    exit 1
fi

echo -e "${GREEN}✅ Found: ${APP_PATH}${NC}"
echo ""

# Clean up any existing instances
echo "🧹 Cleaning up any existing instances..."
pkill -f "MetalHead" || true
sleep 1

# Start the app with logging
echo -e "${BLUE}🚀 Starting MetalHead engine...${NC}"
echo "   Test duration: ${TEST_DURATION} seconds"
echo "   Log file: ${LOG_FILE}"
echo ""

# Run the app and capture output
"${APP_PATH}/Contents/MacOS/MetalHead" > "$LOG_FILE" 2>&1 &
APP_PID=$!

# Wait a moment for initialization
sleep 3

# Check if process is still running
if ! kill -0 $APP_PID 2>/dev/null; then
    echo -e "${RED}❌ Engine crashed during startup${NC}"
    echo "   Check log file: ${LOG_FILE}"
    tail -50 "$LOG_FILE"
    exit 1
fi

echo -e "${GREEN}✅ Engine started (PID: ${APP_PID})${NC}"
echo ""

# Monitor the engine for the test duration
echo -e "${BLUE}📊 Monitoring engine performance...${NC}"
START_TIME=$(date +%s)
END_TIME=$((START_TIME + TEST_DURATION))

# Extract metrics from logs in real-time
FRAME_COUNT=0
INIT_SUCCESS=false
RENDERING_ACTIVE=false
ERROR_COUNT=0

while [ $(date +%s) -lt $END_TIME ]; do
    if ! kill -0 $APP_PID 2>/dev/null; then
        echo -e "${RED}❌ Engine process died unexpectedly${NC}"
        break
    fi
    
    # Parse log file for key metrics (prefer structured METRIC: lines)
    if [ -f "$LOG_FILE" ]; then
        # Check for initialization success (structured metrics)
        if grep -q "METRIC:.*engine_initialized\|METRIC:.*initialization_complete\|✅.*initialized\|✅.*Engine initialized" "$LOG_FILE"; then
            INIT_SUCCESS=true
        fi
        
        # Check for rendering activity (structured metrics)
        if grep -q "METRIC:.*render_called\|METRIC:.*frame_rendered\|Frame.*rendered\|🎬.*render" "$LOG_FILE"; then
            RENDERING_ACTIVE=true
        fi
        
        # Count frames from structured metrics (count render_called metrics)
        FRAME_COUNT=$(grep -c "METRIC:.*render_called" "$LOG_FILE" 2>/dev/null || echo "0")
        
        # Count errors (ensure single value)
        ERROR_COUNT=$(grep -c "METRIC:.*error\|❌\|ERROR\|error:" "$LOG_FILE" 2>/dev/null | head -1 || echo "0")
    fi
    
    sleep 1
done

# Stop the engine
echo ""
echo -e "${BLUE}🛑 Stopping engine...${NC}"
kill $APP_PID 2>/dev/null || true
wait $APP_PID 2>/dev/null || true
sleep 1

# Final log analysis
echo ""
echo -e "${BLUE}📊 Analyzing test results...${NC}"
echo ""

# Extract final metrics from log (prefer structured METRIC: lines)
FINAL_FRAME_COUNT=$(grep -c "METRIC:.*render_called" "$LOG_FILE" 2>/dev/null || echo "0")
FINAL_ERROR_COUNT=$(grep -c "METRIC:.*error\|❌\|ERROR\|error:" "$LOG_FILE" 2>/dev/null | head -1 || echo "0")
FPS_MENTIONS=$(grep -c "METRIC:.*fps=\|FPS\|fps" "$LOG_FILE" 2>/dev/null || echo "0")
INIT_MENTIONS=$(grep -c "METRIC:.*engine_initialized\|METRIC:.*initialization_complete\|✅.*initialized\|Engine initialized" "$LOG_FILE" 2>/dev/null || echo "0")
RENDER_MENTIONS=$(grep -c "METRIC:.*render_called\|render\|Rendering" "$LOG_FILE" 2>/dev/null || echo "0")

# Create metrics JSON
cat > "$METRICS_FILE" << EOF
{
  "test_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "test_duration_seconds": ${TEST_DURATION},
  "engine_status": {
    "initialized": ${INIT_SUCCESS},
    "rendering_active": ${RENDERING_ACTIVE},
    "process_exited_cleanly": false
  },
  "metrics": {
    "frames_rendered": ${FINAL_FRAME_COUNT},
    "errors_detected": ${FINAL_ERROR_COUNT},
    "fps_mentions": ${FPS_MENTIONS},
    "initialization_mentions": ${INIT_MENTIONS},
    "rendering_mentions": ${RENDER_MENTIONS},
    "test_objects_added": $(grep -c "METRIC:.*test_objects_added" "$LOG_FILE" 2>/dev/null || echo "0")
  },
  "log_file": "${LOG_FILE}",
  "test_result": "$([ "$INIT_SUCCESS" = true ] && [ "$FINAL_ERROR_COUNT" -eq 0 ] && echo "PASS" || echo "FAIL")"
}
EOF

# Print results
echo "═══════════════════════════════════════"
echo -e "${BLUE}📈 Test Results Summary${NC}"
echo "═══════════════════════════════════════"
echo ""
echo -e "Test Duration:     ${TEST_DURATION} seconds"
echo -e "Log File:          ${LOG_FILE}"
echo -e "Metrics File:      ${METRICS_FILE}"
echo ""

echo -e "${BLUE}Engine Status:${NC}"
if [ "$INIT_SUCCESS" = true ]; then
    echo -e "  Initialization:  ${GREEN}✅ SUCCESS${NC}"
else
    echo -e "  Initialization:  ${RED}❌ FAILED${NC}"
fi

if [ "$RENDERING_ACTIVE" = true ]; then
    echo -e "  Rendering:       ${GREEN}✅ ACTIVE${NC}"
else
    echo -e "  Rendering:       ${YELLOW}⚠️  NOT DETECTED${NC}"
fi

echo ""
echo -e "${BLUE}Performance Metrics:${NC}"
echo -e "  Frames Rendered:  ${FINAL_FRAME_COUNT}"
echo -e "  Errors Found:    ${FINAL_ERROR_COUNT}"
echo -e "  FPS Mentions:   ${FPS_MENTIONS}"
echo -e "  Render Calls:   ${RENDER_MENTIONS}"

echo ""
echo "═══════════════════════════════════════"

# Determine test result
if [ "$INIT_SUCCESS" = true ] && [ "$FINAL_ERROR_COUNT" -eq 0 ] && [ "$FINAL_FRAME_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ TEST PASSED${NC}"
    echo ""
    echo "Engine is running correctly with:"
    echo "  - Successful initialization"
    echo "  - Active rendering"
    echo "  - No errors detected"
    echo "  - Frames being rendered"
    exit 0
else
    echo -e "${RED}❌ TEST FAILED${NC}"
    echo ""
    echo "Issues detected:"
    [ "$INIT_SUCCESS" = false ] && echo "  - Initialization failed"
    [ "$FINAL_ERROR_COUNT" -gt 0 ] && echo "  - Errors found in logs"
    [ "$FINAL_FRAME_COUNT" -eq 0 ] && echo "  - No frames rendered"
    echo ""
    echo "Check log file for details: ${LOG_FILE}"
    exit 1
fi

