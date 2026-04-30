pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.services
import "."

Item {
    id: root

    // Dashboard integration properties
    property bool embedded: false
    required property HyprlandMonitor monitor

    readonly property var toplevels: ToplevelManager.toplevels
    readonly property int effectiveActiveWorkspaceId: Math.max(1, Math.min(100, monitor?.activeWorkspace?.id))
    readonly property int workspacesShown: (GlobalConfig.overview.rows) * (GlobalConfig.overview.columns)
    readonly property bool useWorkspaceMap: GlobalConfig.overview.useWorkspaceMap
    readonly property var workspaceMap: GlobalConfig.overview.workspaceMap ?? {}
    readonly property int workspaceOffset: useWorkspaceMap ? Number(workspaceMap[root.monitor?.id]) : 0
    readonly property int workspaceGroup: Math.floor((effectiveActiveWorkspaceId - workspaceOffset - 1) / workspacesShown)
    property bool monitorIsFocused: (Hyprland.focusedMonitor?.name == monitor.name)
    property var windows: HyprlandData.windowList
    property var windowByAddress: HyprlandData.windowByAddress
    property var windowAddresses: HyprlandData.addresses
    property var workspaceIds: HyprlandData.workspaceIds
    property var monitorData: HyprlandData.monitors.find(m => m.id === root.monitor?.id)
    property real workspaceScale: GlobalConfig.overview.scale
    property color activeBorderColor: Colours.palette.m3primary

    property real workspaceImplicitWidth: Math.round((monitorData?.transform % 2 === 1) ?
        ((monitor.height / monitor.scale - (monitorData?.reserved?.[0] ?? 0) - (monitorData?.reserved?.[2] ?? 0)) * root.workspaceScale) :
        ((monitor.width / monitor.scale - (monitorData?.reserved?.[0] ?? 0) - (monitorData?.reserved?.[2] ?? 0)) * root.workspaceScale))
    property real workspaceImplicitHeight: Math.round((monitorData?.transform % 2 === 1) ?
        ((monitor.width / monitor.scale - (monitorData?.reserved?.[1] ?? 0) - (monitorData?.reserved?.[3] ?? 0)) * root.workspaceScale) :
        ((monitor.height / monitor.scale - (monitorData?.reserved?.[1] ?? 0) - (monitorData?.reserved?.[3] ?? 0)) * root.workspaceScale))

    property real workspaceNumberMargin: 80
    property real workspaceNumberSize: (GlobalConfig.overview.workspaceNumberBaseSize) * monitor.scale
    property int workspaceZ: 0
    property int windowZ: 1
    property int windowDraggingZ: 99999
    property real workspaceSpacing: GlobalConfig.overview.workspaceSpacing
    property string emptyWorkspaceWallpaperPath: GlobalConfig.overview.emptyWorkspaceWallpaper
    property string specialEmptyWorkspaceWallpaperPath: GlobalConfig.overview.specialEmptyWorkspaceWallpaper
    property bool showSpecialWorkspaces: GlobalConfig.overview.showSpecialWorkspaces
    property bool showCreateSpecialWorkspaceTile: GlobalConfig.overview.showCreateSpecialWorkspaceTile ?? false
    property var configuredSpecialWorkspaces: GlobalConfig.overview.specialWorkspaces
    property int specialWorkspaceColumns: Math.max(1, GlobalConfig.overview.specialWorkspaceColumns)
    property real panelOpacity: Math.max(0, Math.min(1, GlobalConfig.overview.effects.panelOpacity))
    property real workspaceOpacity: Math.max(0, Math.min(1, GlobalConfig.overview.effects.workspaceOpacity))
    property real emptyWorkspaceWallpaperOverlayOpacity: Math.max(0, Math.min(1, GlobalConfig.overview.effects.emptyWorkspaceWallpaperOverlayOpacity))

    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1
    property string draggingTargetSpecialWorkspace: ""
    property int previewRecaptureToken: 0
    property var allWorkspaces: HyprlandData.allWorkspaces
    property bool previewsEnabled: GlobalConfig.overview.previewsEnabled
    property string previewModeRaw: GlobalConfig.overview.previewMode
    property string previewMode: {
        const mode = `${previewModeRaw ?? "live"}`.trim().toLowerCase();
        return (mode === "event" || mode === "snapshot") ? "event" : "live";
    }
    property bool useEventPreviewRefresh: previewsEnabled && previewMode === "event"

    readonly property var monitorSpecialWorkspaceNames: {
        const names = [];
        for (const ws of (allWorkspaces ?? [])) {
            const name = `${ws?.name ?? ""}`;
            if (!name.startsWith("special:"))
                continue;
            if (`${ws?.monitor ?? ""}` !== `${root.monitor?.name ?? ""}`)
                continue;
            names.push(name.slice(8));
        }
        return names;
    }

    readonly property var specialWorkspaceNamesFromWindows: {
        const names = [];
        for (const addr in windowByAddress) {
            const win = windowByAddress[addr];
            if ((win?.monitor ?? -1) !== (root.monitor?.id ?? -1))
                continue;
            const wsName = `${win?.workspace?.name ?? ""}`;
            if (!wsName.startsWith("special:"))
                continue;
            names.push(wsName.slice(8));
        }
        return names;
    }

    readonly property var visibleSpecialWorkspaces: {
        if (!showSpecialWorkspaces)
            return [];

        const out = [];
        const pushUnique = (value) => {
            const cleaned = `${value ?? ""}`.trim();
            if (cleaned.length === 0 || out.includes(cleaned))
                return;
            out.push(cleaned);
        };

        for (const configured of configuredSpecialWorkspaces ?? [])
            pushUnique(configured);
        for (const name of monitorSpecialWorkspaceNames)
            pushUnique(name);
        for (const name of specialWorkspaceNamesFromWindows)
            pushUnique(name);

        return out;
    }

    readonly property bool hasSpecialWorkspaceSection: visibleSpecialWorkspaces.length > 0
    readonly property bool hasEmptyWorkspaceWallpaper: `${emptyWorkspaceWallpaperPath ?? ""}`.trim().length > 0
    readonly property bool hasSpecialEmptyWorkspaceWallpaper: `${specialEmptyWorkspaceWallpaperPath ?? ""}`.trim().length > 0
    readonly property string createSpecialWorkspaceTarget: "__create_special_workspace__"
    readonly property real specialWorkspaceTileHeight: root.workspaceImplicitHeight
    readonly property real specialStripGap: workspaceSpacing * 1.5
    readonly property int totalSpecialTiles: visibleSpecialWorkspaces.length + (showCreateSpecialWorkspaceTile ? 1 : 0)
    readonly property real specialSectionWidth: workspaceColumnLayout.implicitWidth
    readonly property int effectiveSpecialColumns: Math.max(1, Math.min(root.specialWorkspaceColumns, root.totalSpecialTiles))
    readonly property int specialWorkspaceRows: Math.ceil(root.totalSpecialTiles / root.effectiveSpecialColumns)
    readonly property real specialWorkspaceAspectCap: {
        // Use the same aspect ratio as normal workspaces (monitor aspect ratio)
        return Math.max(1, root.workspaceImplicitWidth / Math.max(1, root.workspaceImplicitHeight));
    }
    readonly property real specialWorkspaceTileWidth: {
        const gaps = Math.max(0, root.effectiveSpecialColumns - 1);
        const rawWidth = (root.specialSectionWidth - gaps * workspaceSpacing) / root.effectiveSpecialColumns;
        const aspectWidth = root.specialWorkspaceTileHeight * root.specialWorkspaceAspectCap;
        const cappedWidth = Math.min(rawWidth, aspectWidth);
        return Math.max(80 * root.workspaceScale, cappedWidth);
    }
    readonly property real specialGridUsedWidth: root.effectiveSpecialColumns * root.specialWorkspaceTileWidth + Math.max(0, root.effectiveSpecialColumns - 1) * workspaceSpacing
    readonly property real specialGridOffsetX: Math.max(0, (root.specialSectionWidth - root.specialGridUsedWidth) / 2)
    readonly property real specialGridHeight: root.specialWorkspaceRows * root.specialWorkspaceTileHeight + Math.max(0, root.specialWorkspaceRows - 1) * workspaceSpacing
    readonly property real specialStripHeight: root.specialGridHeight + root.specialStripGap

    function getWorkspaceRow(workspaceId) {
        if (!Number.isFinite(workspaceId))
            return 0;
        const adjusted = workspaceId - workspaceOffset;
        const normalRow = Math.floor((adjusted - 1) / (GlobalConfig.overview.columns)) % (GlobalConfig.overview.rows);
        return (GlobalConfig.overview.orderBottomUp) ? ((GlobalConfig.overview.rows) - normalRow - 1) : normalRow;
    }

    function getWorkspaceColumn(workspaceId) {
        if (!Number.isFinite(workspaceId))
            return 0;
        const adjusted = workspaceId - workspaceOffset;
        const normalCol = (adjusted - 1) % (GlobalConfig.overview.columns);
        return (GlobalConfig.overview.orderRightLeft) ? ((GlobalConfig.overview.columns) - normalCol - 1) : normalCol;
    }

    function getWorkspaceInCell(rowIndex, colIndex) {
        const mappedRow = (GlobalConfig.overview.orderBottomUp) ? ((GlobalConfig.overview.rows) - rowIndex - 1) : rowIndex;
        const mappedCol = (GlobalConfig.overview.orderRightLeft) ? ((GlobalConfig.overview.columns) - colIndex - 1) : colIndex;
        return (workspaceGroup * workspacesShown) + (mappedRow * (GlobalConfig.overview.columns)) + mappedCol + 1 + workspaceOffset;
    }

    function stepWorkspace(delta) {
        if (!Number.isFinite(delta) || delta === 0)
            return;

        const currentId = monitor?.activeWorkspace?.id ?? effectiveActiveWorkspaceId;
        const minWorkspaceId = workspaceOffset + 1;
        let maxWorkspaceId = minWorkspaceId + workspacesShown - 1;
        for (const workspaceId of (workspaceIds ?? [])) {
            if (Number.isFinite(workspaceId) && workspaceId >= minWorkspaceId) {
                maxWorkspaceId = Math.max(maxWorkspaceId, workspaceId);
            }
        }
        maxWorkspaceId = Math.max(maxWorkspaceId, currentId);

        let targetId = currentId + delta;
        if (targetId < minWorkspaceId) {
            targetId = maxWorkspaceId;
        } else if (targetId > maxWorkspaceId) {
            targetId = minWorkspaceId;
        }
        Hyprland.dispatch(`workspace ${targetId}`);
    }

    function isSpecialWorkspace(windowData) {
        const wsName = `${windowData?.workspace?.name ?? ""}`;
        return wsName.startsWith("special:");
    }

    function specialWorkspaceName(windowData) {
        const wsName = `${windowData?.workspace?.name ?? ""}`;
        return wsName.startsWith("special:") ? wsName.slice(8) : "";
    }

    function specialWorkspaceIndex(name) {
        return visibleSpecialWorkspaces.indexOf(`${name ?? ""}`);
    }

    function specialWorkspaceLabel(name) {
        const raw = `${name ?? ""}`.trim();
        if (raw.length === 0)
            return "Special";
        return raw.replace(/[-_]+/g, " ");
    }

    function nextSpecialWorkspaceName() {
        const taken = new Set();
        for (const name of visibleSpecialWorkspaces)
            taken.add(`${name ?? ""}`.trim().toLowerCase());

        const base = "stash";
        if (!taken.has(base))
            return base;

        let index = 2;
        while (taken.has(`${base}-${index}`))
            index += 1;

        return `${base}-${index}`;
    }

    function wallpaperSource(path) {
        const trimmed = `${path ?? ""}`.trim();
        if (trimmed.length === 0)
            return "";
        if (trimmed.startsWith("file:/") || trimmed.startsWith("qrc:/") || trimmed.startsWith("image://") || trimmed.startsWith("http://") || trimmed.startsWith("https://"))
            return trimmed;
        if (trimmed.startsWith("/"))
            return `file://${trimmed}`;
        return trimmed;
    }

    function workspaceHasWindows(workspaceId) {
        if (!Number.isFinite(workspaceId))
            return false;

        for (const addr in windowByAddress) {
            const win = windowByAddress[addr];
            if (root.isSpecialWorkspace(win))
                continue;
            if ((win?.workspace?.id ?? -1) === workspaceId)
                return true;
        }
        return false;
    }

    function specialWindowZ(win) {
        const pinned = win?.pinned ? 200000 : 0;
        const floating = win?.floating ? 100000 : 0;
        const focus = 10000 - (win?.focusHistoryID ?? 9999);
        return pinned + floating + focus;
    }

    function specialWorkspaceGeometry(name, monitorId) {
        const trimmedName = `${name ?? ""}`.trim();
        const currentMonitorId = monitorId ?? -1;
        let minX = null;
        let minY = null;
        let maxX = null;
        let maxY = null;

        for (const addr in windowByAddress) {
            const win = windowByAddress[addr];
            if ((win?.monitor ?? -1) !== currentMonitorId)
                continue;
            if (root.specialWorkspaceName(win) !== trimmedName)
                continue;

            const atX = win?.at?.[0];
            const atY = win?.at?.[1];
            const width = win?.size?.[0];
            const height = win?.size?.[1];
            if (!Number.isFinite(atX) || !Number.isFinite(atY))
                continue;
            if (!Number.isFinite(width) || !Number.isFinite(height))
                continue;

            minX = minX === null ? atX : Math.min(minX, atX);
            minY = minY === null ? atY : Math.min(minY, atY);
            maxX = maxX === null ? (atX + width) : Math.max(maxX, atX + width);
            maxY = maxY === null ? (atY + height) : Math.max(maxY, atY + height);
        }

        return {
            x: minX,
            y: minY,
            width: (minX !== null && maxX !== null) ? Math.max(1, maxX - minX) : null,
            height: (minY !== null && maxY !== null) ? Math.max(1, maxY - minY) : null
        };
    }

    // Calculate which rows have windows or current workspace
    property var rowsWithContent: {
        if (!(GlobalConfig.overview.hideEmptyRows)) return null;

        let rows = new Set();
        const firstWorkspace = root.workspaceGroup * root.workspacesShown + 1 + workspaceOffset;
        const lastWorkspace = (root.workspaceGroup + 1) * root.workspacesShown + workspaceOffset;

        // Add row containing current workspace
        const currentWorkspace = effectiveActiveWorkspaceId;
        if (currentWorkspace >= firstWorkspace && currentWorkspace <= lastWorkspace) {
            rows.add(getWorkspaceRow(currentWorkspace));
        }

        // Add rows with windows
        for (let addr in windowByAddress) {
            const win = windowByAddress[addr];
            const wsId = win?.workspace?.id;
            if (wsId >= firstWorkspace && wsId <= lastWorkspace) {
                const rowIndex = getWorkspaceRow(wsId);
                rows.add(rowIndex);
            }
        }

        return rows;
    }

    implicitWidth: overviewBackground.implicitWidth + (embedded ? 0 : Tokens.padding.large * 2)
    implicitHeight: overviewBackground.implicitHeight + (embedded ? 0 : Tokens.padding.large * 2)

    // In embedded mode, use simpler color mixing
    function mixColor(c1, c2, ratio) {
        return Qt.rgba(
            c1.r * (1 - ratio) + c2.r * ratio,
            c1.g * (1 - ratio) + c2.g * ratio,
            c1.b * (1 - ratio) + c2.b * ratio,
            c1.a * (1 - ratio) + c2.a * ratio
        );
    }

    function applyAlpha(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha);
    }

    function transparentize(color, amount) {
        return Qt.rgba(color.r, color.g, color.b, Math.max(0, color.a * (1 - amount)));
    }

    // Window component definitions
    property Component windowComponent: OverviewWindow {}
    property list<OverviewWindow> windowWidgets: []

    // Connections for live preview updates
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!root.useEventPreviewRefresh)
                return;

            const eventName = `${event?.name ?? event?.event ?? event?.type ?? ""}`;
            if (eventName === "closewindow" || eventName === "openwindow" || eventName === "movewindow") {
                root.previewRecaptureToken += 1;
            }
        }
    }

    Rectangle { // Background
        id: overviewBackground
        property real padding: GlobalConfig.overview.backgroundPadding
        anchors.fill: parent
        anchors.margins: embedded ? 0 : Tokens.padding.large

        implicitWidth: contentLayout.implicitWidth + padding * 2
        implicitHeight: contentLayout.implicitHeight + padding * 2
        clip: true
        color: applyAlpha(Colours.tPalette.m3surface, root.panelOpacity)
        border.width: 0
        border.color: applyAlpha(Colours.palette.m3outline, root.panelOpacity)

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onPressed: mouse => mouse.accepted = true
        }

        ColumnLayout { // Workspaces
            id: contentLayout

            z: root.workspaceZ
            anchors.centerIn: parent
            spacing: workspaceSpacing
            implicitHeight: contentLayout.height
            implicitWidth: contentLayout.width

            ColumnLayout {
                id: workspaceColumnLayout
                spacing: workspaceSpacing

                Repeater {
                    model: GlobalConfig.overview.rows
                    delegate: RowLayout {
                        id: row
                        required property int index
                        property int rowIndex: index
                        spacing: workspaceSpacing
                        visible: !(GlobalConfig.overview.hideEmptyRows) ||
                                 (root.rowsWithContent && root.rowsWithContent.has(rowIndex))
                        Layout.preferredHeight: visible ? implicitHeight : 0

                        Repeater { // Workspace repeater
                            model: GlobalConfig.overview.columns
                            delegate: Rectangle { // Workspace
                                id: workspace
                                required property int index
                                property int colIndex: index
                                property int workspaceValue: root.getWorkspaceInCell(rowIndex, colIndex)
                                property bool showWallpaper: root.hasEmptyWorkspaceWallpaper
                                property color defaultWorkspaceColor: Colours.tPalette.m3surfaceContainer
                                property color hoveredWorkspaceColor: mixColor(defaultWorkspaceColor, Colours.tPalette.m3surfaceContainerHigh, 0.3)
                                property color hoveredBorderColor: Colours.palette.m3outlineVariant
                                property bool hoveredWhileDragging: false

                                implicitWidth: root.workspaceImplicitWidth
                                implicitHeight: root.workspaceImplicitHeight
                                color: showWallpaper ? "transparent" : applyAlpha((hoveredWhileDragging ? hoveredWorkspaceColor : defaultWorkspaceColor), root.workspaceOpacity)
                                radius: Tokens.rounding.large * root.workspaceScale
                                border.width: 2
                                border.color: hoveredWhileDragging
                                    ? applyAlpha(hoveredBorderColor, 1)
                                    : "transparent"

                                Image {
                                    id: workspaceWallpaper
                                    visible: workspace.showWallpaper
                                    anchors.fill: parent
                                    source: root.wallpaperSource(root.emptyWorkspaceWallpaperPath)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    smooth: true
                                    mipmap: true
                                    layer.enabled: workspace.showWallpaper
                                    layer.smooth: true
                                    layer.effect: MultiEffect {
                                        maskEnabled: true
                                        maskSource: workspaceWallpaperMask
                                        maskThresholdMin: 0.5
                                        maskSpreadAtMin: 1.0
                                    }
                                }

                                Item {
                                    id: workspaceWallpaperMask
                                    anchors.fill: parent
                                    visible: false
                                    layer.enabled: true
                                    layer.smooth: true
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: workspace.radius
                                    }
                                }

                                Rectangle {
                                    visible: workspace.showWallpaper
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: applyAlpha(
                                        workspace.hoveredWhileDragging ? workspace.hoveredWorkspaceColor : workspace.defaultWorkspaceColor,
                                        workspace.hoveredWhileDragging
                                            ? Math.min(0.28, root.emptyWorkspaceWallpaperOverlayOpacity + 0.08)
                                            : root.emptyWorkspaceWallpaperOverlayOpacity
                                    )
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !workspace.showWallpaper
                                    text: workspaceValue
                                    font {
                                        pointSize: root.workspaceNumberSize * root.workspaceScale
                                        weight: Font.DemiBold
                                        family: Tokens.font.family.display ?? Tokens.font.family.sans
                                    }
                                    color: transparentize(Colours.palette.m3onSurface, 0.8)
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                MouseArea {
                                    id: workspaceArea
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton
                                    onClicked: {
                                        if (root.draggingTargetWorkspace === -1) {
                                            Hyprland.dispatch(`workspace ${workspaceValue}`)
                                        }
                                    }
                                }

                                DropArea {
                                    anchors.fill: parent
                                    onEntered: {
                                        root.draggingTargetWorkspace = workspaceValue
                                        root.draggingTargetSpecialWorkspace = ""
                                        if (root.draggingFromWorkspace == root.draggingTargetWorkspace) return;
                                        hoveredWhileDragging = true
                                    }
                                    onExited: {
                                        hoveredWhileDragging = false
                                        if (root.draggingTargetWorkspace == workspaceValue) root.draggingTargetWorkspace = -1
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                id: specialWorkspaceSection
                visible: root.showSpecialWorkspaces && root.totalSpecialTiles > 0
                implicitWidth: root.specialSectionWidth
                implicitHeight: visible ? root.specialStripHeight : 0

                Grid {
                    id: specialWorkspaceGrid
                    x: root.specialGridOffsetX
                    y: root.specialStripGap
                    width: root.specialGridUsedWidth
                    columns: root.effectiveSpecialColumns
                    rowSpacing: workspaceSpacing
                    columnSpacing: workspaceSpacing

                    Repeater {
                        model: root.visibleSpecialWorkspaces
                        delegate: Rectangle {
                            id: specialWorkspaceTile
                            required property string modelData
                            property string specialName: modelData
                            property var specialGeometry: root.specialWorkspaceGeometry(specialName, root.monitor?.id)
                            property color baseColor: mixColor(Colours.tPalette.m3surfaceContainer, Colours.tPalette.m3surface, 0.52)
                            property bool hasRenderableGeometry: Number.isFinite(specialGeometry?.width)
                                && Number.isFinite(specialGeometry?.height)
                                && specialGeometry.width > 0
                                && specialGeometry.height > 0
                            property bool showWallpaper: root.hasSpecialEmptyWorkspaceWallpaper
                            property real geometryWidth: hasRenderableGeometry ? specialGeometry.width : Math.max(1, root.workspaceImplicitWidth / root.workspaceScale)
                            property real geometryHeight: hasRenderableGeometry ? specialGeometry.height : Math.max(1, root.workspaceImplicitHeight / root.workspaceScale)
                            property real fitScale: hasRenderableGeometry ? Math.min(width / geometryWidth, height / geometryHeight) : root.workspaceScale
                            property real contentWidth: hasRenderableGeometry ? (geometryWidth * fitScale) : width
                            property real contentHeight: hasRenderableGeometry ? (geometryHeight * fitScale) : height
                            property real contentOffsetX: Math.max(0, (width - contentWidth) / 2)
                            property real contentOffsetY: Math.max(0, (height - contentHeight) / 2)
                            implicitWidth: root.specialWorkspaceTileWidth
                            implicitHeight: root.specialWorkspaceTileHeight
                            radius: Tokens.rounding.large * root.workspaceScale
                            clip: true
                            color: showWallpaper ? "transparent" : applyAlpha(baseColor, root.workspaceOpacity)
                            border.width: 1
                            border.color: applyAlpha(Colours.palette.m3outlineVariant, 0.75)

                            Image {
                                visible: specialWorkspaceTile.showWallpaper
                                anchors.fill: parent
                                source: root.wallpaperSource(root.specialEmptyWorkspaceWallpaperPath)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                smooth: true
                                mipmap: true
                            }

                            Rectangle {
                                visible: specialWorkspaceTile.showWallpaper
                                anchors.fill: parent
                                radius: parent.radius
                                color: applyAlpha(specialWorkspaceTile.baseColor, root.emptyWorkspaceWallpaperOverlayOpacity)
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                onClicked: {
                                    if (root.draggingTargetWorkspace === -1 && !root.draggingTargetSpecialWorkspace) {
                                        Hyprland.dispatch(`togglespecialworkspace ${specialWorkspaceTile.specialName}`);
                                    }
                                }
                            }

                            DropArea {
                                anchors.fill: parent
                                onEntered: {
                                    root.draggingTargetWorkspace = -1;
                                    root.draggingTargetSpecialWorkspace = specialWorkspaceTile.specialName;
                                }
                                onExited: {
                                    if (root.draggingTargetSpecialWorkspace === specialWorkspaceTile.specialName)
                                        root.draggingTargetSpecialWorkspace = "";
                                }
                            }

                            Item {
                                id: specialWorkspaceContent
                                x: specialWorkspaceTile.contentOffsetX
                                y: specialWorkspaceTile.contentOffsetY
                                width: specialWorkspaceTile.contentWidth
                                height: specialWorkspaceTile.contentHeight
                                clip: true

                                Repeater {
                                    model: ScriptModel {
                                        values: {
                                            if (!specialWorkspaceTile.hasRenderableGeometry)
                                                return [];
                                            return ToplevelManager.toplevels.values.filter((toplevel) => {
                                                const address = `0x${toplevel.HyprlandToplevel.address}`;
                                                const win = windowByAddress[address];
                                                if ((win?.monitor ?? -1) !== (root.monitor?.id ?? -1))
                                                    return false;
                                                return root.specialWorkspaceName(win) === specialWorkspaceTile.specialName;
                                            }).sort((a, b) => {
                                                const addrA = `0x${a.HyprlandToplevel.address}`;
                                                const addrB = `0x${b.HyprlandToplevel.address}`;
                                                return addrA.localeCompare(addrB);
                                            });
                                        }
                                    }
                                    delegate: OverviewWindow {
                                        id: specialWindow
                                        required property var modelData
                                        required property int index

                                        // Get data from windowByAddress
                                        property var address: `0x${modelData.HyprlandToplevel.address}`
                                        windowData: windowByAddress[address]
                                        toplevel: modelData
                                        property int monitorId: windowData?.monitor ?? 0
                                        property var monitor: HyprlandData.monitors.find(m => m.id === monitorId)
                                        property Item homeParent: specialWorkspaceContent
                                        monitorData: monitor
                                        widgetMonitorData: root.monitorData
                                        scale: root.workspaceScale
                                        availableWorkspaceWidth: specialWorkspaceContent.width
                                        availableWorkspaceHeight: specialWorkspaceContent.height
                                        positionBaseX: Number.isFinite(specialWorkspaceTile.specialGeometry?.x) ? specialWorkspaceTile.specialGeometry.x : ((monitor?.x ?? 0) + (monitor?.reserved?.[0] ?? 0))
                                        positionBaseY: Number.isFinite(specialWorkspaceTile.specialGeometry?.y) ? specialWorkspaceTile.specialGeometry.y : ((monitor?.y ?? 0) + (monitor?.reserved?.[1] ?? 0))
                                        geometryScaleX: specialWorkspaceTile.fitScale / root.workspaceScale
                                        geometryScaleY: specialWorkspaceTile.fitScale / root.workspaceScale
                                        xOffset: 0
                                        yOffset: 0
                                        widgetMonitorId: root.monitor.id
                                        recaptureToken: root.previewRecaptureToken
                                        restrictToWorkspace: false
                                        animateSize: false
                                        z: root.specialWindowZ(windowData)

                                        function moveToDragLayer() {
                                            const mapped = specialWindow.mapToItem(specialWindowDragLayer, 0, 0);
                                            specialWindow.suspendPositionAnimation = true;
                                            specialWindow.parent = specialWindowDragLayer;
                                            specialWindow.x = mapped.x;
                                            specialWindow.y = mapped.y;
                                            specialWindow.z = root.windowDraggingZ + 1;
                                            Qt.callLater(() => specialWindow.suspendPositionAnimation = false);
                                        }

                                        function returnToHomeParent() {
                                            specialWindow.suspendPositionAnimation = true;
                                            specialWindow.parent = homeParent;
                                            specialWindow.z = root.specialWindowZ(windowData);
                                            Qt.callLater(() => specialWindow.suspendPositionAnimation = false);
                                        }

                                        MouseArea {
                                            id: specialDragArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onEntered: hovered = true
                                            onExited: hovered = false
                                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                            drag.target: parent
                                            onPressed: (mouse) => {
                                                root.draggingFromWorkspace = -1
                                                root.draggingTargetSpecialWorkspace = ""
                                                specialWindow.pressed = true
                                                specialWindow.dragInProgress = true
                                                specialWindow.Drag.source = specialWindow
                                                specialWindow.Drag.hotSpot.x = mouse.x
                                                specialWindow.Drag.hotSpot.y = mouse.y
                                                specialWindow.moveToDragLayer()
                                                specialWindow.Drag.active = true
                                            }
                                            onReleased: {
                                                const targetWorkspace = root.draggingTargetWorkspace
                                                const targetSpecialWorkspace = root.draggingTargetSpecialWorkspace
                                                specialWindow.pressed = false
                                                specialWindow.Drag.active = false
                                                specialWindow.dragInProgress = false
                                                root.draggingFromWorkspace = -1
                                                root.draggingTargetWorkspace = -1
                                                root.draggingTargetSpecialWorkspace = ""
                                                if (targetSpecialWorkspace === root.createSpecialWorkspaceTarget) {
                                                    const createdName = root.nextSpecialWorkspaceName()
                                                    Hyprland.dispatch(`movetoworkspacesilent special:${createdName}, address:${specialWindow.windowData?.address}`)
                                                    specialWindow.returnToHomeParent()
                                                    specialWindow.x = specialWindow.initX
                                                    specialWindow.y = specialWindow.initY
                                                }
                                                else if (targetSpecialWorkspace && targetSpecialWorkspace !== specialWorkspaceTile.specialName) {
                                                    Hyprland.dispatch(`movetoworkspacesilent special:${targetSpecialWorkspace}, address:${specialWindow.windowData?.address}`)
                                                    specialWindow.returnToHomeParent()
                                                    specialWindow.x = specialWindow.initX
                                                    specialWindow.y = specialWindow.initY
                                                }
                                                else if (targetWorkspace !== -1) {
                                                    Hyprland.dispatch(`movetoworkspacesilent ${targetWorkspace}, address:${specialWindow.windowData?.address}`)
                                                    specialWindow.returnToHomeParent()
                                                    specialWindow.x = specialWindow.initX
                                                    specialWindow.y = specialWindow.initY
                                                }
                                                else {
                                                    specialWindow.returnToHomeParent()
                                                    specialWindow.x = specialWindow.initX
                                                    specialWindow.y = specialWindow.initY
                                                }
                                            }
                                            onClicked: (event) => {
                                                if (!windowData)
                                                    return;
                                                if (event.button === Qt.LeftButton) {
                                                    // Close overview if embedded in dashboard
                                                    if (!root.embedded && typeof GlobalStates !== "undefined") {
                                                        GlobalStates.overviewOpen = false;
                                                    }
                                                    Hyprland.dispatch(`focuswindow address:${windowData.address}`);
                                                    event.accepted = true;
                                                } else if (event.button === Qt.MiddleButton) {
                                                    Hyprland.dispatch(`closewindow address:${windowData.address}`);
                                                    event.accepted = true;
                                                }
                                            }

                                            ToolTip {
                                                visible: specialDragArea.containsMouse && !specialWindow.Drag.active
                                                text: `${windowData?.title ?? "Unknown"}\n[${windowData?.class ?? "unknown"}] ${windowData?.xwayland ? "[XWayland] " : ""}`
                                                delay: 500
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: createSpecialWorkspaceTile
                        visible: root.showCreateSpecialWorkspaceTile
                        property bool showWallpaper: root.hasSpecialEmptyWorkspaceWallpaper
                        implicitWidth: root.specialWorkspaceTileWidth
                        implicitHeight: root.specialWorkspaceTileHeight
                        radius: Tokens.rounding.large * root.workspaceScale
                        color: showWallpaper ? "transparent" : applyAlpha(
                            mixColor(Colours.tPalette.m3surfaceContainerHigh, Colours.tPalette.m3surfaceContainer, 0.55),
                            root.draggingTargetSpecialWorkspace === root.createSpecialWorkspaceTarget ? 0.90 : root.workspaceOpacity
                        )
                        border.width: 1
                        border.color: root.draggingTargetSpecialWorkspace === root.createSpecialWorkspaceTarget
                            ? applyAlpha(root.activeBorderColor, 0.96)
                            : applyAlpha(Colours.palette.m3primary, 0.46)

                        Image {
                            visible: createSpecialWorkspaceTile.showWallpaper
                            anchors.fill: parent
                            source: root.wallpaperSource(root.specialEmptyWorkspaceWallpaperPath)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                            mipmap: true
                        }

                        Rectangle {
                            visible: createSpecialWorkspaceTile.showWallpaper
                            anchors.fill: parent
                            radius: parent.radius
                            color: applyAlpha(
                                mixColor(Colours.tPalette.m3surfaceContainerHigh, Colours.tPalette.m3surfaceContainer, 0.55),
                                root.draggingTargetSpecialWorkspace === root.createSpecialWorkspaceTarget
                                    ? Math.min(0.28, root.emptyWorkspaceWallpaperOverlayOpacity + 0.08)
                                    : root.emptyWorkspaceWallpaperOverlayOpacity
                            )
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: Math.max(parent.radius - 1, 0)
                            color: "transparent"
                            border.width: 1
                            border.color: applyAlpha("#FFFFFF", 0.08)
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 0

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: !createSpecialWorkspaceTile.showWallpaper
                                text: root.draggingTargetSpecialWorkspace === root.createSpecialWorkspaceTarget ? "Release" : "+"
                                font.family: Tokens.font.family.display ?? Tokens.font.family.sans
                                font.pointSize: root.draggingTargetSpecialWorkspace === root.createSpecialWorkspaceTarget
                                    ? Tokens.font.size.large * root.workspaceScale
                                    : Tokens.font.size.huge * 1.25 * root.workspaceScale
                                font.weight: Font.DemiBold
                                color: applyAlpha(Colours.palette.m3onSurface, 0.92)
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            onClicked: {
                                const createdName = root.nextSpecialWorkspaceName();
                                Hyprland.dispatch(`togglespecialworkspace ${createdName}`);
                            }
                        }

                        DropArea {
                            anchors.fill: parent
                            onEntered: {
                                root.draggingTargetWorkspace = -1;
                                root.draggingTargetSpecialWorkspace = root.createSpecialWorkspaceTarget;
                            }
                            onExited: {
                                if (root.draggingTargetSpecialWorkspace === root.createSpecialWorkspaceTarget)
                                    root.draggingTargetSpecialWorkspace = "";
                            }
                        }
                    }
                }
            }
        }

        Item { // Windows & focused workspace indicator
            id: windowSpace
            anchors.centerIn: parent
            implicitWidth: contentLayout.implicitWidth
            implicitHeight: contentLayout.implicitHeight

            WheelHandler {
                target: null
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    const deltaY = event.angleDelta.y;
                    if (!deltaY)
                        return;
                    root.stepWorkspace(deltaY > 0 ? -1 : 1);
                    event.accepted = true;
                }
            }

            Repeater { // Window repeater
                model: ScriptModel {
                    values: {
                        return ToplevelManager.toplevels.values.filter((toplevel) => {
                            const address = `0x${toplevel.HyprlandToplevel.address}`
                            var win = windowByAddress[address]
                            if (root.isSpecialWorkspace(win))
                                return false;
                            const minWorkspace = root.workspaceGroup * root.workspacesShown + 1 + workspaceOffset;
                            const maxWorkspace = (root.workspaceGroup + 1) * root.workspacesShown + workspaceOffset;
                            const inWorkspaceGroup = (minWorkspace <= win?.workspace?.id && win?.workspace?.id <= maxWorkspace)
                            return inWorkspaceGroup;
                        }).sort((a, b) => {
                            // Proper stacking order based on Hyprland's window properties
                            const addrA = `0x${a.HyprlandToplevel.address}`
                            const addrB = `0x${b.HyprlandToplevel.address}`
                            const winA = windowByAddress[addrA]
                            const winB = windowByAddress[addrB]

                            // 1. Pinned windows are always on top
                            if (winA?.pinned !== winB?.pinned) {
                                return winA?.pinned ? 1 : -1
                            }

                            // 2. Floating windows above tiled windows
                            if (winA?.floating !== winB?.floating) {
                                return winA?.floating ? 1 : -1
                            }

                            // 3. Within same category, sort by focus history
                            return (winB?.focusHistoryID ?? 0) - (winA?.focusHistoryID ?? 0);
                        })
                    }
                }
                delegate: OverviewWindow {
                    id: window
                    required property var modelData
                    required property int index
                    property int monitorId: windowData?.monitor
                    property var monitor: HyprlandData.monitors.find(m => m.id === monitorId)
                    property var address: `0x${modelData.HyprlandToplevel.address}`
                    windowData: windowByAddress[address]
                    toplevel: modelData
                    monitorData: monitor
                    widgetMonitorData: root.monitorData
                    scale: root.workspaceScale
                    availableWorkspaceWidth: root.workspaceImplicitWidth
                    availableWorkspaceHeight: root.workspaceImplicitHeight
                    widgetMonitorId: root.monitor.id
                    recaptureToken: root.previewRecaptureToken

                    property bool atInitPosition: (initX == x && initY == y)

                    property int workspaceColIndex: root.getWorkspaceColumn(windowData?.workspace.id)
                    property int workspaceRowIndex: root.getWorkspaceRow(windowData?.workspace.id)
                    xOffset: (root.workspaceImplicitWidth + workspaceSpacing) * workspaceColIndex
                    yOffset: (root.workspaceImplicitHeight + workspaceSpacing) * workspaceRowIndex

                    Timer {
                        id: updateWindowPosition
                        interval: GlobalConfig.overview.hacks?.arbitraryRaceConditionDelay
                        repeat: false
                        running: false
                        onTriggered: {
                            window.x = Math.round(Math.max((windowData?.at[0] - (monitor?.x ?? 0) - (monitorData?.reserved?.[0] ?? 0)) * root.workspaceScale * window.widthRatio, 0) + xOffset)
                            window.y = Math.round(Math.max((windowData?.at[1] - (monitor?.y ?? 0) - (monitorData?.reserved?.[1] ?? 0)) * root.workspaceScale * window.heightRatio, 0) + yOffset)
                        }
                    }

                    z: atInitPosition ? (root.windowZ + index) : root.windowDraggingZ
                    Drag.hotSpot.x: targetWindowWidth / 2
                    Drag.hotSpot.y: targetWindowHeight / 2
                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: hovered = true
                        onExited: hovered = false
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        drag.target: parent
                        onPressed: (mouse) => {
                            root.draggingFromWorkspace = windowData?.workspace.id
                            root.draggingTargetSpecialWorkspace = ""
                            window.pressed = true
                            window.Drag.active = true
                            window.Drag.source = window
                            window.Drag.hotSpot.x = mouse.x
                            window.Drag.hotSpot.y = mouse.y
                        }
                        onReleased: {
                            const targetWorkspace = root.draggingTargetWorkspace
                            const targetSpecialWorkspace = root.draggingTargetSpecialWorkspace
                            window.pressed = false
                            window.Drag.active = false
                            root.draggingFromWorkspace = -1
                            root.draggingTargetWorkspace = -1
                            root.draggingTargetSpecialWorkspace = ""
                            if (targetSpecialWorkspace === root.createSpecialWorkspaceTarget) {
                                const createdName = root.nextSpecialWorkspaceName()
                                Hyprland.dispatch(`movetoworkspacesilent special:${createdName}, address:${window.windowData?.address}`)
                                updateWindowPosition.restart()
                            }
                            else if (targetSpecialWorkspace && targetSpecialWorkspace !== root.specialWorkspaceName(windowData)) {
                                Hyprland.dispatch(`movetoworkspacesilent special:${targetSpecialWorkspace}, address:${window.windowData?.address}`)
                                updateWindowPosition.restart()
                            }
                            else if (targetWorkspace !== -1 && targetWorkspace !== windowData?.workspace.id) {
                                Hyprland.dispatch(`movetoworkspacesilent ${targetWorkspace}, address:${window.windowData?.address}`)
                                updateWindowPosition.restart()
                            }
                            else {
                                window.x = window.initX
                                window.y = window.initY
                            }
                        }
                        onClicked: (event) => {
                            if (!windowData) return;

                            if (event.button === Qt.LeftButton) {
                                // Close overview if embedded in dashboard
                                if (!root.embedded && typeof GlobalStates !== "undefined") {
                                    GlobalStates.overviewOpen = false;
                                }
                                Hyprland.dispatch(`focuswindow address:${windowData.address}`)
                                event.accepted = true
                            } else if (event.button === Qt.MiddleButton) {
                                Hyprland.dispatch(`closewindow address:${windowData.address}`)
                                event.accepted = true
                            }
                        }

                        ToolTip {
                            visible: dragArea.containsMouse && !window.Drag.active
                            text: `${windowData?.title ?? "Unknown"}\n[${windowData?.class ?? "unknown"}] ${windowData?.xwayland ? "[XWayland] " : ""}`
                            delay: 500
                        }
                    }
                }
            }

            Rectangle { // Focused workspace indicator
                id: focusedWorkspaceIndicator
                property int activeWorkspaceRowIndex: root.getWorkspaceRow(root.effectiveActiveWorkspaceId)
                property int activeWorkspaceColIndex: root.getWorkspaceColumn(root.effectiveActiveWorkspaceId)
                x: (root.workspaceImplicitWidth + workspaceSpacing) * activeWorkspaceColIndex
                y: (root.workspaceImplicitHeight + workspaceSpacing) * activeWorkspaceRowIndex
                z: root.windowDraggingZ - 1
                width: root.workspaceImplicitWidth
                height: root.workspaceImplicitHeight
                color: "transparent"
                radius: Tokens.rounding.large * root.workspaceScale
                border.width: 2
                border.color: root.activeBorderColor

                Behavior on x {
                    NumberAnimation {
                        duration: Tokens.anim.durations.fast ?? 150
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: Tokens.anim.durations.fast ?? 150
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Item { // Special window drag layer
            id: specialWindowDragLayer
            anchors.fill: parent
            z: root.windowDraggingZ + 1
        }
    }
}
