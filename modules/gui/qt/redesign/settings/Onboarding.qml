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

import VLC.MainInterface
import VLC.Style
import VLC.Util
import VLC.Widgets as Widgets
import VLC.Redesign

/**
 * @brief The first-run onboarding: a modal over the shell that takes the place of the QWidgets
 * wizard of the stock interface (which has a Modern/Classic layout page the redesign does not
 * have). MainCtx asks for it (requestRedesignOnboarding) when "qt-privacy-ask" is set.
 *
 * The steps are OnboardingSteps.steps:
 *   theme      Light / Dark / System and the nine accent swatches (the rows of Settings > General,
 *              applied at once)
 *   shortcuts  a read-only card of the essential keys, read live from ShortcutsModel
 *   privacy    the network access for metadata, and the check for updates
 *   folders    the folders the media library scans (add and remove, as in Settings > Library);
 *              only with a media library
 *   done       Finish
 *
 * Finish stores "qt-privacy-ask" = false (SettingItem saves the configuration file by itself, so
 * the onboarding is not shown again) and starts the scan of the media library, as the QWidgets
 * wizard does. The dialog can not be dismissed with Esc or a click outside: that would leave
 * "qt-privacy-ask" set and bring it back at every start. "Skip" (on every step but the last) is the
 * way out and does the same as Finish: the choices made so far were applied as they were made.
 *
 * It does not host itself anywhere: DialogHost.qml creates it and opens it.
 */
RedesignModalDialog {
    id: root

    // Properties

    //! the steps and the one shown
    readonly property OnboardingSteps steps: OnboardingSteps {
        hasMediaLibrary: MainCtx.mediaLibraryAvailable
    }

    //! the themes of the cards, drawn with their own palettes (not the one of the window)
    readonly property SystemPalette lightPalette: SystemPalette {
        objectName: "onboardingLightPalette"
        source: ColorSchemeModel.Day
        ctx: MainCtx
    }

    readonly property SystemPalette darkPalette: SystemPalette {
        objectName: "onboardingDarkPalette"
        source: ColorSchemeModel.Night
        ctx: MainCtx
    }

    //! the card of the theme in use
    readonly property string selectedKind: steps.kindFor(SettingsBridge.colorSchemes, SettingsBridge.colorSchemeIndex)

    //! "qt-accent-color"
    readonly property var accentSetting: RedesignSettings.item("qt-accent-color")

    //! "qt-privacy-ask": the setting that says the onboarding is still to be shown
    readonly property var askSetting: RedesignSettings.item("qt-privacy-ask")

    // finish() ran
    property bool _finished: false

    // Functions

    //! stores that the onboarding was seen and starts the scan of the media library
    function finish() {
        if (_finished) // a double click on Finish, during the exit transition
            return
        _finished = true
        if (askSetting)
            askSetting.value = false
        if (MainCtx.mediaLibrary)
            MainCtx.mediaLibrary.reload()
        root.close()
    }

    //! "Space\tMedia Play Pause" -> "Space, Media Play Pause"
    function keysText(hotkey) {
        const keys = String(hotkey).split("\t").filter(key => key.length > 0)
        return keys.length > 0 ? keys.join(", ") : qsTr("Not set")
    }

    // Events

    // the accent is live: the cards (their own palettes) read it again, like the shell does
    Connections {
        target: root.accentSetting

        function onValueChanged() {
            root.lightPalette.reloadAccent()
            root.darkPalette.reloadAccent()
        }
    }

    // Settings

    title: qsTr("Welcome to %1").arg(MainCtx.productName)

    bodyWidth: VLCStyle.dp(520, VLCStyle.scale)

    closePolicy: T.Popup.NoAutoClose

    // Children

    Text {
        Layout.fillWidth: true

        text: qsTr("Step %1 of %2").arg(root.steps.current + 1).arg(root.steps.steps.length)
        font.pixelSize: VLCStyle.fontSize_small
        color: root.colorContext.fg.secondary

        Accessible.ignored: true
    }

    // theme
    ColumnLayout {
        Layout.fillWidth: true

        visible: root.steps.currentStep === "theme"

        spacing: RedesignStyle.spacingS

        Text {
            Layout.fillWidth: true

            text: qsTr("Choose how it looks. You can change this later in Settings.")
            font.pixelSize: VLCStyle.fontSize_normal
            color: root.colorContext.fg.primary
            wrapMode: Text.WordWrap
        }

        // the three themes, each drawn as the window of the player
        RowLayout {
            Layout.fillWidth: true

            spacing: RedesignStyle.spacingS

            Accessible.role: Accessible.RadioButton
            Accessible.name: qsTr("Theme")

            Repeater {
                model: root.steps.themeKinds

                ThemePreviewCard {
                    required property string modelData

                    Layout.fillWidth: true
                    Layout.preferredWidth: VLCStyle.dp(150, VLCStyle.scale)

                    kind: modelData
                    text: modelData === "light" ? qsTr("Light")
                                                : (modelData === "dark" ? qsTr("Dark") : qsTr("System"))
                    selected: root.selectedKind === modelData
                    lightPalette: root.lightPalette
                    darkPalette: root.darkPalette

                    onClicked: {
                        const index = root.steps.schemeIndexFor(SettingsBridge.colorSchemes, modelData)
                        if (index >= 0)
                            SettingsBridge.colorSchemeIndex = index
                    }
                }
            }
        }

        AccentRow {
            Layout.fillWidth: true

            spec: ({})
        }
    }

    // shortcuts
    ColumnLayout {
        Layout.fillWidth: true

        visible: root.steps.currentStep === "shortcuts"

        spacing: RedesignStyle.spacingS

        Text {
            Layout.fillWidth: true

            text: qsTr("The keys you will use most. Change any of them in Settings > Controls.")
            font.pixelSize: VLCStyle.fontSize_normal
            color: root.colorContext.fg.primary
            wrapMode: Text.WordWrap
        }

        ColumnLayout {
            Layout.fillWidth: true

            spacing: RedesignStyle.spacingXS

            Accessible.role: Accessible.List
            Accessible.name: qsTr("Essential keyboard shortcuts")

            Repeater {
                model: root.steps.essentials

                RowLayout {
                    id: shortcut

                    required property var modelData

                    // read live: the keys of the configuration now
                    readonly property string keys: root.keysText(ShortcutsModel.hotkeyFor(modelData.action))

                    Layout.fillWidth: true

                    spacing: RedesignStyle.spacingM

                    Accessible.role: Accessible.ListItem
                    Accessible.name: qsTr("%1: %2").arg(modelData.label).arg(keys)

                    Text {
                        Layout.fillWidth: true

                        text: shortcut.modelData.label
                        font.pixelSize: VLCStyle.fontSize_normal
                        color: root.colorContext.fg.primary
                        elide: Text.ElideRight

                        Accessible.ignored: true
                    }

                    Text {
                        Layout.maximumWidth: VLCStyle.dp(240, VLCStyle.scale)

                        text: shortcut.keys
                        font.pixelSize: VLCStyle.fontSize_normal
                        font.bold: true
                        color: root.colorContext.fg.secondary
                        elide: Text.ElideRight

                        Accessible.ignored: true
                    }
                }
            }
        }
    }

    // privacy
    ColumnLayout {
        Layout.fillWidth: true

        visible: root.steps.currentStep === "privacy"

        spacing: RedesignStyle.spacingS

        Text {
            Layout.fillWidth: true

            text: qsTr("%1 does not collect personal data. It can fetch cover art and track information from the internet, and look for updates: you decide.").arg(MainCtx.productName)
            font.pixelSize: VLCStyle.fontSize_normal
            color: root.colorContext.fg.primary
            wrapMode: Text.WordWrap
        }

        SettingRow {
            Layout.fillWidth: true

            key: "metadata-network-access"
        }

        SettingRow {
            Layout.fillWidth: true

            key: "qt-updates-notif"
        }
    }

    // folders: by name, not by type, as in LibraryFoldersRow (the types need a media library)
    ColumnLayout {
        Layout.fillWidth: true

        visible: root.steps.currentStep === "folders"

        spacing: RedesignStyle.spacingS

        Text {
            Layout.fillWidth: true

            text: qsTr("Choose the folders %1 scans for your videos and music.").arg(MainCtx.productName)
            font.pixelSize: VLCStyle.fontSize_normal
            color: root.colorContext.fg.primary
            wrapMode: Text.WordWrap
        }

        Loader {
            Layout.fillWidth: true

            active: root.steps.hasMediaLibrary
            visible: active

            source: "LibraryFolders.qml"
        }
    }

    // done
    ColumnLayout {
        Layout.fillWidth: true

        visible: root.steps.currentStep === "done"

        spacing: RedesignStyle.spacingS

        Text {
            Layout.fillWidth: true

            text: qsTr("You are all set. Everything here can be changed later in Settings.")
            font.pixelSize: VLCStyle.fontSize_normal
            color: root.colorContext.fg.primary
            wrapMode: Text.WordWrap
        }
    }

    footerItems: [
        Widgets.ButtonExt {
            visible: !root.steps.canFinish

            text: qsTr("Skip")

            Accessible.name: qsTr("Skip the introduction")

            onClicked: root.finish()
        },
        Widgets.ButtonExt {
            visible: root.steps.current > 0

            text: qsTr("Back")

            Accessible.name: qsTr("Previous step")

            onClicked: root.steps.back()
        },
        Widgets.ButtonExt {
            visible: !root.steps.canFinish

            text: qsTr("Next")
            font.bold: true

            colorContext.colorSet: ColorContext.ButtonAccent

            Accessible.name: qsTr("Next step")

            onClicked: root.steps.next()
        },
        Widgets.ButtonExt {
            visible: root.steps.canFinish

            text: qsTr("Finish")
            font.bold: true

            colorContext.colorSet: ColorContext.ButtonAccent

            Accessible.name: qsTr("Finish the introduction")

            onClicked: root.finish()
        }
    ]
}
