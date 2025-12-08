# Migration: WatchComplication from Realm to GRDB

## Overview
This migration moves watch complication storage from Realm to GRDB on the Apple Watch, following the same pattern used for other watch-specific data like `WatchConfig`.

## Changes Made

### 1. Database Schema (`DatabaseTables.swift`)
- Added `appWatchComplication` case to `GRDBDatabaseTable` enum
- Added `AppWatchComplication` table definition enum with columns:
  - `identifier` (primary key, text)
  - `complicationData` (JSON text containing the full complication data)

### 2. Table Creation (`AppWatchComplicationTable.swift`) ✨ NEW FILE
- Implements `DatabaseTableProtocol` to manage table creation and updates
- Creates table with automatic column addition for future schema changes
- Follows the same pattern as `HAppEntityTable.swift`

### 3. Model Definition (`AppWatchComplication.swift`) ✨ NEW FILE
- Swift struct conforming to `Codable`, `FetchableRecord`, and `PersistableRecord`
- Stores complete JSON data from iPhone's Realm `WatchComplication` object
- Provides convenience methods:
  - `from(jsonData:)` - Creates instance from JSON data received from iPhone
  - `fetchAll(from:)` - Fetches all complications
  - `fetch(identifier:from:)` - Fetches specific complication
  - `deleteAll(from:)` - Clears all complications

### 4. ViewModel Update (`WatchHomeViewModel.swift`)
Updated two methods:

#### `saveComplicationToDatabase`
- **Before:** Saved to Realm using `WatchComplication(JSON:)` and `realm.add()`
- **After:** Saves to GRDB using `AppWatchComplication.from(jsonData:)` and `db.insert()`
- Uses `onConflict: .replace` for upsert behavior
- Clears existing complications on first sync (index == 0)

#### `fetchComplicationCount`
- **Before:** Used `realm.objects(WatchComplication.self).count`
- **After:** Uses `Current.database().read { try AppWatchComplication.fetchCount(db) }`
- Added error handling

## Design Decisions

### Why Store as JSON Text?
The complication data coming from iPhone is complex Realm object JSON. Rather than mapping all fields, we store the complete JSON as text, which:
- Preserves all data without loss
- Simplifies migration (no field mapping needed)
- Allows the existing `ComplicationController` to work unchanged
- Follows SQLite best practices for complex nested data

### Primary Key: identifier
Uses `identifier` as primary key to match the Realm object's primary key, enabling proper upsert behavior when syncing from iPhone.

## Additional Steps Required

### 1. Update Database Initialization
The `AppWatchComplicationTable` must be registered in the database setup code. Look for where other tables like `WatchConfigTable` are initialized and add:
```swift
try AppWatchComplicationTable().createIfNeeded(database: database)
```

### 2. Update ComplicationController
The `ComplicationController.swift` currently reads from Realm:
```swift
Current.realm().object(ofType: WatchComplication.self, forPrimaryKey: ...)
```

This needs to be updated to read from GRDB:
```swift
try? Current.database().read { db in
    try AppWatchComplication.fetch(identifier: identifier, from: db)
}
```

You'll also need to create a method to convert `AppWatchComplication` to the expected complication template format.

### 3. Migration Strategy
Consider adding migration logic to:
- Copy existing Realm complications to GRDB on first launch
- Delete Realm complications after successful migration
- Handle cases where both databases exist

### 4. Testing
Test the following scenarios:
- Initial sync from iPhone
- Incremental sync (updating existing complications)
- Clearing complications
- Complication count display
- Complication templates in watch faces

## Benefits
✅ Consistent database layer (GRDB for watch data)
✅ Better performance for watch queries
✅ Simplified maintenance (one database system)
✅ Thread-safe access with GRDB's queue
✅ Easier to debug and test

## Notes
- The iPhone still uses Realm for `WatchComplication` storage - only the watch side changed
- The sync protocol remains unchanged - complications still come as JSON data
- The paginated sync approach is preserved
