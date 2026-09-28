//
//  AgendaTableView.swift
//  EZCalendar
//
//  Created by wisanu on 28/9/2569 BE.
//

#if os(iOS)
import SwiftUI
import UIKit
import OSLog

/// Diagnostic logger for `AgendaTableView`'s own positioning internals — same
/// subsystem/category as `EZCalendarAgendaViewModel.syncLogger` so a single
/// `AgendaSync` console filter shows both sides of a scroll transaction
/// (the view model's intent and the table view's actual verification loop).
private let agendaTableDiagnosticsLogger = Logger(
    subsystem: "com.ezcalendar",
    category: "AgendaSync"
)

/// The exact-positioning, reliably-sticky replacement for both the
/// SwiftUI-native list and the `UICollectionView` bridge that preceded it.
///
/// ## Why this exists
///
/// Two SwiftUI-native positioning APIs (`ScrollViewReader.scrollTo`,
/// `scrollPosition(id:anchor:)`) landed on the wrong section when jumping to
/// a selected day — confirmed by device repro, not suspicion. Moving to
/// `UICollectionView` fixed that, but its sticky header — built by hand from
/// `NSCollectionLayoutBoundarySupplementaryItem` with `pinToVisibleBounds`,
/// then rebuilt again on `NSCollectionLayoutSection.list(using:)`, Apple's
/// own most-exercised sticky-header layout — never stuck on device either
/// attempt. Two different, correctly-configured `UICollectionView`
/// mechanisms both failing the same way points at something about how this
/// package hosts `UICollectionView`, not at either layout's configuration.
///
/// `UITableView` sticks section headers **by default**, with no pinning
/// property to configure at all — that default behavior has been part of
/// `.plain`-style table views since iOS 2. It doesn't remove the
/// possibility of another mistake in this file, but it removes an entire
/// category of "configured wrong" that has now failed twice.
///
/// SwiftUI still owns every pixel that renders: cells and headers are the
/// caller's own SwiftUI views, hosted through `UIHostingConfiguration`. This
/// type owns only identity, layout and positioning.
private enum AgendaTableViewIdentifiers {
    /// Not nested inside `AgendaTableView` itself — Swift does not support
    /// static stored properties on a generic type.
    static let cellReuseIdentifier = "AgendaTableView.cell"
    static let headerReuseIdentifier = "AgendaTableView.header"
}

struct AgendaTableView<
    Event: Identifiable,
    ListHeaderView: View,
    EventItemView: View,
    EmptyDayView: View
>: UIViewRepresentable where Event.ID: Sendable {

    @Binding var scrollRequest: AgendaScrollRequest?

    let sections: [EZCalendarAgendaSection<Event>]

    let sectionAppeared: (String) -> Void
    let scrollCommandReceived: (AgendaScrollRequest) -> Void
    let visibleSectionChanged: (String?) -> Void
    let listPositionSettled: () -> Void
    let listPositionFailed: () -> Void
    let contentRevision: Int

    let listHeaderViewContent: (EZCalendarAgendaSection<Event>) -> ListHeaderView
    let eventItemViewContent: (Event) -> EventItemView
    let emptyDayViewContent: (Date) -> EmptyDayView

    func makeUIView(context: Context) -> UITableView {
        let tableView = TrailingInsetTableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.rowHeight = UITableView.automaticDimension
        // A flat `60` was the real cause of the cold-open landing far short
        // of today (see `verify-attempt` log lines: `landedIndex` well below
        // `targetIndex`, every time). One row is a full event card — title,
        // optional subtitle, location line, padding — realistically
        // 120-180pt, not 60. UITableView computes `scrollToRow`'s target
        // offset from the *cumulative estimated* height of every skipped
        // row, and never corrects that estimate for rows that stay
        // off-screen; a low flat estimate is a large, systematic, one-
        // directional undershoot for any jump of more than a few days, not
        // random noise the bounded verify/retry loop below can fully absorb.
        // 140 is a coarse, tunable heuristic — closer to real content than
        // 60, not a claim of exact rendered height (the package cannot see
        // inside the caller's `Event`-driven content by design).
        tableView.estimatedRowHeight = 140
        tableView.sectionHeaderTopPadding = 0
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.estimatedSectionHeaderHeight = 44
        // `UIHostingConfiguration.margins(.all, 0)` on each cell/header only
        // zeroes that configuration's own margins — `UITableView` still adds
        // its own leading/trailing inset on top unless this is disabled, and
        // widens it further to follow the "readable width" on larger
        // screens.
        tableView.cellLayoutMarginsFollowReadableWidth = false
        tableView.layoutMargins = .zero
        tableView.separatorInset = .zero
        tableView.register(
            UITableViewCell.self,
            forCellReuseIdentifier: AgendaTableViewIdentifiers.cellReuseIdentifier
        )
        tableView.register(
            UITableViewHeaderFooterView.self,
            forHeaderFooterViewReuseIdentifier: AgendaTableViewIdentifiers.headerReuseIdentifier
        )
        tableView.delegate = context.coordinator
        context.coordinator.attach(to: tableView)
        return tableView
    }

    /// Keeps one screen height of empty trailing space below the last
    /// section — the UIKit equivalent of the SwiftUI-native implementation's
    /// trailing `Color.clear` row. Without it, `scrollToRow` cannot bring a
    /// section near the end of the range flush to the top: `UIScrollView`
    /// clamps the offset once content runs out, so the target would land
    /// short through no fault of the positioning call itself.
    private final class TrailingInsetTableView: UITableView {
        var didLayout: (() -> Void)?

        override func layoutSubviews() {
            super.layoutSubviews()
            let desired = bounds.height
            if abs(contentInset.bottom - desired) > 1 {
                contentInset.bottom = desired
            }
            didLayout?()
        }
    }

    func updateUIView(_ tableView: UITableView, context: Context) {
        let coordinator = context.coordinator
        coordinator.listHeaderViewContent = listHeaderViewContent
        coordinator.eventItemViewContent = eventItemViewContent
        coordinator.emptyDayViewContent = emptyDayViewContent
        coordinator.sectionAppeared = sectionAppeared
        coordinator.visibleSectionChangedHandler = visibleSectionChanged

        coordinator.applySections(sections, contentRevision: contentRevision)
        coordinator.handleScrollRequest(
            scrollRequest,
            scrollCommandReceived: scrollCommandReceived,
            listPositionSettled: listPositionSettled,
            listPositionFailed: listPositionFailed
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Row identity

    /// One row per event, or a single sentinel row for an empty day — mirrors
    /// `EZCalendarAgendaSection.isEmpty` picking `emptyDayViewContent`.
    ///
    /// `.empty` carries the day id so it is unique *per section*.
    /// `NSDiffableDataSourceSnapshot` item identifiers must be unique across
    /// the whole snapshot, not just within a section — a bare `.empty` case
    /// with no associated value already caused exactly this failure once in
    /// the `UICollectionView` bridge this replaced: every empty day silently
    /// collided on the same identifier, and every empty section after the
    /// first ended up with zero items, crashing the moment `scrollToItem`
    /// targeted one.
    enum RowID: Hashable, Sendable {
        case event(Event.ID)
        case empty(String)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITableViewDelegate {

        var listHeaderViewContent: ((EZCalendarAgendaSection<Event>) -> ListHeaderView)?
        var eventItemViewContent: ((Event) -> EventItemView)?
        var emptyDayViewContent: ((Date) -> EmptyDayView)?
        var sectionAppeared: ((String) -> Void)?
        var visibleSectionChangedHandler: ((String?) -> Void)?

        private(set) var sections: [EZCalendarAgendaSection<Event>] = []
        private var sectionFingerprint: Int?
        private var appliedContentRevision: Int?

        private weak var tableView: UITableView?
        private var dataSource: UITableViewDiffableDataSource<String, RowID>?

        private var lastHandledScrollToken: UUID?
        private var lastReportedSectionID: String?
        private var isProgrammaticScroll = false
        private var pendingScrollRequest: AgendaScrollRequest?
        private var pendingScrollCommandReceived: ((AgendaScrollRequest) -> Void)?
        private var pendingListPositionSettled: (() -> Void)?
        private var pendingListPositionFailed: (() -> Void)?
        private var pendingScrollPhase: PendingScrollPhase = .awaitingLayout
        private var pendingScrollVerificationAttempts = 0
        private var hasAcknowledgedPendingScrollCommand = false
        private var hasAppliedFinalScrollRecovery = false
        private var isPendingScrollScheduled = false
        private var hasRevealedInitialContent = false

        private enum PendingScrollPhase {
            case awaitingLayout
            case verifying
        }

        // 4 was not enough: device logs showed the loop exhausting and
        // falling through to `applyFinalScrollRecovery` — itself also
        // `rect(forSection:)`/estimate-based — before nearby rows had been
        // measured enough times to converge, landing on a different wrong
        // day each run (10th, then 26th, then 16th) depending on exactly
        // which rows happened to get measured within 4 passes. Each attempt
        // is cheap (`reloadData()` + `scrollToRow`, table is hidden via
        // `isHidden` the whole time — see `attach(to:)`), so a much larger
        // bound costs latency, not correctness, and only the cold-open
        // transaction (a potentially long jump from wherever the table
        // defaults to) is likely to ever need many of them.
        private let maximumScrollVerificationAttempts = 20

        func attach(to tableView: UITableView) {
            self.tableView = tableView
            self.dataSource = makeDataSource(for: tableView)
            (tableView as? TrailingInsetTableView)?.didLayout = { [weak self] in
                self?.schedulePendingScrollAfterLayout()
            }

            // Cold-open fix (2026-09-28): a freshly created `UITableView` is on
            // screen the instant SwiftUI inserts it, at contentOffset (0, 0) —
            // i.e. showing whatever section happens to be first in the range,
            // not today. Positioning is not synchronous with mount: the first
            // `scrollToRow` has to wait for `handleScrollRequest` ->
            // `schedulePendingScrollAfterLayout` -> a `DispatchQueue.main.async`
            // hop gated on `tableView.window != nil` and non-zero bounds, and
            // this device repro measured ~800ms and two full request/verify
            // transactions before the first `position-arrived`. The removed
            // alpha-fade (see AGENDA_CALENDAR_HANDOFF.md, "no fade either")
            // was covering exactly this window before it was taken out on the
            // assumption that `scrollToRow` positions synchronously — that
            // assumption is false for the very first frame specifically.
            //
            // This hides only the initial default-position frame(s), not any
            // subsequent tap-driven jump: `revealInitialContentIfNeeded()`
            // fires at most once per `Coordinator`, from whichever completion
            // path finishes first (`completePendingScroll` or the clean-failure
            // `failPendingScroll`), and every request after that already runs
            // with the table view visible.
            //
            // `alpha = 0`, not `isHidden = true`: device logs showed the
            // scroll positioning land byte-exact on the very first verify
            // attempt (`landed` == `target`, `contentOffsetY` matching
            // `targetRectMinY` to five decimals) while the screen still
            // showed a stale day's header — correct geometry, wrong pixels.
            // `isHidden` is documented to let a view's subtree skip/coalesce
            // layout and rendering work; with several `reloadData()` +
            // `UIHostingConfiguration` reconfigurations happening on the
            // header/cells while hidden, unhiding could paint whichever
            // reconfiguration happened to be the one SwiftUI last actually
            // rendered, not necessarily the final, correct one. `alpha = 0`
            // keeps the view fully live for rendering throughout — only its
            // opacity changes, so there's nothing to fall stale.
            tableView.alpha = 0
            // Defensive-only fallback, not the primary mechanism: if some
            // future change ever causes `selectionChanged()` to skip issuing
            // a scroll request on a fresh mount (e.g. because the view model
            // already believes `visibleListSectionID` matches the target),
            // neither completion path above would ever fire and the list
            // would stay invisible forever. One bounded, one-shot timer well
            // past the slowest observed real completion (~800ms) prevents
            // that failure mode without masking it as a false position — it
            // only ever reveals, never reports or corrects a position.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.revealInitialContentIfNeeded()
            }
        }

        private func revealInitialContentIfNeeded() {
            guard !hasRevealedInitialContent else { return }
            hasRevealedInitialContent = true
            tableView?.alpha = 1
        }

        func section(at index: Int) -> EZCalendarAgendaSection<Event>? {
            sections.indices.contains(index) ? sections[index] : nil
        }

        func sectionIndex(for id: String) -> Int? {
            sections.firstIndex { $0.id == id }
        }

        // MARK: Data

        func applySections(
            _ sections: [EZCalendarAgendaSection<Event>],
            contentRevision: Int
        ) {
            self.sections = sections

            guard let dataSource else { return }

            // UITableView retains the hosted SwiftUI configuration until the
            // row is reconfigured. Compare every stable row identity and the
            // caller's content revision, not only each section's row count.
            let fingerprint = snapshotFingerprint(for: sections)
            guard fingerprint != sectionFingerprint ||
                    contentRevision != appliedContentRevision
            else { return }

            var snapshot = NSDiffableDataSourceSnapshot<String, RowID>()
            snapshot.appendSections(sections.map(\.id))
            for section in sections {
                if section.isEmpty {
                    snapshot.appendItems([.empty(section.id)], toSection: section.id)
                } else {
                    snapshot.appendItems(section.events.map { .event($0.id) }, toSection: section.id)
                }
            }
            // Synchronous on purpose: `handleScrollRequest` runs right after
            // this, in the same `updateUIView`, and needs the table view's
            // live counts to already agree with `self.sections`. `apply(_:
            // animatingDifferences:)` is not guaranteed synchronous even
            // with animations off.
            dataSource.applySnapshotUsingReloadData(snapshot)
            sectionFingerprint = fingerprint
            appliedContentRevision = contentRevision
            if pendingScrollRequest != nil {
                pendingScrollPhase = .awaitingLayout
                pendingScrollVerificationAttempts = 0
                hasAppliedFinalScrollRecovery = false
            } else if let anchorID = lastReportedSectionID,
                      let targetIndex = self.sectionIndex(for: anchorID),
                      let tableView = self.tableView {
                isProgrammaticScroll = true
                tableView.scrollToRow(
                    at: IndexPath(row: 0, section: targetIndex),
                    at: .top,
                    animated: false
                )
                tableView.layoutIfNeeded()
                isProgrammaticScroll = false
            }
        }

        private func snapshotFingerprint(
            for sections: [EZCalendarAgendaSection<Event>]
        ) -> Int {
            var hasher = Hasher()
            hasher.combine(sections.count)

            for section in sections {
                hasher.combine(section.id)
                hasher.combine(section.events.count)
                for event in section.events {
                    hasher.combine(event.id)
                }
            }

            return hasher.finalize()
        }

        private func makeDataSource(
            for tableView: UITableView
        ) -> UITableViewDiffableDataSource<String, RowID> {
            // `UITableView` has no `CellRegistration`/`dequeueConfiguredReusableCell`
            // (that pair is `UICollectionView`-only) — the classic
            // register/dequeue-by-identifier pattern still applies here.
            UITableViewDiffableDataSource<String, RowID>(
                tableView: tableView
            ) { [weak self] tableView, indexPath, rowID in
                let cell = tableView.dequeueReusableCell(
                    withIdentifier: AgendaTableViewIdentifiers.cellReuseIdentifier,
                    for: indexPath
                )
                guard let self, let section = self.section(at: indexPath.section) else { return cell }

                switch rowID {
                case .event(let eventID):
                    guard let event = section.events.first(where: { $0.id == eventID }),
                          let content = self.eventItemViewContent
                    else { return cell }
                    cell.contentConfiguration = UIHostingConfiguration { content(event) }
                        .margins(.all, 0)
                case .empty:
                    guard let content = self.emptyDayViewContent else { return cell }
                    cell.contentConfiguration = UIHostingConfiguration { content(section.date) }
                        .margins(.all, 0)
                }
                cell.backgroundColor = .clear
                cell.selectionStyle = .none
                cell.layoutMargins = .zero
                cell.contentView.layoutMargins = .zero
                cell.preservesSuperviewLayoutMargins = false
                cell.separatorInset = .zero
                return cell
            }
        }

        // MARK: Header (delegate, not data source — table view sections
        // headers aren't part of the diffable item model the way a
        // collection view's boundary supplementary items are)

        func tableView(_ tableView: UITableView, viewForHeaderInSection sectionIndex: Int) -> UIView? {
            guard let section = section(at: sectionIndex),
                  let content = listHeaderViewContent
            else { return nil }

            guard let view = tableView.dequeueReusableHeaderFooterView(
                withIdentifier: AgendaTableViewIdentifiers.headerReuseIdentifier
            ) else { return nil }

            view.contentConfiguration = UIHostingConfiguration { content(section) }
                .margins(.all, 0)
            view.backgroundConfiguration = .clear()
            view.layoutMargins = .zero
            view.preservesSuperviewLayoutMargins = false
            return view
        }

        func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection sectionIndex: Int) {
            guard let section = section(at: sectionIndex) else { return }
            sectionAppeared?(section.id)
        }

        func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
            guard let section = section(at: indexPath.section) else { return 140 }
            return section.isEmpty ? 72 : 140
        }

        func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection sectionIndex: Int) -> CGFloat {
            return 44
        }

        // MARK: Programmatic positioning

        /// Applies a new request only after its rendered top section has been
        /// verified. UITableView uses estimated heights for offscreen hosted
        /// rows, so returning from `scrollToRow` is a command acknowledgement,
        /// not proof that the sticky header has settled on the requested day.
        func handleScrollRequest(
            _ request: AgendaScrollRequest?,
            scrollCommandReceived: @escaping (AgendaScrollRequest) -> Void,
            listPositionSettled: @escaping () -> Void,
            listPositionFailed: @escaping () -> Void
        ) {
            guard let request, request.token != lastHandledScrollToken else { return }

            if pendingScrollRequest?.token != request.token {
                pendingScrollPhase = .awaitingLayout
                pendingScrollVerificationAttempts = 0
                hasAcknowledgedPendingScrollCommand = false
                hasAppliedFinalScrollRecovery = false
            }
            pendingScrollRequest = request
            pendingScrollCommandReceived = scrollCommandReceived
            pendingListPositionSettled = listPositionSettled
            pendingListPositionFailed = listPositionFailed
            schedulePendingScrollAfterLayout()
        }

        private func schedulePendingScrollAfterLayout() {
            guard pendingScrollRequest != nil, !isPendingScrollScheduled
            else { return }
            isPendingScrollScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isPendingScrollScheduled = false
                self.performPendingScrollIfPossible()
            }
        }

        private func performPendingScrollIfPossible() {
            guard let request = pendingScrollRequest,
                  request.token != lastHandledScrollToken,
                  let scrollCommandReceived = pendingScrollCommandReceived,
                  let listPositionSettled = pendingListPositionSettled,
                  let listPositionFailed = pendingListPositionFailed,
                  let tableView,
                  tableView.window != nil,
                  tableView.bounds.height > 0,
                  let sectionIndex = sectionIndex(for: request.id)
            else { return }

            guard prepareTableForPositioning(
                tableView,
                targetSectionIndex: sectionIndex
            ) else { return }

            switch pendingScrollPhase {
            case .awaitingLayout:
                issueScroll(
                    to: sectionIndex,
                    request: request,
                    in: tableView,
                    scrollCommandReceived: scrollCommandReceived
                )
                pendingScrollPhase = .verifying
                schedulePendingScrollAfterLayout()

            case .verifying:
                verifyPendingScroll(
                    request,
                    targetSectionIndex: sectionIndex,
                    in: tableView,
                    scrollCommandReceived: scrollCommandReceived,
                    listPositionSettled: listPositionSettled,
                    listPositionFailed: listPositionFailed
                )
            }
        }

        /// Recovers the observed "sections exist but nothing is visible" state
        /// before scrolling. It also prevents UIKit from receiving an index path
        /// whose live snapshot does not contain the sentinel/event row yet.
        private func prepareTableForPositioning(
            _ tableView: UITableView,
            targetSectionIndex: Int
        ) -> Bool {
            let targetIsMissing = targetSectionIndex >= tableView.numberOfSections ||
                tableView.numberOfRows(inSection: targetSectionIndex) == 0
            let hasVisibleRows = !(tableView.indexPathsForVisibleRows ?? []).isEmpty
            let hasInvalidOffset = !isValidContentOffset(in: tableView)

            if targetIsMissing ||
                (!sections.isEmpty && tableView.contentSize.height > 0 && !hasVisibleRows) ||
                hasInvalidOffset {
                let clampedY = clampedContentOffsetY(
                    tableView.contentOffset.y,
                    in: tableView
                )
                if abs(clampedY - tableView.contentOffset.y) > 0.5 {
                    tableView.setContentOffset(
                        CGPoint(x: tableView.contentOffset.x, y: clampedY),
                        animated: false
                    )
                }
                tableView.reloadData()
                tableView.layoutIfNeeded()
            }

            return targetSectionIndex < tableView.numberOfSections &&
                tableView.numberOfRows(inSection: targetSectionIndex) > 0
        }

        private func issueScroll(
            to sectionIndex: Int,
            request: AgendaScrollRequest,
            in tableView: UITableView,
            scrollCommandReceived: (AgendaScrollRequest) -> Void
        ) {
            if !hasAcknowledgedPendingScrollCommand {
                hasAcknowledgedPendingScrollCommand = true
                scrollCommandReceived(request)
            }
            isProgrammaticScroll = true
            tableView.scrollToRow(
                at: IndexPath(row: 0, section: sectionIndex),
                at: .top,
                animated: false
            )
            tableView.layoutIfNeeded()
            isProgrammaticScroll = false
        }

        private func verifyPendingScroll(
            _ request: AgendaScrollRequest,
            targetSectionIndex: Int,
            in tableView: UITableView,
            scrollCommandReceived: (AgendaScrollRequest) -> Void,
            listPositionSettled: () -> Void,
            listPositionFailed: () -> Void
        ) {
            tableView.layoutIfNeeded()

            let landedID = topmostSectionID(in: tableView)
            let isHeaderVisible = tableView.headerView(forSection: targetSectionIndex) != nil
            let isRowVisible = tableView.indexPathsForVisibleRows?.contains(where: { $0.section == targetSectionIndex }) ?? false

            // Quantifies any miss for the `AgendaSync` log: comparing the
            // landed section's index against the target's in `self.sections`
            // shows both direction and magnitude of a mismatch, rather than
            // only "wrong" with no detail — cheap and bounded (at most
            // `maximumScrollVerificationAttempts` calls per transaction).
            let landedIndex = landedID.flatMap(sectionIndex(for:))
            agendaTableDiagnosticsLogger.debug(
                "verify-attempt=\(self.pendingScrollVerificationAttempts, privacy: .public) target=\(request.id, privacy: .public) targetIndex=\(targetSectionIndex, privacy: .public) landed=\(landedID ?? "nil", privacy: .public) landedIndex=\(landedIndex ?? -1, privacy: .public) headerVisible=\(isHeaderVisible, privacy: .public) rowVisible=\(isRowVisible, privacy: .public) contentOffsetY=\(tableView.contentOffset.y, privacy: .public) targetRectMinY=\(tableView.rect(forSection: targetSectionIndex).minY, privacy: .public)"
            )

            if landedID == request.id && (isHeaderVisible || isRowVisible) {
                completePendingScroll(
                    request,
                    targetSectionIndex: targetSectionIndex,
                    in: tableView,
                    listPositionSettled: listPositionSettled
                )
                return
            }

            pendingScrollVerificationAttempts += 1
            guard pendingScrollVerificationAttempts < maximumScrollVerificationAttempts else {
                if !hasAppliedFinalScrollRecovery {
                    hasAppliedFinalScrollRecovery = true
                    applyFinalScrollRecovery(
                        to: targetSectionIndex,
                        in: tableView
                    )
                    schedulePendingScrollAfterLayout()
                } else {
                    failPendingScroll(request, listPositionFailed: listPositionFailed)
                }
                return
            }

            if let landedIndex, landedIndex != targetSectionIndex {
                let deltaSections = CGFloat(targetSectionIndex - landedIndex)
                let estimatedSectionHeight: CGFloat = sections[targetSectionIndex].isEmpty ? 116 : 184
                let estimatedDeltaY = deltaSections * estimatedSectionHeight
                let newOffsetY = clampedContentOffsetY(tableView.contentOffset.y + estimatedDeltaY, in: tableView)
                tableView.setContentOffset(CGPoint(x: tableView.contentOffset.x, y: newOffsetY), animated: false)
                tableView.layoutIfNeeded()
            }

            // The first long jump can use estimated self-sizing heights. A
            // bounded reload/jump lets the target's concrete hosting sizes take
            // part in the following verification without visible animation.
            tableView.reloadData()
            tableView.layoutIfNeeded()
            issueScroll(
                to: targetSectionIndex,
                request: request,
                in: tableView,
                scrollCommandReceived: scrollCommandReceived
            )
            schedulePendingScrollAfterLayout()
        }

        /// Last-resort recovery uses the section's post-reload rect directly,
        /// rather than another row estimate. If that still cannot make the
        /// requested section leading, terminate the transaction explicitly so
        /// the calendar/list synchronization latch cannot remain stuck.
        private func applyFinalScrollRecovery(
            to sectionIndex: Int,
            in tableView: UITableView
        ) {
            tableView.reloadData()
            tableView.layoutIfNeeded()
            let targetY = tableView.rect(forSection: sectionIndex).minY - tableView.adjustedContentInset.top
            tableView.setContentOffset(
                CGPoint(
                    x: tableView.contentOffset.x,
                    y: clampedContentOffsetY(targetY, in: tableView)
                ),
                animated: false
            )
            tableView.layoutIfNeeded()
        }

        private func completePendingScroll(
            _ request: AgendaScrollRequest,
            targetSectionIndex: Int,
            in tableView: UITableView,
            listPositionSettled: () -> Void
        ) {
            // Verified geometry has been observed to disagree with what's
            // actually painted: two scroll requests issued back-to-back
            // (the first abandoned mid-flight, the second landing and
            // verifying successfully) still showed the *first* transaction's
            // day on screen despite the second's `contentOffsetY` matching
            // `targetRectMinY` to five decimals. Headers come from the
            // delegate (`viewForHeaderInSection`), not the diffable data
            // source, and `reloadData()`/`applySnapshotUsingReloadData` is
            // not guaranteed to force UIKit to re-query the *currently
            // pinned* sticky header specifically, even though it reloads
            // everything else. Force it explicitly rather than trust that
            // the geometry match implies the visible header matches too.
            // Done after clearing the pending-scroll state below (not
            // before), so the layout pass this can trigger has nothing
            // pending left to reschedule against.

            pendingScrollRequest = nil
            pendingScrollCommandReceived = nil
            pendingListPositionSettled = nil
            pendingListPositionFailed = nil
            pendingScrollVerificationAttempts = 0
            pendingScrollPhase = .awaitingLayout
            hasAcknowledgedPendingScrollCommand = false
            hasAppliedFinalScrollRecovery = false
            // UITableViewDiffableDataSource forbids calling mutation APIs like reloadSections directly.
            // Reconfigure visible header views directly via headerView(forSection:) instead.
            let visibleSections = Set((tableView.indexPathsForVisibleRows ?? []).map(\.section) + [targetSectionIndex])
            for sectionIndex in visibleSections {
                if let headerView = tableView.headerView(forSection: sectionIndex),
                   let section = self.section(at: sectionIndex),
                   let content = self.listHeaderViewContent {
                    headerView.contentConfiguration = UIHostingConfiguration { content(section) }
                        .margins(.all, 0)
                }
            }
            lastHandledScrollToken = request.token
            lastReportedSectionID = request.id
            visibleSectionChangedHandler?(request.id)
            listPositionSettled()
            revealInitialContentIfNeeded()
        }

        private func failPendingScroll(
            _ request: AgendaScrollRequest,
            listPositionFailed: () -> Void
        ) {
            pendingScrollRequest = nil
            pendingScrollCommandReceived = nil
            pendingListPositionSettled = nil
            pendingListPositionFailed = nil
            pendingScrollVerificationAttempts = 0
            pendingScrollPhase = .awaitingLayout
            hasAcknowledgedPendingScrollCommand = false
            hasAppliedFinalScrollRecovery = false
            lastHandledScrollToken = request.token
            listPositionFailed()
            revealInitialContentIfNeeded()
        }

        private func topmostSectionID(in tableView: UITableView) -> String? {
            guard let visibleRows = tableView.indexPathsForVisibleRows,
                  !visibleRows.isEmpty
            else { return nil }

            let topY = tableView.contentOffset.y + tableView.adjustedContentInset.top + 1
            let visibleSectionIndexes = Set(visibleRows.map(\.section)).sorted()
            let sectionIndex = visibleSectionIndexes.last {
                tableView.rect(forSection: $0).minY <= topY
            } ?? visibleSectionIndexes[0]
            return section(at: sectionIndex)?.id
        }

        private func isValidContentOffset(in tableView: UITableView) -> Bool {
            let lowerBound = -tableView.adjustedContentInset.top
            let upperBound = max(
                lowerBound,
                tableView.contentSize.height - tableView.bounds.height + tableView.adjustedContentInset.bottom
            )
            return tableView.contentOffset.y >= lowerBound - 1 &&
                tableView.contentOffset.y <= upperBound + 1
        }

        private func clampedContentOffsetY(_ offsetY: CGFloat, in tableView: UITableView) -> CGFloat {
            let lowerBound = -tableView.adjustedContentInset.top
            let upperBound = max(
                lowerBound,
                tableView.contentSize.height - tableView.bounds.height + tableView.adjustedContentInset.bottom
            )
            return min(max(offsetY, lowerBound), upperBound)
        }

        // MARK: User scroll

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let isUserDriven = scrollView.isTracking
                || scrollView.isDragging
                || scrollView.isDecelerating
            guard isUserDriven, !isProgrammaticScroll else { return }
            reportTopmostSection()
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            reportTopmostSection()
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate: Bool) {
            guard !willDecelerate else { return }
            reportTopmostSection()
        }

        /// Reports the section whose original layout rect contains the leading
        /// content edge. Probing indexPathForRow(at:) at that edge is
        /// unreliable because the point normally lies inside the pinned header,
        /// where there is no row index path.
        private func reportTopmostSection() {
            guard let tableView,
                  let visibleRows = tableView.indexPathsForVisibleRows,
                  !visibleRows.isEmpty else { return }

            let topY = tableView.contentOffset.y + tableView.adjustedContentInset.top + 1
            let visibleSectionIndexes = Set(visibleRows.map(\.section)).sorted()
            let sectionIndex = visibleSectionIndexes.last {
                tableView.rect(forSection: $0).minY <= topY
            } ?? visibleSectionIndexes[0]

            guard let section = section(at: sectionIndex),
                  section.id != lastReportedSectionID else { return }

            lastReportedSectionID = section.id
            visibleSectionChangedHandler?(section.id)
        }
    }
}
#endif
