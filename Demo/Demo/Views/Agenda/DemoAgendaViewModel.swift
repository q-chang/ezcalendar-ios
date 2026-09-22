//
//  DemoAgendaViewModel.swift
//  Demo
//
//  Created by wisanu on 27/8/2569 BE.
//

import Foundation
import EZCalendar

/// A caller-owned event type. `EZCalendarAgendaView` is generic over this — the
/// library never sees anything but `id` and whatever the `eventDate` closure
/// returns, which is why `title`, `startAt` and `endAt` can be anything at all.
struct DemoJob: Identifiable, Hashable {
    let id: UUID
    let title: String
    let startAt: Date
    let endAt: Date
}

/// Backing data for `DemoAgendaView`: a paged range of months, plus a
/// deterministic spread of jobs across it.
@MainActor
final class DemoAgendaViewModel: ObservableObject {

    let calendar: Calendar

    @Published var calendarMonths: [CalendarMonth] = []
    @Published var jobs: [DemoJob] = []

    @Published var mode: EZCalendarAgendaMode = .monthly
    @Published var selectedDate: Date

    private let startDate: Date
    private let endDate: Date

    init(withCalendar calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.calendar = calendar

        let today = calendar.startOfDay(for: Date())
        self.selectedDate = today

        // Three months either side of today: enough to page through, small
        // enough that the whole agenda list stays quick to rebuild.
        self.startDate = calendar.date(byAdding: .month, value: -6, to: today) ?? today
        self.endDate = calendar.date(byAdding: .month, value: 12, to: today) ?? today

        self.calendarMonths = EZCalendarHelper.generateCalendarMonths(
            startDate: startDate,
            endDate: endDate,
            calendar: calendar
        )

        self.jobs = Self.makeJobs(from: startDate, to: endDate, calendar: calendar)
    }

    /// Formats a day for the sticky list headers.
    func headerTitle(for date: Date) -> String {
        date.toString(dateFormat: "EEEE, d MMMM yyyy", locale: calendar.locale ?? .current)
    }

    /// Formats the month or week title above the calendar.
    func pageTitle(for date: Date) -> String {
        switch mode {
        case .monthly:
            return date.toString(dateFormat: "MMMM yyyy", locale: calendar.locale ?? .current)
        case .weekly:
            let end = calendar.date(byAdding: .day, value: 6, to: date) ?? date
            let from = date.toString(dateFormat: "d MMM", locale: calendar.locale ?? .current)
            let to = end.toString(dateFormat: "d MMM yyyy", locale: calendar.locale ?? .current)
            return "\(from) – \(to)"
        }
    }

    func timeRange(for job: DemoJob) -> String {
        let locale = calendar.locale ?? .current
        return "\(job.startAt.toString(dateFormat: "HH:mm", locale: locale))\n\(job.endAt.toString(dateFormat: "HH:mm", locale: locale))"
    }

    func dayNumber(_ date: Date?) -> String {
        guard let date else { return "" }
        return "\(calendar.component(.day, from: date))"
    }

    // MARK: - Sample data

    /// A stable, boring spread: some days busy, some days with a single job,
    /// and roughly every third day deliberately empty so the empty-state
    /// sections — and the sync onto them — can be exercised.
    private static func makeJobs(from start: Date, to end: Date, calendar: Calendar) -> [DemoJob] {
        let titles = [
            "Install wall-type A/C",
            "Site survey",
            "Warranty check-up",
            "Deliver 18,000 BTU unit",
            "Quote follow-up"
        ]

        var jobs: [DemoJob] = []
        var cursor = calendar.startOfDay(for: start)
        var seed = 0

        while cursor <= end {
            let dayOfMonth = calendar.component(.day, from: cursor)

            // 0, 1 or 2 jobs, keyed off the day number so a given date always
            // looks the same between launches.
            let count = [1, 2, 0, 1, 3, 0, 2][dayOfMonth % 7]

            for slot in 0..<count {
                let hour = 9 + slot * 3
                let startAt = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: cursor) ?? cursor
                let endAt = calendar.date(byAdding: .hour, value: 2, to: startAt) ?? startAt

                jobs.append(
                    DemoJob(
                        id: UUID(),
                        title: titles[seed % titles.count],
                        startAt: startAt,
                        endAt: endAt
                    )
                )
                seed += 1
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return jobs
    }
}
