# Battery & Power Graph — KDE Plasma 6 Widget

A real-time battery level and power consumption graphing widget for the KDE Plasma 6 desktop, with a cyberpunk-inspired dark UI.

WARNING this is vibe coded in Claude Opus v4.6 - USE AT YOUR OWN RISK

![sample](https://github.com/user-attachments/assets/6e768300-e7ba-416f-b4d8-c1199a0cf9fc)

## Features

- **Dual graph modes**: Toggle between Battery % and Power (Watts) over time
- **Real-time monitoring**: Polls `/sys/class/power_supply/` every 60 seconds
- **2-hour rolling history**: Stores up to 120 data points with auto-scrolling
- **Auto-scaling power axis**: Automatically adjusts watt scale to your usage
- **Battery health indicator**: Shows design vs. actual capacity degradation
- **Smart status display**: Time-to-empty/full estimates, charge state, cycle count
- **System tray compact mode**: Shows battery icon with percentage overlay
- **Zero dependencies**: Reads directly from sysfs — no `upower` or `acpi` needed

## Data Sources

The widget reads from the Linux kernel's `sysfs` interface:

| Path | Data |
|------|------|
| `/sys/class/power_supply/BAT*/capacity` | Battery percentage |
| `/sys/class/power_supply/BAT*/power_now` | Instantaneous power draw (µW) |
| `/sys/class/power_supply/BAT*/voltage_now` | Battery voltage (µV) |
| `/sys/class/power_supply/BAT*/current_now` | Battery current (µA) |
| `/sys/class/power_supply/BAT*/status` | Charging/Discharging/Full |
| `/sys/class/power_supply/BAT*/energy_full_design` | Design capacity |
| `/sys/class/power_supply/BAT*/energy_full` | Current full capacity |
| `/sys/class/power_supply/BAT*/cycle_count` | Charge cycle count |
| `/sys/class/power_supply/AC*/online` | AC adapter status |

If `power_now` is unavailable, it calculates watts from `voltage_now × current_now`.

## Installation

```bash
cd org.kde.plasma.batterymonitor-custom
chmod +x install.sh
./install.sh
```

Then right-click your desktop → **Add Widgets** → search **"Battery & Power Graph"**.

## Uninstall

```bash
kpackagetool6 -t Plasma/Applet --remove org.kde.plasma.batterymonitor-custom
```

## Customization

Edit the properties at the top of `contents/ui/main.qml`:

| Property | Default | Description |
|----------|---------|-------------|
| `maxDataPoints` | 120 | History length (at 1-min intervals = 2 hours) |
| `pollIntervalMs` | 60000 | Poll interval in milliseconds |
| `graphHeight` | 180 | Graph canvas height in pixels |
| `graphWidth` | 360 | Graph canvas width in pixels |

Color palette variables (`colorBg`, `colorBattery`, `colorPower`, etc.) can also be adjusted for different themes.

## Compatibility

- **KDE Plasma 6.x** (primary target)
- **KDE Plasma 5.x** (should work with kpackagetool5)
- **Linux kernel 4.x+** (requires sysfs power_supply interface)

## Troubleshooting

**Widget shows "N/A"**: Check that `/sys/class/power_supply/BAT0/capacity` exists and is readable.

**Power shows 0W**: Some laptops don't expose `power_now`. The widget falls back to `voltage_now × current_now`. If neither works, your firmware may not report instantaneous power.

**Graph not updating**: The `executable` data engine runs shell commands. Make sure `bc` is installed (`sudo apt install bc` or equivalent).

## License

GPL-3.0
