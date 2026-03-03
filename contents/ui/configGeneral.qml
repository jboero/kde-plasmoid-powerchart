import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

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
    }
}
