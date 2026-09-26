import Foundation
import SafetyServices

#if canImport(UIKit)
import UIKit
#endif

/// The device battery level, included in an alert so a contact knows how long the
/// phone may keep working.
struct DeviceBattery: BatteryReading {
    var fraction: Double? {
        #if canImport(UIKit)
        // Monitoring has to be enabled before the level is readable, and the
        // simulator reports -1 regardless.
        MainActor.assumeIsolated {
            UIDevice.current.isBatteryMonitoringEnabled = true
            let level = UIDevice.current.batteryLevel
            return level < 0 ? nil : Double(level)
        }
        #else
        nil
        #endif
    }
}
