<<<<<<< HEAD
=======
/*
 * Battery & Power Graph - General Configuration UI
 * 电池与功耗图表 - 通用配置界面
 * 
 * This QML component defines the settings dialog for the plasmoid,
 * allowing users to configure refresh interval, history duration,
 * and power profile switching visibility.
 * 此 QML 组件定义小部件的设置对话框，允许用户配置刷新间隔、历史时长
 * 和电源配置文件切换的可见性。
 */

>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

<<<<<<< HEAD
Kirigami.FormLayout {
    id: page

    property alias cfg_refreshInterval: refreshSpinBox.value
    property alias cfg_historyMinutes: historySpinBox.value
    property alias cfg_showPowerProfile: powerProfileCheck.checked

    QQC2.SpinBox {
        id: refreshSpinBox
        Kirigami.FormData.label: i18n("Refresh interval (seconds):")
        from: 1
        to: 300
        stepSize: 1
    }

    QQC2.SpinBox {
        id: historySpinBox
        Kirigami.FormData.label: i18n("History duration (minutes):")
        from: 5
        to: 1440
        stepSize: 5
    }

    QQC2.CheckBox {
        id: powerProfileCheck
        Kirigami.FormData.label: i18n("Power profile controls:")
        text: i18n("Show power profile switcher in widget")
    }

    QQC2.Label {
        Kirigami.FormData.label: i18n("Note:")
        text: i18n("Shorter intervals give smoother graphs but use slightly more CPU.\nHistory duration controls how far back the graph shows.\nPower profile switching requires power-profiles-daemon (D-Bus service).")
        wrapMode: Text.WordWrap
        opacity: 0.7
=======
// FormLayout provides a labeled form layout for configuration options
// FormLayout 为配置选项提供带标签的表单布局
Kirigami.FormLayout {
    id: page

    // Property aliases bind the UI controls to the configuration schema defined in main.xml
    // 属性别名将 UI 控件绑定到 main.xml 中定义的配置模式
    property alias cfg_refreshInterval: refreshSpinBox.value     // Refresh interval in seconds / 刷新间隔（秒）
    property alias cfg_historyMinutes: historySpinBox.value      // History duration in minutes / 历史时长（分钟）
    property alias cfg_showPowerProfile: powerProfileCheck.checked  // Show/hide power profile switcher / 显示/隐藏电源配置文件切换器

    // SpinBox for setting the refresh interval (1-300 seconds)
    // 用于设置刷新间隔的 SpinBox（1-300 秒）
    QQC2.SpinBox {
        id: refreshSpinBox
        Kirigami.FormData.label: i18n("Refresh interval (seconds):")  // Label shown to the left of the control / 控件左侧显示的标签
        from: 1                        // Minimum value / 最小值
        to: 300                        // Maximum value (5 minutes) / 最大值（5 分钟）
        stepSize: 1                    // Increment/decrement step / 增减步长
    }

    // SpinBox for setting the history duration (5-1440 minutes = 24 hours)
    // 用于设置历史时长的 SpinBox（5-1440 分钟 = 24 小时）
    QQC2.SpinBox {
        id: historySpinBox
        Kirigami.FormData.label: i18n("History duration (minutes):")  // Label / 标签
        from: 5                          // Minimum value (5 minutes) / 最小值（5 分钟）
        to: 1440                         // Maximum value (24 hours) / 最大值（24 小时）
        stepSize: 5                      // Increment step / 增量步长
    }

    // CheckBox to enable/disable power profile switching controls
    // 复选框，启用/禁用电源配置文件切换控件
    QQC2.CheckBox {
        id: powerProfileCheck
        Kirigami.FormData.label: i18n("Power profile controls:")  // Label / 标签
        text: i18n("Show power profile switcher in widget")       // Checkbox text / 复选框文本
    }

    // Informational note explaining the impact of settings
    // 信息提示，说明设置的影响
    QQC2.Label {
        Kirigami.FormData.label: i18n("Note:")  // Label / 标签
        text: i18n("Shorter intervals give smoother graphs but use slightly more CPU.\nHistory duration controls how far back the graph shows.\nPower profile switching requires power-profiles-daemon (D-Bus service).")
        wrapMode: Text.WordWrap  // Enable word wrapping / 启用自动换行
        opacity: 0.7             // Dimmed appearance / 暗淡外观
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
    }
}
