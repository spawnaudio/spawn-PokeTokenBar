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
            (glass button + chevron). Offenders: \(offenders.joined(separator: ", "))
            """)
    }

    func testMenuChevronIsTheTahoePopupGlyph() {
        XCTAssertEqual(TahoeChromeSymbol.menuChevron, "chevron.down")
    }
}
