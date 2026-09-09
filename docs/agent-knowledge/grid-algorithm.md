# The grid algorithm

All of it lives in
[EZCalendarItemViewModel.swift](../../Sources/EZCalendar/Widgets/CalendarItem/EZCalendarItemViewModel.swift).
Read this before changing any date math.

**The algorithm is correct.** Leading padding, trailing padding, 5- and 6-row
months, and non-Gregorian calendars were all verified by dumping grids through a
throwaway test target. The problems are around it, not in it — see
[landmines.md](landmines.md).

## `generateCalendar()`

[Line 143](../../Sources/EZCalendar/Widgets/CalendarItem/EZCalendarItemViewModel.swift#L143).
Called once from `init`, so `calendarWeeks` is never empty for a frame.

### 1. Establish the month's boundaries

Four `guard`s, each returning `[]` on failure:

| Value | Source |
| --- | --- |
| `firstDateOfMonth` | `Date.from(year:month:day: 1, calendar:)` — the **injected** calendar |
| `numberOfDaysInMonth` | `calendar.range(of: .day, in: .month, for:)` |
| `firstDayOfWeekInMonth` | `.weekday` of the 1st (1 = Sunday) |
| `lastDayOfWeekInMonth` | `.weekday` of the last day |

Failure degrades to an empty grid rather than crashing. Preserve that.

### 2. Fill rows

`while dayOfMonth <= numberOfDaysInMonth`, with an inner `for weekDay in 1...7`
([line 168](../../Sources/EZCalendar/Widgets/CalendarItem/EZCalendarItemViewModel.swift#L168)):

- **First row** (`calendarWeeks.isEmpty`): columns where `weekDay < firstDayOfWeekInMonth` are filled from the previous month; the rest are in-month days.
- **Later rows**: in-month days until `dayOfMonth` exceeds the month, then trailing padding.

Every row is wrapped in a `CalendarWeek` with **exactly 7 days**. That invariant
is what makes the `LazyVGrid` 7-column layout safe.

### 3. Result shape

5 or 6 rows normally; **4** when a 28-day month starts on the grid's first column.
February 2026 is the live example — verified output:

```
  1   2   3   4   5   6   7
  8   9  10  11  12  13  14
 15  16  17  18  19  20  21
 22  23  24  25  26  27  28
```

A 6-row month, August 2026 (`*` marks padding):

```
 26* 27* 28* 29* 30* 31*   1
   2   3   4   5   6   7   8
   9  10  11  12  13  14  15
  16  17  18  19  20  21  22
  23  24  25  26  27  28  29
  30  31  1*  2*  3*  4*  5*
```

## The three day-builders

| Method | Line | Sets `hasEvents`? | Actually called? |
| --- | --- | --- | --- |
| `buildCalendarDayInCurrentMonth(_:)` | [244](../../Sources/EZCalendar/Widgets/CalendarItem/EZCalendarItemViewModel.swift#L244) | ✅ | ✅ |
| `buildCalendarDayInPreviousMonth(startDateOfMonth:diffDayFromStart:)` | [288](../../Sources/EZCalendar/Widgets/CalendarItem/EZCalendarItemViewModel.swift#L288) | ❌ always `false` | ✅ — for **both** leading and trailing padding |
| `buildCalendarDayInNextMonth(endDateOfMonth:diffDayFromEnd:)` | [345](../../Sources/EZCalendar/Widgets/CalendarItem/EZCalendarItemViewModel.swift#L345) | ❌ always `false` | ❌ **dead code** |

### The method names lie

`buildCalendarDayInNextMonth` is never invoked. The trailing-padding branch
([line 194](../../Sources/EZCalendar/Widgets/CalendarItem/EZCalendarItemViewModel.swift#L194))
calls `buildCalendarDayInPreviousMonth` instead, passing the **last** date of the
month with a **positive** offset:

```swift
let diffDay = weekDay - lastDayOfWeekInMonth        // positive
buildCalendarDayInPreviousMonth(
    startDateOfMonth: lastDateOfMonth,              // the LAST date
    diffDayFromStart: diffDay
)
```

Since the builder just does `date.addingComponentsOfDate(day: offset)`, a positive
offset walks forward and the dates come out right. The output above confirms it.

But if you refactor here, **the names describe an intent the code does not
follow.** Either wire up `buildCalendarDayInNextMonth` or delete it; leaving a
dead method that shadows the live one is how the next person introduces a bug.

## `hasEvents(from:)`

[Line 377](../../Sources/EZCalendar/Widgets/CalendarItem/EZCalendarItemViewModel.swift#L377):

```swift
calendarMonth.events.contains(where: { $0.eventDate == date })
```

Exact `Date` equality, and only ever called from the current-month builder. Both
facts are load-bearing bugs —
[landmines #2 and #4](landmines.md).

## Where the injected calendar is honored, and where it isn't

| Operation | Uses the injected calendar? |
| --- | --- |
| `Date.from(year:month:day:calendar:)` | ✅ |
| `calendar.range(of:in:for:)`, `.dateComponents` | ✅ |
| `addingComponentsOfDate(day:)` — all padding arithmetic | ❌ `Calendar.current` |
| `startOfMonth` / `endOfMonth` | ❌ hardcoded `.gregorian` |

The last two are [landmines #8 and #9](landmines.md). Day-offset arithmetic makes
them benign today, but any change that widens what those helpers compute will
surface them.

## Changing this file

There is no test suite. Use the `verify-calendar-grid` skill, which sets up a
throwaway test target in a scratch copy, dumps grids, and carries a recorded
baseline to diff against. Details in
[building-and-verifying.md](building-and-verifying.md).
