# Root Cause Analysis: iPad App Self-Launching Issue

## Issue Report Date
**July 26, 2025**

## Problem Description
Users reported that the Home Assistant iOS app on iPad was:
1. Launching itself randomly
2. Preventing users from leaving the app - the app would quickly regain control and return to foreground

## Investigation Period
Analysis of commits from **May 26, 2025 to July 26, 2025** (2 months prior to report date)

## Context and Timeline

### Historical Background
This issue first appeared in **June 2024** after commit d5fe2eee removed iOS 12 compatibility code, which inadvertently made scene activation unconditional. Partial fixes were applied in July 2024 (c878339e) and January 2025 (1d2130ee), but the issue persisted or recurred.

### Situation in May-July 2025
During the investigation period (May 26 - July 26, 2025), the codebase contained:

**Partial Fix Status as of July 2025:**
```swift
// From earlier fixes (pre-July 2025)
let options = UIScene.ActivationRequestOptions()
options.requestingScene = active

// Check if scene already active (added January 2025)
guard active.activationState != .foregroundActive else {
    return .value(delegate)
}

// Activation still happened unconditionally for non-active scenes
if #available(iOS 17.0, *) {
    UIApplication.shared.activateSceneSession(for: .init(session: active.session, options: options))
} else {
    UIApplication.shared.requestSceneSessionActivation(
        active.session,
        userActivity: nil,
        options: options,
        errorHandler: nil
    )
}
```

### The Remaining Problem (July 2025)

Even with the partial fixes, the code was **still activating scenes unconditionally** when they weren't already active, regardless of:
- **App state** (foreground vs background)
- **What triggered the call** (widget refresh, notification, background task)

This meant:
- ✅ The app wouldn't reactivate if already in foreground (fixed in January 2025)
- ❌ But widgets, notifications, and background tasks could still bring the app to foreground
- ❌ Users on iPad couldn't multitask effectively because the app would hijack focus

## The Complete Fix (Applied November 2025)

**PR #3964 - "Prevent iPad App to reopen by itself" (Commit 349b0b28, November 12, 2025)**

The complete fix added crucial application state checking:

```swift
// Current code (as of November 2025)
public func scene<DelegateType: UIWindowSceneDelegate>(
    for query: SceneQuery<DelegateType>
) -> Guarantee<DelegateType> {
    if let active = existingScenes(for: query.activity).first,
       let delegate = active.delegate as? DelegateType {
        
        let options = UIScene.ActivationRequestOptions()
        options.requestingScene = active

        // Check 1: Don't activate if already active (from January 2025)
        guard active.activationState != .foregroundActive else {
            Current.Log.verbose("Did not activate scene - it was already active")
            return .value(delegate)
        }

        // Check 2: Only activate if app is foreground or transitioning (NEW - November 2025)
        let shouldActivate = UIApplication.shared.applicationState == .active ||
            active.activationState == .foregroundInactive

        if shouldActivate {
            Current.Log.verbose("Activating scene")
            
            // Guarantee it runs on main thread
            DispatchQueue.main.async {
                if #available(iOS 17.0, *) {
                    UIApplication.shared.activateSceneSession(
                        for: .init(session: active.session, options: options)
                    )
                } else {
                    UIApplication.shared.requestSceneSessionActivation(
                        active.session,
                        userActivity: nil,
                        options: options,
                        errorHandler: nil
                    )
                }
            }
        } else {
            // NEW - November 2025: Skip activation when app is in background
            Current.Log.verbose("Skipping scene activation - app is in background")
        }

        return .value(delegate)
    }
    // ... rest of method
}
```

### Key Improvements in November 2025 Fix

1. **Application State Check** (`UIApplication.shared.applicationState == .active`)
   - Only activates when app is already in foreground
   - Prevents background tasks/widgets from launching the app

2. **Scene Transition State Check** (`active.activationState == .foregroundInactive`)
   - Allows activation during legitimate transitions
   - Maintains smooth user experience when user is actively using the app

3. **Explicit Logging**
   - Added "Skipping scene activation - app is in background" message
   - Helps debugging and confirms the fix is working

4. **Main Thread Dispatch**
   - Ensures thread safety for UI operations
   - Prevents race conditions from widget extensions

## Why This Was Particularly Problematic on iPad

1. **Multitasking Usage**: iPad users frequently use Split View and Slide Over
2. **Widgets**: Home Screen and Lock Screen widgets refresh frequently
3. **Background Updates**: iPadOS allows more background activity
4. **User Expectations**: iPad users expect desktop-like multitasking without apps stealing focus

## Current Status (December 2025)

✅ **Issue Resolved** - The complete fix has been in production since November 12, 2025

The fix is located in `Sources/App/Scenes/SceneManager.swift`, lines 145-179.

## Prevention Guidelines

To prevent similar issues in the future:

### 1. Always Check Application State
```swift
// Before activating scenes or windows
guard UIApplication.shared.applicationState == .active else {
    // Don't activate from background
    return
}
```

### 2. Check Scene State
```swift
// Before scene operations
guard scene.activationState != .foregroundActive else {
    // Already active, nothing to do
    return
}
```

### 3. Consider the Context
- Is this code called from widgets? → Don't activate
- Is this code called from background tasks? → Don't activate
- Is this code called from user interaction? → Safe to activate

### 4. Add Comprehensive Logging
```swift
Current.Log.verbose("Scene activation decision: state=\(UIApplication.shared.applicationState), scene=\(scene.activationState)")
```

### 5. Test on iPad Specifically
- Test with Split View active
- Test with widgets updating in background
- Test with notifications arriving while using other apps
- Verify the app doesn't steal focus unexpectedly

## Related PRs and Issues

- **#2808** (June 2024) - Introduced the original issue by removing iOS 12 compatibility
- **#2868** (July 2024) - Initial partial fix
- **#3333** (January 2025) - Improved fix (still incomplete)
- **#3964** (November 2025) - Complete fix ✅

## Files Affected

- `Sources/App/Scenes/SceneManager.swift` - Scene management and activation logic
