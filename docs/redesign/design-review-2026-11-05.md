# Vireo design review, 2026-11-05

Build: dev build of `redesign/main` at `c54248a6cd` (rc3 plus the keyboard fixes), portable copy, fresh profile.
Window: 1280x800 unless noted, Windows 11, dark theme unless noted.
Reference: the Figma export `VLC Redesign (Community).zip` (25 PNGs: Player, Player-1, Settings global/audio, Subtitles, effect panels, right-click menu) and `docs/redesign/tokens.md`.
The Figma file is CC BY 4.0 (community page, checked 2026-11-05), which settles the open licence question for the icons cut from it: they can ship with an attribution.

Screenshots: `C:\Users\LOGIXA~1\Temp\claude\D--CODING-Ishaq-Personal-vlc-player-upgraded-UI\0e6b3cd4-ca60-4f28-a667-47d9623d95e5\scratchpad\rv\` (the names below, `.png`). The `sheet-*.png` files there group four screens each.

How it was driven: UI Automation only, no mouse. Hover, pressed and drag states were not captured. Focus states were checked earlier by keyboard and are not repeated here.

## 1. Bugs (behaviour, not taste)

| # | Where | What | Shot |
|---|---|---|---|
| B1 | (withdrawn) | **Not a bug.** The onboarding moved two steps per UI Automation press during the capture run. A traced build showed each press runs `clicked()` once, through `ButtonExt`'s `Accessible.onPressAction`, 10 presses out of 10. The extra step came from keys typed on the same PC while Vireo was the active window: since `c54248a6cd` the onboarding puts the keyboard on Next, so a typed Space or Enter presses it, as it should. The control bar Settings button and the Queue toggle that seemed dead during the same run are unconfirmed for the same reason and need one real click. | `01`..`05` |
| B2 | Main menu > Keyboard shortcuts | The dialog draws only its Close button. Title, background, filter field and the list exist in the accessibility tree but are not painted. Looks like the popup's width collapses to 0 (`KeyboardShortcutsDialog.qml`, `bodyWidth` from `T.Overlay.overlay`). Not confirmed. | `56`, `56b` |
| B3 | Main menu, window under about 700 px tall | The menu runs off the bottom with no scrolling: Keyboard shortcuts, Settings and Help can't be reached. | `72` |
| B4 | Control bar, narrow window | Volume, Subtitles, Audio, Settings, Queue and Fullscreen disappear with no overflow menu, so they can't be reached at all. | `70`, `71` |
| B5 | Videos, details view | Durations differ from the list and grid views of the same files: 00:07 vs 00:06, 00:20 vs 00:19, 00:09 vs 00:08 (rounding vs truncation). The queue says "20 sec" for a 00:19 clip. | `10` vs `09`, `29` |
| B6 | Videos grouped by folder, Continue Watching | Folder tiles show "0 ms" as their duration. rc3 showed "-1 ms" on Continue Watching cards. A duration that is unknown or a folder total should show nothing, and "ms" is never the right unit here. | `14` |
| B7 | Every page beside the queue panel | The page's vertical scrollbar is drawn as a bright white bar about 24 px wide, between the page and the queue (dark grey in light theme). | `32`..`35`, `61`, `62` |
| B8 | Pages with the queue panel open | The page isn't reflowed for the panel: "No playlists fou…" and the Network tiles are cut off under the panel. In a narrow window the queue covers the whole page. | `33`, `34`, `70` |
| B9 | Opening a video | "Resize interface to the native video size" is on by default: the window jumps from 1280x800 to the clip's size (735x551 for the test clips) every time something plays. | `15` |
| B10 | Grid tiles via assistive tech | The default action of a folder or artist tile is Play, not Open: pressing "Season 1" played the folder, pressing an artist played it. Keyboard and screen reader users can't open a folder from the grid. | `15`, `32` |
| B11 | Settings search with no results | The close button jumps from the top right corner to the middle of the right edge. | `55` |
| B12 | Rail > Recent | Shows the header "Home" and highlights Home in the rail (`HomePage.qml` serves both). The user can't tell where they are. | `35` |
| B13 | Settings > Library | "Use media library" shows OFF while the library runs: `bin/winvlc.c:138` always passes `--media-library`. The switch does nothing. | `48` |
| B14 | Onboarding step 4 | Long folder paths are not elided: the dialog grows to almost the window width (1676 px). Settings > Library elides the same paths correctly. | `04` |
| B15 | Settings > Network | The second line of "Download website playback tools" is clipped by the row below. | `49` |
| B16 | Title bar on Network, Playlists, Home | The folder crumb keeps showing the folder of what is playing ("Music", "Night Drive"), not the page shown. | `33`, `34`, `35` |
| B17 | Accessibility tree | Hidden views stay exposed: the grid tiles stay in the tree while the list view is shown, and the closed queue panel's Clear, Sort and Filter stay too. A screen reader reads each video twice. | lists in the run log |

## 2. Against the Figma design

### Title bar (Player, Player-1)
- Figma: the cone app icon, the "…" menu and the sidebar toggle at the left, the page crumb ("📁 Videos"), the window title centred, then minimise, maximise, **fullscreen**, close. Vireo: no app icon, no centred title; the library toggle and fullscreen sit right of centre, before the window buttons. Fullscreen sits between maximise and close in Figma.
- The library toggle is drawn in the accent colour while it is on. In Figma the title bar icons are all `text-default` grey, and the accent marks only the current rail item.
- The crumb shows only the folder icon in the player at 1280 px, with room for the label.

### Rail and sidebar
- Figma's expanded sidebar floats: 8 px margin, radius 6, `bg-panel` #191919, 200 px, 15 px labels. Vireo's is flush with the window, with smaller labels (about 13 px). `07`
- The active rail item is drawn in the accent colour in Figma (Playlists in `Player.png`). Vireo draws it white on a grey pill.
- Vireo has two sidebar-like toggles (top of the rail, and the accent icon in the title bar) with near-identical glyphs. Figma has one.

### Library header
- Figma order: count, sort, view, then a **search field** (about 320 px, placeholder "Search"), then more. Vireo: count, view, sort, search *icon*, more. `09`, `11`
- Figma's breadcrumb uses ▸ separators with the current item in semibold. Vireo uses `›` and the same weight. `31`
- "5 items" is 11 px `text-muted` on #0E0E0E (about 3.2:1), below AA for its size.

### Grid
- Figma tiles: 16:9, radius 10, title regular `text-title` #969696, watched items with a full-width accent bar at the bottom of the thumbnail. Vireo: a small accent wedge in the top-right corner of every unwatched tile, which reads as a rendering glitch at 100 %. `11`, `12`
- In a narrow window the 16:9 tile is squeezed into a portrait shape. `71`

### Control bar
- Figma: prev, **orange** play pill, next, time, seek track with an 8x24 accent thumb, total, a solid green volume cone, then EQ, subtitles, **gear**, queue. Vireo:
  - The play pill turns **grey** while playing, which reads as disabled. Figma keeps it accent. `20`, `22`
  - The seek thumb is a dark 2 px line, hard to see. `20`
  - The volume cone runs green to bright orange at normal volume, so it looks like overdrive. Figma is green with a slight olive shift, and orange or red belongs to more than 100 %.
  - The Settings button uses a panel glyph, not the gear.
  - Fullscreen is in the bar; Figma has it only in the title bar.

### Settings (Settings - global, Settings - audio)
- Figma has a header band: a search field at the top left in a sunken `bg-sunken` strip, the title "Global Settings" and the close X in the same strip. Vireo has no header band, the search sits above the sidebar, and the X floats at the top right. `40`
- The sidebar items have icons in Figma (sliders, cursor, shield, keyboard, play, film, waves, subtitles, folder, broadcast, gauge, record, puzzle), with the selected one's icon in the accent colour. Vireo has text only.
- Group labels: Figma "App / Media / System" in sentence case `text-muted`. Vireo "APP / MEDIA / SYSTEM" small caps.
- Pages have section headings in Figma (Appearance, Startup, Diagnostics) with no row separators. Vireo has one flat list with a hairline under each row.
- Info icons sit right after the label in Figma. In Vireo they sit left of the control, so their column moves with each control's width (three x positions on one page). `41`, `43`, `44`
- Theme and accent colour live in General > Appearance in Figma, with "Interface language" (missing in Vireo). Vireo puts them in Interface.
- Accent swatches: rounded squares in a sunken strip in Figma. Vireo uses circles.
- The selected theme segment in Figma is `accent-tint` with accent text. Vireo fills it with the accent and dark text.
- Dropdowns: Figma uses a 2 px `bg-panel` outline and regular text. Vireo uses a bright 2 px light-grey outline and bold text, so every dropdown looks focused. `43`, `45`
- "Advanced Options >" is one full-width bar at the end of the page in Figma. Vireo has three ways in: the "Advanced options / Show" row, the "Advanced" expander right below it, and "Advanced…" in the sidebar. `40`, `53`

### Track popup vs the Subtitles panel
- Figma's Subtitles is a 400 px side panel with tabs (Playback, Video, Audio, Subtitles), sync controls (delay, speed, duration factor), appearance and presets. Vireo's popup lists tracks and "Add subtitles…" only; delay and the rest live in Settings. `26`, `27`
- The effect panels (compressor, EQ, spatializer, delay, video adjust, crop, video effects) have no Vireo screen to compare. They are reached through the stock windows.

### Menus (right-click menu)
- Figma menus: `bg-popup` at 95 % alpha, radius 8, no border, an icon on every row, the shortcut right-aligned, 48 px rows. Vireo: square corners, a 1.5 px light border, no icons, no shortcuts, and taller rows on items with a submenu (54 px vs 48 px). `12`, `30`
- The selected entry in a submenu is marked with a trailing "•" ("Do not group •"). Use a leading check, as menus on Windows do. `13`

## 3. Polish (nitpicks)

### Dialogs (onboarding, network stream, shortcuts)
- Square corners. `tokens.md` gives modals about 12 to 16 px (`radiusL`), and Settings is rounded, so dialogs and Settings disagree.
- The title is 16 px bold in `text-title` grey: weaker than the body text it sits on. Use `text-heading` #C6C6C6 or `text-strong`.
- The onboarding changes width at every step (747, 1170, 1676, 600 px), so the buttons jump. Pin the width.
- "Step 1 of 5" is 12 px `text-muted` (about 3.2:1). Add a dot progress indicator, and lift the colour.
- Skip, Back and Next look the same weight apart from the accent. Put Skip at the left as a text link, away from Back and Next.
- Step 2's keys: "f" and "v" are lower case next to "Space"; draw them as keycaps. "Full screen" here, "Fullscreen" elsewhere.
- Step 3: only the second row has an info icon.
- Step 4 empty state: "Add folder" is a full-width disabled bar under the field. Once a folder is added, it becomes an inline button at the right, so the layout shifts.
- Step 5 is almost empty. A summary of the choices made would earn the step.

### Home
- Folder cards are a 32 px icon floating above two lines of text, with no card surface, unlike every other tile. `06`
- The paths show the full Windows path, truncated in the middle and ending in "\". Show the folder name, and the parent path muted.
- Section titles are in Title Case ("Frequently Visited Folders", "Continue Watching") while everything else uses sentence case ("Add item", "Create playlist").
- Each carousel row draws its scroll indicator as a 2 px light line under the row, which reads as a divider. `20`
- In the player's side panel the rows are cut at the panel edge with a fade, which looks like an artefact rather than "scroll for more". `20`

### Queue panel (upstream `PlaylistPane.qml`, not restyled)
- "1 elements, 20 sec": the plural is wrong and the time disagrees with the row (00:19).
- Clear and Save as playlist are plain text in the title's colour, with no button shape.
- The empty state "No content yet / Drag & Drop some content here!" is large and in a different voice from the rest ("No playlists found…").
- The current item shows a **pause** glyph while playing (reads as paused), or a speaker for audio. Use one "now playing" marker.
- Music rows without artwork get a **white** square placeholder in dark theme; Playlists' empty state uses a white card too. Both glare. `32`, `34`
- The column header uses a music note for the thumbnail column, also for videos. The details view of Videos does the same. `10`, `29`

### Network page
- The section titles "Folders" and "Computer" are about 26 px, twice any other page title. `33`
- The tile subtitles are `file:///C:/Users/LO…` URLs. Show a readable path, or nothing.

### Mini player
- A bare video rectangle in the bottom right corner: no title, no controls, no close, no radius or shadow. `24`

### Settings rows
- No units on numbers: "Short jump length 10", "TCP connection timeout 5000", "Subtitle delay 0", "Audio output volume step 12.8". Performance puts "(ms)" in the label; do the same everywhere, or put the unit inside the field.
- Raw sentinel values: "Subtitle track -1", "Threads 0". Show "Automatic".
- Empty fields with no placeholder: Output device (should list the devices), Audio language, Source aspect ratio, HTTP proxy, Record directory (should show the default folder).
- The Replay gain description is cut mid-word ("…levels the files that h…").
- Extensions has a bare "Username" and "Password" with no hint of what they're for.
- Long labels wrap ("Mouse wheel vertical axis control") while dropdowns take 400 px. Give the label column more room, or cap the control width (Figma: 320 px).
- Disabled "Add folder" text is close to invisible (#404040 on #1B1B1B).

### Search in Settings
- Results show "Subtitles - <long description>" cut at one line, with no count and no page grouping. The first hit is "Subtitles / Subtitles".
- The sidebar keeps "General" selected while results are shown.
- A description says "VLC partly implements this", still naming VLC. `54`

### Light theme
- The Settings modal has no edge on a light window: no shadow or border, so it merges with the page. `60`
- Muted text (counts, "Restart required", group labels) is #808080 on #FAFAFA, about 3.9:1.

### Update banner
- "An <red>error</red> occurred while checking for updates…" with a play-triangle bullet: the red word, the bullet and the ellipsis read as alarming for a non-event. Write "Couldn't check for updates" in neutral colours, or show nothing until a final release exists. `20`

## 4. Wording

Upstream strings that the Figma design rewrites, or that read badly:

| Now | Figma or suggested |
|---|---|
| Show unimportant error and warnings dialogs | Show confirmation and error dialogs (Figma) |
| Activate the updates availability notification | Check for updates automatically (Figma) |
| Log to file / Log filename / Verbosity | Save a log / Log file / Log details (Figma) |
| Ignore keyboard volume buttons. | (no full stop) |
| Play and pause (a switch) | say what it switches |
| Subtitle Frames per Second | Subtitle frames per second |
| Cookies forwarding | Send cookies with requests |
| Detach the play queue | Open the queue in its own window |
| Drag & Drop some content here! | Drop files here to play them |
| Automatic / Auto (both used) | pick one |

## 5. Not checked or set aside

- Hover, pressed and drag states, tooltips, and the right-click menu of the video (no mouse was used).
- The effect panels (not part of the redesign yet).
- "The application closed abruptly" appeared once after two overlapping launches; a clean close and restart did not bring it back.
- Grey thumbnails and the odd artist names ("IPRD", "▯IART▯") come from the test files I generated, not from Vireo.
- One start of rc3 took about 45 s to show its window; the next took 1 s. Not reproduced.
