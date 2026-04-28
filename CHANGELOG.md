# Changelog

## 1.4.0 (2026-04-28)

### No-battery support / 无电池支持
- Compact representation no longer renders a blank battery icon and "NONE" overflow on machines without a battery; instead shows the active power profile glyph + system watts (RAPL).
- Header icon switches to "ac-adapter" when no battery is present.
- `battery-poll.sh` now reports an explicit `has_battery` flag.

### Power profile in icon and tooltip
- Active power profile (Saver / Balanced / Performance) now overlays the compact battery icon as a small corner glyph and is included in the hover tooltip.

### System power monitoring (RAPL) — user-selectable source
- Poll script always reads both `psys` (whole-platform) and `package-0` (CPU + iGPU) energy counters from `/sys/class/powercap/intel-rapl:*/`.
- QML diffs the energy counters over time to derive watts; handles counter wraparound.
- New "System power source" config dropdown — `PSYS` / `Package` / `None`. **Defaults to `None`** because PSYS scope is firmware-defined and on much Intel client silicon under-reports (sometimes reads lower than the CPU package alone). Users opt in once they verify their hardware reports sane values.
- Detects EACCES (root-only on modern kernels for CVE-2020-8694 mitigation) and surfaces a "locked" status. Settings dialog includes a copyable udev-rule recipe for users who want to enable it — display-only, no automatic privilege changes.
- Power graph overlays the selected system reading as a translucent solid line drawn on top of the (now thinner, 1.5px) primary battery line. Small legend strip below the graph when active.
- Headline readout in Power view shows the selected system metric when available, with a hover tooltip explaining what the number represents in each view, charging vs discharging, and source-specific caveats.

### Charging visualisation
- Power-graph line is now segmented per data point by charging state — green where the battery is charging, highlight color where discharging — matching the compact battery-icon color scheme.
- Header readout distinguishes "X.XW → battery" (charging) from "X.XW load" (discharging) and appends "sys X.XW" when RAPL is available.
- Tooltip rewritten: separate lines for battery state, system power, profile, temperature.

### Hardening
- `setProfile()` and `setTunedProfile()` now whitelist-check their argument against the parsed available-profiles list before building a shell command. Defense-in-depth — both lists were already sourced from trusted system commands, but this closes any path for an unvetted string to reach the shell.

### Cleanup
- Resolved unmerged conflict markers in README.md.

---

## 1.3.0 (2026-03-29)

### Documentation & Code Quality Improvements / 文档和代码质量改进

#### Comprehensive Bilingual Comments / 全面的中英文双语注释
- Added detailed Chinese-English bilingual comments to all source files in `contents/` directory
- Enhanced comment quality with line-by-line explanations, numerical value clarifications, logic descriptions, and state differentiation
- Improved main.qml with extensive documentation for battery icon drawing, graph rendering, and data flow
- Documented configuration schema (main.xml) with detailed explanations for each setting's purpose, type, range, and impact
- Enhanced battery-poll.sh script with formula explanations, unit conversions, and fallback strategy documentation
- Updated config.qml with complete module and property descriptions

**Files Enhanced:**
- `contents/ui/main.qml` - Battery icon canvas drawing, graph area rendering, statistics grid layout
- `contents/ui/configGeneral.qml` - Configuration UI controls and bindings
- `contents/config/config.qml` - Configuration model structure
- `contents/config/main.xml` - KConfig schema definitions with entry details
- `contents/scripts/battery-poll.sh` - Power calculations, time estimates, temperature reading logic

#### Battery Icon Customization / 电池图标自定义
- Adjusted compact representation battery icon height to 60% of container for better visual proportion
- Enhanced battery body dimensions: bodyY=20%, bodyH=60% for optimized appearance
- Improved charging indicator (lightning bolt) and AC plug icon positioning
- Added comprehensive inline documentation for all drawing parameters and percentages

#### Technical Details / 技术细节
- All comments follow bilingual format (Chinese + English) for international collaboration
- Numerical constants explained with specific meanings (e.g., 0.04 for line width, 0.6 for battery height)
- State-based visual handling documented (charging vs. discharging vs. plugged in)
- Canvas drawing logic fully annotated with coordinate calculations and color selection strategies

---


## 1.2.2 (2026-03-03)

- Responsive layout: stats grid and health bar auto-hide when widget is shrunk
- Graph fills available space with Layout.fillHeight
- Minimum widget size reduced to 280×200 for compact placement

## 1.2.0 (2026-03-03)

- Power profile switching via power-profiles-daemon (Saver/Balanced/Performance)
- Configurable settings dialog (refresh interval, history duration, profile visibility)
- Default polling changed to 1-second interval with 10-minute history window
- External battery-poll.sh script replaces inline shell command
- Uses awk instead of bc for arithmetic (wider availability)
- Time-to-full estimates when charging

## 1.1.0 (2026-03-03)

- Temperature monitoring with third graph tab (°C)
- Temperature color thresholds: cool (≤35°C green), warm (35-45°C orange), hot (>45°C red)
- Temperature auto-scaling with 20°C floor
- System tray integration (X-Plasma-NotificationArea metadata)
- Custom vertical battery icon for compact representation
- Three visual states: fill meter (discharging), lightning bolt (charging), plug icon (AC)
- Theme-aware colors using Kirigami semantic color tokens
- Replaced hardcoded cyberpunk palette with Plasma theme adaptation
- Migrated from PlasmaCore.DataSource to Plasma5Support.DataSource (Plasma 6.6+ compat)
- Improved install.sh with upgrade detection and orphan cleanup

## 1.0.0 (2026-03-03)

Initial release.

- Real-time battery percentage and power consumption graphing
- Dual view mode: Battery % and Power (Watts)
- 2-hour rolling history (120 data points at 1-minute intervals)
- Auto-scaling power axis
- Battery health indicator (design vs. actual capacity)
- Time-to-empty estimates
- Cycle count display
- Compact panel representation with battery icon
- Reads directly from /sys/class/power_supply (no external dependencies)
- Built for KDE Plasma 6.0+ with proper KF6 QML imports
