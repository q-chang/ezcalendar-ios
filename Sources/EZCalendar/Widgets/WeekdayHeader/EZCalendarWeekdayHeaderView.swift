//
//  EZCalendarWeekdayHeaderView.swift
//  EZCalendar
//
//  Created by Wisanu Paunglumjeak on 25/12/2567 BE.
//

import SwiftUI

public struct EZCalendarWeekdayHeaderView<WeekdayItemView>: View where WeekdayItemView: View {
    
    var weekDayTitles: [String] = []
    var weekdayItemViewContent: (String) -> WeekdayItemView
    
    init(
        weekDayTitles: [String]? = nil,
        locale: Locale,
        @ViewBuilder weekdayItemViewContent: @escaping (String) -> WeekdayItemView
    ) {
        if let weekDayTitles {
            self.weekDayTitles = weekDayTitles
        } else {
            let formatter = DateFormatter()
            formatter.locale = locale
            self.weekDayTitles = formatter.shortWeekdaySymbols
        }
        self.weekdayItemViewContent = weekdayItemViewContent
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            ForEach(weekDayTitles, id: \.self) { title in
                weekdayItemViewContent(title)
            }
        }
    }
}
