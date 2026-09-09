//
//  AgendaMonthGridView.swift
//  EZCalendar
//
//  Created by wisanu on 27/8/2569 BE.
//

import SwiftUI

/// One month, as a stack of week rows — the collapsible page of `.monthly` mode.
///
/// `EZCalendarItemView` renders a month as a single `LazyVGrid`, which cannot
/// fade or translate one week independently of the others. This view lays the
/// same `[CalendarWeek]` out row by row instead, so the collapse can act on each
/// row separately. The *data* is unchanged: it comes from the very same
/// `EZCalendarItemViewModel` grid the rest of the library uses.
///
/// ## The three numbers that produce the animation
///
/// ```
/// progress 0 ────────────────────────────────► progress 1
///
///  ┌───────────────┐                       ┌───────────────┐
///  │ 29 30  1  2 … │ opacity 1 → 0         │               │  ← consumed
///  │  6  7  8  9 … │ opacity 1 → 0         │               │  ← consumed
///  │ 13 14 15 16 … │ opacity 1 (selected)  │ 13 14 15 16 … │  ← survives
///  │ 20 21 22 23 … │ opacity 1 → 0         │               │  ← consumed
///  └───────────────┘                       └───────────────┘
///     height = full                           height = 1 row
///     offset = 0                              offset = -2 × pitch
/// ```
///
/// * **opacity** — `rowOpacity` fades every row but the selected one.
/// * **offset** — `gridOffset` slides the stack up so the selected row lands at
///   y = 0 exactly as the window finishes closing.
/// * **height** — set by the parent's clipping window, not here.
///
/// Because the offset cancels the rows above it, the selected week appears to
/// hold still while everything around it collapses — which is what the reference
/// animation shows.
struct AgendaMonthGridView<DayItemView: View>: View {

    let page: AgendaMonthPage
    @ObservedObject var viewModel: EZCalendarAgendaViewModel
    let gridLineColor: Color?
    let dayItemViewContent: (CalendarDay) -> DayItemView

    var body: some View {
        VStack(spacing: viewModel.gridSpacing) {
            // Identified by the week's own uuid rather than by content: two
            // structurally identical weeks must stay two distinct rows.
            ForEach(Array(page.weeks.enumerated()), id: \.element.uuid) { index, week in
                AgendaWeekRowView(
                    days: week.calendarDays,
                    dayItemViewContent: dayItemViewContent
                )
                .opacity(viewModel.rowOpacity(rowIndex: index, in: page))
            }
        }
        .background(gridLineColor)
        // Measured *after* the background so the reported height is exactly the
        // height the parent's window has to clip to.
        .measureGridHeight(id: page.id)
        .offset(y: viewModel.gridOffset(for: page))
    }
}

/// One week, as a page of `.weekly` mode.
///
/// Deliberately identical in construction to a single row of
/// `AgendaMonthGridView` — same spacing, same grid-line background — so that
/// when the calendar swaps from the month pager to the week pager at the end of
/// a collapse, nothing on screen moves.
struct AgendaWeekPageView<DayItemView: View>: View {

    let page: AgendaWeekPage
    let gridLineColor: Color?
    let dayItemViewContent: (CalendarDay) -> DayItemView

    var body: some View {
        AgendaWeekRowView(
            days: page.days,
            dayItemViewContent: dayItemViewContent
        )
        .background(gridLineColor)
    }
}
