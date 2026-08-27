# AGENTS.md

Operating guide for AI agents working in **EZCalendar** — a SwiftUI calendar
library distributed via Swift Package Manager.

Read this before touching anything. Several things in this repo are not what they
look like, and the traps are listed in [Landmines](#landmines).

---

## 1. What this project is

A **logic-first** calendar library. It computes month grids (including padding
days borrowed from adjacent months) and hands the caller `CalendarDay` values.
It renders no styling of its own — every cell comes from a caller-supplied
`@ViewBuilder`.

- **Repo:** `git@github.com:q-chang/ezcalendar-ios.git`
- **Product:** one library target, `EZCalendar`
- **Platforms:** iOS 17+, macOS 15+
- **Toolchain:** swift-tools-version 6.0, Swift 6 language mode
- **Tests:** none. See [§6](#6-verifying-changes).
- **Dependencies:** none.

### Design commitments — do not violate without asking

1. **No styling in the library.** No default colors, fonts, or cell sizes. If a change would introduce an opinion about appearance, it belongs in the caller's `@ViewBuilder`.
2. **Zero dependencies.** Foundation and SwiftUI only.
3. **Grid logic is separable from rendering.** `EZCalendarItemViewModel` produces `[CalendarWeek]`; the views only lay it out. Keep date math out of `body`.
4. **Layout is caller-sized.** Views never impose a frame; callers size cells (typically `proxy.size.width / 7` under a `GeometryReader`).

---

## 2. Layout

```
Package.swift                     tools 6.0, single library target
README.md                         user-facing docs — keep in sync with public API
Sources/EZCalendar/
  Models/
    CalendarDay.swift             one grid cell (public struct, INTERNAL init)
    CalendarWeek.swift            7 days (public)
    CalendarMonth.swift           month+year+events — the input unit (public)
    CalendarEvent.swift           uuid + eventDate (public class)
  Extensions/
    Date+.swift                   INTERNAL date helpers — not public API
  Helper/
    EZCalendarHelper.swift        generateCalendarMonths(...)  (public)
  Widgets/
    CalendarItem/
      EZCalendarItemViewModel.swift    ★ all the date math lives here (internal)
      EZCalendarItemView.swift         one month as a LazyVGrid (public)
    WeekdayHeader/
      EZCalendarWeekdayHeaderView.swift  public type, INTERNAL init
    CalendarHorizontalPagging/         (sic — misspelled directory, leave it)
      EZCalendarHorizontalPagingView.swift  the pager (public)
Demo/                             sample app — see landmine #1
EZCalendar.xcodeproj              STALE and broken — see landmine #2
EZCalendar.xcworkspace            wraps Demo + EZCalendar projects
```

`EZCalendarItemViewModel.swift` is the file that matters. Everything else is
plumbing around it.

---

## 3. Public API surface

This package is inconsistent about access control. **Several `public` types have
internal members**, so "the type is public" does not mean callers can use it.
Verified by compiling against the package from an external module.

| Symbol | Callable from another module? |
| --- | --- |
| `CalendarMonth` + `init(month:year:events:)` + `hashString` | ✅ |
| `CalendarWeek` + `init(calendarDays:)` | ✅ |
| `CalendarEvent` + `init(uuid:eventDate:)` | ✅ |
| `CalendarDay` — properties `date`, `isCurrentMonth`, `hasEvents` | ✅ read only |
| `CalendarDay.init(...)` | ❌ internal — callers receive these, never build them |
| `EZCalendarHelper.generateCalendarMonths` | ✅ |
| `EZCalendarItemView` + `init` | ✅ |
| `EZCalendarItemView.gridLineColor(_:)` | ❌ **internal** — `error: 'gridLineColor' is inaccessible due to 'internal' protection level` |
| `EZCalendarWeekdayHeaderView` | ⚠️ type is public, **`init` is internal** — not constructible externally |
| `EZCalendarHorizontalPagingView` + `init` + `.gridLineColor` + `.weekdayScrollable` | ✅ |
| `Date` extension (`Date.from`, `.get(_:)`, `.startOfMonth`, `.toString`) | ❌ **internal** |

That last one explains a real confusion: the Demo app calls `Date.from(...)` and
`calendarDay.date?.get(.day)`, which looks like library API but is **the Demo's own
private copy** of the extension in `Demo/Demo/Extensions/Date+.swift`. Library
consumers get none of it. Never write README examples that rely on those helpers.

If a task is "expose X", the fix is an access-level change plus a **minor** version
bump — see the `release-ezcalendar` skill.

---

## 4. How the grid is built

`EZCalendarItemViewModel.generateCalendar()` — read this before changing date math.

1. From `CalendarMonth(month:year:)`, build the first date of the month via `Date.from(...)` using the **injected** calendar.
2. Get `numberOfDaysInMonth`, `firstDayOfWeekInMonth`, `lastDayOfWeekInMonth`. Every step is a `guard` that returns `[]` on failure — the grid degrades to empty rather than crashing.
3. Loop `while dayOfMonth <= numberOfDaysInMonth`, inner `for weekDay in 1...7`:
   - **First row** (`calendarWeeks.isEmpty`): columns before `firstDayOfWeekInMonth` are filled from the previous month; the rest are in-month days.
   - **Later rows**: in-month days until they run out, then trailing padding.
4. Each row is wrapped in a `CalendarWeek` — **always exactly 7 days**.

Result: 5 or 6 rows, occasionally 4 (a 28-day month starting on the grid's first column, e.g. February 2026).

Three day-builders exist:

| Method | Sets `hasEvents`? |
| --- | --- |
| `buildCalendarDayInCurrentMonth(_:)` | ✅ |
| `buildCalendarDayInPreviousMonth(startDateOfMonth:diffDayFromStart:)` | ❌ always `false` |
| `buildCalendarDayInNextMonth(endDateOfMonth:diffDayFromEnd:)` | ❌ always `false`, **and is dead code** |

`buildCalendarDayInNextMonth` is never called. The trailing-padding branch calls
`buildCalendarDayInPreviousMonth` with the *last* date of the month and a positive
offset, which happens to produce the correct dates. Confirmed: the grids are
right. But if you refactor here, be aware the method names lie about what runs.

---

## 5. Landmines

Each of these was verified against the working tree — none is speculation.

### 1. The Demo does not build this repo's sources

`Demo/Demo.xcodeproj` contains:

```
XCLocalSwiftPackageReference "../../EZCalendar-Swift"
```

That resolves to `/Users/wisanu/Workspaces/iOS/EZCalendar-Swift` — a **different
clone with a different remote** (`wisanu-dev/EZCalendar-Swift`), currently one
commit behind this repo and with differing file contents.

**Editing `Sources/EZCalendar/` here and building the Demo validates nothing.**
If the user asks you to verify a library change in the Demo, say so and either
repoint the reference or use `swift build` plus the grid harness.

### 2. `EZCalendar.xcodeproj` is stale and does not build

```
error: Build input file cannot be found:
  .../CalendarHorizontalPagging/EZCalendarHorizontalPagingViewModel.swift
```

That file was deleted in `9dfad87` ("Remove the view model") but is still listed in
the pbxproj. **The `EZCalendar` scheme has been broken since then — it is not your
change.** SwiftPM is the source of truth; use `swift build`.

### 3. `calendar.firstWeekday` is ignored

The grid is hardcoded Sunday-first. `generateCalendar()` compares the raw
`.weekday` component (1 = Sunday) against a 1...7 column index with no offset, and
`EZCalendarWeekdayHeaderView` uses `DateFormatter.shortWeekdaySymbols`, which is
also Sunday-indexed. Verified: setting `firstWeekday = 2` yields a byte-identical
grid.

The two halves are at least *consistent*, so fixing one without the other will
desynchronize the header from the dates.

### 4. Event matching is exact `Date` equality

```swift
calendarMonth.events.contains(where: { $0.eventDate == date })
```

`CalendarDay.date` is midnight in the calendar's time zone. An event with any
time component silently never matches. Any fix here should compare with
`calendar.isDate(_:inSameDayAs:)` — but that is a behavior change; ask first.

### 5. `CalendarMonth.hashString` is the pager's scroll identity

`hashString` is `"\(hashValue)"`, and the synthesized `Hashable` conformance
**includes `events`**. So injecting events into a month changes its `hashString`,
which changes the `.id()` the pager's `scrollPosition` is tracking. That is the
scroll-jump class of bug in this codebase. It is also process-seeded, so it is not
stable across launches — fine as a transient view id, never persist it.

### 6. Duplicate weekday titles collide as view ids

`EZCalendarWeekdayHeaderView` renders `ForEach(weekDayTitles, id: \.self)`. The
Demo passes `calendar.veryShortWeekdaySymbols`, which in English is
`["S","M","T","W","T","F","S"]` — duplicate SwiftUI identities.

### 7. `generateCalendarMonths(events:)` silently drops its argument

The parameter exists but is never written into the returned `CalendarMonth`s.
Verified: passing an event returns months with `events == []`.

### 8. `Date.startOfMonth` / `.endOfMonth` hardcode Gregorian

```swift
let calendar = Calendar(identifier: .gregorian)
```

...ignoring the injected calendar. Harmless for Gregorian and Buddhist (identical
month boundaries), wrong for Hijri or Hebrew. `generateCalendarMonths` normalizes
through `startOfMonth`, so it inherits this.

### 9. `addingComponentsOfDate` uses `Calendar.current`

Not the injected calendar. Padding-day arithmetic therefore runs on the system
calendar. Day-offset math makes this benign today, but it is a latent bug.

### 10. `Date+.swift` exists twice

Once in `Sources/EZCalendar/Extensions/` (internal) and once in
`Demo/Demo/Extensions/` (the Demo's copy). They differ — the Demo's `toString`
takes a `locale` parameter; the library's hardcodes Gregorian. **Changing one does
not change the other.**

---

## 6. Verifying changes

**Always:**

```bash
swift build
```

**If you touched date math**, there is no test suite — use the
`verify-calendar-grid` skill, which sets up a throwaway test target in a scratch
copy and prints grids against a recorded baseline. Do not commit a test target
unless the user asks for one.

**If you touched the Demo or need an iOS build:**

```bash
xcodebuild -workspace EZCalendar.xcworkspace -scheme Demo \
  -destination 'generic/platform=iOS Simulator' build
```

(Remember landmine #1 — this does not exercise this repo's library sources.)

---

## 7. Conventions

- **Doc comments are `/** ... */` blocks containing full Markdown**, with headings, emoji, tables, and usage examples — essentially README sections embedded in source. Unusual, but it is the house style; match it when adding public API. Several of these blocks describe *aspirational* signatures that drifted from the code — trust the code, and fix the comment while you're there.
- **File headers** carry `// Created by <name> on <date>` in Buddhist-era dates (`25/12/2567 BE`). Leave existing ones alone.
- **Naming:** public types are prefixed `EZCalendar`; models are not (`CalendarDay`, `CalendarMonth`).
- **`CalendarHorizontalPagging`** — the directory is misspelled, as is the Demo's `CalendarHorizontalPaggingViewModel`. Renaming is churn; leave it unless asked.
- **Failure mode is silent degradation.** Date math uses `guard ... else { return [] }` or returns an empty `CalendarDay()`. No `fatalError`, no throwing. Preserve this.
- **Don't add dependencies.**
- **Don't commit or push** unless asked. `main` is the default branch; branch before committing if asked to commit while on it.

---

## 8. Agent skills

Project skills live in `.agents/skills/`. `.claude/skills` is a symlink to that
directory, and `CLAUDE.md` is a symlink to this file — one canonical copy, reachable
under either convention. Invoke skills with the `Skill` tool.

| Skill | Use it when |
| --- | --- |
| **`build-ezcalendar`** | Any source change. Which build commands work, which are known-broken, and the pre-report checklist. |
| **`verify-calendar-grid`** | Changing `EZCalendarItemViewModel`, `Date+.swift`, `EZCalendarHelper`, or anything touching padding days, week counts, locales, or calendar systems. Sets up a throwaway test harness and carries a verified baseline. |
| **`release-ezcalendar`** | Tagging, version bumps, publishing for SwiftPM consumers. |

Useful built-ins here: `code-review` for diffs, `security-review` before release.

---

## 9. Quick triage

| Symptom | Look at |
| --- | --- |
| Grid starts on the wrong weekday | Landmine #3 — `firstWeekday` is ignored |
| Event dot doesn't appear | Landmine #4 (time component) or #2 in README (padding days) |
| Events vanish after `generateCalendarMonths` | Landmine #7 |
| Pager jumps / loses position on data update | Landmine #5 — `hashString` includes `events` |
| Demo doesn't reflect a library change | Landmine #1 — sibling checkout |
| `xcodebuild -scheme EZCalendar` fails | Landmine #2 — stale pbxproj, pre-existing |
| `Date.from` unavailable to a consumer | §3 — the extension is internal |
| Wrong year with a Buddhist calendar | `CalendarMonth.year` is in the calendar's era (2569 BE == 2026 CE) |
