import AppKit
import Foundation

// MARK: - Google Translate API

func translateText(_ text: String) -> String? {
    var comps = URLComponents(string: "https://translate.googleapis.com/translate_a/single")!
    comps.queryItems = [
        URLQueryItem(name: "client", value: "gtx"),
        URLQueryItem(name: "sl", value: "auto"),
        URLQueryItem(name: "tl", value: "ru"),
        URLQueryItem(name: "dt", value: "t"),
        URLQueryItem(name: "q", value: text),
    ]
    guard let url = comps.url else { return nil }

    let sem = DispatchSemaphore(value: 0)
    var result: String?
    URLSession.shared.dataTask(with: url) { data, _, _ in
        defer { sem.signal() }
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let sentences = json.first as? [[Any]]
        else { return }
        result = sentences.compactMap { $0.first as? String }.joined()
    }.resume()
    sem.wait()
    return result
}

// MARK: - Simulate Cmd+C

func simulateCopy() {
    // Save current clipboard to restore if needed
    let src = CGEventSource(stateID: CGEventSourceStateID.hidSystemState)

    // Key down: Cmd + C
    let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: true)  // 0x08 = 'c'
    keyDown?.flags = CGEventFlags.maskCommand
    keyDown?.post(tap: CGEventTapLocation.cghidEventTap)

    // Key up
    let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: false)
    keyUp?.flags = CGEventFlags.maskCommand
    keyUp?.post(tap: CGEventTapLocation.cghidEventTap)

    // Small delay for clipboard to update
    usleep(100_000)  // 100ms
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

        textView = NSTextView(frame: scroll.bounds)
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
    var globalMonitor: Any?
    var translating = false
    var debounceTimer: Timer?

    init(popup: PopupController) {
        self.popup = popup
    }

    func start() {
        // Watch for mouse up events globally (in other apps like Books)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            // Debounce: wait a moment for the selection to settle
            self?.debounceTimer?.invalidate()
            self?.debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                self?.checkSelection()
            }
        }
    }

    func checkSelection() {
        guard !translating else { return }

        // Save current clipboard content
        let pb = NSPasteboard.general
        let savedContent = pb.string(forType: .string)
        let savedCount = pb.changeCount

        // Simulate Cmd+C to copy selected text
        simulateCopy()

        // Check if clipboard changed
        let newCount = pb.changeCount
        guard newCount != savedCount,
              let rawText = pb.string(forType: .string),
              !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return
        }

        // Clean up Apple Books citations
        var text = rawText
        if let range = text.range(of: "Отрывок из книги") {
            text = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let range = text.range(of: "Excerpt From") {
            text = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Remove surrounding quotes if Apple Books added them
        if text.hasPrefix("«") && text.hasSuffix("»") {
            text = String(text.dropFirst().dropLast())
        }
        if text.hasPrefix("\"") && text.hasSuffix("\"") {
            text = String(text.dropFirst().dropLast())
        }

        guard text != lastText else { return }

        // Only translate if contains Latin characters
        guard text.range(of: "[a-zA-Z]{2,}", options: .regularExpression) != nil else { return }

        lastText = text
        translating = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let translated = translateText(text) else {
                DispatchQueue.main.async { self?.translating = false }
                return
            }
            DispatchQueue.main.async {
                self?.popup.update(translated: translated)
                self?.translating = false
            }
        }
    }
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

// MARK: - Main

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let popup = PopupController()
let watcher = SelectionWatcher(popup: popup)
let keyHandler = KeyHandler(popup: popup)
_ = keyHandler

popup.panel.orderFront(nil)
watcher.start()
app.run()
