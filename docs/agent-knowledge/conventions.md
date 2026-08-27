# Conventions

House style. Match it; don't improve it uninvited.

## Doc comments

Public types carry `/** ... */` blocks containing **full Markdown** — headings,
emoji, tables, fenced usage examples. Effectively README sections embedded in
source. `EZCalendarItemViewModel.swift` is ~380 lines of which most is comment.

This is unusual, but it is the convention. Match it when adding public API.

⚠️ **Several blocks have drifted from the code.** `EZCalendarHelper`'s documents an
`events:` parameter that is silently dropped; `EZCalendarWeekdayHeaderView`'s ends
with a stray chat fragment ("Would you like me to help you write..."). One block
describes `EZCalendarMonthView`, a type that does not exist.

**Trust the code, not the comment.** Fix the comment when you touch the function.

## File headers

```swift
//
//  CalendarDay.swift
//  EZCalendar
//
//  Created by Wisanu Paunglumjeak on 25/12/2567 BE.
//
```

Dates are **Buddhist era** (2567 BE = 2024 CE). Leave existing headers alone;
match the format on new files. Some say `Created by wisanu`, some
`Wisanu Paunglumjeak` — both exist, neither is wrong. A few say `File.swift`
instead of the real filename.

## Naming

- **Public views** are prefixed `EZCalendar`: `EZCalendarItemView`, `EZCalendarHorizontalPagingView`, `EZCalendarWeekdayHeaderView`.
- **Models are not**: `CalendarDay`, `CalendarWeek`, `CalendarMonth`, `CalendarEvent`.
- **Helpers**: `EZCalendarHelper`.

### The misspellings are load-bearing

`Sources/EZCalendar/Widgets/CalendarHorizontalPagging/` — "Pagging". So is the
Demo's `CalendarHorizontalPaggingViewModel.swift`. The *types* inside are spelled
correctly (`EZCalendarHorizontalPagingView`).

Renaming is pure churn and breaks the Xcode project references. **Leave it unless
asked.**

## Error handling

**Silent degradation, always.** Date math uses:

```swift
guard let x = ... else { return [] }        // empty grid
guard let y = ... else { return CalendarDay() }  // empty day
```

No `fatalError`, no `throws`, no force-unwrap in the library. A month that cannot
be computed renders empty rather than crashing the host app.

Preserve this. It is a deliberate choice for a UI library — but it is also why
bugs here are silent, which is why the grid harness exists.

(The Demo *does* force-unwrap freely. Different rules; it's sample code.)

## Access control

Mark new API `public` deliberately, and **verify it from an external module** —
this package has a history of `public` types with internal members. See
[public-api.md](public-api.md).

## Swift version

`swift-tools-version: 6.0`, so the package builds in **Swift 6 language mode**
with strict concurrency. It currently compiles warning-free. Keep it that way.

Note the Demo's Xcode target is still `SWIFT_VERSION = 5.0`.

## Git

- **`main` is the default branch.** Branch before committing if asked to commit while on it.
- **Don't commit or push unless asked.**
- Tags are bare semver, no `v` prefix: `1.3.0`, `1.3.1`. See the `release-ezcalendar` skill.

## Dependencies

**Don't add any.** Foundation and SwiftUI only. This is a design commitment — see
[architecture.md](architecture.md#2-zero-dependencies).
