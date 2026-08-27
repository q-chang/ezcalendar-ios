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

    let titleViewContent: (EZCalendarAgendaTitleContext) -> TitleView
    let weekdayItemViewContent: (String) -> WeekdayItemView
    let dayItemViewContent: (CalendarDay) -> DayItemView

    var body: some View {
        VStack(spacing: 0) {
            titleViewContent(titleContext)

            EZCalendarWeekdayHeaderView(
                weekDayTitles: weekDayTitles,
                locale: locale,
                weekdayItemViewContent: weekdayItemViewContent
            )

            calendarWindow
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

    /// `true` once the collapse has fully settled into `.weekly`. Mid-drag the
    /// month pager stays on screen so its rows can keep fading.
    private var showsWeekPager: Bool {
        viewModel.mode == .weekly && viewModel.progress >= 1
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
        .frame(height: viewModel.calendarHeight(for: viewModel.visibleMonthPage).map { CGFloat($0) }, alignment: .top)
        .clipped()
    }

    private var monthPager: some View {
        ScrollView(.horizontal) {
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
        // Take the content's own height rather than the proposal, so the window
        // above can clip a grid that is measuring itself at full size.
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: viewModel.visibleMonthID) { _, id in
            viewModel.pagerScrolled(to: id)
        }
        .onPreferenceChange(AgendaGridHeightKey.self) { heights in
            viewModel.gridHeights.merge(heights) { _, new in new }
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
