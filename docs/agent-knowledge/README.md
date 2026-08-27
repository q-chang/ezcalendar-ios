# Agent knowledge base

Detailed reference for working in EZCalendar. [AGENTS.md](../../AGENTS.md) is the
lean entry point; this directory holds the depth behind it.

Every claim here was verified against the working tree — by compiling from an
external module, or by running the grid through a throwaway test target. Nothing
is inferred from the doc comments in source, several of which have drifted from
the code they describe.

| Document | Read it when |
| --- | --- |
| [architecture.md](architecture.md) | Orienting for the first time. What the library is, the four design commitments, and the file layout. |
| [public-api.md](public-api.md) | Adding, exposing, or documenting API. The `public`/internal split is inconsistent and surprising. |
| [grid-algorithm.md](grid-algorithm.md) | Changing anything in `EZCalendarItemViewModel` or date math. |
| [landmines.md](landmines.md) | **Before any nontrivial change.** Ten verified traps, with reproductions. |
| [building-and-verifying.md](building-and-verifying.md) | Building, running the Demo, or checking a date-math change. There is no test suite. |
| [conventions.md](conventions.md) | Writing code or doc comments that match the house style. |

## The short version

If you read nothing else:

1. **`swift build` is the only build that works.** `xcodebuild -scheme EZCalendar` has been broken since commit `9dfad87`.
2. **The Demo builds this repo's sources** — the old sibling-checkout trap is fixed. Two SwiftUI measurements inside it fail *silently* instead; see landmines #11 and #12.
3. **Tests cover the agenda only.** `swift test` runs `Tests/EZCalendarTests/`. Month-grid date-math changes still need the `verify-calendar-grid` harness.
4. **`public` does not mean callable.** Several public types have internal members.
