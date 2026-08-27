---
name: verify-calendar-grid
description: Empirically verify EZCalendar's month-grid date math by printing generated grids. Use before and after any change to EZCalendarItemViewModel, Date+.swift, EZCalendarHelper, or anything touching padding days, week counts, locales, or calendar systems. The repo ships no tests, so this is the only way to check date logic without running the app.
---

# Verifying the calendar grid

This repository has **no test target**. The grid logic in
[EZCalendarItemViewModel.swift](../../../Sources/EZCalendar/Widgets/CalendarItem/EZCalendarItemViewModel.swift)
is `internal`, so it cannot be exercised from an external package. The reliable
approach is a temporary, throwaway test target.

## Procedure

Work in a **copy** of the repo in your scratchpad so the user's tree stays clean.

### 1. Copy and add a test target

```bash
SCRATCH="$CLAUDE_SCRATCHPAD"          # or your session scratchpad path
cp -R /path/to/ezcalendar-ios "$SCRATCH/ezcopy"
rm -rf "$SCRATCH/ezcopy/.build" "$SCRATCH/ezcopy/.git"
mkdir -p "$SCRATCH/ezcopy/Tests/EZCalendarTests"
```

Add to `targets:` in the copied `Package.swift`:

```swift
.testTarget(
    name: "EZCalendarTests",
    dependencies: ["EZCalendar"]),
```

### 2. Write a grid dump

`Tests/EZCalendarTests/GridTests.swift` — uses swift-testing (`import Testing`),
which ships with the toolchain:

```swift
import Testing
import Foundation
@testable import EZCalendar

func dumpGrid(_ label: String, _ month: Int, _ year: Int, _ cal: Calendar) {
    let vm = EZCalendarItemViewModel(
        calendarMonth: CalendarMonth(month: month, year: year),
        calendar: cal
    )
    print("=== \(label) \(month)/\(year) firstWeekday=\(cal.firstWeekday) rows=\(vm.calendarWeeks.count) ===")
    for week in vm.calendarWeeks {
        print(week.calendarDays.map { d in
            let n = d.date.map { cal.component(.day, from: $0) } ?? 0
            // padding days are suffixed with *
            return d.isCurrentMonth ? String(format: "%4d", n) : String(format: "%3d*", n)
        }.joined())
    }
}

@Test func grids() throws {
    let g = Calendar(identifier: .gregorian)
    dumpGrid("jan-2026", 1, 2026, g)   // starts Thursday → leading padding
    dumpGrid("aug-2026", 8, 2026, g)   // 6-row month → trailing padding
    dumpGrid("feb-2026", 2, 2026, g)   // starts Sunday → exactly 4 rows, no padding
}
```

### 3. Run

```bash
swift test --package-path "$SCRATCH/ezcopy" 2>&1 | sed -n '/=== /,$p'
```

## Known-good baseline

Capture this **before** your change and diff against it after. Verified output on
the current `main`:

```
=== jan-2026 1/2026 firstWeekday=1 rows=5 ===
 28* 29* 30* 31*   1   2   3
   4   5   6   7   8   9  10
  11  12  13  14  15  16  17
  18  19  20  21  22  23  24
  25  26  27  28  29  30  31

=== aug-2026 8/2026 firstWeekday=1 rows=6 ===
 26* 27* 28* 29* 30* 31*   1
   2   3   4   5   6   7   8
   9  10  11  12  13  14  15
  16  17  18  19  20  21  22
  23  24  25  26  27  28  29
  30  31  1*  2*  3*  4*  5*
```

## Invariants to assert

- Every `CalendarWeek` has exactly **7** days.
- Row count is **5 or 6** (4 only when a 28-day month starts on the grid's first column, e.g. Feb 2026).
- Leading padding runs contiguously up to the 1st; trailing padding runs contiguously from the last day.
- Padding cells have `isCurrentMonth == false`; in-month cells have `true`.

## Pre-existing failures — do not "fix" by accident

These reproduce on unmodified `main`. If your dump shows them, that is the
baseline, not a regression you introduced:

- **`firstWeekday` is ignored.** `dumpGrid` with `cal.firstWeekday = 2` produces a
  grid byte-identical to `firstWeekday = 1`. The loop in `generateCalendar()`
  compares the raw `.weekday` component (1 = Sunday) against a 1...7 column index
  with no `firstWeekday` offset.
- **Padding days never carry events.** `buildCalendarDayInPreviousMonth` and
  `buildCalendarDayInNextMonth` never call `hasEvents(from:)`, so `hasEvents` is
  always `false` outside the month.
- **`generateCalendarMonths(events:)` drops its argument.** The returned months
  always have `events == []`.

## Also useful

Buddhist calendar — note the year is in the calendar's own era:

```swift
var b = Calendar(identifier: .buddhist)
b.locale = Locale(identifier: "th_TH")
dumpGrid("buddhist", 1, 2569, b)   // == January 2026 CE
```

## Clean up

Delete the scratch copy when done. **Never** commit a test target into the user's
repo unless they ask for one.
