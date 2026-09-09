//
//  AgendaPageTests.swift
//  EZCalendar
//
//  Created by wisanu on 27/8/2569 BE.
//

import Foundation
import Testing
@testable import EZCalendar

@Suite("Agenda page sets")
struct AgendaPageTests {

    let calendar = Fixture.gregorian

    // MARK: - Month pages

    @Test("A month page carries the grid EZCalendarItemViewModel produced")
    func monthPageUsesTheSharedGrid() {
        let pages = Fixture.monthPages([(7, 2026)])

        #expect(pages.count == 1)

        // July 2026 starts on a Wednesday and has 31 days, so the Sunday-first
        // grid needs five rows and opens on the previous Sunday, 28 June.
        #expect(pages[0].weeks.count == 5)
        #expect(pages[0].weeks.allSatisfy { $0.calendarDays.count == 7 })
        #expect(pages[0].weeks[0].calendarDays[0].date == Fixture.date(2026, 6, 28))
        #expect(pages[0].firstDate == Fixture.date(2026, 7, 1))
    }

    @Test("A month page's id ignores events, so attaching data cannot move the pager")
    func monthPageIDIsStableAcrossEventChanges() {
        let bare = CalendarMonth(month: 7, year: 2026)
        let populated = CalendarMonth(
            month: 7,
            year: 2026,
            events: [CalendarEvent(eventDate: Fixture.date(2026, 7, 16))]
        )

        let bareID = EZCalendarAgendaLogic.monthPages(from: [bare], calendar: calendar)[0].id
        let populatedID = EZCalendarAgendaLogic.monthPages(from: [populated], calendar: calendar)[0].id

        #expect(bareID == populatedID)

        // The identity the existing pager uses does *not* survive this, which is
        // the scroll-jump bug this page id exists to avoid.
        #expect(bare.hashString != populated.hashString)
    }

    @Test("Duplicate months are dropped rather than colliding as ForEach ids")
    func duplicateMonthsAreDropped() {
        let pages = Fixture.monthPages([(7, 2026), (7, 2026), (8, 2026)])

        #expect(pages.count == 2)
        #expect(Set(pages.map(\.id)).count == 2)
    }

    @Test("Month/year are read in the injected calendar's era")
    func buddhistMonthsResolveToTheSameInstant() {
        let buddhist = Fixture.buddhist
        let pages = Fixture.monthPages([(7, 2569)], calendar: buddhist)

        #expect(pages.count == 1)
        // 2569 BE is 2026 CE — the same July, expressed in another era.
        #expect(pages[0].firstDate == Fixture.date(2026, 7, 1))
    }

    // MARK: - Week pages

    @Test("The week shared by two months becomes one page, not two")
    func boundaryWeekIsDeduplicated() {
        let july = Fixture.monthPages([(7, 2026)])[0]
        let august = Fixture.monthPages([(8, 2026)])[0]

        let pages = Fixture.weekPages([(7, 2026), (8, 2026)])

        // 26 July – 1 August appears in both grids; the flattened set holds it once.
        #expect(pages.count == july.weeks.count + august.weeks.count - 1)
        #expect(Set(pages.map(\.id)).count == pages.count)
    }

    @Test("Week pages run consecutively, seven days apart")
    func weekPagesAreConsecutive() {
        let pages = Fixture.weekPages([(7, 2026), (8, 2026)])

        for (previous, next) in zip(pages, pages.dropFirst()) {
            let gap = calendar.dateComponents([.day], from: previous.firstDate, to: next.firstDate).day
            #expect(gap == 7)
        }
    }

    @Test("Every week page holds exactly seven days and starts on the grid's first column")
    func weekPagesAreWellFormed() {
        let pages = Fixture.weekPages([(7, 2026)])

        #expect(!pages.isEmpty)
        #expect(pages.allSatisfy { $0.days.count == 7 })
        #expect(pages[0].firstDate == Fixture.date(2026, 6, 28))
    }

    @Test("An empty month list yields no pages rather than failing")
    func emptyInputDegradesQuietly() {
        #expect(Fixture.monthPages([]).isEmpty)
        #expect(Fixture.weekPages([]).isEmpty)
    }

    // MARK: - Locating a date

    @Test("A date resolves to the month page that owns it")
    func findsTheOwningMonthPage() {
        let pages = Fixture.monthPages([(6, 2026), (7, 2026), (8, 2026)])

        let index = EZCalendarAgendaLogic.index(
            ofMonthContaining: Fixture.date(2026, 7, 16),
            in: pages,
            calendar: calendar
        )

        #expect(index == 1)
    }

    @Test("A date outside the supplied range resolves to no page")
    func missingMonthReturnsNil() {
        let pages = Fixture.monthPages([(7, 2026)])

        let index = EZCalendarAgendaLogic.index(
            ofMonthContaining: Fixture.date(2027, 1, 1),
            in: pages,
            calendar: calendar
        )

        #expect(index == nil)
    }

    @Test("A padding day resolves to the week page that displays it")
    func paddingDayResolvesToItsVisibleWeek() {
        let pages = Fixture.weekPages([(7, 2026)])

        // 30 June is a greyed-out cell in July's first row.
        let index = EZCalendarAgendaLogic.index(
            ofWeekContaining: Fixture.date(2026, 6, 30),
            in: pages,
            calendar: calendar
        )

        #expect(index == 0)
    }
}
