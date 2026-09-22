# Changelog

All notable EZCalendar changes are documented here. The git tag is the
authoritative package version.

## Unreleased

### ✨ Features
- 

### 🐛 Fixes
- 

### 📚 Documentation
- 

### ⚠️ Breaking changes
- None.

### Installation
```swift
.package(url: "https://github.com/q-chang/ezcalendar-ios", from: "NEXT_VERSION")
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
