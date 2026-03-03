#!/bin/bash
# Battery & Power Graph - Plasma 6 Widget Installer
# ──────────────────────────────────────────────────
set -e

WIDGET_ID="org.kde.plasma.batterymonitor-boero"
WIDGET_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "╔══════════════════════════════════════════════╗"
echo "║  Battery & Power Graph - Plasma 6.x Widget   ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# Check for Plasma 6
if command -v plasmashell &>/dev/null; then
    echo "✓ Detected: $(plasmashell --version 2>/dev/null)"
else
    echo "⚠ plasmashell not found."
fi

# Check for battery
for d in /sys/class/power_supply/BAT*; do
    if [ -d "$d" ]; then
        echo "✓ Battery found: $(basename $d)"
        [ -f "$d/capacity" ] && echo "  Charge: $(cat $d/capacity)%"
        [ -f "$d/status" ] && echo "  Status: $(cat $d/status)"
        [ -f "$d/power_now" ] && echo "  Power: $(awk "BEGIN{printf \"%.2f\", $(cat $d/power_now)/1000000}")W"
        break
    fi
done
echo ""

# Install / upgrade
if command -v kpackagetool6 &>/dev/null; then
    DEST="$HOME/.local/share/plasma/plasmoids/$WIDGET_ID"

    # Check if already installed via kpackagetool
    if kpackagetool6 -t Plasma/Applet --show "$WIDGET_ID" &>/dev/null; then
        echo "Existing installation found. Upgrading..."
        kpackagetool6 -t Plasma/Applet --upgrade "$WIDGET_DIR"
        echo "✓ Upgraded successfully"
    else
        # Clean up any manual leftover that kpackagetool doesn't know about
        if [ -d "$DEST" ]; then
            echo "Removing leftover files from $DEST..."
            rm -rf "$DEST"
        fi
        echo "Installing via kpackagetool6..."
        kpackagetool6 -t Plasma/Applet --install "$WIDGET_DIR"
        echo "✓ Installed successfully"
    fi
else
    echo "kpackagetool6 not found, installing manually..."
    DEST="$HOME/.local/share/plasma/plasmoids/$WIDGET_ID"
    rm -rf "$DEST"
    mkdir -p "$DEST"
    cp -r "$WIDGET_DIR"/* "$DEST/"
    echo "✓ Installed to $DEST"
fi

echo ""
echo "══════════════════════════════════════════════════"
echo "  Done! Right-click desktop → Add Widgets"
echo "  → Search 'Battery & Power Graph'"
echo ""
echo "  Uninstall:"
echo "  kpackagetool6 -t Plasma/Applet --remove $WIDGET_ID"
echo "══════════════════════════════════════════════════"
