import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.kirigami 2.20 as Kirigami

PlasmoidItem {
    id: root

    // ── Configurable Properties ──────────────────────────────────────
    readonly property int maxDataPoints: 120       // 2 hours at 1-min intervals
    readonly property int pollIntervalMs: 60000    // 1 minute
    readonly property int graphHeight: 180
    readonly property int graphWidth: 360

    // ── Color Palette (cyberpunk-inspired) ───────────────────────────
    readonly property color colorBg:         "#0a0e17"
    readonly property color colorBgPanel:    "#0f1520"
    readonly property color colorGrid:       "#1a2235"
    readonly property color colorGridAccent: "#243050"
    readonly property color colorText:       "#8899bb"
    readonly property color colorTextBright: "#c0d0ee"
    readonly property color colorBattery:    "#00e5a0"
    readonly property color colorBatteryLow: "#ff4466"
    readonly property color colorBatteryMid: "#ffaa22"
    readonly property color colorPower:      "#00aaff"
    readonly property color colorCharging:   "#44ffaa"
    readonly property color colorGlow:       "#00e5a044"

    // ── Data Models ──────────────────────────────────────────────────
    property var batteryHistory: []
    property var powerHistory: []
    property real currentBattery: -1
    property real currentPower: 0.0
    property bool isCharging: false
    property bool acPlugged: false
    property string batteryStatus: "Unknown"
    property real maxPowerSeen: 25.0   // auto-scales
    property real minPowerSeen: 0.0
    property string timeToEmpty: ""
    property string timeToFull: ""
    property real designCapacity: 0
    property real fullCapacity: 0
    property real batteryHealth: 0
    property int cycleCount: -1

    // ── View Mode ────────────────────────────────────────────────────
    property int viewMode: 0  // 0 = battery%, 1 = power watts

    // ── Compact representation (system tray icon) ────────────────────
    compactRepresentation: Item {
        id: compactRoot
        Layout.minimumWidth: Kirigami.Units.iconSizes.medium
        Layout.minimumHeight: Kirigami.Units.iconSizes.medium

        Kirigami.Icon {
            anchors.fill: parent
            source: {
                if (root.currentBattery < 0) return "battery-missing";
                if (root.isCharging) return "battery-charging";
                if (root.currentBattery > 80) return "battery-100";
                if (root.currentBattery > 60) return "battery-080";
                if (root.currentBattery > 40) return "battery-060";
                if (root.currentBattery > 20) return "battery-040";
                return "battery-low";
            }
            active: compactMouse.containsMouse
        }

        // Small percentage overlay
        PlasmaComponents.Label {
            anchors.centerIn: parent
            text: root.currentBattery >= 0 ? Math.round(root.currentBattery) + "%" : "?"
            font.pixelSize: parent.height * 0.28
            font.bold: true
            color: root.colorTextBright
            style: Text.Outline
            styleColor: "#000000"
        }

        MouseArea {
            id: compactMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.expanded = !root.expanded
        }
    }

    // ── Full representation (expanded popup) ─────────────────────────
    fullRepresentation: Item {
        Layout.preferredWidth: root.graphWidth + 40
        Layout.preferredHeight: root.graphHeight + 260
        Layout.minimumWidth: 300
        Layout.minimumHeight: 300

        Rectangle {
            anchors.fill: parent
            color: root.colorBg
            radius: 4

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // ── Header ───────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Battery icon with glow
                    Item {
                        width: 32
                        height: 32

                        Rectangle {
                            anchors.centerIn: parent
                            width: 28
                            height: 28
                            radius: 14
                            color: "transparent"
                            border.color: root.isCharging ? root.colorCharging : batteryColor(root.currentBattery)
                            border.width: 2
                            opacity: 0.4
                        }

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 22
                            height: 22
                            source: root.isCharging ? "battery-charging" : "battery-full"
                            color: root.isCharging ? root.colorCharging : batteryColor(root.currentBattery)
                        }
                    }

                    ColumnLayout {
                        spacing: 0

                        PlasmaComponents.Label {
                            text: "POWER MONITOR"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.letterSpacing: 2
                            color: root.colorTextBright
                        }

                        PlasmaComponents.Label {
                            text: root.batteryStatus
                            font.pixelSize: 9
                            color: root.isCharging ? root.colorCharging : root.colorText
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Current reading - big number
                    ColumnLayout {
                        spacing: 0

                        PlasmaComponents.Label {
                            Layout.alignment: Qt.AlignRight
                            text: root.viewMode === 0
                                ? (root.currentBattery >= 0 ? Math.round(root.currentBattery) + "%" : "N/A")
                                : root.currentPower.toFixed(1) + "W"
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            font.family: "monospace"
                            color: root.viewMode === 0
                                ? batteryColor(root.currentBattery)
                                : root.colorPower
                        }

                        PlasmaComponents.Label {
                            Layout.alignment: Qt.AlignRight
                            text: {
                                if (root.isCharging && root.timeToFull !== "")
                                    return "⚡ Full in " + root.timeToFull;
                                if (!root.isCharging && root.timeToEmpty !== "")
                                    return "🔋 " + root.timeToEmpty + " remaining";
                                return root.currentPower.toFixed(1) + "W draw";
                            }
                            font.pixelSize: 9
                            color: root.colorText
                        }
                    }
                }

                // ── View Toggle ──────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: ["Battery %", "Power (W)"]

                        Rectangle {
                            Layout.fillWidth: true
                            height: 26
                            radius: 3
                            color: root.viewMode === index ? root.colorGridAccent : "transparent"
                            border.color: root.viewMode === index ? root.colorPower : root.colorGrid
                            border.width: 1

                            PlasmaComponents.Label {
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: 10
                                font.weight: root.viewMode === index ? Font.Bold : Font.Normal
                                color: root.viewMode === index ? root.colorTextBright : root.colorText
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.viewMode = index
                            }
                        }
                    }
                }

                // ── Graph Canvas ─────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.graphHeight
                    color: root.colorBgPanel
                    radius: 4
                    border.color: root.colorGrid
                    border.width: 1
                    clip: true

                    Canvas {
                        id: graphCanvas
                        anchors.fill: parent
                        anchors.margins: 1

                        onPaint: {
                            var ctx = getContext("2d");
                            var w = width;
                            var h = height;
                            var pad = { top: 12, right: 10, bottom: 22, left: 38 };
                            var gw = w - pad.left - pad.right;
                            var gh = h - pad.top - pad.bottom;

                            ctx.clearRect(0, 0, w, h);

                            // Grid lines
                            ctx.strokeStyle = root.colorGrid;
                            ctx.lineWidth = 0.5;
                            for (var i = 0; i <= 4; i++) {
                                var y = pad.top + (gh / 4) * i;
                                ctx.beginPath();
                                ctx.moveTo(pad.left, y);
                                ctx.lineTo(pad.left + gw, y);
                                ctx.stroke();
                            }

                            // Y-axis labels
                            ctx.fillStyle = root.colorText;
                            ctx.font = "9px monospace";
                            ctx.textAlign = "right";
                            ctx.textBaseline = "middle";

                            var maxVal = root.viewMode === 0 ? 100 : root.maxPowerSeen;
                            var minVal = root.viewMode === 0 ? 0 : 0;
                            var unit = root.viewMode === 0 ? "%" : "W";

                            for (var i = 0; i <= 4; i++) {
                                var val = maxVal - (maxVal - minVal) * (i / 4);
                                var y = pad.top + (gh / 4) * i;
                                ctx.fillText(val.toFixed(root.viewMode === 0 ? 0 : 1) + unit, pad.left - 4, y);
                            }

                            // X-axis time labels
                            ctx.textAlign = "center";
                            ctx.textBaseline = "top";
                            var data = root.viewMode === 0 ? root.batteryHistory : root.powerHistory;
                            var numPoints = data.length;

                            if (numPoints > 1) {
                                var labels = [0, Math.floor(numPoints * 0.25), Math.floor(numPoints * 0.5),
                                              Math.floor(numPoints * 0.75), numPoints - 1];
                                for (var li = 0; li < labels.length; li++) {
                                    var idx = labels[li];
                                    if (idx < numPoints) {
                                        var x = pad.left + (idx / (root.maxDataPoints - 1)) * gw;
                                        var minsAgo = (numPoints - 1 - idx);
                                        var label = minsAgo === 0 ? "now" : "-" + minsAgo + "m";
                                        ctx.fillText(label, x, pad.top + gh + 4);
                                    }
                                }
                            }

                            // Draw data
                            if (numPoints < 2) {
                                ctx.fillStyle = root.colorText;
                                ctx.font = "11px sans-serif";
                                ctx.textAlign = "center";
                                ctx.textBaseline = "middle";
                                ctx.fillText("Collecting data...", w / 2, h / 2);
                                return;
                            }

                            // Area fill gradient
                            var gradient = ctx.createLinearGradient(0, pad.top, 0, pad.top + gh);
                            var lineColor = root.viewMode === 0 ? batteryColor(root.currentBattery) : root.colorPower;

                            if (root.viewMode === 0) {
                                gradient.addColorStop(0, Qt.rgba(batteryColorObj(root.currentBattery).r,
                                    batteryColorObj(root.currentBattery).g,
                                    batteryColorObj(root.currentBattery).b, 0.3));
                                gradient.addColorStop(1, Qt.rgba(batteryColorObj(root.currentBattery).r,
                                    batteryColorObj(root.currentBattery).g,
                                    batteryColorObj(root.currentBattery).b, 0.02));
                            } else {
                                gradient.addColorStop(0, "#00aaff30");
                                gradient.addColorStop(1, "#00aaff02");
                            }

                            // Area path
                            ctx.beginPath();
                            for (var i = 0; i < numPoints; i++) {
                                var x = pad.left + (i / (root.maxDataPoints - 1)) * gw;
                                var val = Math.max(minVal, Math.min(maxVal, data[i]));
                                var y = pad.top + gh - ((val - minVal) / (maxVal - minVal)) * gh;
                                if (i === 0) ctx.moveTo(x, y);
                                else ctx.lineTo(x, y);
                            }
                            var lastX = pad.left + ((numPoints - 1) / (root.maxDataPoints - 1)) * gw;
                            ctx.lineTo(lastX, pad.top + gh);
                            ctx.lineTo(pad.left, pad.top + gh);
                            ctx.closePath();
                            ctx.fillStyle = gradient;
                            ctx.fill();

                            // Line path
                            ctx.beginPath();
                            for (var i = 0; i < numPoints; i++) {
                                var x = pad.left + (i / (root.maxDataPoints - 1)) * gw;
                                var val = Math.max(minVal, Math.min(maxVal, data[i]));
                                var y = pad.top + gh - ((val - minVal) / (maxVal - minVal)) * gh;
                                if (i === 0) ctx.moveTo(x, y);
                                else ctx.lineTo(x, y);
                            }
                            ctx.strokeStyle = lineColor;
                            ctx.lineWidth = 2;
                            ctx.stroke();

                            // Current value dot (glow effect)
                            if (numPoints > 0) {
                                var lastVal = data[numPoints - 1];
                                var dotX = pad.left + ((numPoints - 1) / (root.maxDataPoints - 1)) * gw;
                                var dotY = pad.top + gh - ((Math.max(minVal, Math.min(maxVal, lastVal)) - minVal) / (maxVal - minVal)) * gh;

                                // Glow
                                ctx.beginPath();
                                ctx.arc(dotX, dotY, 6, 0, 2 * Math.PI);
                                ctx.fillStyle = lineColor + "44";
                                ctx.fill();

                                // Dot
                                ctx.beginPath();
                                ctx.arc(dotX, dotY, 3, 0, 2 * Math.PI);
                                ctx.fillStyle = lineColor;
                                ctx.fill();
                            }
                        }
                    }
                }

                // ── Stats Grid ───────────────────────────────────────
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 4
                    columnSpacing: 8

                    // Stat cards
                    Repeater {
                        model: statsModel
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            height: 32
                            radius: 3
                            color: root.colorBgPanel
                            border.color: root.colorGrid
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 4

                                PlasmaComponents.Label {
                                    text: model.label
                                    font.pixelSize: 9
                                    color: root.colorText
                                }
                                Item { Layout.fillWidth: true }
                                PlasmaComponents.Label {
                                    text: model.value
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    font.family: "monospace"
                                    color: model.accent ? model.accent : root.colorTextBright
                                }
                            }
                        }
                    }
                }

                // ── Battery Health Bar ───────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    visible: root.batteryHealth > 0

                    RowLayout {
                        Layout.fillWidth: true
                        PlasmaComponents.Label {
                            text: "Battery Health"
                            font.pixelSize: 9
                            color: root.colorText
                        }
                        Item { Layout.fillWidth: true }
                        PlasmaComponents.Label {
                            text: root.batteryHealth.toFixed(1) + "%"
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            color: root.batteryHealth > 80 ? root.colorBattery :
                                   root.batteryHealth > 50 ? root.colorBatteryMid : root.colorBatteryLow
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 4
                        radius: 2
                        color: root.colorGrid

                        Rectangle {
                            width: parent.width * (root.batteryHealth / 100)
                            height: parent.height
                            radius: 2
                            color: root.batteryHealth > 80 ? root.colorBattery :
                                   root.batteryHealth > 50 ? root.colorBatteryMid : root.colorBatteryLow
                        }
                    }
                }
            }
        }
    }

    // ── Stats Model ──────────────────────────────────────────────────
    ListModel {
        id: statsModel
    }

    function updateStatsModel() {
        statsModel.clear();
        statsModel.append({
            label: "Current Draw",
            value: root.currentPower.toFixed(2) + " W",
            accent: root.colorPower
        });
        statsModel.append({
            label: "Battery",
            value: root.currentBattery >= 0 ? Math.round(root.currentBattery) + "%" : "N/A",
            accent: batteryColor(root.currentBattery)
        });
        statsModel.append({
            label: "Status",
            value: root.isCharging ? "⚡ Charging" : (root.acPlugged ? "Plugged In" : "Discharging"),
            accent: root.isCharging ? root.colorCharging : ""
        });
        statsModel.append({
            label: "Cycle Count",
            value: root.cycleCount >= 0 ? root.cycleCount.toString() : "N/A",
            accent: ""
        });
    }

    // ── Color Helpers ────────────────────────────────────────────────
    function batteryColor(pct) {
        if (pct < 0) return colorText;
        if (pct <= 20) return colorBatteryLow;
        if (pct <= 40) return colorBatteryMid;
        return colorBattery;
    }

    function batteryColorObj(pct) {
        if (pct <= 20) return { r: 1.0, g: 0.27, b: 0.4 };
        if (pct <= 40) return { r: 1.0, g: 0.67, b: 0.13 };
        return { r: 0.0, g: 0.9, b: 0.63 };
    }

    // ── Data Source: reads from /sys/class/power_supply ──────────────
    function pollBatteryData() {
        var battPct = -1;
        var watts = 0;
        var charging = false;
        var ac = false;
        var status = "Unknown";
        var tte = "";
        var ttf = "";
        var designCap = 0;
        var fullCap = 0;
        var cycles = -1;

        // We use a DataSource to run a shell command that reads sysfs
        dataSource.connectedSources = ["batteryPoll"];
    }

    // Using PlasmaCore.DataSource to execute shell reads
    PlasmaCore.DataSource {
        id: dataSource
        engine: "executable"
        interval: root.pollIntervalMs

        onNewData: {
            if (sourceName !== "batteryPoll") return;

            var stdout = data["stdout"] || "";
            if (stdout === "") return;

            try {
                var parsed = JSON.parse(stdout);
                root.currentBattery = parsed.battery_pct !== undefined ? parsed.battery_pct : -1;
                root.currentPower = parsed.power_watts !== undefined ? parsed.power_watts : 0;
                root.isCharging = parsed.charging || false;
                root.acPlugged = parsed.ac_online || false;
                root.batteryStatus = parsed.status || "Unknown";
                root.timeToEmpty = parsed.time_to_empty || "";
                root.timeToFull = parsed.time_to_full || "";
                root.designCapacity = parsed.design_capacity || 0;
                root.fullCapacity = parsed.full_capacity || 0;
                root.cycleCount = parsed.cycle_count !== undefined ? parsed.cycle_count : -1;

                if (root.designCapacity > 0 && root.fullCapacity > 0) {
                    root.batteryHealth = (root.fullCapacity / root.designCapacity) * 100;
                }

                // Update history
                if (root.currentBattery >= 0) {
                    var bh = root.batteryHistory.slice();
                    bh.push(root.currentBattery);
                    if (bh.length > root.maxDataPoints) bh.shift();
                    root.batteryHistory = bh;
                }

                var ph = root.powerHistory.slice();
                ph.push(root.currentPower);
                if (ph.length > root.maxDataPoints) ph.shift();
                root.powerHistory = ph;

                // Auto-scale power axis
                if (root.currentPower > root.maxPowerSeen) {
                    root.maxPowerSeen = Math.ceil(root.currentPower / 5) * 5 + 5;
                }

                updateStatsModel();
                graphCanvas.requestPaint();
            } catch (e) {
                console.log("BatteryGraph: parse error: " + e);
            }
        }

        connectedSources: ["batteryPoll"]
    }

    // The actual shell command that reads sysfs and outputs JSON
    property string batteryPollCommand: {
        return 'bash -c \'' +
            'BAT=""; ' +
            'for d in /sys/class/power_supply/BAT*; do [ -d "$d" ] && BAT="$d" && break; done; ' +
            'AC=""; ' +
            'for d in /sys/class/power_supply/AC* /sys/class/power_supply/ADP*; do [ -d "$d" ] && AC="$d" && break; done; ' +
            'PCT=-1; WATTS=0; CHARGING=false; AC_ON=false; STATUS="Unknown"; ' +
            'TTE=""; TTF=""; DCAP=0; FCAP=0; CYCLES=-1; ' +
            'if [ -n "$BAT" ]; then ' +
            '  [ -f "$BAT/capacity" ] && PCT=$(cat "$BAT/capacity"); ' +
            '  STATUS=$(cat "$BAT/status" 2>/dev/null || echo Unknown); ' +
            '  [ "$STATUS" = "Charging" ] && CHARGING=true; ' +
            '  VOLT=0; CURR=0; POW=0; ' +
            '  [ -f "$BAT/voltage_now" ] && VOLT=$(cat "$BAT/voltage_now"); ' +
            '  [ -f "$BAT/current_now" ] && CURR=$(cat "$BAT/current_now"); ' +
            '  [ -f "$BAT/power_now" ] && POW=$(cat "$BAT/power_now"); ' +
            '  if [ "$POW" -gt 0 ] 2>/dev/null; then ' +
            '    WATTS=$(echo "scale=2; $POW / 1000000" | bc); ' +
            '  elif [ "$VOLT" -gt 0 ] && [ "$CURR" -gt 0 ] 2>/dev/null; then ' +
            '    WATTS=$(echo "scale=2; $VOLT * $CURR / 1000000000000" | bc); ' +
            '  fi; ' +
            '  [ -f "$BAT/charge_full_design" ] && DCAP=$(cat "$BAT/charge_full_design"); ' +
            '  [ -f "$BAT/energy_full_design" ] && [ "$DCAP" = "0" ] && DCAP=$(cat "$BAT/energy_full_design"); ' +
            '  [ -f "$BAT/charge_full" ] && FCAP=$(cat "$BAT/charge_full"); ' +
            '  [ -f "$BAT/energy_full" ] && [ "$FCAP" = "0" ] && FCAP=$(cat "$BAT/energy_full"); ' +
            '  [ -f "$BAT/cycle_count" ] && CYCLES=$(cat "$BAT/cycle_count"); ' +
            '  if [ "$CHARGING" = "false" ] && [ "$PCT" -gt 0 ] 2>/dev/null; then ' +
            '    ENERGY_NOW=0; ' +
            '    [ -f "$BAT/energy_now" ] && ENERGY_NOW=$(cat "$BAT/energy_now"); ' +
            '    [ -f "$BAT/charge_now" ] && [ "$ENERGY_NOW" = "0" ] && ENERGY_NOW=$(cat "$BAT/charge_now"); ' +
            '    if [ "$POW" -gt 0 ] 2>/dev/null && [ "$ENERGY_NOW" -gt 0 ] 2>/dev/null; then ' +
            '      MINS=$(echo "$ENERGY_NOW * 60 / $POW" | bc 2>/dev/null); ' +
            '      [ -n "$MINS" ] && [ "$MINS" -gt 0 ] 2>/dev/null && TTE="$((MINS/60))h $((MINS%60))m"; ' +
            '    fi; ' +
            '  fi; ' +
            'fi; ' +
            '[ -n "$AC" ] && [ -f "$AC/online" ] && [ "$(cat $AC/online)" = "1" ] && AC_ON=true; ' +
            'echo "{\\"battery_pct\\": $PCT, \\"power_watts\\": $WATTS, \\"charging\\": $CHARGING, ' +
            '\\"ac_online\\": $AC_ON, \\"status\\": \\"$STATUS\\", \\"time_to_empty\\": \\"$TTE\\", ' +
            '\\"time_to_full\\": \\"$TTF\\", \\"design_capacity\\": $DCAP, \\"full_capacity\\": $FCAP, ' +
            '\\"cycle_count\\": $CYCLES}"' +
            "'"
    }

    // Register the command as a data source
    Component.onCompleted: {
        dataSource.connectedSources = [];
        // Connect with the executable engine using our shell command
        dataSource.connectedSources = [batteryPollCommand];

        // Also do initial stats model setup
        updateStatsModel();
    }

    // Reconnect on interval change
    Connections {
        target: dataSource
        function onSourceConnected(source) {
            console.log("BatteryGraph: connected to " + source);
        }
    }

    // Override the source name matching since we use the full command
    Binding {
        target: dataSource
        property: "connectedSources"
        value: [root.batteryPollCommand]
    }

    // Fix: The executable engine uses the command string as source name
    // We need to handle this in onNewData
    Connections {
        target: dataSource
        function onNewData(sourceName, data) {
            if (sourceName !== root.batteryPollCommand) return;

            var stdout = data["stdout"] || "";
            if (stdout.trim() === "") return;

            try {
                var parsed = JSON.parse(stdout.trim());
                root.currentBattery = parsed.battery_pct !== undefined ? parsed.battery_pct : -1;
                root.currentPower = parsed.power_watts !== undefined ? parsed.power_watts : 0;
                root.isCharging = parsed.charging || false;
                root.acPlugged = parsed.ac_online || false;
                root.batteryStatus = parsed.status || "Unknown";
                root.timeToEmpty = parsed.time_to_empty || "";
                root.timeToFull = parsed.time_to_full || "";
                root.designCapacity = parsed.design_capacity || 0;
                root.fullCapacity = parsed.full_capacity || 0;
                root.cycleCount = parsed.cycle_count !== undefined ? parsed.cycle_count : -1;

                if (root.designCapacity > 0 && root.fullCapacity > 0) {
                    root.batteryHealth = (root.fullCapacity / root.designCapacity) * 100;
                }

                // Update battery history
                if (root.currentBattery >= 0) {
                    var bh = root.batteryHistory.slice();
                    bh.push(root.currentBattery);
                    if (bh.length > root.maxDataPoints) bh.shift();
                    root.batteryHistory = bh;
                }

                // Update power history
                var ph = root.powerHistory.slice();
                ph.push(root.currentPower);
                if (ph.length > root.maxDataPoints) ph.shift();
                root.powerHistory = ph;

                // Auto-scale
                if (root.currentPower > root.maxPowerSeen) {
                    root.maxPowerSeen = Math.ceil(root.currentPower / 5) * 5 + 5;
                }

                updateStatsModel();
                graphCanvas.requestPaint();
            } catch (e) {
                console.log("BatteryGraph: JSON parse error: " + e + " | raw: " + stdout);
            }
        }
    }

    // Tooltip
    toolTipMainText: "Battery: " + (currentBattery >= 0 ? Math.round(currentBattery) + "%" : "N/A")
    toolTipSubText: currentPower.toFixed(1) + "W" + (isCharging ? " ⚡ Charging" : "")
}
