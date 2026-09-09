import AppKit
import SwiftHEXColors

class ColorImage {
  static func from(_ colorHex: String) -> NSImage? {
    // Only treat values explicitly written as hex colors (#RRGGBB) as colors.
    guard colorHex.hasPrefix("#"), let color = NSColor(hexString: colorHex) else {
      return nil
    }

    let size = NSSize(width: 16, height: 16)
    let image = NSImage(size: size)
    image.lockFocus()
    let rect = NSRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)
    let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
    color.setFill()
    path.fill()
    NSColor.black.withAlphaComponent(0.2).setStroke()
    path.stroke()
    image.unlockFocus()

    return image
  }
}
