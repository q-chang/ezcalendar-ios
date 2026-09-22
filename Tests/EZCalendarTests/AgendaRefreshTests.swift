//
//  AgendaRefreshTests.swift
//  EZCalendarTests
//
//  Created by wisanu on 22/9/2569 BE.
//

import SwiftUI
import Testing
@testable import EZCalendar

/// The refresh view is SwiftUI, but its direction lock and lifecycle state live
/// in the agenda view model so they can be verified without synthesising a drag
/// in a simulator.
@Suite("Agenda pull-to-refresh")
@MainActor
struct AgendaRefreshTests {

    private func makeViewModel() -> EZCalendarAgendaViewModel {
        EZCalendarAgendaViewModel(
            calendar: Fixture.gregorian,
            mode: .monthly,
            selection: Fixture.date(2030, 7, 10)
        )
    }

    private func configuration(
        minimumDisplayDuration: TimeInterval = 0,
        onRefresh: @escaping @MainActor () async -> Void = {}
    ) -> AgendaRefreshConfiguration {
        AgendaRefreshConfiguration(
            threshold: 72,
            minimumDisplayDuration: minimumDisplayDuration,
            indicator: { _ in AnyView(EmptyView()) },
            onRefresh: onRefresh
        )
    }

    @Test("A horizontal swipe never arms refresh")
    func horizontalSwipeIsIgnored() {
        let viewModel = makeViewModel()

        viewModel.refreshDragChanged(
            translation: CGSize(width: 80, height: 12),
            threshold: 72
        )

        #expect(viewModel.refreshContext.phase == .idle)
        #expect(viewModel.refreshContext.progress == 0)
    }

    @Test("A downward vertical pull reports progress and arms at the threshold")
    func verticalPullTracksProgress() {
        let viewModel = makeViewModel()

        viewModel.refreshDragChanged(
            translation: CGSize(width: 4, height: 36),
            threshold: 72
        )

        #expect(viewModel.refreshContext.phase == .pulling)
        #expect(viewModel.refreshContext.progress == 0.5)

        viewModel.refreshDragChanged(
            translation: CGSize(width: 4, height: 90),
            threshold: 72
        )

        #expect(viewModel.refreshContext.phase == .armed)
        #expect(viewModel.refreshContext.progress == 1)
    }

    @Test("Releasing before the threshold returns to idle without notifying the caller")
    func shortPullDoesNotRefresh() async {
        let viewModel = makeViewModel()
        var refreshCount = 0

        viewModel.refreshDragChanged(
            translation: CGSize(width: 0, height: 60),
            threshold: 72
        )
        viewModel.refreshDragEnded(
            configuration: configuration {
                refreshCount += 1
            }
        )

        try? await Task.sleep(nanoseconds: 10_000_000)

        #expect(refreshCount == 0)
        #expect(viewModel.refreshContext.phase == .idle)
    }

    @Test("An armed release notifies the caller and remains visible for its minimum duration")
    func armedPullRefreshesAndHonoursMinimumDuration() async {
        let viewModel = makeViewModel()
        var refreshCount = 0

        viewModel.refreshDragChanged(
            translation: CGSize(width: 0, height: 72),
            threshold: 72
        )
        viewModel.refreshDragEnded(
            configuration: configuration(minimumDisplayDuration: 0.05) {
                refreshCount += 1
            }
        )

        await Task.yield()
        #expect(refreshCount == 1)
        #expect(viewModel.refreshContext.phase == .refreshing)

        try? await Task.sleep(nanoseconds: 70_000_000)
        #expect(viewModel.refreshContext.phase == .idle)
    }

    @Test("A refresh cannot be armed again while the caller action is running")
    func refreshDoesNotDuplicate() async {
        let viewModel = makeViewModel()
        var refreshCount = 0

        viewModel.refreshDragChanged(
            translation: CGSize(width: 0, height: 72),
            threshold: 72
        )
        viewModel.refreshDragEnded(
            configuration: configuration(minimumDisplayDuration: 0.08) {
                refreshCount += 1
            }
        )

        viewModel.refreshDragChanged(
            translation: CGSize(width: 0, height: 100),
            threshold: 72
        )
        viewModel.refreshDragEnded(configuration: configuration())

        try? await Task.sleep(nanoseconds: 20_000_000)
        #expect(refreshCount == 1)
    }
}
