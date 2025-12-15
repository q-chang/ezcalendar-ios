//
//  CalendarHorizontalPagingView.swift
//  Demo
//
//  Created by Wisanu Paunglumjeak on 12/1/2568 BE.
//

import SwiftUI
import EZCalendar

struct CalendarHorizontalPagingView: View {
    @StateObject var viewModel: CalendarHorizontalPaggingViewModel
    
    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    
                    HStack {
                        Button("Previous") {
                            guard let date = viewModel.currentMonth.addingComponentsOfDate(month: -1),
                                  viewModel.isDateGreaterThanOrEqualStartDate(date) else {
                                return
                            }
                            viewModel.currentMonth = date
                        }
                        .disabled(
                            !viewModel.isDateGreaterThanOrEqualStartDate(
                                viewModel.currentMonth.addingComponentsOfDate(month: -1)!
                            )
                        )
                        .frame(width: 100, alignment: .leading)
                        
                        Spacer()
                        
                        Text(viewModel.currentMonth.toString(dateFormat: "MMMM yyyy", locale: viewModel.locale))
                        
                        Spacer()
                        
                        Button("Next") {
                            guard let date = viewModel.currentMonth.addingComponentsOfDate(month: 1),
                                  viewModel.isDateLessThanOrEqualEndDate(date) else {
                                return
                            }
                            viewModel.currentMonth = date
                        }
                        .disabled(
                            !viewModel.isDateLessThanOrEqualEndDate(
                                viewModel.currentMonth.addingComponentsOfDate(month: 1)!
                            )
                        )
                        .frame(width: 100, alignment: .trailing)
                    }
                    .bold()
                    .padding(16)
                    
                    EZCalendarHorizontalPagingView(
                        withCalendar: viewModel.calendar,
                        locale: viewModel.locale,
                        currentMonth: $viewModel.currentMonth,
                        calendarMonths: $viewModel.calendarMonths
                    ) { weekdayTitle in
                        Text(weekdayTitle)
                            .foregroundStyle(Color.red)
                            .bold()
                            .frame(
                                width: proxy.size.width / 7,
                                height: 24
                            )
                    } dayItemViewContent: { calendarDay in
                        
                        Text(" \(calendarDay.date?.get(.day) ?? 0) ")
                            .foregroundStyle(
                                calendarDay.isCurrentMonth
                                ? Color.black
                                : Color.gray
                            )
                            .padding(4)
                            .background(calendarDay.hasEvents ? Color.blue : Color.clear)
                            .frame(
                                width: proxy.size.width / 7,
                                height: proxy.size.width / 7
                            )
                    }
                    .weekdayScrollable(true)
                }
            }
        }
        .onChange(of: viewModel.currentMonth) { _, monthDate in
            viewModel.updateEvents(monthDate)
        }
    }
}

#Preview {
    CalendarHorizontalPagingView(
        viewModel: CalendarHorizontalPaggingViewModel(
            withCalendar: .init(identifier: .buddhist),
            locale: Locale(identifier: "th-TH")
        )
    )
}
