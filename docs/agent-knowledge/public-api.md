# Public API surface

This package is **inconsistent about access control**. Several `public` types have
internal members, so "the type is public" does not mean a consumer can use it.

Everything below was verified by compiling a scratch package against `EZCalendar`
as an external module — not by reading modifiers.

## What a consumer can actually reach

| Symbol | Reachable from another module? |
| --- | --- |
| `CalendarMonth` + `init(month:year:events:)` + `hashString` | ✅ |
| `CalendarWeek` + `init(calendarDays:)` | ✅ |
| `CalendarEvent` + `init(uuid:eventDate:)` | ✅ |
| `CalendarDay` — `date`, `isCurrentMonth`, `hasEvents` | ✅ read only |
| `CalendarDay.init(...)` | ❌ internal |
| `EZCalendarHelper.generateCalendarMonths` | ✅ |
| `EZCalendarItemView` + `init` | ✅ |
| `EZCalendarItemView.gridLineColor(_:)` | ❌ **internal** |
| `EZCalendarWeekdayHeaderView` | ⚠️ type public, **`init` internal** |
| `EZCalendarHorizontalPagingView` + `init` + `.gridLineColor` + `.weekdayScrollable` | ✅ |
| `EZCalendarAgendaView` + both `init`s + `.gridLineColor` + `.collapseThreshold` + `.collapseAnimation` + `.collapseOnDaySelection` | ✅ |
| `EZCalendarAgendaMode`, `EZCalendarAgendaPaging` | ✅ |
| `EZCalendarDayContext`, `EZCalendarAgendaSection`, `EZCalendarAgendaTitleContext` | ✅ read only — received, never constructed |
| `Date` extension (`.from`, `.get`, `.startOfMonth`, `.toString`) | ❌ **internal** |

## The three that bite

### `EZCalendarItemView.gridLineColor(_:)` is internal

[EZCalendarItemView.swift:130](../../Sources/EZCalendar/Widgets/CalendarItem/EZCalendarItemView.swift#L130)
declares `func gridLineColor` with no modifier. Compiling a caller against it:

```
error: 'gridLineColor' is inaccessible due to 'internal' protection level
```

The identically-named method on the pager
([EZCalendarHorizontalPagingView.swift](../../Sources/EZCalendar/Widgets/CalendarHorizontalPagging/EZCalendarHorizontalPagingView.swift))
*is* public. So the modifier works on the pager and fails on the grid — which
looks like a compiler bug to anyone who hasn't read the source.

### `EZCalendarWeekdayHeaderView` cannot be constructed

The struct is `public` but its `init` at
[EZCalendarWeekdayHeaderView.swift:92](../../Sources/EZCalendar/Widgets/WeekdayHeader/EZCalendarWeekdayHeaderView.swift#L92)
is not. Consumers can name the type and nothing else. It is reachable only
indirectly, through the pager's `weekdayItemViewContent` closure.

### The `Date` extension is not public API

[Date+.swift:10](../../Sources/EZCalendar/Extensions/Date+.swift#L10) is a bare
`extension Date` — internal. So `Date.from(year:month:day:)`, `.get(_:)`,
`.startOfMonth`, `.endOfMonth`, and `.toString(dateFormat:)` are **invisible to
consumers**.

This causes a specific, recurring confusion. The Demo app calls:

```swift
Date.from(year: 2024, month: 9, day: 1, calendar: calendar)
calendarDay.date?.get(.day)
```

That looks like library API. It is not — it is the Demo's **own private copy** of
the extension at `Demo/Demo/Extensions/Date+.swift`. The two copies differ (the
Demo's `toString` takes a `locale`; the library's hardcodes Gregorian).

**Never write a README example that relies on those helpers.** Use `Calendar` and
`DateComponents` directly:

```swift
// ✅ works for a consumer
let day = calendarDay.date.map { calendar.component(.day, from: $0) } ?? 0

// ❌ compiles only inside the package, or inside the Demo
let day = calendarDay.date?.get(.day) ?? 0
```

## Model reference

### `CalendarMonth`

```swift
public init(month: Int, year: Int, events: [CalendarEvent] = [])
public var hashString: String   // "\(hashValue)"
```

`month` and `year` are in the **era of the calendar passed to the view**, not
always CE. `hashString` is the pager's scroll identity and changes when `events`
changes — see [landmines.md](landmines.md#5-calendarmonthhashstring-is-the-pagers-scroll-identity).

### `CalendarDay`

Received, never constructed. `date` is midnight in the calendar's time zone;
`nil` only if date math failed. There is **no `dayNumber`** — an older README
claimed one.

`isCurrentMonth` is `false` for padding days. `hasEvents` is always `false` for
padding days regardless of the events you attach.

### `CalendarEvent`

A `class`, not a struct — reference semantics. Identity is `uuid` + `eventDate`.

### `CalendarWeek`

Always exactly 7 `CalendarDay`s. Carries a `uuid` regenerated on every `init`, so
two structurally identical weeks are never `==`.

## The agenda's surface

`EZCalendarAgendaView` was verified the same way — a scratch package importing
`EZCalendar` as an external module, compiling both initializers, all three
modifiers, `EZCalendarAgendaPaging`, and every `@ViewBuilder` slot, for macOS and
for `generic/platform=iOS Simulator`.

Three of its public types are **received, never constructed**, in the same spirit
as `CalendarDay`: their initializers are internal on purpose.

| Type | Where a consumer meets it |
| --- | --- |
| `EZCalendarDayContext` | the `dayItemViewContent` closure |
| `EZCalendarAgendaSection<Event>` | the `listHeaderViewContent` closure |
| `EZCalendarAgendaTitleContext` | the `titleViewContent` closure |

Note that `EZCalendarAgendaView` never needs the internal `Date` extension in a
caller's code: `EZCalendarDayContext.date` is a plain `Date?`, and the README
example reads the day number through `Calendar.component(_:from:)`.

## Changing access levels

If a task is "expose X", the change is a modifier plus a **minor** version bump —
new public API, not a patch. See the `release-ezcalendar` skill.

Widening `gridLineColor` on `EZCalendarItemView` is the most obviously correct of
these; it is public on the pager already, and the asymmetry reads as an oversight
rather than a decision.
