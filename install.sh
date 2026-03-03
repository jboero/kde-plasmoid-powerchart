#!/bin/bash
# Battery & Power Graph - Plasma 6 Widget Installer
# ──────────────────────────────────────────────────

set -e

WIDGET_ID="org.kde.plasma.batterymonitor-custom"
WIDGET_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "╔══════════════════════════════════════════════╗"
echo "║  Battery & Power Graph - Plasma 6 Widget     ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# Check for Plasma 6
if command -v plasmashell &>/dev/null; then
    PLASMA_VER=$(plasmashell --version 2>/dev/null | grep -oP '\d+' | head -1)
    echo "✓ Detected Plasma version: $(plasmashell --version 2>/dev/null)"
else
    echo "⚠ plasmashell not found. Make sure KDE Plasma is installed."
fi

# Check for battery
BAT_FOUND=false
for d in /sys/class/power_supply/BAT*; do
    if [ -d "$d" ]; then
        BAT_FOUND=true
        echo "✓ Battery found: $(basename $d)"
        [ -f "$d/capacity" ] && echo "  Current charge: $(cat $d/capacity)%"
        [ -f "$d/status" ] && echo "  Status: $(cat $d/status)"
        [ -f "$d/power_now" ] && echo "  Power: $(echo "scale=2; $(cat $d/power_now) / 1000000" | bc)W"
        break
    fi
done

if [ "$BAT_FOUND" = "false" ]; then
    echo "⚠ No battery detected in /sys/class/power_supply/BAT*"
    echo "  The widget will show N/A for battery data."
    echo "  Power draw from AC adapter may still be available."
fi

echo ""

# Install methods
install_user() {
    echo "Installing for current user..."
    # Method 1: kpackagetool6 (Plasma 6)
    if command -v kpackagetool6 &>/dev/null; then
        echo "Using kpackagetool6..."
        kpackagetool6 -t Plasma/Applet --install "$WIDGET_DIR" 2>/dev/null || \
        kpackagetool6 -t Plasma/Applet --upgrade "$WIDGET_DIR" 2>/dev/null || true
        echo "✓ Installed via kpackagetool6"
        return 0
    fi

    # Method 2: kpackagetool5 fallback
    if command -v kpackagetool5 &>/dev/null; then
        echo "Using kpackagetool5 (Plasma 5 compat)..."
        kpackagetool5 -t Plasma/Applet --install "$WIDGET_DIR" 2>/dev/null || \
        kpackagetool5 -t Plasma/Applet --upgrade "$WIDGET_DIR" 2>/dev/null || true
        echo "✓ Installed via kpackagetool5"
        return 0
    fi

    # Method 3: Manual install
    echo "No kpackagetool found. Installing manually..."
    local DEST="$HOME/.local/share/plasma/plasmoids/$WIDGET_ID"
    mkdir -p "$DEST"
    cp -r "$WIDGET_DIR"/* "$DEST/"
    echo "✓ Installed to $DEST"
    return 0
}

install_user

echo ""
echo "════════════════════════════════════════════════"
echo "  Installation complete!"
echo ""
echo "  To add the widget:"
echo "    1. Right-click your desktop or panel"
echo "    2. Select 'Add Widgets...'"
echo "    3. Search for 'Battery & Power Graph'"
echo "    4. Drag it to your desktop or panel"
echo ""
echo "  To uninstall:"
echo "    kpackagetool6 -t Plasma/Applet --remove $WIDGET_ID"
echo "════════════════════════════════════════════════"
