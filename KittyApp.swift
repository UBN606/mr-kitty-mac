import AppKit
import QuartzCore
import ApplicationServices
import Darwin

private final class KittyImageView: NSImageView {
    var onClick: (() -> Void)?
    var onTrick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.option) {
            onTrick?()
        } else if event.clickCount == 1 {
            onClick?()
            window?.performDrag(with: event)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        let quitItem = menu.addItem(withTitle: "Quit Mr. Kitty", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}

private final class KittyApp: NSObject, NSApplicationDelegate {
    private var panel: NSPanel!
    private var cat: KittyImageView!
    private var biscuit: NSView!
    private var hint: NSTextField!
    private var timer: Timer?
    private var tick = 0
    private var mode = "idle"
    private var modeStarted = Date()
    private var chatProvider = "ChatGPT"
    private var providerButton: NSButton!
    private let assetRoot = URL(fileURLWithPath: Bundle.main.resourcePath ?? ".")

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1024, height: 768)
        let frame = NSRect(x: screen.maxX - 226, y: screen.minY + 28, width: 210, height: 258)
        panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 210, height: 258))
        content.wantsLayer = true
        panel.contentView = content

        cat = KittyImageView(frame: NSRect(x: 9, y: 48, width: 192, height: 208))
        cat.imageScaling = .scaleProportionallyUpOrDown
        cat.wantsLayer = true
        cat.onClick = { [weak self] in self?.beginWorking() }
        cat.onTrick = { [weak self] in self?.beginTrick() }
        content.addSubview(cat)

        biscuit = NSView(frame: NSRect(x: 164, y: 78, width: 15, height: 11))
        biscuit.wantsLayer = true
        biscuit.layer?.backgroundColor = NSColor(calibratedRed: 0.89, green: 0.61, blue: 0.29, alpha: 1).cgColor
        biscuit.layer?.cornerRadius = 6
        biscuit.layer?.borderWidth = 1.5
        biscuit.layer?.borderColor = NSColor(calibratedRed: 1, green: 0.85, blue: 0.62, alpha: 1).cgColor
        biscuit.isHidden = true
        content.addSubview(biscuit)

        let glass = NSVisualEffectView(frame: NSRect(x: 13, y: 4, width: 184, height: 42))
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.wantsLayer = true
        glass.layer?.cornerRadius = 21
        glass.layer?.masksToBounds = true
        glass.layer?.borderWidth = 1
        glass.layer?.borderColor = NSColor.white.withAlphaComponent(0.5).cgColor
        content.addSubview(glass)

        addButton("✎", tooltip: "Open a small text chat", x: 4, parent: glass, action: #selector(openText))
        addButton("🎙", tooltip: "Open voice chat or dictation", x: 49, parent: glass, action: #selector(openVoice))
        addButton("✦", tooltip: "Trick, then treat", x: 94, parent: glass, action: #selector(trickButton))
        providerButton = addButton("G", tooltip: "Switch between ChatGPT and Claude", x: 139, parent: glass, action: #selector(toggleProvider))

        hint = NSTextField(labelWithString: "")
        hint.frame = NSRect(x: 7, y: 238, width: 196, height: 16)
        hint.alignment = .center
        hint.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        hint.textColor = .white
        hint.isHidden = true
        content.addSubview(hint)

        showFrame("idle", 0)
        panel.orderFrontRegardless()
        timer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in self?.advance() }
    }

    @discardableResult
    private func addButton(_ title: String, tooltip: String, x: CGFloat, parent: NSView, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.frame = NSRect(x: x, y: 3, width: 42, height: 36)
        button.isBordered = false
        button.font = NSFont.systemFont(ofSize: 18)
        button.contentTintColor = .white
        button.toolTip = tooltip
        parent.addSubview(button)
        return button
    }

    private func asset(_ name: String) -> NSImage? {
        NSImage(contentsOf: assetRoot.appendingPathComponent("Assets/\(name).png"))
    }

    private func showFrame(_ name: String, _ index: Int) {
        cat.image = asset("\(name)-\(index)")
    }

    private func beginWorking() {
        guard mode == "idle" else { return }
        mode = "working"
        modeStarted = Date()
        tick = 0
    }

    private func beginTrick() {
        guard mode == "idle" || mode == "working" else { return }
        mode = "trick"
        modeStarted = Date()
        biscuit.isHidden = true
        cat.image = asset("sit")
    }

    @objc private func trickButton(_ sender: Any?) { beginTrick() }

    @objc private func toggleProvider(_ sender: Any?) {
        chatProvider = chatProvider == "ChatGPT" ? "Claude" : "ChatGPT"
        providerButton.title = chatProvider == "ChatGPT" ? "G" : "C"
        showHint("Chat: \(chatProvider)")
    }

    @objc private func openText(_ sender: Any?) { openSmallChat(voice: false) }
    @objc private func openVoice(_ sender: Any?) { openSmallChat(voice: true) }

    private func postKey(_ code: CGKeyCode, flags: CGEventFlags = []) {
        let down = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true)
        down?.flags = flags
        down?.post(tap: .cghidEventTap)
        let up = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false)
        up?.flags = flags
        up?.post(tap: .cghidEventTap)
    }

    private func openSmallChat(voice: Bool) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            showHint("Allow Mr. Kitty in Accessibility")
            return
        }
        if chatProvider == "Claude" { openClaudeQuickEntry(voice: voice) }
        else { openChatBar(voice: voice) }
    }

    private func openChatBar(voice: Bool) {
        guard NSWorkspace.shared.launchApplication("ChatGPT") else {
            showHint("Install and open ChatGPT first")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.postKey(49, flags: .maskAlternate)
            if voice { self.showHint("Tap Voice in the ChatGPT bar") }
        }
    }

    private func openClaudeQuickEntry(voice: Bool) {
        guard NSWorkspace.shared.launchApplication("Claude") else {
            showHint("Install and open Claude Desktop first")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if voice {
                self.postKey(57)
                self.showHint("Speak · Caps Lock again to stop")
            } else {
                self.postKey(58)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { self.postKey(58) }
            }
        }
    }

    private func showHint(_ message: String) {
        hint.stringValue = message
        hint.isHidden = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in self?.hint.isHidden = true }
    }

    private func advance() {
        tick += 1
        let elapsed = Date().timeIntervalSince(modeStarted)
        switch mode {
        case "idle":
            if tick % 8 == 0 { showFrame("idle", (tick / 8) % 6) }
        case "working":
            if tick % 6 == 0 { showFrame("working", (tick / 6) % 6) }
            if elapsed > 1.6 { mode = "idle"; tick = 0; showFrame("idle", 0) }
        case "trick":
            let progress = min(1, elapsed / 1.25)
            cat.layer?.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat.pi * 2 * CGFloat(progress)))
            if elapsed > 1.25 {
                cat.layer?.setAffineTransform(.identity)
                cat.image = asset("curl")
                mode = "rest"
                modeStarted = Date()
            }
        case "rest":
            if elapsed > 0.7 {
                cat.image = asset("sit")
                biscuit.isHidden = false
                mode = "treat"
                modeStarted = Date()
            }
        case "treat":
            let progress = min(1, elapsed / 0.8)
            biscuit.frame.origin = NSPoint(x: CGFloat(164 - 62 * progress), y: CGFloat(78 + 82 * progress))
            if elapsed > 0.8 { biscuit.isHidden = true; mode = "chew"; modeStarted = Date() }
        case "chew":
            cat.layer?.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(sin(elapsed * 30) * 0.035)))
            if elapsed > 0.8 {
                cat.layer?.setAffineTransform(.identity)
                mode = "idle"
                tick = 0
                showFrame("idle", 0)
            }
        default: break
        }
    }

    func runSelfTest() -> Bool {
        guard panel != nil, cat.image != nil, providerButton != nil else { return false }
        guard asset("idle-0") != nil, asset("working-0") != nil,
              asset("sit") != nil, asset("curl") != nil else { return false }
        beginTrick()
        guard mode == "trick" else { return false }
        modeStarted = Date().addingTimeInterval(-1.3)
        advance()
        guard mode == "rest" else { return false }
        modeStarted = Date().addingTimeInterval(-0.8)
        advance()
        guard mode == "treat", !biscuit.isHidden else { return false }
        modeStarted = Date().addingTimeInterval(-0.9)
        advance()
        guard mode == "chew" else { return false }
        modeStarted = Date().addingTimeInterval(-0.9)
        advance()
        return mode == "idle" && biscuit.isHidden
    }

    func applicationWillTerminate(_ notification: Notification) { timer?.invalidate() }
}

@main struct EntryPoint {
    static func main() {
        let app = NSApplication.shared
        let delegate = KittyApp()
        app.delegate = delegate
        if CommandLine.arguments.contains("--self-test") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let passed = delegate.runSelfTest()
                print(passed ? "SELF_TEST_PASS" : "SELF_TEST_FAIL")
                fflush(stdout)
                Darwin.exit(passed ? 0 : 2)
            }
        }
        app.run()
    }
}
