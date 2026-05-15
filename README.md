# Battery & Power Graph

A real-time battery level, power consumption, and temperature graphing widget for KDE Plasma 6.

By John Boero and Claude Opus v4.6

Vibe coded - WARNING use at your own risk.

![Plasma 6.0+](https://img.shields.io/badge/Plasma-6.0%2B-blue)
![License: MPL-2.0](https://img.shields.io/badge/License-MPL--2.0-brightgreen)
![QML](https://img.shields.io/badge/Built%20with-QML-orange)

## Overview

Battery & Power Graph fills a gap in the default Plasma desktop: there's no built-in way to graph your battery percentage, power draw, or battery temperature over time. This widget gives you rolling history graphs with a theme-aware UI that adapts to your Plasma color scheme.

It reads directly from the Linux kernel's `sysfs` interface — no external daemons, no `upower` dependency, no polling services. Just raw data from `/sys/class/power_supply/`.

An emoji font pack is required to see buttons as in the screenshots:
```
sudo dnf install google-noto-color-emoji-fonts
```
or
```
sudo apt install fonts-noto-color-emoji
```

## Features

- **Triple graph modes** — Battery %, Power (Watts), and Temperature (°C)
- **Configurable history** — default 10-minute window at 1-second resolution, adjustable up to 24 hours
- **Auto-scaling axes** — power and temperature scales adapt to your hardware
- **Battery health indicator** — compares design capacity vs. current full capacity
- **Temperature monitoring** — reads from sysfs BAT temp or thermal zone fallback
- **Power profile switching** — integrated power-profiles-daemon controls (Saver/Balanced/Performance)
- **Smart time estimates** — time-to-empty and time-to-full calculations
- **Cycle count display** — battery wear tracking
- **System tray integration** — custom vertical battery icon with charge level, lightning bolt (charging), or plug (AC) indicators
- **Theme-aware colors** — uses Kirigami semantic colors, adapts to light/dark themes
- **Zero dependencies** — reads directly from sysfs; uses awk for math (no `bc` required)
- **Configurable** — right-click widget → Configure for refresh interval, history duration, and power profile visibility

## Data Sources

| Path | Data |
|------|------|
| `/sys/class/power_supply/BAT*/capacity` | Battery percentage |
| `/sys/class/power_supply/BAT*/power_now` | Instantaneous power draw (µW) |
| `/sys/class/power_supply/BAT*/voltage_now` | Battery voltage (µV) |
| `/sys/class/power_supply/BAT*/current_now` | Battery current (µA) |
| `/sys/class/power_supply/BAT*/status` | Charging/Discharging/Full |
| `/sys/class/power_supply/BAT*/temp` | Battery temperature (tenths of °C) |
| `/sys/class/power_supply/BAT*/energy_full_design` | Design capacity |
| `/sys/class/power_supply/BAT*/energy_full` | Current full capacity |
| `/sys/class/power_supply/BAT*/cycle_count` | Charge cycle count |
| `/sys/class/power_supply/AC*/online` | AC adapter status |
| `/sys/class/thermal/thermal_zone*/temp` | Thermal zone fallback for temperature |

If `power_now` is unavailable, watts are calculated from `voltage_now × current_now`.

## Installation

### From .plasmoid file

```bash
kpackagetool6 -t Plasma/Applet --install battery-power-graph.plasmoid
```

### From source

```bash
cd org.kde.plasma.batterymonitor-custom
chmod +x install.sh
./install.sh
```

Then right-click your desktop → **Add Widgets** → search **"Battery & Power Graph"**.

### System Tray Replacement

The widget declares itself as a battery provider. To replace the stock battery icon:

1. Right-click the stock battery icon in your system tray
2. Select **"Show Alternatives..."**
3. Choose **"Battery & Power Graph"**

You may need to run `plasmashell --replace &` after first install for the alternatives menu to populate.

## Configuration

Right-click the widget → **Configure...** to adjust:

| Setting | Default | Range | Description |
|---------|---------|-------|-------------|
| Refresh interval | 1 second | 1–300 seconds | How often to poll sysfs |
| History duration | 10 minutes | 5–1440 minutes | Rolling window for graphs |
| Power profile controls | On | On/Off | Show power profile switcher |
| Battery percentage | Hidden | Hidden / After icon / Inside icon | Where to display battery percentage in system tray |

### Battery Percentage Display Options / 电池百分比显示选项

The widget supports three modes for displaying battery percentage in the system tray icon:
小部件支持三种在系统托盘图标中显示电池百分比的模式：

- **Hidden** (default) - No percentage shown; hover tooltip displays exact value  
  **隐藏**（默认）- 不显示百分比；悬停工具提示显示精确值
- **After battery icon** - Shows "XX%" text label to the right of the battery icon, dynamically expanding the icon width  
  **电池图标后面** - 在电池图标右侧显示 "XX%" 文本标签，动态扩展图标宽度
- **Inside battery icon** - Overlays percentage number centered on the battery body (KDE standard style)  
  **电池图标内部** - 将百分比数字覆盖显示在电池主体中心（KDE 标准样式）

The battery icon itself maintains its fixed dimensions regardless of the display mode. When showing percentage after the icon, the overall component width expands dynamically while keeping the battery size constant.
无论显示模式如何，电池图标本身都保持固定尺寸。当在图标后显示百分比时，整个组件的宽度会动态扩展，同时保持电池大小不变.

## Uninstall

```bash
kpackagetool6 -t Plasma/Applet --remove org.kde.plasma.batterymonitor-custom
```

## Compatibility

- **KDE Plasma 6.0+** (tested on 6.6.1)
- **Linux kernel 4.x+** (requires sysfs power_supply interface)
- **power-profiles-daemon** (optional, for profile switching)

## Troubleshooting

**Widget shows "N/A"**: Check that `/sys/class/power_supply/BAT0/capacity` exists and is readable.

**Power shows 0W**: Some laptops don't expose `power_now`. The widget falls back to `voltage_now × current_now`. If neither works, your firmware may not report instantaneous power.

**Temperature tab disabled**: Your hardware doesn't expose battery temperature via sysfs. Check `cat /sys/class/power_supply/BAT0/temp` or look for battery-related thermal zones.

**Power profile buttons not showing**: Install `power-profiles-daemon` and ensure the D-Bus service is running.

## File Structure

```
org.kde.plasma.batterymonitor-custom/
├── metadata.json                    # Plasma 6 widget metadata
├── contents/
│   ├── config/
│   │   ├── config.qml               # Config page registration
│   │   └── main.xml                 # Config schema (defaults)
│   ├── scripts/
│   │   └── battery-poll.sh          # Shell script for sysfs reads
│   └── ui/
│       ├── main.qml                 # Main widget UI (~755 lines)
│       └── configGeneral.qml        # Settings dialog
├── install.sh                       # Installer with upgrade logic
├── README.md
├── CHANGELOG.md
└── LICENSE
```

## License

MPL-2.0
