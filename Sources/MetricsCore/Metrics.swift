public struct CPUTicks: Sendable {
    public let user: UInt32
    public let system: UInt32
    public let idle: UInt32
    public let nice: UInt32

    public init(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32) {
        self.user = user; self.system = system; self.idle = idle; self.nice = nice
    }
}

public enum Metrics {
    // Kernel tick counters wrap at UInt32.max. CPU is normalized across all cores.
    public static func cpuPercent(previous: CPUTicks?, current: CPUTicks) -> Double? {
        guard let previous else { return nil }
        let user = current.user &- previous.user
        let system = current.system &- previous.system
        let nice = current.nice &- previous.nice
        let idle = current.idle &- previous.idle
        // A reset/backwards counter is not a plausible two-second interval.
        // Small modular differences still correctly handle genuine wraparound.
        let limit = UInt32.max / 2
        guard user <= limit, system <= limit, nice <= limit, idle <= limit else { return nil }
        let busy = UInt64(user) + UInt64(system) + UInt64(nice)
        let total = busy + UInt64(idle)
        guard total > 0 else { return nil }
        return Double(busy) / Double(total) * 100
    }

    // Estimate non-reclaimable memory: anonymous resident pages, wired pages,
    // and the compressor's physical footprint. File-backed and purgeable pages
    // are treated as reclaimable. Saturate inconsistent transient snapshots.
    public static func memoryUsed(active: UInt64, inactive: UInt64,
                                  purgeable: UInt64, external: UInt64,
                                  wired: UInt64, compressor: UInt64,
                                  pageSize: UInt64, physical: UInt64) -> UInt64 {
        let resident = Double(active) + Double(inactive)
        let appPages = max(0, resident - Double(purgeable) - Double(external))
        let bytes = (appPages + Double(wired) + Double(compressor)) * Double(pageSize)
        guard bytes < Double(physical) else { return physical }
        return UInt64(max(0, bytes))
    }
}
