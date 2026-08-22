import XCTest
@testable import Aksara

final class FlattenerTests: XCTestCase {
    func testNestedObjectsBecomeDotPaths() {
        let json: [String: Any] = [
            "common": ["login": "Log in", "nested": ["deep": "value"]],
            "auth": ["title": "Sign in"],
        ]
        let flat = Flattener.flatten(json)
        XCTAssertEqual(flat["common.login"], "Log in")
        XCTAssertEqual(flat["common.nested.deep"], "value")
        XCTAssertEqual(flat["auth.title"], "Sign in")
    }

    func testPluralSubKeysAreFlattened() {
        let json: [String: Any] = ["items": ["one": "1 item", "other": "{{count}} items"]]
        let flat = Flattener.flatten(json)
        XCTAssertEqual(flat["items.one"], "1 item")
        XCTAssertEqual(flat["items.other"], "{{count}} items")
    }

    func testArraysAreIndexed() {
        let json: [String: Any] = ["steps": ["first", "second", "third"]]
        let flat = Flattener.flatten(json)
        XCTAssertEqual(flat["steps.0"], "first")
        XCTAssertEqual(flat["steps.1"], "second")
        XCTAssertEqual(flat["steps.2"], "third")
    }

    func testNumbersAndBoolsAreStringified() {
        let json: [String: Any] = ["count": 42, "enabled": true]
        let flat = Flattener.flatten(json)
        XCTAssertEqual(flat["count"], "42")
        // Bools bridge to NSNumber; stringValue is "1"/"0".
        XCTAssertEqual(flat["enabled"], "1")
    }
}
