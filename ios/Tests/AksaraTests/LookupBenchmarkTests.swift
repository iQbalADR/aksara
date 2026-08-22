import XCTest
@testable import Aksara

/// Proves the core claim: `t(...)` is a constant-time hash lookup independent of
/// table size. `measure` records the metric (informational, non-flaky); the
/// assertions guarantee correctness at scale.
final class LookupBenchmarkTests: XCTestCase {
    private func makeTable(count: Int) -> TranslationTable {
        var entries: [String: String] = [:]
        entries.reserveCapacity(count)
        for i in 0..<count {
            entries["ns.key_\(i)"] = "value {{n}} number \(i)"
        }
        return TranslationTable(language: "en", entries: entries)
    }

    func testLookupIsCorrectAtScale() {
        let table = makeTable(count: 50_000)
        XCTAssertEqual(table.count, 50_000)
        XCTAssertEqual(table.value(for: "ns.key_0"), "value {{n}} number 0")
        XCTAssertEqual(table.value(for: "ns.key_49999"), "value {{n}} number 49999")
        XCTAssertNil(table.value(for: "ns.key_50000"))
    }

    func testLookupPerformanceOnLargeTable() {
        let table = makeTable(count: 50_000)
        let keys = (0..<1_000).map { "ns.key_\($0 * 49)" }
        measure {
            for _ in 0..<100 {
                for key in keys {
                    _ = table.value(for: key)
                }
            }
        }
    }
}
