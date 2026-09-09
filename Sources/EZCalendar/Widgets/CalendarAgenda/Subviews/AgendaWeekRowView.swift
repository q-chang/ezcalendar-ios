//
//  AgendaWeekRowView.swift
//  EZCalendar
//
//  Created by wisanu on 27/8/2569 BE.
//

import SwiftUI

/// One week of the calendar — always exactly seven cells.
///
/// This is the unit the collapse animation works in: a month grid is a stack of
/// these, and `.weekly` mode is one of them surviving on its own.
///
/// The only layout opinion here is `maxWidth: .infinity` on each cell, which is
/// the `HStack` equivalent of the `GridItem(.flexible())` columns
/// `EZCalendarItemView` uses. It divides the width evenly and states nothing
/// about height — that still comes from the caller's cell.
struct AgendaWeekRowView<DayItemView: View>: View {

    let days: [CalendarDay]
    let dayItemViewContent: (CalendarDay) -> DayItemView

    var body: some View {
        HStack(spacing: 1) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                dayItemViewContent(day)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
