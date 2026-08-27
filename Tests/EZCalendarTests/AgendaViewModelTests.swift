//
//  AgendaViewModelTests.swift
//  EZCalendar
//
//  Created by wisanu on 27/8/2569 BE.
//

import Foundation
import Testing
@testable import EZCalendar

/// State transitions of `EZCalendarAgendaViewModel`.
///
/// The view model is `@MainActor`, so the suite is too. Every fixture month here
/// sits in 2030, deliberately clear of the real "today" — otherwise the
/// today-wins selection rules would fire and make the assertions depend on the
/// day the tests happen to run.
@Suite("Agenda view model transitions")
@MainActor
struct AgendaViewModelTests {

    let calendar = Fixture.gregorian

    func makeViewModel(
        mode: EZCalendarAgendaMode = .monthly,
        selection: Date = Fixture.date(2030, 7, 10),
        months: [(month: Int, year: Int)] = [(6, 2030), (7, 2030), (8, 2030)]
    ) -> EZCalendarAgendaViewModel {
        let viewModel = EZCalendarAgendaViewModel(calendar: calendar, mode: mode, selection: selection)
        viewModel.rebuildPages(from: Fixture.months(months))
        viewModel.primePagers(for: selection)
        return viewModel
    }

    // MARK: - Construction

    @Test("A view model starts at its mode's resting progress")
    func startsAtRest() {
        #expect(makeViewModel(mode: .monthly).progress == 0)
        #expect(makeViewModel(mode: .weekly).progress == 1)
    }

    @Test("The selection is normalised to the start of its day on the way in")
    func selectionIsNormalisedAtInit() {
        let viewModel = makeViewModel(selection: Fixture.dateTime(2030, 7, 10, 16, 45))

        #expect(viewModel.selection == Fixture.date(2030, 7, 10))
    }

    @Test("Priming positions both pagers on the page holding the selection")
    func primingPositionsBothPagers() {
        let viewModel = makeViewModel()

        #expect(viewModel.visibleMonthID == EZCalendarAgendaLogic.monthID(month: 7, year: 2030))
        #expect(viewModel.visibleWeekPage?.days.contains { $0.date == Fixture.date(2030, 7, 10) } == true)
    }

    // MARK: - Tapping a day

    @Test("Tapping a day in .monthly selects it and snaps to .weekly")
    func tapAutoSnapsToWeekly() {
        let viewModel = makeViewModel(mode: .monthly)

        viewModel.selectDay(Fixture.dateTime(2030, 7, 22, 9, 30))

        #expect(viewModel.selection == Fixture.date(2030, 7, 22))
        #expect(viewModel.mode == .weekly)
    }

    @Test("Tapping a day in .weekly selects it and leaves the mode alone")
    func tapInWeeklyKeepsTheMode() {
        let viewModel = makeViewModel(mode: .weekly)

        viewModel.selectDay(Fixture.date(2030, 7, 22))

        #expect(viewModel.selection == Fixture.date(2030, 7, 22))
        #expect(viewModel.mode == .weekly)
    }

    @Test("Selecting a day pages the calendar to the month that owns it")
    func selectionPagesTheCalendar() {
        let viewModel = makeViewModel(mode: .monthly)

        viewModel.selection = Fixture.date(2030, 8, 14)
        viewModel.selectionChanged()

        #expect(viewModel.visibleMonthID == EZCalendarAgendaLogic.monthID(month: 8, year: 2030))
    }

    @Test("Selecting a day asks the list to scroll to that day's section")
    func selectionRequestsAListScroll() {
        let viewModel = makeViewModel()
        let target = Fixture.date(2030, 8, 14)

        // The list only accepts a target it actually has a section for.
        viewModel.sectionDates = [EZCalendarAgendaLogic.dayID(for: target, calendar: calendar): target]

        viewModel.selection = target
        viewModel.selectionChanged()

        #expect(viewModel.scrollTarget == EZCalendarAgendaLogic.dayID(for: target, calendar: calendar))
    }

    // MARK: - Collapsing by scrolling the list

    @Test("Scrolling a .monthly list part way collapses part way, without changing mode")
    func partialScrollDoesNotChangeMode() {
        let viewModel = makeViewModel(mode: .monthly)

        viewModel.listOffsetChanged(40)

        #expect(viewModel.progress == 0.4)
        #expect(viewModel.mode == .monthly)
    }

    @Test("Scrolling a .monthly list past the threshold flips it to .weekly")
    func fullScrollCollapses() {
        let viewModel = makeViewModel(mode: .monthly)

        viewModel.listOffsetChanged(140)

        #expect(viewModel.progress == 1)
        #expect(viewModel.mode == .weekly)
    }

    @Test("Once collapsed, scrolling deeper into the list leaves the calendar alone")
    func scrollingWhileCollapsedIsInert() {
        let viewModel = makeViewModel(mode: .monthly)

        viewModel.listOffsetChanged(140)
        viewModel.listOffsetChanged(900)
        viewModel.listOffsetChanged(300)

        #expect(viewModel.mode == .weekly)
        #expect(viewModel.progress == 1)
    }

    @Test("Over-scrolling the top of a .weekly list expands the calendar again")
    func overscrollExpands() {
        let viewModel = makeViewModel(mode: .weekly)

        viewModel.listOffsetChanged(-40)
        #expect(abs(viewModel.progress - 0.6) < 0.000_001)
        #expect(viewModel.mode == .weekly)

        viewModel.listOffsetChanged(-120)
        #expect(viewModel.progress == 0)
        #expect(viewModel.mode == .monthly)
    }

    @Test("A custom threshold changes how far the list has to travel")
    func customThresholdIsHonoured() {
        let viewModel = makeViewModel(mode: .monthly)
        viewModel.collapseThreshold = 250

        viewModel.listOffsetChanged(140)

        #expect(viewModel.mode == .monthly)
        #expect(abs(viewModel.progress - 0.56) < 0.000_001)
    }

    // MARK: - Collapsing by dragging the handle

    @Test("A handle drag past the threshold snaps to the other mode")
    func handleDragSnaps() {
        let viewModel = makeViewModel(mode: .monthly)

        viewModel.handleDragChanged(translation: -60)
        #expect(abs(viewModel.progress - 0.6) < 0.000_001)
        #expect(viewModel.mode == .monthly)

        viewModel.handleDragEnded(translation: -130)
        #expect(viewModel.mode == .weekly)
    }

    @Test("A handle drag that stops short springs back")
    func handleDragSpringsBack() {
        let viewModel = makeViewModel(mode: .monthly)

        viewModel.handleDragChanged(translation: -70)
        viewModel.handleDragEnded(translation: -70)

        #expect(viewModel.mode == .monthly)
        #expect(viewModel.progress == 0)
    }

    @Test("While the handle is held, the list's own scrolling cannot fight it")
    func handleDragOutranksTheList() {
        let viewModel = makeViewModel(mode: .monthly)

        viewModel.handleDragChanged(translation: -50)
        viewModel.listOffsetChanged(900)

        #expect(abs(viewModel.progress - 0.5) < 0.000_001)
        #expect(viewModel.mode == .monthly)
    }

    // MARK: - Horizontal paging

    @Test("Swiping to a new month selects its 1st")
    func swipingMonthSelectsTheFirst() {
        let viewModel = makeViewModel(mode: .monthly)

        viewModel.pagerScrolled(to: EZCalendarAgendaLogic.monthID(month: 8, year: 2030))

        #expect(viewModel.selection == Fixture.date(2030, 8, 1))
    }

    @Test("Swiping to a new week selects its first day")
    func swipingWeekSelectsItsFirstDay() {
        let viewModel = makeViewModel(mode: .weekly)
        let pages = viewModel.weekPages
        let target = pages[3]

        viewModel.pagerScrolled(to: target.id)

        #expect(viewModel.selection == target.firstDate)
    }

    @Test("A page id from the mode that is not on screen is ignored")
    func mismatchedPageIDIsIgnored() {
        let viewModel = makeViewModel(mode: .monthly)
        let before = viewModel.selection

        // A week id arriving while the month pager is on screen.
        viewModel.pagerScrolled(to: viewModel.weekPages[0].id)

        #expect(viewModel.selection == before)
    }

    @Test("Paging forward and back returns to the same month")
    func pagingIsReversible() {
        let viewModel = makeViewModel(mode: .monthly, selection: Fixture.date(2030, 7, 10))

        viewModel.page(by: 1)
        #expect(viewModel.selection == Fixture.date(2030, 8, 1))

        viewModel.page(by: -1)
        #expect(viewModel.selection == Fixture.date(2030, 7, 1))
    }

    @Test("Paging past the end of the supplied range changes nothing")
    func pagingPastTheEndIsInert() {
        let viewModel = makeViewModel(mode: .monthly, selection: Fixture.date(2030, 8, 5), months: [(8, 2030)])

        viewModel.page(by: 1)

        #expect(viewModel.selection == Fixture.date(2030, 8, 5))
    }

    // MARK: - List → calendar

    @Test("The list's pinned header moves the calendar's selection")
    func pinnedHeaderDrivesTheSelection() {
        let viewModel = makeViewModel()
        let pinned = Fixture.date(2030, 7, 24)
        let below = Fixture.date(2030, 7, 25)

        viewModel.sectionDates = [
            EZCalendarAgendaLogic.dayID(for: pinned, calendar: calendar): pinned,
            EZCalendarAgendaLogic.dayID(for: below, calendar: calendar): below
        ]

        viewModel.headerOffsetsChanged([
            AgendaHeaderOffset(id: EZCalendarAgendaLogic.dayID(for: pinned, calendar: calendar), minY: -3),
            AgendaHeaderOffset(id: EZCalendarAgendaLogic.dayID(for: below, calendar: calendar), minY: 210)
        ])

        #expect(viewModel.selection == pinned)
    }

    @Test("A header for a day the list does not know about is ignored")
    func unknownHeaderIsIgnored() {
        let viewModel = makeViewModel()
        let before = viewModel.selection

        viewModel.headerOffsetsChanged([AgendaHeaderOffset(id: "day-9999-1-1", minY: 0)])

        #expect(viewModel.selection == before)
    }

    @Test("A header reporting the day already selected does not re-select it")
    func redundantHeaderIsANoOp() {
        let viewModel = makeViewModel(selection: Fixture.date(2030, 7, 10))
        let id = EZCalendarAgendaLogic.dayID(for: Fixture.date(2030, 7, 10), calendar: calendar)
        viewModel.sectionDates = [id: Fixture.date(2030, 7, 10)]

        viewModel.headerOffsetsChanged([AgendaHeaderOffset(id: id, minY: 0)])

        #expect(viewModel.selection == Fixture.date(2030, 7, 10))
        // Nothing to scroll to: the list is already where it needs to be.
        #expect(viewModel.scrollTarget == nil)
    }

    @Test("Scrolling the list into another month pages the calendar with it")
    func listScrollPagesTheCalendar() {
        let viewModel = makeViewModel(mode: .monthly, selection: Fixture.date(2030, 7, 10))
        let target = Fixture.date(2030, 8, 20)
        let id = EZCalendarAgendaLogic.dayID(for: target, calendar: calendar)
        viewModel.sectionDates = [id: target]

        viewModel.headerOffsetsChanged([AgendaHeaderOffset(id: id, minY: 0)])
        viewModel.selectionChanged()

        #expect(viewModel.selection == target)
        #expect(viewModel.visibleMonthID == EZCalendarAgendaLogic.monthID(month: 8, year: 2030))
    }

    // MARK: - Mode changes from the caller

    @Test("Assigning the mode settles the calendar at that mode's progress")
    func externalModeChangeSettlesProgress() {
        let viewModel = makeViewModel(mode: .monthly)

        viewModel.mode = .weekly
        viewModel.modeChanged()
        #expect(viewModel.progress == 1)

        viewModel.mode = .monthly
        viewModel.modeChanged()
        #expect(viewModel.progress == 0)
    }

    @Test("Switching to .weekly lands on the week holding the selection")
    func modeChangePositionsTheWeekPager() {
        let viewModel = makeViewModel(mode: .monthly, selection: Fixture.date(2030, 7, 24))

        viewModel.mode = .weekly
        viewModel.modeChanged()

        let page = viewModel.weekPages.first { $0.id == viewModel.visibleWeekID }
        #expect(page?.days.contains { $0.date == Fixture.date(2030, 7, 24) } == true)
    }

    // MARK: - Measured geometry

    @Test("The calendar has no height until the grid has been measured")
    func heightIsNilBeforeMeasurement() {
        let viewModel = makeViewModel()

        #expect(viewModel.calendarHeight(for: viewModel.visibleMonthPage) == nil)
    }

    @Test("A measured grid collapses to exactly one of its own rows")
    func measuredGridCollapsesToOneRow() {
        let viewModel = makeViewModel(mode: .monthly, selection: Fixture.date(2030, 7, 24))
        guard let page = viewModel.visibleMonthPage else {
            Issue.record("no visible page")
            return
        }

        // Pretend the rendered grid reported itself: rows of 50pt, 1pt apart.
        let rows = Double(page.weeks.count)
        viewModel.gridHeights[page.id] = rows * 50 + (rows - 1)

        viewModel.progress = 0
        #expect(viewModel.calendarHeight(for: page) == rows * 50 + (rows - 1))

        viewModel.progress = 1
        #expect(viewModel.calendarHeight(for: page) == 50)
    }

    @Test("The grid slides the selected week to the top as it collapses")
    func measuredGridSlidesToTheSelectedWeek() {
        let viewModel = makeViewModel(mode: .monthly, selection: Fixture.date(2030, 7, 24))
        guard let page = viewModel.visibleMonthPage else {
            Issue.record("no visible page")
            return
        }

        let rows = Double(page.weeks.count)
        viewModel.gridHeights[page.id] = rows * 50 + (rows - 1)

        let selectedRow = EZCalendarAgendaLogic.rowIndex(
            containing: Fixture.date(2030, 7, 24),
            in: page.weeks,
            calendar: calendar
        )

        viewModel.progress = 1
        #expect(viewModel.gridOffset(for: page) == -Double(selectedRow) * 51)

        viewModel.progress = 0
        #expect(viewModel.gridOffset(for: page) == 0)
    }

    @Test("A page that does not own the selection collapses onto its own first row")
    func neighbouringPageCollapsesToItsFirstRow() {
        let viewModel = makeViewModel(mode: .monthly, selection: Fixture.date(2030, 7, 24))
        guard let neighbour = viewModel.monthPages.first(where: { $0.calendarMonth.month == 8 }) else {
            Issue.record("no neighbouring page")
            return
        }

        let rows = Double(neighbour.weeks.count)
        viewModel.gridHeights[neighbour.id] = rows * 50 + (rows - 1)
        viewModel.progress = 1

        // Mid-swipe, August must not borrow July's row index.
        #expect(viewModel.gridOffset(for: neighbour) == 0)
        #expect(viewModel.rowOpacity(rowIndex: 0, in: neighbour) == 1)
        #expect(viewModel.rowOpacity(rowIndex: 1, in: neighbour) == 0)
    }
}
