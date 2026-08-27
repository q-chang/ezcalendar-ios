//
//  EZCalendarAgendaPaging.swift
//  EZCalendar
//
//  Created by wisanu on 27/8/2569 BE.
//

import Foundation

/**
 # ⏭️ `EZCalendarAgendaPaging` — page the agenda from anywhere

 `EZCalendarAgendaView` paces itself off its `selectedDate` binding, so paging it
 is just "select a day on the next page". This helper computes *which* day that
 is, applying the same rules the view applies to a swipe.

 Use it when the paging control lives somewhere the view's `titleViewContent`
 cannot reach — a navigation bar, a toolbar, a keyboard shortcut. Inside the
 title bar, prefer `context.pageForward()` / `context.pageBackward()`, which do
 exactly this with the arguments already filled in.

 ```swift
 Button("Next month") {
     if let next = EZCalendarAgendaPaging.selection(
         paging: .forward,
         from: selectedDate,
         mode: mode,
         calendarMonths: months,
         calendar: calendar
     ) {
         selectedDate = next            // the view pages itself to follow
     }
 }
 ```

 Returns `nil` at either end of `calendarMonths` — there is no page to move to,
 and the selection should stay where it is.
 */
public enum EZCalendarAgendaPaging {

    /// Which way to page.
    public enum Direction: Sendable {
        case backward
        case forward

        var step: Int {
            switch self {
            case .backward: return -1
            case .forward: return 1
            }
        }
    }

    /// The day to select one page away, applying the mode's selection rule:
    ///
    /// | Mode | Lands on | Selects |
    /// | --- | --- | --- |
    /// | `.monthly` | the next/previous month | today if it falls in that month, otherwise the 1st |
    /// | `.weekly` | the next/previous week | today if it falls in that week, otherwise the week's first day |
    ///
    /// - Parameter today: injectable for tests; defaults to now.
    /// - Returns: the new selection, or `nil` at the ends of `calendarMonths`.
    public static func selection(
        paging direction: Direction,
        from selectedDate: Date,
        mode: EZCalendarAgendaMode,
        calendarMonths: [CalendarMonth],
        calendar: Calendar,
        today: Date = Date()
    ) -> Date? {
        let monthPages = EZCalendarAgendaLogic.monthPages(from: calendarMonths, calendar: calendar)
        let weekPages = EZCalendarAgendaLogic.weekPages(from: monthPages, calendar: calendar)

        return EZCalendarAgendaLogic.steppedSelection(
            from: selectedDate,
            step: direction.step,
            monthPages: monthPages,
            weekPages: weekPages,
            mode: mode,
            today: today,
            calendar: calendar
        )
    }
}
