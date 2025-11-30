# MetalHead Test Scripts

Scripts for installing, testing, and verifying the MetalHead engine.

## Scripts

### `install.sh`
Installs the built MetalHead.app to `/Applications`.

**Usage:**
```bash
./scripts/install.sh
```

**Requirements:**
- Project must be built first: `xcodebuild -scheme MetalHead build`

### `test_engine.sh`
Runs the engine and verifies it's working correctly with measurable outputs.

**Usage:**
```bash
# Run for 10 seconds (default)
./scripts/test_engine.sh

# Run for 30 seconds
./scripts/test_engine.sh 30
```

**Output:**
- Creates log files in `./test-logs/`
- Generates metrics JSON file
- Prints test results summary
- Exit code: 0 for pass, 1 for fail

**Metrics Captured:**
- Engine initialization status
- Rendering activity
- Frame count
- Error count
- FPS mentions
- Render calls

### `parse_logs.sh`
Parses engine logs and extracts measurable metrics.

**Usage:**
```bash
# Human-readable format (default)
./scripts/parse_logs.sh [log_file]

# JSON format
./scripts/parse_logs.sh [log_file] json

# CSV format
./scripts/parse_logs.sh [log_file] csv
```

**Output Formats:**
- `human`: Human-readable summary
- `json`: JSON format for programmatic parsing
- `csv`: CSV format for spreadsheet analysis

## Log Format

The engine outputs structured logs with the format:
```
[TIMESTAMP] [LEVEL] [CATEGORY] MESSAGE
METRIC: metric_name key=value key=value
```

**Example:**
```
[17:30:45.123] [INFO] [Rendering] Frame 60 rendered
METRIC: frame_rendered count=60 sceneObjects=3 fps=120
```

## Metrics

The engine outputs the following metrics (prefixed with `METRIC:`):

- `engine_initialized`: Engine initialization status
- `engine_started`: Engine start status
- `initialization_complete`: Full initialization completion
- `test_objects_added`: Test objects added to scene
- `render_called`: Render function called
- `frame_rendered`: Frame successfully rendered
- `initialization_error`: Initialization error occurred

## Test Verification

The test script verifies:
1. ✅ Engine initializes successfully
2. ✅ Rendering is active
3. ✅ Frames are being rendered
4. ✅ No errors detected
5. ✅ Performance metrics are present

## Example Workflow

```bash
# 1. Build the project
xcodebuild -scheme MetalHead build

# 2. Install the app
./scripts/install.sh

# 3. Run tests
./scripts/test_engine.sh 15

# 4. Parse logs
./scripts/parse_logs.sh test-logs/engine_test_*.log json
```

