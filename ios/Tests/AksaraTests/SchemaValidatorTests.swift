import XCTest
@testable import Aksara

final class SchemaValidatorTests: XCTestCase {
    func testValidObjectPasses() throws {
        let dict = try SchemaValidator.validated(TestSupport.data(#"{"common":{"login":"Log in"}}"#))
        let common = dict["common"] as? [String: Any]
        XCTAssertEqual(common?["login"] as? String, "Log in")
    }

    func testNumbersAllowedAsLeaves() throws {
        XCTAssertNoThrow(try SchemaValidator.validated(TestSupport.data(#"{"n":42}"#)))
    }

    func testTopLevelArrayRejected() {
        XCTAssertThrowsError(try SchemaValidator.validated(TestSupport.data("[1,2,3]"))) { error in
            XCTAssertEqual(error as? SchemaValidationError, .topLevelNotObject)
        }
    }

    func testInvalidJSONRejected() {
        XCTAssertThrowsError(try SchemaValidator.validated(TestSupport.data("not json at all"))) { error in
            XCTAssertEqual(error as? SchemaValidationError, .notJSON)
        }
    }

    func testNullLeafRejected() {
        XCTAssertThrowsError(try SchemaValidator.validated(TestSupport.data(#"{"a":{"b":null}}"#))) { error in
            XCTAssertEqual(error as? SchemaValidationError, .unsupportedValue(path: "a.b"))
        }
    }
}
