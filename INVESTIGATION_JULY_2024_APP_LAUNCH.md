# Root Cause Analysis: iPad App Self-Launching Issue

## Issue Report Date
**July 26, 2024**

## Problem Description
Users reported that the Home Assistant iOS app on iPad was:
1. Launching itself randomly
2. Preventing users from leaving the app - the app would quickly regain control and return to foreground

## Root Cause Analysis

### Timeline of Changes

#### 1. **June 10, 2024 - The Breaking Change (Commit d5fe2eee)**
**PR:** #2808 - "Remove some deprecated code pointed in #2655"

**What changed:**
- Removed iOS 12 compatibility code from `SceneManager.swift`
- Inadvertently modified the scene activation logic in the `scene(for:)` method

**The Problem:**
```swift
// Before June 10 - with compatibility code
public func scene<DelegateType: UIWindowSceneDelegate>(
    for query: SceneQuery<DelegateType>
) -> Guarantee<DelegateType> {
    if let active = existingScenes(for: query.activity).first,
       let delegate = active.delegate as? DelegateType {
        UIApplication.shared.requestSceneSessionActivation(
            active.session,
            userActivity: nil,
            options: nil,  // ❌ No options, no requesting scene
            errorHandler: nil
        )
        return .value(delegate)
    }
    // ...
}
```

This code would **unconditionally activate** any existing scene, regardless of:
- Whether the app was in the background
- Whether the scene was already active
- What triggered the activation (widget, notification, background task)

### Why This Caused Problems on iPad

1. **Widgets and Background Tasks:** When widgets refreshed or background tasks ran, they would call `scene(for:)` to get access to view controllers
2. **Unconditional Activation:** The method would always call `requestSceneSessionActivation`, bringing the app to foreground
3. **User Experience Impact:** 
   - App would launch itself when widgets updated
   - Users couldn't switch to other apps because background tasks would reactivate the Home Assistant app
   - Particularly problematic on iPad where users expect seamless multitasking

### The Fix Evolution

#### Phase 1: July 25, 2024 (Commit c878339e)
**PR:** #2868 - "Fix issue where notification URL closes app right away"

**What was fixed:**
- Added `UIScene.ActivationRequestOptions` with `requestingScene` property
- Used iOS 17+ API `activateSceneSession` when available

```swift
let options = UIScene.ActivationRequestOptions()
options.requestingScene = active

if #available(iOS 17.0, *) {
    UIApplication.shared.activateSceneSession(for: .init(session: active.session, options: options))
} else {
    UIApplication.shared.requestSceneSessionActivation(
        active.session,
        userActivity: nil,
        options: options,  // ✓ Now includes requesting scene
        errorHandler: nil
    )
}
```

**Result:** Partial fix - helped with some scenarios but didn't fully solve the problem

#### Phase 2: January 15, 2025 (Commit 1d2130ee)
**PR:** #3333 - "Only activate scene when not active already"

**What was added:**
- Guard clause to prevent activation if scene is already active

```swift
// Only activate scene if not activated already
guard active.activationState != .foregroundActive else {
    Current.Log.verbose("Did not activate scene \(active.session.persistentIdentifier), it was already active")
    return .value(delegate)
}
```

**Result:** Better, but still had issues with background activation

#### Phase 3: November 12, 2025 (Commit 349b0b28)
**PR:** #3964 - "Prevent iPad App to reopen by itself"

**The Complete Fix:**
```swift
// Only activate scene if not activated already
guard active.activationState != .foregroundActive else {
    Current.Log.verbose("Did not activate scene \(active.session.persistentIdentifier), it was already active")
    return .value(delegate)
}

// Only activate scene if the app is already in foreground or transitioning to foreground
// This prevents widgets, notifications, or background tasks from unexpectedly bringing the app to foreground
let shouldActivate = UIApplication.shared.applicationState == .active ||
    active.activationState == .foregroundInactive

if shouldActivate {
    Current.Log.verbose("Activating scene \(active.session.persistentIdentifier)")
    
    // Guarantee it runs on main thread when coming from widgets
    DispatchQueue.main.async {
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
    }
} else {
    Current.Log.verbose("Skipping scene activation for \(active.session.persistentIdentifier) - app is in background")
}
```

**Key improvements:**
1. ✅ Check if scene is already in foreground active state
2. ✅ Only activate if app state is `.active` (foreground) or scene is `.foregroundInactive` (transitioning)
3. ✅ Skip activation entirely when app is in background
4. ✅ Dispatch to main thread to ensure thread safety
5. ✅ Added comprehensive logging for debugging

## Current Status

The current codebase (as of December 2025) has the complete fix applied. The issue has been resolved through the three-phase fix described above.

## Prevention

To prevent similar issues in the future:

1. **Always check application state** before calling scene activation APIs
2. **Check scene activation state** before attempting to activate
3. **Be cautious when removing "compatibility" code** - ensure the replacement behavior matches the original intent
4. **Consider the context** of where methods are called from (foreground UI vs background tasks vs widgets)
5. **Add logging** to track unexpected activations during development

## Files Affected

- `Sources/App/Scenes/SceneManager.swift` - Primary file with the scene management logic

## Testing and Verification

### Manual Testing Checklist

To verify the fix works correctly:

1. **Widget Background Updates:**
   - [ ] Add Home Assistant widgets to home screen
   - [ ] Put app in background and switch to another app
   - [ ] Wait for widget to refresh
   - [ ] Verify: App should NOT launch itself

2. **Notification Handling:**
   - [ ] Send a notification with URL action
   - [ ] With app in background, tap the notification
   - [ ] Verify: App should open to the URL and stay open

3. **Background Tasks:**
   - [ ] Enable background fetch
   - [ ] Put app in background
   - [ ] Wait for background refresh
   - [ ] Verify: App should NOT launch itself

4. **iPad Multitasking:**
   - [ ] Open Split View with Home Assistant and another app
   - [ ] Interact with widgets or trigger background updates
   - [ ] Verify: Focus should not switch unexpectedly to Home Assistant

5. **Scene Already Active:**
   - [ ] Open app normally
   - [ ] Trigger an action that calls `scene(for:)` (e.g., widget tap while app is open)
   - [ ] Verify: No flickering or double activation

### Why Unit Tests Are Challenging

Unit testing `SceneManager` is difficult because:
- `UIApplication.shared` is a singleton that cannot be easily mocked
- `UIScene` lifecycle is managed by the system
- Scene activation is an asynchronous operation with system involvement
- Application state transitions are controlled by iOS

**Recommendation:** Focus on integration tests and manual QA testing for scene-related functionality.

## Related Issues

- #3305 - User reports of app launching itself
- #2655 - Original issue that led to the deprecated code removal
- #2868 - Fix issue where notification URL closes app right away (July 25, 2024)
- #3333 - Only activate scene when not active already (January 15, 2025)
- #3964 - Prevent iPad App to reopen by itself (November 12, 2025)
