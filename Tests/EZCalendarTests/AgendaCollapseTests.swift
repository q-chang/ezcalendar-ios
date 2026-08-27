//
//  AgendaCollapseTests.swift
//  EZCalendar
//
//  Created by wisanu on 27/8/2569 BE.
//

import Foundation
import Testing
@testable import EZCalendar

@Suite("Agenda collapse gesture and geometry")
struct AgendaCollapseTests {

    let threshold: Double = 100

    // MARK: - Progress from the list's scroll offset

    @Test(
        "Scrolling the list up out of .monthly collapses proportionally",
        arguments: [
            (offset: 0.0, progress: 0.0),
            (offset: 25.0, progress: 0.25),
            (offset: 50.0, progress: 0.5),
            (offset: 100.0, progress: 1.0),
            (offset: 400.0, progress: 1.0)
        ]
    )
    func listScrollCollapsesFromMonthly(offset: Double, progress: Double) {
        let result = EZCalendarAgendaLogic.progress(
            forListOffset: offset,
            mode: .monthly,
            threshold: threshold
        )

        #expect(result == progress)
    }

    @Test("Rubber-banding above the top of a .monthly list cannot over-expand it")
    func overscrollInMonthlyStaysExpanded() {
        let result = EZCalendarAgendaLogic.progress(
            forListOffset: -80,
            mode: .monthly,
            threshold: threshold
        )

        #expect(result == 0)
    }

    @Test(
        "In .weekly only an over-scroll past the top expands the calendar",
        arguments: [
            (offset: 500.0, progress: 1.0),   // deep in the list: no effect
            (offset: 0.0, progress: 1.0),     // parked at the top: no effect
            (offset: -30.0, progress: 0.7),   // rubber-banding: expanding
            (offset: -100.0, progress: 0.0),  // full expand
            (offset: -260.0, progress: 0.0)   // clamped
        ]
    )
    func listScrollExpandsFromWeekly(offset: Double, progress: Double) {
        let result = EZCalendarAgendaLogic.progress(
            forListOffset: offset,
            mode: .weekly,
            threshold: threshold
        )

        #expect(abs(result - progress) < 0.000_001)
    }

    @Test("Ordinary scrolling inside a .weekly list never touches the calendar")
    func scrollingWithinWeeklyIsInert() {
        // This is the property that makes the gesture feel native: once
        // collapsed, the list owns every downward pixel.
        for offset in stride(from: 0.0, through: 900.0, by: 60.0) {
            let result = EZCalendarAgendaLogic.progress(
                forListOffset: offset,
                mode: .weekly,
                threshold: threshold
            )

            #expect(result == 1)
        }
    }

    // MARK: - Progress from the grab handle

    @Test(
        "Dragging the handle up out of .monthly collapses proportionally",
        arguments: [
            (translation: 0.0, progress: 0.0),
            (translation: -40.0, progress: 0.4),
            (translation: -100.0, progress: 1.0),
            (translation: -300.0, progress: 1.0)
        ]
    )
    func handleDragCollapses(translation: Double, progress: Double) {
        let result = EZCalendarAgendaLogic.progress(
            forHandleTranslation: translation,
            mode: .monthly,
            threshold: threshold
        )

        #expect(abs(result - progress) < 0.000_001)
    }

    @Test(
        "Dragging the handle down out of .weekly expands proportionally",
        arguments: [
            (translation: 0.0, progress: 1.0),
            (translation: 60.0, progress: 0.4),
            (translation: 100.0, progress: 0.0),
            (translation: 300.0, progress: 0.0)
        ]
    )
    func handleDragExpands(translation: Double, progress: Double) {
        let result = EZCalendarAgendaLogic.progress(
            forHandleTranslation: translation,
            mode: .weekly,
            threshold: threshold
        )

        #expect(abs(result - progress) < 0.000_001)
    }

    @Test("Dragging the handle the wrong way does nothing")
    func wrongWayDragsAreInert() {
        #expect(EZCalendarAgendaLogic.progress(forHandleTranslation: 120, mode: .monthly, threshold: threshold) == 0)
        #expect(EZCalendarAgendaLogic.progress(forHandleTranslation: -120, mode: .weekly, threshold: threshold) == 1)
    }

    @Test("A zero or negative threshold cannot divide by zero; the mode simply holds")
    func degenerateThresholdHoldsTheMode() {
        #expect(EZCalendarAgendaLogic.progress(forListOffset: 50, mode: .monthly, threshold: 0) == 0)
        #expect(EZCalendarAgendaLogic.progress(forListOffset: 50, mode: .weekly, threshold: 0) == 1)
        #expect(EZCalendarAgendaLogic.progress(forHandleTranslation: -50, mode: .monthly, threshold: -10) == 0)
    }

    @Test("A custom threshold rescales the whole gesture")
    func thresholdRescalesTheGesture() {
        // Half the threshold, so half the travel is a full collapse.
        #expect(EZCalendarAgendaLogic.progress(forListOffset: 50, mode: .monthly, threshold: 50) == 1)
        #expect(EZCalendarAgendaLogic.progress(forListOffset: 50, mode: .monthly, threshold: 200) == 0.25)
    }

    // MARK: - Where a released gesture settles

    @Test("A drag that crosses the threshold snaps to the other mode")
    func fullDragSnapsAcross() {
        #expect(EZCalendarAgendaLogic.resolvedMode(progress: 1, from: .monthly) == .weekly)
        #expect(EZCalendarAgendaLogic.resolvedMode(progress: 0, from: .weekly) == .monthly)
    }

    @Test("A drag that stops short springs back to where it started")
    func partialDragSpringsBack() {
        #expect(EZCalendarAgendaLogic.resolvedMode(progress: 0.99, from: .monthly) == .monthly)
        #expect(EZCalendarAgendaLogic.resolvedMode(progress: 0.5, from: .monthly) == .monthly)
        #expect(EZCalendarAgendaLogic.resolvedMode(progress: 0.01, from: .weekly) == .weekly)
        #expect(EZCalendarAgendaLogic.resolvedMode(progress: 0.5, from: .weekly) == .weekly)
    }

    @Test("A mode's resting progress is its own end of the range")
    func modesRestAtTheirOwnEnds() {
        #expect(EZCalendarAgendaMode.monthly.progress == 0)
        #expect(EZCalendarAgendaMode.weekly.progress == 1)
    }

    // MARK: - Geometry

    @Test("The calendar window shrinks from the whole month to exactly one row")
    func windowInterpolatesToOneRow() {
        // A five-row grid, 50pt rows, 1pt gaps: 5×50 + 4×1 = 254.
        let full = 254.0
        let row = EZCalendarAgendaLogic.rowHeight(gridHeight: full, rowCount: 5, spacing: 1)

        #expect(row == 50)
        #expect(EZCalendarAgendaLogic.gridHeight(fullHeight: full, rowHeight: row, progress: 0) == full)
        #expect(EZCalendarAgendaLogic.gridHeight(fullHeight: full, rowHeight: row, progress: 1) == row)
        #expect(EZCalendarAgendaLogic.gridHeight(fullHeight: full, rowHeight: row, progress: 0.5) == (full + row) / 2)
    }

    @Test("Progress outside 0…1 cannot push the window past either end")
    func windowIsClamped() {
        #expect(EZCalendarAgendaLogic.gridHeight(fullHeight: 254, rowHeight: 50, progress: 3) == 50)
        #expect(EZCalendarAgendaLogic.gridHeight(fullHeight: 254, rowHeight: 50, progress: -3) == 254)
    }

    @Test("Before anything has been measured the window states no opinion")
    func unmeasuredGeometryIsInert() {
        #expect(EZCalendarAgendaLogic.gridHeight(fullHeight: 0, rowHeight: 0, progress: 0.5) == 0)
        #expect(EZCalendarAgendaLogic.rowHeight(gridHeight: 0, rowCount: 5, spacing: 1) == 0)
        #expect(EZCalendarAgendaLogic.rowHeight(gridHeight: 254, rowCount: 0, spacing: 1) == 0)
    }

    @Test("The grid slides up by exactly the rows above the selected one")
    func gridSlidesTheSelectedRowToTheTop() {
        let pitch = 51.0  // 50pt row + 1pt gap

        // Selecting a day in the third row: two rows of pitch have to disappear.
        #expect(EZCalendarAgendaLogic.gridOffset(selectedRowIndex: 2, rowPitch: pitch, progress: 1) == -102)
        #expect(EZCalendarAgendaLogic.gridOffset(selectedRowIndex: 2, rowPitch: pitch, progress: 0.5) == -51)
        #expect(EZCalendarAgendaLogic.gridOffset(selectedRowIndex: 2, rowPitch: pitch, progress: 0) == 0)

        // The first row is already at the top, so it never travels.
        #expect(EZCalendarAgendaLogic.gridOffset(selectedRowIndex: 0, rowPitch: pitch, progress: 1) == 0)
    }

    @Test("A nonsensical row index cannot push the grid downward")
    func negativeRowIndexIsIgnored() {
        #expect(EZCalendarAgendaLogic.gridOffset(selectedRowIndex: -4, rowPitch: 51, progress: 1) == 0)
    }

    @Test("Only the selected week survives the collapse; the rest fade out")
    func nonSelectedRowsFade() {
        let selected = 2

        // Fully expanded, every row is solid.
        for row in 0..<5 {
            #expect(EZCalendarAgendaLogic.rowOpacity(rowIndex: row, selectedRowIndex: selected, progress: 0) == 1)
        }

        // Half way, the selected row is untouched and the others are half gone.
        #expect(EZCalendarAgendaLogic.rowOpacity(rowIndex: selected, selectedRowIndex: selected, progress: 0.5) == 1)
        #expect(EZCalendarAgendaLogic.rowOpacity(rowIndex: 0, selectedRowIndex: selected, progress: 0.5) == 0.5)

        // Fully collapsed, only the selected row is visible.
        #expect(EZCalendarAgendaLogic.rowOpacity(rowIndex: selected, selectedRowIndex: selected, progress: 1) == 1)
        #expect(EZCalendarAgendaLogic.rowOpacity(rowIndex: 4, selectedRowIndex: selected, progress: 1) == 0)
    }

    // MARK: - The two drivers agree

    @Test("A handle drag and a list scroll of the same distance produce the same collapse")
    func bothDriversAgree() {
        // The handle reports upward movement as a negative translation; the list
        // reports the same movement as a positive offset. Normalised, they are
        // the same gesture — which is why the view has one transition path.
        for distance in stride(from: 0.0, through: 100.0, by: 10.0) {
            let fromHandle = EZCalendarAgendaLogic.progress(
                forHandleTranslation: -distance,
                mode: .monthly,
                threshold: threshold
            )

            let fromList = EZCalendarAgendaLogic.progress(
                forListOffset: distance,
                mode: .monthly,
                threshold: threshold
            )

            #expect(fromHandle == fromList)
        }
    }
}
