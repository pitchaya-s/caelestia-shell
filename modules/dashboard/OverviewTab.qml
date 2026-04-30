pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import qs.components
import "./overview"

Item {
    id: root

    required property ShellScreen screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)

    implicitWidth: overviewWidget.implicitWidth
    implicitHeight: overviewWidget.implicitHeight

    OverviewWidget {
        id: overviewWidget
        anchors.fill: parent
        anchors.margins: 10
        monitor: root.monitor
        embedded: true
    }
}
