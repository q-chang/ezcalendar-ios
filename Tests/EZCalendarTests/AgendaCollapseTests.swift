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

    // MARK: - The handle drag decides by threshold, not by tracking

    @Test(
        "Dragging the handle up out of .monthly switches only once past the threshold",
        arguments: [
            (translation: 0.0, expected: EZCalendarAgendaMode.monthly),
            (translation: -40.0, expected: .monthly),
            (translation: -99.0, expected: .monthly),
            (translation: -100.0, expected: .weekly),
            (translation: -260.0, expected: .weekly)
        ]
    )
    func handleDragCollapsesAtThreshold(translation: Double, expected: EZCalendarAgendaMode) {
        let result = EZCalendarAgendaLogic.mode(
            forHandleTranslation: translation,
            from: .monthly,
            threshold: threshold
        )

        #expect(result == expected)
    }

    @Test(
        "Dragging the handle down out of .weekly switches only once past the threshold",
        arguments: [
            (translation: 0.0, expected: EZCalendarAgendaMode.weekly),
            (translation: 55.0, expected: .weekly),
            (translation: 99.0, expected: .weekly),
            (translation: 100.0, expected: .monthly),
            (translation: 300.0, expected: .monthly)
        ]
    )
    func handleDragExpandsAtThreshold(translation: Double, expected: EZCalendarAgendaMode) {
        let result = EZCalendarAgendaLogic.mode(
            forHandleTranslation: translation,
            from: .weekly,
            threshold: threshold
        )

        #expect(result == expected)
    }

    @Test("Dragging the handle the wrong way never switches, however far it goes")
    func wrongWayDragsAreInert() {
        #expect(EZCalendarAgendaLogic.mode(forHandleTranslation: 400, from: .monthly, threshold: threshold) == .monthly)
        #expect(EZCalendarAgendaLogic.mode(forHandleTranslation: -400, from: .weekly, threshold: threshold) == .weekly)
    }

    @Test("A custom threshold moves the switching point")
    func thresholdIsHonoured() {
        // Half the distance is enough…
        #expect(EZCalendarAgendaLogic.mode(forHandleTranslation: -50, from: .monthly, threshold: 50) == .weekly)
        // …and twice the distance is not.
        #expect(EZCalendarAgendaLogic.mode(forHandleTranslation: -50, from: .monthly, threshold: 200) == .monthly)
    }

    @Test("A zero or negative threshold cannot switch modes by accident")
    func degenerateThresholdHoldsTheMode() {
        #expect(EZCalendarAgendaLogic.mode(forHandleTranslation: -500, from: .monthly, threshold: 0) == .monthly)
        #expect(EZCalendarAgendaLogic.mode(forHandleTranslation: 500, from: .weekly, threshold: -10) == .weekly)
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

}
