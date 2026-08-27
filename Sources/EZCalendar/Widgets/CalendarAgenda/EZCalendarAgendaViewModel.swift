//
//  EZCalendarAgendaViewModel.swift
//  EZCalendar
//
//  Created by wisanu on 27/8/2569 BE.
//

import Foundation
import SwiftUI

/**
 # 🎛️ `EZCalendarAgendaViewModel` — the agenda's state machine

 `EZCalendarAgendaView` owns three things the caller can see (`mode`,
 `selectedDate`, `calendarMonths`) and about a dozen it cannot: page sets,
 measured heights, scroll offsets, collapse progress, and the two re-entrancy
 latches that keep the calendar and the list from shouting at each other.

 The public three stay as `@Binding`s on the view. Everything else lives here, so
 `body` never computes and never branches on anything but data.

 ## The one number that drives every animation

 `progress` is `0` when the calendar is a full month and `1` when it is a single
 week. A list scroll, a handle drag, and a programmatic `mode` change all funnel
 into it, which is why the view has exactly one transition code path instead of
 three.

 ## The two latches

 Two-way sync is a feedback loop by construction: the calendar scrolls the list,
 the list reports a new top day, that day updates the calendar, which scrolls the
 list. Two guards break it.

 | Latch | Blocks |
 | --- | --- |
 | `isDrivingList` | List → calendar echo while *we* are animating the list. Released on a short timer, because SwiftUI has no "scroll finished" callback. |
 | `isDrivingPager` | Page → selection echo while *we* are animating the pager to follow a selection the user made elsewhere. |

 `selectionChanged()` adds a third, cheaper guard: if the list's top
 section already *is* the newly selected day, it skips the scroll entirely. Most
 echoes die there and never reach a latch.
 */
@MainActor
final class EZCalendarAgendaViewModel: ObservableObject {

    // MARK: - Configuration

    let calendar: Calendar

    /// Points of drag or scroll that constitute a full collapse or expand.
    /// Caller-tunable through `.collapseThreshold(_:)`.
    var collapseThreshold: Double = 100

    /// Animation used when a gesture settles or `mode` changes programmatically.
    /// Caller-tunable through `.collapseAnimation(_:)`.
    var collapseAnimation: Animation = .snappy(duration: 0.28)

    /// The inter-row gap of the grid. Matches `EZCalendarItemView`'s fixed 1pt
    /// `LazyVGrid` spacing — the library's one deliberate styling exception,
    /// which exists so a caller's cell background reads as grid lines.
    let gridSpacing: Double = 1

    // MARK: - Page sets

    @Published private(set) var monthPages: [AgendaMonthPage] = []
    @Published private(set) var weekPages: [AgendaWeekPage] = []

    /// Scroll positions of the two horizontal pagers, one per mode.
    @Published var visibleMonthID: String?
    @Published var visibleWeekID: String?

    // MARK: - Collapse state

    /// `0` = full month, `1` = single week. Continuous while a gesture is live.
    @Published var progress: Double = 0

    /// Natural, *unclipped* height of each month page's grid, keyed by page id.
    /// Measured at runtime — the library states no opinion about cell height, so
    /// the collapse animation has no constant it could use instead.
    @Published var gridHeights: [String: Double] = [:]

    // MARK: - List state

    /// Where each visible section header sits, in the list's coordinate space.
    @Published private(set) var headerOffsets: [AgendaHeaderOffset] = []

    /// Section id the list should scroll to. The view watches this inside its
    /// `ScrollViewReader` and calls `scrollTo`.
    @Published var scrollTarget: String?

    /// `dayID` → date, so a reported header id can be turned back into a day.
    var sectionDates: [String: Date] = [:]

    // MARK: - Re-entrancy latches

    private var isDrivingList = false
    private var isDrivingPager = false
    private var isHandleDragging = false
    private var listSyncRelease: Task<Void, Never>?
    private var pagerSyncRelease: Task<Void, Never>?

    // MARK: - Mirrored caller state
    //
    // `mode` and `selection` are `@Binding`s on the view, but the view model is
    // their source of truth: gestures, paging and list scrolling all write here
    // first, and `EZCalendarAgendaView` mirrors the value out to the caller's
    // binding (and any caller change back in) at its edges.
    //
    // Keeping `Binding` out of the view model is not tidiness. `Binding` is not
    // `Sendable`, and half of this state is written from SwiftUI preference
    // callbacks, which are `@Sendable` closures — a binding captured there does
    // not compile under Swift 6's strict concurrency.

    /// The mode the calendar is resting in, or heading toward mid-gesture.
    @Published var mode: EZCalendarAgendaMode

    /// The selected day, always normalised to the start of the day.
    @Published var selection: Date

    init(calendar: Calendar, mode: EZCalendarAgendaMode, selection: Date) {
        self.calendar = calendar
        self.mode = mode
        self.selection = calendar.startOfDay(for: selection)
        self.progress = mode.progress
    }

    private var today: Date { Date() }

    // MARK: - Page building

    /// Rebuilds both page sets. Cheap enough to call on every `calendarMonths`
    /// change: the month grids come straight from `EZCalendarItemViewModel`, and
    /// the week set is a de-duplicated flattening of them.
    func rebuildPages(from months: [CalendarMonth]) {
        monthPages = EZCalendarAgendaLogic.monthPages(from: months, calendar: calendar)
        weekPages = EZCalendarAgendaLogic.weekPages(from: monthPages, calendar: calendar)
    }

    var visibleMonthPage: AgendaMonthPage? {
        monthPages.first { $0.id == visibleMonthID } ?? monthPages.first
    }

    var visibleWeekPage: AgendaWeekPage? {
        weekPages.first { $0.id == visibleWeekID } ?? weekPages.first
    }

    /// First day of the page on screen — what the caller's title bar formats.
    /// Deliberately not the selected date, so a title does not flicker while the
    /// user taps around inside one page.
    func pageDate(for mode: EZCalendarAgendaMode, fallback: Date) -> Date {
        switch mode {
        case .monthly: return visibleMonthPage?.firstDate ?? fallback
        case .weekly: return visibleWeekPage?.firstDate ?? fallback
        }
    }

    // MARK: - Measured geometry
    //
    // The three numbers below are what turn a measured grid into the interactive
    // collapse. All of them derive from `gridHeights`, which is reported by the
    // rendered grid itself — never assumed.

    /// Natural height of the month page currently on screen.
    private func fullGridHeight(for page: AgendaMonthPage?) -> Double {
        guard let page else { return 0 }
        return gridHeights[page.id] ?? 0
    }

    /// Height of one week row, backed out of the measured grid.
    private func rowHeight(for page: AgendaMonthPage?) -> Double {
        guard let page else { return 0 }
        return EZCalendarAgendaLogic.rowHeight(
            gridHeight: fullGridHeight(for: page),
            rowCount: page.weeks.count,
            spacing: gridSpacing
        )
    }

    /// Animated height of the calendar window: full month → one row.
    func calendarHeight(for page: AgendaMonthPage?) -> Double? {
        let full = fullGridHeight(for: page)

        // Before the first measurement lands, return nil so the view lets the
        // grid size itself naturally rather than clamping it to zero.
        guard full > 0 else { return nil }

        return EZCalendarAgendaLogic.gridHeight(
            fullHeight: full,
            rowHeight: rowHeight(for: page),
            progress: progress
        )
    }

    /// How far the grid slides up so the selected week lands at the top.
    func gridOffset(for page: AgendaMonthPage?) -> Double {
        guard let page else { return 0 }

        return EZCalendarAgendaLogic.gridOffset(
            selectedRowIndex: selectedRowIndex(in: page),
            rowPitch: rowHeight(for: page) + gridSpacing,
            progress: progress
        )
    }

    /// Opacity of one week row: the selected week holds, the rest fade away.
    func rowOpacity(rowIndex: Int, in page: AgendaMonthPage) -> Double {
        EZCalendarAgendaLogic.rowOpacity(
            rowIndex: rowIndex,
            selectedRowIndex: selectedRowIndex(in: page),
            progress: progress
        )
    }

    /// The week row the collapse animation converges on.
    ///
    /// Only the page holding the selection has a meaningful answer. Neighbouring
    /// pages — visible mid-swipe — collapse onto their own first row instead of
    /// borrowing an index that does not apply to them.
    private func selectedRowIndex(in page: AgendaMonthPage) -> Int {
        let components = calendar.dateComponents([.year, .month], from: selection)

        guard components.year == page.calendarMonth.year,
              components.month == page.calendarMonth.month
        else { return 0 }

        return EZCalendarAgendaLogic.rowIndex(
            containing: selection,
            in: page.weeks,
            calendar: calendar
        )
    }

    // MARK: - Day selection

    /// A tap on a day cell.
    ///
    /// Selecting always collapses: in `.monthly` the tap doubles as the
    /// month → week snap, which is why the user never has to drag to get the
    /// list its full height.
    func selectDay(_ date: Date) {
        selection = calendar.startOfDay(for: date)

        if mode == .monthly {
            mode = .weekly
        }
    }

    /// Reacts to a new selection from any source: tap, page swipe, list scroll,
    /// or the caller assigning the binding.
    func selectionChanged() {
        let date = selection
        syncPager(to: date, mode: mode)

        // Cheapest echo guard: if the list is already showing this day at the
        // top, it was the list that moved the selection. Scrolling it again
        // would fight the user's finger.
        let targetID = EZCalendarAgendaLogic.dayID(for: date, calendar: calendar)
        guard EZCalendarAgendaLogic.topMostSectionID(headerOffsets: headerOffsets) != targetID else { return }

        requestListScroll(to: date)
    }

    // MARK: - Mode transitions

    /// Settles `progress` on a mode change, and pre-positions the pager that is
    /// about to appear so the swap between the month and week pagers is
    /// invisible: both show the same week, in the same place, at `progress == 1`.
    func modeChanged() {
        syncPager(to: selection, mode: mode)

        withAnimation(collapseAnimation) {
            progress = mode.progress
        }
    }

    // MARK: - Collapse gestures

    /// The agenda list scrolled. This is the primary collapse driver, and the
    /// reason the gesture never fights the list: the collapse only consumes
    /// movement the list itself cannot use.
    func listOffsetChanged(_ offset: Double) {
        // An explicit handle drag outranks the list; ignore inertial noise while
        // the user's finger owns the transition.
        guard !isHandleDragging else { return }

        let current = mode
        let newProgress = EZCalendarAgendaLogic.progress(
            forListOffset: offset,
            mode: current,
            threshold: collapseThreshold
        )

        progress = newProgress

        let resolved = EZCalendarAgendaLogic.resolvedMode(progress: newProgress, from: current)
        if resolved != current {
            mode = resolved
        }
    }

    /// Live drag on the grab handle.
    func handleDragChanged(translation: Double) {
        isHandleDragging = true

        progress = EZCalendarAgendaLogic.progress(
            forHandleTranslation: translation,
            mode: mode,
            threshold: collapseThreshold
        )
    }

    /// Released handle drag: past the threshold it snaps to the other mode,
    /// short of it it springs back to where it started.
    func handleDragEnded(translation: Double) {
        isHandleDragging = false

        let current = mode
        let finalProgress = EZCalendarAgendaLogic.progress(
            forHandleTranslation: translation,
            mode: current,
            threshold: collapseThreshold
        )

        let resolved = EZCalendarAgendaLogic.resolvedMode(progress: finalProgress, from: current)

        if resolved != current {
            // `modeChanged()` animates progress to its rest value.
            mode = resolved
        } else {
            withAnimation(collapseAnimation) {
                progress = current.progress
            }
        }
    }

    // MARK: - Horizontal paging

    /// Moves the calendar one page in either direction and applies the page's
    /// selection rule. Returns `nil` — and changes nothing — at the ends of the
    /// supplied range.
    func page(by step: Int) {
        guard let newSelection = EZCalendarAgendaLogic.steppedSelection(
            from: selection,
            step: step,
            monthPages: monthPages,
            weekPages: weekPages,
            mode: mode,
            today: today,
            calendar: calendar
        ) else { return }

        selection = newSelection
    }

    /// The user swiped the pager. Applies the mode's selection rule:
    /// today if the new page contains it, otherwise the page's first day.
    func pagerScrolled(to id: String?) {
        guard !isDrivingPager, let id else { return }

        let newSelection: Date?

        switch mode {
        case .monthly:
            newSelection = monthPages.first { $0.id == id }.map {
                EZCalendarAgendaLogic.selection(forMonthPage: $0, today: today, calendar: calendar)
            }
        case .weekly:
            newSelection = weekPages.first { $0.id == id }.map {
                EZCalendarAgendaLogic.selection(forWeekPage: $0, today: today, calendar: calendar)
            }
        }

        guard let newSelection,
              !calendar.isDate(newSelection, inSameDayAs: selection)
        else { return }

        selection = newSelection
    }

    /// Scrolls whichever pager is on screen to the page holding `date`.
    func syncPager(to date: Date, mode: EZCalendarAgendaMode) {
        switch mode {
        case .monthly:
            guard let index = EZCalendarAgendaLogic.index(ofMonthContaining: date, in: monthPages, calendar: calendar) else { return }
            let id = monthPages[index].id
            guard id != visibleMonthID else { return }

            withPagerLatch { withAnimation { self.visibleMonthID = id } }

        case .weekly:
            guard let index = EZCalendarAgendaLogic.index(ofWeekContaining: date, in: weekPages, calendar: calendar) else { return }
            let id = weekPages[index].id
            guard id != visibleWeekID else { return }

            withPagerLatch { withAnimation { self.visibleWeekID = id } }
        }
    }

    /// Positions both pagers without animation. Used once, on appear.
    func primePagers(for date: Date) {
        if let index = EZCalendarAgendaLogic.index(ofMonthContaining: date, in: monthPages, calendar: calendar) {
            visibleMonthID = monthPages[index].id
        }

        if let index = EZCalendarAgendaLogic.index(ofWeekContaining: date, in: weekPages, calendar: calendar) {
            visibleWeekID = weekPages[index].id
        }
    }

    // MARK: - List sync

    /// The list reported new header positions. Whichever header is pinned at the
    /// top is the day the calendar should be showing as selected.
    func headerOffsetsChanged(_ offsets: [AgendaHeaderOffset]) {
        headerOffsets = offsets

        // Do not read the list back while we are the ones moving it.
        guard !isDrivingList else { return }

        guard let id = EZCalendarAgendaLogic.topMostSectionID(headerOffsets: offsets),
              let date = sectionDates[id],
              !calendar.isDate(date, inSameDayAs: selection)
        else { return }

        selection = date
    }

    /// Asks the list to bring `date`'s sticky header to the top.
    private func requestListScroll(to date: Date) {
        let id = EZCalendarAgendaLogic.dayID(for: date, calendar: calendar)
        guard sectionDates[id] != nil else { return }

        isDrivingList = true
        scrollTarget = id
        releaseListLatch()
    }

    /// SwiftUI gives no "scroll animation finished" callback, so the list latch
    /// is released on a timer just longer than the scroll animation. Each new
    /// request cancels the previous timer, so a burst of selections holds the
    /// latch until the last one settles rather than releasing early.
    private func releaseListLatch() {
        listSyncRelease?.cancel()
        listSyncRelease = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            self?.isDrivingList = false
        }
    }

    /// Same idea for the pager: hold the latch across the scroll animation so the
    /// page we just moved to does not report itself back as a user swipe.
    private func withPagerLatch(_ work: () -> Void) {
        isDrivingPager = true
        work()

        pagerSyncRelease?.cancel()
        pagerSyncRelease = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            self?.isDrivingPager = false
        }
    }
}
