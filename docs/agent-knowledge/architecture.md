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
| Tests | `Tests/EZCalendarTests/` — agenda logic only; the month grid is untested, see [building-and-verifying.md](building-and-verifying.md) |
| Latest tag | `2.2.0` (2026-09-28) — see [CHANGELOG.md](../../CHANGELOG.md) |

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

⚠️ **One documented exception.** On iOS, the agenda list's scroll positioning
and sticky headers are a `UIViewRepresentable` bridge to `UITableView`
(`Subviews/AgendaTableView.swift`), not pure SwiftUI. `UIKit` is a system
framework, not a package dependency, so this does not violate the letter of
this rule — but it is a real exception to "SwiftUI renders everything" worth
knowing about before assuming the agenda list is portable SwiftUI code. It
exists because SwiftUI-native scrolling (`ScrollViewReader`/
`scrollPosition(id:anchor:)`) and two different `UICollectionView`
sticky-header configurations all failed on device — see
[landmines.md #12](landmines.md#12-scrollto-into-a-long-lazyvstack-lands-approximately)
and [#14](landmines.md#14-two-different-uicollectionview-sticky-header-mechanisms-both-failed-on-device).
SwiftUI still renders every cell and header's *content*, through
`UIHostingConfiguration` — only identity, layout, and positioning moved to
UIKit. macOS keeps the original SwiftUI-native `ScrollView`/`LazyVStack`
implementation behind `#if os(iOS)`, since `UIKit` does not exist there.

### 3. Grid logic is separable from rendering

`EZCalendarItemViewModel` produces `[CalendarWeek]`; the views only lay it out.
Keep date math out of `body`. This is also what makes the logic testable at all —
see [grid-algorithm.md](grid-algorithm.md).

### 4. Layout is caller-sized

Views never impose a frame. Callers size cells, typically `proxy.size.width / 7`
under a `GeometryReader`. A view in this package that calls `.frame(width:height:)`
on its own content is a bug.

⚠️ **One documented exception.** `AgendaCalendarView` puts a `.frame(height:)`
clipping window around the calendar, because a month cannot animate down to a
single week without one. The height is never a constant: the grid reports its own
natural height through `AgendaGridHeightKey`, and the row height is divided back
out of it. Before the first measurement arrives the height is `nil` and the grid
sizes itself. Adding a *constant* frame anywhere is still a bug.

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

        └─────────────────────────────────► EZCalendarAgendaView (public)
                                              ← re-lays the same weeks row by
                                                row so they can fade and slide,
                                                over a date-grouped event list
```

`CalendarMonth` carries `month`/`year` as **integers in the era of the injected
calendar**, not a `Date`. With `Calendar(identifier: .buddhist)`, January 2026 CE
is `CalendarMonth(month: 1, year: 2569)`. This trips people up regularly.

## File layout

```
Package.swift                     tools 6.0, library + test target
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
    CalendarAgenda/
      EZCalendarAgendaView.swift          collapsible calendar + list (public)
      EZCalendarAgendaViewModel.swift     its state machine (internal, @MainActor)
      EZCalendarAgendaLogic.swift       ★ its pure date + geometry math (internal)
      EZCalendarAgendaModels.swift        day context, section, title context
      EZCalendarAgendaMode.swift          .monthly / .weekly
      EZCalendarAgendaPaging.swift        programmatic paging helper (public)
      Subviews/                           calendar, list, rows, preference keys
        AgendaListView.swift              grab handle + list container;
                                           #if os(iOS) branches to
                                           AgendaTableView, #else keeps the
                                           SwiftUI-native list for macOS
        AgendaTableView.swift             iOS only — UITableView bridge for
                                           exact scroll positioning + sticky
                                           headers (see architecture
                                           commitment #2 above)

Tests/EZCalendarTests/            Swift Testing suites over EZCalendarAgendaLogic
                                  and EZCalendarAgendaViewModel

Demo/                             sample app — links a SIBLING checkout, not this
                                  repo. See landmines.md #1.
EZCalendar.xcodeproj              STALE and broken. See landmines.md #2.
EZCalendar.xcworkspace            wraps Demo + EZCalendar projects
```

`Sources/EZCalendar/Widgets/CalendarItem/EZCalendarItemViewModel.swift` is the
file that matters. Everything else is plumbing around it — including
`EZCalendarAgendaView`, which consumes the very same `[CalendarWeek]` grid rather
than computing one of its own.

## A note on the source doc comments

Public types carry very large `/** ... */` blocks containing full Markdown —
headings, tables, usage examples. Several of them **describe signatures that no
longer exist** or behavior the code does not implement. `EZCalendarHelper`'s block
documents an `events:` parameter that is silently dropped; the weekday header's
block ends with a chat transcript fragment.

**Trust the code, not the comment.** Fix the comment when you touch the function.
