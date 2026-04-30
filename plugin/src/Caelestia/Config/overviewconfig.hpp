#pragma once

#include "configobject.hpp"

namespace caelestia::config {

class OverviewAnimationDuration : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(int, elementMove, 500)
    CONFIG_PROPERTY(int, elementMoveEnter, 400)
    CONFIG_PROPERTY(int, elementMoveFast, 200)

public:
    explicit OverviewAnimationDuration(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class OverviewAnimation : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_SUBOBJECT(OverviewAnimationDuration, duration)

public:
    explicit OverviewAnimation(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_duration(new OverviewAnimationDuration(this)) {}
};

class OverviewEffects : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(qreal, panelOpacity, 0.92)
    CONFIG_PROPERTY(qreal, workspaceOpacity, 0.86)
    CONFIG_PROPERTY(qreal, emptyWorkspaceWallpaperOverlayOpacity, 0.18)
    CONFIG_PROPERTY(qreal, windowOverlayOpacity, 0.22)

public:
    explicit OverviewEffects(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class OverviewWindowPreview : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, showIcons, true)
    CONFIG_PROPERTY(qreal, iconToWindowRatio, 0.25)
    CONFIG_PROPERTY(qreal, iconToWindowRatioCompact, 0.45)
    CONFIG_PROPERTY(qreal, xwaylandIndicatorToIconRatio, 0.35)
    CONFIG_PROPERTY(qreal, inactiveMonitorOpacity, 0.4)
    CONFIG_PROPERTY(bool, cropToFill, false)

public:
    explicit OverviewWindowPreview(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class OverviewHacks : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(int, arbitraryRaceConditionDelay, 150)
    CONFIG_PROPERTY(int, hyprlandEventDebounceMs, 40)

public:
    explicit OverviewHacks(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class OverviewConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(int, rows, 2)
    CONFIG_PROPERTY(int, columns, 5)
    CONFIG_PROPERTY(qreal, scale, 0.16)
    CONFIG_PROPERTY(bool, hideEmptyRows, true)
    CONFIG_PROPERTY(bool, useWorkspaceMap, false)
    CONFIG_PROPERTY(bool, orderRightLeft, false)
    CONFIG_PROPERTY(bool, orderBottomUp, false)
    CONFIG_PROPERTY(bool, previewsEnabled, true)
    CONFIG_PROPERTY(QString, previewMode, "live")
    CONFIG_PROPERTY(bool, includeInactiveMonitorPreviews, true)
    CONFIG_PROPERTY(int, previewRecaptureDelayMs, 60)
    CONFIG_PROPERTY(bool, showSpecialWorkspaces, true)
    CONFIG_PROPERTY(bool, showCreateSpecialWorkspaceTile, false)
    CONFIG_PROPERTY(int, specialWorkspaceColumns, 5)
    CONFIG_PROPERTY(QString, emptyWorkspaceWallpaper, "")
    CONFIG_PROPERTY(QString, specialEmptyWorkspaceWallpaper, "")
    CONFIG_PROPERTY(qreal, workspaceSpacing, 5)
    CONFIG_PROPERTY(qreal, backgroundPadding, 10)
    CONFIG_PROPERTY(int, workspaceNumberBaseSize, 250)
    CONFIG_PROPERTY(qreal, elevationMargin, 10)
    CONFIG_SUBOBJECT(OverviewAnimation, animation)
    CONFIG_SUBOBJECT(OverviewEffects, effects)
    CONFIG_SUBOBJECT(OverviewWindowPreview, windowPreview)
    CONFIG_SUBOBJECT(OverviewHacks, hacks)

public:
    explicit OverviewConfig(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_animation(new OverviewAnimation(this))
        , m_effects(new OverviewEffects(this))
        , m_windowPreview(new OverviewWindowPreview(this))
        , m_hacks(new OverviewHacks(this)) {}
};

}
