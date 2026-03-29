<<<<<<< HEAD
=======
/*
 * Battery & Power Graph - Main UI Component
 * 电池与功耗图表 - 主界面组件
 * 
 * This is the main QML component for the KDE Plasma 6 plasmoid that displays
 * real-time battery percentage, power consumption, and temperature graphs.
 * 这是 KDE Plasma 6 小部件的主要 QML 组件，用于显示实时电池电量、功耗和温度图表。
 * 
 * Architecture: Polls shell script every N seconds, parses JSON output, updates graphs.
 * 架构：每隔 N 秒轮询 shell 脚本，解析 JSON 输出，更新图表。
 */

>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
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

<<<<<<< HEAD
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
=======
    // ── Config / 配置 ───────────────────────────────────────────────────────
    // Refresh interval in milliseconds (derived from user configuration in seconds)
    // 刷新间隔（毫秒），从用户配置的秒数派生
    readonly property int refreshMs: plasmoid.configuration.refreshInterval * 1000
    
    // Maximum number of data points to retain in history arrays
    // Calculated based on history duration and refresh interval
    // 历史数据数组中保留的最大数据点数，根据历史时长和刷新间隔计算
    readonly property int maxDataPoints: Math.max(10,
        Math.floor(plasmoid.configuration.historyMinutes * 60 / plasmoid.configuration.refreshInterval))
    
    // Battery% & temp: 10× retention window, sampled 1/10 as often → same array length
    // 电池电量和温度：10 倍保留窗口，每 10 次采样 1 次，保持相同的数组长度
    readonly property int maxDataPointsLong: maxDataPoints
    
    // Graph dimensions in pixels
    // 图表尺寸（像素）
    readonly property int graphHeight: 180
    readonly property int graphWidth: 360

    // ── Semantic colors / 语义化颜色 ──────────────────────────────────────────────
    // Battery color indicators using Kirigami theme colors for automatic light/dark mode support
    // 电池颜色指示器，使用 Kirigami 主题颜色以自动支持亮色/暗色模式
    readonly property color colorBattery:    Kirigami.Theme.positiveTextColor      // Green for good battery level / 绿色表示良好电量
    readonly property color colorBatteryLow: Kirigami.Theme.negativeTextColor      // Red for low battery / 红色表示低电量
    readonly property color colorBatteryMid: Kirigami.Theme.neutralTextColor       // Orange/Yellow for medium battery / 橙黄色表示中等电量
    readonly property color colorPower:      Kirigami.Theme.highlightColor         // Highlight color for power graph / 高亮色用于功耗图表
    readonly property color colorCharging:   Kirigami.Theme.positiveTextColor      // Green when charging / 充电时绿色
    readonly property color colorTemp:       "#ff8844"  // warm orange for temperature / 暖橙色表示温度
    readonly property color colorText:       Kirigami.Theme.disabledTextColor      // Dim text for labels / 暗淡文本用于标签
    readonly property color colorTextBright: Kirigami.Theme.textColor              // Bright text for values / 明亮文本用于数值
    readonly property color colorGrid:       Qt.rgba(Kirigami.Theme.textColor.r,   // Faint grid lines / 淡网格线
                                                      Kirigami.Theme.textColor.g,
                                                      Kirigami.Theme.textColor.b, 0.1)
    readonly property color colorGridAccent: Qt.rgba(Kirigami.Theme.highlightColor.r,  // Accent grid lines / 强调网格线
                                                      Kirigami.Theme.highlightColor.g,
                                                      Kirigami.Theme.highlightColor.b, 0.2)
    readonly property color colorCardBg:     Qt.ringa(Kirigami.Theme.backgroundColor.r,  // Card background / 卡片背景
                                                      Kirigami.Theme.backgroundColor.g,
                                                      Kirigami.Theme.backgroundColor.b, 0.3)

    // ── Data state / 数据状态 ───────────────────────────────────────────────────
    property int pollCounter: 0   // counts poll cycles; battery% & temp sample every 10th
                                  // 计数器，电池电量和温度每 10 次轮询采样 1 次
    property var batteryHistory: []      // Array of battery percentage values / 电池电量百分比数组
    property var powerHistory: []        // Array of power consumption values (Watts) / 功耗值数组（瓦特）
    property var tempHistory: []         // Array of temperature values (°C) / 温度值数组（摄氏度）
    property real currentBattery: -1     // Current battery percentage (-1 = unavailable) / 当前电池电量（-1 = 不可用）
    property real currentPower: 0.0      // Current power consumption in Watts / 当前功耗（瓦特）
    property real currentTemp: -1        // Current temperature in °C (-1 = unavailable) / 当前温度（摄氏度，-1 = 不可用）
    property bool isCharging: false      // Whether battery is currently charging / 是否正在充电
    property bool acPlugged: false       // Whether AC adapter is plugged in / 是否插入电源适配器
    property string batteryStatus: "Unknown"  // Battery status string from sysfs / 来自 sysfs 的电池状态字符串
    property real maxPowerSeen: 25.0     // Auto-scaling maximum for power graph Y-axis / 功耗图表 Y 轴自动缩放最大值
    property real maxTempSeen: 60.0      // Auto-scaling maximum for temperature graph Y-axis / 温度图表 Y 轴自动缩放最大值
    property string timeToEmpty: ""      // Estimated time remaining until empty / 预计剩余使用时间
    property string timeToFull: ""       // Estimated time until fully charged / 预计充满时间
    property real designCapacity: 0      // Battery design capacity (mAh or Wh) / 电池设计容量（毫安时或瓦时）
    property real fullCapacity: 0        // Current full charge capacity (mAh or Wh) / 当前满充容量（毫安时或瓦时）
    property real batteryHealth: 0       // Battery health percentage (fullCapacity / designCapacity × 100) / 电池健康度百分比
    property int cycleCount: -1          // Battery cycle count (-1 = unavailable) / 电池循环次数（-1 = 不可用）
    property int viewMode: 1             // 0 = battery%, 1 = power, 2 = temp / 视图模式：0=电量，1=功耗，2=温度
    property string currentProfile: ""   // power-profiles-daemon active profile / 当前电源配置文件
    property var availableProfiles: []   // list of available profiles / 可用配置文件列表
    property bool ppdAvailable: false    // whether net.hadess.PowerProfiles D-Bus service is present / 是否有电源配置文件 D-Bus 服务
    property string tunedProfile: ""     // TuneD active profile / TuneD 活动配置文件
    property var tunedProfiles: []       // list of {name, desc} objects / TuneD 配置文件列表
    property var tunedProfileNames: []   // just names for setTunedProfile / TuneD 配置文件名称列表
    property var tunedDisplayNames: []   // "name - description" for combobox display / TuneD 配置文件显示名称列表
    property bool tunedAvailable: false  // whether tuned-adm is present / tuned-adm 是否可用
    property bool tunedSwitching: false  // true while user-initiated switch is in flight / 用户切换配置文件时设为 true
    // Bump this to signal the graph to repaint (avoids cross-scope id refs)
    // 增加此值以通知图表重绘（避免跨作用域 ID 引用）
    property int dataVersion: 0

    // ── Tooltip & background / 工具提示和背景 ─────────────────────────────────────────
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
    toolTipMainText: "Battery: " + (currentBattery >= 0 ? Math.round(currentBattery) + "%" : "N/A")
    toolTipSubText: currentPower.toFixed(1) + "W" +
        (currentTemp >= 0 ? " · " + currentTemp.toFixed(1) + "°C" : "") +
        (isCharging ? " ⚡ Charging" : "")
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground

<<<<<<< HEAD
    // ── Shell command ────────────────────────────────────────────────
    readonly property string pollCommand: {
        // Locate the poll script in the plasmoid package
=======
    // ── Shell command / Shell 命令 ───────────────────────────────────────────────
    // Constructs the command to execute the battery polling script
    // 构建执行电池轮询脚本的命令
    readonly property string pollCommand: {
        // Locate the poll script in the plasmoid package
        // 在 plasmoid 包中定位轮询脚本
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
        var scriptDir = Qt.resolvedUrl("../scripts/battery-poll.sh").toString().replace("file://", "");
        return "bash " + scriptDir;
    }


<<<<<<< HEAD
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

=======
    // ── Executable data source / 可执行数据源 ───────────────────────────────────────
    // DataSource component for executing shell commands and capturing output
    // 用于执行 shell 命令并捕获输出的 DataSource 组件
    Plasma5Support.DataSource {
        id: executable
        engine: "executable"           // Use the executable engine / 使用可执行引擎
        connectedSources: []           // List of currently connected command sources / 当前连接的命令源列表

        // Callback when command execution completes
        // 命令执行完成时的回调函数
        onNewData: (sourceName, data) => {
            var stdout = data["stdout"] || "";    // Capture standard output / 捕获标准输出
            executable.disconnectSource(sourceName);  // Disconnect after execution / 执行后断开连接

            if (stdout.trim() === "") return;  // Ignore empty output / 忽略空输出

            try {
                // Parse JSON output from the shell script
                // 解析 shell 脚本的 JSON 输出
                var parsed = JSON.parse(stdout.trim());

                // Update battery data properties
                // 更新电池数据属性
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
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

<<<<<<< HEAD
                // Power profile
=======
                // Power profile handling / 电源配置文件处理
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
                var pp = parsed.power_profile || "";
                root.currentProfile = pp;
                var pa = parsed.profiles_available || "";
                if (pa !== "") {
                    root.availableProfiles = pa.split(",").filter(function(s) { return s !== ""; });
                    root.ppdAvailable = true;
                } else if (pp !== "") {
                    // D-Bus service is running (we got ActiveProfile) but couldn't parse Profiles list
                    // Fall back to standard profiles
<<<<<<< HEAD
=======
                    // D-Bus 服务正在运行（获取到 ActiveProfile）但无法解析 Profiles 列表
                    // 回退到标准配置文件
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
                    root.availableProfiles = ["power-saver", "balanced", "performance"];
                    root.ppdAvailable = true;
                } else {
                    root.availableProfiles = [];
                    root.ppdAvailable = false;
                }

<<<<<<< HEAD
                // TuneD profiles
                var tp = parsed.tuned_profile || "";
                // Clear user-switching lock once the daemon confirms the new profile
=======
                // TuneD profiles handling / TuneD 配置文件处理
                var tp = parsed.tuned_profile || "";
                // Clear user-switching lock once the daemon confirms the new profile
                // 一旦守护进程确认新配置文件，清除用户切换锁
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
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
<<<<<<< HEAD
=======
                                                                  // 分割"  - "格式（2 个以上空格加破折号）
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
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

<<<<<<< HEAD
=======
                // Calculate battery health percentage
                // 计算电池健康度百分比
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
                if (root.designCapacity > 0 && root.fullCapacity > 0) {
                    root.batteryHealth = (root.fullCapacity / root.designCapacity) * 100;
                }

<<<<<<< HEAD
                // Power history: every poll cycle
=======
                // Update power history (every poll cycle)
                // 更新功耗历史（每次轮询周期）
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
                var ph = root.powerHistory.slice();
                ph.push(root.currentPower);
                if (ph.length > root.maxDataPoints) ph.shift();
                root.powerHistory = ph;

                // Battery% & temp: sample every 10th poll for 10× longer retention
<<<<<<< HEAD
=======
                // 电池电量和温度：每 10 次轮询采样 1 次，保留 10 倍时长
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
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

<<<<<<< HEAD
=======
                // Auto-scale graph Y-axis maximums
                // 自动缩放图表 Y 轴最大值
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
                if (root.currentPower > root.maxPowerSeen) {
                    root.maxPowerSeen = Math.ceil(root.currentPower / 5) * 5 + 5;
                }
                if (root.currentTemp > root.maxTempSeen) {
                    root.maxTempSeen = Math.ceil(root.currentTemp / 10) * 10 + 10;
                }

                updateStatsModel();
                // Signal the graph to repaint via dataVersion bump
<<<<<<< HEAD
=======
                // 通过增加 dataVersion 通知图表重绘
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
                root.dataVersion++;

            } catch (e) {
                console.log("BatteryGraph: parse error: " + e + " | raw: " + stdout);
            }
        }
    }

<<<<<<< HEAD
=======
    // Execute the polling command
    // 执行轮询命令
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
    function execCommand() {
        executable.connectSource(root.pollCommand);
    }

    // ── Profile setter (separate source so it doesn't collide with poll) ─
<<<<<<< HEAD
=======
    // 配置文件设置器（独立的数据源，避免与轮询冲突）
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
    Plasma5Support.DataSource {
        id: profileSetter
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            profileSetter.disconnectSource(sourceName);
            // Re-poll immediately to update the displayed profile
<<<<<<< HEAD
=======
            // 立即重新轮询以更新显示的配置文件
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
            root.execCommand();
        }
    }

<<<<<<< HEAD
    function setProfile(profileName) {
        // Use powerprofilesctl if available, otherwise gdbus
=======
    // Set power profile using powerprofilesctl or gdbus
    // 使用 powerprofilesctl 或 gdbus 设置电源配置文件
    function setProfile(profileName) {
        // Use powerprofilesctl if available, otherwise gdbus
        // 如果可用则使用 powerprofilesctl，否则使用 gdbus
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
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
<<<<<<< HEAD
=======
    // TuneD 配置文件设置器（需要通过 pkexec 获取 root 权限）
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
    Plasma5Support.DataSource {
        id: tunedSetter
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            tunedSetter.disconnectSource(sourceName);
            root.execCommand();
        }
    }

<<<<<<< HEAD
=======
    // Set TuneD profile using tuned-adm
    // 使用 tuned-adm 设置 TuneD 配置文件
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
    function setTunedProfile(profileName) {
        tunedSetter.connectSource("tuned-adm profile " + profileName);
    }

<<<<<<< HEAD
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
=======
    // ── Timer / 定时器 ───────────────────────────────────────────────────────
    // Periodic timer to poll battery data at configured intervals
    // 定期定时器，按配置的间隔轮询电池数据
    Timer {
        id: pollTimer
        interval: root.refreshMs               // Polling interval in milliseconds / 轮询间隔（毫秒）
        running: true                          // Timer is running / 定时器运行中
        repeat: true                           // Repeat indefinitely / 无限重复
        triggeredOnStart: true                 // Trigger immediately on start / 启动时立即触发
        onTriggered: root.execCommand()        // Execute poll command on each trigger / 每次触发时执行轮询命令
    }

    // ── Compact representation (vertical battery icon for systray) ──
    // 紧凑表示形式（系统托盘的垂直电池图标）
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
    compactRepresentation: Item {
        id: compactRoot
        Layout.minimumWidth: Kirigami.Units.iconSizes.medium
        Layout.minimumHeight: Kirigami.Units.iconSizes.medium
        Layout.preferredWidth: Layout.minimumWidth
        Layout.preferredHeight: Layout.minimumHeight

<<<<<<< HEAD
=======
        // Custom canvas-drawn vertical battery icon with charging/plug indicators
        // 自定义 Canvas 绘制的垂直电池图标，带充电/插头指示器
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
        Canvas {
            id: batteryIcon
            anchors.fill: parent

<<<<<<< HEAD
            property real pct: root.currentBattery
            property bool charging: root.isCharging
            property bool plugged: root.acPlugged
            onPctChanged: requestPaint()
=======
            property real pct: root.currentBattery      // Battery percentage / 电池电量百分比
            property bool charging: root.isCharging     // Charging state / 充电状态
            property bool plugged: root.acPlugged       // AC plugged state / 电源插入状态
            onPctChanged: requestPaint()                // Request repaint when properties change / 属性变化时请求重绘
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
            onChargingChanged: requestPaint()
            onPluggedChanged: requestPaint()

            onPaint: {
<<<<<<< HEAD
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

                // Main body
                var bodyX = w * 0.06;
                var bodyY = h * 0.15;
                var bodyW = w * 0.82;
                var bodyH = h * 0.7;
                var r = Math.max(2, bodyH * 0.15);

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

=======
                var ctx = getContext("2d");              // Get 2D rendering context / 获取 2D 渲染上下文
                var w = width;                           // Canvas width / 画布宽度
                var h = height;                          // Canvas height / 画布高度
                ctx.clearRect(0, 0, w, h);               // Clear previous frame / 清除上一帧

                var pct = Math.max(0, Math.min(100, root.currentBattery));  // Clamp battery percentage to 0-100 / 限制电量百分比在 0-100 范围
                var lw = Math.max(1, Math.round(Math.min(w, h) * 0.04));    // Line width based on icon size (4% of smaller dimension) / 基于图标尺寸的线宽（较小维度的 4%）

                // ── Horizontal battery body (nub on right) ──
                // 水平电池主体（右侧凸起）
                // The nub represents the positive terminal of the battery
                // 凸起部分代表电池的正极端子
                var nubW = Math.max(2, w * 0.06);       // Nub width: 6% of canvas width, minimum 2px / 凸起宽度：画布宽度的 6%，最小 2 像素
                var nubH = h * 0.25;                     // Nub height: 25% of canvas height / 凸起高度：画布高度的 25%
                var nubX = w * 0.88;                     // Nub X position: 88% from left / 凸起 X 位置：距左侧 88%
                var nubY = (h - nubH) / 2;               // Center vertically / 垂直居中

                ctx.beginPath();
                ctx.roundedRect(nubX, nubY, nubW, nubH, 1, 1);  // Draw rounded rectangle for nub / 绘制凸起的圆角矩形
                ctx.fillStyle = Kirigami.Theme.textColor.toString();
                ctx.fill();                                   // Fill with theme text color / 用主题文本颜色填充

                // Main body / 电池主体
                // The main rectangular body of the battery icon
                // 电池图标的主体矩形部分
                var bodyX = w * 0.06;                    // Body X position: 6% from left / 主体 X 位置：距左侧 6%
                var bodyY = h * 0.20;                    // Body Y position: 20% from top / 主体 Y 位置：距顶部 20%
                var bodyW = w * 0.82;                    // Body width: 82% of canvas width / 主体宽度：画布宽度的 82%
                var bodyH = h * 0.6;                     // Body height: 60% of canvas height / 主体高度：画布高度的 60%
                var r = Math.max(2, bodyH * 0.15);       // Corner radius: 15% of body height, minimum 2px / 圆角半径：主体高度的 15%，最小 2 像素

                ctx.beginPath();
                ctx.roundedRect(bodyX, bodyY, bodyW, bodyH, r, r);  // Draw rounded rectangle for battery body / 绘制电池主体的圆角矩形
                ctx.strokeStyle = Kirigami.Theme.textColor.toString();
                ctx.lineWidth = lw;                      // Set line width / 设置线宽
                ctx.stroke();                            // Draw outline / 绘制轮廓

                // ── Fill level (grows left to right) ──
                // 填充级别（从左到右增长）
                // Visual indicator showing current battery charge level
                // 显示当前电池电量的视觉指示器
                if (root.currentBattery >= 0) {
                    var inset = lw + 1;                  // Inset from border for visual padding / 距边框的内边距
                    var fillX = bodyX + inset;           // Fill area X start / 填充区域 X 起点
                    var fillY = bodyY + inset;           // Fill area Y start / 填充区域 Y 起点
                    var fillMaxW = bodyW - inset * 2;    // Maximum fill width / 最大填充宽度
                    var fillH = bodyH - inset * 2;       // Fill height / 填充高度
                    var fillW = fillMaxW * (pct / 100);  // Current fill width based on percentage / 基于百分比的当前填充宽度
                    var fillR = Math.max(1, r * 0.5);    // Fill corner radius: 50% of body corner radius / 填充圆角半径：主体圆角半径的 50%

                    // Determine fill color based on battery level and charging state
                    // 根据电量水平和充电状态确定填充颜色
                    var fillColor;
                    if (root.isCharging) {
                        fillColor = root.colorCharging;           // Green when charging / 充电时绿色
                    } else if (pct <= 20) {
                        fillColor = root.colorBatteryLow;         // Red for low battery (≤20%) / 低电量红色（≤20%）
                    } else if (pct <= 40) {
                        fillColor = root.colorBatteryMid;         // Orange for medium battery (≤40%) / 中等电量橙色（≤40%）
                    } else {
                        fillColor = root.colorBattery;            // Green for good battery (>40%) / 良好电量绿色（>40%）
                    }

                    // Draw fill only if there's charge to display
                    // 仅在有需要显示的电量和时才绘制填充
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
                    if (fillW > 0) {
                        ctx.beginPath();
                        ctx.roundedRect(fillX, fillY, Math.max(fillR * 2, fillW), fillH, fillR, fillR);
                        ctx.fillStyle = fillColor.toString();
<<<<<<< HEAD
                        ctx.fill();
=======
                        ctx.fill();                              // Fill with determined color / 用确定的颜色填充
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
                    }
                }

                // ── Charging: lightning bolt ──
<<<<<<< HEAD
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
=======
                // 充电状态：闪电符号
                // Lightning bolt overlay when battery is charging
                // 电池充电时的闪电覆盖层
                if (root.isCharging) {
                    var cx = bodyX + bodyW * 0.5;        // Center X of lightning / 闪电中心 X
                    var cy = h * 0.5;                    // Center Y of lightning / 闪电中心 Y
                    var bh = bodyH * 0.5;                // Lightning bolt height: 50% of body height / 闪电高度：主体高度的 50%
                    var bw = bh * 0.4;                   // Lightning bolt width: 40% of height / 闪电宽度：高度的 40%

                    // Draw zigzag lightning bolt path
                    // 绘制锯齿形闪电路径
                    ctx.beginPath();
                    ctx.moveTo(cx + bw * 0.05, cy - bh * 0.5);   // Top point / 顶点
                    ctx.lineTo(cx - bw * 0.4,  cy + bh * 0.05);  // Left-middle point / 左中点
                    ctx.lineTo(cx + bw * 0.05, cy + bh * 0.05);  // Right-middle point / 右中点
                    ctx.lineTo(cx - bw * 0.05, cy + bh * 0.5);   // Bottom-left point / 左下点
                    ctx.lineTo(cx + bw * 0.4,  cy - bh * 0.05);  // Right-middle upper point / 右中上点
                    ctx.lineTo(cx - bw * 0.05, cy - bh * 0.05);  // Left-middle upper point / 左中上点
                    ctx.closePath();                             // Close path / 闭合路径
                    ctx.fillStyle = Kirigami.Theme.backgroundColor.toString();
                    ctx.fill();                                  // Fill with background color (cutout effect) / 用背景色填充（镂空效果）
                    ctx.strokeStyle = Kirigami.Theme.textColor.toString();
                    ctx.lineWidth = Math.max(0.5, w * 0.03);     // Stroke width / 描边宽度
                    ctx.stroke();                                // Draw outline / 绘制轮廓
                }
                
                // ── Plugged in (not charging): plug icon ──
                // 已插电（未充电）：插头符号
                // Plug icon overlay when AC adapter is connected but not charging
                // 电源适配器连接但未充电时的插头覆盖层
                else if (root.acPlugged) {
                    var px = bodyX + bodyW * 0.5;        // Center X of plug / 插头中心 X
                    var py = h * 0.5;                    // Center Y of plug / 插头中心 Y
                    var ps = Math.max(3, bodyH * 0.12);  // Plug size: 12% of body height, minimum 3px / 插头尺寸：主体高度的 12%，最小 3 像素

                    // Draw plug body (rounded rectangle)
                    // 绘制插头主体（圆角矩形）
                    ctx.beginPath();
                    ctx.roundedRect(px - ps, py - ps * 0.6, ps * 2, ps * 1.2, 1, 1);
                    ctx.fillStyle = Kirigami.Theme.backgroundColor.toString();
                    ctx.fill();                                  // Fill with background color (cutout effect) / 用背景色填充
                    ctx.strokeStyle = Kirigami.Theme.textColor.toString();
                    ctx.lineWidth = Math.max(0.8, w * 0.04);     // Stroke width / 描边宽度
                    ctx.stroke();                                // Draw outline / 绘制轮廓

                    // Draw two plug prongs (metal pins)
                    // 绘制两个插脚（金属针脚）
                    var prongW = Math.max(1, ps * 0.25);         // Prong width: 25% of plug size / 插脚宽度：插头尺寸的 25%
                    ctx.fillStyle = Kirigami.Theme.textColor.toString();
                    ctx.fillRect(px - ps * 0.45, py - ps * 0.6 - ps * 0.5, prongW, ps * 0.5);  // Left prong / 左插脚
                    ctx.fillRect(px + ps * 0.2,  py - ps * 0.6 - ps * 0.5, prongW, ps * 0.5);  // Right prong / 右插脚
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
                }
            }
        }

<<<<<<< HEAD
=======
        // Mouse area to toggle expanded/collapsed state
        // 鼠标点击区域，切换展开/折叠状态
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
        MouseArea {
            id: compactMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.expanded = !root.expanded
        }
    }

<<<<<<< HEAD
    // ── Full representation ──────────────────────────────────────────
=======
    // ── Full representation / 完整表示形式 ─────────────────────────────────────────
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
    fullRepresentation: ColumnLayout {
        id: fullRep
        Layout.preferredWidth: root.graphWidth + 40
        Layout.preferredHeight: root.graphHeight + 260
        Layout.minimumWidth: 280
        Layout.minimumHeight: 200
        spacing: Kirigami.Units.smallSpacing * 2

        // Whether there's enough room below the graph for stats
<<<<<<< HEAD
        readonly property bool showStats: fullRep.height > root.graphHeight + 180

        // Header
=======
        // 图表下方是否有足够空间显示统计信息
        readonly property bool showStats: fullRep.height > root.graphHeight + 180

        // Header section with battery icon and status
        // 头部区域，包含电池图标和状态信息
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing * 2

<<<<<<< HEAD
=======
            // Battery icon indicator
            // 电池图标指示器
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
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

<<<<<<< HEAD
=======
            // Title and status label
            // 标题和状态标签
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
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

<<<<<<< HEAD
            Item { Layout.fillWidth: true }

=======
            // Spacer
            // 占位符
            Item { Layout.fillWidth: true }

            // Current value display (battery %, power, or temperature)
            // 当前值显示（电量百分比、功耗或温度）
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
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

<<<<<<< HEAD
        // Tab bar
=======
        // Tab bar for switching between graph modes
        // 选项卡栏，用于在不同图表模式间切换
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
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
<<<<<<< HEAD
                enabled: root.currentTemp >= 0
=======
                enabled: root.currentTemp >= 0  // Only enabled if temperature data is available / 仅在温度数据可用时启用
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
                onClicked: { root.viewMode = 2; graphCanvas.requestPaint(); }
            }
        }

<<<<<<< HEAD
        // Graph
=======
        // Graph canvas area
        // 画布绘图区域
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
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

<<<<<<< HEAD
=======
            // Canvas component for drawing the line graph
            // 用于绘制折线图的 Canvas 组件
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
            Canvas {
                id: graphCanvas
                anchors.fill: parent
                anchors.margins: 1

                // Repaint when data arrives or theme changes
<<<<<<< HEAD
=======
                // 数据到达或主题变化时重绘
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
                property int watchVersion: root.dataVersion
                onWatchVersionChanged: requestPaint()
                property color themeText: root.colorText
                onThemeTextChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    var w = width, h = height;
<<<<<<< HEAD
                    var pad = { top: 12, right: 10, bottom: 22, left: 38 };
                    var gw = w - pad.left - pad.right;
                    var gh = h - pad.top - pad.bottom;
                    ctx.clearRect(0, 0, w, h);

                    // Grid
=======
                    var pad = { top: 12, right: 10, bottom: 22, left: 38 };  // Padding for axes labels / 坐标轴标签的边距
                    var gw = w - pad.left - pad.right;  // Graph width / 图表宽度
                    var gh = h - pad.top - pad.bottom;  // Graph height / 图表高度
                    ctx.clearRect(0, 0, w, h);

                    // Draw horizontal grid lines
                    // 绘制水平网格线
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
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

<<<<<<< HEAD
                    // Y-axis
=======
                    // Y-axis labels with values and units
                    // Y 轴标签，包含数值和单位
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
                    ctx.fillStyle = root.colorText.toString();
                    ctx.font = "9px monospace";
                    ctx.textAlign = "right";
                    ctx.textBaseline = "middle";
                    var maxVal = root.viewMode === 0 ? 100 : root.viewMode === 1 ? root.maxPowerSeen : root.maxTempSeen;
<<<<<<< HEAD
                    var minVal = root.viewMode === 2 ? 20 : 0;
=======
                    var minVal = root.viewMode === 2 ? 20 : 0;  // Temperature starts at 20°C / 温度从 20°C 开始
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
                    var unit = root.viewMode === 0 ? "%" : root.viewMode === 1 ? "W" : "°C";
                    for (i = 0; i <= 4; i++) {
                        val = maxVal - (maxVal - minVal) * (i / 4);
                        y = pad.top + (gh / 4) * i;
                        ctx.fillText(val.toFixed(root.viewMode === 0 ? 0 : root.viewMode === 2 ? 0 : 1) + unit, pad.left - 4, y);
                    }

<<<<<<< HEAD
                    // X-axis
                    ctx.textAlign = "center";
                    ctx.textBaseline = "top";
                    var data = root.viewMode === 0 ? root.batteryHistory
                             : root.viewMode === 1 ? root.powerHistory
                             : root.tempHistory;
                    var numPoints = data.length;
                    // Battery% & temp are sampled 10× less often
=======
                    // X-axis time labels
                    // X 轴时间标签
                    ctx.textAlign = "center";
                    ctx.textBaseline = "top";
                    var data = root.viewMode === 0 ? root.batteryHistory
                                 : root.viewMode === 1 ? root.powerHistory
                                 : root.tempHistory;
                    var numPoints = data.length;
                    // Battery% & temp are sampled 10× less often, so interval is 10× longer
                    // 电池电量和温度采样频率低 10 倍，所以间隔是 10 倍
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
                    var intervalSec = root.viewMode === 1
                        ? plasmoid.configuration.refreshInterval
                        : plasmoid.configuration.refreshInterval * 10;

                    var maxPts = root.viewMode === 1 ? root.maxDataPoints : root.maxDataPointsLong;
                    if (numPoints > 1) {
                        var labels = [0, Math.floor(numPoints * 0.25), Math.floor(numPoints * 0.5),
<<<<<<< HEAD
                                      Math.floor(numPoints * 0.75), numPoints - 1];
=======
                                          Math.floor(numPoints * 0.75), numPoints - 1];
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
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

<<<<<<< HEAD
=======
                    // Show message when not enough data collected yet
                    // 数据不足时显示提示信息
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
                    if (numPoints < 2) {
                        ctx.fillStyle = root.colorText.toString();
                        ctx.font = "11px sans-serif";
                        ctx.textAlign = "center";
                        ctx.textBaseline = "middle";
                        ctx.fillText("Collecting data... (" + numPoints + " sample" + (numPoints !== 1 ? "s" : "") + ")", w / 2, h / 2);
                        return;
                    }

<<<<<<< HEAD
=======
                    // Determine line color based on view mode and current value
                    // 根据视图模式和当前值确定线条颜色
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
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

<<<<<<< HEAD
                    // Area gradient
                    var gradient = ctx.createLinearGradient(0, pad.top, 0, pad.top + gh);
                    gradient.addColorStop(0, Qt.rgba(cObj.r, cObj.g, cObj.b, 0.3));
                    gradient.addColorStop(1, Qt.rgba(cObj.r, cObj.g, cObj.b, 0.02));

                    // Area
=======
                    // Area gradient fill (fades from top to bottom)
                    // 区域渐变填充（从上到下渐变）
                    var gradient = ctx.createLinearGradient(0, pad.top, 0, pad.top + gh);
                    gradient.addColorStop(0, Qt.rgba(cObj.r, cObj.g, cObj.b, 0.3));
                    gradient.addColorStop(1, Qt.ringa(cObj.r, cObj.g, cObj.b, 0.02));

                    // Fill area under the line
                    // 填充线下方面积
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
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

<<<<<<< HEAD
                    // Line
=======
                    // Draw the line graph
                    // 绘制折线图
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
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

<<<<<<< HEAD
                    // Dot
=======
                    // Draw dot at the latest data point
                    // 在最新数据点绘制圆点标记
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
                    if (numPoints > 0) {
                        var lastVal = data[numPoints - 1];
                        var dotX = pad.left + ((numPoints - 1) / (maxPts - 1)) * gw;
                        var dotY = pad.top + gh - ((Math.max(minVal, Math.min(maxVal, lastVal)) - minVal) / (maxVal - minVal)) * gh;

                        ctx.beginPath();
                        ctx.arc(dotX, dotY, 6, 0, 2 * Math.PI);
<<<<<<< HEAD
                        ctx.fillStyle = Qt.rgba(cObj.r, cObj.g, cObj.b, 0.25);
=======
                        ctx.fillStyle = Qt.ringa(cObj.r, cObj.g, cObj.b, 0.25);
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
                        ctx.fill();
                        ctx.beginPath();
                        ctx.arc(dotX, dotY, 3, 0, 2 * Math.PI);
                        ctx.fillStyle = lineColor;
                        ctx.fill();
                    }
                }
            }
        }

<<<<<<< HEAD
        // ── Power Profile Switcher ───────────────────────────────────
=======
        // ── Power Profile Switcher / 电源配置文件切换器 ───────────────────────────────────
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
        RowLayout {
            Layout.fillWidth: true
            visible: root.ppdAvailable && plasmoid.configuration.showPowerProfile && fullRep.showStats
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: "Profile:"
                font: Kirigami.Theme.smallFont
                color: root.colorText
            }

<<<<<<< HEAD
=======
            // Repeater creates buttons for each available profile
            // Repeater 为每个可用配置文件创建按钮
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
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

<<<<<<< HEAD
        // ── TuneD Profile Switcher ─────────────────────────────────────
=======
        // ── TuneD Profile Switcher / TuneD 配置文件切换器 ─────────────────────────────────────
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
        RowLayout {
            Layout.fillWidth: true
            visible: root.tunedAvailable && fullRep.showStats
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: "TuneD:"
                font: Kirigami.Theme.smallFont
                color: root.colorText
            }

<<<<<<< HEAD
=======
            // ComboBox for TuneD profile selection
            // TuneD 配置文件选择的下拉框
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
            PlasmaComponents.ComboBox {
                id: tunedCombo
                Layout.fillWidth: true
                model: root.tunedDisplayNames
                font: Kirigami.Theme.smallFont

                // Only sync from poll when user isn't mid-switch
<<<<<<< HEAD
=======
                // 仅在用户未进行切换时才从轮询同步
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
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
<<<<<<< HEAD
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
=======
        // 统计网格 - 当小部件缩小时隐藏
        // Displays battery statistics in a 2-column grid layout
        // 以两列网格布局显示电池统计信息
        GridLayout {
            Layout.fillWidth: true
            visible: fullRep.showStats  // Only show when there's enough vertical space / 仅在垂直空间足够时显示
            columns: 2                  // Two columns for compact display / 两列紧凑显示
            rowSpacing: Kirigami.Units.smallSpacing    // Row spacing / 行间距
            columnSpacing: Kirigami.Units.smallSpacing // Column spacing / 列间距

            // Repeater creates delegates for each stat item in the model
            // Repeater 为模型中的每个统计项创建委托
            Repeater {
                model: statsModel  // Data model populated by updateStatsModel() / 由 updateStatsModel() 填充的数据模型
                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 32                       // Fixed height for consistency / 固定高度以保持一致性
                    radius: Kirigami.Units.smallSpacing  // Rounded corners / 圆角
                    color: root.colorCardBg          // Card background color / 卡片背景色
                    border.color: root.colorGrid     // Border color / 边框颜色
                    border.width: 1                  // Border width / 边框宽度

                    // Row layout to position label and value horizontally
                    // 行布局，水平排列标签和值
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing  // Inner margin / 内边距
                        spacing: Kirigami.Units.smallSpacing          // Spacing between elements / 元素间距

                        // Stat label (left side)
                        // 统计标签（左侧）
                        PlasmaComponents.Label {
                            text: model.label         // Label from model / 来自模型的标签
                            font: Kirigami.Theme.smallFont  // Small font for labels / 小号字体用于标签
                            color: root.colorText     // Standard text color / 标准文本颜色
                        }
                        
                        // Spacer to push value to the right
                        // 占位符，将值推到右侧
                        Item { Layout.fillWidth: true }
                        
                        // Stat value (right side, bold monospace)
                        // 统计值（右侧，粗体等宽字体）
                        PlasmaComponents.Label {
                            text: model.value                      // Value from model / 来自模型的值
                            font.pixelSize: 10                     // Smaller pixel size for compact display / 较小的像素尺寸以紧凑显示
                            font.weight: Font.Bold                 // Bold for emphasis / 粗体以强调
                            font.family: "monospace"               // Monospace for numerical alignment / 等宽字体用于数字对齐
                            color: model.accent !== "" ? model.accent : root.colorTextBright  // Accent color if available, otherwise bright text / 如果有强调色则使用，否则使用明亮文本
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
                        }
                    }
                }
            }
        }

<<<<<<< HEAD
        // Battery health bar
=======
        // Battery health bar showing degradation over time
        // 电池健康度条，显示随时间的损耗情况
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
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
<<<<<<< HEAD
=======
            // Health bar visualization
            // 健康度条可视化
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
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

<<<<<<< HEAD
    // ── Stats model ──────────────────────────────────────────────────
    ListModel { id: statsModel }

=======
    // ── Stats model / 统计数据模型 ─────────────────────────────────────────────────
    // ListModel to store and display battery statistics
    // 用于存储和显示电池统计信息的 ListModel
    ListModel { id: statsModel }

    // Update the stats model with latest battery data
    // 使用最新的电池数据更新统计模型
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
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

<<<<<<< HEAD
    // ── Helpers ──────────────────────────────────────────────────────
    function batteryColor(pct) {
        if (pct < 0) return root.colorText;
        if (pct <= 20) return root.colorBatteryLow;
        if (pct <= 40) return root.colorBatteryMid;
        return root.colorBattery;
    }

=======
    // ── Helpers / 辅助函数 ─────────────────────────────────────────────────────
    // Get battery color based on percentage
    // 根据电量百分比获取电池颜色
    function batteryColor(pct) {
        if (pct < 0) return root.colorText;
        if (pct <= 20) return root.colorBatteryLow;    // Low battery (red) / 低电量（红色）
        if (pct <= 40) return root.colorBatteryMid;    // Medium battery (orange) / 中等电量（橙色）
        return root.colorBattery;                       // Good battery (green) / 良好电量（绿色）
    }

    // Get battery color as RGB object for gradients
    // 获取电池颜色的 RGB 对象，用于渐变
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
    function batteryColorObj(pct) {
        var c;
        if (pct <= 20) { c = root.colorBatteryLow; return { r: c.r, g: c.g, b: c.b }; }
        if (pct <= 40) { c = root.colorBatteryMid;  return { r: c.r, g: c.g, b: c.b }; }
        c = root.colorBattery; return { r: c.r, g: c.g, b: c.b };
    }

    // Temperature color: cool (green) → warm (orange) → hot (red)
<<<<<<< HEAD
    function tempColor(deg) {
        if (deg < 0) return root.colorText;
        if (deg <= 35) return root.colorBattery;       // cool — green
        if (deg <= 45) return root.colorTemp;           // warm — orange
        return root.colorBatteryLow;                    // hot — red
    }

=======
    // 温度颜色：凉爽（绿色）→ 温暖（橙色）→ 炎热（红色）
    function tempColor(deg) {
        if (deg < 0) return root.colorText;
        if (deg <= 35) return root.colorBattery;       // Cool temperature (green) / 凉爽温度（绿色）
        if (deg <= 45) return root.colorTemp;           // Warm temperature (orange) / 温暖温度（橙色）
        return root.colorBatteryLow;                    // Hot temperature (red) / 炎热温度（红色）
    }

    // Get temperature color as RGB object for gradients
    // 获取温度颜色的 RGB 对象，用于渐变
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
    function tempColorObj(deg) {
        var c = root.tempColor(deg);
        return { r: c.r, g: c.g, b: c.b };
    }

<<<<<<< HEAD
=======
    // Initialize stats model when component is ready
    // 组件就绪时初始化统计模型
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
    Component.onCompleted: {
        updateStatsModel();
    }
}
