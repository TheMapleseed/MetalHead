# Files/Directories to Remove - Not Relevant to New Framework Configuration

## Summary
This document lists all files and directories that are not relevant to the new MetalHeadEngine framework structure and should be removed or added to `.gitignore`.

---

## 1. Planning/Temporary Documents (OBSOLETE - Restructuring Complete)

### Should be removed:
- **`ARCHITECTURE_PLAN.md`** - Planning document for framework restructuring (now complete)
- **`restructure_to_framework.sh`** - Helper script for restructuring (no longer needed)
- **`MISSING_FEATURES.md`** - Outdated feature tracking (references old structure)

---

## 2. Build Artifacts (Should be in .gitignore)

### Should be removed and added to .gitignore:
- **`build/`** - Entire directory containing Xcode build artifacts
  - `build/XCBuildData/` - Xcode build cache files
  - These are generated files and should not be in version control

---

## 3. Test Results (Should be in .gitignore)

### Should be removed and added to .gitignore:
- **`test-results/`** - Entire directory containing test result bundles
  - `test-results/test-results.xcresult/` - Generated test results
  - These are generated files and should not be in version control

---

## 4. User-Specific Xcode Files (Should be in .gitignore)

### Should be removed and added to .gitignore:
- **`MetalHead.xcodeproj/xcuserdata/`** - User-specific Xcode settings
- **`MetalHead.xcodeproj/project.xcworkspace/xcuserdata/`** - User-specific workspace settings
  - Contains `UserInterfaceState.xcuserstate` and other user preferences
  - These are user-specific and should not be in version control

---

## 5. Outdated Documentation (May need updates or removal)

### Review and potentially remove/update:
- **`docs/BUILD_STATUS.md`** - Outdated build status (dated October 26, 2025, references old structure)
- **`docs/FINAL_VERIFICATION.md`** - Outdated verification document
- **`docs/STATUS.md`** - Outdated status document
- **`docs/run_tests.sh`** - Redundant test script (Makefile handles this)
- **`docs/verify_build.sh`** - Redundant build verification script

---

## 6. Redundant/Old Scripts (May be obsolete)

### Review and potentially remove:
- **`post_build_test.sh`** - Post-build test runner (may be redundant with Makefile)
- **`UpdatePostBuildTest.sh`** - Script to update test configuration (one-time use, now obsolete)
- **`run_tests.sh`** - Test runner script (redundant with Makefile `test` target)

---

## 7. Configuration Files (Review if still needed)

### Review if still relevant:
- **`ExportOptions.plist`** - App export configuration (may still be needed for distribution)
  - **Decision:** Keep if you plan to export/distribute the app
  - **Decision:** Remove if not needed

---

## 8. Build System (Review if still needed)

### Review if still relevant:
- **`Makefile`** - Build system with various targets
  - **Decision:** Keep if you use it for CI/CD or automation
  - **Decision:** Remove if you only use Xcode for building
  - Note: Makefile doesn't reference old Core/Utilities structure, so it's still valid

---

## Recommended Actions

### Immediate Removal (Safe to delete):
1. `ARCHITECTURE_PLAN.md` - Planning doc, restructuring complete
2. `restructure_to_framework.sh` - One-time script, no longer needed
3. `MISSING_FEATURES.md` - Outdated, references old structure
4. `docs/` directory - All outdated documentation
5. `post_build_test.sh` - Redundant with Makefile
6. `UpdatePostBuildTest.sh` - One-time script, obsolete
7. `run_tests.sh` - Redundant with Makefile

### Add to .gitignore (Don't delete, just ignore):
1. `build/` - Build artifacts
2. `test-results/` - Test result bundles
3. `*.xcuserstate` - User state files
4. `xcuserdata/` - User-specific Xcode settings
5. `*.xcuserdatad/` - User data directories

### Review and Decide:
1. `ExportOptions.plist` - Keep if distributing, remove if not
2. `Makefile` - Keep if using for automation, remove if only using Xcode

---

## Files to Keep (Relevant to New Structure)

✅ **Keep these:**
- `README.md` - Main documentation (may need updates)
- `API_GUIDELINES.md` - API documentation (may need updates)
- `TESTING_AND_LOGGING.md` - Testing documentation (may need updates)
- `MetalHead.png` - App icon source
- `MetalHead.xcodeproj/` - Xcode project (core project file)
- `MetalHead/` - App target files
- `MetalHeadEngine/` - Framework source code
- `MetalHeadTests/` - Test files

---

## Summary Count

- **Files to remove:** ~15-20 files
- **Directories to remove:** 2-3 directories
- **Files to add to .gitignore:** ~5 patterns
- **Files to review:** 2 files (ExportOptions.plist, Makefile)

