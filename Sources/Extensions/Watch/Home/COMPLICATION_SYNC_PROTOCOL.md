# Complication Sync Protocol Documentation

## Overview

This document describes the paginated complication sync protocol between the iPhone and Apple Watch. Complications are synced one at a time to avoid WatchConnectivity payload size limits.

## Architecture

### Key Components

**iPhone (iOS App):**
- `WatchCommunicatorService.swift` - Handles sync requests from watch
- Realm database - Stores `WatchComplication` objects

**Apple Watch (watchOS App):**
- `WatchHomeViewModel.swift` - Initiates sync requests
- `ExtensionDelegate.swift` - Receives and processes individual complications
- `ComplicationController.swift` - Provides complications to watchOS

## Protocol Flow

```
┌─────────┐                                    ┌─────────┐
│  Watch  │                                    │  Phone  │
└────┬────┘                                    └────┬────┘
     │                                              │
     │  1. Request complication at index 0          │
     │  Message: "syncComplication"                 │
     │  Content: {"index": 0}                       │
     ├──────────────────────────────────────────────>│
     │                                              │
     │                                   2. Fetch complication from Realm
     │                                   3. Serialize to JSON Data
     │                                              │
     │  4. Response with complication data          │
     │  Message: "syncComplicationResponse"         │
     │  Content: {                                  │
     │    "complicationData": Data,                 │
     │    "hasMore": true,                          │
     │    "index": 0,                               │
     │    "total": 5                                │
     │  }                                           │
     │<──────────────────────────────────────────────┤
     │                                              │
5. Save to Realm                                    │
6. Check hasMore flag                               │
     │                                              │
     │  7. Request complication at index 1          │
     │  Message: "syncComplication"                 │
     │  Content: {"index": 1}                       │
     ├──────────────────────────────────────────────>│
     │                                              │
     │           ... Repeat for each complication ...
     │                                              │
     │  N. Final complication                       │
     │  Content: {                                  │
     │    "complicationData": Data,                 │
     │    "hasMore": false,  ← Last one             │
     │    "index": 4,                               │
     │    "total": 5                                │
     │  }                                           │
     │<──────────────────────────────────────────────┤
     │                                              │
N+1. Complete sync                                  │
N+2. Reload complication timeline                   │
     │                                              │
```

## Message Specifications

### 1. Sync Request (Watch → Phone)

**Message Type:** `ImmediateMessage`

**Identifier:** `"syncComplication"`

**Content:**
```swift
{
    "index": Int  // 0-based index of complication to fetch
}
```

**Example:**
```swift
ImmediateMessage(
    identifier: "syncComplication",
    content: ["index": 0]
)
```

### 2. Sync Response (Phone → Watch)

**Message Type:** `ImmediateMessage`

**Identifier:** `"syncComplicationResponse"`

**Content (Success):**
```swift
{
    "complicationData": Data,  // JSON-serialized WatchComplication
    "hasMore": Bool,           // true if more complications are pending
    "index": Int,              // The index that was requested
    "total": Int               // Total number of complications
}
```

**Content (Error):**
```swift
{
    "error": String,           // Error description
    "hasMore": false,
    "index": -1,
    "total": 0
}
```

**Example (Success):**
```swift
ImmediateMessage(
    identifier: "syncComplicationResponse",
    content: [
        "complicationData": complicationData,  // Data object
        "hasMore": true,
        "index": 2,
        "total": 5
    ]
)
```

## Implementation Details

### Phone Side (WatchCommunicatorService.swift)

#### Key Methods

**`syncSingleComplication(message:)`**
- Receives sync request with index
- Fetches complication from Realm at that index
- Serializes to JSON string using ObjectMapper's `toJSONString()`
- Converts JSON string to `Data`
- Sends response with `hasMore` flag

**Protocol:**
```swift
/// Syncs a single complication to the watch by index (paginated approach)
/// This avoids payload size limits by sending complications one at a time.
///
/// Protocol:
/// 1. Watch sends "syncComplication" with {"index": N}
/// 2. Phone responds with "syncComplicationResponse" containing:
///    - "complicationData": Data (JSON of the complication)
///    - "hasMore": Bool (true if index+1 < total)
///    - "index": Int (the index sent by watch)
///    - "total": Int (total number of complications)
/// 3. Watch saves the complication and requests next if hasMore is true
private func syncSingleComplication(message: ImmediateMessage)
```

**Message Observation:**
```swift
ImmediateMessage.observations.store[.init(queue: .main)] = { [weak self] message in
    guard let self else { return }
    
    if message.identifier == "syncComplication" {
        self.syncSingleComplication(message: message)
    }
}
```

### Watch Side

#### WatchHomeViewModel.swift

**`requestConfig()`**
- Initiates paginated sync by requesting index 0
- Called when watch app launches or config is refreshed

**`requestNextComplication(index:)`**
- Helper method to send sync request for a specific index
- Called recursively as responses are received

**Protocol:**
```swift
/// Requests a single complication from the phone by index
/// - Parameter index: The index of the complication to request (0-based)
///
/// This implements a paginated sync protocol:
/// 1. Watch sends request with index
/// 2. Phone responds with complication at that index + "hasMore" flag
/// 3. If hasMore is true, watch requests next index
/// 4. Continues until hasMore is false or error occurs
private func requestNextComplication(index: Int)
```

#### ExtensionDelegate.swift

**`handleSyncComplicationResponse(_:)`**
- Receives individual complication responses
- Deserializes JSON data to `WatchComplication` object
- Saves to Realm database
- Clears existing complications on index 0 (first complication)
- Requests next complication if `hasMore` is true
- Triggers complication reload when complete

**Key Features:**
- Tracks sync progress (count, timing)
- Comprehensive logging at each step
- Automatic chaining of requests
- Error handling

**Protocol:**
```swift
/// Handles individual complication sync responses from the phone
/// This is part of the paginated complication sync protocol where complications
/// are sent one at a time to avoid payload size limits.
///
/// Expected message content:
/// - "complicationData": Data - JSON string of the complication
/// - "hasMore": Bool - true if more complications are pending
/// - "index": Int - index of this complication
/// - "total": Int - total number of complications
/// - "error": String? - optional error message
private func handleSyncComplicationResponse(_ message: ImmediateMessage)
```

## Data Flow

### Complication Serialization (Phone)

```
WatchComplication (Realm Object)
        ↓
toJSONString() (ObjectMapper)
        ↓
JSON String
        ↓
.data(using: .utf8)
        ↓
Data (suitable for WatchConnectivity)
```

### Complication Deserialization (Watch)

```
Data (from WatchConnectivity)
        ↓
JSONSerialization.jsonObject()
        ↓
[String: Any] Dictionary
        ↓
WatchComplication(JSON:) (ObjectMapper)
        ↓
WatchComplication (Realm Object)
        ↓
Save to Realm Database
```

## Advantages of Paginated Approach

1. **No Payload Size Limits**
   - Each message only contains one complication
   - Avoids "Payload contains unsupported type" errors
   - Works with any number of complications

2. **Better Error Recovery**
   - If one complication fails, others can still sync
   - Clear indication of which complication caused error

3. **Progress Tracking**
   - Watch knows exact progress (N of M)
   - Can display sync progress to user if needed

4. **Efficient Memory Usage**
   - Only one complication in memory at a time
   - No large JSON arrays to allocate

5. **Incremental Sync**
   - Could be extended to only sync changed complications
   - Could support cancellation mid-sync

## Logging

### Watch Logs (Expected Output)

```
Requesting complications sync from phone (paginated approach)
Requesting complication at index 0
Starting complication sync
Received complication 1 of 3
Deserialized complication: ABC123-UUID
Clearing existing complications from watch database
Saved complication 1 to watch database
More complications pending, requesting index 1
Received complication 2 of 3
Deserialized complication: DEF456-UUID
Saved complication 2 to watch database
More complications pending, requesting index 2
Received complication 3 of 3
Deserialized complication: GHI789-UUID
Saved complication 3 to watch database
Complication sync complete! Received 3 of 3 complications in 0.45s
Providing complication descriptors: - Configured complications from database: 3
```

### Phone Logs (Expected Output)

```
Watch requested complication at index 0
Sending complication 1 of 3 (hasMore: true)
Watch requested complication at index 1
Sending complication 2 of 3 (hasMore: true)
Watch requested complication at index 2
Sending complication 3 of 3 (hasMore: false)
```

## Error Handling

### Invalid Index
```
Phone: "Invalid complication index 5 (total: 3)"
Watch: "Received error during complication sync: Invalid index 5, total is 3"
```

### Serialization Failure
```
Phone: "Failed to serialize complication at index 2"
Watch: "Received error during complication sync: Failed to serialize complication"
```

### Deserialization Failure
```
Watch: "Failed to create WatchComplication from JSON at index 1"
(Continues with next complication if available)
```

## Backward Compatibility

The legacy `syncComplications` method remains available but is not recommended due to payload size limits. It attempts to send all complications via WatchConnectivity Context in one message.

**Legacy Method:** `syncComplications(message: InteractiveImmediateMessage)`
- Sends all complications via Context
- May fail with "Payload contains unsupported type" error
- Kept for reference but deprecated

## Testing

### Test Scenarios

1. **Zero Complications**
   - Phone has no complications
   - Watch should receive total=0 and not request anything

2. **Single Complication**
   - Phone has 1 complication
   - Watch receives hasMore=false on first response

3. **Multiple Complications**
   - Phone has N complications
   - Watch requests N times, last one has hasMore=false

4. **Large Complication**
   - Test with complex complication data
   - Verify individual message stays under size limits

5. **Network Interruption**
   - Start sync, lose connectivity mid-way
   - Verify partial sync doesn't corrupt database

## Performance Considerations

- **Message Frequency:** Each complication requires one round-trip
- **Typical Timing:** ~0.1s per complication over local connection
- **Database:** Realm write for each complication (fast)
- **UI Impact:** Sync happens in background, doesn't block UI

## Future Enhancements

Potential improvements to consider:

1. **Batch Requests**
   - Request multiple indices at once
   - Balance between payload size and round-trips

2. **Delta Sync**
   - Only sync changed complications
   - Use modification timestamps or checksums

3. **Compression**
   - Compress JSON data before sending
   - Significant savings for text-heavy complications

4. **Cancellation**
   - Allow user to cancel sync mid-process
   - Add cancellation token to protocol

5. **Progress UI**
   - Show sync progress indicator in watch app
   - Display "Syncing complications 3 of 5..."

## Related Files

- `WatchCommunicatorService.swift` - Phone sync logic
- `WatchHomeViewModel.swift` - Watch sync initiation
- `ExtensionDelegate.swift` - Watch sync handling
- `ComplicationController.swift` - Provides complications to watchOS
- `WatchComplication.swift` - Data model

## Version History

- **v1.0** (Current) - Paginated sync protocol implemented
- **v0.x** (Legacy) - Single-message Context sync (deprecated)
