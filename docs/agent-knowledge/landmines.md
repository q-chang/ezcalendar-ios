# Landmines

Ten things in this repo that are not what they look like. **Each was verified
against the working tree** — by compiling, by running a grid harness, or by
reading the pbxproj. None is speculation.

Read this before any nontrivial change. Most of these will otherwise cost you a
debugging session on a bug you did not write.

| # | Landmine | Class |
| --- | --- | --- |
| [1](#1-the-demo-now-builds-this-repo-fixed) | ~~Demo links a sibling checkout~~ — **fixed** | ✅ resolved |
| [2](#2-ezcalendarxcodeproj-is-stale-and-does-not-build) | `EZCalendar.xcodeproj` is broken | 🔴 false alarm |
| [3](#3-calendarfirstweekday-is-ignored) | `firstWeekday` ignored | 🟠 wrong output |
| [4](#4-event-matching-is-exact-date-equality) | Exact `Date` equality for events | 🟠 silent no-match |
| [5](#5-calendarmonthhashstring-is-the-pagers-scroll-identity) | `hashString` includes `events` | 🟠 scroll jumps |
| [6](#6-duplicate-weekday-titles-collide-as-view-ids) | Duplicate `ForEach` ids | 🟡 SwiftUI identity |
| [7](#7-generatecalendarmonthsevents-silently-drops-its-argument) | `events:` arg dropped | 🟠 silent no-op |
| [8](#8-datestartofmonth--endofmonth-hardcode-gregorian) | Gregorian hardcoded | 🟡 latent |
| [9](#9-addingcomponentsofdate-uses-calendarcurrent) | `Calendar.current` leak | 🟡 latent |
| [10](#10-dateswift-exists-twice) | `Date+.swift` exists twice | 🟡 edit the wrong one |
| [11](#11-geometry-probes-go-silent-off-screen) | Off-screen `GeometryReader`s stop reporting | 🔴 silent dead feature |
| [12](#12-scrollto-into-a-long-lazyvstack-lands-approximately) | `scrollTo` lands short in a long `LazyVStack` | 🟠 wrong output |
| [13](#13-a-draggesture-on-a-view-the-drag-moves-damps-itself) | A `DragGesture` on a view the drag moves damps itself | 🟠 wrong output |

---

## 1. The Demo now builds this repo (FIXED)

This used to be the worst trap in the repository: the Demo's package reference
was `relativePath = "../../EZCalendar-Swift"`, a *different clone with a
different remote*, so editing `Sources/EZCalendar/` here and building the Demo
validated nothing.

**It was repointed to `relativePath = ".."` — this repository.** A green Demo
build now does exercise your library changes, and `scripts/demo/run-demo.sh` no
longer warns.

Kept here because the old advice is still in circulation: if you find a comment,
commit message or doc saying the Demo builds a sibling checkout, that is stale.

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


---

## 11. Geometry probes go silent off-screen

Measuring a scroll view's content offset with a `GeometryReader` **only works
while the probe is near the viewport**. Two natural-looking probes were tried in
`EZCalendarAgendaView` and both failed identically:

```swift
// ❌ background of the LazyVStack — with a few hundred sections this view is
//    tens of thousands of points tall
LazyVStack { ... }.background(GeometryReader { ... })

// ❌ a 1pt sentinel above the content
ScrollView { Color.clear.frame(height: 1).background(GeometryReader { ... }); LazyVStack { ... } }
```

Both report **exactly once**, on first layout, and then never again. The agenda
list opens scrolled thousands of points down onto the selected day, so the single
reported value is `0` — and stays `0` forever.

**This fails silently.** There is no warning and no crash; whatever is built on
the probe simply never runs. A scroll-driven collapse gesture built on one was
completely dead for several build-and-look cycles before an on-screen debug
overlay showed `n1` — one callback, ever.

The section headers *do* keep reporting, because a `LazyVStack` only materialises
them near the viewport. If you need a scroll measurement in this list, derive it
from those.

(The gesture that prompted this has since been removed — the collapse is driven
by the grab handle alone — but the measurement trap is unchanged and will catch
the next thing built here.)

If you need a scroll offset here, measure something that lives near the viewport,
and **verify it updates more than once** before building on it.

### 11b. A pinned header never moves

Related, and the trap one level down: with `pinnedViews: [.sectionHeaders]`, the
*pinned* header sits at `minY == 0` for as long as its section is on screen,
however far the list scrolls. Anchoring a measurement to it yields a constant
zero. Any measurement derived from header positions has to exclude the one parked
at the top edge.

---

## 12. `scrollTo` into a long `LazyVStack` lands approximately

`ScrollViewProxy.scrollTo(id, anchor: .top)` across a few hundred
variable-height sections does not land exactly. SwiftUI estimates the offsets of
rows it has not built yet, and the estimate drifts over a long hop.

Undershooting by even one header height is not cosmetic in a two-way-synced list:
the *previous* day's header stays pinned at the top, the sync reads it as the day
on screen, and the calendar selects **the day before the one the user tapped**.
Reproduced by tapping 5 August and landing on 4 August.

`EZCalendarAgendaViewModel.correctScroll(towards:)` re-issues the scroll once the
target is materialised — at which point the estimate is exact — with a capped
number of attempts so an unreachable target (the last day in the range) cannot
wedge the sync latch open.


---

## 13. A `DragGesture` on a view the drag moves damps itself

`DragGesture` reports `translation` in the coordinate space of **the view it is
attached to**. If that view moves in response to the drag, its movement is
subtracted from the reading, and the gesture quietly measures short.

`EZCalendarAgendaView`'s grab handle sits directly under the calendar, so
collapsing the calendar pulls the handle up — under the finger doing the
collapsing. With the default (local) space:

```swift
// ❌ self-damping: the handle rises as the calendar closes
DragGesture(minimumDistance: 1)
```

a 150pt finger movement reported **−75**. The commit threshold silently needed
about twice the distance the caller configured, and the damping is not even
linear — it depends on how much calendar is left to close.

```swift
// ✅ measured against something that does not move
DragGesture(minimumDistance: 1, coordinateSpace: .global)
```

**This fails quietly in the worst way**: the gesture still works, still tracks,
still commits — just at the wrong distance. It reads as "the threshold feels too
stiff" rather than as a bug, and tuning the threshold to compensate would bake
the error in. It was found by rendering `value.translation.height` into an
on-screen overlay (see #11 — the same technique, for the same reason).

Anything else that drags a view whose position depends on the drag — a sheet, a
resizable pane, a pull-to-reveal header — has this bug unless it names a fixed
coordinate space.
