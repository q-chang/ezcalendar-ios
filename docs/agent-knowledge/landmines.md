# Landmines

Ten things in this repo that are not what they look like. **Each was verified
against the working tree** — by compiling, by running a grid harness, or by
reading the pbxproj. None is speculation.

Read this before any nontrivial change. Most of these will otherwise cost you a
debugging session on a bug you did not write.

| # | Landmine | Class |
| --- | --- | --- |
| [1](#1-the-demo-does-not-build-this-repos-sources) | Demo links a sibling checkout | 🔴 wasted work |
| [2](#2-ezcalendarxcodeproj-is-stale-and-does-not-build) | `EZCalendar.xcodeproj` is broken | 🔴 false alarm |
| [3](#3-calendarfirstweekday-is-ignored) | `firstWeekday` ignored | 🟠 wrong output |
| [4](#4-event-matching-is-exact-date-equality) | Exact `Date` equality for events | 🟠 silent no-match |
| [5](#5-calendarmonthhashstring-is-the-pagers-scroll-identity) | `hashString` includes `events` | 🟠 scroll jumps |
| [6](#6-duplicate-weekday-titles-collide-as-view-ids) | Duplicate `ForEach` ids | 🟡 SwiftUI identity |
| [7](#7-generatecalendarmonthsevents-silently-drops-its-argument) | `events:` arg dropped | 🟠 silent no-op |
| [8](#8-datestartofmonth--endofmonth-hardcode-gregorian) | Gregorian hardcoded | 🟡 latent |
| [9](#9-addingcomponentsofdate-uses-calendarcurrent) | `Calendar.current` leak | 🟡 latent |
| [10](#10-dateswift-exists-twice) | `Date+.swift` exists twice | 🟡 edit the wrong one |

---

## 1. The Demo does not build this repo's sources

`Demo/Demo.xcodeproj/project.pbxproj` contains:

```
XCLocalSwiftPackageReference "../../EZCalendar-Swift"
    relativePath = "../../EZCalendar-Swift";
```

That resolves to `/Users/wisanu/Workspaces/iOS/EZCalendar-Swift` — a **different
clone with a different remote** (`wisanu-dev/EZCalendar-Swift`, vs this repo's
`q-chang/ezcalendar-ios`). At time of writing it is one commit behind and its
files differ.

**Editing `Sources/EZCalendar/` here and building the Demo validates nothing.**
`xcodebuild ... -scheme Demo` will report BUILD SUCCEEDED against code you did not
change.

`scripts/demo/run-demo.sh` prints a warning about this on every run.

If asked to verify a library change in the Demo: say so, then either repoint the
package reference or fall back to `swift build` plus the grid harness.

---

## 2. `EZCalendar.xcodeproj` is stale and does not build

```
error: Build input file cannot be found:
  .../CalendarHorizontalPagging/EZCalendarHorizontalPagingViewModel.swift
```

That file was deleted in commit `9dfad87` ("Remove the view model") but is still
listed in the pbxproj. **The `EZCalendar` scheme has been broken since then. It is
not your change.**

Do not "fix" your way out of this by reverting work. SwiftPM is the source of
truth for the library target — use `swift build`. Repairing the pbxproj is only in
scope if the user asks.

---

## 3. `calendar.firstWeekday` is ignored

The grid is hardcoded Sunday-first.
[generateCalendar()](../../Sources/EZCalendar/Widgets/CalendarItem/EZCalendarItemViewModel.swift#L171)
compares the raw `.weekday` component (1 = Sunday) against a `1...7` column index
with no `firstWeekday` offset.

**Reproduction.** Dumping January 2026 with `firstWeekday = 1` and `firstWeekday = 2`
produces byte-identical grids:

```
 28* 29* 30* 31*   1   2   3
   4   5   6   7   8   9  10
  ...
```

Impact: Monday-first regions — most of Europe — get a Sunday-first calendar.

**The header has the same bias**, via `DateFormatter.shortWeekdaySymbols`
([line 102](../../Sources/EZCalendar/Widgets/WeekdayHeader/EZCalendarWeekdayHeaderView.swift#L102)),
which is always Sunday-indexed. So the two halves are at least *consistent*.

⚠️ **Fixing one without the other desynchronizes the header from the dates** —
a worse bug than the one being fixed. Change both or neither.

---

## 4. Event matching is exact `Date` equality

[EZCalendarItemViewModel.swift:377](../../Sources/EZCalendar/Widgets/CalendarItem/EZCalendarItemViewModel.swift#L377):

```swift
calendarMonth.events.contains(where: { $0.eventDate == date })
```

`CalendarDay.date` is midnight in the calendar's time zone. An event stamped
`14:30` — or built in a different time zone — **silently never matches**. No
warning, no dot.

Callers must normalize:

```swift
CalendarEvent(eventDate: calendar.startOfDay(for: rawDate))
```

A proper fix uses `calendar.isDate(_:inSameDayAs:)`, but that changes behavior for
existing consumers. Ask before doing it.

### 4b. Padding days never carry events

`hasEvents(from:)` is only called by `buildCalendarDayInCurrentMonth`. The two
padding builders hardcode the default `hasEvents: false`.

**Reproduction.** An event on Dec 31 2025, rendered in the January 2026 grid where
Dec 31 is a visible leading cell, flags **0** days.

---

## 5. `CalendarMonth.hashString` is the pager's scroll identity

[CalendarMonth.swift:16](../../Sources/EZCalendar/Models/CalendarMonth.swift#L16)
is `"\(hashValue)"`, and the synthesized `Hashable` conformance **includes
`events`**.

The pager uses it two ways:

- `.id(calendarMonth.hashString)` on each page ([line 151](../../Sources/EZCalendar/Widgets/CalendarHorizontalPagging/EZCalendarHorizontalPagingView.swift#L151))
- `.scrollPosition(id: $activeCalendarMonthHash)` ([line 159](../../Sources/EZCalendar/Widgets/CalendarHorizontalPagging/EZCalendarHorizontalPagingView.swift#L159))

So **injecting events into a month changes its identity mid-scroll**, and the
tracked position no longer matches any page. This is the scroll-jump class of bug
in this codebase. The Demo hits it: it loads events in `.onChange(of: currentMonth)`,
i.e. for the month the user just landed on.

Mitigation for callers: load events for a month *before* it scrolls into view.

Also: `hashValue` is **seeded per process**. Fine as a transient view id, never
persist it or compare it across launches.

---

## 6. Duplicate weekday titles collide as view ids

[EZCalendarWeekdayHeaderView.swift:109](../../Sources/EZCalendar/Widgets/WeekdayHeader/EZCalendarWeekdayHeaderView.swift#L109):

```swift
ForEach(weekDayTitles, id: \.self) { title in
```

The Demo passes `calendar.veryShortWeekdaySymbols`, which in English is
`["S","M","T","W","T","F","S"]` — two `"S"`, two `"T"`. Duplicate SwiftUI
identities in a `ForEach`.

Prefer `shortWeekdaySymbols` (`["Sun","Mon",...]`), or index the titles.

---

## 7. `generateCalendarMonths(events:)` silently drops its argument

[EZCalendarHelper.swift:87](../../Sources/EZCalendar/Helper/EZCalendarHelper.swift#L87)
accepts `events: [CalendarEvent] = []` and never writes it into the returned
months. Its own doc comment documents the parameter as working.

**Reproduction.** Passing one event across a 4-month range returns months with
`events == []` — total carried events: 0.

Attach events by replacing elements of the `calendarMonths` array instead.

---

## 8. `Date.startOfMonth` / `.endOfMonth` hardcode Gregorian

[Date+.swift:49](../../Sources/EZCalendar/Extensions/Date+.swift#L49):

```swift
let calendar = Calendar(identifier: .gregorian)
```

...ignoring any injected calendar. Harmless for Gregorian and Buddhist (identical
month boundaries), wrong for Hijri, Hebrew, and similar.

`generateCalendarMonths` normalizes its `startDate` through `startOfMonth`, so it
inherits this.

---

## 9. `addingComponentsOfDate` uses `Calendar.current`

[Date+.swift:22](../../Sources/EZCalendar/Extensions/Date+.swift#L22) adds
components via `Calendar.current`, not the injected calendar. All padding-day
arithmetic therefore runs on the system calendar.

Day-offset math makes this benign today. It is a latent bug, not a live one — but
it is the reason a "just pass the calendar through" refactor is less trivial than
it looks.

---

## 10. `Date+.swift` exists twice

| Path | Access | `toString` |
| --- | --- | --- |
| `Sources/EZCalendar/Extensions/Date+.swift` | internal | hardcodes Gregorian, no `locale` param |
| `Demo/Demo/Extensions/Date+.swift` | Demo-private | takes a `locale` parameter |

They have **diverged**. Changing one does not change the other, and the Demo's
calls to `Date.from(...)` resolve to its own copy — not to the library. See
[public-api.md](public-api.md#the-date-extension-is-not-public-api).
