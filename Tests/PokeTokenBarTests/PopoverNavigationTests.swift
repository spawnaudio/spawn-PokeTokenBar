import XCTest
@testable import PokeTokenBar

// Popover navigation reset: AppDelegate.togglePopover calls reset() so reopen
// always lands on Focus (Settings must not linger). Collection segment is sticky
// except representative pick, which forces Dex.
@MainActor
final class PopoverNavigationTests: XCTestCase {
    func testDefaultsToFocusAndDex() {
        let nav = PopoverNavigation()
        XCTAssertFalse(nav.showSettings)
        XCTAssertEqual(nav.tab, .focus)
        XCTAssertEqual(nav.collectionSegment, .dex)
        XCTAssertFalse(nav.showingCollectionLog)
    }

    func testRootTabsAreFocusLinearUsageCollection() {
        XCTAssertEqual(PopoverTab.allCases, [.focus, .linear, .usage, .collection])
    }

    func testResetReturnsToFocusFromSettingsAndKeepsCollectionSegment() {
        let nav = PopoverNavigation()
        nav.showSettings = true
        nav.tab = .collection
        nav.collectionSegment = .bag
        nav.showingCollectionLog = true
        nav.reset()
        XCTAssertFalse(nav.showSettings)
        XCTAssertEqual(nav.tab, .focus)
        XCTAssertEqual(nav.collectionSegment, .bag, "reopen keeps Bag/Dex/Shop; only tab goes back to Focus")
        XCTAssertTrue(nav.showingCollectionLog, "Dex vs catch-log stays unless representative pick forces Dex")
    }

    func testOpenRepresentativeDexLeavesSettingsForCollectionDex() {
        let nav = PopoverNavigation()
        nav.showSettings = true
        nav.collectionSegment = .shop
        nav.showingCollectionLog = true

        nav.openRepresentativeDex()

        XCTAssertFalse(nav.showSettings)
        XCTAssertEqual(nav.tab, .collection)
        XCTAssertEqual(nav.collectionSegment, .dex)
        XCTAssertFalse(nav.showingCollectionLog, "representative pick opens Dex, not catch log")
    }

    func testShowFocusLeavesSettings() {
        let nav = PopoverNavigation()
        nav.showSettings = true
        nav.tab = .linear
        nav.showFocus()
        XCTAssertFalse(nav.showSettings)
        XCTAssertEqual(nav.tab, .focus)
    }
}

final class RepresentativeLocalizationTests: XCTestCase {
    func testGermanSettingsLabelsIncludeLatestMainStrings() {
        let l = L(.de)

        XCTAssertEqual(l.todayTokensShort, "Heutige Tokens")
        XCTAssertEqual(l.todayCost, "Heutige Kosten ($)")
        XCTAssertEqual(l.limitPercent, "Limit %")
        XCTAssertEqual(l.animationQualityLabel, "Animation")
        XCTAssertEqual(l.animationQualityHint, "Flüssigere Animationen verbrauchen mehr Batterie")
        XCTAssertEqual(l.animationPowerSaver, "Energiesparmodus")
        XCTAssertEqual(l.animationBalanced, "Ausgewogen")
        XCTAssertEqual(l.animationSmooth, "Flüssig")
    }

    /// 대표 포켓몬은 메뉴바와 플로팅 펫에 함께 쓰이는 독립 개념이다. 모든 언어가 pet 전용 표현으로
    /// 되돌아가거나 스페인어 추가 뒤 한 언어만 빠지지 않도록 사용자가 보는 핵심 액션을 고정한다.
    func testRepresentativeActionsAreLocalizedInEverySupportedLanguage() {
        let expected: [(AppLanguage, label: String, follow: String, choose: String, set: String)] = [
            (.ko, "대표 포켓몬", "현재 포켓몬 따라가기", "도감에서 선택…", "대표로 설정"),
            (.en, "Representative Pokémon", "Follow current companion", "Choose in Pokédex…",
             "Set as representative"),
            (.ja, "代表ポケモン", "現在のポケモンに合わせる", "図鑑で選ぶ…", "代表ポケモンに設定"),
            (.es, "Pokémon representativo", "Seguir al compañero actual", "Elegir en la Pokédex…",
             "Establecer como representante"),
            (.fr, "Pokémon représentatif", "Suivre le compagnon actuel", "Choisir dans le Pokédex…",
             "Définir comme représentatif"),
            (.pt, "Pokémon representativo", "Seguir o companheiro atual", "Escolher na Pokédex…",
             "Definir como representante"),
            (.de, "Repräsentatives Pokémon", "Aktuellem Begleiter folgen", "Im Pokédex auswählen…",
             "Als repräsentativ festlegen"),
        ]

        XCTAssertEqual(expected.map(\.0), AppLanguage.allCases)
        for item in expected {
            let l = L(item.0)
            XCTAssertEqual(l.representativePokemonLabel, item.label)
            XCTAssertEqual(l.representativeFollowCurrent, item.follow)
            XCTAssertEqual(l.representativeChooseFromDex, item.choose)
            XCTAssertEqual(l.representativeSet, item.set)
            XCTAssertFalse(l.representativeBadge.isEmpty)
        }
    }

    func testPopoverIACopyExistsInEverySupportedLanguage() {
        for lang in AppLanguage.allCases {
            let l = L(lang)
            XCTAssertFalse(l.focusTab.isEmpty, "\(lang.rawValue).focusTab")
            XCTAssertFalse(l.usageTab.isEmpty, "\(lang.rawValue).usageTab")
            XCTAssertFalse(l.dexSegment.isEmpty, "\(lang.rawValue).dexSegment")
            XCTAssertFalse(l.activeIssueSection.isEmpty, "\(lang.rawValue).activeIssueSection")
            XCTAssertFalse(l.todayUsageSection.isEmpty, "\(lang.rawValue).todayUsageSection")
            XCTAssertFalse(l.focusIdlePrompt.isEmpty, "\(lang.rawValue).focusIdlePrompt")
            XCTAssertFalse(l.openLinearTab.isEmpty, "\(lang.rawValue).openLinearTab")
            XCTAssertFalse(l.todayDeskEmptyHint.isEmpty, "\(lang.rawValue).todayDeskEmptyHint")
            XCTAssertFalse(l.todayDeskDetailsSection.isEmpty, "\(lang.rawValue).todayDeskDetailsSection")
            XCTAssertFalse(l.todayDeskTeamLabel.isEmpty, "\(lang.rawValue).todayDeskTeamLabel")
        }
        let en = L(.en)
        XCTAssertEqual(en.focusIdlePrompt, "Select a Linear issue to focus")
        XCTAssertEqual(en.openLinearTab, "Open Linear")
        XCTAssertEqual(en.usageTab, "Usage")
        XCTAssertEqual(en.dexSegment, "Dex")
        XCTAssertEqual(en.todayDeskWindowTitle, "Today")
        XCTAssertEqual(en.todayDeskEmptyHint, "Pin an in-progress issue from the left list.")
    }
}
