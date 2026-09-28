//
//  AgendaTableView.swift
//  EZCalendar
//
//  Created by wisanu on 28/9/2569 BE.
//

#if os(iOS)
import SwiftUI
import UIKit

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

    let listHeaderViewContent: (EZCalendarAgendaSection<Event>) -> ListHeaderView
    let eventItemViewContent: (Event) -> EventItemView
    let emptyDayViewContent: (Date) -> EmptyDayView

    func makeUIView(context: Context) -> UITableView {
        let tableView = TrailingInsetTableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
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
        override func layoutSubviews() {
            super.layoutSubviews()
            let desired = bounds.height
            if abs(contentInset.bottom - desired) > 1 {
                contentInset.bottom = desired
            }
        }
    }

    func updateUIView(_ tableView: UITableView, context: Context) {
        let coordinator = context.coordinator
        coordinator.listHeaderViewContent = listHeaderViewContent
        coordinator.eventItemViewContent = eventItemViewContent
        coordinator.emptyDayViewContent = emptyDayViewContent
        coordinator.sectionAppeared = sectionAppeared
        coordinator.visibleSectionChangedHandler = visibleSectionChanged

        coordinator.applySections(sections)
        coordinator.handleScrollRequest(
            scrollRequest,
            scrollCommandReceived: scrollCommandReceived,
            listPositionSettled: listPositionSettled
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
        private var sectionFingerprint: [String] = []

        private weak var tableView: UITableView?
        private var dataSource: UITableViewDiffableDataSource<String, RowID>?

        private var lastHandledScrollToken: UUID?
        private var lastReportedSectionID: String?
        private var isProgrammaticScroll = false

        func attach(to tableView: UITableView) {
            self.tableView = tableView
            self.dataSource = makeDataSource(for: tableView)
        }

        func section(at index: Int) -> EZCalendarAgendaSection<Event>? {
            sections.indices.contains(index) ? sections[index] : nil
        }

        func sectionIndex(for id: String) -> Int? {
            sections.firstIndex { $0.id == id }
        }

        // MARK: Data

        func applySections(_ sections: [EZCalendarAgendaSection<Event>]) {
            self.sections = sections

            // Comparing ids + event counts is cheap and catches every real
            // rebuild. `EZCalendarAgendaView.body` re-evaluates on every frame
            // of the collapse animation — this must be a no-op then, or the
            // diffable data source would re-diff dozens of times a second.
            let fingerprint = sections.flatMap { [$0.id, String($0.events.count)] }
            guard fingerprint != sectionFingerprint else { return }
            sectionFingerprint = fingerprint

            guard let dataSource else { return }

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

        // MARK: Programmatic positioning

        /// Applies a new `AgendaScrollRequest` exactly once per token.
        /// Positioning here is synchronous and exact: `UITableView`
        /// precomputes every row's offset the same way it always has, so
        /// there is nothing to wait on and no undershoot to correct — and
        /// therefore nothing to hide with a fade either. `scrollToRow(at:
        /// animated: false)` jumps directly with no visible scroll through
        /// intermediate days on its own.
        func handleScrollRequest(
            _ request: AgendaScrollRequest?,
            scrollCommandReceived: (AgendaScrollRequest) -> Void,
            listPositionSettled: @escaping () -> Void
        ) {
            guard let request, request.token != lastHandledScrollToken else { return }
            lastHandledScrollToken = request.token

            scrollCommandReceived(request)

            guard let tableView,
                  let sectionIndex = sectionIndex(for: request.id)
            else { return }

            let performScroll = { [weak self] in
                guard let self else { return }
                tableView.layoutIfNeeded()

                // `sectionIndex` was computed from `self.sections`, which
                // `applySections` keeps in lockstep with the diffable data
                // source. Defensive: force one more synchronous reload and
                // recheck before scrolling to a row that might not exist —
                // `scrollToRow` crashes outright on an out-of-bounds target,
                // as its `UICollectionView` counterpart did once already.
                if sectionIndex >= tableView.numberOfSections ||
                    tableView.numberOfRows(inSection: sectionIndex) == 0 {
                    tableView.reloadData()
                    tableView.layoutIfNeeded()
                }

                guard sectionIndex < tableView.numberOfSections,
                      tableView.numberOfRows(inSection: sectionIndex) > 0
                else { return }

                self.isProgrammaticScroll = true
                tableView.scrollToRow(
                    at: IndexPath(row: 0, section: sectionIndex),
                    at: .top,
                    animated: false
                )
                self.isProgrammaticScroll = false
                self.lastReportedSectionID = request.id
                self.visibleSectionChangedHandler?(request.id)
                listPositionSettled()
            }

            performScroll()
        }

        // MARK: User scroll

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard !isProgrammaticScroll else { return }
            reportTopmostSection()
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            reportTopmostSection()
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate: Bool) {
            guard !willDecelerate else { return }
            reportTopmostSection()
        }

        /// Whichever section owns the row just past the top inset is, by
        /// definition, the day the sticky header is currently showing.
        private func reportTopmostSection() {
            guard let tableView else { return }

            let probe = CGPoint(
                x: tableView.bounds.midX,
                y: tableView.contentOffset.y + tableView.adjustedContentInset.top + 1
            )

            guard let indexPath = tableView.indexPathForRow(at: probe),
                  let section = section(at: indexPath.section),
                  section.id != lastReportedSectionID
            else { return }

            lastReportedSectionID = section.id
            visibleSectionChangedHandler?(section.id)
        }
    }
}
#endif
