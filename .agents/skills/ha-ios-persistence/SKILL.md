---
name: ha-ios-persistence
description: Data persistence across GRDB, Realm, and UserDefaults. Use when adding or migrating a persistent model, choosing a storage layer, implementing DatabaseTableProtocol, or reading/writing config for Watch, CarPlay, widgets, or the entity registry.
---

# Data Persistence

The project uses **two** database layers:

- **GRDB** (`GRDB.swift`): newer layer, accessed via `Current.database()`. Used for Watch config, CarPlay config, widget config, entity registry, panels, etc. When adding a new persistent model, prefer GRDB: implement `DatabaseTableProtocol` (defines `tableName`, `definedColumns`, and `createIfNeeded`) and register it in `DatabaseQueue.tables()` in `GRDB+Initialization.swift`. The protocol's `migrateColumns` helper auto-handles additive migrations.
- **Realm** (`RealmSwift`): legacy layer, used for older models (actions, zones, sensors, etc.). Access via `Current.realm()`.
- **UserDefaults**: simple preferences and watch communication.
