import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.services
import qs.components

Item { // Window
    id: root
    property var toplevel
    property var windowData
    property var monitorData
    property var widgetMonitorData
    property var scale
    property var availableWorkspaceWidth
    property var availableWorkspaceHeight
    property real positionBaseX: (monitorData?.x ?? 0) + (monitorData?.reserved?.[0] ?? 0)
    property real positionBaseY: (monitorData?.y ?? 0) + (monitorData?.reserved?.[1] ?? 0)
    property int recaptureToken: 0
    property bool restrictToWorkspace: true
    property real widthRatio: {
        if (!widgetMonitorData || !monitorData)
            return 1;

        const widgetWidth = (widgetMonitorData.transform % 2 === 1) ? (widgetMonitorData.height ?? 1) : (widgetMonitorData.width ?? 1);
        const sourceWidth = (monitorData.transform % 2 === 1) ? (monitorData.height ?? 1) : (monitorData.width ?? 1);
        const sourceScale = monitorData.scale ?? 1;
        const widgetScale = widgetMonitorData.scale ?? 1;
        return (widgetWidth * sourceScale) / (sourceWidth * widgetScale);
    }
    property real heightRatio: {
        if (!widgetMonitorData || !monitorData)
            return 1;

        const widgetHeight = (widgetMonitorData.transform % 2 === 1) ? (widgetMonitorData.width ?? 1) : (widgetMonitorData.height ?? 1);
        const sourceHeight = (monitorData.transform % 2 === 1) ? (monitorData.width ?? 1) : (monitorData.height ?? 1);
        const sourceScale = monitorData.scale ?? 1;
        const widgetScale = widgetMonitorData.scale ?? 1;
        return (widgetHeight * sourceScale) / (sourceHeight * widgetScale);
    }
    property real initX: Math.max(((windowData?.at[0] ?? 0) - positionBaseX) * root.scale * geometryScaleX, 0) + xOffset
    property real initY: Math.max(((windowData?.at[1] ?? 0) - positionBaseY) * root.scale * geometryScaleY, 0) + yOffset
    property real xOffset: 0
    property real yOffset: 0
    property int widgetMonitorId: 0
    property real geometryScaleX: widthRatio
    property real geometryScaleY: heightRatio

    property var targetWindowWidth: (windowData?.size[0] ?? 100) * scale * geometryScaleX
    property var targetWindowHeight: (windowData?.size[1] ?? 100) * scale * geometryScaleY
    property bool hovered: false
    property bool pressed: false

    // Configuration properties adapted to caelestia's Tokens
    property bool showIcons: GlobalConfig.overview.windowPreview?.showIcons ?? true
    property var iconToWindowRatio: GlobalConfig.overview.windowPreview?.iconToWindowRatio ?? 0.25
    property var xwaylandIndicatorToIconRatio: GlobalConfig.overview.windowPreview?.xwaylandIndicatorToIconRatio ?? 0.25
    property var iconToWindowRatioCompact: GlobalConfig.overview.windowPreview?.iconToWindowRatioCompact ?? 0.35
    property bool cropToFill: GlobalConfig.overview.windowPreview?.cropToFill ?? false
    property bool previewsEnabled: GlobalConfig.overview.previewsEnabled ?? true
    property bool includeInactiveMonitorPreviews: GlobalConfig.overview.includeInactiveMonitorPreviews ?? false
    property int previewRecaptureDelayMs: GlobalConfig.overview.previewRecaptureDelayMs ?? 50
    property real windowOverlayOpacity: Math.max(0, Math.min(1, GlobalConfig.overview.effects?.windowOverlayOpacity ?? 0.5))
    property string previewModeRaw: GlobalConfig.overview.previewMode ?? "live"
    property string previewMode: {
        const mode = `${previewModeRaw ?? "live"}`.trim().toLowerCase();
        return (mode === "event" || mode === "snapshot") ? "event" : "live";
    }
    property bool livePreviewEnabled: previewsEnabled && previewMode === "live"
    property bool shouldCapturePreview: {
        if (!overviewOpen || !previewsEnabled || !previewCaptureEnabled)
            return false;
        if (includeInactiveMonitorPreviews)
            return true;
        return (windowData?.monitor ?? -1) === widgetMonitorId;
    }

    // Icon lookup using DesktopEntries for proper icon resolution
    property var entry: DesktopEntries.heuristicLookup(windowData?.class)
    property string iconName: {
        const raw = `${entry?.icon ?? ""}`.trim();
        const withoutProviderPrefix = raw.replace(/^image:\/\/icon\//, "");
        const withoutQuery = withoutProviderPrefix.split("?")[0].trim();
        return withoutQuery.length > 0 ? withoutQuery : "application-x-executable";
    }
    property var iconPath: Quickshell.iconPath(iconName, "image-missing")

    // Font size for compact mode calculation
    property real baseFontSize: Tokens.font?.size?.small ?? 12
    property bool compactMode: baseFontSize * 4 > targetWindowHeight || baseFontSize * 4 > targetWindowWidth

    property bool indicateXWayland: windowData?.xwayland ?? false
    property bool previewCaptureEnabled: true
    property bool initialized: false
    property bool dragInProgress: false
    property bool suspendPositionAnimation: false
    property bool animateSize: true
    property bool overviewOpen: true // Simplified - in full implementation, this would come from a global state
    property real inactiveMonitorOpacity: GlobalConfig.overview.windowPreview?.inactiveMonitorOpacity ?? 0.5
    property real windowRounding: Tokens.rounding.large

    x: initX
    y: initY
    width: Math.min(targetWindowWidth, availableWorkspaceWidth)
    height: Math.min(targetWindowHeight, availableWorkspaceHeight)
    opacity: (windowData?.monitor ?? -1) == widgetMonitorId ? 1 : inactiveMonitorOpacity
    visible: {
        const thisWsId = windowData?.workspace?.id;
        const isFullscreen = (windowData?.fullscreen ?? 0) > 0;
        if (isFullscreen || thisWsId === undefined) return true;
        return !HyprlandData.windowList.some(w => w.workspace?.id === thisWsId && (w.fullscreen ?? 0) > 0);
    }

    clip: true
    Component.onCompleted: Qt.callLater(() => root.initialized = true)

    function applyAlpha(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, Math.max(0, Math.min(1, alpha)));
    }

    function transparentize(color, amount) {
        return Qt.rgba(color.r, color.g, color.b, Math.max(0, color.a * (1 - amount)));
    }

    Behavior on x {
        enabled: root.initialized && !root.dragInProgress && !root.suspendPositionAnimation
        Anim {
            type: Anim.Standard
        }
    }
    Behavior on y {
        enabled: root.initialized && !root.dragInProgress && !root.suspendPositionAnimation
        Anim {
            type: Anim.Standard
        }
    }
    Behavior on width {
        enabled: root.initialized && root.animateSize && !root.dragInProgress && !root.suspendPositionAnimation
        Anim {
            type: Anim.Standard
        }
    }
    Behavior on height {
        enabled: root.initialized && root.animateSize && !root.dragInProgress && !root.suspendPositionAnimation
        Anim {
            type: Anim.Standard
        }
    }

    // Opaque background for windows on the active monitor.
    // The simplest solution for making those windows fully opaque and not interacting with actual
    // windows behind the overview, e.g., applying blur to them.
    Rectangle {
        visible: (root.windowData?.monitor ?? -1) === root.widgetMonitorId
        anchors.fill: parent
        radius: root.windowRounding * root.scale
        color: Colours.tPalette.m3surfaceContainer
    }

    ScreencopyView {
        id: windowPreview
        readonly property real srcAspect: {
            const w = root.windowData?.size?.[0] ?? 0;
            const h = root.windowData?.size?.[1] ?? 0;
            return (w > 0 && h > 0) ? (w / h) : 1;
        }
        anchors.centerIn: parent
        width: root.cropToFill
            ? Math.max(parent.width, parent.height * srcAspect)
            : Math.min(parent.width, parent.height * srcAspect)
        height: root.cropToFill
            ? Math.max(parent.height, parent.width / srcAspect)
            : Math.min(parent.height, parent.width / srcAspect)
        captureSource: shouldCapturePreview ? root.toplevel : null
        live: livePreviewEnabled
        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: previewMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.windowRounding * root.scale
        color: pressed ? applyAlpha(Colours.tPalette.m3surfaceContainerHigh, Math.min(1, root.windowOverlayOpacity + 0.30)) :
            hovered ? applyAlpha(Colours.tPalette.m3surfaceContainerHigh, Math.min(1, root.windowOverlayOpacity + 0.20)) :
            applyAlpha(Colours.tPalette.m3surfaceContainer, root.windowOverlayOpacity)
        border.color: transparentize(Colours.tPalette.m3outline, 0.7)
        border.width: 1

        ColumnLayout {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: root.baseFontSize * 0.5

            Image {
                id: windowIcon
                visible: root.showIcons
                property var iconSize: {
                    const renderedSize = Math.min(root.width, root.height);
                    return renderedSize * (root.compactMode ? root.iconToWindowRatioCompact : root.iconToWindowRatio) / (root.monitorData?.scale ?? 1);
                }
                Layout.alignment: Qt.AlignHCenter
                source: root.iconPath
                width: iconSize
                height: iconSize
                sourceSize: Qt.size(Math.max(1, Math.round(iconSize)), Math.max(1, Math.round(iconSize)))
            }
        }
    }

    Item {
        id: previewMask
        width: windowPreview.width
        height: windowPreview.height
        anchors.centerIn: parent
        visible: false
        layer.enabled: true
        layer.smooth: true
        Rectangle {
            anchors.centerIn: parent
            width: root.width
            height: root.height
            radius: root.windowRounding * root.scale
        }
    }

    function refreshCapture() {
        if (!overviewOpen || livePreviewEnabled || !previewsEnabled)
            return;

        root.previewCaptureEnabled = false;
        previewResetTimer.restart();
    }

    Timer {
        id: previewResetTimer
        interval: Math.max(1, previewRecaptureDelayMs)
        repeat: false
        onTriggered: root.previewCaptureEnabled = true
    }

    onRecaptureTokenChanged: {
        if (recaptureToken > 0)
            root.refreshCapture();
    }
}
