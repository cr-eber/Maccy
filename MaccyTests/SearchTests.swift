import XCTest
import Defaults
@testable import Maccy

class SearchTests: XCTestCase {
  var items: [Search.Searchable]!

  @MainActor
  func testSimpleSearch() { // swiftlint:disable:this function_body_length
    items = [
      HistoryItemDecorator(historyItemWithTitle("foo bar baz")),
      HistoryItemDecorator(historyItemWithTitle("foo bar zaz")),
      HistoryItemDecorator(historyItemWithTitle("xxx yyy zzz"))
    ]

    XCTAssertEqual(search(""), [
      Search.SearchResult(score: nil, object: items[0], ranges: []),
      Search.SearchResult(score: nil, object: items[1], ranges: []),
      Search.SearchResult(score: nil, object: items[2], ranges: [])
    ])
    XCTAssertEqual(search("z"), [
      Search.SearchResult(
        score: nil,
        object: items[0],
        ranges: [range(from: 10, to: 10, in: items[0])]
      ),
      Search.SearchResult(
        score: nil,
        object: items[1],
        ranges: [range(from: 8, to: 8, in: items[1])]
      ),
      Search.SearchResult(
        score: nil,
        object: items[2],
        ranges: [range(from: 8, to: 8, in: items[2])]
      )
    ])
    XCTAssertEqual(search("foo"), [
      Search.SearchResult(
        score: nil,
        object: items[0],
        ranges: [range(from: 0, to: 2, in: items[0])]
      ),
      Search.SearchResult(
        score: nil,
        object: items[1],
        ranges: [range(from: 0, to: 2, in: items[1])]
      )
    ])
    XCTAssertEqual(search("za"), [
      Search.SearchResult(
        score: nil,
        object: items[1],
        ranges: [range(from: 8, to: 9, in: items[1])]
      )
    ])
    XCTAssertEqual(search("yyy"), [
      Search.SearchResult(
        score: nil,
        object: items[2],
        ranges: [range(from: 4, to: 6, in: items[2])]
      )
    ])
    XCTAssertEqual(search("fbb"), [])
    XCTAssertEqual(search("m"), [])
  }

  private func search(_ string: String) -> [Search.SearchResult] {
    return Search().search(string: string, within: items)
  }

  // swiftlint:disable:next identifier_name
  private func range(from: Int, to: Int, in item: HistoryItemDecorator) -> Range<String.Index> {
    let startIndex = item.title.startIndex
    let lowerBound = item.title.index(startIndex, offsetBy: from)
    let upperBound = item.title.index(startIndex, offsetBy: to + 1)

    return lowerBound..<upperBound
  }

  @MainActor
  private func historyItemWithTitle(_ value: String?) -> HistoryItem {
    let contents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: value?.data(using: .utf8)
      )
    ]
    let item = HistoryItem()
    Storage.shared.context.insert(item)
    item.contents = contents
    item.title = item.generateTitle()

    return item
  }
}
