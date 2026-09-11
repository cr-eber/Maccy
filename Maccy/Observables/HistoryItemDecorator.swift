import AppKit.NSWorkspace
import Defaults
import SwiftHEXColors
import Foundation
import Observation
import Sauce

@Observable
class HistoryItemDecorator: Identifiable, Hashable, HasVisibility {
  static func == (lhs: HistoryItemDecorator, rhs: HistoryItemDecorator) -> Bool {
    return lhs.id == rhs.id
  }

  static var previewImageSize: NSSize { NSScreen.forPopup?.visibleFrame.size ?? NSSize(width: 2048, height: 1536) }
  static var thumbnailImageSize: NSSize { NSSize(width: 340, height: Defaults[.imageMaxHeight]) }

  let id = UUID()

  var title: String = ""
  var attributedTitle: AttributedString?
  var isMasked: Bool = false

  // Title as displayed: masked items show only the first/last few characters.
  var displayTitle: String {
    isMasked ? Self.mask(title) : title
  }

  var isVisible: Bool = true
  var selectionIndex: Int = -1
  var isSelected: Bool {
    return selectionIndex != -1
  }
  var shortcuts: [KeyShortcut] = []

  var application: String? {
    if item.universalClipboard {
      return "iCloud"
    }

    guard let bundle = item.application,
      let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle)
    else {
      return nil
    }

    return url.deletingPathExtension().lastPathComponent
  }

  var hasImage: Bool { item.image != nil }

  var previewImageGenerationTask: Task<(), Error>?
  var thumbnailImageGenerationTask: Task<(), Error>?
  var previewImage: NSImage?
  var previewText: String {
    item.previewableText
  }
  var thumbnailImage: NSImage?
  var applicationImage: ApplicationImage

  // 10k characters seems to be more than enough on large displays
  var text: String { previewText.shortened(to: 10_000) }

  var isPinned: Bool { item.pin != nil }
  var isUnpinned: Bool { item.pin == nil }

  func hash(into hasher: inout Hasher) {
    // We need to hash title and attributedTitle, so SwiftUI knows it needs to update the view if they chage
    hasher.combine(id)
    hasher.combine(title)
    hasher.combine(attributedTitle)
    hasher.combine(isMasked)
  }

  private(set) var item: HistoryItem
  
  var multiSelectionIndex: Int? {
    guard AppState.shared.navigator.isMultiSelectInProgress else {
      return nil
    }
    return selectionIndex
  }
  
  // Describe the complete item independently of its potentially truncated visual content.
  var accessibilityLabel: String {
    var parts: [String] = []
    if hasImage, let image = item.image {
      let size = image.pixelSize
      parts.append(String(format: NSLocalizedString("history_item_image_accessibility_label_no_app", comment: ""), Int(size.width), Int(size.height)))
    } else {
      parts.append(displayTitle)
    }
    if let application = application {
      parts.append(application)
    }
    if isPinned {
      parts.append(NSLocalizedString("history_item_pinned_accessibility_value", comment: ""))
    }
    if let index = multiSelectionIndex {
      parts.append(String(format: NSLocalizedString("history_item_selected_accessibility_value", comment: ""), index + 1, AppState.shared.navigator.selection.count))
    }
    return parts.joined(separator: ", ")
  }

  init(_ item: HistoryItem, shortcuts: [KeyShortcut] = []) {
    self.item = item
    self.shortcuts = shortcuts
    self.title = item.title
    self.isMasked = item.masked
    self.applicationImage = ApplicationImageCache.shared.getImage(item: item)

    synchronizeItemPin()
    synchronizeItemTitle()
  }

  @MainActor
  func ensureThumbnailImage() {
    guard item.image != nil else {
      return
    }
    guard thumbnailImage == nil else {
      return
    }
    guard thumbnailImageGenerationTask == nil else {
      return
    }
    thumbnailImageGenerationTask = Task { [weak self] in
      self?.generateThumbnailImage()
    }
  }

  @MainActor
  func ensurePreviewImage() {
    guard item.image != nil else {
      return
    }
    guard previewImage == nil else {
      return
    }
    guard previewImageGenerationTask == nil else {
      return
    }
    previewImageGenerationTask = Task { [weak self] in
      self?.generatePreviewImage()
    }
  }

  @MainActor
  func asyncGetPreviewImage() async -> NSImage? {
    if let image = previewImage {
      return image
    }
    ensurePreviewImage()
    _ = await previewImageGenerationTask?.result
    return previewImage
  }

  @MainActor
  func cleanupImages() {
    thumbnailImageGenerationTask?.cancel()
    previewImageGenerationTask?.cancel()
    thumbnailImage?.recache()
    previewImage?.recache()
    thumbnailImage = nil
    previewImage = nil
    item.clearDecodedImageCache()
  }

  @MainActor
  private func generateThumbnailImage() {
    guard let image = item.image else {
      return
    }
    thumbnailImage = image.resized(to: HistoryItemDecorator.thumbnailImageSize)
  }

  @MainActor
  private func generatePreviewImage() {
    guard let image = item.image else {
      return
    }
    previewImage = image.resized(to: HistoryItemDecorator.previewImageSize)
  }

  @MainActor
  func sizeImages() {
    generatePreviewImage()
    generateThumbnailImage()
  }

  // Number of characters to keep before the first match when the matched
  // part of a long item would otherwise be scrolled out of view.
  private static let matchContextBefore = 20
  private static let matchWindowLength = 500
  // Rough estimate of how many characters fit on one row, used to decide
  // whether the match is already visible without windowing.
  private static let approxCharsPerLine = 60

  // Replace the middle of the text with password dots, keeping the exact
  // character count so search highlight positions stay valid.
  // Rules:
  // - 3 characters or fewer: mask everything (revealing any would be too much)
  // - otherwise at least the first and last character are always shown
  // - if the configured reveal would leave at most one character masked
  //   (trivial to brute-force), fall back to first/last character only
  static func mask(_ text: String) -> String {
    let characters = Array(text)
    guard characters.count > 3 else {
      return String(repeating: "•", count: characters.count)
    }

    var prefixCount = max(1, Defaults[.maskPrefixLength])
    var suffixCount = max(1, Defaults[.maskSuffixLength])
    if characters.count - prefixCount - suffixCount <= 1 {
      prefixCount = 1
      suffixCount = 1
    }

    return String(characters.prefix(prefixCount))
      + String(repeating: "•", count: characters.count - prefixCount - suffixCount)
      + String(characters.suffix(suffixCount))
  }

  @MainActor
  func toggleMask() {
    item.masked.toggle()
    isMasked = item.masked
    try? Storage.shared.context.save()
  }

  // Highlight every occurrence of the query in the given text using the
  // configured highlight style. Used by the preview pane.
  // `searching` provides the real (unmasked) text to find matches in while
  // the attributes are applied to `text` (the displayed, possibly masked,
  // string of the same character length).
  static func highlightAll(
    of query: String, in text: String, searching: String? = nil
  ) -> AttributedString {
    var attributed = AttributedString(text)
    guard !query.isEmpty else { return attributed }

    let source = searching ?? text
    var searchStart = source.startIndex
    while searchStart < source.endIndex,
          let match = source.range(
            of: query, options: .caseInsensitive, range: searchStart..<source.endIndex
          ) {
      let lowerOffset = source.distance(from: source.startIndex, to: match.lowerBound)
      let upperOffset = source.distance(from: source.startIndex, to: match.upperBound)
      if upperOffset <= attributed.characters.count {
        let lower = attributed.characters.index(attributed.startIndex, offsetBy: lowerOffset)
        let upper = attributed.characters.index(attributed.startIndex, offsetBy: upperOffset)
        switch Defaults[.highlightMatch] {
        case .bold:
          attributed[lower..<upper].font = .system(size: Defaults[.fontSize]).bold()
        case .italic:
          attributed[lower..<upper].font = .system(size: Defaults[.fontSize]).italic()
        case .underline:
          attributed[lower..<upper].underlineStyle = .single
        case .coloredText:
          attributed[lower..<upper].foregroundColor =
            NSColor(hexString: Defaults[.highlightMatchColor]) ?? NSColor(hexString: "#D45247")
        default:
          attributed[lower..<upper].backgroundColor = .findHighlightColor
          attributed[lower..<upper].foregroundColor = .black
        }
      }
      searchStart = match.upperBound
    }

    return attributed
  }

  func highlight(_ query: String, _ ranges: [Range<String.Index>]) {
    guard !query.isEmpty, !title.isEmpty else {
      attributedTitle = nil
      return
    }

    // Window the title around the first match (à la Ditto) so the matched
    // part is always visible, marking cut-off sides with an ellipsis.
    // Only window when the match would not fit into the visible rows.
    let visibleCapacity = Defaults[.maxItemLines] * Self.approxCharsPerLine
    var windowStart = title.startIndex
    if let firstMatch = ranges.first,
       firstMatch.lowerBound >= title.startIndex, firstMatch.upperBound <= title.endIndex,
       title.distance(from: title.startIndex, to: firstMatch.upperBound) > visibleCapacity {
      windowStart = title.index(
        firstMatch.lowerBound, offsetBy: -Self.matchContextBefore, limitedBy: title.startIndex
      ) ?? title.startIndex
    }
    let windowEnd = title.index(
      windowStart, offsetBy: Self.matchWindowLength, limitedBy: title.endIndex
    ) ?? title.endIndex

    let cutAtStart = windowStart > title.startIndex
    let cutAtEnd = windowEnd < title.endIndex

    // Masked items render dots in place of the real characters; the masked
    // string has the same character count, so all offsets stay valid.
    let displaySource = isMasked ? Self.mask(title) : title
    let startOffset = title.distance(from: title.startIndex, to: windowStart)
    let endOffset = title.distance(from: title.startIndex, to: windowEnd)
    let displayStart = displaySource.index(displaySource.startIndex, offsetBy: startOffset)
    let displayEnd = displaySource.index(displaySource.startIndex, offsetBy: endOffset)
    var display = String(displaySource[displayStart..<displayEnd])
    if cutAtStart {
      display = "…" + display
    }
    if cutAtEnd {
      display += "…"
    }

    var attributedString = AttributedString(display)
    let windowOffset = title.distance(from: title.startIndex, to: windowStart)
    let ellipsisOffset = cutAtStart ? 1 : 0
    let visibleLength = title.distance(from: windowStart, to: windowEnd)

    for range in ranges {
      guard range.lowerBound >= title.startIndex, range.upperBound <= title.endIndex else {
        continue
      }

      var lower = title.distance(from: title.startIndex, to: range.lowerBound) - windowOffset
      var upper = title.distance(from: title.startIndex, to: range.upperBound) - windowOffset
      lower = max(lower, 0)
      upper = min(upper, visibleLength)
      guard lower < upper else {
        continue
      }

      let lowerBound = attributedString.characters.index(
        attributedString.startIndex, offsetBy: lower + ellipsisOffset
      )
      let upperBound = attributedString.characters.index(
        attributedString.startIndex, offsetBy: upper + ellipsisOffset
      )

      switch Defaults[.highlightMatch] {
      case .bold:
        attributedString[lowerBound..<upperBound].font = .system(size: Defaults[.fontSize]).bold()
      case .italic:
        attributedString[lowerBound..<upperBound].font = .system(size: Defaults[.fontSize]).italic()
      case .underline:
        attributedString[lowerBound..<upperBound].underlineStyle = .single
      case .coloredText:
        attributedString[lowerBound..<upperBound].foregroundColor =
          NSColor(hexString: Defaults[.highlightMatchColor]) ?? NSColor(hexString: "#D45247")
      default:
        attributedString[lowerBound..<upperBound].backgroundColor = .findHighlightColor
        attributedString[lowerBound..<upperBound].foregroundColor = .black
      }
    }

    attributedTitle = attributedString
  }

  @MainActor
  func togglePin() {
    if item.pin != nil {
      item.pin = nil
    } else {
      let pin = HistoryItem.randomAvailablePin
      item.pin = pin
    }
  }

  private func synchronizeItemPin() {
    _ = withObservationTracking {
      item.pin
    } onChange: {
      DispatchQueue.main.async {
        if let pin = self.item.pin {
          self.shortcuts = KeyShortcut.create(character: pin)
        }
        self.synchronizeItemPin()
      }
    }
  }

  private func synchronizeItemTitle() {
    _ = withObservationTracking {
      item.title
    } onChange: {
      DispatchQueue.main.async {
        self.title = self.item.title
        self.synchronizeItemTitle()
      }
    }
  }
}
