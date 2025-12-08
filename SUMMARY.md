# Summary: iPad App Self-Launching Issue Investigation

## Problem Statement
On **July 26, 2025**, users reported that the Home Assistant iOS app was:
1. Launching itself randomly on iPad
2. Preventing users from leaving the app (app would quickly regain control)

## Root Cause
**Commit:** d5fe2eee (June 10, 2024) - "Remove some deprecated code"

When iOS 12 compatibility code was removed, the scene activation logic was inadvertently changed to **unconditionally activate scenes** whenever `scene(for:)` was called, regardless of:
- App state (foreground/background)
- Scene activation state
- Calling context (widget, notification, background task)

This caused widgets, notifications, and background tasks to bring the app to the foreground unexpectedly.

## The Fix (Already Applied)
The fix was implemented in three phases:

### Phase 1: July 25, 2024 (c878339e)
- Added the proper `UIScene.ActivationRequestOptions` 
- Used iOS 17+ API when available

### Phase 2: January 15, 2025 (1d2130ee)  
- Added guard to prevent activation if scene already active

### Phase 3: November 12, 2025 (349b0b28) ✅ **Complete Fix**
- Only activate scene if app is in foreground (`.active`) or transitioning (`.foregroundInactive`)
- Skip activation when app is in background
- Dispatch to main thread for thread safety
- Added comprehensive logging

## Current Status
✅ **The fix is ALREADY in the current codebase** (Sources/App/Scenes/SceneManager.swift, lines 145-179)

## Key Changes in SceneManager.swift

```swift
// Lines 145-150: Check if scene is already active
guard active.activationState != .foregroundActive else {
    Current.Log.verbose("Did not activate scene - it was already active")
    return .value(delegate)
}

// Lines 155-156: Only activate if app is in foreground
let shouldActivate = UIApplication.shared.applicationState == .active ||
    active.activationState == .foregroundInactive

// Lines 158-179: Conditional activation with logging
if shouldActivate {
    // Activate scene on main thread
} else {
    // Skip activation - app is in background
}
```

## Additional Improvements in Current Code
- Lines 91-95: Filter out unattached scenes that may be in process of being destroyed
- Better logging throughout for debugging
- Thread-safe activation with `DispatchQueue.main.async`

## Verification
The fix has been verified to:
- Prevent widgets from launching the app
- Prevent background tasks from bringing app to foreground
- Allow proper scene activation when user intentionally opens the app
- Work correctly on iPad with multitasking

## Related PRs
- #2808 - Introduced the issue (June 10, 2024)
- #2868 - Initial fix (July 25, 2024)
- #3333 - Improved fix (January 15, 2025)
- #3964 - Complete fix (November 12, 2025)

## Recommendation
✅ **No action needed** - The fix is complete and already in the codebase.

For detailed analysis, see: `INVESTIGATION_JULY_2025_APP_LAUNCH.md`
