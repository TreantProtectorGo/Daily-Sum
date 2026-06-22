import XCTest
@testable import Flux

@MainActor
final class CustomNumberPadFeedbackTests: XCTestCase {
    func testDockedGrabberDoesNotReserveHeightWhileExpanded() {
        XCTAssertEqual(DockedAmountNumberPadLayout.expandedGrabberReservedHeight, 0)
        XCTAssertEqual(DockedAmountNumberPadLayout.collapsedGrabberHeight, 24)
    }

    func testLayoutKeepsBackspaceInBottomRightOfNumberGrid() {
        let expectedRows: [[CustomNumberPadAction]] = [
            [.digit(1), .digit(2), .digit(3)],
            [.digit(4), .digit(5), .digit(6)],
            [.digit(7), .digit(8), .digit(9)],
            [.decimalSeparator, .digit(0), .backspace]
        ]

        XCTAssertEqual(
            CustomNumberPadLayout.numberGridRows,
            expectedRows
        )
    }

    func testLayoutPlacesMultiplyAndDivideOnSameRow() {
        let expectedRows: [CustomNumberPadSideColumnRow] = [
            .single(.operation(.add)),
            .single(.operation(.subtract)),
            .pair(.operation(.multiply), .operation(.divide)),
            .single(.confirm)
        ]

        XCTAssertEqual(
            CustomNumberPadLayout.sideColumnRows,
            expectedRows
        )
    }

    func testLayoutUsesWiderGapBetweenNumberGridAndSideColumn() {
        XCTAssertGreaterThan(
            CustomNumberPadLayout.sectionSpacing,
            CustomNumberPadLayout.numberGridSpacing
        )
    }

    func testLayoutUsesMoreTopPaddingAndTighterBottomPadding() {
        XCTAssertEqual(CustomNumberPadLayout.outerTopPadding, 16)
        XCTAssertEqual(CustomNumberPadLayout.outerBottomPadding, 2)
        XCTAssertGreaterThan(
            CustomNumberPadLayout.outerTopPadding,
            CustomNumberPadLayout.outerBottomPadding
        )
    }

    func testSheetHeightTracksKeypadContentInsteadOfLargeFixedDetent() {
        XCTAssertEqual(CustomNumberPadLayout.sheetHeight, 300)
        XCTAssertLessThan(CustomNumberPadLayout.sheetHeight, 400)
    }

    func testLayoutUsesStandaloneKeysInsteadOfGroupedPanels() {
        XCTAssertFalse(CustomNumberPadLayout.usesGroupedSectionPanels)
        XCTAssertEqual(CustomNumberPadLayout.sectionPanelPadding, 0)
    }

    func testNumberKeyUsesNeutralPaletteAndDarkensWhenPressed() {
        let idle = CustomNumberPadFeedback.appearance(for: .number, isPressed: false)
        let pressed = CustomNumberPadFeedback.appearance(for: .number, isPressed: true)

        XCTAssertEqual(idle.backgroundStyle, .elevatedSurface)
        XCTAssertEqual(idle.foregroundStyle, .primary)
        XCTAssertEqual(idle.pressedOverlayOpacity, 0)
        XCTAssertEqual(pressed.pressedOverlayOpacity, 0.14)
    }

    func testOperatorKeyKeepsAccentTextOnNeutralSurface() {
        let appearance = CustomNumberPadFeedback.appearance(for: .operation, isPressed: true)

        XCTAssertEqual(appearance.backgroundStyle, .elevatedSurface)
        XCTAssertEqual(appearance.foregroundStyle, .accent)
        XCTAssertEqual(appearance.borderOpacity, 0.10)
        XCTAssertEqual(appearance.pressedOverlayOpacity, 0.16)
    }

    func testConfirmKeyUsesAccentSurfaceAndDarkensWhenPressed() {
        let idle = CustomNumberPadFeedback.appearance(for: .confirm, isPressed: false)
        let pressed = CustomNumberPadFeedback.appearance(for: .confirm, isPressed: true)

        XCTAssertEqual(idle.backgroundStyle, .accent)
        XCTAssertEqual(idle.foregroundStyle, .inverse)
        XCTAssertEqual(idle.pressedOverlayOpacity, 0)
        XCTAssertEqual(pressed.pressedOverlayOpacity, 0.18)
    }

    func testAcceptedAndCorrectedActionsUseLightImpactHaptic() {
        XCTAssertEqual(CustomNumberPadFeedback.hapticKind(for: .accepted), .lightImpact)
        XCTAssertEqual(CustomNumberPadFeedback.hapticKind(for: .corrected), .lightImpact)
    }

    func testIgnoredActionsUseWarningHaptic() {
        XCTAssertEqual(CustomNumberPadFeedback.hapticKind(for: .ignored), .warning)
    }

    func testKeySurfacePaletteUsesElevatedLightAndDarkColors() {
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)
        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)

        XCTAssertEqual(
            CustomNumberPadPalette.color(for: .elevatedSurface).resolvedColor(with: lightTraits),
            UIColor.systemBackground.resolvedColor(with: lightTraits)
        )
        XCTAssertEqual(
            CustomNumberPadPalette.color(for: .elevatedSurface).resolvedColor(with: darkTraits),
            UIColor.tertiarySystemBackground.resolvedColor(with: darkTraits)
        )
    }

    func testGroupSurfacePaletteSeparatesKeyClustersInLightAndDarkColors() {
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)
        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)

        XCTAssertEqual(
            CustomNumberPadPalette.groupSurface.resolvedColor(with: lightTraits),
            UIColor.systemGray6.resolvedColor(with: lightTraits)
        )
        XCTAssertEqual(
            CustomNumberPadPalette.groupSurface.resolvedColor(with: darkTraits),
            UIColor.secondarySystemBackground.resolvedColor(with: darkTraits)
        )
        XCTAssertNotEqual(
            CustomNumberPadPalette.groupSurface.resolvedColor(with: lightTraits),
            CustomNumberPadPalette.color(for: .elevatedSurface).resolvedColor(with: lightTraits)
        )
    }

    func testSheetSurfaceMatchesKeypadBackgroundInLightAndDarkColors() {
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)
        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)

        XCTAssertEqual(
            CustomNumberPadPalette.sheetSurface.resolvedColor(with: lightTraits),
            CustomNumberPadPalette.groupSurface.resolvedColor(with: lightTraits)
        )
        XCTAssertEqual(
            CustomNumberPadPalette.sheetSurface.resolvedColor(with: darkTraits),
            CustomNumberPadPalette.groupSurface.resolvedColor(with: darkTraits)
        )
    }
}
