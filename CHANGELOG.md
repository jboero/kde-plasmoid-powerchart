# Changelog

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
