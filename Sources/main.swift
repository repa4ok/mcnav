import Cocoa
import ApplicationServices

// Single instance check
let dominated = NSRunningApplication.runningApplications(withBundleIdentifier: "com.mcnav.app")
    .contains { $0 != .current && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
if dominated {
    let alert = NSAlert()
    alert.messageText = "MCNav is already running"
    alert.runModal()
    exit(0)
}

var currentPos: CGPoint? = nil

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

struct Window {
    let id: CGWindowID
    let center: CGPoint
}

func getWindows() -> [Window] {
    guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return [] }

    let regularAppPIDs = Set(NSWorkspace.shared.runningApplications
        .filter { $0.activationPolicy == .regular }
        .map { $0.processIdentifier })

    var windows: [Window] = []
    for w in list {
        guard let id = w[kCGWindowNumber as String] as? CGWindowID,
              let pid = w[kCGWindowOwnerPID as String] as? pid_t,
              let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
              let bounds = w[kCGWindowBounds as String] as? [String: CGFloat],
              let x = bounds["X"], let y = bounds["Y"],
              let width = bounds["Width"], let height = bounds["Height"],
              regularAppPIDs.contains(pid),
              // Filter out auxiliary UI like status bars (e.g. Safari's ~20px tall URL preview bar)
              width > 50, height > 50 else { continue }

        windows.append(Window(id: id, center: CGPoint(x: x + width/2, y: y + height/2)))
    }
    return windows
}

func getFocusedWindowID() -> CGWindowID? {
    guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
    let axApp = AXUIElementCreateApplication(app.processIdentifier)
    var window: CFTypeRef?
    guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &window) == .success else { return nil }
    var windowID: CGWindowID = 0
    _ = _AXUIElementGetWindow(window as! AXUIElement, &windowID)
    return windowID
}

func moveMouse(to point: CGPoint) {
    CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
}

func clickMouse(at point: CGPoint) {
    CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
}

func findNearest(from pos: CGPoint, direction: String) -> CGPoint? {
    let windows = getWindows()
    var best: CGPoint? = nil
    var bestScore = CGFloat.infinity

    for w in windows {
        let dx = w.center.x - pos.x, dy = w.center.y - pos.y

        switch direction {
        case "left" where dx >= -10, "right" where dx <= 10, "up" where dy >= -10, "down" where dy <= 10: continue
        default: break
        }

        let score = (direction == "left" || direction == "right") ? abs(dx) + abs(dy) * 2 : abs(dy) + abs(dx) * 2
        if score < bestScore { bestScore = score; best = w.center }
    }
    return best
}

let directions: [Int64: String] = [123: "left", 124: "right", 125: "down", 126: "up"]

func eventCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if [.leftMouseDown, .rightMouseDown, .otherMouseDown].contains(type) {
        currentPos = nil
        return Unmanaged.passUnretained(event)
    }

    guard type == .keyDown else { return Unmanaged.passUnretained(event) }
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags.rawValue

    // Ctrl+Up: activate
    if keyCode == 126 && (flags & (1 << 18)) != 0 {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard let focusedID = getFocusedWindowID(),
                  let thumbnail = getWindows().first(where: { $0.id == focusedID }) else { return }
            currentPos = thumbnail.center
            moveMouse(to: currentPos!)
        }
        return Unmanaged.passUnretained(event)
    }

    // Not in nav mode or non-nav key: exit
    guard currentPos != nil else { return Unmanaged.passUnretained(event) }
    guard [123, 124, 125, 126, 36, 53].contains(keyCode) else {
        currentPos = nil
        return Unmanaged.passUnretained(event)
    }

    // Arrow keys: navigate
    if let dir = directions[keyCode], let next = findNearest(from: currentPos!, direction: dir) {
        currentPos = next
        moveMouse(to: next)
        return nil
    }

    // Enter: click
    if keyCode == 36 {
        clickMouse(at: currentPos!)
        currentPos = nil
        return nil
    }

    // Escape: cancel
    if keyCode == 53 { currentPos = nil }

    return Unmanaged.passUnretained(event)
}

let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.leftMouseDown.rawValue) |
                (1 << CGEventType.rightMouseDown.rawValue) | (1 << CGEventType.otherMouseDown.rawValue)

guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                   eventsOfInterest: CGEventMask(eventMask), callback: eventCallback, userInfo: nil) else {
    let alert = NSAlert()
    alert.messageText = "Error: Grant Accessibility permissions in System Preferences"
    alert.runModal()
    exit(1)
}

CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
CFRunLoopRun()
