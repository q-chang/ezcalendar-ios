//
//  DemoRangeSelectionView.swift
//  Demo
//
//  Created by wisanu on 11/9/2569 BE.
//

import SwiftUI
import EZCalendar

/**
 # 📅 Demo: Range Selection (Start Date → End Date)

 A form field that opens a bottom-sheet picker built on
 `EZCalendarHorizontalPagingView`. The library has no selection state; the
 range lives in `DateRangeSelection`, and every mark on the grid comes from the
 `dayItemViewContent` closure.

 ## Tap rules

 1. The first tap sets **Start Date**, the second sets **End Date**.
 2. A second tap *before* Start doesn't make a backwards range: that day
    becomes the new Start and End stays empty.
 3. A second tap *on* Start makes a one-day range (Start = End).
 4. Once both are set, the next tap clears them and becomes the new Start.

 ## Look

 * **Start / End** — a filled blue square.
 * **Days between** — a light band that runs unbroken across each week, and
   across pages when the range spans months.
 * **Padding days** — blank, so each page shows only its own month.

 **เลือกวัน** is enabled once both ends are set and copies the draft back to the
 form. **✕** discards the draft.
 */
struct DemoRangeSelectionView: View {

    @StateObject var viewModel: DemoRangeSelectionViewModel
    @State private var isPickerPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                Text("วันที่")
                Text("*")
                    .foregroundStyle(.red)
            }
            .font(.subheadline)

            Button {
                isPickerPresented = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundStyle(RangePalette.navy)

                    Text(fieldTitle)
                        .foregroundStyle(viewModel.selection.isComplete ? Color.primary : Color.secondary)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .frame(height: 48)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.separator))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(16)
        .navigationTitle("Range Selection")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isPickerPresented) {
            DateRangePickerSheet(viewModel: viewModel)
        }
    }

    private var fieldTitle: String {
        guard let startDate = viewModel.selection.startDate,
              let endDate = viewModel.selection.endDate else {
            return "เลือกวันที่"
        }
        return "\(viewModel.format(startDate)) - \(viewModel.format(endDate))"
    }
}

#Preview {
    DemoRangeSelectionView(
        viewModel: DemoRangeSelectionViewModel(
            withCalendar: {
                var calendar: Calendar = .init(identifier: .buddhist)
                calendar.locale = Locale(identifier: "th-TH")
                return calendar
            }()
        )
    )
}
