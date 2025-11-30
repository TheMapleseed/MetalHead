#!/bin/bash

# MetalHead Log Parser Script
# Parses engine logs and extracts measurable metrics for verification

set -e

LOG_FILE=${1:-"./test-logs/engine_test_*.log"}
OUTPUT_FORMAT=${2:-"human"}  # human, json, csv

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}📊 MetalHead Log Parser${NC}"
echo "=========================="
echo ""

# Find most recent log file if pattern used
if [[ "$LOG_FILE" == *"*"* ]]; then
    LOG_FILE=$(ls -t ${LOG_FILE} 2>/dev/null | head -1)
fi

if [ ! -f "$LOG_FILE" ]; then
    echo -e "${RED}❌ Log file not found: ${LOG_FILE}${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Parsing: ${LOG_FILE}${NC}"
echo ""

# Extract metrics (prefer structured METRIC: lines)
INIT_SUCCESS=$(grep -c "METRIC:.*engine_initialized\|METRIC:.*initialization_complete\|✅.*initialized\|Engine initialized" "$LOG_FILE" 2>/dev/null || echo "0")
FRAME_COUNT=$(grep "METRIC:.*frame_rendered" "$LOG_FILE" 2>/dev/null | grep -o "count=[0-9]*" | grep -o "[0-9]*" | tail -1 || echo "0")
if [ "$FRAME_COUNT" = "0" ]; then
    FRAME_COUNT=$(grep -c "METRIC:.*frame_rendered\|Frame.*rendered" "$LOG_FILE" 2>/dev/null || echo "0")
fi
ERROR_COUNT=$(grep -c "METRIC:.*error\|❌\|ERROR\|error:" "$LOG_FILE" 2>/dev/null || echo "0")
WARNING_COUNT=$(grep -c "⚠️\|WARNING\|warning:" "$LOG_FILE" 2>/dev/null || echo "0")
FPS_MENTIONS=$(grep "METRIC:.*fps=" "$LOG_FILE" 2>/dev/null | grep -o "fps=[0-9]*" | grep -o "[0-9]*" | head -1 || echo "0")
if [ "$FPS_MENTIONS" = "0" ]; then
    FPS_MENTIONS=$(grep -o "FPS[^0-9]*[0-9]*" "$LOG_FILE" 2>/dev/null | grep -o "[0-9]*" | head -1 || echo "0")
fi
RENDER_CALLS=$(grep -c "METRIC:.*render_called\|render\|Rendering" "$LOG_FILE" 2>/dev/null || echo "0")
OBJECT_COUNT=$(grep "METRIC:.*sceneObjects=" "$LOG_FILE" 2>/dev/null | grep -o "sceneObjects=[0-9]*" | grep -o "[0-9]*" | head -1 || echo "0")
if [ "$OBJECT_COUNT" = "0" ]; then
    OBJECT_COUNT=$(grep -o "sceneObjects=[0-9]*" "$LOG_FILE" 2>/dev/null | grep -o "[0-9]*" | head -1 || echo "0")
fi

# Extract specific log lines
INIT_LINES=$(grep "initialized\|Initialization" "$LOG_FILE" 2>/dev/null | head -5)
ERROR_LINES=$(grep "❌\|ERROR\|error:" "$LOG_FILE" 2>/dev/null | head -10)
FPS_LINES=$(grep "FPS\|fps" "$LOG_FILE" 2>/dev/null | head -5)

# Output based on format
case "$OUTPUT_FORMAT" in
    json)
        cat << EOF
{
  "log_file": "${LOG_FILE}",
  "metrics": {
    "initialization_success": ${INIT_SUCCESS},
    "frames_rendered": ${FRAME_COUNT},
    "errors": ${ERROR_COUNT,
    "warnings": ${WARNING_COUNT},
    "fps": ${FPS_MENTIONS},
    "render_calls": ${RENDER_CALLS},
    "scene_objects": ${OBJECT_COUNT}
  },
  "status": "$([ "$INIT_SUCCESS" -gt 0 ] && [ "$ERROR_COUNT" -eq 0 ] && echo "PASS" || echo "FAIL")"
}
EOF
        ;;
    csv)
        echo "metric,value"
        echo "initialization_success,${INIT_SUCCESS}"
        echo "frames_rendered,${FRAME_COUNT}"
        echo "errors,${ERROR_COUNT}"
        echo "warnings,${WARNING_COUNT}"
        echo "fps,${FPS_MENTIONS}"
        echo "render_calls,${RENDER_CALLS}"
        echo "scene_objects,${OBJECT_COUNT}"
        ;;
    human|*)
        echo "═══════════════════════════════════════"
        echo -e "${BLUE}📈 Metrics Summary${NC}"
        echo "═══════════════════════════════════════"
        echo ""
        echo -e "${BLUE}Status:${NC}"
        if [ "$INIT_SUCCESS" -gt 0 ]; then
            echo -e "  Initialization:  ${GREEN}✅ SUCCESS${NC}"
        else
            echo -e "  Initialization:  ${RED}❌ FAILED${NC}"
        fi
        
        if [ "$ERROR_COUNT" -eq 0 ]; then
            echo -e "  Errors:           ${GREEN}✅ NONE${NC}"
        else
            echo -e "  Errors:           ${RED}❌ ${ERROR_COUNT} FOUND${NC}"
        fi
        echo ""
        echo -e "${BLUE}Performance:${NC}"
        echo -e "  Frames Rendered: ${FRAME_COUNT}"
        echo -e "  FPS:             ${FPS_MENTIONS}"
        echo -e "  Render Calls:    ${RENDER_CALLS}"
        echo -e "  Scene Objects:   ${OBJECT_COUNT}"
        echo ""
        echo -e "${BLUE}Issues:${NC}"
        echo -e "  Warnings:        ${WARNING_COUNT}"
        echo ""
        
        if [ -n "$INIT_LINES" ]; then
            echo -e "${BLUE}Initialization Logs:${NC}"
            echo "$INIT_LINES" | head -5
            echo ""
        fi
        
        if [ -n "$FPS_LINES" ]; then
            echo -e "${BLUE}FPS Logs:${NC}"
            echo "$FPS_LINES" | head -5
            echo ""
        fi
        
        if [ "$ERROR_COUNT" -gt 0 ] && [ -n "$ERROR_LINES" ]; then
            echo -e "${RED}Error Logs:${NC}"
            echo "$ERROR_LINES" | head -10
            echo ""
        fi
        
        echo "═══════════════════════════════════════"
        ;;
esac

