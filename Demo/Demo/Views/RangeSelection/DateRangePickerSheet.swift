//
//  DateRangePickerSheet.swift
//  Demo
//
//  Created by wisanu on 11/9/2569 BE.
//

import SwiftUI
import EZCalendar

/// The bottom sheet from the range-selection mock: title, month pager, summary
/// line and a confirm button. It edits a draft; ✕ throws the draft away.
struct DateRangePickerSheet: View {

    @ObservedObject var viewModel: DemoRangeSelectionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft: DateRangeSelection
    @State private var currentMonth: Date
    @State private var sheetHeight: CGFloat = 600

    private let weekdayHeight: CGFloat = 28
    private let rowHeight: CGFloat = 44
    private let markSize: CGFloat = 38

    init(viewModel: DemoRangeSelectionViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _draft = State(initialValue: viewModel.selection)
        _currentMonth = State(initialValue: viewModel.initialMonth(for: viewModel.selection))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            VStack(spacing: 0) {
                monthBar

                pager
                    .padding(.top, 4)

                Text(viewModel.summary(of: draft))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)

                confirmButton
                    .padding(.top, 12)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            sheetHeight = height
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(sheetHeight)])
        .presentationBackground(Color(.systemBackground))
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Text("วันที่")
                .font(.title2.bold())

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
            }
        }
        .foregroundStyle(RangePalette.navy)
        .padding(16)
    }

    private var monthBar: some View {
        HStack {
            Button {
                page(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(viewModel.month(currentMonth, offsetBy: -1) == nil)

            Spacer()

            Text(viewModel.format(currentMonth, dateFormat: "MMMM yyyy"))
                .font(.headline)
                .foregroundStyle(RangePalette.navy)

            Spacer()

            Button {
                page(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(viewModel.month(currentMonth, offsetBy: 1) == nil)
        }
        .tint(RangePalette.navy)
        .frame(height: 48)
    }

    private var pager: some View {
        EZCalendarHorizontalPagingView(
            withCalendar: viewModel.calendar,
            weekDayTitles: viewModel.weekdayTitles,
            currentMonth: $currentMonth,
            calendarMonths: $viewModel.calendarMonths
        ) { weekdayTitle in
            Text(weekdayTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: weekdayHeight)
        } dayItemViewContent: { calendarDay in
            dayCell(calendarDay)
        }
        // Months have 4–6 rows. Reserving six keeps the sheet from resizing
        // every time the user pages.
        .frame(height: weekdayHeight + rowHeight * 6 + 5, alignment: .top)
    }

    private var confirmButton: some View {
        Button {
            viewModel.selection = draft
            dismiss()
        } label: {
            Text("เลือกวัน")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    draft.isComplete ? RangePalette.navy : Color.gray.opacity(0.4),
                    in: RoundedRectangle(cornerRadius: 10)
                )
        }
        .disabled(!draft.isComplete)
    }

    // MARK: - Day cell

    @ViewBuilder
    private func dayCell(_ calendarDay: CalendarDay) -> some View {
        if calendarDay.isCurrentMonth, let date = calendarDay.date {
            let isEndpoint = draft.isEndpoint(date, calendar: viewModel.calendar)
            let isInRange = draft.isInRange(date, calendar: viewModel.calendar)

            Button {
                draft.select(date, calendar: viewModel.calendar)
            } label: {
                Text("\(viewModel.calendar.component(.day, from: date))")
                    .foregroundStyle(isEndpoint ? Color.white : Color.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: rowHeight)
                    .background {
                        ZStack {
                            if isInRange {
                                // The grid leaves 1pt between columns. Reaching
                                // 0.5pt into it from each side makes the band
                                // read as one continuous strip across the week.
                                RangePalette.band
                                    .frame(height: markSize)
                                    .padding(.horizontal, -0.5)
                            }
                            if isEndpoint {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(RangePalette.accent)
                                    .frame(width: markSize, height: markSize)
                            }
                        }
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            // Padding days render blank, as in the mock.
            Color.clear
                .frame(height: rowHeight)
        }
    }

    private func page(by value: Int) {
        guard let month = viewModel.month(currentMonth, offsetBy: value) else {
            return
        }
        currentMonth = month
    }
}

enum RangePalette {
    static let navy = Color(red: 0.12, green: 0.24, blue: 0.40)
    static let accent = Color(red: 0.23, green: 0.36, blue: 0.84)
    static let band = Color(red: 0.89, green: 0.92, blue: 0.98)
}
