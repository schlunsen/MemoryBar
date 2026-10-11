import XCTest
@testable import MetricsCore

final class MetricsTests: XCTestCase {
    func testCPUUsesIntervalRatherThanLifetimeCounters() {
        let previous = CPUTicks(user: 1000, system: 2000, idle: 3000, nice: 100)
        let current = CPUTicks(user: 1010, system: 2020, idle: 3070, nice: 100)
        XCTAssertEqual(Metrics.cpuPercent(previous: previous, current: current)!, 30, accuracy: 0.001)
    }

    func testCPUFirstAndEmptySamplesAreUnavailable() {
        let ticks = CPUTicks(user: 1, system: 2, idle: 3, nice: 4)
        XCTAssertNil(Metrics.cpuPercent(previous: nil, current: ticks))
        XCTAssertNil(Metrics.cpuPercent(previous: ticks, current: ticks))
    }

    func testCPUCounterWrapIsHandled() {
        let previous = CPUTicks(user: .max - 4, system: 0, idle: 10, nice: 0)
        let current = CPUTicks(user: 5, system: 0, idle: 20, nice: 0)
        XCTAssertEqual(Metrics.cpuPercent(previous: previous, current: current)!, 50, accuracy: 0.001)
    }

    func testCPUCounterResetIsUnavailableInsteadOfMisleadingSpike() {
        let previous = CPUTicks(user: 100, system: 100, idle: 100, nice: 0)
        let current = CPUTicks(user: 1, system: 1, idle: 1, nice: 0)
        XCTAssertNil(Metrics.cpuPercent(previous: previous, current: current))
    }

    func testMemoryExcludesReclaimablePagesAndIncludesPhysicalCompressor() {
        let used = Metrics.memoryUsed(active: 100, inactive: 50, purgeable: 10, external: 40,
                                      wired: 20, compressor: 5, pageSize: 16_384, physical: 8_000_000)
        XCTAssertEqual(used, 125 * 16_384)
    }

    func testTransientMemorySnapshotsDoNotUnderflowOrExceedPhysicalRAM() {
        XCTAssertEqual(Metrics.memoryUsed(active: 1, inactive: 1, purgeable: 10, external: 20,
                                         wired: 3, compressor: 2, pageSize: 4096, physical: 1_000_000), 5 * 4096)
        XCTAssertEqual(Metrics.memoryUsed(active: 1000, inactive: 1000, purgeable: 0, external: 0,
                                         wired: 100, compressor: 10, pageSize: 16_384, physical: 1000), 1000)
    }
}
