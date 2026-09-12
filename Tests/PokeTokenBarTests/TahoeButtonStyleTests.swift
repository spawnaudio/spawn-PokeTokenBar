import XCTest
@testable import PokeTokenBar

/// Action buttons in the UI sources must go through `tahoeButtonStyle` so macOS 26+
/// picks up Liquid Glass and older macOS keeps bordered / borderless fallbacks.
/// Raw `.bordered` / `.borderedProminent` / `.borderless` are only allowed inside
/// that helper (PopoverChrome.swift). List rows, dex cells, and disclosures stay `.plain`.
final class TahoeButtonStyleTests: XCTestCase {
    func testUIButtonsUseTahoeHelperInsteadOfRawBorderedStyles() throws {
        let ui = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PokeTokenBar/UI")
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(
            at: ui, includingPropertiesForKeys: nil))
        let forbidden = [
            ".buttonStyle(.borderedProminent)",
            ".buttonStyle(.bordered)",
            ".buttonStyle(.borderless)",
            ".buttonStyle(.glassProminent)",
            ".buttonStyle(.glass)",
        ]
        var offenders: [String] = []

        for case let url as URL in enumerator where url.pathExtension == "swift" {
            if url.lastPathComponent == "PopoverChrome.swift" { continue }
            let lines = try String(contentsOf: url, encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if forbidden.contains(where: { trimmed.contains($0) }) {
                    offenders.append("\(url.lastPathComponent):\(index + 1)")
                }
            }
        }

        XCTAssertTrue(offenders.isEmpty, """
            Use tahoeButtonStyle(.prominent/.regular/.accessory) so Tahoe glass and older \
            macOS fallbacks stay in one place. Offenders: \(offenders.joined(separator: ", "))
            """)
    }

    func testPopoverChromeOwnsGlassAndFallbackStyles() throws {
        let chrome = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PokeTokenBar/UI/PopoverChrome.swift")
        let source = try String(contentsOf: chrome, encoding: .utf8)
        XCTAssertTrue(source.contains("func tahoeButtonStyle"))
        XCTAssertTrue(source.contains(".glassProminent"))
        XCTAssertTrue(source.contains(".buttonStyle(.borderedProminent)"))
        XCTAssertTrue(source.contains(".buttonStyle(.bordered)"))
        XCTAssertTrue(source.contains(".buttonStyle(.borderless)"))
        XCTAssertTrue(source.contains("GlassEffectContainer"))
        XCTAssertTrue(source.contains("TahoeMenuLabel"))
        XCTAssertTrue(source.contains("TahoePopupMenu"))
        XCTAssertTrue(source.contains("TahoeTabBar"))
        XCTAssertTrue(source.contains("TahoeChromeSymbol.menuChevron"))
        XCTAssertTrue(source.contains("func popoverBottomBarChrome"))
        XCTAssertTrue(source.contains("func linearChipChrome"))
        XCTAssertTrue(source.contains("func linearSegmentChrome"))
        XCTAssertTrue(source.contains("struct LinearTagChip"))
        XCTAssertTrue(source.contains("struct LinearPropertyRow"))
        XCTAssertTrue(source.contains(".linearChipChrome(expands: expands)"))
        XCTAssertTrue(source.contains(".linearSegmentChrome(selected: selected)"))
        XCTAssertFalse(
            popupMenuContainsTahoeButtonStyle(source),
            "TahoePopupMenu must stay a quiet chip, not a glass button")
    }

    func testUIPickersDoNotUseNativeMenuOrSegmentedStyles() throws {
        let ui = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PokeTokenBar/UI")
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(
            at: ui, includingPropertiesForKeys: nil))
        let forbidden = [".pickerStyle(.segmented)", ".pickerStyle(.menu)", ".menuIndicator(.visible)"]
        var offenders: [String] = []

        for case let url as URL in enumerator where url.pathExtension == "swift" {
            if url.lastPathComponent == "PopoverChrome.swift" { continue }
            let lines = try String(contentsOf: url, encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if forbidden.contains(where: { trimmed.contains($0) }) {
                    offenders.append("\(url.lastPathComponent):\(index + 1)")
                }
            }
        }

        XCTAssertTrue(offenders.isEmpty, """
            Tabs use TahoeTabBar and dropdowns use TahoePopupMenu / TahoeMenuLabel \
            (quiet chip + chevron). Offenders: \(offenders.joined(separator: ", "))
            """)
    }

    func testMenuChevronIsTheTahoePopupGlyph() {
        XCTAssertEqual(TahoeChromeSymbol.menuChevron, "chevron.down")
    }

    func testLinearInformationSurfacesStayQuietAndUnboxed() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PokeTokenBar/UI")
        let linear = try String(
            contentsOf: root.appendingPathComponent("LinearIntegrationView.swift"), encoding: .utf8)
        let today = try String(
            contentsOf: root.appendingPathComponent("TodayDeskView.swift"), encoding: .utf8)
        let controls = try String(
            contentsOf: root.appendingPathComponent("LinearIssueControls.swift"), encoding: .utf8)
        let composer = try String(
            contentsOf: root.appendingPathComponent("LinearIssueComposer.swift"), encoding: .utf8)
        let usage = try String(
            contentsOf: root.appendingPathComponent("UsageTabView.swift"), encoding: .utf8)

        XCTAssertTrue(linear.contains("LinearIssueEntityRow"))
        XCTAssertTrue(linear.contains("LinearTagChip"))
        XCTAssertTrue(linear.contains("VStack(alignment: .leading, spacing: 0)"))
        XCTAssertFalse(linear.contains("popoverCard()"))
        XCTAssertFalse(linear.contains("strokeBorder(Color.primary.opacity(0.08)"))

        XCTAssertTrue(today.contains("LinearPropertyRow"))
        XCTAssertTrue(today.contains("TodayDeskPinRow"))
        XCTAssertFalse(today.contains("pinned ? Color.accentColor.opacity(0.14)"))

        XCTAssertTrue(controls.contains(".buttonStyle(.plain)"))
        XCTAssertFalse(idButtonUsesTahoeGlass(controls))
        XCTAssertTrue(controls.contains(".linearChipChrome()"))

        XCTAssertTrue(composer.contains("LinearPropertyRow(label: l.linearIssueTeam)"))
        XCTAssertTrue(composer.contains(".linearChipChrome(expands: true)"))

        XCTAssertTrue(usage.contains("linearSegmentChrome(selected: isSelected)"))
        XCTAssertFalse(usage.contains("TahoeGlassCluster"))
    }

    private func popupMenuContainsTahoeButtonStyle(_ source: String) -> Bool {
        guard let range = source.range(of: "struct TahoePopupMenu") else { return true }
        let rest = source[range.lowerBound...]
        guard let end = rest.range(of: "struct TahoeTabItem") else {
            return rest.contains("tahoeButtonStyle")
        }
        return rest[..<end.lowerBound].contains("tahoeButtonStyle")
    }

    private func idButtonUsesTahoeGlass(_ source: String) -> Bool {
        guard let range = source.range(of: "struct LinearIssueIDButton") else { return true }
        let rest = source[range.lowerBound...]
        guard let end = rest.range(of: "struct LinearIssueCompletionStats") else {
            return rest.contains("tahoeButtonStyle")
        }
        return rest[..<end.lowerBound].contains("tahoeButtonStyle")
    }
}
