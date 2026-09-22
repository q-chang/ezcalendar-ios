//
//  AgendaCalendarView.swift
//  EZCalendar
//
//  Created by wisanu on 27/8/2569 BE.
//

import SwiftUI

/// The top half of the agenda: caller title bar, weekday header, and the
/// collapsible calendar window.
///
/// ## Why there are two pagers
///
/// `.monthly` must page by month and `.weekly` must page by week, so one scroll
/// view cannot serve both — its pages would be the wrong size in one of the two
/// modes. This view keeps both and shows one at a time:
///
/// | Condition | Pager on screen |
/// | --- | --- |
/// | `.monthly`, or any drag in progress | month pager, collapsed by `progress` |
/// | `.weekly`, fully settled | week pager |
///
/// The swap is invisible because the month pager at `progress == 1` is already
/// showing exactly one week row, in the same place, with the same background as
/// the week pager's page. The user sees the collapse finish; the pager change
/// underneath it has no visual signature.
struct AgendaCalendarView<TitleView: View, WeekdayItemView: View, DayItemView: View>: View {

    @ObservedObject var viewModel: EZCalendarAgendaViewModel

    let weekDayTitles: [String]?
    let locale: Locale
    let gridLineColor: Color?
    let refreshConfiguration: AgendaRefreshConfiguration?

    let titleViewContent: (EZCalendarAgendaTitleContext) -> TitleView
    let weekdayItemViewContent: (String) -> WeekdayItemView
    let dayItemViewContent: (CalendarDay) -> DayItemView

    var body: some View {
        if let refreshConfiguration {
            calendarContent
                .contentShape(Rectangle())
                .simultaneousGesture(refreshGesture(configuration: refreshConfiguration))
        } else {
            calendarContent
        }
    }

    private var calendarContent: some View {
        VStack(spacing: 0) {
            refreshIndicator

            titleViewContent(titleContext)

            EZCalendarWeekdayHeaderView(
                weekDayTitles: weekDayTitles,
                locale: locale,
                weekdayItemViewContent: weekdayItemViewContent
            )

            calendarWindow
        }
    }

    /// The refresh slot is structurally above the caller's title bar rather
    /// than overlaid on the grid. The caller controls its height while pulling
    /// (typically from `context.progress`), so the library imposes no visual
    /// treatment or fixed layout on a custom indicator.
    @ViewBuilder
    private var refreshIndicator: some View {
        if let refreshConfiguration,
           viewModel.refreshContext.phase != .idle {
            refreshConfiguration.indicator(viewModel.refreshContext)
                .allowsHitTesting(false)
        }
    }

    /// A simultaneous gesture lets the month pager continue owning horizontal
    /// swipes. `EZCalendarAgendaViewModel` direction-locks the first meaningful
    /// movement, so only a downward vertical pull changes refresh state.
    private func refreshGesture(configuration: AgendaRefreshConfiguration) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                viewModel.refreshDragChanged(
                    translation: value.translation,
                    threshold: configuration.threshold
                )
            }
            .onEnded { _ in
                viewModel.refreshDragEnded(configuration: configuration)
            }
    }

    /// Data and actions for the caller's `‹ July 2569 ›` bar.
    private var titleContext: EZCalendarAgendaTitleContext {
        EZCalendarAgendaTitleContext(
            date: viewModel.pageDate(for: viewModel.mode, fallback: viewModel.selection),
            mode: viewModel.mode,
            pageBackward: { viewModel.page(by: -1) },
            pageForward: { viewModel.page(by: 1) }
        )
    }

    /// `true` once the collapse has fully settled into `.weekly`.
    ///
    /// All three conditions matter. `progress >= 1` covers a drag that the user
    /// pushed to the end; `!isTransitioning` covers an animated mode change,
    /// where `progress` reaches its target value in the model long before the
    /// animation that shows it has finished. Without the second one, both pagers
    /// render at once for the whole transition and visibly ghost over each other.
    private var showsWeekPager: Bool {
        viewModel.mode == .weekly && viewModel.progress >= 1 && !viewModel.isTransitioning
    }

    /// The clipping window that gives the calendar its height.
    ///
    /// The height is `nil` until the first measurement arrives, which lets the
    /// grid size itself naturally for one frame rather than collapsing to zero.
    /// After that it is driven entirely by measured values — the library never
    /// asserts how tall a caller's day cell is.
    private var calendarWindow: some View {
        ZStack(alignment: .top) {
            if showsWeekPager {
                weekPager
            } else {
                monthPager
            }
        }
        // The window height is calculated from the measured week rows. This
        // keeps four-, five-, and six-row months distinct in expanded mode and
        // gives the collapse animation the same complete month height.
        .frame(height: calendarWindowHeight, alignment: .top)
        .clipped()
    }

    private var calendarWindowHeight: CGFloat? {
        return viewModel.calendarHeight(for: viewModel.visibleMonthPage).map { CGFloat($0) }
    }

    private var monthPager: some View {
        ScrollView(.horizontal) {
            // Each visible month contains a non-lazy VStack of all its week
            // rows, so row measurement stays complete. Keeping the page strip
            // lazy avoids constructing every configured month during a swipe.
            LazyHStack(alignment: .top, spacing: 0) {
                ForEach(viewModel.monthPages) { page in
                    AgendaMonthGridView(
                        page: page,
                        viewModel: viewModel,
                        gridLineColor: gridLineColor,
                        dayItemViewContent: dayItemViewContent
                    )
                    .containerRelativeFrame(.horizontal, count: 1, spacing: 0)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $viewModel.visibleMonthID)
        .scrollIndicators(.never)
        // Do not apply `.fixedSize(vertical: true)` here. A horizontal
        // `ScrollView` then keeps its initial five-row internal viewport even
        // when the outer window grows for a six-row month; a wrapping frame
        // merely exposes blank space below that clipped viewport. Giving the
        // scroll view the measured window height directly lets its own clipping
        // region grow with the visible page.
        .frame(height: calendarWindowHeight, alignment: .top)
        .onChange(of: viewModel.visibleMonthID) { _, id in
            viewModel.pagerScrolled(to: id)
        }
        .onPreferenceChange(AgendaGridRowHeightKey.self) { rowHeights in
            for (pageID, rows) in rowHeights {
                let height = rows.values.reduce(0, +)
                    + viewModel.gridSpacing * Double(max(0, rows.count - 1))
                viewModel.gridHeights[pageID] = height
            }
        }
    }

    private var weekPager: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 0) {
                ForEach(viewModel.weekPages) { page in
                    AgendaWeekPageView(
                        page: page,
                        gridLineColor: gridLineColor,
                        dayItemViewContent: dayItemViewContent
                    )
                    .containerRelativeFrame(.horizontal, count: 1, spacing: 0)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $viewModel.visibleWeekID)
        .scrollIndicators(.never)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: viewModel.visibleWeekID) { _, id in
            viewModel.pagerScrolled(to: id)
        }
    }
}
