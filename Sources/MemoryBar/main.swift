import AppKit
import Darwin
import MetricsCore

struct SystemSampler {
    private var previousCPU: CPUTicks?
    private let physicalMemory = ProcessInfo.processInfo.physicalMemory
    private let pageSize: UInt64?

    init() {
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        var size: vm_size_t = 0
        pageSize = host_page_size(host, &size) == KERN_SUCCESS && size > 0 ? UInt64(size) : nil
    }

    mutating func cpu() -> Double? {
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { previousCPU = nil; return nil }
        let current = CPUTicks(user: info.cpu_ticks.0, system: info.cpu_ticks.1,
                               idle: info.cpu_ticks.2, nice: info.cpu_ticks.3)
        defer { previousCPU = current }
        return Metrics.cpuPercent(previous: previousCPU, current: current)
    }

    func memory() -> UInt64? {
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        guard let pageSize else { return nil }
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return Metrics.memoryUsed(active: UInt64(info.active_count), inactive: UInt64(info.inactive_count),
                                  purgeable: UInt64(info.purgeable_count), external: UInt64(info.external_page_count),
                                  wired: UInt64(info.wire_count), compressor: UInt64(info.compressor_page_count),
                                  pageSize: pageSize, physical: physicalMemory)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var item: NSStatusItem!
    private var timer: Timer?
    private var sampler = SystemSampler()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        item.button?.toolTip = "CPU across all cores · estimated memory used · updates every 2 seconds"
        let menu = NSMenu()
        let label = NSMenuItem(title: "MemoryBar · CPU & RAM", action: nil, keyEquivalent: "")
        menu.addItem(label)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit MemoryBar", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
        update()
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        timer.tolerance = 0.25
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func update() {
        let cpu = sampler.cpu().map { String(format: "%3.0f%%", $0) } ?? "  —"
        let memory = sampler.memory().map { String(format: "%.1f GB", Double($0) / 1_000_000_000) } ?? "— GB"
        let title = "CPU \(cpu) · RAM \(memory)"
        if item.button?.title != title { item.button?.title = title }
    }

    @objc private func quitApp() { NSApp.terminate(nil) }

    func applicationWillTerminate(_ notification: Notification) { timer?.invalidate() }
}

if CommandLine.arguments.contains("--smoke-test") {
    // Exercise the same sampler without creating NSApplication or a menu item.
    var sampler = SystemSampler()
    for index in 0..<6 {
        let cpu = sampler.cpu()
        guard let memory = sampler.memory(), index == 0 || cpu != nil else {
            fputs("Kernel metric read failed\n", stderr)
            exit(1)
        }
        print("sample=\(index) cpu=\(cpu.map { String(format: "%.1f", $0) } ?? "warming-up") memory_bytes=\(memory)")
        if index < 5 { Thread.sleep(forTimeInterval: 2) }
    }
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
