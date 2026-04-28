/*
 * Battery & Power Graph - General Configuration UI
 * 电池与功耗图表 - 通用配置界面
 * 
 * This QML file defines the configuration dialog for the plasmoid.
 * Users can adjust refresh interval, history duration, and feature visibility.
 * 此 QML 文件定义小部件的配置对话框。
 * 用户可以调整刷新间隔、历史时长和功能可见性。
 */

import QtQuick                                    // Import Qt Quick module / 导入 Qt Quick 模块
import QtQuick.Controls as QQC2                  // Import Qt Quick Controls 2 / 导入 Qt Quick Controls 2
import QtQuick.Layouts                           // Import Qt Quick Layouts / 导入 Qt Quick 布局
import org.kde.kirigami as Kirigami              // Import KDE Kirigami UI framework / 导入 KDE Kirigami UI 框架

// FormLayout provides a structured form layout with labels and fields
// FormLayout 提供带有标签和字段的结构化表单布局
Kirigami.FormLayout {
    id: page

    // Property aliases bind configuration values to UI controls
    // cfg_ prefix indicates these are configuration properties managed by Plasmoid
    // 属性别名将配置值绑定到 UI 控件
    // cfg_前缀表示这些是由 Plasmoid 管理的配置属性
    property alias cfg_refreshInterval: refreshSpinBox.value     // Refresh interval in seconds / 刷新间隔（秒）
    property alias cfg_historyMinutes: historySpinBox.value      // History duration in minutes / 历史时长（分钟）
    property alias cfg_showPowerProfile: powerProfileCheck.checked  // Show/hide power profile controls / 显示/隐藏电源配置文件控件
    property alias cfg_showBatteryPercentage: batteryPercentageCheck.checked  // Show/hide battery percentage text / 显示/隐藏电池百分比文本
    property string cfg_raplSource: "none"  // RAPL system-power source: psys | package | none

    // SpinBox for numeric input with increment/decrement buttons
    // 带增减按钮的数值输入 SpinBox
    QQC2.SpinBox {
        id: refreshSpinBox
        Kirigami.FormData.label: i18n("Refresh interval (seconds):")  // Label shown to the left of the control / 控件左侧显示的标签
        from: 1                      // Minimum value: 1 second / 最小值：1 秒
        to: 300                      // Maximum value: 300 seconds (5 minutes) / 最大值：300 秒（5 分钟）
        stepSize: 1                  // Increment step: 1 second / 增量步长：1 秒
    }

    // SpinBox for history duration configuration
    // 历史时长配置的 SpinBox
    QQC2.SpinBox {
        id: historySpinBox
        Kirigami.FormData.label: i18n("History duration (minutes):")  // Label text / 标签文本
        from: 5                      // Minimum value: 5 minutes / 最小值：5 分钟
        to: 1440                     // Maximum value: 1440 minutes (24 hours) / 最大值：1440 分钟（24 小时）
        stepSize: 5                  // Increment step: 5 minutes / 增量步长：5 分钟
    }

    // CheckBox to toggle power profile switching visibility
    // 用于切换电源配置文件可见性的复选框
    QQC2.CheckBox {
        id: powerProfileCheck
        Kirigami.FormData.label: i18n("Power profile controls:")  // Label for the checkbox / 复选框的标签
        text: i18n("Show power profile switcher in widget")       // Checkbox text / 复选框文本
    }

    // CheckBox to toggle battery percentage display in compact representation
    // 用于切换紧凑模式下电池百分比显示的复选框
    QQC2.CheckBox {
        id: batteryPercentageCheck
        Kirigami.FormData.label: i18n("Battery percentage:")  // Label for the checkbox / 复选框的标签
        text: i18n("Show battery percentage next to icon")    // Checkbox text / 复选框文本
    }

    // RAPL system-power source selector. PSYS *should* be whole-platform but is
    // implementation-defined and on some Intel client silicon under-reports
    // (e.g. reads lower than the CPU package alone). Let the user pick.
    QQC2.ComboBox {
        id: raplSourceCombo
        Kirigami.FormData.label: i18n("System power source:")
        textRole: "label"
        valueRole: "value"
        model: [
            { value: "psys",    label: i18n("PSYS — whole-platform (preferred)") },
            { value: "package", label: i18n("Package — CPU + iGPU only") },
            { value: "none",    label: i18n("None — disable overlay") }
        ]
        Component.onCompleted: {
            var idx = indexOfValue(cfg_raplSource);
            currentIndex = idx >= 0 ? idx : 0;
        }
        onActivated: cfg_raplSource = currentValue
        QQC2.ToolTip.visible: hovered
        QQC2.ToolTip.delay: 500
        QQC2.ToolTip.text: i18n("PSYS is the only true whole-platform reading but its scope is firmware-defined and on some Intel CPUs under-reports (can read lower than the CPU package alone). Package is CPU+iGPU only — accurate for what it covers but excludes display, NICs, etc. If readings look implausible, try the other source or set to None.")
    }

    // Informational note with multi-line text and reduced opacity
    // 带多行文本和降低透明度的信息提示
    QQC2.Label {
        Kirigami.FormData.label: i18n("Note:")                    // Label: "Note:" / 标签："注意："
        text: i18n("Shorter intervals give smoother graphs but use slightly more CPU.\nHistory duration controls how far back the graph shows.\nPower profile switching requires power-profiles-daemon (D-Bus service).")
        wrapMode: Text.WordWrap                                   // Enable word wrapping / 启用自动换行
        opacity: 0.7                                              // Dim the text to indicate it's secondary information / 降低文本透明度以表示次要信息
    }

    // System-power (RAPL) unlock instructions — energy_uj is root-only on modern
    // kernels (CVE-2020-8694 mitigation). Conservative hint, no auto-modifications.
    ColumnLayout {
        Kirigami.FormData.label: i18n("System power (RAPL):")
        Layout.fillWidth: true
        Layout.preferredWidth: 420
        spacing: Kirigami.Units.smallSpacing

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("If 'System' watts show as locked, RAPL energy counters are root-only on this kernel. Drop a one-time udev rule to allow user reads (persistent, easy to revert):")
            wrapMode: Text.WordWrap
            opacity: 0.8
        }

        // Bordered, selectable command block with a copy button in the corner.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: raplCmd.implicitHeight + Kirigami.Units.smallSpacing * 2
            color: Kirigami.Theme.alternateBackgroundColor
            border.color: Kirigami.Theme.disabledTextColor
            border.width: 1
            radius: 4

            TextEdit {
                id: raplCmd
                anchors.left: parent.left
                anchors.right: copyBtn.left
                anchors.top: parent.top
                anchors.margins: Kirigami.Units.smallSpacing
                text: "echo 'SUBSYSTEM==\"powercap\", ACTION==\"add\", RUN+=\"/bin/chmod a+r /sys/%p/energy_uj\"' | sudo tee /etc/udev/rules.d/99-rapl.rules\nsudo udevadm trigger"
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.Wrap
                color: Kirigami.Theme.textColor
                font.family: "monospace"
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }

            QQC2.ToolButton {
                id: copyBtn
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 2
                icon.name: "edit-copy"
                text: copied ? i18n("Copied") : i18n("Copy")
                display: QQC2.AbstractButton.IconOnly
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: text
                property bool copied: false
                onClicked: {
                    raplCmd.selectAll();
                    raplCmd.copy();
                    raplCmd.deselect();
                    copied = true;
                    copiedReset.restart();
                }
                Timer {
                    id: copiedReset
                    interval: 1500
                    onTriggered: copyBtn.copied = false
                }
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("Revert: sudo rm /etc/udev/rules.d/99-rapl.rules && sudo udevadm trigger")
            wrapMode: Text.WordWrap
            opacity: 0.7
            font.family: "monospace"
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        }
    }
}
