import AppKit
import Foundation

enum FlagState {
    case Resize
    case Drag
    case Ignore
}

final class Observer {
    private var monitor: Any?

    func startObserving(state: @escaping (FlagState) -> Void) {
        self.monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
            state(self.state(for: event.modifierFlags))
        }
    }

    private func state(for flags: NSEvent.ModifierFlags) -> FlagState {
        // lets just check the resizing case: if our flags are exactly Control+Option+Shift.
        let desiredFlags: NSEvent.ModifierFlags  = [.control, .option, .shift]
        let relevantFlags: NSEvent.ModifierFlags = flags.intersection(.deviceIndependentFlagsMask)
        
        if relevantFlags == desiredFlags {
            return .Resize
        } else {
            return .Ignore
        }
    }

    deinit {
        if let monitor = self.monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
