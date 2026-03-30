import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ── Config ───────────────────────────────────────────────────────
    readonly property int refreshMs: plasmoid.configuration.refreshInterval * 1000
    readonly property int maxDataPoints: Math.max(10,
        Math.floor(plasmoid.configuration.historyMinutes * 60 / plasmoid.configuration.refreshInterval))
    // Battery% & temp: 10× retention window, sampled 1/10 as often → same array length
    readonly property int maxDataPointsLong: maxDataPoints
    readonly property int graphHeight: 180
    readonly property int graphWidth: 360

    // ── Semantic colors ──────────────────────────────────────────────
    readonly property color colorBattery:    Kirigami.Theme.positiveTextColor
    readonly property color colorBatteryLow: Kirigami.Theme.negativeTextColor
    readonly property color colorBatteryMid: Kirigami.Theme.neutralTextColor
    readonly property color colorPower:      Kirigami.Theme.highlightColor
    readonly property color colorCharging:   Kirigami.Theme.positiveTextColor
    readonly property color colorTemp:       "#ff8844"  // warm orange for temperature
    readonly property color colorText:       Kirigami.Theme.disabledTextColor
    readonly property color colorTextBright: Kirigami.Theme.textColor
    readonly property color colorGrid:       Qt.rgba(Kirigami.Theme.textColor.r,
                                                      Kirigami.Theme.textColor.g,
                                                      Kirigami.Theme.textColor.b, 0.1)
    readonly property color colorGridAccent: Qt.rgba(Kirigami.Theme.highlightColor.r,
                                                      Kirigami.Theme.highlightColor.g,
                                                      Kirigami.Theme.highlightColor.b, 0.2)
    readonly property color colorCardBg:     Qt.rgba(Kirigami.Theme.backgroundColor.r,
                                                      Kirigami.Theme.backgroundColor.g,
                                                      Kirigami.Theme.backgroundColor.b, 0.3)

    // ── Data state ───────────────────────────────────────────────────
    property int pollCounter: 0   // counts poll cycles; battery% & temp sample every 10th
    property var batteryHistory: []
    property var powerHistory: []
    property var tempHistory: []
    property real currentBattery: -1
    property real currentPower: 0.0
    property real currentTemp: -1       // °C, -1 = unavailable
    property bool isCharging: false
    property bool acPlugged: false
    property string batteryStatus: "Unknown"
    property real maxPowerSeen: 25.0
    property real maxTempSeen: 60.0     // auto-scales
    property string timeToEmpty: ""
    property string timeToFull: ""
    property real designCapacity: 0
    property real fullCapacity: 0
    property real batteryHealth: 0
    property int cycleCount: -1
    property int viewMode: 1            // 0 = battery%, 1 = power, 2 = temp
    property string currentProfile: ""   // power-profiles-daemon active profile
    property var availableProfiles: []   // list of available profiles
    property bool ppdAvailable: false    // whether net.hadess.PowerProfiles D-Bus service is present
    property string tunedProfile: ""      // TuneD active profile
    property var tunedProfiles: []        // list of {name, desc} objects
    property var tunedProfileNames: []    // just names for setTunedProfile
    property var tunedDisplayNames: []    // "name - description" for combobox display
    property bool tunedAvailable: false   // whether tuned-adm is present
    property bool tunedSwitching: false   // true while user-initiated switch is in flight
    // Bump this to signal the graph to repaint (avoids cross-scope id refs)
    property int dataVersion: 0

    // ── Tooltip & background ─────────────────────────────────────────
    toolTipMainText: "Battery: " + (currentBattery >= 0 ? Math.round(currentBattery) + "%" : "N/A")
    toolTipSubText: currentPower.toFixed(1) + "W" +
        (currentTemp >= 0 ? " · " + currentTemp.toFixed(1) + "°C" : "") +
        (isCharging ? " ⚡ Charging" : "")
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground

    // ── Shell command ────────────────────────────────────────────────
    readonly property string pollCommand: {
        // Locate the poll script in the plasmoid package
        var scriptDir = Qt.resolvedUrl("../scripts/battery-poll.sh").toString().replace("file://", "");
        return "bash " + scriptDir;
    }


    // ── Executable data source ───────────────────────────────────────
    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            var stdout = data["stdout"] || "";
            executable.disconnectSource(sourceName);

            if (stdout.trim() === "") return;

            try {
                var parsed = JSON.parse(stdout.trim());

                root.currentBattery = (parsed.battery_pct !== undefined) ? parsed.battery_pct : -1;
                root.currentPower = (parsed.power_watts !== undefined) ? parsed.power_watts : 0;
                root.isCharging = parsed.charging || false;
                root.acPlugged = parsed.ac_online || false;
                root.batteryStatus = parsed.status || "Unknown";
                root.timeToEmpty = parsed.time_to_empty || "";
                root.timeToFull = parsed.time_to_full || "";
                root.designCapacity = parsed.design_capacity || 0;
                root.fullCapacity = parsed.full_capacity || 0;
                root.cycleCount = (parsed.cycle_count !== undefined) ? parsed.cycle_count : -1;
                root.currentTemp = (parsed.temp_celsius !== undefined) ? parsed.temp_celsius : -1;

                // Power profile
                var pp = parsed.power_profile || "";
                root.currentProfile = pp;
                var pa = parsed.profiles_available || "";
                if (pa !== "") {
                    root.availableProfiles = pa.split(",").filter(function(s) { return s !== ""; });
                    root.ppdAvailable = true;
                } else if (pp !== "") {
                    // D-Bus service is running (we got ActiveProfile) but couldn't parse Profiles list
                    // Fall back to standard profiles
                    root.availableProfiles = ["power-saver", "balanced", "performance"];
                    root.ppdAvailable = true;
                } else {
                    root.availableProfiles = [];
                    root.ppdAvailable = false;
                }

                // TuneD profiles
                var tp = parsed.tuned_profile || "";
                // Clear user-switching lock once the daemon confirms the new profile
                if (tp !== "" && tp !== root.tunedProfile && root.tunedSwitching) {
                    root.tunedSwitching = false;
                }
                root.tunedProfile = tp;
                var ta = parsed.tuned_available || "";
                if (ta !== "") {
                    var entries = ta.split("|").filter(function(s) { return s.trim() !== ""; });
                    var names = [];
                    var display = [];
                    for (var ti = 0; ti < entries.length; ti++) {
                        var parts = entries[ti].split(/ {2,}- /);  // split on "  - " (2+ spaces then dash)
                        var pname = parts[0].trim();
                        var pdesc = parts.length > 1 ? parts[1].trim() : "";
                        names.push(pname);
                        display.push(pdesc ? pname + " — " + pdesc : pname);
                    }
                    root.tunedProfileNames = names;
                    root.tunedDisplayNames = display;
                    root.tunedAvailable = true;
                } else {
                    root.tunedProfileNames = [];
                    root.tunedDisplayNames = [];
                    root.tunedAvailable = (tp !== "");
                }

                if (root.designCapacity > 0 && root.fullCapacity > 0) {
                    root.batteryHealth = (root.fullCapacity / root.designCapacity) * 100;
                }

                // Power history: every poll cycle
                var ph = root.powerHistory.slice();
                ph.push(root.currentPower);
                if (ph.length > root.maxDataPoints) ph.shift();
                root.powerHistory = ph;

                // Battery% & temp: sample every 10th poll for 10× longer retention
                root.pollCounter++;
                if (root.pollCounter % 10 === 0) {
                    if (root.currentBattery >= 0) {
                        var bh = root.batteryHistory.slice();
                        bh.push(root.currentBattery);
                        if (bh.length > root.maxDataPointsLong) bh.shift();
                        root.batteryHistory = bh;
                    }

                    if (root.currentTemp >= 0) {
                        var th = root.tempHistory.slice();
                        th.push(root.currentTemp);
                        if (th.length > root.maxDataPointsLong) th.shift();
                        root.tempHistory = th;
                    }
                }

                if (root.currentPower > root.maxPowerSeen) {
                    root.maxPowerSeen = Math.ceil(root.currentPower / 5) * 5 + 5;
                }
                if (root.currentTemp > root.maxTempSeen) {
                    root.maxTempSeen = Math.ceil(root.currentTemp / 10) * 10 + 10;
                }

                updateStatsModel();
                // Signal the graph to repaint via dataVersion bump
                root.dataVersion++;

            } catch (e) {
                console.log("BatteryGraph: parse error: " + e + " | raw: " + stdout);
            }
        }
    }

    function execCommand() {
        executable.connectSource(root.pollCommand);
    }

    // ── Profile setter (separate source so it doesn't collide with poll) ─
    Plasma5Support.DataSource {
        id: profileSetter
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            profileSetter.disconnectSource(sourceName);
            // Re-poll immediately to update the displayed profile
            root.execCommand();
        }
    }

    function setProfile(profileName) {
        // Use powerprofilesctl if available, otherwise gdbus
        profileSetter.connectSource(
            "if command -v powerprofilesctl >/dev/null 2>&1; then " +
            "powerprofilesctl set " + profileName + "; else " +
            "gdbus call --system --dest net.hadess.PowerProfiles " +
            "--object-path /net/hadess/PowerProfiles " +
            "--method org.freedesktop.DBus.Properties.Set net.hadess.PowerProfiles ActiveProfile " +
            "\"<string '" + profileName + "'>\"" +
            "; fi");
    }

    // ── TuneD profile setter (requires root via pkexec) ──────────────
    Plasma5Support.DataSource {
        id: tunedSetter
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            tunedSetter.disconnectSource(sourceName);
            root.execCommand();
        }
    }

    function setTunedProfile(profileName) {
        tunedSetter.connectSource("tuned-adm profile " + profileName);
    }

    // ── Timer ────────────────────────────────────────────────────────
    Timer {
        id: pollTimer
        interval: root.refreshMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.execCommand()
    }

    // ── Compact representation (vertical battery icon for systray) ──
    compactRepresentation: Item {
        id: compactRoot
        Layout.minimumWidth: Kirigami.Units.iconSizes.medium
        Layout.minimumHeight: Kirigami.Units.iconSizes.medium
        Layout.preferredWidth: Layout.minimumWidth
        Layout.preferredHeight: Layout.minimumHeight

        Canvas {
            id: batteryIcon
            anchors.fill: parent

            property real pct: root.currentBattery
            property bool charging: root.isCharging
            property bool plugged: root.acPlugged
            onPctChanged: requestPaint()
            onChargingChanged: requestPaint()
            onPluggedChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d");
                var w = width;
                var h = height;
                ctx.clearRect(0, 0, w, h);

                var pct = Math.max(0, Math.min(100, root.currentBattery));
                var lw = Math.max(1, Math.round(Math.min(w, h) * 0.04));

                // ── Horizontal battery body (nub on right) ──
                var nubW = Math.max(2, w * 0.06);
                var nubH = h * 0.3;
                var nubX = w * 0.88;
                var nubY = (h - nubH) / 2;

                ctx.beginPath();
                ctx.roundedRect(nubX, nubY, nubW, nubH, 1, 1);
                ctx.fillStyle = Kirigami.Theme.textColor.toString();
                ctx.fill();

                // Main body / 电池主体
                var bodyX = w * 0.06;                    // Body X position: 6% from left / 主体 X 位置：距左侧 6%
                var bodyY = h * 0.25;                    // Body Y position: 20% from top for vertical centering / 主体 Y 位置：距顶部 20% 以垂直居中
                var bodyW = w * 0.82;                    // Body width: 82% of canvas width / 主体宽度：画布宽度的 82%
                var bodyH = h * 0.5;                     // Body height: 60% of canvas height (adjusted for better proportion) / 主体高度：画布高度的 60%（调整以获得更好的比例）
                var r = Math.max(2, bodyH * 0.15);       // Corner radius: 15% of body height, minimum 2px / 圆角半径：主体高度的 15%，最小 2 像素

                ctx.beginPath();
                ctx.roundedRect(bodyX, bodyY, bodyW, bodyH, r, r);
                ctx.strokeStyle = Kirigami.Theme.textColor.toString();
                ctx.lineWidth = lw;
                ctx.stroke();

                // ── Fill level (grows left to right) ──
                if (root.currentBattery >= 0) {
                    var inset = lw + 1;
                    var fillX = bodyX + inset;
                    var fillY = bodyY + inset;
                    var fillMaxW = bodyW - inset * 2;
                    var fillH = bodyH - inset * 2;
                    var fillW = fillMaxW * (pct / 100);
                    var fillR = Math.max(1, r * 0.5);

                    var fillColor;
                    if (root.isCharging) {
                        fillColor = root.colorCharging;
                    } else if (pct <= 20) {
                        fillColor = root.colorBatteryLow;
                    } else if (pct <= 40) {
                        fillColor = root.colorBatteryMid;
                    } else {
                        fillColor = root.colorBattery;
                    }

                    if (fillW > 0) {
                        ctx.beginPath();
                        ctx.roundedRect(fillX, fillY, Math.max(fillR * 2, fillW), fillH, fillR, fillR);
                        ctx.fillStyle = fillColor.toString();
                        ctx.fill();
                    }
                }

                // ── Charging: lightning bolt ──
                if (root.isCharging) {
                    var cx = bodyX + bodyW * 0.5;
                    var cy = h * 0.5;
                    var bh = bodyH * 0.5;
                    var bw = bh * 0.4;

                    ctx.beginPath();
                    ctx.moveTo(cx + bw * 0.05, cy - bh * 0.5);
                    ctx.lineTo(cx - bw * 0.4,  cy + bh * 0.05);
                    ctx.lineTo(cx + bw * 0.05, cy + bh * 0.05);
                    ctx.lineTo(cx - bw * 0.05, cy + bh * 0.5);
                    ctx.lineTo(cx + bw * 0.4,  cy - bh * 0.05);
                    ctx.lineTo(cx - bw * 0.05, cy - bh * 0.05);
                    ctx.closePath();
                    ctx.fillStyle = Kirigami.Theme.backgroundColor.toString();
                    ctx.fill();
                    ctx.strokeStyle = Kirigami.Theme.textColor.toString();
                    ctx.lineWidth = Math.max(0.5, w * 0.03);
                    ctx.stroke();
                }
                // ── Plugged in (not charging): plug icon ──
                else if (root.acPlugged) {
                    var px = bodyX + bodyW * 0.5;
                    var py = h * 0.5;
                    var ps = Math.max(3, bodyH * 0.12);

                    ctx.beginPath();
                    ctx.roundedRect(px - ps, py - ps * 0.6, ps * 2, ps * 1.2, 1, 1);
                    ctx.fillStyle = Kirigami.Theme.backgroundColor.toString();
                    ctx.fill();
                    ctx.strokeStyle = Kirigami.Theme.textColor.toString();
                    ctx.lineWidth = Math.max(0.8, w * 0.04);
                    ctx.stroke();

                    var prongW = Math.max(1, ps * 0.25);
                    ctx.fillStyle = Kirigami.Theme.textColor.toString();
                    ctx.fillRect(px - ps * 0.45, py - ps * 0.6 - ps * 0.5, prongW, ps * 0.5);
                    ctx.fillRect(px + ps * 0.2,  py - ps * 0.6 - ps * 0.5, prongW, ps * 0.5);
                }
            }
        }

        MouseArea {
            id: compactMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.expanded = !root.expanded
        }
    }

    // ── Full representation ──────────────────────────────────────────
    fullRepresentation: ColumnLayout {
        id: fullRep
        Layout.preferredWidth: root.graphWidth + 40
        Layout.preferredHeight: root.graphHeight + 260
        Layout.minimumWidth: 280
        Layout.minimumHeight: 200
        spacing: Kirigami.Units.smallSpacing * 2

        // Whether there's enough room below the graph for stats
        readonly property bool showStats: fullRep.height > root.graphHeight + 180

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing * 2

            Item {
                width: 32; height: 32
                Rectangle {
                    anchors.centerIn: parent
                    width: 28; height: 28; radius: 14
                    color: "transparent"
                    border.color: root.isCharging ? root.colorCharging : root.batteryColor(root.currentBattery)
                    border.width: 2; opacity: 0.4
                }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 22; height: 22
                    source: root.isCharging ? "battery-charging" : "battery-full"
                    color: root.isCharging ? root.colorCharging : root.batteryColor(root.currentBattery)
                }
            }

            ColumnLayout {
                spacing: 0
                PlasmaExtras.Heading {
                    text: "Power Monitor"
                    level: 4
                }
                PlasmaComponents.Label {
                    text: root.batteryStatus
                    font: Kirigami.Theme.smallFont
                    color: root.isCharging ? root.colorCharging : root.colorText
                }
            }

            Item { Layout.fillWidth: true }

            ColumnLayout {
                spacing: 0
                PlasmaComponents.Label {
                    Layout.alignment: Qt.AlignRight
                    text: root.viewMode === 0
                        ? (root.currentBattery >= 0 ? Math.round(root.currentBattery) + "%" : "N/A")
                        : root.viewMode === 1
                        ? root.currentPower.toFixed(1) + "W"
                        : (root.currentTemp >= 0 ? root.currentTemp.toFixed(1) + "°C" : "N/A")
                    font.pixelSize: 22
                    font.weight: Font.Bold
                    font.family: "monospace"
                    color: root.viewMode === 0
                        ? root.batteryColor(root.currentBattery)
                        : root.viewMode === 1 ? root.colorPower : root.tempColor(root.currentTemp)
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
                    font: Kirigami.Theme.smallFont
                    color: root.colorText
                }
            }
        }

        // Tab bar
        PlasmaComponents.TabBar {
            Layout.fillWidth: true
            PlasmaComponents.TabButton {
                text: "Power (W)"
                checked: root.viewMode === 1
                onClicked: { root.viewMode = 1; graphCanvas.requestPaint(); }
            }
            PlasmaComponents.TabButton {
                text: "Battery %"
                checked: root.viewMode === 0
                onClicked: { root.viewMode = 0; graphCanvas.requestPaint(); }
            }
            PlasmaComponents.TabButton {
                text: "Temp (°C)"
                checked: root.viewMode === 2
                enabled: root.currentTemp >= 0
                onClicked: { root.viewMode = 2; graphCanvas.requestPaint(); }
            }
        }

        // Graph
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 100
            Layout.preferredHeight: root.graphHeight
            color: root.colorCardBg
            radius: Kirigami.Units.smallSpacing
            border.color: root.colorGrid
            border.width: 1
            clip: true

            Canvas {
                id: graphCanvas
                anchors.fill: parent
                anchors.margins: 1

                // Repaint when data arrives or theme changes
                property int watchVersion: root.dataVersion
                onWatchVersionChanged: requestPaint()
                property color themeText: root.colorText
                onThemeTextChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    var w = width, h = height;
                    var pad = { top: 12, right: 10, bottom: 22, left: 38 };
                    var gw = w - pad.left - pad.right;
                    var gh = h - pad.top - pad.bottom;
                    ctx.clearRect(0, 0, w, h);

                    // Grid
                    ctx.strokeStyle = root.colorGrid.toString();
                    ctx.lineWidth = 0.5;
                    var i, y, val, x;
                    for (i = 0; i <= 4; i++) {
                        y = pad.top + (gh / 4) * i;
                        ctx.beginPath();
                        ctx.moveTo(pad.left, y);
                        ctx.lineTo(pad.left + gw, y);
                        ctx.stroke();
                    }

                    // Y-axis
                    ctx.fillStyle = root.colorText.toString();
                    ctx.font = "9px monospace";
                    ctx.textAlign = "right";
                    ctx.textBaseline = "middle";
                    var maxVal = root.viewMode === 0 ? 100 : root.viewMode === 1 ? root.maxPowerSeen : root.maxTempSeen;
                    var minVal = root.viewMode === 2 ? 20 : 0;
                    var unit = root.viewMode === 0 ? "%" : root.viewMode === 1 ? "W" : "°C";
                    for (i = 0; i <= 4; i++) {
                        val = maxVal - (maxVal - minVal) * (i / 4);
                        y = pad.top + (gh / 4) * i;
                        ctx.fillText(val.toFixed(root.viewMode === 0 ? 0 : root.viewMode === 2 ? 0 : 1) + unit, pad.left - 4, y);
                    }

                    // X-axis
                    ctx.textAlign = "center";
                    ctx.textBaseline = "top";
                    var data = root.viewMode === 0 ? root.batteryHistory
                             : root.viewMode === 1 ? root.powerHistory
                             : root.tempHistory;
                    var numPoints = data.length;
                    // Battery% & temp are sampled 10× less often
                    var intervalSec = root.viewMode === 1
                        ? plasmoid.configuration.refreshInterval
                        : plasmoid.configuration.refreshInterval * 10;

                    var maxPts = root.viewMode === 1 ? root.maxDataPoints : root.maxDataPointsLong;
                    if (numPoints > 1) {
                        var labels = [0, Math.floor(numPoints * 0.25), Math.floor(numPoints * 0.5),
                                      Math.floor(numPoints * 0.75), numPoints - 1];
                        for (var li = 0; li < labels.length; li++) {
                            var idx = labels[li];
                            if (idx < numPoints) {
                                x = pad.left + (idx / (maxPts - 1)) * gw;
                                var secsAgo = (numPoints - 1 - idx) * intervalSec;
                                var label;
                                if (secsAgo === 0) label = "now";
                                else if (secsAgo < 60) label = "-" + secsAgo + "s";
                                else label = "-" + Math.floor(secsAgo / 60) + "m";
                                ctx.fillText(label, x, pad.top + gh + 4);
                            }
                        }
                    }

                    if (numPoints < 2) {
                        ctx.fillStyle = root.colorText.toString();
                        ctx.font = "11px sans-serif";
                        ctx.textAlign = "center";
                        ctx.textBaseline = "middle";
                        ctx.fillText("Collecting data... (" + numPoints + " sample" + (numPoints !== 1 ? "s" : "") + ")", w / 2, h / 2);
                        return;
                    }

                    var lineColor = root.viewMode === 0
                        ? root.batteryColor(root.currentBattery).toString()
                        : root.viewMode === 1
                        ? root.colorPower.toString()
                        : root.tempColor(root.currentTemp).toString();
                    var cObj = root.viewMode === 0
                        ? root.batteryColorObj(root.currentBattery)
                        : root.viewMode === 1
                        ? (function() { var c = root.colorPower; return { r: c.r, g: c.g, b: c.b }; })()
                        : root.tempColorObj(root.currentTemp);

                    // Area gradient
                    var gradient = ctx.createLinearGradient(0, pad.top, 0, pad.top + gh);
                    gradient.addColorStop(0, Qt.rgba(cObj.r, cObj.g, cObj.b, 0.3));
                    gradient.addColorStop(1, Qt.rgba(cObj.r, cObj.g, cObj.b, 0.02));

                    // Area
                    ctx.beginPath();
                    for (i = 0; i < numPoints; i++) {
                        x = pad.left + (i / (maxPts - 1)) * gw;
                        val = Math.max(minVal, Math.min(maxVal, data[i]));
                        y = pad.top + gh - ((val - minVal) / (maxVal - minVal)) * gh;
                        if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                    }
                    var lastX = pad.left + ((numPoints - 1) / (maxPts - 1)) * gw;
                    ctx.lineTo(lastX, pad.top + gh);
                    ctx.lineTo(pad.left, pad.top + gh);
                    ctx.closePath();
                    ctx.fillStyle = gradient;
                    ctx.fill();

                    // Line
                    ctx.beginPath();
                    for (i = 0; i < numPoints; i++) {
                        x = pad.left + (i / (maxPts - 1)) * gw;
                        val = Math.max(minVal, Math.min(maxVal, data[i]));
                        y = pad.top + gh - ((val - minVal) / (maxVal - minVal)) * gh;
                        if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                    }
                    ctx.strokeStyle = lineColor;
                    ctx.lineWidth = 2;
                    ctx.stroke();

                    // Dot
                    if (numPoints > 0) {
                        var lastVal = data[numPoints - 1];
                        var dotX = pad.left + ((numPoints - 1) / (maxPts - 1)) * gw;
                        var dotY = pad.top + gh - ((Math.max(minVal, Math.min(maxVal, lastVal)) - minVal) / (maxVal - minVal)) * gh;

                        ctx.beginPath();
                        ctx.arc(dotX, dotY, 6, 0, 2 * Math.PI);
                        ctx.fillStyle = Qt.rgba(cObj.r, cObj.g, cObj.b, 0.25);
                        ctx.fill();
                        ctx.beginPath();
                        ctx.arc(dotX, dotY, 3, 0, 2 * Math.PI);
                        ctx.fillStyle = lineColor;
                        ctx.fill();
                    }
                }
            }
        }

        // ── Power Profile Switcher ───────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            visible: root.ppdAvailable && plasmoid.configuration.showPowerProfile && fullRep.showStats
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: "Profile:"
                font: Kirigami.Theme.smallFont
                color: root.colorText
            }

            Repeater {
                model: root.availableProfiles
                delegate: PlasmaComponents.ToolButton {
                    Layout.fillWidth: true
                    text: {
                        var label = modelData;
                        if (label === "power-saver") return "🔋 Saver";
                        if (label === "balanced") return "⚖️ Balanced";
                        if (label === "performance") return "🚀 Performance";
                        return label;
                    }
                    checked: root.currentProfile === modelData
                    font: Kirigami.Theme.smallFont
                    onClicked: root.setProfile(modelData)
                }
            }
        }

        // ── TuneD Profile Switcher ─────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            visible: root.tunedAvailable && fullRep.showStats
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: "TuneD:"
                font: Kirigami.Theme.smallFont
                color: root.colorText
            }

            PlasmaComponents.ComboBox {
                id: tunedCombo
                Layout.fillWidth: true
                model: root.tunedDisplayNames
                font: Kirigami.Theme.smallFont

                // Only sync from poll when user isn't mid-switch
                Connections {
                    target: root
                    function onTunedProfileChanged() {
                        if (!root.tunedSwitching) {
                            tunedCombo.currentIndex = root.tunedProfileNames.indexOf(root.tunedProfile);
                        }
                    }
                }
                onModelChanged: currentIndex = root.tunedProfileNames.indexOf(root.tunedProfile)

                onActivated: (index) => {
                    root.tunedSwitching = true;
                    root.setTunedProfile(root.tunedProfileNames[index]);
                }
            }
        }

        // Stats grid — hidden when widget is shrunk
        GridLayout {
            Layout.fillWidth: true
            visible: fullRep.showStats
            columns: 2
            rowSpacing: Kirigami.Units.smallSpacing
            columnSpacing: Kirigami.Units.smallSpacing

            Repeater {
                model: statsModel
                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: Kirigami.Units.smallSpacing
                    color: root.colorCardBg
                    border.color: root.colorGrid
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents.Label {
                            text: model.label
                            font: Kirigami.Theme.smallFont
                            color: root.colorText
                        }
                        Item { Layout.fillWidth: true }
                        PlasmaComponents.Label {
                            text: model.value
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.family: "monospace"
                            color: model.accent !== "" ? model.accent : root.colorTextBright
                        }
                    }
                }
            }
        }

        // Battery health bar
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            visible: root.batteryHealth > 0 && fullRep.showStats

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Label {
                    text: "Battery Health"
                    font: Kirigami.Theme.smallFont
                    color: root.colorText
                }
                Item { Layout.fillWidth: true }
                PlasmaComponents.Label {
                    text: root.batteryHealth.toFixed(1) + "%"
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    font.weight: Font.Bold
                    color: root.batteryHealth > 80 ? root.colorBattery :
                           root.batteryHealth > 50 ? root.colorBatteryMid : root.colorBatteryLow
                }
            }
            Rectangle {
                Layout.fillWidth: true
                height: 4; radius: 2
                color: root.colorGrid
                Rectangle {
                    width: parent.width * Math.min(1.0, root.batteryHealth / 100)
                    height: parent.height; radius: 2
                    color: root.batteryHealth > 80 ? root.colorBattery :
                           root.batteryHealth > 50 ? root.colorBatteryMid : root.colorBatteryLow
                }
            }
        }
    }

    // ── Stats model ──────────────────────────────────────────────────
    ListModel { id: statsModel }

    function updateStatsModel() {
        statsModel.clear();
        statsModel.append({ label: "Battery",
            value: root.currentBattery >= 0 ? Math.round(root.currentBattery) + "%" : "N/A",
            accent: root.batteryColor(root.currentBattery).toString() });
        statsModel.append({ label: "Status",
            value: root.isCharging ? "⚡ Charging" : (root.acPlugged ? "Plugged In" : "Discharging"),
            accent: root.isCharging ? root.colorCharging.toString() : "" });
        statsModel.append({ label: "Temperature",
            value: root.currentTemp >= 0 ? root.currentTemp.toFixed(1) + " °C" : "N/A",
            accent: root.currentTemp >= 0 ? root.tempColor(root.currentTemp).toString() : "" });
        statsModel.append({ label: "Cycle Count",
            value: root.cycleCount >= 0 ? root.cycleCount.toString() : "N/A",
            accent: "" });
    }

    // ── Helpers ──────────────────────────────────────────────────────
    function batteryColor(pct) {
        if (pct < 0) return root.colorText;
        if (pct <= 20) return root.colorBatteryLow;
        if (pct <= 40) return root.colorBatteryMid;
        return root.colorBattery;
    }

    function batteryColorObj(pct) {
        var c;
        if (pct <= 20) { c = root.colorBatteryLow; return { r: c.r, g: c.g, b: c.b }; }
        if (pct <= 40) { c = root.colorBatteryMid;  return { r: c.r, g: c.g, b: c.b }; }
        c = root.colorBattery; return { r: c.r, g: c.g, b: c.b };
    }

    // Temperature color: cool (green) → warm (orange) → hot (red)
    function tempColor(deg) {
        if (deg < 0) return root.colorText;
        if (deg <= 35) return root.colorBattery;       // cool — green
        if (deg <= 45) return root.colorTemp;           // warm — orange
        return root.colorBatteryLow;                    // hot — red
    }

    function tempColorObj(deg) {
        var c = root.tempColor(deg);
        return { r: c.r, g: c.g, b: c.b };
    }

    Component.onCompleted: {
        updateStatsModel();
    }
}
