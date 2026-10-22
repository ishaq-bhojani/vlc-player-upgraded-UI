/*****************************************************************************
 * Copyright (C) 2026 Vireo contributors
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

import VLC.Style
import VLC.Redesign

/**
 * @brief A selectable card of the theme step of the onboarding: a small drawing of the Vireo
 * window (title bar, icon rail, a few tiles, the control bar with the play pill) in the colours
 * of one theme, and its name under it.
 *
 * `kind` is "light", "dark" or "system"; system draws the window split in two along a diagonal,
 * the light one on the upper left. The colours are read from the palettes (`lightPalette`,
 * `darkPalette`: SystemPalette items of the two themes, owned by whoever creates the cards),
 * never written here, and the play pill uses the accent of the palette, so a swatch picked
 * elsewhere shows at once (the owner calls SystemPalette.reloadAccent()).
 *
 * `selected` is the theme in use: it gets the accent outline. A click, Enter, Return or Space
 * emits `clicked()`; the owner decides what it selects.
 */
T.AbstractButton {
    id: root

    // Properties

    //! "light", "dark" or "system"
    property string kind: "light"

    //! the theme in use
    property bool selected: false

    //! the palette of the light theme, and of the dark one
    property SystemPalette lightPalette
    property SystemPalette darkPalette

    //! the shape of the drawing (width / height)
    readonly property real aspect: 1.6

    // the width of the drawing, and its height
    readonly property real _drawingWidth: width - leftPadding - rightPadding
    readonly property real _drawingHeight: _drawingWidth / aspect

    // Settings

    implicitWidth: VLCStyle.dp(150, VLCStyle.scale)
    implicitHeight: topPadding + _drawingHeight + RedesignStyle.spacingS + label.implicitHeight + bottomPadding

    padding: VLCStyle.dp(6, VLCStyle.scale)

    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    checkable: false

    Accessible.role: Accessible.RadioButton
    Accessible.name: text
    Accessible.checked: selected
    Accessible.onPressAction: root.clicked()

    // Enter and Return select the card, as Space does
    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()

    // Children

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        colorSet: ColorContext.View

        focused: root.visualFocus
        hovered: root.hovered
    }

    // The window of one theme, drawn with its palette.
    component Miniature: Item {
        id: mini

        required property SystemPalette pal

        readonly property ColorContext windowContext: ColorContext {
            id: windowTheme

            palette: mini.pal
            colorSet: ColorContext.Window
        }

        readonly property ColorContext viewContext: ColorContext {
            id: viewTheme

            palette: mini.pal
            colorSet: ColorContext.View
        }

        readonly property ColorContext accentContext: ColorContext {
            id: accentTheme

            palette: mini.pal
            colorSet: ColorContext.ButtonAccent
        }

        readonly property real unit: height / 40

        Rectangle {
            anchors.fill: parent

            color: windowTheme.bg.primary
        }

        // the title bar
        Rectangle {
            id: titleBar

            width: parent.width
            height: mini.unit * 5

            color: windowTheme.bg.secondary

            Row {
                anchors {
                    left: parent.left
                    leftMargin: mini.unit * 2
                    verticalCenter: parent.verticalCenter
                }

                spacing: mini.unit

                Repeater {
                    model: 3

                    Rectangle {
                        width: mini.unit * 1.6
                        height: width
                        radius: width / 2
                        color: windowTheme.fg.secondary
                    }
                }
            }

            Rectangle {
                anchors.centerIn: parent

                width: mini.unit * 16
                height: mini.unit * 1.6
                radius: height / 2
                color: windowTheme.fg.secondary
            }
        }

        // the icon rail
        Rectangle {
            id: rail

            anchors {
                top: titleBar.bottom
                bottom: controlBar.top
                left: parent.left
            }

            width: mini.unit * 6

            color: windowTheme.bg.secondary

            Column {
                anchors {
                    top: parent.top
                    topMargin: mini.unit * 2
                    horizontalCenter: parent.horizontalCenter
                }

                spacing: mini.unit * 2

                Repeater {
                    model: 4

                    Rectangle {
                        required property int index

                        width: mini.unit * 2.4
                        height: width
                        radius: mini.unit * 0.6
                        color: index === 0 ? accentTheme.bg.primary : windowTheme.fg.secondary
                    }
                }
            }
        }

        // the tiles of the library
        Grid {
            anchors {
                top: titleBar.bottom
                topMargin: mini.unit * 2
                bottom: controlBar.top
                bottomMargin: mini.unit * 2
                left: rail.right
                leftMargin: mini.unit * 2
                right: parent.right
                rightMargin: mini.unit * 2
            }

            columns: 3
            rows: 2
            spacing: mini.unit * 1.6

            readonly property real tileWidth: (width - (columns - 1) * spacing) / columns
            readonly property real tileHeight: (height - (rows - 1) * spacing) / rows

            Repeater {
                model: 6

                Rectangle {
                    width: parent.tileWidth
                    height: parent.tileHeight
                    radius: mini.unit * 1.2
                    color: viewTheme.bg.secondary
                }
            }
        }

        // the control bar: the seek line and the play pill
        Rectangle {
            id: controlBar

            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }

            height: mini.unit * 8

            color: windowTheme.bg.secondary

            Rectangle {
                anchors {
                    left: parent.left
                    leftMargin: mini.unit * 2
                    right: parent.right
                    rightMargin: mini.unit * 2
                    top: parent.top
                    topMargin: mini.unit * 1.2
                }

                height: mini.unit * 0.8
                radius: height / 2
                color: windowTheme.fg.secondary
                opacity: 0.5
            }

            Rectangle {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: mini.unit * 1.2
                }

                width: mini.unit * 10
                height: mini.unit * 4
                radius: height / 2
                color: accentTheme.bg.primary
            }
        }
    }

    contentItem: ColumnLayout {
        spacing: RedesignStyle.spacingS

        // the drawing, clipped by its frame
        Item {
            id: frame

            Layout.fillWidth: true
            Layout.preferredHeight: root._drawingHeight

            clip: true

            // light and dark: one window
            Miniature {
                anchors.fill: parent

                visible: root.kind !== "system"
                pal: root.kind === "light" ? root.lightPalette : root.darkPalette
            }

            // system: the dark window, and over its upper left half the light one. The half is
            // a rotated clipping rectangle whose right edge passes through the middle of the card
            // (the content is turned back so that it stays upright).
            Item {
                anchors.fill: parent

                visible: root.kind === "system"

                Miniature {
                    anchors.fill: parent

                    pal: root.darkPalette
                }

                Item {
                    id: half

                    readonly property real reach: Math.sqrt(frame.width * frame.width + frame.height * frame.height)

                    width: reach
                    height: reach * 2
                    x: frame.width / 2 - width
                    y: frame.height / 2 - height / 2

                    transformOrigin: Item.Right
                    rotation: Math.atan2(frame.width, frame.height) * 180 / Math.PI

                    clip: true

                    Item {
                        width: frame.width
                        height: frame.height
                        x: half.width - width / 2
                        y: half.height / 2 - height / 2

                        transformOrigin: Item.Center
                        rotation: -half.rotation

                        Miniature {
                            anchors.fill: parent

                            pal: root.lightPalette
                        }
                    }
                }
            }
        }

        Text {
            id: label

            Layout.fillWidth: true

            text: root.text
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: VLCStyle.fontSize_normal
            font.bold: root.selected
            color: theme.fg.primary
            elide: Text.ElideRight

            Accessible.ignored: true
        }
    }

    background: Rectangle {
        radius: RedesignStyle.radiusM
        color: "transparent"

        border.width: (root.selected || root.visualFocus) ? VLCStyle.dp(2, VLCStyle.scale) : VLCStyle.dp(1, VLCStyle.scale)
        border.color: root.visualFocus ? theme.visualFocus
                                       : (root.selected ? theme.accent : theme.border)
    }
}
