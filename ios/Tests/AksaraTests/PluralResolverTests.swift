import XCTest
@testable import Aksara

final class PluralResolverTests: XCTestCase {
    let resolver = PluralResolver.default

    func testEnglish() {
        XCTAssertEqual(resolver.category(for: 1, language: "en"), .one)
        XCTAssertEqual(resolver.category(for: 0, language: "en"), .other)
        XCTAssertEqual(resolver.category(for: 2, language: "en"), .other)
        XCTAssertEqual(resolver.category(for: 100, language: "en"), .other)
    }

    func testIndonesianAndJapaneseAreOtherOnly() {
        for count in [0, 1, 2, 5, 100] {
            XCTAssertEqual(resolver.category(for: count, language: "id"), .other)
            XCTAssertEqual(resolver.category(for: count, language: "ja"), .other)
        }
    }

    func testArabicFullSet() {
        XCTAssertEqual(resolver.category(for: 0, language: "ar"), .zero)
        XCTAssertEqual(resolver.category(for: 1, language: "ar"), .one)
        XCTAssertEqual(resolver.category(for: 2, language: "ar"), .two)
        XCTAssertEqual(resolver.category(for: 3, language: "ar"), .few)
        XCTAssertEqual(resolver.category(for: 10, language: "ar"), .few)
        XCTAssertEqual(resolver.category(for: 11, language: "ar"), .many)
        XCTAssertEqual(resolver.category(for: 99, language: "ar"), .many)
        XCTAssertEqual(resolver.category(for: 100, language: "ar"), .other)
        XCTAssertEqual(resolver.category(for: 103, language: "ar"), .few) // 103 % 100 == 3
    }

    func testRegionCodeIsNormalized() {
        XCTAssertEqual(resolver.category(for: 1, language: "en-US"), .one)
        XCTAssertEqual(resolver.category(for: 3, language: "ar_EG"), .few)
    }

    func testUnknownLanguageFallsBackToEnglishRule() {
        XCTAssertEqual(resolver.category(for: 1, language: "xx"), .one)
        XCTAssertEqual(resolver.category(for: 5, language: "xx"), .other)
    }

    func testCustomRuleCanBeRegistered() {
        struct AllZero: PluralRule {
            func category(for count: Int) -> PluralCategory { .zero }
        }
        let custom = PluralResolver()
        custom.register(AllZero(), for: "zz")
        XCTAssertEqual(custom.category(for: 7, language: "zz"), .zero)
    }
}
