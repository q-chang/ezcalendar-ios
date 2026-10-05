# Changelog

All notable EZCalendar changes are documented here. The git tag is the
authoritative package version.

## Unreleased

### ✨ Features
- Added `.selectableDateRange(_:)` to `EZCalendarAgendaView` so callers can
  constrain which calendar days can be selected. Out-of-range days remain
  visible, expose `isSelectable == false` through `EZCalendarDayContext`, and
  ignore taps.

### 🐛 Fixes
- Kept agenda selection and list scrolling within the configured date range.
  The final selectable day no longer scrolls into a viewport-sized blank area
  after the last section.

### 📚 Documentation
- Documented the selectable date range modifier and its behavior in the README
  and public API guide.

### ⚠️ Breaking changes
- None.

### Installation
```swift
.package(url: "https://github.com/q-chang/ezcalendar-ios", from: "NEXT_VERSION")
```

## EZCalendar 2.2.1

This release fixes list scroll misalignment and desynchronization when calendar events
load asynchronously or across large date ranges on iOS.

### 🐛 Fixes
- **Async Data Load Re-anchoring**: Fixed an issue where the agenda list content shifted away
  from the selected date (e.g. landing on an earlier day) after events loaded asynchronously.
  `EZCalendarAgendaView` now automatically re-anchors to `viewModel.selection` on `eventsRevision`,
  `eventsFingerprint`, and `calendarMonths` updates, and `AgendaTableView` preserves the visible
  anchor section when applying diffable data snapshots.
- **Accurate Row & Header Height Estimation**: Implemented `tableView(_:estimatedHeightForRowAt:)`
  and `tableView(_:estimatedHeightForHeaderInSection:)` in `AgendaTableView`, differentiating
  empty days (~72pt) from event days (~140pt). This eliminates cumulative height estimation errors
  that previously caused long programmatic jumps (across months or a year) to undershoot.
- **Strict Verification & Directional Convergence**: Fixed premature verification exit in
  `AgendaTableView` where estimated section rects produced false-positive arrival detections.
  Verification now checks that the target section's header or row is genuinely visible in the viewport,
  and retries dynamically nudge `contentOffset.y` towards the target section index for swift convergence.
- **Diffable Data Source Mutation Safety**: Resolved `NSInternalInconsistencyException` crash caused
  by mutating section reloads with `UITableViewDiffableDataSource`; visible headers are now safely
  reconfigured directly via `headerView(forSection:).contentConfiguration`.

### 📚 Documentation
- Updated `docs/agent-knowledge/landmines.md` with landmines #17 and #18 covering diffable data
  source mutation constraints and un-rendered section estimation pitfalls.

### ⚠️ Breaking changes
- None.

### Installation
```swift
.package(url: "https://github.com/q-chang/ezcalendar-ios", from: "2.2.1")
```

## EZCalendar 2.2.0

This release makes the agenda list's iOS scroll positioning and sticky
headers exact and reliable, fixing a jump that previously landed one day
short and a sticky header that could scroll away with its own content.

### 🐛 Fixes
- `EZCalendarAgendaView`'s agenda list, on iOS, now scrolls to a selected day
  and shows the sticky header for whichever day is at the top of the list
  correctly and reliably. It previously undershot by one day (the previous
  day's header stayed pinned at the top) using SwiftUI's native
  `scrollPosition(id:anchor:)`, and continued to fail once, then twice, when
  ported to a `UICollectionView` bridge whose sticky headers never actually
  stuck on device. The agenda list on iOS is now a `UITableView` bridge —
  `Subviews/AgendaTableView.swift` — which sticks section headers by
  default and positions exactly, since `UITableView` precomputes every row's
  offset instead of estimating it. macOS is unaffected: it keeps the
  original SwiftUI-native `ScrollView`/`LazyVStack` implementation, since
  `UIKit` does not exist there.

### 📚 Documentation
- Added landmines for the diffable-data-source pitfalls this uncovered — see
  [landmines.md #14–16](docs/agent-knowledge/landmines.md).

### ⚠️ Breaking changes
- `EZCalendarAgendaView`'s `Event` generic parameter now also requires
  `Event.ID: Sendable`, needed for the `UITableView`/`NSDiffableDataSourceSnapshot`
  bridge under Swift 6 strict concurrency. Every realistic `Identifiable.ID`
  (`String`, `UUID`, `Int`, ...) already conforms, so this is very unlikely to
  affect an existing caller — but it is a new constraint on public API, not
  purely an internal change.

### Installation
```swift
.package(url: "https://github.com/q-chang/ezcalendar-ios", from: "2.2.0")
```

## EZCalendar 2.1.0

This minor release adds opt-in pull-to-refresh for agenda calendars while
preserving caller-owned visuals and data loading.

### ✨ Features
- Added `.pullToRefresh(minimumDisplayDuration:indicator:onRefresh:)` to
  `EZCalendarAgendaView`. It recognises downward vertical pulls only in the
  calendar area, keeps horizontal paging independent, and exposes caller-owned
  refresh visuals through `EZCalendarAgendaRefreshContext`. The indicator is
  inserted above `titleViewContent`, pushing the header and calendar down.

### 🐛 Fixes
- Restored lazy monthly paging while keeping its viewport synchronized with the
  measured visible month. Four-, five-, and six-row months render their complete
  grids; a sixth week no longer appears as an empty area below the fifth row.

### ✨ Demo app
- Added an interactive agenda pull-to-refresh example with a caller-styled
  header indicator and simulated asynchronous reload.

### 📚 Documentation
- Documented agenda pull-to-refresh, its refresh phases, and the caller-owned
  async loading lifecycle, including its placement above `titleViewContent`.

### ⚠️ Breaking changes
- None.

### Installation
```swift
.package(url: "https://github.com/q-chang/ezcalendar-ios", from: "2.1.0")
```

## EZCalendar 2.0.3

This patch fixes the agenda calendar's month height calculation for custom day
cell layouts.

### 🐛 Fixes
- `EZCalendarAgendaView` now measures each rendered week row and sizes the
  monthly calendar from the complete row set. Four-, five-, and six-row months
  no longer collapse into a five-row height or clip the final week.
- Monthly paging now lays out the complete page needed for reliable row-height
  measurement while preserving the existing weekly collapse behavior.

### 📚 Documentation
- Documented that agenda month height follows the rendered week rows and can
  therefore vary between months and caller-supplied day-cell layouts.

### ⚠️ Breaking changes
- None.

### Installation
```swift
.package(url: "https://github.com/q-chang/ezcalendar-ios", from: "2.0.3")
```

## EZCalendar 2.0.2

This release adds an optional configuration for the agenda calendar's
day-selection behavior. The existing behavior remains the default.

### ✨ Library
- Added `.collapseOnDaySelection(_:)` to `EZCalendarAgendaView`. Set it to
  `false` to keep the calendar in `.monthly` mode after selecting a day; the
  default `true` preserves the previous automatic collapse to `.weekly` mode.

### 📚 Documentation
- Documented the new agenda modifier and its default behavior in the README.

### ⚠️ Breaking changes
- None.

### Installation
```swift
.package(url: "https://github.com/q-chang/ezcalendar-ios", from: "2.0.2")
```

## EZCalendar 2.0.1

**No library changes.** `Sources/EZCalendar` is identical to 2.0.0: same public API, same behavior, same platform floor (iOS 17 / macOS 15). Updating is optional; a `from: "2.0.0"` requirement picks it up automatically.

This release adds date-selection examples to the Demo app and the README.

### ✨ Demo app
- **Horizontal Pagging: single date selection.** Tap a day to select it: it gets a ring, and the date appears under the calendar. Only days of the visible month can be selected, so one date is never marked on two pages.
- **New Range Selection screen.** A form field opens a bottom-sheet Start/End picker built on `EZCalendarHorizontalPagingView`, on the Thai Buddhist calendar.
  - 1st tap sets **Start Date**, 2nd tap sets **End Date**
  - A 2nd tap *before* Start makes that day the new Start; End stays empty
  - A 2nd tap *on* Start makes a one-day range (Start = End)
  - A tap after a complete range clears it and starts a new one
  - Start and End show as filled squares, with a continuous band between them, including across months
  - **เลือกวัน** saves the range and **✕** discards changes

### 📚 Documentation
- New **Date selection** section in the README with single-date and range examples, tap rules, a screenshot, and common pitfalls.
- The README install snippet now uses `from: "2.0.0"` instead of `from: "1.3.1"`.

### Installation
```swift
.package(url: "https://github.com/q-chang/ezcalendar-ios", from: "2.0.0")
```
