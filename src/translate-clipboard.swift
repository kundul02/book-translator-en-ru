import AppKit
import Foundation

// MARK: - Google Translate API

enum TranslateError: Error {
    case network(String)
    case badResponse
}

// Strict form encoding: URLComponents leaves "+" unescaped, which the server reads as a space ("C++" -> "C  ")
private let queryAllowed: CharacterSet = {
    var cs = CharacterSet.alphanumerics
    cs.insert(charactersIn: "-._~")
    return cs
}()

private func encodeQuery(_ s: String) -> String {
    s.addingPercentEncoding(withAllowedCharacters: queryAllowed) ?? s
}

// Keep each GET request well under URL length limits
let maxChunkLength = 1500

func splitIntoChunks(_ text: String, maxLength: Int = maxChunkLength) -> [String] {
    var chunks: [String] = []
    var rest = Substring(text)
    while rest.count > maxLength {
        let limit = rest.index(rest.startIndex, offsetBy: maxLength)
        let window = rest[..<limit]
        // Prefer breaking after a sentence end, then after whitespace, else hard cut
        let breakAt = window.lastIndex(where: { ".!?\n".contains($0) })
            ?? window.lastIndex(where: { $0.isWhitespace })
        let cut = breakAt.map { rest.index(after: $0) } ?? limit
        chunks.append(String(rest[..<cut]))
        rest = rest[cut...]
    }
    if !rest.isEmpty { chunks.append(String(rest)) }
    return chunks
}

func translateChunk(_ text: String) -> Result<String, TranslateError> {
    let query = "client=gtx&sl=auto&tl=ru&dt=t&q=" + encodeQuery(text)
    guard let url = URL(string: "https://translate.googleapis.com/translate_a/single?" + query) else {
        return .failure(.badResponse)
    }
    var request = URLRequest(url: url)
    request.timeoutInterval = 10

    let sem = DispatchSemaphore(value: 0)
    var result: Result<String, TranslateError> = .failure(.badResponse)
    URLSession.shared.dataTask(with: request) { data, response, error in
        defer { sem.signal() }
        if let error {
            result = .failure(.network(error.localizedDescription))
            return
        }
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            result = .failure(.network("HTTP \(http.statusCode)"))
            return
        }
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let sentences = json.first as? [[Any]]
        else { return }
        result = .success(sentences.compactMap { $0.first as? String }.joined())
    }.resume()
    sem.wait()
    return result
}

func translateText(_ text: String) -> Result<String, TranslateError> {
    var parts: [String] = []
    for chunk in splitIntoChunks(text) {
        let trimmed = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { continue }
        switch translateChunk(trimmed) {
        case .success(let t): parts.append(t)
        case .failure(let e): return .failure(e)
        }
    }
    return .success(parts.joined(separator: " "))
}

// MARK: - Simulate Cmd+C

func simulateCopy() {
    let src = CGEventSource(stateID: CGEventSourceStateID.hidSystemState)

    // Key down: Cmd + C
    let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: true)  // 0x08 = 'c'
    keyDown?.flags = CGEventFlags.maskCommand
    keyDown?.post(tap: CGEventTapLocation.cghidEventTap)

    // Key up
    let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: false)
    keyUp?.flags = CGEventFlags.maskCommand
    keyUp?.post(tap: CGEventTapLocation.cghidEventTap)
}

// MARK: - Clipboard snapshot (all types, not just plain text)

func snapshotPasteboard(_ pb: NSPasteboard) -> [NSPasteboardItem] {
    (pb.pasteboardItems ?? []).map { item in
        let copy = NSPasteboardItem()
        for type in item.types {
            if let data = item.data(forType: type) {
                copy.setData(data, forType: type)
            }
        }
        return copy
    }
}

func restorePasteboard(_ pb: NSPasteboard, items: [NSPasteboardItem]) {
    pb.clearContents()
    if !items.isEmpty {
        pb.writeObjects(items)
    }
}

// MARK: - Apple Books selection menu

let booksBundleID = "com.apple.iBooksX"

func axAttribute(_ el: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(el, name as CFString, &value) == .success ? value : nil
}

// The selection menu sits near the top of the window tree (depth 2); its submenus are deeper
func findSelectionMenu(in app: AXUIElement) -> AXUIElement? {
    guard let window = axAttribute(app, kAXFocusedWindowAttribute) else { return nil }
    var queue: [(AXUIElement, Int)] = [(window as! AXUIElement, 0)]
    while !queue.isEmpty {
        let (el, depth) = queue.removeFirst()
        if axAttribute(el, kAXRoleAttribute) as? String == kAXMenuRole { return el }
        if depth < 3, let kids = axAttribute(el, kAXChildrenAttribute) as? [AXUIElement] {
            queue.append(contentsOf: kids.map { ($0, depth + 1) })
        }
    }
    return nil
}

// Books pops up its highlight/notes menu after every selection. Close it via
// Accessibility (AXCancel) rather than sending Esc, which could exit full screen.
// Keeps polling briefly because the menu may appear after the copy finishes.
func dismissBooksMenu(attempts: Int = 40) {
    guard let front = NSWorkspace.shared.frontmostApplication,
          front.bundleIdentifier == booksBundleID else { return }
    let app = AXUIElementCreateApplication(front.processIdentifier)
    AXUIElementSetMessagingTimeout(app, 0.2)
    if let menu = findSelectionMenu(in: app) {
        AXUIElementPerformAction(menu, kAXCancelAction as CFString)
    }
    guard attempts > 0 else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.015) {
        dismissBooksMenu(attempts: attempts - 1)
    }
}

// Closes the menu the instant Books reports it opened, instead of waiting for the next poll.
// Armed only right after a selection so the right-click context menu keeps working.
final class BooksMenuObserver {
    private var observer: AXObserver?
    private var pid: pid_t = 0
    private var armedUntil = Date.distantPast

    func arm() {
        attachIfNeeded()
        armedUntil = Date().addingTimeInterval(0.7)
    }

    private func attachIfNeeded() {
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.bundleIdentifier == booksBundleID,
              front.processIdentifier != pid else { return }
        detach()

        let callback: AXObserverCallback = { _, element, _, refcon in
            guard let refcon else { return }
            let me = Unmanaged<BooksMenuObserver>.fromOpaque(refcon).takeUnretainedValue()
            guard Date() < me.armedUntil else { return }
            AXUIElementPerformAction(element, kAXCancelAction as CFString)
        }
        var obs: AXObserver?
        guard AXObserverCreate(front.processIdentifier, callback, &obs) == .success, let obs else { return }
        let app = AXUIElementCreateApplication(front.processIdentifier)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard AXObserverAddNotification(obs, app, kAXMenuOpenedNotification as CFString, refcon) == .success else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
        observer = obs
        pid = front.processIdentifier
    }

    private func detach() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        observer = nil
        pid = 0
    }
}

// MARK: - Popup Window

class PopupController: NSObject, NSWindowDelegate {
    let panel: NSPanel
    let textView: NSTextView

    override init() {
        let font = NSFont.systemFont(ofSize: 15, weight: .regular)
        let maxW: CGFloat = 520
        let maxH: CGFloat = 420
        let pad:  CGFloat = 20

        let screen = NSScreen.main?.visibleFrame ?? .zero
        let x = screen.maxX - maxW - 30
        let y = screen.maxY - maxH - 30

        panel = NSPanel(
            contentRect: NSRect(x: x, y: y, width: maxW, height: 100),
            styleMask: [.titled, .closable, .resizable, .hudWindow, .utilityWindow, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.title = "Перевод"
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.becomesKeyOnlyIfNeeded = true
        panel.minSize = NSSize(width: 200, height: 80)

        let bounds = panel.contentView!.bounds
        let scroll = NSScrollView(frame: NSRect(x: pad, y: pad, width: bounds.width - pad*2, height: bounds.height - pad*2))
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder

        textView = NSTextView(frame: NSRect(origin: .zero, size: scroll.contentSize))
        textView.minSize = NSSize(width: 0, height: scroll.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.isEditable = false; textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = font; textView.textColor = .white
        textView.string = "Выделите текст в книге..."
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.autoresizingMask = [.width]
        scroll.documentView = textView

        let btnPlus = NSButton(frame: NSRect(x: bounds.width - pad - 25, y: 5, width: 25, height: 25))
        btnPlus.title = "+"
        btnPlus.bezelStyle = .inline
        btnPlus.autoresizingMask = [.minXMargin, .maxYMargin]
        btnPlus.action = #selector(increaseFont)

        let btnMinus = NSButton(frame: NSRect(x: bounds.width - pad - 55, y: 5, width: 25, height: 25))
        btnMinus.title = "-"
        btnMinus.bezelStyle = .inline
        btnMinus.autoresizingMask = [.minXMargin, .maxYMargin]
        btnMinus.action = #selector(decreaseFont)

        panel.contentView!.addSubview(scroll)
        panel.contentView!.addSubview(btnPlus)
        panel.contentView!.addSubview(btnMinus)

        super.init()
        
        btnPlus.target = self
        btnMinus.target = self
        panel.delegate = self
    }

    @objc func increaseFont() {
        changeFontSize(by: 2)
    }

    @objc func decreaseFont() {
        changeFontSize(by: -2)
    }

    func changeFontSize(by delta: CGFloat) {
        let currentSize = textView.font?.pointSize ?? 15
        let newSize = max(10, min(36, currentSize + delta))
        textView.font = NSFont.systemFont(ofSize: newSize, weight: .regular)
        update(translated: textView.string)
    }

    func update(translated: String) {
        textView.string = translated

        let font = textView.font ?? NSFont.systemFont(ofSize: 15)
        let maxH: CGFloat = 420
        let pad:  CGFloat = 20
        let textSize = (translated as NSString).boundingRect(
            with: NSSize(width: panel.frame.width - pad * 2 - 10, height: 10000),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        ).size
        let newH = min(textSize.height + 80, maxH)
        var frame = panel.frame
        let topEdge = frame.origin.y + frame.size.height
        frame.size.height = newH
        frame.origin.y = topEdge - newH
        panel.setFrame(frame, display: true, animate: true)

        show()
    }

    func show() {
        if !panel.isVisible {
            panel.orderFront(nil)
        }
    }

    func windowWillClose(_ n: Notification) {
        NSApp.terminate(nil)
    }
}

// MARK: - Mouse-up watcher: detect when user finishes selecting text

class SelectionWatcher {
    let popup: PopupController
    var lastText: String = ""
    var monitors: [Any] = []
    var mouseDownLocation: NSPoint = .zero
    var debounceTimer: Timer?
    var checking = false
    // Incremented per request so a slow, outdated translation never overwrites a newer one
    var requestID = 0
    // Hold Option while selecting to keep the Books menu (e.g. to add a highlight)
    var keepBooksMenu = false
    let booksMenuObserver = BooksMenuObserver()

    init(popup: PopupController) {
        self.popup = popup
    }

    func start() {
        // Watch mouse events globally (in other apps like Books)
        if let m = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown], handler: { [weak self] _ in
            self?.mouseDownLocation = NSEvent.mouseLocation
        }) { monitors.append(m) }

        if let m = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp], handler: { [weak self] event in
            guard let self, self.isSelectionGesture(event) else { return }
            self.keepBooksMenu = event.modifierFlags.contains(.option)
            // Close the Books menu right away instead of after the copy to shorten its flash
            if !self.keepBooksMenu {
                self.booksMenuObserver.arm()
                dismissBooksMenu()
            }
            // Debounce: wait a moment for the selection to settle
            self.debounceTimer?.invalidate()
            self.debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                self?.checkSelection()
            }
        }) { monitors.append(m) }
    }

    // Only drag, double/triple click or shift-click can select text; plain clicks
    // must not send Cmd+C (e.g. in Finder it would copy the clicked file)
    func isSelectionGesture(_ event: NSEvent) -> Bool {
        let up = NSEvent.mouseLocation
        let moved = hypot(up.x - mouseDownLocation.x, up.y - mouseDownLocation.y) > 4
        return moved || event.clickCount >= 2 || event.modifierFlags.contains(.shift)
    }

    func checkSelection() {
        guard !checking else { return }
        checking = true

        // Save current clipboard to restore after copying the selection
        let pb = NSPasteboard.general
        let saved = snapshotPasteboard(pb)
        let savedCount = pb.changeCount

        // Simulate Cmd+C to copy selected text
        simulateCopy()

        // Poll without blocking the main thread; some apps update the clipboard slowly
        waitForClipboard(pb, since: savedCount, attempts: 15) { [weak self] changed in
            guard let self else { return }
            self.checking = false
            guard changed else { return }
            if !self.keepBooksMenu {
                dismissBooksMenu()
            }
            let rawText = pb.string(forType: .string)
            restorePasteboard(pb, items: saved)
            if let rawText {
                self.handle(rawText: rawText)
            }
        }
    }

    func waitForClipboard(_ pb: NSPasteboard, since count: Int, attempts: Int, completion: @escaping (Bool) -> Void) {
        if pb.changeCount != count { return completion(true) }
        guard attempts > 0 else { return completion(false) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
            self?.waitForClipboard(pb, since: count, attempts: attempts - 1, completion: completion)
        }
    }

    func handle(rawText: String) {
        let text = cleanBooksCitation(rawText)
        guard !text.isEmpty else { return }

        // Same selection again (e.g. after hiding the popup with Esc) - just show it
        guard text != lastText else {
            popup.show()
            return
        }

        // Only translate if contains Latin characters
        guard text.range(of: "[a-zA-Z]{2,}", options: .regularExpression) != nil else { return }

        lastText = text
        requestID += 1
        let id = requestID

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = translateText(text)
            DispatchQueue.main.async {
                guard let self, id == self.requestID else { return }
                switch result {
                case .success(let translated):
                    self.popup.update(translated: translated)
                case .failure(let error):
                    // Allow retrying the same selection
                    self.lastText = ""
                    let reason: String
                    switch error {
                    case .network(let msg): reason = msg
                    case .badResponse: reason = "неожиданный ответ сервера"
                    }
                    self.popup.update(translated: "Ошибка перевода: \(reason)")
                }
            }
        }
    }
}

// Clean up Apple Books citations and surrounding quotes
func cleanBooksCitation(_ raw: String) -> String {
    var text = raw
    for marker in ["Отрывок из книги", "Excerpt From"] {
        if let range = text.range(of: marker) {
            text = String(text[..<range.lowerBound])
        }
    }
    text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    for (open, close) in [("«", "»"), ("“", "”"), ("\"", "\"")] where text.count >= 2 {
        if text.hasPrefix(open) && text.hasSuffix(close) {
            text = String(text.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    return text
}

// MARK: - Escape key handler

class KeyHandler {
    var monitor: Any?
    init(popup: PopupController) {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                popup.panel.orderOut(nil)
                return nil
            }
            return event
        }
    }
}

// MARK: - App delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    let popup: PopupController
    init(popup: PopupController) { self.popup = popup }

    // Launching the app again while it runs (it has no Dock icon) brings back a hidden panel
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        popup.show()
        return false
    }
}

// Two running copies would both send Cmd+C on every selection; the newest one wins
func terminateOtherInstances() {
    let me = ProcessInfo.processInfo.processIdentifier
    let names: Set = ["TranslatePopup", "translate-clipboard"]
    for other in NSWorkspace.shared.runningApplications where other.processIdentifier != me {
        let sameBundle = other.bundleIdentifier != nil && other.bundleIdentifier == Bundle.main.bundleIdentifier
        let sameName = other.executableURL.map { names.contains($0.lastPathComponent) } ?? false
        if sameBundle || sameName {
            other.terminate()
        }
    }
}

// MARK: - Main

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
terminateOtherInstances()

let popup = PopupController()
let appDelegate = AppDelegate(popup: popup)
app.delegate = appDelegate

// Posting Cmd+C to other apps requires Accessibility permission
let axOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
if !AXIsProcessTrustedWithOptions(axOptions) {
    popup.textView.string = "Разрешите доступ: Системные настройки → Конфиденциальность и безопасность → Универсальный доступ → включите TranslatePopup."
    // Pick up the permission as soon as it is granted, no restart needed
    Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
        guard AXIsProcessTrusted() else { return }
        timer.invalidate()
        popup.update(translated: "Выделите текст в книге...")
    }
}
let watcher = SelectionWatcher(popup: popup)
let keyHandler = KeyHandler(popup: popup)
_ = keyHandler

popup.panel.orderFront(nil)
watcher.start()
app.run()
