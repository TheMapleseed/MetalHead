#!/bin/bash

# Post-Build Test Runner
# Automatically runs tests after successful builds with timeout protection

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo ""
echo -e "${YELLOW}============================================${NC}"
echo -e "${YELLOW}Running Post-Build Tests${NC}"
echo -e "${YELLOW}============================================${NC}"
echo ""

# Configuration
PROJECT_NAME="MetalHead"
SCHEME="MetalHead"
DESTINATION='platform=macOS'
TEST_TIMEOUT=120 # 2 minutes total timeout

# Run tests with timeout
echo -e "${YELLOW}Running tests with ${TEST_TIMEOUT} second timeout...${NC}"

timeout ${TEST_TIMEOUT} xcodebuild test-without-building \
    -project ${PROJECT_NAME}.xcodeproj \
    -scheme ${SCHEME} \
    -destination ${DESTINATION} \
    -only-testing:MetalHeadTests/MetalHeadTests/testUnifiedEngineInitialization \
    -only-testing:MetalHeadTests/MetalHeadTests/testEngineStartStop \
    2>&1 | tee /tmp/test_output.log

TEST_EXIT_CODE=${PIPESTATUS[0]}

# Check results
if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}✅ Post-build tests PASSED${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
else
    echo ""
    echo -e "${RED}============================================${NC}"
    echo -e "${RED}❌ Post-build tests FAILED or TIMED OUT${NC}"
    echo -e "${RED}============================================${NC}"
    echo ""
    echo "View full test output: cat /tmp/test_output.log"
    # Don't fail the build, just warn
    exit 0
fi

