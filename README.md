# MemoryBar

**Your Mac's CPU and memory usage, right in the menu bar.**

A small native Swift/AppKit app with one readout and a Quit menu. No Dock icon or dashboard to manage.

Example readout:

```text
CPU  12% · RAM 8.2 GB
```

### At a glance

- **Live CPU and RAM** — refreshed every two seconds.
- **Native and simple** — reads macOS kernel counters directly, without spawning monitoring commands.
- **Local only** — no network requests, telemetry, accounts, updater, or privileged helper.
- **Easy to leave** — click the menu-bar item and choose **Quit MemoryBar**.

## Get started

Requires **macOS 13 or newer** and **Swift 6+**, supplied by a compatible Xcode or Command Line Tools installation. The build uses your Mac's native architecture. The current build has been tested on Apple Silicon; Intel builds have not been verified.

Clone the repository, build, and open the app:

```sh
git clone https://github.com/schlunsen/MemoryBar.git
cd MemoryBar
sh build.sh
open dist/MemoryBar.app
```

The repository is private, so cloning requires an account with access. The build script creates `dist/MemoryBar.app` and does not launch it. You can also open that bundle in Finder or move it to your Applications folder. Login startup is not enabled automatically.

The app is **ad-hoc signed for local use**, not signed with a Developer ID or notarized for distribution. There is no prebuilt GitHub release; build from source on your Mac. The project has no third-party package dependencies.

## What the numbers mean

| Metric | Meaning |
| --- | --- |
| CPU | Busy CPU time across all cores since the previous sample, normalized to **0–100%**. |
| RAM | Estimated physical memory used, shown in decimal **GB** (1 GB = 1,000,000,000 bytes). |

The RAM estimate includes anonymous resident memory, wired memory, and the compressor's physical footprint. It subtracts file-backed and purgeable pages from active plus inactive pages, then adds wired and compressor pages. Reclaimable caches are excluded, and the result is bounded by physical RAM. Kernel snapshots and accounting differences can cause the result to differ from Activity Monitor.

CPU initially shows a dash while the first interval is collected. Failed reads and invalid CPU intervals also show a dash. Counter wraparound is handled, and sampling resumes on subsequent updates. The timer allows a little scheduling tolerance to reduce wakeups.

## Efficiency

One timer samples every two seconds with 250 ms tolerance. Physical RAM and page size are cached; CPU calculations use scalar counters; Mach host-port references are released after each read. The menu-bar title is updated only when the displayed value changes. There are no background worker loops, subprocesses, network requests, or history buffers during normal operation.

A six-sample, 10-second smoke run of the release sampler on Apple Silicon recorded **7.1 MB peak resident memory**. `/usr/bin/time -l` reported user and system CPU time as `0.00` seconds at its displayed precision. This measures the sampler without the AppKit menu UI, includes process startup, and is not a full-app memory or battery benchmark. Actual menu-bar overhead has not been measured.

To repeat the finite smoke check without opening a menu-bar item:

```sh
/usr/bin/time -l dist/MemoryBar.app/Contents/MacOS/MemoryBar --smoke-test
```

## Development

```sh
swift test        # Run the metric calculation tests
sh build.sh       # Build and locally sign dist/MemoryBar.app
```

Tests cover CPU interval accounting, initial and empty samples, counter wraparound and resets, plus memory accounting and bounds. The build script verifies the app's local code signature.

```text
Sources/
  MemoryBar/       AppKit menu-bar UI and native system sampling
  MetricsCore/     CPU and memory calculations
Tests/            Calculation tests
build.sh          Release build and app-bundle packaging
```

Original implementation. Generated `.build/` and `dist/` directories are excluded from version control.
