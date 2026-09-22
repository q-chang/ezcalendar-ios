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
 measured heights, collapse progress, and the two re-entrancy
 latches that keep the calendar and the list from shouting at each other.

 The public three stay as `@Binding`s on the view. Everything else lives here, so
 `body` never computes and never branches on anything but data.

 ## The one number that drives every animation

 `progress` is `0` when the calendar is a full month and `1` when it is a single
 week. A live handle drag writes it continuously so the calendar tracks the
 finger; releasing the drag, or changing `mode` programmatically, animates it to
 one end or the other.

 The agenda list cannot change the mode at all — scrolling it only scrolls it.

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

    /// How far the grab handle must be dragged, on release, to commit a switch.
    /// Caller-tunable through `.collapseThreshold(_:)`.
    var collapseThreshold: Double = 78

    /// How fast the handle must be flicked, in points per second, to commit a
    /// switch regardless of distance.
    /// Caller-tunable through `.collapseVelocityThreshold(_:)`.
    var collapseVelocityThreshold: Double = 350

    /// Animation used when a gesture settles or `mode` changes programmatically.
    /// Caller-tunable through `.collapseAnimation(_:)`.
    var collapseAnimation: Animation = .easeOut(duration: 0.3)

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

    /// `true` from the moment a mode change starts until its animation finishes.
    ///
    /// This exists because `progress` is a *model* value: `withAnimation` sets it
    /// to its target instantly and animates only what SwiftUI interpolates from
    /// it. Anything that branches — like "which pager is on screen" — would
    /// therefore switch on the first frame and cross-fade the two pagers on top
    /// of each other for the whole transition. Branch on this instead.
    @Published private(set) var isTransitioning = false

    /// Natural, *unclipped* height of each month page's grid, keyed by page id.
    /// Measured at runtime — the library states no opinion about cell height, so
    /// the collapse animation has no constant it could use instead.
    @Published var gridHeights: [String: Double] = [:]

    // MARK: - List state

    /// Where each visible section header sits, in the list's coordinate space.
    @Published private(set) var headerOffsets: [AgendaHeaderOffset] = []

    /// What the list should scroll to, and whether to animate getting there.
    /// The view watches this inside its `ScrollViewReader` and calls `scrollTo`.
    @Published var scrollRequest: AgendaScrollRequest?

    /// `dayID` → date, so a reported header id can be turned back into a day.
    var sectionDates: [String: Date] = [:]

    // MARK: - Re-entrancy latches

    private var isDrivingList = false
    private var isDrivingPager = false
    private var listSyncRelease: Task<Void, Never>?
    private var pagerSyncRelease: Task<Void, Never>?

    /// The section id an in-flight scroll is heading for. The list latch is
    /// released the moment this one reports itself pinned — see
    /// `headerOffsetsChanged(_:)`.
    private var pendingScrollTarget: String?

    /// The very first scroll positions the list on the selected day. That one
    /// must not animate: the day can be months from the top of the range, and
    /// animating there would scroll through every section in between.
    private var hasPositionedList = false

    /// Scroll offset the list last reported, and the offset it was resting at
    /// when the current mode settled. The collapse is driven by the difference.

    /// Re-issues left for the current scroll. See `correctScroll(towards:)`.
    private var scrollCorrectionsRemaining = 0

    /// How close to the top edge the target header has to land, in points,
    /// before the scroll counts as arrived.
    private let arrivalSlack: Double = 2

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
        // CalendarWeek identities are regenerated with the page data, so a
        // previous row-height measurement is no longer valid. Let the visible
        // page report its own rows again rather than briefly clipping to a
        // stale height.
        gridHeights = [:]
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
    /// Updates the selected day and optionally collapses a monthly calendar.
    func selectDay(_ date: Date, collapseOnSelection: Bool = true) {
        selection = calendar.startOfDay(for: date)

        if mode == .monthly && collapseOnSelection {
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
        // The pager for the incoming mode is about to be created. A freshly
        // created `ScrollView` can report its own initial position back through
        // `scrollPosition(id:)`, which would read as a user swipe and rewrite
        // the selection — so latch before it appears, not only when we move it.
        holdPagerLatch()

        syncPager(to: selection, mode: mode)

        let target = mode.progress

        // A gesture that ran all the way to the end has already put `progress`
        // where it belongs; animating a no-op would raise and drop
        // `isTransitioning` for one frame and flicker the pager swap.
        guard progress != target else { return }

        isTransitioning = true

        withAnimation(collapseAnimation, completionCriteria: .removed) {
            progress = target
        } completion: {
            // Swap the pagers without an implicit animation of their own: the
            // two are geometrically identical at this point, so the change
            // should have no visual signature at all.
            var transaction = Transaction()
            transaction.disablesAnimations = true

            withTransaction(transaction) {
                self.isTransitioning = false
            }
        }
    }

    // MARK: - Collapse gesture
    //
    // The grab handle is the *only* thing that switches modes by gesture.
    //
    // The agenda list used to drive it too, off its scroll offset. That is gone
    // on purpose: it meant an ordinary scroll through the day's events could
    // collapse the calendar out from under the reader, and an over-scroll at the
    // top could expand it, neither of which the user asked for. Scrolling the
    // list now only ever scrolls the list.

    /// Live drag on the grab handle: the calendar follows the finger.
    ///
    /// This only previews. Nothing is committed until the finger lifts, so a
    /// drag can be taken anywhere and abandoned, and `mode` is stable throughout —
    /// which is what lets the mapping below use it as a fixed starting point.
    func handleDragChanged(translation: Double) {
        progress = EZCalendarAgendaLogic.progress(
            forHandleTranslation: translation,
            from: mode,
            travel: interactiveTravel
        )
    }

    /// Released handle drag: commit past the distance threshold *or* on a fast
    /// enough flick, otherwise spring back.
    func handleDragEnded(translation: Double, velocity: Double) {
        let resolved = EZCalendarAgendaLogic.mode(
            forHandleTranslation: translation,
            velocity: velocity,
            from: mode,
            threshold: collapseThreshold,
            velocityThreshold: collapseVelocityThreshold
        )

        if resolved != mode {
            // `modeChanged()` animates whatever is left of the way there.
            mode = resolved
        } else {
            withAnimation(collapseAnimation) {
                progress = mode.progress
            }
        }
    }

    /// How far the handle must travel to close the calendar completely: the
    /// height the grid actually loses, month minus one week row.
    ///
    /// Measured, never assumed — the caller decides how tall a day cell is. Until
    /// the first measurement lands there is nothing to map against, so the
    /// commit threshold stands in; the gesture still works on the very first
    /// frame, it just is not yet 1:1 with the content.
    private var interactiveTravel: Double {
        guard let page = visibleMonthPage else { return collapseThreshold }

        let distance = fullGridHeight(for: page) - rowHeight(for: page)
        return distance > 0 ? distance : collapseThreshold
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

    /// Puts **both** pagers on the page holding `date`.
    ///
    /// The off-screen one matters as much as the visible one. An interactive
    /// collapse reveals the month pager the instant `progress` drops below 1 —
    /// mid-gesture, long before any mode change could fix it up — so if it were
    /// only synced on mode changes, dragging open a week that the list had
    /// scrolled into a different month would reveal the wrong month and then
    /// jump. The visible pager animates to its page; the hidden one is simply
    /// placed there.
    func syncPager(to date: Date, mode: EZCalendarAgendaMode) {
        if let index = EZCalendarAgendaLogic.index(ofMonthContaining: date, in: monthPages, calendar: calendar) {
            let id = monthPages[index].id

            if id != visibleMonthID {
                holdPagerLatch()

                if mode == .monthly {
                    withAnimation { visibleMonthID = id }
                } else {
                    visibleMonthID = id
                }
            }
        }

        if let index = EZCalendarAgendaLogic.index(ofWeekContaining: date, in: weekPages, calendar: calendar) {
            let id = weekPages[index].id

            if id != visibleWeekID {
                holdPagerLatch()

                if mode == .weekly {
                    withAnimation { visibleWeekID = id }
                } else {
                    visibleWeekID = id
                }
            }
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

        let topID = EZCalendarAgendaLogic.topMostSectionID(headerOffsets: offsets)

        // Do not read the list back while we are the ones moving it.
        if isDrivingList {
            // Release on *arrival* rather than on a timer. A timer has to guess
            // how long the scroll takes, and guessing short is catastrophic: the
            // latch lifts mid-flight, every header the list is still flying past
            // rewrites the selection, and each rewrite starts another scroll.
            correctScroll(towards: offsets)
            return
        }

        guard let topID,
              let date = sectionDates[topID],
              !calendar.isDate(date, inSameDayAs: selection)
        else { return }

        selection = date
    }

    /// Turns the list's scroll into collapse progress.
    ///
    /// The measurement is deliberately *relative*: how far the **selected day's**
    /// own sticky header has been dragged away from the top edge, not how far the
    /// list has scrolled overall.
    ///
    /// Absolute scroll offset cannot work here. The list opens already scrolled
    /// to the selected day, which is typically months into the range, so an
    /// absolute measure reads as "miles from the top" before the user has
    /// touched anything — and the calendar would collapse on launch. Anchoring to
    /// the selected day instead makes "the list is at its top" mean "the day you
    /// picked is at the top", which is what the user actually sees, and it holds
    /// anywhere in the range.
    ///
    /// ```
    ///   anchor header minY      relative offset      meaning
    ///   ──────────────────      ───────────────      ───────────────────
    ///          0                       0             at rest
    ///        -60                     +60             dragged up  → collapsing
    ///        +60                     -60             pulled down → expanding
    /// ```
    ///
    /// When the anchor scrolls out of view entirely there is nothing to report,
    /// so progress simply holds — which is the right behaviour: deep in the list
    /// the calendar stays collapsed.
    /// Asks the list to bring `date`'s sticky header to the top.
    private func requestListScroll(to date: Date) {
        let id = EZCalendarAgendaLogic.dayID(for: date, calendar: calendar)
        guard sectionDates[id] != nil else { return }

        isDrivingList = true
        pendingScrollTarget = id
        scrollCorrectionsRemaining = 3
        scrollRequest = AgendaScrollRequest(id: id, animated: hasPositionedList)
        hasPositionedList = true

        releaseListLatch()
    }

    /// Nudges the list onto its target, then releases the latch.
    ///
    /// `scrollTo` into a `LazyVStack` of a few hundred variable-height sections
    /// lands *approximately*: SwiftUI has to estimate the offsets of rows it has
    /// not built yet, and the estimate drifts over a long hop. Undershooting by
    /// even one header height is not cosmetic here — the previous day's header
    /// stays pinned at the top, the sync reads it as the day on screen, and the
    /// calendar ends up selecting the day *before* the one that was asked for.
    ///
    /// The residual is already being measured, so this re-issues the scroll now
    /// that the target is materialised and the estimate is exact. Attempts are
    /// capped: the latch must not be held open by a target that can never reach
    /// the top, such as the last day in the range.
    private func correctScroll(towards offsets: [AgendaHeaderOffset]) {
        guard let target = pendingScrollTarget else {
            releaseListLatchNow()
            return
        }

        // Not built yet — keep waiting; the backstop timer covers the rest.
        guard let landed = offsets.first(where: { $0.id == target }) else { return }

        if abs(landed.minY) <= arrivalSlack {
            releaseListLatchNow()
            return
        }

        guard scrollCorrectionsRemaining > 0 else {
            releaseListLatchNow()
            return
        }

        scrollCorrectionsRemaining -= 1
        scrollRequest = AgendaScrollRequest(id: target, animated: false)
    }

    /// Backstop only. The latch is normally released by arrival, in
    /// `headerOffsetsChanged(_:)`; this covers the case where the target never
    /// reports itself — a section that was removed mid-scroll, or a list too
    /// short to bring that day to the top.
    private func releaseListLatch() {
        listSyncRelease?.cancel()
        listSyncRelease = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            self?.releaseListLatchNow()
        }
    }

    private func releaseListLatchNow() {
        listSyncRelease?.cancel()
        listSyncRelease = nil
        pendingScrollTarget = nil
        scrollCorrectionsRemaining = 0
        isDrivingList = false
    }

    /// Holds the pager latch across a programmatic move, so the page we just
    /// scrolled to does not report itself back as a user swipe.
    ///
    /// Unlike the list, the pager has no "arrived" signal worth waiting on — the
    /// id we are moving to is the id it will report — so this one does stay a
    /// timer.
    private func holdPagerLatch() {
        isDrivingPager = true

        pagerSyncRelease?.cancel()
        pagerSyncRelease = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            self?.isDrivingPager = false
        }
    }
}
