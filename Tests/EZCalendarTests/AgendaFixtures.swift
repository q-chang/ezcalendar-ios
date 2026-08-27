//
//  AgendaFixtures.swift
//  EZCalendar
//
//  Created by wisanu on 27/8/2569 BE.
//

import Foundation
@testable import EZCalendar

/// Shared setup for the agenda tests.
///
/// Every calendar here keeps `TimeZone.current`. That is deliberate: the padding
/// days in `EZCalendarItemViewModel` are computed through
/// `Date.addingComponentsOfDate`, which does its arithmetic on `Calendar.current`
/// (landmines.md #9). Pinning the fixtures to a *different* zone would make the
/// tests disagree with the code under test for reasons that have nothing to do
/// with the agenda.
enum Fixture {

    static var gregorian: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    static var buddhist: Calendar {
        var calendar = Calendar(identifier: .buddhist)
        calendar.locale = Locale(identifier: "th_TH")
        return calendar
    }

    /// Midnight on a given day, matching how `Date.from` builds dates.
    static func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar = Fixture.gregorian) -> Date {
        calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: 0, minute: 0, second: 0)
        ) ?? .distantPast
    }

    /// A specific time of day — used to prove the agenda buckets by *day*, not
    /// by instant.
    static func dateTime(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, calendar: Calendar = Fixture.gregorian) -> Date {
        calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        ) ?? .distantPast
    }

    /// `[(month, year)]` → `[CalendarMonth]`.
    static func months(_ pairs: [(month: Int, year: Int)]) -> [CalendarMonth] {
        pairs.map { CalendarMonth(month: $0.month, year: $0.year) }
    }

    static func monthPages(_ pairs: [(month: Int, year: Int)], calendar: Calendar = Fixture.gregorian) -> [AgendaMonthPage] {
        EZCalendarAgendaLogic.monthPages(from: months(pairs), calendar: calendar)
    }

    static func weekPages(_ pairs: [(month: Int, year: Int)], calendar: Calendar = Fixture.gregorian) -> [AgendaWeekPage] {
        EZCalendarAgendaLogic.weekPages(from: monthPages(pairs, calendar: calendar), calendar: calendar)
    }
}

/// A caller-owned event type. The library knows nothing about it beyond
/// `Identifiable` and whatever the `eventDate` closure reports.
struct TestEvent: Identifiable, Equatable {
    let id: Int
    let date: Date
}
