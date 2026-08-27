//
//  EZCalendarAgendaLogic.swift
//  EZCalendar
//
//  Created by wisanu on 27/8/2569 BE.
//

import Foundation

/// One section header's vertical position, as reported by the list.
///
/// `minY` is measured in the scroll *container's* coordinate space, so it is
/// negative once the header has travelled above the top edge.
struct AgendaHeaderOffset: Hashable {
    let id: String
    let minY: Double
}

/// Everything the agenda list needs, produced in a single pass over the events.
struct AgendaEventIndex<Event> {
    /// One section per calendar day in range, in ascending date order.
    let sections: [EZCalendarAgendaSection<Event>]
    /// `dayID`s that have at least one event — the day-dot lookup for the grid.
    let daysWithEvents: Set<String>
}

/**
 # 🧮 `EZCalendarAgendaLogic` — the agenda's date and geometry math

 Every non-trivial calculation `EZCalendarAgendaView` performs lives here as a
 **static, pure function**: no SwiftUI, no stored state, no `Calendar.current`.

 That is the same split `EZCalendarItemViewModel` makes for the month grid, and
 for the same reason — it is the only part of a SwiftUI view that can be unit
 tested. `Tests/EZCalendarTests/` exercises this type directly.

 ## What lives here

 | Group | Functions |
 | --- | --- |
 | Identity | `dayID`, `monthID`, `weekID` — stable `ForEach` / `scrollTo` keys |
 | Pages | `monthPages`, `weekPages` — the horizontal page sets |
 | Selection rules | `selection(forMonthPage:)`, `selection(forWeekPage:)` |
 | Two-way sync | `topMostSectionID`, `index(of:)`, `eventIndex` |
 | Collapse geometry | `progress(...)`, `resolvedMode`, `gridHeight`, `gridOffset`, `rowOpacity` |

 ## ⚠️ Two deliberate deviations from `Date+.swift`

 The internal `Date` extension in this package has two known traps
 (`landmines.md` #8 and #9): `startOfMonth` hardcodes Gregorian, and
 `addingComponentsOfDate` does its arithmetic on `Calendar.current` rather than
 the injected calendar. Nothing in this file uses either. All arithmetic goes
 through the injected `calendar` via `date(byAdding:to:)`, so a Buddhist or
 Hijri calendar behaves the same as a Gregorian one.
 */
enum EZCalendarAgendaLogic {

    /// Hard ceiling on the day-by-day loop in `eventIndex`, ~54 years. A corrupt
    /// calendar cannot spin the app; it degrades to a short list, per the
    /// package's "silent degradation, never crashes" rule.
    static let maximumSectionCount = 20_000

    // MARK: - Identity
    //
    // Every id is derived from calendar components, never from `hashValue`.
    // `CalendarMonth.hashString` is `"\(hashValue)"`, which (a) folds in `events`
    // and so changes the moment a month is populated, and (b) is seeded per
    // process. Using it as scroll identity is what makes the existing pager jump
    // when data arrives mid-scroll (landmines.md #5). These ids are stable.

    /// Stable day key: `"day-2569-7-16"`, in the era of the injected calendar.
    static func dayID(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "day-\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    /// Stable month-page key: `"month-2569-7"`.
    static func monthID(month: Int, year: Int) -> String {
        "month-\(year)-\(month)"
    }

    /// Stable week-page key, derived from the week's first day.
    static func weekID(firstDate: Date, calendar: Calendar) -> String {
        "week-\(dayID(for: firstDate, calendar: calendar))"
    }

    // MARK: - Pages

    /// Builds the `.monthly` page set, reusing `EZCalendarItemViewModel` for the
    /// grid itself so the agenda and the existing pager can never disagree about
    /// what a month looks like.
    ///
    /// Months that fail date math, and duplicate months, are dropped rather than
    /// rendered — a duplicate id would collide as a `ForEach` identity.
    static func monthPages(from months: [CalendarMonth], calendar: Calendar) -> [AgendaMonthPage] {
        var seen = Set<String>()
        var pages: [AgendaMonthPage] = []

        for month in months {
            let id = monthID(month: month.month, year: month.year)
            guard seen.insert(id).inserted else { continue }

            guard let firstDate = Date.from(
                year: month.year,
                month: month.month,
                day: 1,
                calendar: calendar
            ) else { continue }

            let weeks = EZCalendarItemViewModel(calendarMonth: month, calendar: calendar).calendarWeeks
            guard !weeks.isEmpty else { continue }

            pages.append(
                AgendaMonthPage(id: id, calendarMonth: month, firstDate: firstDate, weeks: weeks)
            )
        }

        return pages
    }

    /// Flattens the month grids into the `.weekly` page set.
    ///
    /// Consecutive months share their boundary week — the week holding both the
    /// 31st and the 1st is generated twice, once by each month, with different
    /// `isCurrentMonth` flags. Keying on the week's first day de-duplicates it;
    /// the earlier month's copy wins, so paging across a month boundary advances
    /// by exactly one week with no repeated page.
    static func weekPages(from monthPages: [AgendaMonthPage], calendar: Calendar) -> [AgendaWeekPage] {
        var seen = Set<String>()
        var pages: [AgendaWeekPage] = []

        for page in monthPages {
            for week in page.weeks {
                guard let firstDate = week.calendarDays.first?.date else { continue }
                let id = weekID(firstDate: firstDate, calendar: calendar)
                guard seen.insert(id).inserted else { continue }

                pages.append(
                    AgendaWeekPage(id: id, firstDate: firstDate, days: week.calendarDays)
                )
            }
        }

        return pages
    }

    // MARK: - Selection rules on a page change

    /// Which day to select when a month scrolls into view: **today if this is
    /// today's month, otherwise the 1st**.
    ///
    /// "Today's month" is a month/year component match, not a grid match — today
    /// showing up as a greyed-out padding cell does not count.
    static func selection(forMonthPage page: AgendaMonthPage, today: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: today)

        if components.year == page.calendarMonth.year, components.month == page.calendarMonth.month {
            return calendar.startOfDay(for: today)
        }

        return page.firstDate
    }

    /// Which day to select when a week scrolls into view: **today if this week
    /// contains it, otherwise the week's first day**.
    ///
    /// The first day is column 1 of the grid. The grid is Sunday-first regardless
    /// of `calendar.firstWeekday` (landmines.md #3), so this is Sunday — matching
    /// the weekday header, which is Sunday-indexed too.
    static func selection(forWeekPage page: AgendaWeekPage, today: Date, calendar: Calendar) -> Date {
        let containsToday = page.days.contains { day in
            guard let date = day.date else { return false }
            return calendar.isDate(date, inSameDayAs: today)
        }

        return containsToday ? calendar.startOfDay(for: today) : page.firstDate
    }

    // MARK: - Locating a date in a page set

    /// Index of the month page holding `date`, by month/year components.
    static func index(ofMonthContaining date: Date, in pages: [AgendaMonthPage], calendar: Calendar) -> Int? {
        let components = calendar.dateComponents([.year, .month], from: date)

        return pages.firstIndex {
            $0.calendarMonth.year == components.year && $0.calendarMonth.month == components.month
        }
    }

    /// Index of the week page holding `date`, by same-day comparison.
    ///
    /// A date in a month's padding cells resolves to the week that *displays* it,
    /// which is what the user sees — so paging and selection stay consistent
    /// across a month boundary.
    static func index(ofWeekContaining date: Date, in pages: [AgendaWeekPage], calendar: Calendar) -> Int? {
        pages.firstIndex { page in
            page.days.contains { day in
                guard let dayDate = day.date else { return false }
                return calendar.isDate(dayDate, inSameDayAs: date)
            }
        }
    }

    /// The selection produced by stepping `step` pages from the page holding
    /// `date`. Returns `nil` at the ends of the range — there is nowhere to page
    /// to, and the caller should leave the selection alone.
    static func steppedSelection(
        from date: Date,
        step: Int,
        monthPages: [AgendaMonthPage],
        weekPages: [AgendaWeekPage],
        mode: EZCalendarAgendaMode,
        today: Date,
        calendar: Calendar
    ) -> Date? {
        switch mode {
        case .monthly:
            guard let current = index(ofMonthContaining: date, in: monthPages, calendar: calendar) else { return nil }
            let target = current + step
            guard monthPages.indices.contains(target) else { return nil }
            return selection(forMonthPage: monthPages[target], today: today, calendar: calendar)

        case .weekly:
            guard let current = index(ofWeekContaining: date, in: weekPages, calendar: calendar) else { return nil }
            let target = current + step
            guard weekPages.indices.contains(target) else { return nil }
            return selection(forWeekPage: weekPages[target], today: today, calendar: calendar)
        }
    }

    // MARK: - The agenda list

    /// Buckets the caller's events into one section per calendar day.
    ///
    /// The range spans the calendar's own months **unioned with the event dates**,
    /// so an event outside the paged range still appears in the list rather than
    /// being silently dropped. Days with no events still get a section — that is
    /// what makes the calendar↔list sync exact in both directions.
    static func eventIndex<Event>(
        events: [Event],
        eventDate: (Event) -> Date,
        monthPages: [AgendaMonthPage],
        calendar: Calendar
    ) -> AgendaEventIndex<Event> {

        // One pass: bucket by day id, and note the extremes for the range union.
        var buckets: [String: [Event]] = [:]
        var earliestEvent: Date?
        var latestEvent: Date?

        for event in events {
            let day = calendar.startOfDay(for: eventDate(event))
            buckets[dayID(for: day, calendar: calendar), default: []].append(event)

            if earliestEvent.map({ day < $0 }) ?? true { earliestEvent = day }
            if latestEvent.map({ day > $0 }) ?? true { latestEvent = day }
        }

        let daysWithEvents = Set(buckets.keys)

        guard var cursor = rangeStart(monthPages: monthPages, earliestEvent: earliestEvent, calendar: calendar),
              let end = rangeEnd(monthPages: monthPages, latestEvent: latestEvent, calendar: calendar),
              cursor <= end
        else {
            return AgendaEventIndex(sections: [], daysWithEvents: daysWithEvents)
        }

        var sections: [EZCalendarAgendaSection<Event>] = []
        sections.reserveCapacity(min(maximumSectionCount, 512))

        while cursor <= end, sections.count < maximumSectionCount {
            let id = dayID(for: cursor, calendar: calendar)
            sections.append(
                EZCalendarAgendaSection(id: id, date: cursor, events: buckets[id] ?? [])
            )

            // Injected calendar, not `Calendar.current` — see the type's note.
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return AgendaEventIndex(sections: sections, daysWithEvents: daysWithEvents)
    }

    /// Earliest day the list covers: the 1st of the first paged month, pulled
    /// back further if an event predates it.
    private static func rangeStart(
        monthPages: [AgendaMonthPage],
        earliestEvent: Date?,
        calendar: Calendar
    ) -> Date? {
        let monthStart = monthPages.first.map { calendar.startOfDay(for: $0.firstDate) }

        switch (monthStart, earliestEvent) {
        case let (month?, event?): return min(month, event)
        case let (month?, nil): return month
        case let (nil, event?): return event
        case (nil, nil): return nil
        }
    }

    /// Latest day the list covers: the last day of the final paged month, pushed
    /// out further if an event postdates it.
    private static func rangeEnd(
        monthPages: [AgendaMonthPage],
        latestEvent: Date?,
        calendar: Calendar
    ) -> Date? {
        let monthEnd = monthPages.last.flatMap { page -> Date? in
            // Last day of the month == one month on, one day back.
            calendar.date(byAdding: DateComponents(month: 1, day: -1), to: page.firstDate)
        }.map { calendar.startOfDay(for: $0) }

        switch (monthEnd, latestEvent) {
        case let (month?, event?): return max(month, event)
        case let (month?, nil): return month
        case let (nil, event?): return event
        case (nil, nil): return nil
        }
    }

    // MARK: - List → Calendar sync

    /// The day whose sticky header is currently pinned at the top of the list.
    ///
    /// Each header reports its `minY` in the scroll container's space. A header
    /// that has travelled *above* the top edge has `minY <= topInset`; the last
    /// such header — the one closest to the edge — is the one the sticky
    /// treatment is showing, and therefore the day the calendar should select.
    ///
    /// While the list is rubber-banding past its very top no header qualifies,
    /// so the first upcoming header is reported instead.
    static func topMostSectionID(headerOffsets: [AgendaHeaderOffset], topInset: Double = 0) -> String? {
        guard !headerOffsets.isEmpty else { return nil }

        // 0.5pt of slack: a header parked exactly at the edge should count as
        // pinned, and float arithmetic will not land on the boundary exactly.
        let threshold = topInset + 0.5

        let pinned = headerOffsets
            .filter { $0.minY <= threshold }
            .max { $0.minY < $1.minY }

        return pinned?.id ?? headerOffsets.min { $0.minY < $1.minY }?.id
    }

    // MARK: - Collapse geometry
    //
    // `progress` is the single number every transition animation reads:
    //   0 = fully expanded (.monthly), 1 = fully collapsed (.weekly).
    // Both drag sources normalise into it, so the view has one code path for an
    // interactive drag, an inertial scroll, and a programmatic mode change.

    static func clamp(_ value: Double, lower: Double = 0, upper: Double = 1) -> Double {
        min(max(value, lower), upper)
    }

    /// Collapse progress driven by the agenda list's own scroll offset.
    ///
    /// `offset` is how far the list content has travelled up past its top:
    /// positive once scrolled into content, negative while rubber-banding above
    /// the first section.
    ///
    /// * `.monthly` — scrolling the list up (offset climbing from 0) collapses
    ///   the calendar. One threshold's worth of scroll is a full collapse.
    /// * `.weekly` — the list is free to scroll normally; only an over-scroll
    ///   *past the top* (a negative offset, which the list can only produce when
    ///   it is already at the top) expands the calendar again.
    ///
    /// This is why the collapse never fights the list: the same finger movement
    /// that would scroll the list is what drives the collapse, and only when the
    /// list has nowhere left to scroll.
    static func progress(forListOffset offset: Double, mode: EZCalendarAgendaMode, threshold: Double) -> Double {
        guard threshold > 0 else { return mode.progress }

        switch mode {
        case .monthly:
            return clamp(offset / threshold)
        case .weekly:
            return offset >= 0 ? 1 : 1 - clamp(-offset / threshold)
        }
    }

    /// Collapse progress driven by an explicit drag on the grab handle.
    ///
    /// `translation` is `DragGesture.Value.translation.height`: negative upward.
    /// Dragging up out of `.monthly` collapses; dragging down out of `.weekly`
    /// expands. Dragging the "wrong" way clamps and does nothing.
    static func progress(forHandleTranslation translation: Double, mode: EZCalendarAgendaMode, threshold: Double) -> Double {
        guard threshold > 0 else { return mode.progress }

        switch mode {
        case .monthly:
            return clamp(-translation / threshold)
        case .weekly:
            return 1 - clamp(translation / threshold)
        }
    }

    /// Where a released drag settles.
    ///
    /// Because both `progress` functions normalise by the threshold, "the drag
    /// exceeded the threshold" is exactly "progress reached the far end". Any
    /// shorter drag springs back to the mode it started in.
    static func resolvedMode(progress: Double, from mode: EZCalendarAgendaMode) -> EZCalendarAgendaMode {
        switch mode {
        case .monthly: return progress >= 1 ? .weekly : .monthly
        case .weekly: return progress <= 0 ? .monthly : .weekly
        }
    }

    /// Height of the calendar grid at a given progress: it shrinks from the full
    /// month down to exactly one week row.
    ///
    /// Both inputs are **measured at runtime**, never constants — the library
    /// states no opinion about how tall a caller's day cell is.
    static func gridHeight(fullHeight: Double, rowHeight: Double, progress: Double) -> Double {
        guard fullHeight > 0, rowHeight > 0 else { return fullHeight }
        return fullHeight - (fullHeight - rowHeight) * clamp(progress)
    }

    /// How far the grid slides up inside its shrinking window.
    ///
    /// At `progress == 1` the selected week must sit at y = 0, so the grid has to
    /// travel up by exactly the space the rows above it occupy. Interpolating
    /// that distance by `progress` is what makes the selected week appear to hold
    /// still while the rows above it are consumed.
    ///
    /// `rowPitch` is row height *plus* the 1pt inter-row spacing — the distance
    /// from one row's top edge to the next — not the row height alone.
    static func gridOffset(selectedRowIndex: Int, rowPitch: Double, progress: Double) -> Double {
        -Double(max(0, selectedRowIndex)) * rowPitch * clamp(progress)
    }

    /// Back out the height of a single week row from the grid's measured natural
    /// height.
    ///
    /// The library never states how tall a day cell is — the caller's
    /// `@ViewBuilder` decides — so the collapse animation cannot use a constant
    /// here. It measures the rendered grid and divides, subtracting the `spacing`
    /// gaps that sit *between* rows (n rows have n-1 gaps).
    static func rowHeight(gridHeight: Double, rowCount: Int, spacing: Double) -> Double {
        guard rowCount > 0, gridHeight > 0 else { return 0 }
        return max(0, (gridHeight - spacing * Double(rowCount - 1)) / Double(rowCount))
    }

    /// Opacity of one week row mid-transition: the selected week stays solid,
    /// every other week fades out linearly as the grid closes over it.
    static func rowOpacity(rowIndex: Int, selectedRowIndex: Int, progress: Double) -> Double {
        rowIndex == selectedRowIndex ? 1 : 1 - clamp(progress)
    }

    /// Which week row of a month grid holds `date`.
    ///
    /// Falls back to row 0 rather than failing — an unresolvable selection
    /// collapses to the first week instead of producing an empty calendar.
    static func rowIndex(containing date: Date, in weeks: [CalendarWeek], calendar: Calendar) -> Int {
        let found = weeks.firstIndex { week in
            week.calendarDays.contains { day in
                guard let dayDate = day.date else { return false }
                return calendar.isDate(dayDate, inSameDayAs: date)
            }
        }

        return found ?? 0
    }
}
