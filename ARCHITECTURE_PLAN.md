# MetalHead Architecture Restructuring Plan

## Goal
Restructure MetalHead so the engine is a **standalone framework** that can be:
- Built independently
- Used by the app
- Used by tests
- Potentially used by other projects

## Current Structure
```
MetalHead/
├── MetalHead/ (App Target)
│   ├── Core/ (Engine code - should be framework)
│   ├── Utilities/ (Engine utilities - should be framework)
│   ├── MetalHeadApp.swift (App code - stays in app)
│   └── ContentView.swift (App code - stays in app)
└── MetalHeadTests/ (Test Target)
```

## Target Structure
```
MetalHead/
├── MetalHeadEngine/ (Framework Target)
│   ├── Core/
│   │   ├── Rendering/
│   │   ├── Audio/
│   │   ├── Input/
│   │   ├── Memory/
│   │   ├── Synchronization/
│   │   └── UnifiedMultimediaEngine.swift
│   └── Utilities/
│       ├── ErrorHandling/
│       ├── Extensions/
│       ├── Logging/
│       ├── Performance/
│       └── Testing/
├── MetalHead/ (App Target)
│   ├── MetalHeadApp.swift
│   ├── ContentView.swift
│   └── Assets.xcassets/
└── MetalHeadTests/ (Test Target)
    └── (all test files)
```

## Steps to Implement

### 1. Create Framework Target in Xcode
- File > New > Target
- Choose "Framework & Library" > "Framework"
- Name: `MetalHeadEngine`
- Language: Swift
- Minimum Deployment: macOS 26.0

### 2. Move Files to Framework
Move these directories to MetalHeadEngine:
- `MetalHead/Core/` → `MetalHeadEngine/Core/`
- `MetalHead/Utilities/` → `MetalHeadEngine/Utilities/`

### 3. Update Target Memberships
- **MetalHeadEngine framework**: Core/*, Utilities/*
- **MetalHead app**: MetalHeadApp.swift, ContentView.swift, Assets.xcassets
- **MetalHeadTests**: All test files

### 4. Add Framework Dependencies
- **MetalHead app**: Link MetalHeadEngine.framework
- **MetalHeadTests**: Link MetalHeadEngine.framework

### 5. Update Imports
In app files (MetalHeadApp.swift, ContentView.swift):
```swift
import MetalHeadEngine
```

### 6. Update Module Name
Ensure framework module name is `MetalHeadEngine` in build settings.

## Benefits
✅ Engine is standalone and reusable
✅ Clear separation of concerns
✅ Can be distributed as a framework
✅ Tests use the same framework as the app
✅ Better code organization

## Implementation Notes
- Framework will be built before app/tests
- All public APIs must be marked `public`
- Framework will be embedded in app bundle
- Tests link against framework (not app)

