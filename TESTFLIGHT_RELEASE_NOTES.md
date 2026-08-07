# TestFlight release notes

## Week of 2026-08-01 → 2026-08-07

Big week for the Apple Watch — most actionable domains now have real controls
instead of just "run the action". Also a new Energy widget, deep links to
entities, and a round of Mac polish.

### Apple Watch

- Added light, cover, fan, climate, vacuum and lock controls, using split-tap
  rows: tap the row to toggle, tap the trailing area to open the detailed
  control.
- Added areas browsing to the watch home, and areas can now be added as home
  items.
- Added Assist and Assist prompt items, configurable from the iPhone or from
  the watch itself. Assist opens a session with the chosen pipeline; Assist
  prompt sends its text and plays the response.
- Rectangular complications can now be added from the watch item list.
- Lock controls now show a loading indicator, ask for confirmation before
  opening, and give haptic feedback.
- Fixed lock, cover and vacuum buttons triggering each other.
- Fixed home items not responding to taps.
- Fixed legacy complications rendering blank on the watch face.
- Fixed complications freezing at old values.
- Fixed complication gauges ignoring an edited min/max range.
- Fixed icon colors in the watch configuration "add item" menu.

### CarPlay

- Added climate and vacuum controls.
- Entity icons now match the frontend.
- The delete confirmation when editing items only shows for items that don't
  already ask for run confirmation.

### Widgets

- New **Energy** widget (small, medium and large) mirroring the energy
  dashboard: pick a server, a source (Auto / Consumption / Solar) and a period
  (Today / Yesterday / This week / This month). Shows solar generation, grid
  consumption and the period cost.

### Entity picker and "Add to"

- Pull to refresh on iOS (reload button on macOS) to update the entity list
  from the server, with inline progress.
- Hidden entities no longer clutter the browse list, but now show up when you
  search for them.
- "Add all" is now "Select all", and there's a new "Remove all".
- New **Deeplink** option in the entity "Add to" menu: copies a deep link to
  that entity's more info dialog. Links are server-agnostic by default, with an
  "Include server" toggle for multi-server setups.
- Entity icons now match the frontend.
- Fixed search field spacing.

### Mac

- New macOS Tahoe Liquid Glass app icon, plus an updated app icon and dark mode
  appearance.
- The launch splash is disabled on Mac Catalyst.
- Stand-by no longer shows the settings gear or the clean cache / reload button
  on Mac.
- Mac-specific wording for the General settings description.

### Connection and authentication

- Re-authentication is now triggered when the websocket rejects the access
  token, and the frontend shows an error empty state when it can't
  authenticate.
- The suggested re-authentication URL respects a Home Assistant Cloud opt-out —
  remote UI is no longer preselected when Cloud is off (unless it's the only
  URL configured).
- Server Switching is out of Labs.

### Other

- Datetime sensor states are formatted instead of showing the raw ISO string.
- Watch and CarPlay entity states respect the entity's display precision.
- The remaining legacy Siri intents were migrated to App Intents, so shortcuts
  built with the old intents keep working after updating.
- "Remember Last Page" is now opt-in (off by default).
- Fixed kiosk mode "Hide status bar" having no effect.
- Fixed the stand-by loading logo not animating.

### Worth testing

- Watch controls for lights, covers, fans, climate, vacuums and locks —
  especially rows next to each other, which used to trigger one another.
- Complications: values refreshing, gauge ranges, and the legacy complication
  types on the watch face.
- The new Energy widget across sizes, sources and periods.
- Re-authentication when a token expires, on both Cloud and external-URL setups.
- Existing Siri shortcuts built before the App Intents migration.
