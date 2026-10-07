---
name: ha-ios-concurrency
description: Asynchronous code and server networking conventions. Use when writing async/await, Tasks, actors, or Combine, deciding whether to touch PromiseKit, annotating view models with @MainActor, or calling the Home Assistant server via HAKit.
---

# Concurrency & Networking

## Concurrency

**Prefer Swift Concurrency (`async`/`await`, `Task`, actors, structured concurrency) for all new asynchronous code.**

- **Do not introduce new [PromiseKit](https://github.com/mxcl/PromiseKit) code.** PromiseKit is a legacy dependency that the codebase is gradually moving away from. Parts of `HomeAssistantAPI` (`HAAPI.swift`) still use it, so don't assume a full migration — but new work should use `async`/`await` instead of `Promise`/`Guarantee`.
- When touching existing PromiseKit code, migrate it to `async`/`await` where practical rather than extending the PromiseKit usage.
- Use `Combine` only where an existing reactive pattern already requires it; otherwise prefer `async`/`await` and `AsyncStream`/`AsyncSequence`.
- Annotate SwiftUI-facing view models with `@MainActor`.

## Networking

Use `HAKit` (the Home Assistant Swift SDK) for server communication:
- REST API calls via `HAConnection`
- WebSocket subscriptions for real-time updates
- Connection info managed through `Current.servers`
- Prefer `async`/`await` for new request flows (see Concurrency above); avoid adding new PromiseKit-based calls.
