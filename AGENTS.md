# AGENTS.md

**EZCalendar** — a logic-first SwiftUI calendar library distributed via Swift
Package Manager. It computes month grids and hands the caller `CalendarDay`
values; every pixel comes from a caller-supplied `@ViewBuilder`.

| | |
| --- | --- |
| Product | one library target, `EZCalendar` |
| Platforms | iOS 17+, macOS 15+ |
| Toolchain | swift-tools-version 6.0, Swift 6 language mode |
| Dependencies | none |
| Tests | `swift test` — agenda logic only; the month grid is still untested |

---

## Read this first

Four things in this repo are not what they look like. Each has cost real
debugging time.

1. **`swift build` is the only build that works.** `xcodebuild -scheme EZCalendar` has been broken since commit `9dfad87` — a deleted file is still listed in the pbxproj. It is not your change.
2. **The Demo builds this repo — but two SwiftUI measurements in it lie.** The old sibling-checkout trap is fixed (the package reference now points at the repo root). What replaced it: off-screen `GeometryReader`s stop reporting, and `scrollTo` into a long `LazyVStack` lands short. Both fail silently. See landmines [#11](docs/agent-knowledge/landmines.md#11-geometry-probes-go-silent-off-screen) and [#12](docs/agent-knowledge/landmines.md#12-scrollto-into-a-long-lazyvstack-lands-approximately).
3. **Tests cover the agenda only.** `Tests/EZCalendarTests/` exercises `EZCalendarAgendaView`'s logic. `EZCalendarItemViewModel`'s month-grid math has no tests — changes there still need the `verify-calendar-grid` harness. Don't add a test target for anything else unless asked.
4. **`public` does not mean callable.** Several public types have internal members — `EZCalendarItemView.gridLineColor`, `EZCalendarWeekdayHeaderView.init`, and the whole `Date` extension. Verify from an external module before documenting API.

Full detail and reproductions: [docs/agent-knowledge/landmines.md](docs/agent-knowledge/landmines.md).

---

## Commands

```bash
swift build                             # after every source change
swift test                              # agenda logic suite
scripts/demo/run-demo.sh                # build + boot simulator + install + launch
scripts/demo/run-demo.sh --build-only   # iOS compile check only
```

Before reporting a change complete: `swift build` clean → `swift test` green →
grid harness if month-grid date math changed → external-module compile check if
public API changed.

---

## Knowledge base

Depth lives in [docs/agent-knowledge/](docs/agent-knowledge/). Read the one that
matches the task.

| Document | Read it when |
| --- | --- |
| [architecture.md](docs/agent-knowledge/architecture.md) | Orienting. What the library is, its four design commitments, file layout. |
| [public-api.md](docs/agent-knowledge/public-api.md) | Adding, exposing, or documenting API. |
| [grid-algorithm.md](docs/agent-knowledge/grid-algorithm.md) | Changing `EZCalendarItemViewModel` or any date math. |
| [landmines.md](docs/agent-knowledge/landmines.md) | **Before any nontrivial change.** Ten verified traps. |
| [building-and-verifying.md](docs/agent-knowledge/building-and-verifying.md) | Building, running the Demo, checking a change without a test suite. |
| [conventions.md](docs/agent-knowledge/conventions.md) | Writing code or doc comments in the house style. |

The file that matters is
[`Sources/EZCalendar/Widgets/CalendarItem/EZCalendarItemViewModel.swift`](Sources/EZCalendar/Widgets/CalendarItem/EZCalendarItemViewModel.swift).
Everything else is plumbing around it.

---

## Skills

Project skills live in `.agents/skills/`. `.claude/skills` symlinks to that
directory, and `CLAUDE.md` symlinks to this file — one canonical copy, reachable
under either convention.

| Skill | Use it when |
| --- | --- |
| **`build-ezcalendar`** | Any source change. Which build commands work, which are known-broken. |
| **`verify-calendar-grid`** | Touching date math, padding days, locales, or calendar systems. Throwaway harness with a recorded baseline. |
| **`release-ezcalendar`** | Tagging, version bumps, publishing for SwiftPM consumers. |
| **`write-changelog`** | Drafting or updating `CHANGELOG.md` from repository changes. |

Useful built-ins: `code-review` for diffs, `security-review` before release.

---

## Hard rules

- **No new dependencies.** Foundation and SwiftUI only.
- **No styling in the library.** No default colors, fonts, or frames — that is the caller's job.
- **Silent degradation, never crashes.** Date math `guard`s to an empty grid. No `fatalError`, no `throws`, no force-unwrap in `Sources/`.
- **Don't commit or push unless asked.** `main` is default; branch first if asked to commit while on it.
- **Trust the code, not the doc comments.** Several have drifted from what they describe.

---

## Quick triage

| Symptom | Cause |
| --- | --- |
| Grid starts on the wrong weekday | [`firstWeekday` is ignored](docs/agent-knowledge/landmines.md#3-calendarfirstweekday-is-ignored) |
| Event dot doesn't appear | [exact `Date` equality](docs/agent-knowledge/landmines.md#4-event-matching-is-exact-date-equality), or the day is padding |
| Events vanish after `generateCalendarMonths` | [the `events:` arg is dropped](docs/agent-knowledge/landmines.md#7-generatecalendarmonthsevents-silently-drops-its-argument) |
| Pager jumps on data update | [`hashString` includes `events`](docs/agent-knowledge/landmines.md#5-calendarmonthhashstring-is-the-pagers-scroll-identity) |
| A `GeometryReader` reports once then never again | [off-screen probes go silent](docs/agent-knowledge/landmines.md#11-geometry-probes-go-silent-off-screen) |
| Agenda selects the day *before* the one tapped | [`scrollTo` lands short](docs/agent-knowledge/landmines.md#12-scrollto-into-a-long-lazyvstack-lands-approximately) |
| `xcodebuild -scheme EZCalendar` fails | [stale pbxproj, pre-existing](docs/agent-knowledge/landmines.md#2-ezcalendarxcodeproj-is-stale-and-does-not-build) |
| `Date.from` unavailable to a consumer | [the extension is internal](docs/agent-knowledge/public-api.md#the-date-extension-is-not-public-api) |
| Wrong year with a Buddhist calendar | `CalendarMonth.year` is in the calendar's era — 2569 BE == 2026 CE |
