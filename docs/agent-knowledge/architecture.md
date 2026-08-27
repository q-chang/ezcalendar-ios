# Architecture

## What this project is

A **logic-first** SwiftUI calendar library. It computes month grids — including
padding days borrowed from the adjacent months — and hands the caller
`CalendarDay` values. It renders no styling of its own; every cell comes from a
caller-supplied `@ViewBuilder`.

| | |
| --- | --- |
| Repo | `git@github.com:q-chang/ezcalendar-ios.git` |
| Product | one library target, `EZCalendar` |
| Platforms | iOS 17+, macOS 15+ |
| Toolchain | swift-tools-version 6.0, Swift 6 language mode |
| Dependencies | none — Foundation and SwiftUI only |
| Tests | **none** — see [building-and-verifying.md](building-and-verifying.md) |
| Latest tag | `1.3.1` (2026-02-10) |

## Design commitments

Do not violate these without asking. They are what the library is *for*.

### 1. No styling in the library

No default colors, fonts, or cell sizes anywhere in `Sources/`. If a change would
introduce an opinion about appearance, it belongs in the caller's `@ViewBuilder`.
The one deliberate exception is the fixed `1pt` `LazyVGrid` spacing, which exists
solely so a caller-supplied background can read as grid lines.

### 2. Zero dependencies

Foundation and SwiftUI. Adding a package dependency is a design change, not an
implementation detail.

### 3. Grid logic is separable from rendering

`EZCalendarItemViewModel` produces `[CalendarWeek]`; the views only lay it out.
Keep date math out of `body`. This is also what makes the logic testable at all —
see [grid-algorithm.md](grid-algorithm.md).

### 4. Layout is caller-sized

Views never impose a frame. Callers size cells, typically `proxy.size.width / 7`
under a `GeometryReader`. A view in this package that calls `.frame(width:height:)`
on its own content is a bug.

## Data flow

```
CalendarMonth (month + year + events)      ← the caller builds these
        │                                    (Ints, not a Date — see below)
        ▼
EZCalendarItemViewModel        (internal)  ← all date math lives here
        │
        ▼
[CalendarWeek] → [CalendarDay]             ← always exactly 7 days per week
        │
        ▼
EZCalendarItemView             (public)    ← LazyVGrid, one month
        │
        ▼
EZCalendarHorizontalPagingView (public)    ← paged strip + weekday header
```

`CalendarMonth` carries `month`/`year` as **integers in the era of the injected
calendar**, not a `Date`. With `Calendar(identifier: .buddhist)`, January 2026 CE
is `CalendarMonth(month: 1, year: 2569)`. This trips people up regularly.

## File layout

```
Package.swift                     tools 6.0, single library target
README.md                         user-facing docs — keep in sync with public API
AGENTS.md                         lean agent entry point (CLAUDE.md symlinks here)
docs/agent-knowledge/             this directory
scripts/demo/run-demo.sh          build + boot + install + launch the Demo
.agents/skills/                   project skills (.claude/skills symlinks here)

Sources/EZCalendar/
  Models/
    CalendarDay.swift             one grid cell — public struct, INTERNAL init
    CalendarWeek.swift            7 days (public)
    CalendarMonth.swift           month+year+events — the input unit (public)
    CalendarEvent.swift           uuid + eventDate (public class)
  Extensions/
    Date+.swift                   INTERNAL date helpers — not public API
  Helper/
    EZCalendarHelper.swift        generateCalendarMonths(...) (public)
  Widgets/
    CalendarItem/
      EZCalendarItemViewModel.swift    ★ all the date math (internal)
      EZCalendarItemView.swift         one month as a LazyVGrid (public)
    WeekdayHeader/
      EZCalendarWeekdayHeaderView.swift  public type, INTERNAL init
    CalendarHorizontalPagging/         (sic — misspelled, leave it)
      EZCalendarHorizontalPagingView.swift  the pager (public)

Demo/                             sample app — links a SIBLING checkout, not this
                                  repo. See landmines.md #1.
EZCalendar.xcodeproj              STALE and broken. See landmines.md #2.
EZCalendar.xcworkspace            wraps Demo + EZCalendar projects
```

`Sources/EZCalendar/Widgets/CalendarItem/EZCalendarItemViewModel.swift` is the
file that matters. Everything else is plumbing around it.

## A note on the source doc comments

Public types carry very large `/** ... */` blocks containing full Markdown —
headings, tables, usage examples. Several of them **describe signatures that no
longer exist** or behavior the code does not implement. `EZCalendarHelper`'s block
documents an `events:` parameter that is silently dropped; the weekday header's
block ends with a chat transcript fragment.

**Trust the code, not the comment.** Fix the comment when you touch the function.
