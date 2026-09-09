// swiftlint:disable file_length
import AppKit.NSRunningApplication
import Defaults
import Foundation
import Logging
import Observation
import Sauce
import Settings
import SwiftData

@Observable
class History: ItemsContainer { // swiftlint:disable:this type_body_length
  static let shared = History()
  let logger = Logger(label: "org.p0deje.Maccy")

  var items: [HistoryItemDecorator] = []
  var pasteStack: PasteStack?

  var pinnedItems: [HistoryItemDecorator] { items.filter(\.isPinned) }
  var unpinnedItems: [HistoryItemDecorator] { items.filter(\.isUnpinned) }

  var searchQuery: String = "" {
    didSet {
      throttler.throttle { [self] in
        // Text search should never surface image items.
        let searchScope = searchQuery.isEmpty ? all : all.filter { !$0.hasImage }
        updateItems(search.search(string: searchQuery, within: searchScope))

        if searchQuery.isEmpty {
          AppState.shared.navigator.select(item: unpinnedItems.first)
        } else {
          AppState.shared.navigator.highlightFirst()
        }

        AppState.shared.popup.needsResize = true
      }
    }
  }

  var pressedShortcutItem: HistoryItemDecorator? {
    guard let event = NSApp.currentEvent else {
      return nil
    }

    let modifierFlags = event.modifierFlags
      .intersection(.deviceIndependentFlagsMask)
      .subtracting(.capsLock)

    guard HistoryItemAction(modifierFlags) != .unknown else {
      return nil
    }

    let key = Sauce.shared.key(for: Int(event.keyCode))
    return items.first { $0.shortcuts.contains(where: { $0.key == key }) }
  }

  private let search = Search()
  private let sorter = Sorter()
  private let throttler = Throttler(minimumDelay: 0.2)

  @ObservationIgnored
  private var sessionLog: [Int: HistoryItem] = [:]

  // The distinction between `all` and `items` is the following:
  // - `all` stores all history items, even the ones that are currently hidden by a search
  // - `items` stores only visible history items, updated during a search
  @ObservationIgnored
  var all: [HistoryItemDecorator] = []

  init() {
    Task {
      for await _ in Defaults.updates(.pasteByDefault, initial: false) {
        updateShortcuts()
      }
    }

    Task {
      for await _ in Defaults.updates(.sortBy, initial: false) {
        try? await load()
      }
    }

    Task {
      for await _ in Defaults.updates(.pinTo, initial: false) {
        try? await load()
      }
    }

    Task {
      for await _ in Defaults.updates(.showSpecialSymbols, initial: false) {
        for item in items {
          await updateTitle(item: item, title: item.item.generateTitle())
        }
      }
    }

    Task {
      for await _ in Defaults.updates(.imageMaxHeight, initial: false) {
        for item in items {
          await item.cleanupImages()
        }
      }
    }
  }

  @MainActor
  func load() async throws {
    let descriptor = FetchDescriptor<HistoryItem>()
    let results = try Storage.shared.context.fetch(descriptor)
    all = sorter.sort(results).map { HistoryItemDecorator($0) }
    items = all

    // Heal titles stored with special symbols (⏎/⇥) after the
    // showSpecialSymbols default changed.
    if !Defaults[.showSpecialSymbols] {
      for item in all where item.item.title.contains("⏎") || item.item.title.contains("⇥") {
        updateTitle(item: item, title: item.item.generateTitle())
      }
    }

    limitHistorySize(to: Defaults[.size])

    updateShortcuts()
    // Ensure that panel size is proper *after* loading all items.
    Task {
      AppState.shared.popup.needsResize = true
    }
  }

  @MainActor
  private func limitHistorySize(to maxSize: Int) {
    let unpinned = all.filter(\.isUnpinned)
    if unpinned.count >= maxSize {
      unpinned[maxSize...].forEach(delete)
    }
  }

  @MainActor
  func insertIntoStorage(_ item: HistoryItem) throws {
    logger.info("Inserting item with id '\(item.title)'")
    Storage.shared.context.insert(item)
    Storage.shared.context.processPendingChanges()
    try? Storage.shared.context.save()
  }

  @discardableResult
  @MainActor
  func add(_ item: HistoryItem) -> HistoryItemDecorator {
    if #available(macOS 15.0, *) {
      try? History.shared.insertIntoStorage(item)
    } else {
      // On macOS 14 the history item needs to be inserted into storage directly after creating it.
      // It was already inserted after creation in Clipboard.swift
    }

    // Only in-place modifications (an app rewriting its last copy) are merged
    // synchronously — an O(1) session-log lookup. Regular duplicates are found
    // and merged lazily after the copy so a large history never delays it.
    var removedItemIndex: Int?
    if let existingHistoryItem = isModified(item) {
      // The replaced model is deleted below; abort in-flight dedup scans.
      dedupGeneration += 1
      item.firstCopiedAt = existingHistoryItem.firstCopiedAt
      item.numberOfCopies += existingHistoryItem.numberOfCopies
      item.pin = existingHistoryItem.pin
      item.masked = existingHistoryItem.masked
      item.title = existingHistoryItem.title
      if !item.fromMaccy {
        item.application = existingHistoryItem.application
      }
      logger.info("Removing duplicate item '\(item.title)'")
      removedItemIndex = all.firstIndex(where: { $0.item == existingHistoryItem })
      if let removedItemIndex {
        cleanup(all[removedItemIndex])
      }
      deleteFromStorage(existingHistoryItem)
      if let removedItemIndex {
        all.remove(at: removedItemIndex)
      }
    } else {
      // Capture the title now: the model may be merged away and deleted
      // by lazy deduplication before this task runs.
      let title = item.title
      Task {
        Notifier.notify(body: title, sound: .write)
      }
    }

    // Remove exceeding items. Do this after the item is added to avoid removing something
    // if a duplicate was found as then the size already stayed the same.
    limitHistorySize(to: Defaults[.size] - 1)

    sessionLog[Clipboard.shared.changeCount] = item

    var itemDecorator: HistoryItemDecorator
    if let pin = item.pin {
      itemDecorator = HistoryItemDecorator(item, shortcuts: KeyShortcut.create(character: pin))
      if let removedItemIndex {
        // If pin to bottom -> last element should be inserted to the removedItemIndex - 1
        // Or to the last all array place.
        all.insert(itemDecorator, at: min(removedItemIndex, all.count))
      }
    } else {
      itemDecorator = HistoryItemDecorator(item)

      let sortedItems = sorter.sort(all.map(\.item) + [item])
      if let index = sortedItems.firstIndex(of: item) {
        all.insert(itemDecorator, at: index)
      }

      items = all
      updateUnpinnedShortcuts()
      AppState.shared.popup.needsResize = true

      scheduleDeduplication(of: itemDecorator)
    }

    return itemDecorator
  }

  // MARK: - Lazy deduplication

  // Deduplication runs after the copy has already landed in the history so the
  // copy path stays O(1) even with tens of thousands of items. Tasks are
  // chained to run one at a time; tests await `dedupTask`.
  @ObservationIgnored
  private(set) var dedupTask: Task<Void, Never>?

  // Bumped whenever the whole history is replaced (load/clear) so in-flight
  // scans abort instead of touching deleted models.
  @ObservationIgnored
  private var dedupGeneration = 0

  @MainActor
  private func scheduleDeduplication(of decorator: HistoryItemDecorator) {
    dedupTask = Task(priority: .utility) { [previousTask = dedupTask] in
      await previousTask?.value
      await self.deduplicate(decorator)
    }
  }

  @MainActor
  private func deduplicate(_ decorator: HistoryItemDecorator) async {
    let item = decorator.item
    let generation = dedupGeneration

    // Resolve the row by its model: a reload recreates all decorators, but
    // the underlying items stay the same. A missing row was deleted or
    // already merged — its model must not be touched then.
    guard let position = all.firstIndex(where: { $0.item === item }) else {
      return
    }

    let text = item.text

    // Only rows older than (after) the fresh copy are candidates, so two
    // pending scans can never fold the same pair in opposite directions.
    var duplicateItem: HistoryItem?
    var scanned = 0
    for candidate in all[(position + 1)...] {
      // Yield periodically so a long scan never blocks the UI.
      if scanned.isMultiple(of: 512) {
        await Task.yield()
        guard generation == dedupGeneration else {
          return
        }
      }
      scanned += 1

      let candidateItem = candidate.item
      guard candidateItem !== item else { continue }

      if let text, !text.isEmpty {
        if candidateItem.text == text {
          duplicateItem = candidateItem
          break
        }
      } else if candidateItem.supersedes(item) {
        duplicateItem = candidateItem
        break
      }
    }

    // Re-resolve both rows — either may have been deleted, merged, or had
    // its decorator recreated while the scan was yielding.
    guard generation == dedupGeneration,
          let duplicateItem,
          let fresh = all.first(where: { $0.item === item }),
          let old = all.first(where: { $0.item === duplicateItem }),
          fresh != old else {
      return
    }

    merge(old, into: fresh)
  }

  // Folds the older duplicate row into the freshly copied one — the same
  // semantics the upstream synchronous dedup had: the fresh copy survives
  // at the top and inherits the old row's pin, mask, title and history.
  @MainActor
  private func merge(_ oldDecorator: HistoryItemDecorator, into survivor: HistoryItemDecorator) {
    let oldItem = oldDecorator.item
    let newItem = survivor.item

    // Exact duplicates reuse the stored contents; a text duplicate with
    // different formats keeps the latest copy's formats.
    if oldItem.supersedes(newItem) {
      deleteContents(of: newItem)
      newItem.contents = oldItem.contents
      oldItem.contents = []
    }

    newItem.firstCopiedAt = min(oldItem.firstCopiedAt, newItem.firstCopiedAt)
    newItem.lastCopiedAt = max(oldItem.lastCopiedAt, newItem.lastCopiedAt)
    newItem.numberOfCopies += oldItem.numberOfCopies
    newItem.pin = oldItem.pin
    newItem.masked = newItem.masked || oldItem.masked
    newItem.title = oldItem.title
    if !newItem.fromMaccy {
      newItem.application = oldItem.application
    }
    survivor.title = newItem.title
    survivor.isMasked = newItem.masked

    for (key, value) in sessionLog where value === oldItem {
      sessionLog[key] = newItem
    }

    cleanup(oldDecorator)
    withLogging("Merging duplicate item") {
      deleteFromStorage(oldItem)
      Storage.shared.context.processPendingChanges()
      try? Storage.shared.context.save()
    }
    all.removeAll { $0.item === oldItem }
    items.removeAll { $0.item === oldItem }

    // An inherited pin brings the shortcut along and may re-sort the row.
    if let pin = newItem.pin {
      survivor.shortcuts = KeyShortcut.create(character: pin)
      let sortedItems = sorter.sort(all.map(\.item))
      if let currentIndex = all.firstIndex(of: survivor),
         let newIndex = sortedItems.firstIndex(of: newItem) {
        all.remove(at: currentIndex)
        all.insert(survivor, at: min(newIndex, all.count))
      }
    }

    if searchQuery.isEmpty {
      items = all
    } else {
      // Re-run the active search so the merged row lands in the right place.
      searchQuery = searchQuery
    }

    updateUnpinnedShortcuts()
    AppState.shared.popup.needsResize = true
  }

  @MainActor
  private func withLogging(_ msg: String, _ block: () throws -> Void) rethrows {
    func dataCounts() -> String {
      let historyItemCount = try? Storage.shared.context.fetchCount(FetchDescriptor<HistoryItem>())
      let historyContentCount = try? Storage.shared.context.fetchCount(FetchDescriptor<HistoryItemContent>())
      return "HistoryItem=\(historyItemCount ?? 0) HistoryItemContent=\(historyContentCount ?? 0)"
    }

    logger.info("\(msg) Before: \(dataCounts())")
    try? block()
    logger.info("\(msg) After: \(dataCounts())")
  }

  @MainActor
  func clear() {
    dedupGeneration += 1
    withLogging("Clearing history") {
      all.forEach { item in
        if item.isUnpinned {
          cleanup(item)
        }
      }
      all.removeAll(where: \.isUnpinned)
      sessionLog.removeValues { $0.pin == nil }
      items = all

      try? Storage.shared.context.transaction {
        try? Storage.shared.context.delete(
          model: HistoryItem.self,
          where: #Predicate { $0.pin == nil }
        )
        try? Storage.shared.context.delete(
          model: HistoryItemContent.self,
          where: #Predicate { $0.item?.pin == nil }
        )
      }
      Storage.shared.context.processPendingChanges()
      try? Storage.shared.context.save()
    }

    Clipboard.shared.clear()
    AppState.shared.popup.close()
    Task {
      AppState.shared.popup.needsResize = true
    }
  }

  @MainActor
  func clearAll() {
    dedupGeneration += 1
    withLogging("Clearing all history") {
      all.forEach { item in
        cleanup(item)
      }
      all.removeAll()
      sessionLog.removeAll()
      items = all

      do {
        let context = Storage.shared.context
        try context.transaction {
          // Bulk deletion cannot remove children with live inverse relationships.
          try context.delete(
            model: HistoryItemContent.self,
            where: #Predicate { $0.item == nil }
          )
          try context.delete(model: HistoryItem.self)
          try context.delete(model: HistoryItemContent.self)
        }
      } catch {
        logger.error("Failed to clear storage: \(String(reflecting: error))")
      }
      Storage.shared.context.processPendingChanges()
      try? Storage.shared.context.save()
    }

    Clipboard.shared.clear()
    AppState.shared.popup.close()
    Task {
      AppState.shared.popup.needsResize = true
    }
  }

  @MainActor
  func delete(_ item: HistoryItemDecorator?) {
    guard let item else { return }

    // Abort in-flight dedup scans so they never touch the deleted model.
    dedupGeneration += 1

    cleanup(item)
    withLogging("Removing history item") {
      deleteFromStorage(item.item)
      Storage.shared.context.processPendingChanges()
      try? Storage.shared.context.save()
    }

    all.removeAll { $0 == item }
    items.removeAll { $0 == item }
    sessionLog.removeValues { $0 == item.item }

    updateUnpinnedShortcuts()
    Task {
      AppState.shared.popup.needsResize = true
    }
  }

  @MainActor
  private func deleteFromStorage(_ item: HistoryItem) {
    deleteContents(of: item)
    Storage.shared.context.delete(item)
  }

  @MainActor
  private func deleteContents(of item: HistoryItem) {
    item.contents.forEach(Storage.shared.context.delete)
  }

  @MainActor
  private func cleanup(_ item: HistoryItemDecorator) {
    item.cleanupImages()
  }

  @MainActor
  func select(_ item: HistoryItemDecorator?, flags modifierFlags: NSEvent.ModifierFlags) {
    guard let item else {
      return
    }

    if modifierFlags.isEmpty {
      AppState.shared.popup.close()
      Clipboard.shared.copy(item.item, removeFormatting: Defaults[.removeFormattingByDefault])
      if Defaults[.pasteByDefault] {
        Clipboard.shared.paste()
      }
    } else {
      switch HistoryItemAction(modifierFlags) {
      case .copy:
        AppState.shared.popup.close()
        Clipboard.shared.copy(item.item)
      case .paste:
        AppState.shared.popup.close()
        Clipboard.shared.copy(item.item)
        Clipboard.shared.paste()
      case .pasteWithoutFormatting:
        AppState.shared.popup.close()
        Clipboard.shared.copy(item.item, removeFormatting: true)
        Clipboard.shared.paste()
      case .unknown:
        return
      }
    }

    Task {
      searchQuery = ""
    }
  }

  @MainActor
  func startPasteStack(selection: inout Selection<HistoryItemDecorator>, flags modifierFlags: NSEvent.ModifierFlags) {
    guard AppState.shared.multiSelectionEnabled else { return }
    guard let item = selection.first else { return }
    PasteStack.initializeIfNeeded()

    let stack = PasteStack(items: selection.items, modifierFlags: modifierFlags)
    pasteStack = stack

    logger.info("Initialising PasteStack with \(stack.items.count) items")
    logger.info("Copying \(item.item.title) from PasteStack")

    if modifierFlags.isEmpty {
      AppState.shared.popup.close()
      Clipboard.shared.copy(item.item, removeFormatting: Defaults[.removeFormattingByDefault])
    } else {
      switch HistoryItemAction(modifierFlags) {
      case .copy:
        AppState.shared.popup.close()
        Clipboard.shared.copy(item.item)
      case .paste:
        AppState.shared.popup.close()
        Clipboard.shared.copy(item.item)
      case .pasteWithoutFormatting:
        AppState.shared.popup.close()
        Clipboard.shared.copy(item.item, removeFormatting: true)
        Clipboard.shared.paste()
      case .unknown:
        return
      }
    }

    Task {
      searchQuery = ""
    }
  }

  func handlePasteStack() {
    guard let stack = pasteStack else {
      return
    }

    guard let pasted = stack.items.first else {
      pasteStack = nil
      logger.info("PasteStack is empty")
      return
    }

    logger.info("PasteStack pasted \(pasted.item.title)")

    stack.items.removeFirst()

    guard let item = stack.items.first else {
      pasteStack = nil
      logger.info("PasteStack is empty")
      return
    }

    logger.info("Copying \(item.item.title) from PasteStack. \(stack.items.count) items remaining in stack.")

    Task {
      if stack.modifierFlags.isEmpty {
        await Clipboard.shared.copy(item.item, removeFormatting: Defaults[.removeFormattingByDefault])
      } else {
        switch HistoryItemAction(stack.modifierFlags) {
        case .copy:
          await Clipboard.shared.copy(item.item)
        case .paste:
          await Clipboard.shared.copy(item.item)
        case .pasteWithoutFormatting:
          await Clipboard.shared.copy(item.item, removeFormatting: true)
        case .unknown:
          return
        }
      }
    }
  }

  func interruptPasteStack() {
    guard pasteStack != nil else {
      return
    }
    logger.info("Interrupting PasteStack")
    pasteStack = nil
  }

  @MainActor
  func togglePin(_ item: HistoryItemDecorator?) {
    guard let item else { return }

    item.togglePin()

    // An unpinned item surfaces at the top, like a fresh copy.
    if item.isUnpinned {
      item.item.lastCopiedAt = Date.now
    }

    let sortedItems = sorter.sort(all.map(\.item))
    if let currentIndex = all.firstIndex(of: item),
       let newIndex = sortedItems.firstIndex(of: item.item) {
      all.remove(at: currentIndex)
      all.insert(item, at: newIndex)
    }

    items = all

    searchQuery = ""
    updateUnpinnedShortcuts()
    if item.isUnpinned {
      AppState.shared.navigator.scrollTarget = item.id
    }
  }

  private func isModified(_ item: HistoryItem) -> HistoryItem? {
    if let modified = item.modified, sessionLog.keys.contains(modified) {
      return sessionLog[modified]
    }

    return nil
  }

  private func updateItems(_ newItems: [Search.SearchResult]) {
    items = newItems.map { result in
      let item = result.object
      item.highlight(searchQuery, result.ranges)

      return item
    }

    updateUnpinnedShortcuts()
  }

  private func updateShortcuts() {
    for item in pinnedItems {
      if let pin = item.item.pin {
        item.shortcuts = KeyShortcut.create(character: pin)
      }
    }

    updateUnpinnedShortcuts()
  }

  @MainActor
  private func updateTitle(item: HistoryItemDecorator, title: String) {
    item.title = title
    item.item.title = title
  }

  private func updateUnpinnedShortcuts() {
    let visibleUnpinnedItems = unpinnedItems.filter(\.isVisible)
    for item in visibleUnpinnedItems {
      item.shortcuts = []
    }

    var index = 1
    for item in visibleUnpinnedItems.prefix(9) {
      item.shortcuts = KeyShortcut.create(character: String(index))
      index += 1
    }
  }
}
