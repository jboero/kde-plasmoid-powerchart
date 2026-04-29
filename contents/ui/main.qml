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
    readonly property bool showBatteryPercentage: plasmoid.configuration.showBatteryPercentage  // Show/hide battery percentage in compact mode / 紧凑模式下显示/隐藏电池百分比

    // ── Semantic colors ──────────────────────────────────────────────
    readonly property color colorBattery:    Kirigami.Theme.positiveTextColor
    readonly property color colorBatteryLow: Kirigami.Theme.negativeTextColor
    readonly property color colorBatteryMid: Kirigami.Theme.neutralTextColor
    readonly property color colorPower:      Kirigami.Theme.highlightColor
    readonly property color colorCharging:   Kirigami.Theme.positiveTextColor
    readonly property color colorPluggedAC:  "#4a90e2"  // blue for AC plugged but not charging / 蓝色表示接通电源但未充电
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
    // powerHistory stores tuples {v, c, p} = {batteryWatts, charging?, systemWatts at sample time}.
    // Historical points are frozen at the source that was active when sampled — switching
    // source only affects new samples and the live readouts.
    property var powerHistory: []
    property var tempHistory: []
    property real currentBattery: -1
    property real currentPower: 0.0
    property real currentTemp: -1       // °C, -1 = unavailable
    property bool isCharging: false
    property bool acPlugged: false
    property bool hasBattery: true
    property string batteryStatus: "Unknown"
    property real maxPowerSeen: 25.0
    property real maxTempSeen: 60.0     // auto-scales
    property string timeToEmpty: ""
    property string timeToFull: ""
    property real designCapacity: 0
    property real fullCapacity: 0
    property real batteryHealth: 0
    property int cycleCount: -1

    // ── RAPL system-power: PSYS + package, user-selectable ────────────
    // Both readings are sampled every poll; the user picks which one drives
    // currentSystemWatts via the raplSource config (psys|package|none).
    property real lastPsysEnergyUj: -1
    property real lastPsysTs: -1
    property real psysMaxUj: -1
    property real psysWatts: -1            // derived from PSYS deltas; -1 = no reading
    property string psysStatus: "unavailable"  // "ok" | "locked" | "unavailable"

    property real lastPkgEnergyUj: -1
    property real lastPkgTs: -1
    property real pkgMaxUj: -1
    property real pkgWatts: -1
    property string pkgStatus: "unavailable"

    // User-selected source label and resolved watts.
    readonly property string activeRaplSource: plasmoid.configuration.raplSource || "none"
    readonly property real currentSystemWatts: {
        if (activeRaplSource === "psys") return psysWatts;
        if (activeRaplSource === "package") return pkgWatts;
        return -1;  // "none" → overlay disabled
    }
    readonly property string activeRaplStatus: {
        if (activeRaplSource === "psys") return psysStatus;
        if (activeRaplSource === "package") return pkgStatus;
        return "disabled";
    }
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
    toolTipMainText: hasBattery
        ? "Battery: " + (currentBattery >= 0 ? Math.round(currentBattery) + "%" : "N/A")
        : (currentSystemWatts >= 0 ? "System: " + currentSystemWatts.toFixed(1) + "W" : "Power Monitor")
    toolTipSubText: {
        var lines = [];
        if (hasBattery) {
            var w = currentPower.toFixed(1) + "W";
            if (isCharging) lines.push("⚡ Charging at " + w);
            else lines.push("Discharging " + w);
        }
        if (currentSystemWatts >= 0)
            lines.push("System: " + currentSystemWatts.toFixed(1) + "W"
                + (activeRaplSource === "package" ? " (CPU only)" : ""));
        else if (activeRaplStatus === "locked" && !hasBattery)
            lines.push("System power locked — see Configure");
        else if (activeRaplSource === "none")
            { /* user disabled */ }
        if (currentTemp >= 0) lines.push(currentTemp.toFixed(1) + "°C");
        if (currentProfile !== "") lines.push("Profile: " + profileLabel(currentProfile));
        return lines.join("\n");
    }
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
                root.hasBattery = parsed.has_battery !== undefined ? parsed.has_battery : (root.currentBattery >= 0);
                root.batteryStatus = parsed.status || "Unknown";
                root.timeToEmpty = parsed.time_to_empty || "";
                root.timeToFull = parsed.time_to_full || "";
                root.designCapacity = parsed.design_capacity || 0;
                root.fullCapacity = parsed.full_capacity || 0;
                root.cycleCount = (parsed.cycle_count !== undefined) ? parsed.cycle_count : -1;
                root.currentTemp = (parsed.temp_celsius !== undefined) ? parsed.temp_celsius : -1;

                // RAPL — diff μJ against previous sample for watts.
                // PSYS and package are tracked independently; user config picks which
                // drives the displayed `currentSystemWatts`.
                var nowTs = (parsed.poll_ts !== undefined) ? parsed.poll_ts : -1;

                root.psysStatus = parsed.psys_status || "unavailable";
                root.psysMaxUj = (parsed.psys_max_uj !== undefined) ? parsed.psys_max_uj : -1;
                var psysE = (parsed.psys_energy_uj !== undefined) ? parsed.psys_energy_uj : -1;
                if (psysE >= 0 && nowTs > 0 && root.lastPsysEnergyUj >= 0 && root.lastPsysTs > 0) {
                    var pdt = nowTs - root.lastPsysTs;
                    var pde = psysE - root.lastPsysEnergyUj;
                    if (pde < 0 && root.psysMaxUj > 0) pde += root.psysMaxUj;
                    if (pdt > 0 && pde >= 0) root.psysWatts = pde / pdt / 1000000;
                } else if (psysE < 0) {
                    root.psysWatts = -1;
                }
                root.lastPsysEnergyUj = psysE;
                root.lastPsysTs = nowTs;

                root.pkgStatus = parsed.pkg_status || "unavailable";
                root.pkgMaxUj = (parsed.pkg_max_uj !== undefined) ? parsed.pkg_max_uj : -1;
                var pkgE = (parsed.pkg_energy_uj !== undefined) ? parsed.pkg_energy_uj : -1;
                if (pkgE >= 0 && nowTs > 0 && root.lastPkgEnergyUj >= 0 && root.lastPkgTs > 0) {
                    var kdt = nowTs - root.lastPkgTs;
                    var kde = pkgE - root.lastPkgEnergyUj;
                    if (kde < 0 && root.pkgMaxUj > 0) kde += root.pkgMaxUj;
                    if (kdt > 0 && kde >= 0) root.pkgWatts = kde / kdt / 1000000;
                } else if (pkgE < 0) {
                    root.pkgWatts = -1;
                }
                root.lastPkgEnergyUj = pkgE;
                root.lastPkgTs = nowTs;

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

                // Power history: every poll cycle, tuple {v, c, p}
                var ph = root.powerHistory.slice();
                ph.push({ v: root.currentPower, c: root.isCharging, p: root.currentSystemWatts });
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

                // Auto-scale considers both RAPL sources so switching doesn't clip history.
                var peak = Math.max(root.currentPower, root.psysWatts, root.pkgWatts);
                if (peak > root.maxPowerSeen) {
                    root.maxPowerSeen = Math.ceil(peak / 5) * 5 + 5;
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
        // Defense-in-depth: only accept names from the parsed available list before
        // building a shell command, so profile strings can't reach the shell unvetted.
        if (root.availableProfiles.indexOf(profileName) < 0) return;
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
        // Defense-in-depth: same whitelist pattern as setProfile.
        if (root.tunedProfileNames.indexOf(profileName) < 0) return;
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

    // ── Compact representation (square systray icon) ──
    // Strictly square: width = height. Percentage, when enabled, renders as a
    // centered overlay on the battery body (KDE-standard style) instead of as
    // a sibling label that would expand the icon's slot horizontally.
    compactRepresentation: Item {
        id: compactRoot
        Layout.minimumHeight: Kirigami.Units.iconSizes.medium
        Layout.minimumWidth: Layout.minimumHeight
        Layout.preferredHeight: Layout.minimumHeight
        Layout.preferredWidth: Layout.minimumHeight

        // Battery icon canvas — fills the whole compact item.
        Item {
            id: batteryIcon
            anchors.fill: parent
            visible: root.hasBattery

            Canvas {
                id: batteryCanvas
                anchors.fill: parent

                property real pct: root.currentBattery
                property bool charging: root.isCharging
                property bool plugged: root.acPlugged
                property string profile: root.currentProfile
                onPctChanged: requestPaint()
                onChargingChanged: requestPaint()
                onPluggedChanged: requestPaint()
                onProfileChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    var w = width;
                    var h = height;
                    ctx.clearRect(0, 0, w, h);

                    var pct = Math.max(0, Math.min(100, root.currentBattery));
                    var lw = Math.max(1, Math.round(Math.min(w, h) * 0.04));

                    // ── Horizontal battery body (nub on right) ──
                    // Main body dimensions / 主体尺寸
                    var bodyX = w * 0.06;                    // Body X position: 6% from left for proper spacing / 主体 X 位置：距左侧 6% 以获得适当间距
                    var bodyY = h * 0.25;                    // Body Y position: 25% from top for vertical centering / 主体 Y 位置：距顶部 25% 以垂直居中
                    var bodyW = w * 0.82;                    // Body width: 82% of canvas width / 主体宽度：画布宽度的 82%
                    var bodyH = h * 0.5;                     // Body height: 50% of canvas height / 主体高度：画布高度的 50%
                    var r = Math.max(2, bodyH * 0.25);       // Corner radius: 25% of body height (large rounded corners per design spec) / 圆角半径：主体高度的 25%（大圆角设计）

                    // Positive electrode (nub) - small and delicate on the right side / 正电极 - 右侧小巧精致
                    var nubW = Math.max(2, w * 0.045);       // Nub width: ~4.5% of canvas width (small and delicate) / 正极宽度：画布宽度的约 4.5%（小巧精致）
                    var nubH = h * 0.2;                      // Nub height: 20% of canvas height (smaller for better proportion) / 正极高度：画布高度的 20%（更小以获得更好的比例）
                    var nubX = bodyX + bodyW;                // Nub X position: immediately after battery body / 正极 X 位置：紧接电池主体之后
                    var nubY = (h - nubH) / 2;               // Nub Y position: vertically centered / 正极 Y 位置：垂直居中

                    // Draw positive electrode first (behind battery body) / 先绘制正电极（在电池主体后面）
                    ctx.beginPath();
                    ctx.roundedRect(nubX, nubY, nubW, nubH, 1, 1);
                    ctx.fillStyle = Kirigami.Theme.textColor.toString();
                    ctx.fill();

                    // Determine border color (always white/text color) / 确定边框颜色（始终为白色/文本颜色）
                    var borderColor = Kirigami.Theme.textColor.toString();
                    
                    // Determine fill color based on battery level and charging state / 根据电量和充电状态确定填充颜色
                    var fillColor;
                    
                    if (root.isCharging) {
                        // Charging: green fill / 充电中：绿色填充
                        fillColor = root.colorCharging;
                    } else if (root.acPlugged) {
                        // AC plugged but not charging: blue fill / 接通电源但未充电：蓝色填充
                        fillColor = root.colorPluggedAC;
                    } else if (pct <= 20) {
                        // Below 20%: red fill / 20% 以下：红色填充
                        fillColor = root.colorBatteryLow;
                    } else if (pct <= 30) {
                        // Between 20% and 30%: orange fill / 20% 到 30% 之间：橙色填充
                        fillColor = root.colorBatteryMid;
                    } else {
                        // Above 30%: normal/bright color / 30% 以上：正常/亮色填充
                        fillColor = Kirigami.Theme.textColor;
                    }

                    // Draw battery border / 绘制电池边框
                    ctx.beginPath();
                    ctx.roundedRect(bodyX, bodyY, bodyW, bodyH, r, r);
                    ctx.strokeStyle = borderColor;
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

                        if (fillW > 0) {
                            ctx.beginPath();
                            ctx.roundedRect(fillX, fillY, Math.max(fillR * 2, fillW), fillH, fillR, fillR);
                            ctx.fillStyle = fillColor.toString();
                            ctx.fill();
                        }
                    }

                    // ── Charging/Plugged: hide icons (no lightning bolt or plug icon) ──
                    // 充电/接通电源：隐藏图标（不显示闪电或插头图标）
                    // Icons are intentionally omitted when charging or plugged in
                    // 当充电或接通电源时故意省略图标
                }

                // Power-profile glyph badge in the bottom-right corner of the battery icon.
                // Renders only when a profile is active.
                Text {
                    visible: root.currentProfile !== ""
                    text: root.profileGlyph(root.currentProfile)
                    color: Kirigami.Theme.textColor
                    font.pixelSize: Math.max(8, parent.height * 0.42)
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: -1
                    anchors.bottomMargin: -2
                }
            }

            // Optional centered percentage overlay on the battery body (KDE-standard
            // style). Off by default — the tooltip already shows the precise reading,
            // and a sibling label would expand the systray slot horizontally.
            Text {
                anchors.centerIn: parent
                visible: root.showBatteryPercentage && root.currentBattery >= 0
                text: Math.round(root.currentBattery)
                color: Kirigami.Theme.textColor
                font.pixelSize: Math.max(7, Math.round(parent.height * 0.36))
                font.bold: true
                // Subtle outline so the digit reads on top of any fill color.
                style: Text.Outline
                styleColor: Kirigami.Theme.backgroundColor
            }
        }

        // No-battery layout: profile glyph centered, with an optional watts line below
        // when showBatteryPercentage is enabled. Stacked vertically to keep the systray
        // slot square instead of expanding horizontally.
        Column {
            id: noBatteryStack
            anchors.centerIn: parent
            visible: !root.hasBattery
            spacing: 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.currentProfile !== ""
                text: root.profileGlyph(root.currentProfile)
                color: Kirigami.Theme.textColor
                font.pixelSize: Math.max(10, Math.round(compactRoot.height
                    * (root.showBatteryPercentage ? 0.5 : 0.7)))
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.showBatteryPercentage && root.currentSystemWatts >= 0
                text: Math.round(root.currentSystemWatts) + "W"
                color: Kirigami.Theme.textColor
                font.pixelSize: Math.max(7, Math.round(compactRoot.height * 0.32))
                font.bold: true
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
                    source: !root.hasBattery
                        ? "ac-adapter"
                        : (root.isCharging ? "battery-charging" : "battery-full")
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
                id: headlineCol
                spacing: 0
                // In Power view, prefer the selected system reading over the battery
                // wattage so the big number is non-redundant with the sublabel.
                readonly property bool powerShowsSystem: root.viewMode === 1 && root.currentSystemWatts >= 0

                PlasmaComponents.Label {
                    Layout.alignment: Qt.AlignRight
                    text: root.viewMode === 0
                        ? (root.currentBattery >= 0 ? Math.round(root.currentBattery) + "%" : "N/A")
                        : root.viewMode === 1
                        ? (headlineCol.powerShowsSystem
                            ? root.currentSystemWatts.toFixed(1) + "W"
                            : root.currentPower.toFixed(1) + "W")
                        : (root.currentTemp >= 0 ? root.currentTemp.toFixed(1) + "°C" : "N/A")
                    font.pixelSize: 22
                    font.weight: Font.Bold
                    font.family: "monospace"
                    color: root.viewMode === 0
                        ? root.batteryColor(root.currentBattery)
                        : root.viewMode === 1
                        ? (headlineCol.powerShowsSystem ? root.colorTextBright : root.colorPower)
                        : root.tempColor(root.currentTemp)
                }
                PlasmaComponents.Label {
                    Layout.alignment: Qt.AlignRight
                    text: {
                        var bits = [];
                        if (root.hasBattery) {
                            if (root.isCharging) {
                                bits.push("⚡ " + root.currentPower.toFixed(1) + "W → battery");
                                if (root.timeToFull !== "") bits.push("full in " + root.timeToFull);
                            } else {
                                bits.push(root.currentPower.toFixed(1) + "W load");
                                if (root.timeToEmpty !== "") bits.push(root.timeToEmpty + " left");
                            }
                        } else if (root.currentSystemWatts >= 0) {
                            // No battery: still want a sublabel to give context to the big number.
                            bits.push((root.activeRaplSource === "package" ? "CPU package" : "platform") + " power");
                        }
                        return bits.join(" · ");
                    }
                    font: Kirigami.Theme.smallFont
                    color: root.colorText
                }

                // Hover tooltip explaining what the big number represents in each view.
                HoverHandler { id: headlineHover }
                QQC2.ToolTip.visible: headlineHover.hovered
                QQC2.ToolTip.delay: 400
                QQC2.ToolTip.text: {
                    if (root.viewMode === 0)
                        return i18n("Battery charge level (%) from /sys/class/power_supply/BAT*/capacity.");
                    if (root.viewMode === 2)
                        return i18n("Battery temperature (°C) from sysfs / thermal zone.");
                    // Power view
                    if (headlineCol.powerShowsSystem) {
                        if (root.activeRaplSource === "psys")
                            return i18n("System power (RAPL PSYS) — whole-platform reading. Note: PSYS scope is firmware-defined and on some Intel CPUs under-reports. Switch source in Configure if it looks off.");
                        return i18n("CPU package power (RAPL package-0) — CPU + iGPU only, excludes display, RAM, NIC, etc. Whole-system draw is not measurable on this hardware; battery power_now reflects total when discharging.");
                    }
                    if (root.isCharging)
                        return i18n("Power flowing into the battery (charge rate). Wall draw is higher due to system consumption + charger losses.");
                    if (root.activeRaplStatus === "locked")
                        return i18n("Battery load. System (RAPL) power is locked to root on this kernel — see Configure for the unlock recipe.");
                    return i18n("Battery load — total power being delivered from the cells to the system.");
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

                    // Power mode stores tuples {v, c, p}; battery%/temp are flat numbers.
                    var isPower = root.viewMode === 1;
                    var values = new Array(numPoints);
                    var charging = isPower ? new Array(numPoints) : null;
                    var psysVals = isPower ? new Array(numPoints) : null;
                    var hasPsys = false;
                    for (i = 0; i < numPoints; i++) {
                        if (isPower) {
                            values[i] = data[i].v;
                            charging[i] = data[i].c;
                            psysVals[i] = data[i].p;
                            if (psysVals[i] >= 0) hasPsys = true;
                        } else {
                            values[i] = data[i];
                        }
                    }

                    // Pick the headline (current-state) color for area/dot.
                    var lineColor, cObj;
                    if (root.viewMode === 0) {
                        lineColor = root.batteryColor(root.currentBattery).toString();
                        cObj = root.batteryColorObj(root.currentBattery);
                    } else if (isPower) {
                        // Charging → green (matches battery icon); discharging → highlight.
                        var primary = root.isCharging ? root.colorCharging : root.colorPower;
                        lineColor = primary.toString();
                        cObj = { r: primary.r, g: primary.g, b: primary.b };
                    } else {
                        lineColor = root.tempColor(root.currentTemp).toString();
                        cObj = root.tempColorObj(root.currentTemp);
                    }

                    // Area gradient (uses current-state color)
                    var gradient = ctx.createLinearGradient(0, pad.top, 0, pad.top + gh);
                    gradient.addColorStop(0, Qt.rgba(cObj.r, cObj.g, cObj.b, 0.3));
                    gradient.addColorStop(1, Qt.rgba(cObj.r, cObj.g, cObj.b, 0.02));

                    function px(i) { return pad.left + (i / (maxPts - 1)) * gw; }
                    function py(v) {
                        var clamped = Math.max(minVal, Math.min(maxVal, v));
                        return pad.top + gh - ((clamped - minVal) / (maxVal - minVal)) * gh;
                    }

                    // Area
                    ctx.beginPath();
                    for (i = 0; i < numPoints; i++) {
                        x = px(i); y = py(values[i]);
                        if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                    }
                    var lastX = px(numPoints - 1);
                    ctx.lineTo(lastX, pad.top + gh);
                    ctx.lineTo(pad.left, pad.top + gh);
                    ctx.closePath();
                    ctx.fillStyle = gradient;
                    ctx.fill();

                    // Line — segmented in power mode by charging state, single-color elsewhere.
                    // Drawn before the PSYS overlay so the system line sits on top.
                    ctx.lineWidth = 1.5;
                    if (isPower) {
                        var dischargeColor = root.colorPower.toString();
                        var chargeColor = root.colorCharging.toString();
                        // Walk runs of identical charging state and stroke each as one path.
                        var runStart = 0;
                        for (i = 1; i <= numPoints; i++) {
                            if (i === numPoints || charging[i] !== charging[runStart]) {
                                ctx.beginPath();
                                // Anchor segment to the previous run's last point so there's no gap.
                                var startIdx = runStart === 0 ? 0 : runStart - 1;
                                ctx.moveTo(px(startIdx), py(values[startIdx]));
                                for (var j = runStart; j < i; j++) {
                                    ctx.lineTo(px(j), py(values[j]));
                                }
                                ctx.strokeStyle = charging[runStart] ? chargeColor : dischargeColor;
                                ctx.stroke();
                                runStart = i;
                            }
                        }
                    } else {
                        ctx.beginPath();
                        for (i = 0; i < numPoints; i++) {
                            x = px(i); y = py(values[i]);
                            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                        }
                        ctx.strokeStyle = lineColor;
                        ctx.stroke();
                    }

                    // PSYS overlay (system power) — solid translucent line on top of the
                    // battery line so the underlying color shows through where they overlap.
                    if (isPower && hasPsys) {
                        ctx.save();
                        ctx.beginPath();
                        var psysStarted = false;
                        for (i = 0; i < numPoints; i++) {
                            if (psysVals[i] < 0) { psysStarted = false; continue; }
                            x = px(i); y = py(psysVals[i]);
                            if (!psysStarted) { ctx.moveTo(x, y); psysStarted = true; }
                            else ctx.lineTo(x, y);
                        }
                        ctx.strokeStyle = Qt.rgba(
                            Kirigami.Theme.textColor.r,
                            Kirigami.Theme.textColor.g,
                            Kirigami.Theme.textColor.b, 0.65).toString();
                        ctx.lineWidth = 1.5;
                        ctx.stroke();
                        ctx.restore();
                    }

                    // Dot — color reflects current state (charging vs discharging in power mode).
                    if (numPoints > 0) {
                        var dotX = px(numPoints - 1);
                        var dotY = py(values[numPoints - 1]);
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

        // Mini legend for the power graph — shown only when PSYS overlay is visible.
        // Disambiguates the solid (battery/state-colored) line from the dashed system line.
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing
            visible: root.viewMode === 1 && root.currentSystemWatts >= 0 && fullRep.showStats

            Item { Layout.fillWidth: true }
            PlasmaComponents.Label {
                text: (root.isCharging ? "━ → battery" : "━ load")
                font: Kirigami.Theme.smallFont
                color: root.isCharging ? root.colorCharging : root.colorPower
            }
            PlasmaComponents.Label {
                text: "━ " + (root.activeRaplSource === "package" ? "CPU package" : "system")
                font: Kirigami.Theme.smallFont
                color: root.colorTextBright
                opacity: 0.65
            }
            Item { Layout.fillWidth: true }
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
    function profileLabel(p) {
        if (p === "power-saver") return "Saver";
        if (p === "balanced") return "Balanced";
        if (p === "performance") return "Performance";
        return p;
    }
    function profileGlyph(p) {
        if (p === "power-saver") return "🔋";
        if (p === "balanced") return "⚖";
        if (p === "performance") return "🚀";
        return "";
    }

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
