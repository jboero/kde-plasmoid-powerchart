# Battery & Power Graph — KDE Plasma 6 Widget
## Reconstruction / Continuation Prompt

By John Boero

Paste this prompt to Claude Opus to recreate the widget from scratch or continue development.

---

## Project Summary

Build a KDE Plasma 6 widget called **"Battery & Power Graph"** (`org.kde.plasma.batterymonitor-boero`) that provides real-time rolling graphs of battery percentage, power draw (watts), and battery temperature (°C). It reads directly from Linux sysfs (`/sys/class/power_supply/`) with zero external dependencies, integrates into the Plasma system tray as a battery icon replacement, and supports power-profiles-daemon for profile switching.

## Current State: v1.2.2

The widget is fully functional with these components:

### File Structure
```
org.kde.plasma.batterymonitor-custom/
├── metadata.json                    # Plasma 6 package metadata
├── contents/
│   ├── config/
│   │   ├── config.qml               # Registers config page
│   │   └── main.xml                 # KConfigXT schema (defaults)
│   ├── scripts/
│   │   └── battery-poll.sh          # External shell script for sysfs reads
│   └── ui/
│       ├── main.qml                 # Main widget (~755 lines)
│       └── configGeneral.qml        # Settings dialog UI
├── install.sh                       # Smart installer with upgrade detection
├── README.md
├── CHANGELOG.md
└── LICENSE (MPL-2.0)
```

### Architecture Decisions

1. **Plasma5Support.DataSource** with `engine: "executable"` — runs an external shell script and parses JSON stdout. The `Plasma5Support` import is required for Plasma 6.6+ (the old `PlasmaCore.DataSource` was removed). Import: `import org.kde.plasma.plasma5support as Plasma5Support`

2. **External battery-poll.sh** instead of inline shell — the QML uses `Qt.resolvedUrl("../scripts/battery-poll.sh")` to locate the script within the plasmoid package. The script uses `awk` for math (not `bc`).

3. **Timer + connectSource/disconnectSource pattern** — a `Timer` triggers `execCommand()` which calls `executable.connectSource(pollCommand)`. The `onNewData` handler processes the JSON then immediately calls `disconnectSource` to prevent stale source buildup.

4. **Kirigami semantic colors** — no hardcoded color palette. Uses `Kirigami.Theme.positiveTextColor`, `.negativeTextColor`, `.neutralTextColor`, `.highlightColor`, `.textColor`, `.disabledTextColor`, `.backgroundColor` so the widget adapts to any Plasma theme (light or dark).

5. **Canvas-based graph** — custom `Canvas` paint routine handles all three view modes with area fills, gradient overlays, axis labels, time labels, and a glowing current-value dot.

6. **Responsive layout** — `fullRepresentation` is a `ColumnLayout` with a computed `showStats` property. When shrunk below threshold, stats grid and health bar auto-hide; the graph gets `Layout.fillHeight: true` to expand into available space.

7. **System tray integration** — metadata declares `X-Plasma-NotificationArea`, `X-Plasma-NotificationAreaCategory: Hardware`, and `X-Plasma-Provides: ["org.kde.plasma.battery"]`. The `compactRepresentation` renders a custom vertical battery icon via Canvas with three states: fill meter (discharging), lightning bolt overlay (charging), plug icon (plugged not charging).

### Key Technical Details

**metadata.json** must include:
- `"KPackageStructure": "Plasma/Applet"` (top-level, NOT inside KPlugin)
- `"X-Plasma-API-Minimum-Version": "6.0"` (top-level)
- NO `X-Plasma-API`, NO `X-Plasma-MainScript` (Plasma 6 infers these)
- `"X-Plasma-NotificationArea": "true"` for systray
- `"X-Plasma-Provides": ["org.kde.plasma.battery"]` to replace stock battery

**QML imports** (Plasma 6.6+ compatible):
```qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
```
Note: No version numbers on imports (Plasma 6 style).

**Config system**: `contents/config/main.xml` defines KConfigXT entries; `contents/config/config.qml` registers the config page; `contents/ui/configGeneral.qml` provides the UI. Access in QML via `plasmoid.configuration.refreshInterval`, etc.

**Temperature sources** (in priority order):
1. `/sys/class/power_supply/BAT*/temp` — value in tenths of °C, divide by 10
2. Fallback: scan `/sys/class/thermal/thermal_zone*/type` for `*bat*|*BAT*|*battery*|*Battery*`, read `temp` (millidegrees, divide by 1000)
3. Returns -1 if unavailable → temp tab shows disabled

**Temperature graph**: Uses `minVal = 20` (not 0) to avoid wasting space below typical operating temps. Auto-scales: `maxTempSeen = ceil(currentTemp/10)*10 + 10`. Color thresholds: ≤35°C green (cool), 35-45°C orange (warm), >45°C red (hot).

**Power profile switching**: Detects `powerprofilesctl` CLI or falls back to `gdbus` D-Bus calls to `net.hadess.PowerProfiles`. Displays Saver/Balanced/Performance buttons. Uses a separate `Plasma5Support.DataSource` instance (`profileSetter`) to run `powerprofilesctl set <profile>` without colliding with the poll source.

**Compact icon**: Canvas-drawn vertical (AA cell style) battery. Terminal nub on top (30% width, 6% height), main body (70% width, 82% height) with rounded corners. Fill level grows upward. Line width: `Math.max(1.5, w * 0.07)`. Outline uses `Kirigami.Theme.textColor`.

**Stats grid**: 2-column GridLayout with 7 items: Current Draw, Battery, Status, Temperature, Profile, Cycle Count, Health. Uses `ListModel` populated by `updateStatsModel()`.

**Graph repaint signaling**: Uses a `dataVersion` integer property that increments after each data update. The Canvas watches this via `property int watchVersion: root.dataVersion` / `onWatchVersionChanged: requestPaint()`. This avoids cross-scope `id` references between fullRepresentation and root.

**X-axis time labels**: Dynamically computed from `intervalSec = plasmoid.configuration.refreshInterval`. Shows seconds for <60s ago, minutes otherwise. Five evenly-spaced labels: 0%, 25%, 50%, 75%, now.

### Default Configuration
- Refresh interval: **1 second** (sysfs reads are zero-cost kernel virtual files)
- History window: **10 minutes** (= 600 data points at 1s)
- Power profile controls: **shown**

### Install Script Logic
1. Check if registered via `kpackagetool6 --show`
2. If registered → `--upgrade` (clean in-place update)
3. If not registered but directory exists → remove orphan, then `--install`
4. If clean slate → straight `--install`
5. Fallback: manual copy to `~/.local/share/plasma/plasmoids/`

### Known Considerations
- `plasmashell --replace &` may be needed after first install for systray alternatives menu
- Some laptops don't expose `power_now` — widget falls back to `voltage_now × current_now`
- Temperature availability varies by hardware
- The `.plasmoid` file is just a zip containing: `metadata.json`, `contents/`, `LICENSE`, `README.md`, `CHANGELOG.md`

## To Continue Development

Likely next features:
- Per-device Bluetooth battery monitoring
- Notification thresholds (alert at X% battery)
- Graph export / screenshot
- Multiple battery support (BAT0 + BAT1)
- KDE Store submission polish (screenshots, translations)
- config.qml entries for color overrides
