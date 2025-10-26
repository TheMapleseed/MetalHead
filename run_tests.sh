#!/bin/bash

# MetalHead Test Runner
# Runs tests with proper output and timeout handling

set -e

echo "========================================="
echo "Running MetalHead Tests"
echo "========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="MetalHead"
SCHEME="MetalHead"
DESTINATION='platform=macOS'

echo -e "${BLUE}Building test target...${NC}"
xcodebuild -project ${PROJECT_NAME}.xcodeproj \
    -scheme ${SCHEME} \
    -destination ${DESTINATION} \
    -configuration Debug \
    build-for-testing \
    > /tmp/metalhead_build.log 2>&1

if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed!${NC}"
    cat /tmp/metalhead_build.log
    exit 1
fi

echo -e "${GREEN}Build succeeded!${NC}"
echo ""

echo -e "${BLUE}Running tests with 60 second timeout...${NC}"
echo ""

# Run tests with timeout
timeout 60 xcodebuild test-without-building \
    -project ${PROJECT_NAME}.xcodeproj \
    -scheme ${SCHEME} \
    -destination ${DESTINATION} \
    2>&1 | grep -E "(Test Case|Test Suite|passed|failed|Testing)" || true

exit_code=${PIPESTATUS[0]}

echo ""
if [ $exit_code -eq 0 ]; then
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}All tests passed!${NC}"
    echo -e "${GREEN}=========================================${NC}"
else
    echo -e "${RED}=========================================${NC}"
    echo -e "${RED}Tests failed or timed out!${NC}"
    echo -e "${RED}=========================================${NC}"
fi

exit $exit_code

