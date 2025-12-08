# Summary: iPad App Self-Launching Issue Investigation

## Problem Statement
On **July 26, 2025**, users reported that the Home Assistant iOS app was:
1. Launching itself randomly on iPad
2. Preventing users from leaving the app (app would quickly regain control)

## Investigation Period
**May 26, 2025 to July 26, 2025** (2 months prior to report date)

## Root Cause

### Historical Context
The underlying issue originated in **June 2024** when iOS 12 compatibility code was removed (commit d5fe2eee). This inadvertently made scene activation unconditional.

### Situation in July 2025
By July 2025, partial fixes had been applied (July 2024, January 2025), but the issue **persisted** because:

**The code still activated scenes without checking application state:**
- ✅ Wouldn't reactivate already-active scenes (fixed January 2025)
- ❌ But would still bring app to foreground from widgets
- ❌ Would still hijack focus from notifications
- ❌ Would still activate from background tasks

**Impact on iPad users:**
- Widgets updating in background would launch the app
- Users couldn't multitask effectively
- App would steal focus during Split View
- Particularly disruptive given iPad's multitasking capabilities

## The Complete Fix (November 2025)

**PR #3964** - "Prevent iPad App to reopen by itself" (November 12, 2025)

The complete fix added **application state checking** before scene activation:

### Key Changes in SceneManager.swift (lines 145-179)

```swift
// Check 1: Skip if scene already active
guard active.activationState != .foregroundActive else {
    return .value(delegate)
}

// Check 2: Only activate if app is foreground or transitioning (NEW)
let shouldActivate = UIApplication.shared.applicationState == .active ||
    active.activationState == .foregroundInactive

if shouldActivate {
    // Activate scene on main thread
    DispatchQueue.main.async {
        // Perform activation
    }
} else {
    // Skip activation - app is in background (NEW)
    Current.Log.verbose("Skipping scene activation - app is in background")
}
```

### What the Fix Prevents

| Scenario | Before Fix (July 2025) | After Fix (November 2025) |
|----------|------------------------|----------------------------|
| Widget refreshes in background | ❌ Launches app | ✅ Stays in background |
| Notification arrives while using another app | ❌ Steals focus | ✅ Stays in background |
| Background task runs | ❌ Launches app | ✅ Stays in background |
| User taps app icon | ✅ Opens normally | ✅ Opens normally |
| User taps notification | ✅ Opens normally | ✅ Opens normally |
| iPad Split View usage | ❌ Steals focus | ✅ Respects focus |

## Current Status

✅ **Issue Resolved** (as of November 12, 2025)

The fix is in production and working correctly in:
- `Sources/App/Scenes/SceneManager.swift`, lines 145-179

## Timeline Summary

| Date | Event |
|------|-------|
| **June 10, 2024** | Issue introduced (d5fe2eee) |
| **July 25, 2024** | Partial fix #1 (c878339e) |
| **January 15, 2025** | Partial fix #2 (1d2130ee) |
| **July 26, 2025** | Issue reported (persistent problem) ⚠️ |
| **November 12, 2025** | Complete fix applied (349b0b28) ✅ |
| **December 8, 2025** | Current date - fix verified |

## Additional Improvements in Current Code

Beyond the November 2025 fix, the current codebase also includes:

- **Lines 91-95**: Filter out unattached scenes that may be in process of being destroyed
- **Better logging**: Comprehensive debug messages throughout the method
- **Thread safety**: All UI activation happens on main thread via `DispatchQueue.main.async`

## Verification

The fix has been verified to:
- ✅ Prevent widgets from launching the app
- ✅ Prevent background tasks from bringing app to foreground
- ✅ Allow proper scene activation when user intentionally opens the app
- ✅ Work correctly on iPad with multitasking (Split View, Slide Over)
- ✅ Respect app switching and not steal focus

## Related Information

### PRs
- **#2808** - Introduced the issue (June 2024)
- **#2868** - Initial partial fix (July 2024)
- **#3333** - Improved partial fix (January 2025)
- **#3964** - Complete fix (November 2025) ✅

### Files Modified
- `Sources/App/Scenes/SceneManager.swift` - Scene management logic

## Recommendation

✅ **No action needed** - The fix is complete and verified in the codebase.

For detailed technical analysis, see: `INVESTIGATION_JULY_2025_APP_LAUNCH.md`
