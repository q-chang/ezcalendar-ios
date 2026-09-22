//
//  EZCalendarAgendaRefresh.swift
//  EZCalendar
//
//  Created by wisanu on 22/9/2569 BE.
//

import Foundation
import SwiftUI

/**
 # 🔄 Agenda pull-to-refresh

 `EZCalendarAgendaView` can recognise a downward pull that begins in its
 calendar area — title, weekday header, and month/week grid — without competing
 with horizontal month paging or the agenda list's scroll view.

 The library owns the gesture and refresh lifecycle, but never draws an
 indicator. Its indicator slot is immediately above `titleViewContent`, so
 your view pushes the title and calendar down instead of floating over the
 month grid. Supply the visual treatment and asynchronous work through
 `.pullToRefresh(minimumDisplayDuration:indicator:onRefresh:)`:

 ```swift
 .pullToRefresh(
     minimumDisplayDuration: 1.2,
     indicator: { context in
         RefreshIndicator(context: context)
     },
     onRefresh: {
         await viewModel.reload()
     }
 )
 ```

 The closure is the notification that a refresh was committed. It should return
 only after the caller's refresh work is complete; the library keeps the
 indicator visible for the longer of that work and the configured minimum.
 */
public enum EZCalendarAgendaRefreshPhase: Equatable, Sendable {
    /// No pull gesture or refresh is active.
    case idle

    /// A downward, vertical pull is underway but has not reached the threshold.
    case pulling

    /// The pull passed the threshold and will refresh if released.
    case armed

    /// The caller's asynchronous refresh closure is running.
    case refreshing
}

/// The state passed to an agenda pull-to-refresh indicator.
///
/// This is received in the `indicator` closure and is intentionally not
/// constructed by callers. `progress` is clamped to `0...1`; it is `1` while
/// armed and while the refresh action is running.
public struct EZCalendarAgendaRefreshContext: Equatable, Sendable {
    /// The refresh lifecycle's current phase.
    public let phase: EZCalendarAgendaRefreshPhase

    /// Pull distance expressed as a fraction of the refresh threshold.
    public let progress: Double

    init(phase: EZCalendarAgendaRefreshPhase, progress: Double) {
        self.phase = phase
        self.progress = progress
    }
}

/// Type-erased refresh configuration retained by `EZCalendarAgendaView`.
///
/// The public modifier accepts any `View` for the indicator. Type erasure keeps
/// that opt-in from expanding the agenda's already substantial generic surface.
struct AgendaRefreshConfiguration {
    let threshold: Double
    let minimumDisplayDuration: TimeInterval
    let indicator: (EZCalendarAgendaRefreshContext) -> AnyView
    let onRefresh: @MainActor () async -> Void
}
