import AppKit
import Defaults
import KeyboardShortcuts
import SwiftHEXColors
import SwiftUI

struct PreviewItemView: View {
  static var largeTextThreshold = 1_000

  var item: HistoryItemDecorator

  @ViewBuilder
  func previewImage(content: () -> some View) -> some View {
    content()
      .aspectRatio(contentMode: .fit)
      .clipShape(.rect(cornerRadius: 5))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if item.hasImage {
        AsyncView<NSImage?, _, _>(id: item.id) {
          return await item.asyncGetPreviewImage()
        } content: { image in
          if let image = image {
            previewImage {
              Image(nsImage: image)
                .resizable()
            }
          } else {
            previewImage {
              ZStack {
                Color.gray.opacity(0.3)
                  .frame(
                    idealWidth: HistoryItemDecorator.previewImageSize.width,
                    idealHeight: HistoryItemDecorator.previewImageSize.height
                  )
                Image(systemName: "photo.badge.exclamationmark")
                  .symbolRenderingMode(.multicolor)
                  .frame(alignment: .center)
              }
            }
          }
        } placeholder: {
          previewImage {
            ZStack {
              Color.gray.opacity(0.3)
                .frame(
                  idealWidth: HistoryItemDecorator.previewImageSize.width,
                  idealHeight: HistoryItemDecorator.previewImageSize.height
                )
              ProgressView()
                .frame(alignment: .center)
            }
          }
        }
      } else {
        let text = item.previewText
        let query = AppState.shared.history.searchQuery
        if text.count >= Self.largeTextThreshold {
          LargeTextPreviewView(text: text, query: query)
            .id("textpreview-\(item.id)")
        } else {
          ScrollView {
            Text(HistoryItemDecorator.highlightAll(of: query, in: text))
              .font(.body)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .frame(maxWidth: .infinity)
        }
      }

      Spacer(minLength: 0)

      Divider()
        .padding(.bottom)

      if let application = item.application {
        HStack(spacing: 3) {
          Text("Application", tableName: "PreviewItemView")
          AppImageView(
            appImage: item.applicationImage,
            size: NSSize(width: 11, height: 11)
          )
          Text(application)
        }
      }

      if item.hasImage, let image = item.item.image {
        HStack(spacing: 3) {
          Text("Dimensions", tableName: "PreviewItemView")
          Text("\(Int(image.pixelSize.width))×\(Int(image.pixelSize.height))")
        }
      }

      HStack(spacing: 3) {
        Text("FirstCopyTime", tableName: "PreviewItemView")
        Text(item.item.firstCopiedAt, style: .date)
        Text(item.item.firstCopiedAt, style: .time)
      }

      HStack(spacing: 3) {
        Text("LastCopyTime", tableName: "PreviewItemView")
        Text(item.item.lastCopiedAt, style: .date)
        Text(item.item.lastCopiedAt, style: .time)
      }

      HStack(spacing: 3) {
        Text("NumberOfCopies", tableName: "PreviewItemView")
        Text(String(item.item.numberOfCopies))
      }
    }
    .controlSize(.small)
  }
}

struct LargeTextPreviewView: NSViewRepresentable {
  let text: String
  var query: String = ""

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = Self.makeScrollView(text: text)
    if let textView = scrollView.documentView as? NSTextView {
      Self.highlightMatches(of: query, in: textView)
    }
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    guard let textView = scrollView.documentView as? NSTextView else {
      return
    }

    if textView.string != text {
      textView.string = text
    }
    Self.highlightMatches(of: query, in: textView)
  }

  static func highlightMatches(of query: String, in textView: NSTextView) {
    guard let storage = textView.textStorage else { return }

    let fullRange = NSRange(location: 0, length: storage.length)
    storage.removeAttribute(.backgroundColor, range: fullRange)
    storage.removeAttribute(.underlineStyle, range: fullRange)
    storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
    storage.addAttribute(
      .font, value: NSFont.systemFont(ofSize: NSFont.systemFontSize), range: fullRange
    )

    guard !query.isEmpty else { return }

    let string = storage.string as NSString
    var location = 0
    while location < string.length {
      let found = string.range(
        of: query,
        options: .caseInsensitive,
        range: NSRange(location: location, length: string.length - location)
      )
      guard found.location != NSNotFound, found.length > 0 else { break }

      switch Defaults[.highlightMatch] {
      case .bold:
        storage.addAttribute(
          .font, value: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize), range: found
        )
      case .italic:
        let italic = NSFontManager.shared.convert(
          NSFont.systemFont(ofSize: NSFont.systemFontSize), toHaveTrait: .italicFontMask
        )
        storage.addAttribute(.font, value: italic, range: found)
      case .underline:
        storage.addAttribute(
          .underlineStyle, value: NSUnderlineStyle.single.rawValue, range: found
        )
      case .coloredText:
        let color = NSColor(hexString: Defaults[.highlightMatchColor]) ?? .systemRed
        storage.addAttribute(.foregroundColor, value: color, range: found)
      default:
        storage.addAttribute(.backgroundColor, value: NSColor.findHighlightColor, range: found)
        storage.addAttribute(.foregroundColor, value: NSColor.black, range: found)
      }

      location = found.location + found.length
    }
  }

  static func makeScrollView(text: String) -> NSScrollView {
    let textView = NSTextView(usingTextLayoutManager: true)
    textView.isEditable = false
    textView.isSelectable = false
    textView.isRichText = false
    textView.drawsBackground = false
    textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
    textView.textColor = .labelColor
    textView.textContainerInset = .zero
    textView.minSize = .zero
    textView.maxSize = NSSize(
      width: CGFloat.greatestFiniteMagnitude,
      height: CGFloat.greatestFiniteMagnitude
    )
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = false
    textView.autoresizingMask = [.width]
    textView.textContainer?.lineFragmentPadding = 0
    textView.textContainer?.widthTracksTextView = true
    textView.textContainer?.heightTracksTextView = false
    textView.string = text

    let scrollView = NSScrollView()
    scrollView.documentView = textView
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.autohidesScrollers = true
    scrollView.borderType = .noBorder
    scrollView.drawsBackground = false
    return scrollView
  }
}
