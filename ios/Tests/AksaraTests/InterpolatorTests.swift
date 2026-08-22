import XCTest
@testable import Aksara

final class InterpolatorTests: XCTestCase {
    func testSingleVariable() {
        XCTAssertEqual(
            Interpolator.interpolate("Welcome, {{name}}!", args: ["name": "Oncom"]),
            "Welcome, Oncom!"
        )
    }

    func testMultipleVariables() {
        XCTAssertEqual(
            Interpolator.interpolate("{{a}} + {{b}} = {{c}}", args: ["a": "1", "b": "2", "c": "3"]),
            "1 + 2 = 3"
        )
    }

    func testWhitespaceInsideBracesIsTolerated() {
        XCTAssertEqual(
            Interpolator.interpolate("Hi {{ name }}", args: ["name": "Sam"]),
            "Hi Sam"
        )
    }

    func testMissingVariableLeavesPlaceholderIntact() {
        XCTAssertEqual(
            Interpolator.interpolate("Hi {{name}}, {{missing}}", args: ["name": "Sam"]),
            "Hi Sam, {{missing}}"
        )
    }

    func testNoPlaceholdersReturnedUnchanged() {
        XCTAssertEqual(Interpolator.interpolate("plain text", args: ["x": "y"]), "plain text")
    }

    func testEmptyArgsReturnsTemplateUnchanged() {
        XCTAssertEqual(Interpolator.interpolate("Hi {{name}}", args: [:]), "Hi {{name}}")
    }

    func testUnterminatedPlaceholderEmittedVerbatim() {
        XCTAssertEqual(
            Interpolator.interpolate("Hi {{name", args: ["name": "Sam"]),
            "Hi {{name"
        )
    }
}
