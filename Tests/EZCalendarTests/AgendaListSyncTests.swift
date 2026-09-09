//
//  AgendaListSyncTests.swift
//  EZCalendar
//
//  Created by wisanu on 27/8/2569 BE.
//

import Foundation
import Testing
@testable import EZCalendar

@Suite("Agenda list and two-way sync")
struct AgendaListSyncTests {

    let calendar = Fixture.gregorian

    // MARK: - Sections

    @Test("Every day in range gets a section, so any tapped day has a scroll target")
    func sectionsCoverEveryDayInRange() {
        let index = EZCalendarAgendaLogic.eventIndex(
            events: [TestEvent](),
            eventDate: \.date,
            monthPages: Fixture.monthPages([(7, 2026)]),
            calendar: calendar
        )

        #expect(index.sections.count == 31)
        #expect(index.sections.first?.date == Fixture.date(2026, 7, 1))
        #expect(index.sections.last?.date == Fixture.date(2026, 7, 31))
        #expect(index.sections.allSatisfy { $0.isEmpty })
    }

    @Test("Sections run in ascending order with no gaps")
    func sectionsAreContiguous() {
        let index = EZCalendarAgendaLogic.eventIndex(
            events: [TestEvent](),
            eventDate: \.date,
            monthPages: Fixture.monthPages([(7, 2026), (8, 2026)]),
            calendar: calendar
        )

        #expect(index.sections.count == 62)

        for (previous, next) in zip(index.sections, index.sections.dropFirst()) {
            let gap = calendar.dateComponents([.day], from: previous.date, to: next.date).day
            #expect(gap == 1)
        }
    }

    @Test("An event stamped at a real time of day still lands on its own day")
    func eventsAreBucketedByDayNotByInstant() {
        let event = TestEvent(id: 1, date: Fixture.dateTime(2026, 7, 16, 9, 0))

        let index = EZCalendarAgendaLogic.eventIndex(
            events: [event],
            eventDate: \.date,
            monthPages: Fixture.monthPages([(7, 2026)]),
            calendar: calendar
        )

        let section = index.sections.first { $0.date == Fixture.date(2026, 7, 16) }

        #expect(section?.events == [event])
        #expect(index.sections.filter { !$0.isEmpty }.count == 1)
    }

    @Test("Several events on one day stay in the order they were supplied")
    func sameDayEventsKeepCallerOrder() {
        let events = [
            TestEvent(id: 1, date: Fixture.dateTime(2026, 7, 16, 9, 0)),
            TestEvent(id: 2, date: Fixture.dateTime(2026, 7, 16, 13, 0)),
            TestEvent(id: 3, date: Fixture.dateTime(2026, 7, 16, 17, 0))
        ]

        let index = EZCalendarAgendaLogic.eventIndex(
            events: events,
            eventDate: \.date,
            monthPages: Fixture.monthPages([(7, 2026)]),
            calendar: calendar
        )

        let section = index.sections.first { $0.date == Fixture.date(2026, 7, 16) }

        #expect(section?.events.map(\.id) == [1, 2, 3])
    }

    @Test("An event outside the paged months extends the list rather than being dropped")
    func eventsOutsideTheRangeExtendIt() {
        let events = [
            TestEvent(id: 1, date: Fixture.date(2026, 6, 28)),
            TestEvent(id: 2, date: Fixture.date(2026, 8, 3))
        ]

        let index = EZCalendarAgendaLogic.eventIndex(
            events: events,
            eventDate: \.date,
            monthPages: Fixture.monthPages([(7, 2026)]),
            calendar: calendar
        )

        #expect(index.sections.first?.date == Fixture.date(2026, 6, 28))
        #expect(index.sections.last?.date == Fixture.date(2026, 8, 3))
        #expect(index.sections.contains { $0.events.map(\.id) == [1] })
        #expect(index.sections.contains { $0.events.map(\.id) == [2] })
    }

    @Test("A day-dot lookup covers padding days, which CalendarDay.hasEvents never does")
    func paddingDaysCarryTheirEventDot() {
        // 30 June is a greyed-out leading cell of July's grid.
        let event = TestEvent(id: 1, date: Fixture.dateTime(2026, 6, 30, 11, 0))

        let index = EZCalendarAgendaLogic.eventIndex(
            events: [event],
            eventDate: \.date,
            monthPages: Fixture.monthPages([(7, 2026)]),
            calendar: calendar
        )

        let paddingDayID = EZCalendarAgendaLogic.dayID(for: Fixture.date(2026, 6, 30), calendar: calendar)
        #expect(index.daysWithEvents.contains(paddingDayID))

        // For contrast: the grid's own flag is false for that same cell.
        let julyGrid = Fixture.monthPages([(7, 2026)])[0]
        let paddingCell = julyGrid.weeks[0].calendarDays.first { $0.date == Fixture.date(2026, 6, 30) }
        #expect(paddingCell?.hasEvents == false)
    }

    @Test("No months and no events produce no sections rather than failing")
    func emptyInputProducesNoSections() {
        let index = EZCalendarAgendaLogic.eventIndex(
            events: [TestEvent](),
            eventDate: \.date,
            monthPages: [],
            calendar: calendar
        )

        #expect(index.sections.isEmpty)
        #expect(index.daysWithEvents.isEmpty)
    }

    @Test("An absurd range is capped instead of looping the app to a halt")
    func rangeIsCapped() {
        let events = [
            TestEvent(id: 1, date: Fixture.date(1900, 1, 1)),
            TestEvent(id: 2, date: Fixture.date(2100, 1, 1))
        ]

        let index = EZCalendarAgendaLogic.eventIndex(
            events: events,
            eventDate: \.date,
            monthPages: Fixture.monthPages([(7, 2026)]),
            calendar: calendar
        )

        #expect(index.sections.count == EZCalendarAgendaLogic.maximumSectionCount)
    }

    // MARK: - List → calendar

    @Test("The pinned header is the one the calendar follows")
    func pinnedHeaderWins() {
        // Two headers above the top edge, one below: the pinned one is the
        // closest of the two, at -2.
        let offsets = [
            AgendaHeaderOffset(id: "day-a", minY: -240),
            AgendaHeaderOffset(id: "day-b", minY: -2),
            AgendaHeaderOffset(id: "day-c", minY: 180)
        ]

        #expect(EZCalendarAgendaLogic.topMostSectionID(headerOffsets: offsets) == "day-b")
    }

    @Test("A header resting exactly at the top edge counts as pinned")
    func headerAtTheEdgeCountsAsPinned() {
        let offsets = [
            AgendaHeaderOffset(id: "day-a", minY: 0),
            AgendaHeaderOffset(id: "day-b", minY: 200)
        ]

        #expect(EZCalendarAgendaLogic.topMostSectionID(headerOffsets: offsets) == "day-a")
    }

    @Test("While the list rubber-bands past its top, the first upcoming header wins")
    func overscrollFallsBackToTheFirstHeader() {
        // Nothing has reached the top edge yet — every header is still below it.
        let offsets = [
            AgendaHeaderOffset(id: "day-a", minY: 40),
            AgendaHeaderOffset(id: "day-b", minY: 260)
        ]

        #expect(EZCalendarAgendaLogic.topMostSectionID(headerOffsets: offsets) == "day-a")
    }

    @Test("A top inset shifts which header counts as pinned")
    func topInsetMovesThePinLine() {
        let offsets = [
            AgendaHeaderOffset(id: "day-a", minY: 10),
            AgendaHeaderOffset(id: "day-b", minY: 300)
        ]

        // Without an inset, nothing is pinned and the fallback picks day-a.
        #expect(EZCalendarAgendaLogic.topMostSectionID(headerOffsets: offsets) == "day-a")
        // With a 60pt inset, day-a is genuinely pinned under it.
        #expect(EZCalendarAgendaLogic.topMostSectionID(headerOffsets: offsets, topInset: 60) == "day-a")
    }

    @Test("An empty list reports no day at all")
    func noHeadersReportNothing() {
        #expect(EZCalendarAgendaLogic.topMostSectionID(headerOffsets: []) == nil)
    }

    // MARK: - Calendar → list

    @Test("The id a tapped day scrolls to is the id its section was built with")
    func tapTargetMatchesTheSectionID() {
        let index = EZCalendarAgendaLogic.eventIndex(
            events: [TestEvent](),
            eventDate: \.date,
            monthPages: Fixture.monthPages([(7, 2026)]),
            calendar: calendar
        )

        let tapped = Fixture.date(2026, 7, 16)
        let scrollTarget = EZCalendarAgendaLogic.dayID(for: tapped, calendar: calendar)
        let section = index.sections.first { $0.date == tapped }

        #expect(section?.id == scrollTarget)
    }

    @Test("A day id ignores the time of day, so a tap and a scroll agree")
    func dayIDIsIndependentOfTimeOfDay() {
        let midnight = EZCalendarAgendaLogic.dayID(for: Fixture.date(2026, 7, 16), calendar: calendar)
        let afternoon = EZCalendarAgendaLogic.dayID(for: Fixture.dateTime(2026, 7, 16, 14, 30), calendar: calendar)

        #expect(midnight == afternoon)
    }

    @Test("Day ids are written in the injected calendar's era")
    func dayIDsFollowTheCalendarEra() {
        let gregorianID = EZCalendarAgendaLogic.dayID(for: Fixture.date(2026, 7, 16), calendar: calendar)
        let buddhistID = EZCalendarAgendaLogic.dayID(for: Fixture.date(2026, 7, 16), calendar: Fixture.buddhist)

        #expect(gregorianID == "day-2026-7-16")
        #expect(buddhistID == "day-2569-7-16")
    }
}
