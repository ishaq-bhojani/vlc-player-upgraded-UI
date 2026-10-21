# Stock responsibilities of MainInterface / MainDisplay / Player in the redesign shell

The redesign root (`modules/gui/qt/redesign/shell/RedesignInterface.qml`) replaces `MainInterface.qml`, and since Task 21 it
no longer hosts the stock pages `MainDisplay`, `Player` and `MinimalView`. This lists what those files did, where it lives
now, and what is dropped or deferred (with the task that owns it).

## Moved into the redesign shell

| Stock | Redesign |
|---|---|
| Window background, metrics, tooltips, detached play queue window, global shortcuts, CSD resize and shadow, drop of media, two-finger swipe back | root (Task 19) |
| `viewLoader` (MinimalView / Player / MainDisplay) | `Stage` + `LibraryPanel` + `MiniPlayerCard`, selected by `ShellStates` |
| `Dialogs {}` (MainDisplay, Player) | one instance in the root |
| `FloatingNotification` | root |
| `PageLoader` `stackView` + `pageModel`, `History.onNavigate`, `ModelSortSettingHandler` | root `libraryPages` (one item, moves between the panel and the Stage); Home is the redesign `HomePage` |
| `onHasVideoOutputChanged` -> player view | root |
| Hotkeys for the keys no item took | root `Keys.onPressed` (the video does not take keyboard focus) |
| `MainCtx.askShow` (interface asked to show itself) | root: shows the bars of the immersive state |
| `Player.isInteractive` (DVD menus): mouse and keys reach the video, the pointer stays visible, `NavigationBox`, button to show the bars, no bars by pointer proximity | `Stage` (`interactiveTimer`, `NavigationBox`, show-bars button) and root (`pointerNear*` ignored, keys do not show the bars) |
| Player top bar / control bar auto hide FSM | `ShellStates` (pointer within 80 px of an edge, key activity) |
| Back button of the player (stops a video that has no surface without PIP) | `leaveToBrowse()` (title bar button, panel "Browse the library", back gesture) |
| MiniPlayer, PIPPlayer | `RedesignControlBar` (Task 22), `MiniPlayerCard` |
| Preferences (`DialogsProvider.prefsDialog()`): Ctrl+P, main menu "Settings" | the Settings modal (`settings/SettingsModal.qml`), hosted by `shell/DialogHost.qml` like the other dialogs: `ShellActions.settingsRequested(page)` (`""` = the page shown last, `"shortcuts"` = the keyboard shortcuts of Controls, which the main menu no longer uses: see the next row) opens it, `closed()` gives the keyboard back; one modal at a time. Ctrl+P is a `Shortcut` of `DialogHost`, and the root turns the stock Ctrl+P of `GlobalShortcuts.qml` off (two shortcuts of the same key are ambiguous and neither fires). The C++ entry points (`prefsDialog()` from the system tray, "Advanced..." of the modal) keep the stock QWidgets dialog | Task 34b |
| Main menu "Keyboard shortcuts" (was the Settings modal on the Controls shortcuts page) | `dialogs/KeyboardShortcutsDialog.qml`, hosted by `DialogHost` like the others: `ShellActions.keyboardShortcutsRequested()` opens it. It is only a `RedesignModalDialog` around `settings/ShortcutsPage.qml` (`showBack` and `showTitle` off), the page of Settings > Controls, so the recording (click a key, Esc cancels, Backspace removes), the conflict prompt ("%1 is already used by "%2". Replace?") and the notice for the keys the window takes itself (`util/ShellKeys.qml`: Ctrl+P and the stock `GlobalShortcuts.qml` keys; `ShortcutsModel` can not know them) exist once | Task 37 |
| "Add subtitles..." of the track popup (`DialogsProvider.loadSubtitlesFile()`, a file dialog for the media being played) | `dialogs/AddSubtitlesDialog.qml`, hosted by `DialogHost`: `ShellActions.addSubtitlesRequested(mode)` with `"current"` (a file for the media being played; the track popup sends this), `"playlist"` (the subtitles of a folder for the media of the play queue), `"folder"` (the videos of a folder are appended to the queue with their subtitles) or `""` (the dialog chooses by what plays); the mode can be changed in the dialog. Names are paired by `util/SubtitleMatch.qml` and shown for review. `SubtitleAttacher` (C++, `redesign/cpp/subtitleattacher.*`) adds the files (`AddAssociatedMedia` for the playing media, `input_item_AddSlave` for the queue items) and, with a media library, saves them (`vlc_ml_media_add_external_mrl`) on the ML thread; the library is never waited for. It also listens to the player: when a media that is in the library starts, the subtitles saved for it are added to it once the media plays (once per start, skipping those its input item already has as slaves: the input does not deduplicate; the stock `MediaToInputItem` does not read them). Remembered subtitles apply to local (`file://`) library media only. The folder is read on a worker thread (`SubtitleAttacher.requestFolder`, answer `folderListed`). Without a library the dialog works and only does not save. No QML file names a library type | Task 37 |
| Modal dialogs (`OpenNetworkStreamDialog`, `NewPlaylistDialog`, `ToolConsentDialog`, `AddSubtitlesDialog`, `KeyboardShortcutsDialog`) | based on `dialogs/RedesignModalDialog.qml`: a popup is not under the `ColorContext` of the window, so the body and the footer each have their own and the dialog only writes its body (default property) and its buttons (`footerItems`). `SettingsModal` is a bare popup with the same need and has the context in its content. The "Save as playlist" of the play queue (`QueuePanel`) opens, with a media library, a small menu: "New playlist..." (the shell's New playlist dialog, `ShellActions.newPlaylistRequested`) and "Add to existing playlist..." (`DialogsProvider.playlistsDialog`, the classic dialog); without a library it saves the queue to a file. The "Add folders" button of the empty Home page opens the Library page of the Settings modal (`settingsRequested("library")`) | Task 34b |

## Dropped or deferred

| Stock | Status | Owner |
|---|---|---|
| `Ctrl+F` search (`MainCtx.search.askShow()`) | dropped for now (the page headers of the library host the search box) | Task 26 (ViewHeader) |
| Touch drag on the video (`TouchDragHandler`: one finger drag sends wheel hotkeys) | not ported | R5 polish pass |
| List mode of the library page in the panel beside the video (the pages use the global `MainCtx.gridView`, which must not be flipped) | the page only gets the panel width | Task 26 (LibraryOptions view modes, CompactListView) |
| Navigation neighbours (`Navigation.*`) between panel, Stage and control bar | focus is routed by `_focusState()` only | R5 accessibility pass |
| Play queue panel (`PlaylistPane`) | `RightPanel` (mode `queue`) hosts `QueuePanel`, which reuses `PlaylistPane` as is; the Queue button (`ShellActions.queueRequested`) toggles it while `MainCtx.playqueuePanel.docked`, else shows or hides the detached window of upstream. The panel mode follows `MainCtx.playqueuePanel.visible` (Ctrl+L, saved state); the main menu has the "Docked Play Queue" toggle of the classic View menu | done (Task 24) |
| `UpdatePane` | `RedesignInterface` hosts the upstream `UpdatePane.qml` in a Loader named `updatePaneLoader` (the name C++ looks for, else `MainCtx::getUpdateModel` opens the modal update dialog) in a slot above the control bar, hidden in the immersive state; same activation as `MainDisplay.qml` (guarded by `typeof UpdateModel`, so builds without `UPDATE_CHECK` leave it inactive); dismissing it calls `_focusState()` | done (Task 21d) |
| `VoronoiSnow`, `interfaceScalePinchHandler` (pinch to scale) | not ported | none |
| Library header (address bar, view-mode cycle, sort, search), history forward | the panel header has back and the title | Task 26 |
