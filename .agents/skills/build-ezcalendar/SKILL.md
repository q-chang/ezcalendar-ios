---
name: build-ezcalendar
description: Build and sanity-check the EZCalendar package and its Demo app. Use whenever you change anything under Sources/EZCalendar or Demo/, or when asked to "build", "compile", or "check it still builds". Covers which build commands work in this repo and which are known-broken.
---

# Building EZCalendar

## The one command that matters

```bash
swift build
```

Fast (~7s cold), builds the library for macOS in Swift 6 language mode. **Run this after every source change.** A clean `swift build` is the baseline for calling any change done.

## Building for iOS

The package targets iOS 17+, but `swift build` only exercises the macOS slice. To confirm an iOS build, use the Demo app instead of the package scheme:

```bash
xcodebuild -workspace EZCalendar.xcworkspace -scheme Demo \
  -destination 'generic/platform=iOS Simulator' \
  build
```

This takes a few minutes. Add `-derivedDataPath <scratchpad>/dd` to keep artifacts out of the user's DerivedData.

> ⚠️ **The Demo builds against a sibling checkout, not this repo.** `Demo/Demo.xcodeproj` has an `XCLocalSwiftPackageReference` with `relativePath = "../../EZCalendar-Swift"` — a *different* clone (remote `wisanu-dev/EZCalendar-Swift`) that is behind this one. A green Demo build does **not** validate your changes to `Sources/EZCalendar`. Either repoint that reference, or rely on `swift build` plus a temporary test target (see the `verify-calendar-grid` skill).

## Known-broken: the `EZCalendar` xcodeproj scheme

Do **not** use this — it fails, and it is not your change that broke it:

```bash
# BROKEN
xcodebuild -scheme EZCalendar -destination 'generic/platform=iOS Simulator' build
```

```
error: Build input file cannot be found:
  .../Widgets/CalendarHorizontalPagging/EZCalendarHorizontalPagingViewModel.swift
```

`EZCalendar.xcodeproj` still lists `EZCalendarHorizontalPagingViewModel.swift`, deleted in commit `9dfad87` ("Remove the view model"). The checked-in xcodeproj is stale; SwiftPM is the source of truth for the library target. Fixing the pbxproj is only in scope if the user asks.

## Checklist before reporting a change complete

1. `swift build` succeeds with no new warnings.
2. If the change touches date math, run the grid harness (`verify-calendar-grid` skill).
3. If the change touches public API, confirm the symbol is actually `public` — this repo has several `public struct`s with internal members (see AGENTS.md).
