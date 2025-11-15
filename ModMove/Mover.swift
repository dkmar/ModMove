import AppKit
import Foundation

enum ResizeCorner {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

final class Mover {
    var state: FlagState = .Ignore {
        didSet {
            if self.state != oldValue {
                self.changed(state: self.state)
            }
        }
    }

    private var monitor: Any?
    private var lastMousePosition: CGPoint?
    private var window: AccessibilityElement?
    private var resizeCorner: ResizeCorner?
    private var initialWindowFrame: CGRect?

    private func mouseMoved(handler: (_ window: AccessibilityElement, _ mouseDelta: CGPoint) -> Void) {
        let point = Mouse.currentPosition()
        if self.window == nil {
            self.window = AccessibilityElement.systemWideElement.element(at: point)?.window()
        }

        guard let window = self.window else {
            return
        }

        let currentPid = NSRunningApplication.current.processIdentifier
        if let pid = window.pid(), pid != currentPid {
            NSRunningApplication(processIdentifier: pid)?.activate(options: .activateIgnoringOtherApps)
        }

        window.bringToFront()
        if let lastPosition = self.lastMousePosition {
            let mouseDelta = CGPoint(x: lastPosition.x - point.x, y: lastPosition.y - point.y)
            handler(window, mouseDelta)
        }

        self.lastMousePosition = point
    }

    private func determineClosestCorner(mousePosition: CGPoint, windowFrame: CGRect) -> ResizeCorner {
        let corners: [(ResizeCorner, CGPoint)] = [
            (.topLeft, CGPoint(x: windowFrame.minX, y: windowFrame.minY)),
            (.topRight, CGPoint(x: windowFrame.maxX, y: windowFrame.minY)),
            (.bottomLeft, CGPoint(x: windowFrame.minX, y: windowFrame.maxY)),
            (.bottomRight, CGPoint(x: windowFrame.maxX, y: windowFrame.maxY))
        ]

        let closestCorner = corners.min { corner1, corner2 in
            let dist1 = hypot(mousePosition.x - corner1.1.x, mousePosition.y - corner1.1.y)
            let dist2 = hypot(mousePosition.x - corner2.1.x, mousePosition.y - corner2.1.y)
            return dist1 < dist2
        }

        return closestCorner?.0 ?? .bottomRight
    }

    private func resizeWindow(window: AccessibilityElement, mouseDelta: CGPoint) {
        guard let position = window.position, let size = window.size else {
            return
        }

        // Initialize resize corner on first move
        if resizeCorner == nil {
            let frame = CGRect(origin: position, size: size)
            let mousePos = Mouse.currentPosition()
            resizeCorner = determineClosestCorner(mousePosition: mousePos, windowFrame: frame)
            initialWindowFrame = frame
        }

        guard let corner = resizeCorner else {
            return
        }

        var newPosition = position
        var newSize = size

        switch corner {
        case .bottomRight:
            // Resize from bottom-right (expand right and down)
            newSize = CGSize(width: size.width - mouseDelta.x, height: size.height - mouseDelta.y)

        case .bottomLeft:
            // Resize from bottom-left (expand left and down)
            newSize = CGSize(width: size.width + mouseDelta.x, height: size.height - mouseDelta.y)
            newPosition = CGPoint(x: position.x - mouseDelta.x, y: position.y)

        case .topRight:
            // Resize from top-right (expand right and up)
            newSize = CGSize(width: size.width - mouseDelta.x, height: size.height + mouseDelta.y)
            newPosition = CGPoint(x: position.x, y: position.y - mouseDelta.y)

        case .topLeft:
            // Resize from top-left (expand left and up)
            newSize = CGSize(width: size.width + mouseDelta.x, height: size.height + mouseDelta.y)
            newPosition = CGPoint(x: position.x - mouseDelta.x, y: position.y - mouseDelta.y)
        }

        // Ensure minimum window size
        newSize.width = max(newSize.width, 100)
        newSize.height = max(newSize.height, 100)

        window.position = newPosition
        window.size = newSize
    }

    private func moveWindow(window: AccessibilityElement, mouseDelta: CGPoint) {
        if let position = window.position {
            let newPosition = CGPoint(x: position.x - mouseDelta.x, y: position.y - mouseDelta.y)
            window.position = newPosition
        }
    }

    private func changed(state: FlagState) {
        self.removeMonitor()

        switch state {
        case .Resize:
            self.monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { _ in
                self.mouseMoved(handler: self.resizeWindow)
            }
        case .Drag:
            self.monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { _ in
                self.mouseMoved(handler: self.moveWindow)
            }
        case .Ignore:
            self.lastMousePosition = nil
            self.window = nil
            self.resizeCorner = nil
            self.initialWindowFrame = nil
        }
    }

    private func removeMonitor() {
        if let monitor = self.monitor {
            NSEvent.removeMonitor(monitor)
        }
        self.monitor = nil
    }

    deinit {
        self.removeMonitor()
    }
}
