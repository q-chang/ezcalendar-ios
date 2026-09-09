//
//  EZCalendarAgendaModels.swift
//  EZCalendar
//
//  Created by wisanu on 27/8/2569 BE.
//

import Foundation

/**
 # 🔲 `EZCalendarDayContext` — what a day cell knows about itself

 `EZCalendarItemView` hands its `@ViewBuilder` a bare `CalendarDay`, which carries
 no notion of selection. The agenda view has a selected date, so its `dayItemViewContent`
 receives this richer context instead.

 | Property | Meaning |
 | --- | --- |
 | `day` | The underlying `CalendarDay` — `date`, `isCurrentMonth`, `hasEvents`. |
 | `isSelected` | Same calendar day as the view's `selectedDate` binding. |
 | `isToday` | Same calendar day as the real-world today. |
 | `hasEvents` | Recomputed by the agenda view — **see the note below**. |

 ## ⚠️ Prefer `context.hasEvents` over `context.day.hasEvents`

 `CalendarDay.hasEvents` is computed by `EZCalendarItemViewModel` with *exact*
 `Date` equality against `CalendarMonth.events`, and is hardcoded `false` for
 padding days borrowed from the adjacent month.

 The agenda view instead buckets its own `events` array with
 `Calendar.isDate(_:inSameDayAs:)`, so `context.hasEvents`:

 * matches an event stamped at any time of day, not just midnight, and
 * is correct on padding days — the greyed-out 30th of the previous month still
   shows its dot.

 ```swift
 dayItemViewContent: { context in
     VStack(spacing: 2) {
         Text(dayNumber(context.day))
             .foregroundStyle(context.isCurrentMonth ? .primary : .secondary)
         if context.hasEvents { Circle().frame(width: 4, height: 4) }
     }
     .background(context.isSelected ? Color.accentColor : .clear)
 }
 ```
 */
public struct EZCalendarDayContext: Hashable {

    /// The grid cell this context describes.
    public let day: CalendarDay

    /// `true` when this cell is the view's `selectedDate`, compared day-to-day.
    public let isSelected: Bool

    /// `true` when this cell is the real-world today, compared day-to-day.
    public let isToday: Bool

    /// `true` when the agenda's `events` array contains at least one event on
    /// this day. Correct for padding days; matches on the day, not the instant.
    public let hasEvents: Bool

    /// Convenience passthrough — `false` for days borrowed from an adjacent month.
    public var isCurrentMonth: Bool { day.isCurrentMonth }

    /// Convenience passthrough — `nil` only if the underlying date math failed.
    public var date: Date? { day.date }

    init(day: CalendarDay, isSelected: Bool, isToday: Bool, hasEvents: Bool) {
        self.day = day
        self.isSelected = isSelected
        self.isToday = isToday
        self.hasEvents = hasEvents
    }
}

/**
 # 📋 `EZCalendarAgendaSection` — one day of the agenda list

 The bottom list is a flat run of one section per calendar day, each with a
 sticky header. **Every day in range gets a section**, including days with no
 events — those render `emptyDayViewContent` instead of event rows.

 That is a deliberate trade. It makes the list longer, but it is what lets the
 two-way sync be exact: tapping any day on the calendar always has a section to
 scroll to, and scrolling the list always has a day to report back.

 The generic `Event` is *your* type. The library never inspects it; it only asks
 the `eventDate` closure which day to file it under.
 */
public struct EZCalendarAgendaSection<Event>: Identifiable {

    /// Stable, calendar-scoped day identity — the `id` used for `scrollTo`.
    public let id: String

    /// Start of this day, in the view's calendar.
    public let date: Date

    /// The caller's events for this day, in the order they were supplied.
    public let events: [Event]

    /// `true` when this day has no events and renders `emptyDayViewContent`.
    public var isEmpty: Bool { events.isEmpty }

    init(id: String, date: Date, events: [Event]) {
        self.id = id
        self.date = date
        self.events = events
    }
}

/**
 # ⬅️➡️ `EZCalendarAgendaTitleContext` — what the title bar is handed

 The `‹ July 2569 ›` bar above the weekday row is entirely caller-drawn. The
 agenda view supplies the data and the two paging actions; the caller supplies
 every pixel.

 ```swift
 titleViewContent: { context in
     HStack {
         Button(action: context.pageBackward) { Image(systemName: "chevron.left") }
         Spacer()
         Text(formatter.string(from: context.date))
         Spacer()
         Button(action: context.pageForward) { Image(systemName: "chevron.right") }
     }
 }
 ```

 `date` is the first day of the page currently on screen — the 1st of the month
 in `.monthly`, the first day of the week in `.weekly`. It is *not* the selected
 date, so a title formatted from it never flickers while the user taps around
 inside one page.
 */
public struct EZCalendarAgendaTitleContext {

    /// First day of the page currently on screen.
    public let date: Date

    /// The mode the calendar is resting in.
    public let mode: EZCalendarAgendaMode

    /// Page one month (or week) earlier, applying the usual selection rules.
    public let pageBackward: () -> Void

    /// Page one month (or week) later, applying the usual selection rules.
    public let pageForward: () -> Void

    init(
        date: Date,
        mode: EZCalendarAgendaMode,
        pageBackward: @escaping () -> Void,
        pageForward: @escaping () -> Void
    ) {
        self.date = date
        self.mode = mode
        self.pageBackward = pageBackward
        self.pageForward = pageForward
    }
}

/// One horizontally-paged month. `id` is derived from month + year only, never
/// from `CalendarMonth.hashString`, whose value changes whenever `events`
/// changes and would yank the pager's scroll position mid-flight.
struct AgendaMonthPage: Identifiable, Hashable {
    let id: String
    let calendarMonth: CalendarMonth
    let firstDate: Date
    let weeks: [CalendarWeek]
}

/// One horizontally-paged week — always exactly 7 days. `id` is derived from the
/// first day's date, so a week that appears in two months' grids is one page.
struct AgendaWeekPage: Identifiable, Hashable {
    let id: String
    let firstDate: Date
    let days: [CalendarDay]
}


/// One request for the agenda list to scroll somewhere.
///
/// `animated` is `false` only for the very first positioning, which can be
/// months from the top of the range — animating that would scroll visibly
/// through every section in between.
struct AgendaScrollRequest: Equatable {
    let id: String
    let animated: Bool
}
