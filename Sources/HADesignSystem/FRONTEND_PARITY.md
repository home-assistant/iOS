# Frontend parity

Tracks the port of `home-assistant/frontend`'s UI components and dashboard cards into SwiftUI in this
package. The frontend is the design authority: when a component exists there, the Swift version takes
its capabilities, tokens and thresholds from `src/components/ha-*.ts` rather than inventing them, and
says so in a doc comment.

## The pattern

Every port is the same four steps, and the fourth is free:

1. **The component** — one type per file under `Sources/Components`, `public`, app-agnostic (no
   `Current`, no `L10n`, no `Server`; strings come through `HADesignSystemEnvironment`). Wrap it in
   `#if !os(watchOS)` if it touches UIKit.
2. **A `#Preview`** — required by `ha-ios-ui`, and the thing you actually iterate against in Xcode.
3. **Variants in `DesignSystemComponent`** — one `DesignSystemComponentVariant` per capability the
   component has: each alert type, each threshold, with and without the optional parts. This is what
   makes the in-app library a specification rather than a sampler.
4. **Snapshot coverage** — nothing to write. `ComponentsGallerySnapshotTests` iterates
   `DesignSystemComponent.allCases` and records one light and one dark image per component covering
   all of its variants. Adding a case to `variants` extends the recorded image.

Colours come from `Color+Semantic.swift`, which spells out the frontend token it mirrors. The full
CSS custom-property table is generated into `FrontendColors.swift` by `Tools/BuildFrontendColors.py`
— check there first before hardcoding a value.

## Triage

Not all 216 components and ~55 cards are worth porting. Each falls into one of:

- **Port** — presentational, no `hass` coupling. Belongs in this package.
- **Native** — SwiftUI already has it (`ha-checkbox` → `Toggle`, `ha-select` → `Picker`,
  `ha-dialog` → `.sheet`, `ha-textarea` → `TextEditor`). Port only as a styled wrapper, and only if
  the frontend's styling actually differs from the platform's.
- **App** — needs `hass` state, `Current`, or the entity registry (every `*-picker`, `ha-entity-*`,
  `ha-state-icon`). These live in `Sources/App`, not here; the package can only own the dumb shell
  they render into.
- **Skip** — web-only or editor-only: `ha-code-editor`, `ha-yaml-editor`, `ha-ansi-to-html`,
  `ha-sortable`, `ha-sidebar`, `ha-drawer`, `ha-split-panel`, `ha-hls-player`, `ha-web-rtc-player`,
  `ha-form`/`ha-selector`, `data-table`, and the config-panel filter panes.

## Batches

### 1 — Presentational primitives ✅

`ha-alert`, `ha-bar`, `ha-metric`, `ha-empty-state`, `ha-section-title`, `ha-tip`, `ha-label`,
`ha-big-number`, `ha-tree-indicator`.

### 2 — Status and structure ✅

Done: `ha-badge`, `ha-segmented-bar`, `ha-settings-row`, `ha-marquee-text`, `ha-faded`,
`progress/ha-progress-ring`.

`HAProgressRing` covers only the determinate ring; without a value it hands off to the package's
existing `HAProgressView`, which is already the `ha-spinner` equivalent and draws its own track.

`ha-expansion-panel` did not become a new type: `CollapsibleView` already was it, and gained the
`outlined`, `leftChevron` and `noCollapse` options it was missing.

Also done: `progress/ha-progress-bar` and `ha-toast`, both in the platform's idiom rather than the
web's. `HAProgressBar` draws the determinate bar and defers to `ProgressView`'s linear style when the
length is unknown, since an indeterminate animation cannot be snapshotted; it is distinct from
`HABar`, which is a *reading* rather than progress. `HAToast` is the surface only — when it appears
and when it leaves belongs to whatever presents it, which is also what keeps it snapshottable.

`ha-tooltip` is **Native**: a tooltip is a popover on iOS, and `.popover` already is one. Nothing to
add to the package.

### 3 — Chips, buttons and toggles ✅

Done: `chips/ha-assist-chip`, `chips/ha-filter-chip`, `chips/ha-input-chip`,
`ha-button-toggle-group`, `ha-icon-button-toggle`, `buttons/ha-progress-button`.

`chips/ha-chip-set` needs no type — it is a wrapping row, which `FlowLayout` already is.

`PillView` is **not** the `ha-filter-chip` equivalent, despite the resemblance. It is the app's own
brand-filled capsule (server pickers); the filter chip is a Material 3 selectable chip with a
leading check and a neutral 15% fill. They are different components and both stay.

Also done: `ha-tab` and `ha-tab-group` as `HATabGroup` — the config panel's tab bar, not the app's
main navigation, which is `TabView`'s job — and `ha-icon-button-group`.

`ha-outlined-button` and `ha-outlined-icon-button` need no types: `.outlinedButton` in
`HAButtonStyles` already is one, and `HAControlButton` is the icon form.

`HAIconButtonGroup` does not slide a thumb between positions as the frontend does; each toggle draws
its own circle. A shared thumb would have to animate between children, and the gallery snapshot could
only ever catch it mid-slide.

### 4 — Controls ✅

`ha-control-button`, `ha-control-button-group`, `ha-control-switch`, `ha-control-slider`,
`ha-control-select`, `ha-control-number-buttons`, `ha-control-circular-slider`, `ha-select-box`
and `ha-gauge`.

The value maths lives apart from the drawing, in `HASliderScale` and `HACircularSliderScale`, each
with unit tests — a snapshot shows a bar or an arc of some length, not whether the value behind it
was clamped, snapped and bounded in the right order. The two scales are deliberately *not* one type:
the linear slider clamps after snapping, while the dial snaps without clamping because its bounds
depend on the other handle. `HAControlNumberButtons` shares `HASliderScale` with the linear slider,
since the frontend applies the same rule in both.

`ha-labeled-slider` is a label plus `ha-control-slider` and needs no separate type.

`HAGauge` is the dashboard's 180° dial. It is **not** `WidgetGaugeArcView`, which sweeps 270° for the
Home Screen; the two are not interchangeable. It takes its diameter as a parameter rather than
growing from the offered width, because the arcs are shapes with no intrinsic size and an aspect
ratio around them collapses to nothing under an unbounded height proposal — which is what a
`sizeThatFits` snapshot offers.

`ha-control-select-menu` is the one left, and it is arguably **Native**: a menu anchored to a
control is `Menu` on iOS.

### 5 — Tile ✅

`ha-card`, `tile/ha-tile-icon`, `tile/ha-tile-badge`, `tile/ha-tile-info`, and `hui-tile-card` —
which is `ha-tile-container` and the card together, since the container is not useful alone.

`HATileCard` is **not** `WidgetTileView`: that one draws the Home Screen widget's tiles at widget
sizes from a `WidgetTileModel`. Keep them apart.

`HACard` overlaps the older `CardView`, which the app's settings screens use. They are the same idea
with different metrics — `ha-card` is a 12pt radius with the divider border and the card background;
`CardView` is 8pt with `onSurface` and no background. `HACard` is the one that matches the frontend;
fold `CardView` into it when the dashboard cards land, rather than restyling it under its existing
call sites now.

## Known defect: outlined controls fringe

`HAButtonStyles`' outlined styles stroke their border *on* the path, so half its width falls outside
the shape and shows as a hairline nick at the widest points — visible against the card in the alarm
panel's recorded image. `strokeBorder` on an inset shape is the fix, as used in `HALabel`, `HABadge`
and `haChipShape`. Left alone here because changing a shared button style re-records
`HAButtonStyles.test` and touches every button in the app, which wants its own review rather than
riding along with a batch of ports.

## Text that must wrap needs `fixedSize`

`Text` answers a short height proposal by dropping to one line and ellipsizing, and a
`sizeThatFits` snapshot offers exactly that. Any text meant to wrap — a faded paragraph, a form
field's label, a tip — needs `.fixedSize(horizontal: false, vertical: true)` so it takes the height
it needs at the offered width. Three components shipped with this bug before it was recognised;
if a recorded image ends in "…" where it should have wrapped, this is why.

## A note on minimum-only frames

`.frame(minHeight: x)` with no other dimension resolves to `x` when the height proposal is zero,
which is what a `sizeThatFits` snapshot hands it — so content taller than the minimum overflows
instead of growing the frame. `HATileCard` hit this: both orientations rendered at exactly 56pt, and
the vertical tile's text hung out of the card. Apply such a floor only where the content really can
be shorter than it, and check the recorded image rather than trusting the modifier.

### 6 — Dashboard cards ✅ (bar the sankey-shaped ones)

Done: `hui-entity-card`, `hui-button-card`, `hui-glance-card`, `hui-gauge-card`,
`hui-markdown-card`, `hui-heading-card`, `hui-clock-card`.

Cards take plain values the app maps entity state onto — the same split the widgets already use
(`WidgetTileModel` and friends). The package must not learn what an entity is.

`HAClockCard` takes the instant as a parameter rather than reading the clock, so it renders the same
way twice; the same trick suits anything else time-dependent. `HAMarkdownCard` uses
`AttributedString`'s Markdown parser, which handles inline syntax but not block structure — headings
and lists arrive as plain lines, which is a smaller subset than the frontend renders.

Also done: `hui-thermostat-card` (composes `HAControlCircularSlider`), `hui-todo-list-card`,
`hui-weather-forecast-card`, `hui-alarm-panel-card`, and `hui-picture-card` — which covers
`hui-picture-entity-card` too, since they differ only in whether the picture is captioned. It takes a
resolved `Image`, as `HASelectBox` does, since the package fetches nothing.

And: `hui-statistic-card`, `hui-humidifier-card` and `hui-picture-glance-card`, the last built on
`HAPictureCard`'s footer slot, which was put there for it.

`HAHumidifierCard` is the thermostat card's furniture with a humidity range and a green dial. The
frontend keeps them as separate cards for the same reason: what they read, and the colour they read
it in, differ even though the layout is identical.

Also done: `hui-entities-card` with `HAEntityRow`, and `hui-light-card`.

`HAEntityRow` covers the whole `hui-*-entity-row` family. The frontend has a row type per domain —
toggle, text, cover, climate, number, input — but they are one shell with different trailing content,
exactly as the card features are one control each. A row's *action* is plain accent text, not a
button style: the rendered card puts bare blue words there, and a padded pill in a 40pt row crowds
out the entity's name.

The layout cards — `hui-grid-card`, `hui-horizontal-stack-card`, `hui-vertical-stack-card` — need no
types: they are `LazyVGrid`, `HStack` and `VStack`. `hui-conditional-card` and
`hui-entity-filter-card` are behaviour, not drawing. `hui-iframe-card` is web-only, `hui-map-card`
wants MapKit, and `hui-picture-elements-card` is absolute positioning over an image — all **Skip**
or app work.

### 7 — Charts ✅ (partly)

Done: `chart/state-history-chart-line` as `HAHistoryChart`,
`chart/state-history-chart-timeline` as `HAHistoryTimeline`, and `hui-history-graph-card`, which
carries both — a history panel mixes them, since a temperature makes a line and a door makes bands.

`HAHistoryChart` takes its time zone explicitly. Swift Charts formats an automatic date axis in the
*system's* zone and does not consult `\.timeZone` in the environment, so a chart left to itself reads
"2 AM" on one machine and "12 AM" on another. Anything else plotting dates needs the same treatment.

Give each history a `series:` value in its `LineMark`. Without it the marks merge into one series,
which joins the end of one reading to the start of the next and paints them all one colour.

Also done: `chart/statistics-chart` with `hui-statistics-graph-card`, and
`hui-energy-distribution-card`. Statistics are bars, not a line: a statistic covers a *span*, so a
line between two of them would imply values nobody measured.

`HAEnergyDistributionCard` reads the figures as a summary rather than drawing the frontend's flow
diagram with dots travelling along its paths. Those dots are continuous animation, which a snapshot
cannot capture twice the same way — a decision, not an omission.

Also done: `chart/ha-sankey-chart`. Its arithmetic is in `HASankeyLayout`, tested apart from the
drawing for the same reason the slider scales are — a diagram of plausible shapes looks right whether
or not the flows add up.

Also done: `chart/ha-sunburst-chart`, whose angles are in `HASunburstLayout` — children divide their
parent's wedge rather than the whole circle, and need not add up to it, so a partial breakdown draws
as a partial inner ring instead of distorting the ring outside it.

Also done: `hui-energy-sources-table-card` as `HAEnergySourcesTable`, and
`hui-energy-date-selection-card` as `HAEnergyPeriodSelector` — the card holds nothing but
`hui-energy-period-selector`, so that is what was ported.

The rest of `cards/energy/*` need no types. The graph cards are `HAStatisticsChart` or
`HAHistoryChart` over a different statistic; the gauge cards are `HAGaugeCard` with levels;
`hui-energy-compare-card` is an `ha-alert`, which is `HAAlertView`. What they add is which statistic
to fetch, and that is app work.

### 8 — Date and time inputs ✅

`ha-base-time-input` as `HABaseTimeInput`, with `ha-time-input` (`HATimeInput`) and
`ha-duration-input` (`HADurationInput`) wrapping it, plus `ha-date-input` (`HADateInput`) and
`ha-absolute-time` (`HAAbsoluteTime`).

These were the last five components not covered by a triage rule — the audit below found them.

The carries in `ha-duration-input`'s `_durationChanged` are in `HATimeComponents.normalized`, tested
apart from the drawing like the slider scales. They are **not uniform**, and each asymmetry is the
frontend's rather than an oversight, so each has a test pinning it:

- Milliseconds carry into seconds whenever they exceed 999, even with the millisecond box hidden —
  the frontend only skips that branch when the value is *also* already zero.
- Seconds carry only when the second box is shown. With it hidden, 90 seconds stays 90.
- Minutes carry unconditionally.
- Hours carry only past **24**, not at it, so a flat day's worth stays spelled "24h" while 25 becomes
  "1d 1h".

The boxes are a fixed 60pt wide, because the frontend's `.time-input-wrap` is sized to its content.
A `TextField` given a flexible frame swallows the container instead, which is what the first
recording showed — the row filled all 350pt rather than ending after the minutes.

`TopRoundedRectangle` is the shape of a Material filled field: rounded on top, square along the
bottom so the underline reads as one continuous rule rather than a border around each box. It is
shared with `HADateInput` and belongs to any further form input. `UnevenRoundedRectangle` says the
same thing in a line but is iOS 17.

`HAAbsoluteTime` takes both instants like `HARelativeTime`, for the same reason: a view that read the
clock itself could not be snapshotted.

### 9 — Markdown, QR code and QR scanner ✅

The three that were triaged **Port** and then deferred.

`ha-markdown` / `ha-markdown-element` as `HAMarkdownText`, which `HAMarkdownCard` now renders
through. `AttributedString(markdown:)` reads inline syntax well and block structure not at all, so
`HAMarkdownParser` recovers the block layer — headings, lists including GFM task lists, fenced code,
quotes, thematic breaks and tables — and hands each block's text back to Foundation for the inline
pass. The parser is pure and tested apart from the drawing.

`ha-qr-code` as `HAQRCode`, through Core Image rather than a dependency. **The generator emits
opaque black on opaque white, which a template image cannot use**: template rendering reads alpha
alone, so the first recording was six solid squares. Inverting and then reading luminance as alpha
(`colorInvert` → `maskToAlpha`) makes the data modules opaque and the field transparent.

Every recorded symbol was decoded back to its source string with `CIDetector`, in both light and
dark mode. Do this for anything generated rather than drawn — a QR code that looks plausible and
does not scan passes a snapshot test perfectly.

`ColorContrast` lifts the frontend's `common/color/rgb.ts` out of `HALabel` so `HAQRCode` can share
it. A themed code whose foreground falls below a 3:1 ratio against its background gets the
foreground redrawn, as the frontend does, rather than rendering unscannable.

`ha-qr-scanner` as `HAQRScanner` for the chrome and `HACameraPreview` for the AVFoundation capture —
the same split the frontend makes between its `render` and the `qr-scanner` library it drives. The
status is injected rather than discovered, so every state can be previewed and snapshotted; whether
a camera exists and whether the user allowed it are the app's questions. **The live-camera state is
deliberately absent from the gallery**, so no snapshot run can trip a permission prompt.

The viewfinder takes an explicit size, for the reason `HAGauge` takes a diameter — see the note on
minimum-only frames below.

### 10 — The rest of the cards ✅

A second audit, this time over the whole frontend (1420 custom elements, narrowed to `components/`,
`components/chart/`, `panels/lovelace/cards/`, `card-features/`, `entity-rows/` and `badges/`), found
nine more that were genuinely missing rather than covered by a rule:

`HASparkline` (`hui-graph-base`) with `HASparklineGeometry`, `HAAnalogClock`
(`hui-clock-card-analog`), `HASensorCard`, `HAErrorCard`, `HALogbookCard`, `HAMediaControlCard`,
`HAPlantStatusCard`, `HACalendarCard` and `HAAreaCard`.

The sparkline is not Swift Charts, unlike `HAHistoryChart`: it has no axes to format and no time
zone to get wrong, and the frontend's smoothing is a specific curve a chart library would substitute
its own for. `get-path.ts` makes each reading a *control* point and passes the curve through the
midpoints between readings, which is what stops the line overshooting past a spike.

`HACalendarCard` deliberately diverges: the frontend writes event titles into the day cells, which is
unreadable at phone width, so the month is dots and the titles are a list under it.

**Watch for a name already taken in `Shared`.** `HACalendarEvent` exists there, so the card's event
type is `HACalendarCardEvent`.

## Every card a user can add to a dashboard is covered

`LovelaceCardCoverageTests` pins all **71** card types from the frontend's
`create-element/create-card-element.ts` — `ALWAYS_LOADED_TYPES` + `LAZY_LOAD_TYPES`, which is the
registry the card picker is built from and so exactly the set of `type:` values a dashboard config
can contain. Each is either a component, a named composition, or excluded with a reason.

That check found one card genuinely missing: `hui-distribution-card`, now `HADistributionCard`. The
bar is `HASegmentedBar`; the card adds the empty state, the legend that collapses behind a
show-more chip, and legend entries that exclude a source. Excluding is the point — one dominant
source flattens every other slice into a sliver, so hiding it removes it from the **total** as well
as from the bar and the rest can be compared.

Its legend is the card's own rather than `HASegmentedBar`'s, because this one carries each source's
amount. The frontend makes the same split: `hui-distribution-card` renders a `ul.legend` around a
bar-only `ha-segmented-bar`.

Two things the audit settled that had been assumed:

- **The newer cards have converged on the tile shape.** `hui-shortcut-card`, `hui-toggle-group-card`,
  `hui-updates-card` and `hui-home-summary-card` are each nothing but a `ha-tile-container` +
  `ha-tile-icon` + `ha-tile-info`. They need no component; they are `HATileCard` with different
  content.
- **Two cards are literal subclasses upstream.** `hui-entity-button-card extends HuiButtonCard` and
  `hui-shopping-list-card extends HuiTodoListCard`, so `HAButtonCard` and `HATodoListCard` cover them
  by construction rather than by resemblance.

The count is pinned deliberately, so a card type *disappearing* upstream is as visible as one
arriving.

## The mapping is a protocol, not a comment

`FrontendComponent` requires a `frontendComponentName`, and 134 types declare one. Conformance means
"this is a port"; the nine components with no counterpart deliberately do not conform, and that
absence is the mapping.

`DesignSystemComponent.frontendComponentName` reads each name off the component's own conformance
rather than repeating it, so an element name has one home. Generic view types are specialised with
`AnyView` only because a static member cannot be read off an unbound generic.

The property is computed, not stored — generic types cannot have stored statics.

`FrontendComponentMappingTests` keeps it honest: every gallery case must either name an element or be
listed as app-native, so a new port cannot quietly arrive unmapped.

## What the re-comparison found

With the mapping in place, every ported component was re-checked against its gallery page. Three of
the nine just added were wrong in ways that compiled and looked plausible:

- **`hui-media-control-card`** — the artwork is a *square on the trailing edge* over a flat colour
  block, faded in by a gradient, with the transport stacked under the title. Not a full-bleed image
  with a dark scrim and controls beside the title. Its text colour is contrast-derived from the
  block, so a yellow cover takes dark text.
- **`hui-plant-status-card`** — readings sit side by side as centred columns, and a problem bolds the
  value as well as reddening it. The name over a picture sits in a flat `rgba(0,0,0,.54)` band.
- **`ha-markdown`** — headings keep shrinking to h6; collapsing h5 and h6 to one size loses the only
  thing telling them apart.

All three were layout errors invisible to the compiler and to a snapshot with nothing to compare
against. **The gallery page is the check; build against it, not against the CSS alone.**

## Every component names its frontend counterpart

Every file in the package says in its doc comment which frontend element it corresponds to, or
states plainly that there is none. All 148 of them, not just the ported ones: an app-native
component that says "Frontend counterpart: none" and why is as useful to the next reader as a port
that names its element, because it answers the same question without them having to go and check.

Supporting types name what they mirror rather than an element — `HAGlanceItem` is the frontend's
`GlanceConfigEntity`, `HASankeyNode` its `Node` and `Link`, `HAChartSeries` the data
`state-history-chart-line` is handed. Layout and value maths split out of a component names the
element it was split from, since the frontend keeps that arithmetic inside the element.

Three types overlap with a later port and say so rather than pretending to be the counterpart:
`CardView` against `HACard`, `PillView` against the chip family, and `TextButton` against
`HAButtonStyle`.

## Every frontend component is accounted for

An audit of all 206 `ha-*` elements against this document found 130 not named individually. Bucketing
those by the category rules above resolved all but five — the date and time inputs, now batch 8. The
rest split as: 35 pickers and 6 icon elements needing `hass` or the entity registry, 28 Native, 13
App, 13 config-panel filter panes, 8 editors, 5 state formatters, 2 Skip, and 15 already built but
recorded here under their Swift name rather than the element's.

Two were worth re-checking because the `-picker` rule is broad, and both were bucketed correctly:
`ha-color-picker` is a combo box over theme colours, not a swatch grid, and `ha-grid-size-picker`'s
class is `HaGridSizeEditor` — dashboard card-editor UI.

## Checking against the rendered frontend

`https://design.home-assistant.io` is the frontend's own gallery, and it renders the real components.
Screenshotting it with a headless browser and comparing against the recorded images is worth more
than reading CSS: it found three components that compiled, looked plausible and were wrong — the tile
card washing its whole surface when active, the gauge putting its value under the dial instead of
inside it, and the slider's cursor drawn as fill rather than as a grip. Do this before trusting a
port, not after someone reports it.

The gallery does not cover everything, though: it has no page for the date and time inputs, so batch
8 was built from the markup and CSS alone. When there is nothing to screenshot, say so rather than
implying the port was checked against a rendering.

## What is left

Everything triaged as **Port** is done. Batch 9 closed the last three; nothing is deferred.

The card features under `panels/lovelace/card-features/` need no types of their own: each is a
composition of controls that are already here. `hui-light-brightness-card-feature` is an
`HAControlSlider`, `hui-cover-open-close-card-feature` is an `HAControlButtonGroup` of
`HAControlButton`s, the mode features are `HAControlSelect`, and the target temperature and humidity
features are `HAControlNumberButtons`. What the features add is the mapping from entity state, which
is app work.

`ha-icon` / `ha-svg-icon` / `ha-domain-icon` / `ha-service-icon` stay split: the icon *lookup* is app
work, since it needs the entity, and the drawing is already `MaterialDesignIconsImage`.

The rest of the frontend's ~206 `ha-*` components fall under **Native**, **App** or **Skip** — see
the triage above. Anything that needs `hass` state belongs in `Sources/App`, filling the shells here.

Accounting for the last few by name, so nobody has to re-derive them: `ha-icon-next` / `ha-icon-prev`
are chevrons, which SwiftUI flips for RTL on its own; `ha-icon-overflow-menu` is `Menu`;
`voice-assistant-brand-icon` is an app asset; and `buttons/ha-call-service-button` is
`HAProgressButton` wired to a service call, which is app work.
