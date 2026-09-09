//
//  AgendaSelectionTests.swift
//  EZCalendar
//
//  Created by wisanu on 27/8/2569 BE.
//

import Foundation
import Testing
@testable import EZCalendar

@Suite("Agenda selection rules")
struct AgendaSelectionTests {

    let calendar = Fixture.gregorian

    /// A fixed "today" so the today-wins rules are testable at all. Every test
    /// injects it rather than reading the clock.
    let today = Fixture.date(2026, 7, 16)

    // MARK: - Paging a month

    @Test("Landing on a month that is not today's selects the 1st")
    func monthWithoutTodaySelectsTheFirst() {
        let page = Fixture.monthPages([(9, 2026)])[0]

        let selection = EZCalendarAgendaLogic.selection(forMonthPage: page, today: today, calendar: calendar)

        #expect(selection == Fixture.date(2026, 9, 1))
    }

    @Test("Landing on today's month selects today, not the 1st")
    func monthWithTodaySelectsToday() {
        let page = Fixture.monthPages([(7, 2026)])[0]

        let selection = EZCalendarAgendaLogic.selection(forMonthPage: page, today: today, calendar: calendar)

        #expect(selection == Fixture.date(2026, 7, 16))
    }

    @Test("Today showing as a padding cell does not count as today's month")
    func todayInPaddingDoesNotHijackTheSelection() {
        // 16 July is not in August's grid at all, but 1 August's row does reach
        // back into July. Use a today that lands in that padding: 31 July.
        let page = Fixture.monthPages([(8, 2026)])[0]
        let julyThirtyFirst = Fixture.date(2026, 7, 31)

        let displaysToday = page.weeks[0].calendarDays.contains { $0.date == julyThirtyFirst }
        #expect(displaysToday)

        let selection = EZCalendarAgendaLogic.selection(
            forMonthPage: page,
            today: julyThirtyFirst,
            calendar: calendar
        )

        // The month is August, so August's 1st wins over a visible July cell.
        #expect(selection == Fixture.date(2026, 8, 1))
    }

    @Test("A time of day on today is normalised away")
    func todaySelectionIsStartOfDay() {
        let page = Fixture.monthPages([(7, 2026)])[0]

        let selection = EZCalendarAgendaLogic.selection(
            forMonthPage: page,
            today: Fixture.dateTime(2026, 7, 16, 14, 30),
            calendar: calendar
        )

        #expect(selection == Fixture.date(2026, 7, 16))
    }

    // MARK: - Paging a week

    @Test("Landing on a week without today selects its first day, a Sunday")
    func weekWithoutTodaySelectsItsFirstDay() {
        let pages = Fixture.weekPages([(7, 2026)])
        // The 5 – 11 July row.
        let page = pages[1]

        let selection = EZCalendarAgendaLogic.selection(
            forWeekPage: page,
            today: Fixture.date(2026, 9, 1),
            calendar: calendar
        )

        #expect(selection == Fixture.date(2026, 7, 5))
        #expect(calendar.component(.weekday, from: selection) == 1)
    }

    @Test("Landing on today's week selects today")
    func weekWithTodaySelectsToday() {
        let pages = Fixture.weekPages([(7, 2026)])
        // The 12 – 18 July row holds today.
        let page = pages[2]

        let selection = EZCalendarAgendaLogic.selection(forWeekPage: page, today: today, calendar: calendar)

        #expect(selection == today)
    }

    // MARK: - Stepping

    @Test("Stepping forward in .monthly moves one month and applies the rule")
    func steppingForwardByMonth() {
        let monthPages = Fixture.monthPages([(7, 2026), (8, 2026), (9, 2026)])
        let weekPages = EZCalendarAgendaLogic.weekPages(from: monthPages, calendar: calendar)

        let selection = EZCalendarAgendaLogic.steppedSelection(
            from: Fixture.date(2026, 7, 16),
            step: 1,
            monthPages: monthPages,
            weekPages: weekPages,
            mode: .monthly,
            today: today,
            calendar: calendar
        )

        #expect(selection == Fixture.date(2026, 8, 1))
    }

    @Test("Stepping backward into today's month selects today")
    func steppingBackwardOntoToday() {
        let monthPages = Fixture.monthPages([(7, 2026), (8, 2026)])
        let weekPages = EZCalendarAgendaLogic.weekPages(from: monthPages, calendar: calendar)

        let selection = EZCalendarAgendaLogic.steppedSelection(
            from: Fixture.date(2026, 8, 1),
            step: -1,
            monthPages: monthPages,
            weekPages: weekPages,
            mode: .monthly,
            today: today,
            calendar: calendar
        )

        #expect(selection == today)
    }

    @Test("Stepping forward in .weekly moves exactly seven days")
    func steppingForwardByWeek() {
        let monthPages = Fixture.monthPages([(7, 2026)])
        let weekPages = EZCalendarAgendaLogic.weekPages(from: monthPages, calendar: calendar)

        let selection = EZCalendarAgendaLogic.steppedSelection(
            from: Fixture.date(2026, 7, 8),
            step: 1,
            monthPages: monthPages,
            weekPages: weekPages,
            mode: .weekly,
            today: today,
            calendar: calendar
        )

        // 8 July sits in the 5 – 11 row; one page on is 12 – 18, which holds
        // today, so today wins over the row's Sunday.
        #expect(selection == today)
    }

    @Test("Stepping past the end of the range changes nothing")
    func steppingPastTheEndReturnsNil() {
        let monthPages = Fixture.monthPages([(7, 2026)])
        let weekPages = EZCalendarAgendaLogic.weekPages(from: monthPages, calendar: calendar)

        let forward = EZCalendarAgendaLogic.steppedSelection(
            from: Fixture.date(2026, 7, 16),
            step: 1,
            monthPages: monthPages,
            weekPages: weekPages,
            mode: .monthly,
            today: today,
            calendar: calendar
        )

        let backward = EZCalendarAgendaLogic.steppedSelection(
            from: Fixture.date(2026, 7, 16),
            step: -1,
            monthPages: monthPages,
            weekPages: weekPages,
            mode: .monthly,
            today: today,
            calendar: calendar
        )

        #expect(forward == nil)
        #expect(backward == nil)
    }

    // MARK: - The public wrapper

    @Test("EZCalendarAgendaPaging applies the same rules a swipe does")
    func publicPagingHelperMatchesTheSwipeRules() {
        let months = Fixture.months([(7, 2026), (8, 2026), (9, 2026)])

        let forward = EZCalendarAgendaPaging.selection(
            paging: .forward,
            from: Fixture.date(2026, 8, 1),
            mode: .monthly,
            calendarMonths: months,
            calendar: calendar,
            today: today
        )

        let backward = EZCalendarAgendaPaging.selection(
            paging: .backward,
            from: Fixture.date(2026, 8, 1),
            mode: .monthly,
            calendarMonths: months,
            calendar: calendar,
            today: today
        )

        #expect(forward == Fixture.date(2026, 9, 1))
        #expect(backward == today)
    }

    @Test("The row a date collapses onto is the row that displays it")
    func rowIndexFindsTheSelectedWeek() {
        let page = Fixture.monthPages([(7, 2026)])[0]

        #expect(EZCalendarAgendaLogic.rowIndex(containing: Fixture.date(2026, 7, 1), in: page.weeks, calendar: calendar) == 0)
        #expect(EZCalendarAgendaLogic.rowIndex(containing: Fixture.date(2026, 7, 16), in: page.weeks, calendar: calendar) == 2)
        #expect(EZCalendarAgendaLogic.rowIndex(containing: Fixture.date(2026, 7, 31), in: page.weeks, calendar: calendar) == 4)
    }

    @Test("A date the grid never shows collapses onto the first row rather than failing")
    func unknownDateFallsBackToTheFirstRow() {
        let page = Fixture.monthPages([(7, 2026)])[0]

        let index = EZCalendarAgendaLogic.rowIndex(
            containing: Fixture.date(2030, 1, 1),
            in: page.weeks,
            calendar: calendar
        )

        #expect(index == 0)
    }
}
