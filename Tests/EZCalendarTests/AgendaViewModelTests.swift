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

        #expect(viewModel.scrollRequest?.id == EZCalendarAgendaLogic.dayID(for: target, calendar: calendar))
        // The first positioning jumps; animating it would scroll through every
        // section between the top of the range and the selected day.
        #expect(viewModel.scrollRequest?.animated == false)
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
        #expect(viewModel.scrollRequest == nil)
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

@Suite("Agenda list-sync latch")
@MainActor
struct AgendaListLatchTests {

    let calendar = Fixture.gregorian

    /// A view model with a known set of day sections already registered.
    func makeViewModel(selection: Date = Fixture.date(2030, 7, 10)) -> EZCalendarAgendaViewModel {
        let viewModel = EZCalendarAgendaViewModel(calendar: calendar, mode: .monthly, selection: selection)
        viewModel.rebuildPages(from: Fixture.months([(7, 2030)]))
        viewModel.primePagers(for: selection)

        var dates: [String: Date] = [:]
        for day in 1...31 {
            let date = Fixture.date(2030, 7, day)
            dates[EZCalendarAgendaLogic.dayID(for: date, calendar: calendar)] = date
        }
        viewModel.sectionDates = dates

        return viewModel
    }

    func id(_ day: Int) -> String {
        EZCalendarAgendaLogic.dayID(for: Fixture.date(2030, 7, day), calendar: calendar)
    }

    @Test("Headers passed mid-scroll cannot rewrite the selection")
    func inFlightHeadersAreIgnored() {
        let viewModel = makeViewModel(selection: Fixture.date(2030, 7, 10))

        // Ask for a scroll to the 24th…
        viewModel.selection = Fixture.date(2030, 7, 24)
        viewModel.selectionChanged()
        #expect(viewModel.scrollRequest?.id == id(24))

        // …then feed it every day it would fly past on the way there. Without
        // the latch each of these would become the new selection, and each new
        // selection would start another scroll.
        for day in 11...23 {
            viewModel.headerOffsetsChanged([AgendaHeaderOffset(id: id(day), minY: 0)])
            #expect(viewModel.selection == Fixture.date(2030, 7, 24))
        }
    }

    @Test("The latch lifts the moment the list reaches its target")
    func latchReleasesOnArrival() {
        let viewModel = makeViewModel(selection: Fixture.date(2030, 7, 10))

        viewModel.selection = Fixture.date(2030, 7, 24)
        viewModel.selectionChanged()

        // Arrival.
        viewModel.headerOffsetsChanged([AgendaHeaderOffset(id: id(24), minY: 0)])
        #expect(viewModel.selection == Fixture.date(2030, 7, 24))

        // The user now scrolls on their own, and is obeyed immediately.
        viewModel.headerOffsetsChanged([AgendaHeaderOffset(id: id(26), minY: 0)])
        #expect(viewModel.selection == Fixture.date(2030, 7, 26))
    }

    @Test("A scroll the user starts is never mistaken for one we started")
    func userScrollIsHonouredWithoutARequest() {
        let viewModel = makeViewModel(selection: Fixture.date(2030, 7, 10))

        viewModel.headerOffsetsChanged([AgendaHeaderOffset(id: id(18), minY: 0)])

        #expect(viewModel.selection == Fixture.date(2030, 7, 18))
        // A list-driven change must not bounce the list back.
        #expect(viewModel.scrollRequest == nil)
    }

    @Test("Only the first positioning skips the animation")
    func onlyTheFirstScrollIsInstant() {
        let viewModel = makeViewModel(selection: Fixture.date(2030, 7, 10))

        viewModel.selection = Fixture.date(2030, 7, 12)
        viewModel.selectionChanged()
        #expect(viewModel.scrollRequest?.animated == false)

        viewModel.headerOffsetsChanged([AgendaHeaderOffset(id: id(12), minY: 0)])
        viewModel.scrollRequest = nil

        viewModel.selection = Fixture.date(2030, 7, 20)
        viewModel.selectionChanged()
        #expect(viewModel.scrollRequest?.animated == true)
    }
}

@Suite("Agenda scroll landing correction")
@MainActor
struct AgendaScrollCorrectionTests {

    let calendar = Fixture.gregorian

    func makeViewModel() -> EZCalendarAgendaViewModel {
        let selection = Fixture.date(2030, 7, 10)
        let viewModel = EZCalendarAgendaViewModel(calendar: calendar, mode: .monthly, selection: selection)
        viewModel.rebuildPages(from: Fixture.months([(7, 2030)]))
        viewModel.primePagers(for: selection)

        var dates: [String: Date] = [:]
        for day in 1...31 {
            let date = Fixture.date(2030, 7, day)
            dates[EZCalendarAgendaLogic.dayID(for: date, calendar: calendar)] = date
        }
        viewModel.sectionDates = dates
        return viewModel
    }

    func id(_ day: Int) -> String {
        EZCalendarAgendaLogic.dayID(for: Fixture.date(2030, 7, day), calendar: calendar)
    }

    /// Drives one scroll request and returns the view model mid-flight.
    func requestScroll(_ viewModel: EZCalendarAgendaViewModel, to day: Int) {
        viewModel.selection = Fixture.date(2030, 7, day)
        viewModel.selectionChanged()
        viewModel.scrollRequest = nil
    }

    @Test("A scroll that lands short is re-issued rather than accepted")
    func undershootIsCorrected() {
        let viewModel = makeViewModel()
        requestScroll(viewModel, to: 24)

        // The target came to rest 30pt below the top edge — one header height
        // short, which is exactly the case that used to select the wrong day.
        viewModel.headerOffsetsChanged([
            AgendaHeaderOffset(id: id(23), minY: -8),
            AgendaHeaderOffset(id: id(24), minY: 30)
        ])

        #expect(viewModel.scrollRequest?.id == id(24))
        // A correction is a jump, never an animation — the list is already there.
        #expect(viewModel.scrollRequest?.animated == false)
        // And the near-miss must not have been read back as a selection.
        #expect(viewModel.selection == Fixture.date(2030, 7, 24))
    }

    @Test("Landing within the slack counts as arrived and hands control back")
    func arrivalReleasesTheLatch() {
        let viewModel = makeViewModel()
        requestScroll(viewModel, to: 24)

        viewModel.headerOffsetsChanged([AgendaHeaderOffset(id: id(24), minY: 1)])
        #expect(viewModel.scrollRequest == nil)

        // Latch is open: the user's own scrolling is obeyed again.
        viewModel.headerOffsetsChanged([AgendaHeaderOffset(id: id(27), minY: 0)])
        #expect(viewModel.selection == Fixture.date(2030, 7, 27))
    }

    @Test("Corrections are capped, so an unreachable target cannot wedge the sync")
    func correctionsAreCapped() {
        let viewModel = makeViewModel()
        requestScroll(viewModel, to: 31)

        // The last day of the range can never reach the top — the list runs out
        // of content below it. Keep reporting a residual it can never close.
        for _ in 0..<6 {
            viewModel.headerOffsetsChanged([AgendaHeaderOffset(id: id(31), minY: 200)])
            viewModel.scrollRequest = nil
        }

        // The latch has given up, so the list is back in charge.
        viewModel.headerOffsetsChanged([AgendaHeaderOffset(id: id(29), minY: 0)])
        #expect(viewModel.selection == Fixture.date(2030, 7, 29))
    }

    @Test("A target that has not been built yet is waited for, not corrected")
    func unbuiltTargetIsWaitedFor() {
        let viewModel = makeViewModel()
        requestScroll(viewModel, to: 24)

        // Mid-flight the list reports only the rows it is passing.
        viewModel.headerOffsetsChanged([AgendaHeaderOffset(id: id(15), minY: 0)])

        #expect(viewModel.scrollRequest == nil)
        #expect(viewModel.selection == Fixture.date(2030, 7, 24))
    }
}

/// The collapse is driven by list travel accumulated from section-header
/// movement, because no absolute scroll probe survives (see AgendaPreferences).
@Suite("Agenda collapse travel")
@MainActor
struct AgendaCollapseTravelTests {

    let calendar = Fixture.gregorian

    func makeViewModel(mode: EZCalendarAgendaMode = .monthly) -> EZCalendarAgendaViewModel {
        let selection = Fixture.date(2030, 7, 10)
        let viewModel = EZCalendarAgendaViewModel(calendar: calendar, mode: mode, selection: selection)
        viewModel.rebuildPages(from: Fixture.months([(7, 2030)]))
        viewModel.primePagers(for: selection)

        var dates: [String: Date] = [:]
        for day in 1...31 {
            let date = Fixture.date(2030, 7, day)
            dates[EZCalendarAgendaLogic.dayID(for: date, calendar: calendar)] = date
        }
        viewModel.sectionDates = dates
        return viewModel
    }

    func id(_ day: Int) -> String {
        EZCalendarAgendaLogic.dayID(for: Fixture.date(2030, 7, day), calendar: calendar)
    }

    /// One frame of list geometry: the pinned header parked at 0, and the two
    /// free headers below it, all shifted up by `travelled` points.
    func frame(_ viewModel: EZCalendarAgendaViewModel, pinned: Int, next: Int, travelled: Double) {
        viewModel.trackListTravel([
            AgendaHeaderOffset(id: id(pinned), minY: 0),
            AgendaHeaderOffset(id: id(next), minY: 240 - travelled),
            AgendaHeaderOffset(id: id(next + 1), minY: 500 - travelled)
        ])
    }

    @Test("The first frame only seeds the measurement; it is not a drag")
    func firstFrameIsNotADrag() {
        let viewModel = makeViewModel()

        frame(viewModel, pinned: 10, next: 11, travelled: 0)

        #expect(viewModel.progress == 0)
        #expect(viewModel.mode == .monthly)
    }

    @Test("Dragging up accumulates travel and collapses the calendar")
    func draggingUpCollapses() {
        let viewModel = makeViewModel()
        frame(viewModel, pinned: 10, next: 11, travelled: 0)

        frame(viewModel, pinned: 10, next: 11, travelled: 40)
        #expect(abs(viewModel.progress - 0.4) < 0.000_001)
        #expect(viewModel.mode == .monthly)

        frame(viewModel, pinned: 10, next: 11, travelled: 105)
        #expect(viewModel.progress == 1)
        #expect(viewModel.mode == .weekly)
    }

    @Test("Travel accumulates across frames rather than resetting each one")
    func travelAccumulates() {
        let viewModel = makeViewModel()
        frame(viewModel, pinned: 10, next: 11, travelled: 0)

        for step in stride(from: 20.0, through: 80.0, by: 20.0) {
            frame(viewModel, pinned: 10, next: 11, travelled: step)
        }

        #expect(abs(viewModel.progress - 0.8) < 0.000_001)
        #expect(viewModel.mode == .monthly)
    }

    @Test("Pulling down expands, from wherever in the range the list is resting")
    func pullingDownExpands() {
        let viewModel = makeViewModel(mode: .weekly)
        frame(viewModel, pinned: 20, next: 21, travelled: 0)

        frame(viewModel, pinned: 20, next: 21, travelled: -45)
        #expect(abs(viewModel.progress - 0.55) < 0.000_001)
        #expect(viewModel.mode == .weekly)

        frame(viewModel, pinned: 20, next: 21, travelled: -110)
        #expect(viewModel.progress == 0)
        #expect(viewModel.mode == .monthly)
    }

    @Test("The pinned header is ignored, since it never moves however far you scroll")
    func pinnedHeaderIsExcluded() {
        let viewModel = makeViewModel()

        // Seed, then move only the free headers. If the parked one were counted,
        // the median would be dragged towards zero and the drag would read short.
        viewModel.trackListTravel([
            AgendaHeaderOffset(id: id(10), minY: 0),
            AgendaHeaderOffset(id: id(11), minY: 300)
        ])
        viewModel.trackListTravel([
            AgendaHeaderOffset(id: id(10), minY: 0),
            AgendaHeaderOffset(id: id(11), minY: 200)
        ])

        #expect(viewModel.progress == 1)
        #expect(viewModel.mode == .weekly)
    }

    @Test("A header appearing at the edge cannot be mistaken for a drag")
    func newHeadersAreIgnoredUntilSeenTwice() {
        let viewModel = makeViewModel()
        viewModel.trackListTravel([
            AgendaHeaderOffset(id: id(10), minY: 0),
            AgendaHeaderOffset(id: id(11), minY: 240)
        ])

        // Day 12 scrolls into view for the first time. It has no previous
        // position, so it contributes nothing; day 11 says the list held still.
        viewModel.trackListTravel([
            AgendaHeaderOffset(id: id(10), minY: 0),
            AgendaHeaderOffset(id: id(11), minY: 240),
            AgendaHeaderOffset(id: id(12), minY: 620)
        ])

        #expect(viewModel.progress == 0)
    }

    @Test("Settling on a new day re-zeroes the gesture")
    func settlingReZeroes() {
        let viewModel = makeViewModel()
        frame(viewModel, pinned: 10, next: 11, travelled: 0)
        frame(viewModel, pinned: 10, next: 11, travelled: 105)
        #expect(viewModel.mode == .weekly)

        // The list settles on day 14; the next gesture starts from zero there.
        viewModel.headerOffsetsChanged([AgendaHeaderOffset(id: id(14), minY: 0)])
        #expect(viewModel.selection == Fixture.date(2030, 7, 14))

        frame(viewModel, pinned: 14, next: 15, travelled: 0)
        frame(viewModel, pinned: 14, next: 15, travelled: -110)
        #expect(viewModel.progress == 0)
        #expect(viewModel.mode == .monthly)
    }

    @Test("The selection is frozen mid-gesture so the zero cannot shift under it")
    func selectionFreezesMidGesture() {
        let viewModel = makeViewModel()
        frame(viewModel, pinned: 10, next: 11, travelled: 0)
        frame(viewModel, pinned: 10, next: 11, travelled: 55)
        #expect(abs(viewModel.progress - 0.55) < 0.000_001)

        // A one-line empty day pins the next header well inside the threshold.
        viewModel.headerOffsetsChanged([AgendaHeaderOffset(id: id(11), minY: 0)])

        #expect(viewModel.selection == Fixture.date(2030, 7, 10))
        #expect(abs(viewModel.progress - 0.55) < 0.000_001)
    }
}

@Suite("Agenda collapse settling")
@MainActor
struct AgendaCollapseSettleTests {

    let calendar = Fixture.gregorian

    func makeViewModel(mode: EZCalendarAgendaMode = .monthly) -> EZCalendarAgendaViewModel {
        let selection = Fixture.date(2030, 7, 10)
        let viewModel = EZCalendarAgendaViewModel(calendar: calendar, mode: mode, selection: selection)
        viewModel.rebuildPages(from: Fixture.months([(7, 2030)]))
        viewModel.primePagers(for: selection)
        return viewModel
    }

    @Test("A drag released short of the threshold springs back")
    func partialDragSpringsBack() {
        let viewModel = makeViewModel()

        viewModel.listOffsetChanged(60)
        #expect(abs(viewModel.progress - 0.6) < 0.000_001)

        // Without this, a half-finished scroll leaves the calendar frozen
        // mid-collapse: there is no gesture-ended callback to resolve it.
        viewModel.settleCollapse()

        #expect(viewModel.progress == 0)
        #expect(viewModel.mode == .monthly)
    }

    @Test("A partial expand springs back to weekly")
    func partialExpandSpringsBack() {
        let viewModel = makeViewModel(mode: .weekly)

        viewModel.listOffsetChanged(-55)
        #expect(abs(viewModel.progress - 0.45) < 0.000_001)

        viewModel.settleCollapse()

        #expect(viewModel.progress == 1)
        #expect(viewModel.mode == .weekly)
    }

    @Test("Settling an already-resting calendar changes nothing")
    func settlingAtRestIsANoOp() {
        let viewModel = makeViewModel()
        viewModel.settleCollapse()
        #expect(viewModel.progress == 0)
        #expect(viewModel.mode == .monthly)

        let collapsed = makeViewModel(mode: .weekly)
        collapsed.settleCollapse()
        #expect(collapsed.progress == 1)
        #expect(collapsed.mode == .weekly)
    }

    @Test("A drag that crossed the threshold has already flipped and needs no settling")
    func crossedThresholdNeedsNoSettle() {
        let viewModel = makeViewModel()

        viewModel.listOffsetChanged(140)
        #expect(viewModel.mode == .weekly)
        #expect(viewModel.progress == 1)

        viewModel.settleCollapse()
        #expect(viewModel.mode == .weekly)
        #expect(viewModel.progress == 1)
    }
}
