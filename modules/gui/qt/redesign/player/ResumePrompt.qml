/*****************************************************************************
 * Copyright (C) 2026 VLC Reborn contributors
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Player
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Redesign

/**
 * @brief The resume prompt of the redesign: a compact bar just above the Play button that asks
 * whether to continue a partly watched media where it was left off.
 *
 * It takes the place of the upstream ResumeDialog (same Player calls) and hides after the same
 * time. Its parent is the item it positions itself in (the control bar).
 */
FocusScope {
    id: root

    // Properties

    // the item the prompt is placed above
    property Item anchorItem: ShellActions.playButton

    // where the media was left off, formatted (e.g. "12:34"). libvlccore does not report it
    // to the interface (vlc_player.h only has vlc_player_RestorePlaybackPos), the prompt then
    // asks "where you left off".
    property string restoreTimeText

    // Settings

    visible: false
    enabled: visible

    implicitWidth: background.implicitWidth
    implicitHeight: background.implicitHeight

    width: implicitWidth
    height: implicitHeight

    Accessible.role: Accessible.Dialog
    Accessible.name: qsTr("Resume dialog")

    Navigation.cancelAction: function() { root.dismiss() }

    // Signals

    signal hidden()

    // Functions

    function show() {
        reposition()
        root.visible = true
        continueButton.forceActiveFocus()
        timeout.restart()
    }

    // restore the position
    function accept() {
        Player.restorePlaybackPos()
        dismiss()
    }

    // start over: the media stays at the start
    function dismiss() {
        timeout.stop()
        root.visible = false
        Player.acknowledgeRestoreCallback()
        hidden()
    }

    function reposition() {
        if (!anchorItem || !parent)
            return

        const point = anchorItem.mapToItem(parent, 0, 0)

        x = Math.max(RedesignStyle.spacingS, Math.min(point.x, parent.width - width - RedesignStyle.spacingS))
        y = point.y - height - RedesignStyle.spacingS
    }

    // Events

    onAnchorItemChanged: reposition()
    onWidthChanged: reposition()
    onHeightChanged: reposition()

    Component.onCompleted: {
        if (Player.canRestorePlayback)
            show()
    }

    // Children

    Connections {
        target: Player

        function onCanRestorePlaybackChanged() {
            if (Player.canRestorePlayback)
                root.show()
            else
                root.dismiss()
        }
    }

    // the bar moves with the layout of the control bar
    Connections {
        target: root.parent

        function onWidthChanged() { root.reposition() }
        function onHeightChanged() { root.reposition() }
    }

    // not dismissed: the media was not started over explicitly, it only stops asking
    Timer {
        id: timeout

        interval: 10000

        onTriggered: {
            root.visible = false
            root.hidden()
        }
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        colorSet: ColorContext.Window
    }

    Rectangle {
        id: background

        anchors.fill: parent

        implicitWidth: row.implicitWidth + 2 * RedesignStyle.spacingM
        implicitHeight: row.implicitHeight + 2 * RedesignStyle.spacingXS

        radius: RedesignStyle.radiusL
        color: theme.bg.secondary
        border.width: VLCStyle.dp(1, VLCStyle.scale)
        border.color: theme.border

        RowLayout {
            id: row

            anchors.centerIn: parent

            spacing: RedesignStyle.spacingS

            T.Label {
                text: root.restoreTimeText !== "" ? qsTr("Continue from %1?").arg(root.restoreTimeText)
                                                  : qsTr("Continue where you left off?")
                color: theme.fg.primary
                font.pixelSize: VLCStyle.fontSize_normal
                font.bold: true
            }

            Widgets.ButtonExt {
                id: continueButton

                text: qsTr("Continue")

                AccessibleCompat.id: "resumeContinueButton"

                font.bold: true
                focus: true

                colorContext.colorSet: ColorContext.ButtonAccent

                onClicked: root.accept()

                Navigation.parentItem: root
                Navigation.rightItem: startOverButton
            }

            Widgets.ButtonExt {
                id: startOverButton

                text: qsTr("Start over")

                AccessibleCompat.id: "resumeStartOverButton"

                font.bold: true

                onClicked: root.dismiss()

                Navigation.parentItem: root
                Navigation.leftItem: continueButton
            }
        }
    }
}
