//
//  DemoAgendaView.swift
//  Demo
//
//  Created by wisanu on 27/8/2569 BE.
//

import SwiftUI
import EZCalendar

/**
 # 📆 Demo: `EZCalendarAgendaView`

 A deliberately plain integration, built to make the *behaviour* legible rather
 than to look like the mockups:

 * **Day cell** — the date number, a filled circle when selected, a ring when it
   is today, and a dot when the day has jobs.
 * **Event card** — title and time range, nothing more.
 * **Sticky header** — the date, plus "No jobs scheduled" on an empty day.
 * **Title bar** — `‹ July 2026 ›`, driven by the component's own paging closures.

 The strip under the title bar reports the last few state changes, so the
 two-way sync can be verified on screen: tap a date and watch the list scroll,
 scroll the list and watch the selection follow.
 */
struct DemoAgendaView: View {

    @StateObject var viewModel: DemoAgendaViewModel

    var body: some View {
        VStack(spacing: 0) {
            EZCalendarAgendaView(
                withCalendar: viewModel.calendar,
                weekDayTitles: viewModel.calendar.shortWeekdaySymbols,
                mode: $viewModel.mode,
                selectedDate: $viewModel.selectedDate,
                calendarMonths: $viewModel.calendarMonths,
                events: viewModel.jobs,
                eventDate: { $0.startAt },
                titleViewContent: titleBar,
                weekdayItemViewContent: weekdayCell,
                dayItemViewContent: dayCell,
                listHeaderViewContent: sectionHeader,
                eventItemViewContent: eventCard,
                emptyDayViewContent: emptyDay,
                handleViewContent: grabHandle
            )
            .gridLineColor(Color(.separator).opacity(0.35))
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Agenda")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.selectedDate) { _, date in
            viewModel.note("selected \(viewModel.headerTitle(for: date))")
        }
        .onChange(of: viewModel.mode) { _, mode in
            viewModel.note("mode → .\(mode.rawValue)")
        }
    }

    // MARK: - Calendar slots

    @ViewBuilder
    private func titleBar(_ context: EZCalendarAgendaTitleContext) -> some View {
        VStack(spacing: 6) {
            HStack {
                Button(action: context.pageBackward) {
                    Image(systemName: "chevron.left")
                }

                Spacer()

                Text(viewModel.pageTitle(for: context.date))
                    .font(.headline)

                Spacer()

                Button(action: context.pageForward) {
                    Image(systemName: "chevron.right")
                }
            }

            HStack(spacing: 12) {
                // Proves the external Binding<Mode>: flipping this drives the
                // same transition the drag gesture does.
                Button(context.mode == .monthly ? "Collapse" : "Expand") {
                    viewModel.mode = context.mode == .monthly ? .weekly : .monthly
                }
                .font(.caption)

                Button("Today") {
                    viewModel.selectedDate = viewModel.calendar.startOfDay(for: Date())
                }
                .font(.caption)

                Spacer()

                Text(".\(context.mode.rawValue)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            // A tiny on-screen log, so the sync can be checked without Xcode.
            VStack(alignment: .leading, spacing: 1) {
                ForEach(viewModel.log, id: \.self) { line in
                    Text(line)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 44, alignment: .top)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    private func weekdayCell(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .background(Color(.systemBackground))
    }

    private func dayCell(_ context: EZCalendarDayContext) -> some View {
        VStack(spacing: 3) {
            Text(viewModel.dayNumber(context.date))
                .font(.system(size: 15))
                .foregroundStyle(dayForeground(context))
                .frame(width: 30, height: 30)
                .background {
                    if context.isSelected {
                        Circle().fill(Color.accentColor)
                    } else if context.isToday {
                        Circle().stroke(Color.accentColor, lineWidth: 1)
                    }
                }

            // Note: `context.hasEvents`, not `context.day.hasEvents` — the
            // agenda's own same-day match, which also works on padding days.
            Circle()
                .fill(Color.accentColor)
                .frame(width: 5, height: 5)
                .opacity(context.hasEvents ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(Color(.systemBackground))
    }

    private func dayForeground(_ context: EZCalendarDayContext) -> Color {
        if context.isSelected { return .white }
        return context.isCurrentMonth ? .primary : .secondary.opacity(0.6)
    }

    // MARK: - List slots

    private func grabHandle() -> some View {
        Capsule()
            .fill(Color.secondary.opacity(0.4))
            .frame(width: 40, height: 5)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))
    }

    private func sectionHeader(_ section: EZCalendarAgendaSection<DemoJob>) -> some View {
        HStack {
            Text(viewModel.headerTitle(for: section.date))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(section.isEmpty ? .secondary : .primary)

            Spacer()

            if !section.isEmpty {
                Text("\(section.events.count)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Opaque, so rows scroll *under* the pinned header rather than through it.
        .background(Color(.systemGroupedBackground))
    }

    private func eventCard(_ job: DemoJob) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(viewModel.timeRange(for: job))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .leading)

            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(job.title)
                    .font(.subheadline)
                Text("Bang Sue, Bangkok")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func emptyDay(_ date: Date) -> some View {
        Text("No jobs scheduled")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
    }
}

#Preview {
    NavigationStack {
        DemoAgendaView(viewModel: DemoAgendaViewModel())
    }
}
