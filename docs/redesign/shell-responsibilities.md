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

## Dropped or deferred

| Stock | Status | Owner |
|---|---|---|
| `Ctrl+F` search (`MainCtx.search.askShow()`) | dropped for now (the page headers of the library host the search box) | Task 26 (ViewHeader) |
| Touch drag on the video (`TouchDragHandler`: one finger drag sends wheel hotkeys) | not ported | R5 polish pass |
| List mode of the library page in the panel beside the video (the pages use the global `MainCtx.gridView`, which must not be flipped) | the page only gets the panel width | Task 26 (LibraryOptions view modes, CompactListView) |
| Navigation neighbours (`Navigation.*`) between panel, Stage and control bar | focus is routed by `_focusState()` only | R5 accessibility pass |
| Play queue panel (`PlaylistPane`) | `RightPanel` (mode `queue`) hosts `QueuePanel`, which reuses `PlaylistPane` as is; the Queue button (`ShellActions.queueRequested`) toggles it while `MainCtx.playqueuePanel.docked`, else shows or hides the detached window of upstream. The panel mode follows `MainCtx.playqueuePanel.visible` (Ctrl+L, saved state); the main menu has the "Docked Play Queue" toggle of the classic View menu | done (Task 24) |
| `UpdatePane` | not hosted, VLC falls back to its update dialog | settings / update task |
| `VoronoiSnow`, `interfaceScalePinchHandler` (pinch to scale) | not ported | none |
| Library header (address bar, view-mode cycle, sort, search), history forward | the panel header has back and the title | Task 26 |
