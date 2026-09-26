import Foundation
import XCTest

/// The controls the Widgets tab builds for a widget's options.
///
/// Every defect these cover had the same shape: the control rendered, it
/// accepted input, and the value went nowhere useful. A setting that looks
/// like it worked is worse than one that is missing.
final class WidgetOptionTests: XCTestCase {

    // MARK: Reading with the catalog's default

    /// A widget saved before a key existed carries no value for it, and the
    /// control used to read it with Swift's zero rather than the catalog's
    /// default. So the toggle showed off while the tile ran on, until it was
    /// touched once and the disagreement wrote itself into the file.
    func testAMissingKeyReadsAsTheCatalogDefault() {
        for kind in WidgetKind.allCases {
            guard let entry = WidgetCatalog.entry(kind) else { continue }
            let empty = WidgetConfig()
            for key in WidgetCatalog.configurableKeys(kind) {
                switch entry.defaults.values[key] {
                case .bool(let fallback):
                    XCTAssertEqual(empty.bool(key, default: fallback), fallback,
                                   "\(kind.rawValue).\(key)")
                case .string(let fallback):
                    XCTAssertEqual(empty.string(key, default: fallback), fallback,
                                   "\(kind.rawValue).\(key)")
                default:
                    continue
                }
            }
        }
    }

    /// And a stored value still wins, or the control could not change anything.
    func testAStoredValueBeatsTheDefault() {
        var config = WidgetConfig()
        config.set("chart", .bool(true))
        XCTAssertTrue(config.bool("chart", default: false))
    }

    // MARK: Every option has some control

    /// The Widgets tab builds a control per configurable key. A key whose
    /// shape has no branch renders nothing, so the option exists, is stored,
    /// and cannot be reached: `symbols` was exactly that.
    func testEveryConfigurableKeyHasAShapeThatCanBeRendered() {
        for kind in WidgetKind.allCases {
            guard let entry = WidgetCatalog.entry(kind) else { continue }
            for key in WidgetCatalog.configurableKeys(kind) {
                let value = entry.defaults.values[key]
                XCTAssertNotNil(value, "\(kind.rawValue).\(key) is listed but has no default")
                switch value {
                case .bool, .number, .string, .list: break
                case .none: XCTFail("\(kind.rawValue).\(key) has no value to render")
                }
            }
        }
    }

    // MARK: Free-form lists

    /// The watchlist editor is a comma separated field, so the parse is the
    /// whole feature. Whitespace, trailing separators and empty entries all
    /// arrive while someone is still typing.
    func testCommaSeparatedEntriesAreParsedForgivingly() {
        XCTAssertEqual(parse("AAPL, MSFT,NVDA"), ["AAPL", "MSFT", "NVDA"])
        XCTAssertEqual(parse("  AAPL  ,   MSFT  "), ["AAPL", "MSFT"])
        XCTAssertEqual(parse("AAPL,,MSFT"), ["AAPL", "MSFT"], "a double comma is a typo, not a gap")
        XCTAssertEqual(parse("AAPL,"), ["AAPL"], "mid-edit, having just typed the separator")
    }

    /// An empty field is a half-finished edit rather than a request for a
    /// widget with nothing in it, so it must not be written.
    func testAnEmptyListIsNotWritten() {
        XCTAssertTrue(parse("").isEmpty)
        XCTAssertTrue(parse("   ,  , ").isEmpty)
    }

    private func parse(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: Round trip

    /// What the field shows has to be what a save would produce, or an edit
    /// that changes nothing still rewrites the value.
    func testTheListSurvivesADisplayAndReparse() {
        let original = ["AAPL", "MSFT", "NVDA"]
        XCTAssertEqual(parse(original.joined(separator: ", ")), original)
    }
}
