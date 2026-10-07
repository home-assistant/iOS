---
name: ha-ios-magicitem
description: The cross-platform MagicItem action model shared by Widgets, Watch, CarPlay, and App Shortcuts. Use when adding or changing item types or action overrides, or touching anything that persists MagicItem via Codable.
---

# MagicItem — Cross-Platform Action Abstraction

`MagicItem` (`Sources/Shared/MagicItem/MagicItem.swift`) is the shared model for items that can appear in Widgets, Watch, CarPlay, and App Shortcuts. It has a `type` (`.script`, `.scene`, `.entity`, `.action`, `.folder`, `.assistPipeline`) and an optional `action` override. `ItemType.rawValue` is persisted (Codable), so **never change existing raw values**.
