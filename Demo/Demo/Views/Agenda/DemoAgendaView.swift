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
 * **Pull to refresh** — a caller-styled indicator above the title bar and a
   simulated asynchronous reload.

 The calendar switches between month and week only via the grab handle, the
 Collapse/Expand button, or tapping a day. Scrolling the event list just scrolls
 it.
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
            .pullToRefresh(
                minimumDisplayDuration: 1.2,
                indicator: refreshIndicator,
                onRefresh: {
                    await viewModel.refreshAgenda()
                }
            )
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Agenda")
        .navigationBarTitleDisplayMode(.inline)
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

    private func refreshIndicator(_ context: EZCalendarAgendaRefreshContext) -> some View {
        HStack(spacing: 8) {
            if context.phase == .refreshing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: context.phase == .armed ? "arrow.down.circle.fill" : "arrow.down.circle")
                    .symbolRenderingMode(.hierarchical)
            }

            Text(refreshMessage(for: context.phase))
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: Capsule())
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        // The library puts this slot directly before `titleViewContent`.
        // Let the pull distance reveal it gradually, while a committed refresh
        // gives the spinner its complete natural height.
        .frame(height: refreshIndicatorHeight(for: context), alignment: .bottom)
        .clipped()
        .accessibilityElement(children: .combine)
    }

    private func refreshIndicatorHeight(for context: EZCalendarAgendaRefreshContext) -> CGFloat {
        let fullHeight: CGFloat = 48
        return context.phase == .refreshing
            ? fullHeight
            : fullHeight * context.progress
    }

    private func refreshMessage(for phase: EZCalendarAgendaRefreshPhase) -> String {
        switch phase {
        case .idle, .pulling:
            return "Pull to refresh"
        case .armed:
            return "Release to refresh"
        case .refreshing:
            return "Refreshing agenda…"
        }
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
            .padding(.vertical, 14)
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
