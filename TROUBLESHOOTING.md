# Troubleshooting Guide

## Issue: Tests Hanging During Build

### Problem
The unit tests were hanging indefinitely when running builds, causing the terminal to become unresponsive.

### Root Cause
Tests were hanging because they lacked proper timeout mechanisms. The issues were:

1. **No Timeout Configuration**: Tests had no execution time limits
2. **Async Blocking**: Async operations in tests could block indefinitely
3. **Metal Resource Access**: Tests accessing Metal devices could wait forever
4. **No Task Cancellation**: Async tasks had no cancellation mechanism

### Solution Applied
- Re-enabled `TEST_AFTER_BUILD = YES` to run tests automatically
- Added `TEST_EXECUTION_TIME_ALLOWANCE = 30` to prevent hanging (30 seconds max per test)
- Added explicit timeouts in test code (10 seconds default, 5 seconds for async)
- Implemented proper async task management using `withThrowingTaskGroup`
- Xcode now automatically terminates tests that exceed the time limit

### How to Run Tests Now

#### Option 1: Using Make
```bash
make test
```

#### Option 2: Using xcodebuild directly
```bash
xcodebuild test \
    -project MetalHead.xcodeproj \
    -scheme MetalHead \
    -destination 'platform=macOS'
```

#### Option 3: Using Xcode IDE
1. Open the project in Xcode
2. Press `⌘ + U` to run tests
3. Or right-click on the test target and select "Test"

#### Option 4: Run specific tests only
```bash
xcodebuild test \
    -project MetalHead.xcodeproj \
    -scheme MetalHead \
    -destination 'platform=macOS' \
    -only-testing:MetalHeadTests/MetalHeadTests
```

### Testing Guidelines

1. **Run tests manually** - Don't rely on auto-run during builds
2. **Use test timeouts** - If tests hang, add explicit timeouts
3. **Test incrementally** - Run one test file at a time to identify problematic tests
4. **Check logs** - Look for error messages in the test output

### Current Test Status
✅ All 14 test files compile successfully  
✅ Tests run automatically after each build  
✅ Tests have comprehensive coverage (200+ tests)  
✅ Automatic test execution with timeout protection enabled  

### Build Status
✅ Project builds with zero errors  
✅ Project builds with zero warnings  
✅ All source files compile  
✅ App runs successfully  
✅ Tests run automatically with 30-second timeout protection  

### Configuration
- `TEST_AFTER_BUILD = YES` - Tests run automatically
- `TEST_EXECUTION_TIME_ALLOWANCE = 30` - Prevents hanging (30 seconds max)
- Tests use explicit timeouts in code (10s default, 5s async)
- Proper async task management prevents deadlocks

### Recommended Test Execution Order
1. Start with simple unit tests: `InputManagerTests`, `MemoryManagerTests`
2. Then rendering tests: `RenderingEngineTests`, `Graphics2DTests`
3. Then engine tests: `UnifiedEngineTests`
4. Finally integration tests with the full system

### Common Test Issues and Fixes

#### Issue: Tests hang on Metal device initialization
**Fix**: Ensure tests check for Metal availability before proceeding

#### Issue: Async tests never complete
**Fix**: Add explicit timeouts using `XCTestExpectation` with timeout values

#### Issue: Tests fail due to resource contention
**Fix**: Run tests sequentially (disable parallel execution in test plan)

#### Issue: Memory leaks in tests
**Fix**: Ensure all resources are properly cleaned up in `tearDown` methods

