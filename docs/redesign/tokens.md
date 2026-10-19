# VLC Reborn design tokens

Status: **PROVISIONAL (PNG export)**. Source: the owner's PNG export of the Figma community file "VLC Redesign (Community)" (25 PNGs, read-only). No Figma account access was available, so every colour and metric below was measured from rendered pixels, not from the Figma Inspect panel. Re-check against Inspect when the owner has access.

How to read this file:

- **Table A** names every colour once (dark and light). Dark values are sampled; each lists the PNG and pixel coordinates (original pixel coordinates in that PNG) it was read from.
- **Table B** maps every `ColorContext` slot (colour set x section x name x state, see `modules/gui/qt/style/colorcontext.hpp`) to a Table A name, for dark and light. `@a` is an alpha (0 = transparent). The palette code in Task 5 reads this table.
- **Table C** is the 9 accent swatches. **Table D** holds spacing, radius and sizes. **Font** and **Icons** follow.
- Light values: the export has no light frame. Light values are `PROVISIONAL (derived, no light frame in export)`: each dark colour is mapped by role onto the matching entry of the upstream light palette (`SystemPalette::makeLightPalette`). Where upstream has no matching entry the derivation is stated.
- Colours that Figma does not show at all (status colours, shadow, focus ring, badge, indicator) keep the upstream value and are marked `upstream value retained`.
- WCAG contrast checks are done in Task 5, not here. Several derived light text colours are probably below 4.5:1 and will be adjusted there.

### Sampling notes (read before using the values)

1. **Sampling method.** A pure-Python PNG decoder (zlib plus filter reconstruction, 8-bit colour types 2/3/6) read exact pixel values at the listed coordinates, or the lightest/most common pixel inside a text or icon bounding box. No colour management was applied. Frames of the same colour differ by +-1 per channel across files (for example #0E0E0E vs #0F0F0F, #1B1B1B vs #1A1A1B); those were merged into the value from the highest-resolution frame.
2. **Text looks dim.** In every frame the default label and icon colour is #8F8F8F (not white), the selected row is #EAEAEA, and primary text never reaches pure white. This is the design as exported; if the owner confirms the export was dimmed (for example by a frame-level opacity), Table A text colours need to be re-sampled.
3. **Semi-transparent surfaces.** The Settings modal body, the subtitle panel and the context menu are exported at 95% alpha (alpha byte 242). Table A lists the RGB only; apply alpha 0.95 to popups, menus and modals.
4. **Frame scales.** Export scale was inferred per file from round-number evidence and font size (table below). Table D divides PNG pixels by that scale.

| PNG | Size | Inferred scale | Design frame | Evidence |
|---|---|---|---|---|
| Player.png | 7680x4320 | 4x | 1920x1080 | exact 16:9 at 1920x1080; title bar 160 px = 40, bar 220 px = 55 |
| Player-1.png | 3840x2160 | 2x | 1920x1080 | title bar 80 px = 40 (matches Player.png) |
| Player-2/3/4.png | 1056x594 | 0.55x | 1920x1080 | accent variants only; used for colour, not metrics |
| Settings - global.png, Settings - audio.png | 3234x2685 | 3x | 1078x895 | sidebar 600 px = 200, header 150 px = 50, row 120 px = 40, border 6 px = 2, body label cap height 31 px = 10.3 (14 px Inter) |
| Subtitles.png | 1600x3784 | 4x | 400x946 | panel 1600 px = 400, tab bar 192 px = 48, field 128 px = 32, border 8 px = 2 |
| Property 1=expanded*.png (effect panels) | 1440 wide | 4x | 360 wide | slider track 64 px = 16, same as Subtitles.png slider |
| right-click menu.png | 584x1366 | 2x | 292x683 | font parity: cap height 20 px = 10 (14 px Inter); 3x would give a 9 px font |
| Frame 151*.png, Frame 159*.png, small icons | 124x161, 64x64, 24x24 | 1x (assumed) | n/a | onboarding theme tiles and accent dot; colour only |

The scale for Settings, the effect panels and the menu is the least certain part of this file; they are flagged in Table D.

## Table A: colours

Every dark value is `PROVISIONAL (PNG export)`. Coordinates are pixels in the named PNG (original resolution).

| Figma colour name | Dark hex | Dark source (PNG @ x,y) | Light hex | Light provenance | Role |
|---|---|---|---|---|---|
| `bg-window` | #0E0E0E | PROVISIONAL (PNG export): Player-1.png @ 500,1900; Settings - global.png @ 1617,2425 | #FAFAFA | PROVISIONAL (derived, no light frame in export): upstream lightGrey100 (View Bg Primary) | App/modal window background (content area). Settings modal rendered at 95% alpha (242/255). |
| `bg-panel` | #191919 | PROVISIONAL (PNG export): Player-1.png @ 300,1000; Settings - global.png @ 2425,417 | #F2F2F2 | PROVISIONAL (derived, no light frame in export): upstream lightGrey300 | Floating sidebar/rail panel, dropdown, standard button, EQ panel, text-field border. Settings sidebar samples as #181818 (+-1), merged into this colour. |
| `bg-bar` | #1B1B1B | PROVISIONAL (PNG export): Player.png @ 2304,46; Player.png @ 2304,4128 | #EDEDED | PROVISIONAL (derived, no light frame in export): upstream lightGrey400 (Window Bg) | Title bar and bottom control bar. |
| `bg-sunken` | #090909 | PROVISIONAL (PNG export): Player.png @ 3072,4212; Settings - global.png @ 1617,64 | #E9E9E9 | PROVISIONAL (derived, no light frame in export): upstream lightGrey500 | Inset surfaces: seek/slider track, input field fill, tab bar, settings header, toggle outer border. |
| `bg-secondary` | #090909 | PROVISIONAL (PNG export): Player.png @ 3072,4212 | #FFFFFF | PROVISIONAL (derived, no light frame in export): upstream Qt::white (View Bg Secondary) | View "secondary" background; same dark value as bg-sunken. |
| `bg-field` | #151515 | PROVISIONAL (PNG export): Settings - global.png @ 485,80; Player-1.png @ 3130,140 | #F6F6F6 | PROVISIONAL (derived, no light frame in export): upstream lightGrey200 | Search field fill. |
| `bg-selected` | #222222 | PROVISIONAL (PNG export): Settings - global.png @ 485,423 | #E5E5E5 | PROVISIONAL (derived, no light frame in export): upstream lightGrey600 (Item Bg Highlight) | Selected / hovered list and sidebar row. |
| `bg-popup` | #181818 | PROVISIONAL (PNG export): right-click menu.png @ 200,10 | #F6F6F6 | PROVISIONAL (derived, no light frame in export): upstream lightGrey200 (Tooltip Bg) | Context menu / tooltip / dropdown list surface; rendered at 95% alpha (242/255); +-1 from bg-panel. |
| `line-separator` | #212121 | PROVISIONAL (PNG export): Player.png @ 300,578; Player-1.png @ 1500,221 | #E0E0E0 | PROVISIONAL (derived, no light frame in export): upstream separator light #E0E0E0 | 1 px hairline under headers / between sections. |
| `text-strong` | #EAEAEA | PROVISIONAL (PNG export): Settings - global.png @ 231,382 | #000000 | PROVISIONAL (derived, no light frame in export): upstream black (Item Fg Highlight) | Selected sidebar label, hovered icon, strongest text. |
| `text-heading` | #C6C6C6 | PROVISIONAL (PNG export): Settings - global.png @ 779,272 | #212121 | PROVISIONAL (derived, no light frame in export): upstream darkGrey300 (View Fg Primary) | Settings section headings ("Appearance"). |
| `text-title` | #969696 | PROVISIONAL (PNG export): Settings - global.png @ 1020,77; Player-1.png @ 483,670 | #4B4B4B | PROVISIONAL (derived, no light frame in export): upstream black@0.7 over #FAFAFA | Dialog title, file/tile names, current breadcrumb. |
| `text-default` | #8F8F8F | PROVISIONAL (PNG export): Player.png @ 722,4190; Settings - global.png @ 866,402 | #666666 | PROVISIONAL (derived, no light frame in export): upstream black@0.6 over white | Default labels, control-bar icons, field text (most common text colour in export). |
| `text-muted` | #6B6B6B | PROVISIONAL (PNG export): Player.png @ 336,444 | #808080 | PROVISIONAL (derived, no light frame in export): black@0.5 over white (no upstream equivalent) | Secondary text: counts, watched titles, inactive tabs, section group labels. |
| `text-faint` | #404040 | PROVISIONAL (PNG export): Settings - global.png @ 205,82; Settings - global.png @ 2957,1002 | #B3B3B3 | PROVISIONAL (derived, no light frame in export): upstream black@0.3 over white (disabled) | Placeholder text, disabled text, toggle OFF knob. |
| `accent` | #D37918 | PROVISIONAL (PNG export): Player.png @ 268,4185; Settings - global.png @ 2208,692 | #D37918 | PROVISIONAL (derived, no light frame in export): Figma shows one accent; WCAG check in Task 5 | Accent (default = swatch 1 orange). Play button, thumb, active icon, links. |
| `accent-dim` | #AB6314 | PROVISIONAL (PNG export): Settings - audio.png @ 894,941; right-click menu.png @ 53,43 | #AB6314 | PROVISIONAL (derived, no light frame in export) | Accent at reduced strength: slider thumbs and toggle knob in Settings, coloured menu icons. |
| `accent-tint` | #371F06 | PROVISIONAL (PNG export): Player.png @ 1152,4212; Settings - global.png @ 2263,533 | #F2E0CD | PROVISIONAL (derived, no light frame in export): accent at 20% over #FAFAFA | Filled portion of seek/slider track, selected segmented button, toggle ON track. |
| `accent-pressed` | #B76915 | PROVISIONAL (derived): accent.darker(115), not sampled | #B76915 | PROVISIONAL (derived, no light frame in export): accent.darker(115) of #D37918 (Task 5 plan: pressed = base.darker(115)) | Pressed accent button. No pressed frame in export; value is derived, not sampled. Task 5 derives it from the active accent (`AccentShades.pressed`); hover = `lighter(115)` = #F28B1C for the default accent. |
| `on-accent` | #161616 | PROVISIONAL (PNG export): Player.png @ 329,4186 | #161616 | PROVISIONAL (derived, no light frame in export): Task 5 switches black/white by WCAG | Glyph on accent fill (play icon). |
| `volume-green` | #79A512 | PROVISIONAL (PNG export): Player.png @ 6530,4212 | #79A512 | PROVISIONAL (derived, no light frame in export) | Volume cone fill. Rendered as a gradient #79A512 (left) to #869413 (x=6640); the green start colour is used for Slider Fg Positive. |
| `slider-neutral` | #9D5D00 | upstream value retained (not shown in export) | #9D5D00 | upstream value retained (not shown in export) (modules/gui/qt/style/systempalette.cpp) | Volume over 100% segment. |
| `slider-negative` | #C42B1C | upstream value retained (not shown in export) | #C42B1C | upstream value retained (not shown in export) | Volume clipping segment. |
| `status-positive-fg` | #00FF00 | upstream value retained (not shown in export) | #00FF00 | upstream value retained (not shown in export) | Qt::green. |
| `status-negative-fg` | #FF0000 | upstream value retained (not shown in export) | #FF0000 | upstream value retained (not shown in export) | Qt::red. |
| `status-positive-bg` | #008000 | upstream value retained (not shown in export) | #DFF6DD | upstream value retained (not shown in export) | Qt::darkGreen (dark) / #dff6dd (light). |
| `status-negative-bg` | #800000 | upstream value retained (not shown in export) | #FDE7E9 | upstream value retained (not shown in export) | Qt::darkRed (dark) / #fde7e9 (light). |
| `status-neutral-bg` | #808000 | upstream value retained (not shown in export) | #E4DAB8 | upstream value retained (not shown in export) | Qt::darkYellow (dark) / #e4dab8 (light). |
| `indicator` | #666666 | upstream value retained (not shown in export) | #9E9E9E | upstream value retained (not shown in export) | Item indicator (active marker). |
| `inverse-surface` | #FFFFFF | upstream value retained (not shown in export) | #000000 | upstream value retained (not shown in export) | Overlay/badge/focus-ring colour that inverts with the theme (white in dark, black in light). |
| `inverse-on` | #000000 | upstream value retained (not shown in export) | #FFFFFF | upstream value retained (not shown in export) | Foreground on inverse-surface (badge text). |
| `shadow-color` | #000000 | upstream value retained (not shown in export) | #000000 | upstream value retained (not shown in export) | Drop shadow (applied at alpha 0.22). |

Colours seen in the export but not given a name because they are content, not UI: video letterbox #2C2A28/#2D2B29 (Player.png), thumbnail letterbox #000000 (Player-1.png), subtitle colour swatch values #B8B8B8 and #0C0C0C (Subtitles.png).

Not shown in the export and therefore not in Table A: hover, pressed (other than the derived `accent-pressed`) and focus states of any control, error/warning banners, scrollbars, the drop shadow colour. Table B keeps the upstream behaviour for these.

## Table B: ColorContext slots

Columns: Dark and Light give the Table A name (with `@alpha` where not 1). The `Origin` column says how the row was produced:

- `set`: upstream `makeDarkPalette()`/`makeLightPalette()` sets this slot; the Figma colour replaces the value.
- `fallback`: upstream does not set this slot (it resolves through `SystemPalette::getColor` to the Normal state or to the View set); the row repeats the View value explicitly so no cell is empty.
- `new`: slot upstream does not set, added because the design needs it.

States not listed for a slot fall back to its Normal row (that is how `SystemPalette::getColor` resolves them). Counts: 133 rows (108 set, 20 fallback, 5 new). Every slot set by either upstream palette function is present; the 15 colour sets each have Fg and Bg Primary and Secondary Normal rows.

Slot decisions the table cannot show on its own:

- `Item`: Fg Primary = `text-title` (tile and row names), Fg Secondary = `text-muted` (watched or count text), Fg Highlight = `text-strong` (selected row).
- `Slider`: Bg Primary = track, Fg Primary = filled portion (`accent-tint`, as in the Figma seek bar). The slider thumb is drawn with `Decoration Accent` (View) = `accent`. Fg Positive is the volume cone green.
- `Switch`: Bg Primary = OFF label area, Fg Primary = OFF knob, Bg Secondary = ON knob (`accent-dim`), Fg Secondary = ON label text (`accent`), Decoration Border = outer border, Decoration Accent (new) = ON track (`accent-tint`).
- `TextField`/`SpinBox`: Decoration Border Normal is the 2 px `bg-panel` outline Figma draws around the sunken `bg-sunken` fill.
- Light differs from dark in two places by design: the slider fill and the switch ON state use the full `accent` in light (the dark 20% tint would be nearly invisible on a light track), with a white knob and `on-accent` label. Both are `PROVISIONAL (derived, no light frame in export)`.
- Slots Figma does not draw (View borders, focus ring, shadow, disabled accent button, badge) keep the upstream alpha scheme on `inverse-surface`, which is white in dark and black in light.

| ColorSet | Section | Name | State | Dark (Table A name) | Dark hex | Light (Table A name) | Light hex | Origin |
|---|---|---|---|---|---|---|---|---|
| View | Bg | Primary | Normal | `bg-window` | #0E0E0E | `bg-window` | #FAFAFA | set |
| View | Bg | Secondary | Normal | `bg-secondary` | #090909 | `bg-secondary` | #FFFFFF | set |
| View | Fg | Primary | Normal | `text-default` | #8F8F8F | `text-default` | #666666 | set |
| View | Fg | Primary | Disabled | `text-faint` | #404040 | `text-faint` | #B3B3B3 | set |
| View | Fg | Secondary | Normal | `text-muted` | #6B6B6B | `text-muted` | #808080 | set |
| View | Bg | Negative | Normal | `status-negative-bg` | #800000 | `status-negative-bg` | #FDE7E9 | set |
| View | Fg | Negative | Normal | `status-negative-fg` | #FF0000 | `status-negative-fg` | #FF0000 | set |
| View | Bg | Neutral | Normal | `status-neutral-bg` | #808000 | `status-neutral-bg` | #E4DAB8 | set |
| View | Fg | Neutral | Normal | `accent` | #D37918 | `accent` | #D37918 | set |
| View | Bg | Positive | Normal | `status-positive-bg` | #008000 | `status-positive-bg` | #DFF6DD | set |
| View | Fg | Positive | Normal | `status-positive-fg` | #00FF00 | `status-positive-fg` | #00FF00 | set |
| View | Decoration | VisualFocus | Normal | `inverse-surface @0` | #FFFFFF@0 | `inverse-surface @0` | #000000@0 | set |
| View | Decoration | VisualFocus | Focused | `inverse-surface` | #FFFFFF | `inverse-surface` | #000000 | set |
| View | Decoration | Border | Normal | `inverse-surface @0.4` | #FFFFFF@0.4 | `inverse-surface @0.4` | #000000@0.4 | set |
| View | Decoration | Border | Focused | `inverse-surface @0.7` | #FFFFFF@0.7 | `inverse-surface @0.7` | #000000@0.7 | set |
| View | Decoration | Border | Hovered | `inverse-surface @0.7` | #FFFFFF@0.7 | `inverse-surface @0.7` | #000000@0.7 | set |
| View | Decoration | Border | Disabled | `inverse-surface @0` | #FFFFFF@0 | `inverse-surface @0` | #000000@0 | set |
| View | Decoration | Shadow | Normal | `shadow-color @0.22` | #000000@0.22 | `shadow-color @0.22` | #000000@0.22 | set |
| View | Decoration | Separator | Normal | `line-separator` | #212121 | `line-separator` | #E0E0E0 | set |
| View | Decoration | Accent | Normal | `accent` | #D37918 | `accent` | #D37918 | set |
| View | Fg | Link | Normal | `accent` | #D37918 | `accent` | #D37918 | set |
| Window | Bg | Primary | Normal | `bg-bar` | #1B1B1B | `bg-bar` | #EDEDED | set |
| Window | Bg | Secondary | Normal | `bg-bar` | #1B1B1B | `bg-bar` | #EDEDED | set |
| Window | Decoration | Border | Normal | `line-separator` | #212121 | `line-separator` | #E0E0E0 | set |
| Window | Fg | Primary | Normal | `text-default` | #8F8F8F | `text-default` | #666666 | fallback |
| Window | Fg | Secondary | Normal | `text-muted` | #6B6B6B | `text-muted` | #808080 | fallback |
| Badge | Bg | Primary | Normal | `inverse-surface @0.8` | #FFFFFF@0.8 | `inverse-surface @0.6` | #000000@0.6 | set |
| Badge | Fg | Primary | Normal | `inverse-on` | #000000 | `inverse-on` | #FFFFFF | set |
| Badge | Bg | Secondary | Normal | `bg-secondary` | #090909 | `bg-secondary` | #FFFFFF | fallback |
| Badge | Fg | Secondary | Normal | `text-muted` | #6B6B6B | `text-muted` | #808080 | fallback |
| TabButton | Bg | Primary | Normal | `bg-selected @0` | #222222@0 | `bg-selected @0` | #E5E5E5@0 | set |
| TabButton | Bg | Primary | Focused | `bg-selected` | #222222 | `bg-selected` | #E5E5E5 | set |
| TabButton | Bg | Primary | Hovered | `bg-selected` | #222222 | `bg-selected` | #E5E5E5 | set |
| TabButton | Fg | Primary | Normal | `text-muted` | #6B6B6B | `text-muted` | #808080 | set |
| TabButton | Fg | Primary | Focused | `text-default` | #8F8F8F | `text-default` | #666666 | set |
| TabButton | Fg | Primary | Hovered | `text-default` | #8F8F8F | `text-default` | #666666 | set |
| TabButton | Fg | Primary | Disabled | `text-faint` | #404040 | `text-faint` | #B3B3B3 | set |
| TabButton | Fg | Secondary | Normal | `text-default` | #8F8F8F | `text-default` | #666666 | set |
| TabButton | Bg | Secondary | Normal | `bg-secondary` | #090909 | `bg-secondary` | #FFFFFF | fallback |
| ToolButton | Bg | Primary | Normal | `bg-sunken @0` | #090909@0 | `bg-sunken @0` | #E9E9E9@0 | set |
| ToolButton | Bg | Secondary | Normal | `bg-sunken` | #090909 | `bg-sunken` | #E9E9E9 | set |
| ToolButton | Fg | Primary | Normal | `text-default` | #8F8F8F | `text-default` | #666666 | set |
| ToolButton | Fg | Primary | Focused | `text-strong` | #EAEAEA | `text-strong` | #000000 | set |
| ToolButton | Fg | Primary | Hovered | `text-strong` | #EAEAEA | `text-strong` | #000000 | set |
| ToolButton | Fg | Primary | Disabled | `text-faint` | #404040 | `text-faint` | #B3B3B3 | set |
| ToolButton | Fg | Secondary | Normal | `text-strong` | #EAEAEA | `text-strong` | #000000 | set |
| ToolButton | Decoration | Border | Normal | `bg-sunken @0` | #090909@0 | `bg-sunken @0` | #E9E9E9@0 | set |
| ToolButton | Decoration | Border | Focused | `bg-sunken @0` | #090909@0 | `bg-sunken @0` | #E9E9E9@0 | set |
| ToolButton | Decoration | Border | Hovered | `bg-sunken @0` | #090909@0 | `bg-sunken @0` | #E9E9E9@0 | set |
| ToolButton | Decoration | Border | Disabled | `bg-sunken @0` | #090909@0 | `bg-sunken @0` | #E9E9E9@0 | set |
| MenuBar | Bg | Primary | Normal | `bg-selected @0` | #222222@0 | `bg-selected @0` | #E5E5E5@0 | set |
| MenuBar | Bg | Primary | Focused | `bg-selected` | #222222 | `bg-selected` | #E5E5E5 | set |
| MenuBar | Bg | Primary | Hovered | `bg-selected` | #222222 | `bg-selected` | #E5E5E5 | set |
| MenuBar | Fg | Primary | Normal | `text-default` | #8F8F8F | `text-default` | #666666 | set |
| MenuBar | Fg | Primary | Disabled | `text-faint` | #404040 | `text-faint` | #B3B3B3 | set |
| MenuBar | Bg | Secondary | Normal | `bg-secondary` | #090909 | `bg-secondary` | #FFFFFF | fallback |
| MenuBar | Fg | Secondary | Normal | `text-muted` | #6B6B6B | `text-muted` | #808080 | fallback |
| Item | Bg | Primary | Normal | `bg-selected @0` | #222222@0 | `bg-selected @0` | #E5E5E5@0 | set |
| Item | Bg | Primary | Focused | `bg-selected @0.5` | #222222@0.5 | `bg-selected @0.5` | #E5E5E5@0.5 | set |
| Item | Bg | Primary | Hovered | `bg-selected @0.5` | #222222@0.5 | `bg-selected @0.5` | #E5E5E5@0.5 | set |
| Item | Bg | Highlight | Normal | `bg-selected` | #222222 | `bg-selected` | #E5E5E5 | set |
| Item | Bg | Highlight | Focused | `bg-selected @0.8` | #222222@0.8 | `bg-selected @0.8` | #E5E5E5@0.8 | set |
| Item | Bg | Highlight | Hovered | `bg-selected @0.8` | #222222@0.8 | `bg-selected @0.8` | #E5E5E5@0.8 | set |
| Item | Fg | Highlight | Normal | `text-strong` | #EAEAEA | `text-strong` | #000000 | set |
| Item | Fg | Primary | Normal | `text-title` | #969696 | `text-title` | #4B4B4B | set |
| Item | Fg | Secondary | Normal | `text-muted` | #6B6B6B | `text-muted` | #808080 | set |
| Item | Decoration | Indicator | Normal | `indicator` | #666666 | `indicator` | #9E9E9E | set |
| Item | Bg | Secondary | Normal | `bg-secondary` | #090909 | `bg-secondary` | #FFFFFF | fallback |
| ButtonAccent | Bg | Primary | Normal | `accent` | #D37918 | `accent` | #D37918 | set |
| ButtonAccent | Bg | Primary | Pressed | `accent-pressed` | #B76915 | `accent-pressed` | #B76915 | set |
| ButtonAccent | Bg | Primary | Disabled | `inverse-surface @0.2` | #FFFFFF@0.2 | `inverse-surface @0.2` | #000000@0.2 | set |
| ButtonAccent | Fg | Primary | Normal | `on-accent` | #161616 | `on-accent` | #161616 | set |
| ButtonAccent | Fg | Primary | Disabled | `inverse-surface @0.3` | #FFFFFF@0.3 | `inverse-surface @0.3` | #000000@0.3 | set |
| ButtonAccent | Decoration | Border | Normal | `accent @0` | #D37918@0 | `accent @0` | #D37918@0 | set |
| ButtonAccent | Decoration | Border | Focused | `accent @0` | #D37918@0 | `accent @0` | #D37918@0 | set |
| ButtonAccent | Decoration | Border | Hovered | `accent @0` | #D37918@0 | `accent @0` | #D37918@0 | set |
| ButtonAccent | Decoration | Border | Disabled | `accent @0` | #D37918@0 | `accent @0` | #D37918@0 | set |
| ButtonAccent | Bg | Secondary | Normal | `bg-secondary` | #090909 | `bg-secondary` | #FFFFFF | fallback |
| ButtonAccent | Fg | Secondary | Normal | `text-muted` | #6B6B6B | `text-muted` | #808080 | fallback |
| ButtonStandard | Bg | Primary | Normal | `bg-panel` | #191919 | `bg-panel` | #F2F2F2 | set |
| ButtonStandard | Fg | Primary | Normal | `text-default` | #8F8F8F | `text-default` | #666666 | set |
| ButtonStandard | Fg | Primary | Focused | `text-strong` | #EAEAEA | `text-strong` | #000000 | set |
| ButtonStandard | Fg | Primary | Hovered | `text-strong` | #EAEAEA | `text-strong` | #000000 | set |
| ButtonStandard | Fg | Primary | Disabled | `text-faint` | #404040 | `text-faint` | #B3B3B3 | set |
| ButtonStandard | Decoration | Border | Normal | `bg-panel @0` | #191919@0 | `bg-panel @0` | #F2F2F2@0 | set |
| ButtonStandard | Decoration | Border | Focused | `bg-panel @0` | #191919@0 | `bg-panel @0` | #F2F2F2@0 | set |
| ButtonStandard | Decoration | Border | Hovered | `bg-panel @0` | #191919@0 | `bg-panel @0` | #F2F2F2@0 | set |
| ButtonStandard | Decoration | Border | Disabled | `bg-panel @0` | #191919@0 | `bg-panel @0` | #F2F2F2@0 | set |
| ButtonStandard | Bg | Secondary | Normal | `bg-secondary` | #090909 | `bg-secondary` | #FFFFFF | fallback |
| ButtonStandard | Fg | Secondary | Normal | `text-muted` | #6B6B6B | `text-muted` | #808080 | fallback |
| Tooltip | Bg | Primary | Normal | `bg-popup` | #181818 | `bg-popup` | #F6F6F6 | set |
| Tooltip | Fg | Primary | Normal | `text-strong` | #EAEAEA | `text-strong` | #000000 | set |
| Tooltip | Bg | Secondary | Normal | `bg-secondary` | #090909 | `bg-secondary` | #FFFFFF | fallback |
| Tooltip | Fg | Secondary | Normal | `text-muted` | #6B6B6B | `text-muted` | #808080 | fallback |
| Slider | Bg | Primary | Normal | `bg-sunken` | #090909 | `bg-sunken` | #E9E9E9 | set |
| Slider | Bg | Primary | Focused | `bg-sunken` | #090909 | `bg-sunken` | #E9E9E9 | set |
| Slider | Bg | Primary | Hovered | `bg-sunken` | #090909 | `bg-sunken` | #E9E9E9 | set |
| Slider | Bg | Secondary | Normal | `bg-sunken` | #090909 | `bg-sunken` | #E9E9E9 | set |
| Slider | Fg | Primary | Normal | `accent-tint` | #371F06 | `accent` | #D37918 | set |
| Slider | Fg | Positive | Normal | `volume-green` | #79A512 | `volume-green` | #79A512 | set |
| Slider | Fg | Neutral | Normal | `slider-neutral` | #9D5D00 | `slider-neutral` | #9D5D00 | set |
| Slider | Fg | Negative | Normal | `slider-negative` | #C42B1C | `slider-negative` | #C42B1C | set |
| Slider | Fg | Secondary | Normal | `text-muted` | #6B6B6B | `text-muted` | #808080 | fallback |
| ComboBox | Fg | Primary | Normal | `text-default` | #8F8F8F | `text-default` | #666666 | set |
| ComboBox | Bg | Primary | Normal | `bg-panel` | #191919 | `bg-panel` | #F2F2F2 | set |
| ComboBox | Bg | Secondary | Normal | `bg-popup` | #181818 | `bg-popup` | #F6F6F6 | set |
| ComboBox | Fg | Secondary | Normal | `text-muted` | #6B6B6B | `text-muted` | #808080 | fallback |
| TextField | Decoration | Border | Normal | `bg-panel` | #191919 | `bg-panel` | #F2F2F2 | set |
| TextField | Decoration | Border | Focused | `accent` | #D37918 | `accent` | #D37918 | set |
| TextField | Decoration | Border | Hovered | `text-faint` | #404040 | `text-faint` | #B3B3B3 | set |
| TextField | Decoration | Border | Disabled | `bg-panel @0` | #191919@0 | `bg-panel @0` | #F2F2F2@0 | set |
| TextField | Bg | Highlight | Normal | `accent-tint` | #371F06 | `accent-tint` | #F2E0CD | set |
| TextField | Fg | Highlight | Normal | `text-strong` | #EAEAEA | `text-strong` | #000000 | set |
| TextField | Bg | Primary | Normal | `bg-sunken` | #090909 | `bg-sunken` | #E9E9E9 | new |
| TextField | Fg | Primary | Normal | `text-default` | #8F8F8F | `text-default` | #666666 | new |
| TextField | Bg | Secondary | Normal | `bg-secondary` | #090909 | `bg-secondary` | #FFFFFF | fallback |
| TextField | Fg | Secondary | Normal | `text-muted` | #6B6B6B | `text-muted` | #808080 | fallback |
| SpinBox | Decoration | Border | Normal | `bg-panel` | #191919 | `bg-panel` | #F2F2F2 | set |
| SpinBox | Decoration | Border | Focused | `accent` | #D37918 | `accent` | #D37918 | set |
| SpinBox | Decoration | Border | Hovered | `text-faint` | #404040 | `text-faint` | #B3B3B3 | set |
| SpinBox | Decoration | Border | Disabled | `bg-panel @0` | #191919@0 | `bg-panel @0` | #F2F2F2@0 | set |
| SpinBox | Bg | Highlight | Normal | `accent-tint` | #371F06 | `accent-tint` | #F2E0CD | set |
| SpinBox | Fg | Highlight | Normal | `text-strong` | #EAEAEA | `text-strong` | #000000 | set |
| SpinBox | Bg | Primary | Normal | `bg-sunken` | #090909 | `bg-sunken` | #E9E9E9 | new |
| SpinBox | Fg | Primary | Normal | `text-default` | #8F8F8F | `text-default` | #666666 | new |
| SpinBox | Bg | Secondary | Normal | `bg-secondary` | #090909 | `bg-secondary` | #FFFFFF | fallback |
| SpinBox | Fg | Secondary | Normal | `text-muted` | #6B6B6B | `text-muted` | #808080 | fallback |
| Switch | Bg | Primary | Normal | `bg-panel` | #191919 | `bg-panel` | #F2F2F2 | set |
| Switch | Fg | Primary | Normal | `text-faint` | #404040 | `text-faint` | #B3B3B3 | set |
| Switch | Decoration | Border | Normal | `bg-sunken` | #090909 | `bg-sunken` | #E9E9E9 | set |
| Switch | Bg | Secondary | Normal | `accent-dim` | #AB6314 | `inverse-on` | #FFFFFF | set |
| Switch | Fg | Secondary | Normal | `accent` | #D37918 | `on-accent` | #161616 | set |
| Switch | Decoration | Accent | Normal | `accent-tint` | #371F06 | `accent` | #D37918 | new |

## Table C: accent swatches

Order is the Figma order in `Settings - global.png` (Accent colour row, left to right). Default accent = swatch 1 (Orange, #D37918), which is also the play-button colour in `Player.png`.

**Code uses one column: "Swatch value (code uses this)".** `redesign::accentSwatches()` (Task 5) returns these nine values in this order and `defaultAccent()` returns swatch 1. This is the accent the user gets when the swatch is picked, i.e. the colour drawn on the play button and thumbs. The last column is only the picker preview as drawn in the Settings frame, where unselected swatches are dimmed; do not use it as a value.

How the values were obtained: swatch 1 is the selected swatch, drawn at full strength, and equals the play button in `Player.png`. Swatches 7, 8 and 9 (purple, pink, grey) are measured on the play button in `Player-2.png`, `Player-3.png` and `Player-4.png` (pixel 38,574). Swatches 2-6 have no player frame; they are un-dimmed from the drawn swatch with `(drawn - 0.3*9) / 0.7` per channel, which assumes the inactive swatches are drawn at about 70% opacity over the sampled #090909 background. That assumption reproduces swatches 7-9 to within 1 per channel, but swatches 2-6 remain `PROVISIONAL (derived)`.

| # | Name | Swatch value (code uses this) | Source of the value | Picker preview as drawn (inactive state, Settings frame) | Drawn swatch sampled at (x,y) |
|---|---|---|---|---|---|
| 1 | Orange | #D37918 | Player.png play button @ 268,4185; equals the drawn swatch (selected state, full strength) | #D37918 | 2208,692 in Settings - global.png |
| 2 | Red | #E15032 | PROVISIONAL (derived): un-dimmed from the drawn swatch, assumes 70% opacity over #090909 | #A03B26 | 2315,692 in Settings - global.png |
| 3 | Gold | #C49F23 | PROVISIONAL (derived): un-dimmed from the drawn swatch, assumes 70% opacity over #090909 | #8C721B | 2422,692 in Settings - global.png |
| 4 | Green | #19A235 | PROVISIONAL (derived): un-dimmed from the drawn swatch, assumes 70% opacity over #090909 | #147428 | 2528,692 in Settings - global.png |
| 5 | Teal | #19AAD4 | PROVISIONAL (derived): un-dimmed from the drawn swatch, assumes 70% opacity over #090909 | #147A97 | 2635,692 in Settings - global.png |
| 6 | Blue | #195DD4 | PROVISIONAL (derived): un-dimmed from the drawn swatch, assumes 70% opacity over #090909 | #144497 | 2742,692 in Settings - global.png |
| 7 | Purple | #8E42FF | PROVISIONAL (PNG export): measured, Player-2.png @ 38,574 | #6631B5 | 2849,692 in Settings - global.png |
| 8 | Pink | #F052B3 | PROVISIONAL (PNG export): measured, Player-3.png @ 38,574 | #AB3C80 | 2955,692 in Settings - global.png |
| 9 | Grey | #AFAFAF | PROVISIONAL (PNG export): measured, Player-4.png @ 38,574 | #7E7E7E | 3062,692 in Settings - global.png |

Accent shades follow the Task 5 plan: hover = `base.lighter(115)`, pressed = `base.darker(115)`; the text colour on accent is chosen at runtime by WCAG contrast (Task 5).

Other accent-related colours seen: `accent-dim` #AB6314 (Settings sliders, toggle knob, menu icons) is the default swatch value #D37918 at about 80% strength over the panel; `accent-tint` #371F06 is a 20% tint of the same swatch value used for selected backgrounds and filled tracks. With a non-default swatch value both must be derived from the active accent (Task 5).

## Table D: spacing, radius, sizes

All values are design pixels = PNG pixels / scale (scale per file in the table above). All are `PROVISIONAL (PNG export)`. A "+-" means the edge anti-aliasing leaves one source pixel of doubt. Radii come from the inset of the first pixel row of the corner (r ~ first_inset + sqrt(first_inset)) and are +-1 px.

| Token | Value (design px) | Source PNG | Scale | Measurement |
|---|---|---|---|---|
| Title bar height | 40 | Player.png, Player-1.png | 4x / 2x | rows 0..159 at 4x = 160 px |
| Control bar height | 55 | Player.png | 4x | bar starts at y=4100, frame ends 4320 |
| Control bar: play button | 54 x 28, radius 7 | Player.png | 4x | x 232..447, y 4156..4267; first inset 23 px |
| Control bar: item row height / seek track height | 28 (outer), 24 (inner fill) | Player.png | 4x | track y 4156..4267 = 112 px; 2 px #090909 border around the fill |
| Seek track extent | x 254 to 1492 (1238 wide), radius 7 | Player.png | 4x | x 1016..5967 |
| Seek thumb | 8 x 24, radius 4 | Player.png | 4x | x 1384..1415 = 32 px; y 4164..4259 |
| Volume cone | 64 wide, 12.5 tall at narrow end, 25 tall at wide end | Player.png | 4x | x 6613..6867; y 4187..4236 (left), 4163..4260 (right) |
| Control bar icons | ink 17 to 22 wide (24 px icon box) | Player.png | 4x | queue 70 px, settings 74 px, subtitles 88 px |
| Left rail width | 50 | Player.png | 4x | x 0..199 |
| Library panel width (rail layout) | 377 (x 50..427) | Player.png | 4x | x 200..1707 |
| Rail icon ink | 18 x 17.5 | Player.png | 4x | home icon bbox 72 x 70 px |
| Library list row pitch | 42 | Player.png | 4x | rows "Create playlist" / "Cool Songs" / "Anime to Watch" |
| Separator thickness | 1 | Player.png, Player-1.png | 4x / 2x | 4 px / 2 px |
| Window margin around floating sidebar | 8 | Player-1.png | 2x | sidebar x 16..417, y 96..2143 |
| Floating sidebar width / radius | 200 / 6 | Player-1.png | 2x | x 16..417; first inset 8 px |
| Sidebar item pitch | 46 | Player-1.png | 2x | Home y 79 / Videos y 127 in 2000 px preview |
| Grid tile (16:9 thumbnail) | 315 x 177.5, radius 10 | Player-1.png | 2x | x 475..1104, y 262..616; first inset 17 px |
| Grid gap (column and row) | 20 | Player-1.png | 2x | x 1105..1146 gap = 40 px |
| Library header rule position | 110 from top of frame (1 px) | Player-1.png | 2x | y 221..222 |
| Settings modal size (without shadow) | 1048 x 865 | Settings - global.png | 3x | x 45..3188, y 21..2615; shadow margin about 7 px |
| Settings modal radius | about 12 to 18 (uncertain) | Settings - global.png | 3x | corner row inset noisy because of the shadow |
| Settings modal inner padding | 8 | Settings - global.png | 3x | 24 px gap between modal edge and header/sidebar |
| Settings header height | 50 | Settings - global.png | 3x | y 21..170 = 150 px; fill bg-sunken |
| Settings search field | 200 wide x 34 tall, radius 8, 8 inset | Settings - global.png | 3x | x 69..668, y 45..146; first inset 13 px |
| Settings sidebar panel | 200 wide, radius 8 | Settings - global.png | 3x | x 69..668 |
| Settings sidebar row | 188 x 40, radius 2, row pitch 48, side inset 6 | Settings - global.png | 3x | selected row x 87..650, y 336..455; pitch 144 px; first inset 3 px |
| Settings content left padding | 32 | Settings - global.png | 3x | sidebar edge x 668 to label x 766 |
| Settings content right padding | 24 | Settings - global.png | 3x | control right edge 3116, modal edge 3188 |
| Settings row pitch | 46 | Settings - global.png | 3x | labels at y 417 / 556 / 694 |
| Control outer border (dropdown, toggle, segmented) | 2, colour bg-sunken | Settings - global.png | 3x | 6 px border around 96 px fill |
| Dropdown / text field | 320 wide x 36 outer (32 inner), inner radius 4 to 5 | Settings - global.png | 3x | x 2157..3116; y 363..470; inner first inset 8 px |
| Segmented control (theme) | 320 wide, 3 segments 104 x 32, gap 2 | Settings - global.png | 3x | segments 312 px, gaps 6 px |
| Accent swatch | 20 x 20, radius 3; selected tile 32 x 32; pitch 36 | Settings - global.png | 3x | swatch 58x60, tile 94x96, pitch 107 px |
| Toggle | 68 x 32 outer (26 inner), knob 26 wide | Settings - global.png | 3x | x 2913..3116, y 954..1049; knob 78 px |
| Browse button | 100 wide | Settings - global.png | 3x | x 2817..3116 |
| Advanced Options bar | 784 x 38, radius 2 | Settings - global.png | 3x | x 765..3116, y 1956..2069 |
| Subtitles panel width | 400 | Subtitles.png | 4x | 1600 px |
| Subtitles tab bar | 48 + 2 accent underline | Subtitles.png | 4x | y 0..191, underline y 192..199 |
| Subtitles field height | 32 | Subtitles.png | 4x | field y 432..559 |
| Slider track (Subtitles, effects) | 16 outer, 12 inner, 2 border | Subtitles.png, Property 1=expanded.png | 4x | y 1300..1363 = 64 px, fill 48 px |
| Slider thumb (Subtitles) | 8 wide x 24 tall | Subtitles.png | 4x | x 508..539 = 32 px, y 1284..1379 = 96 px |
| Subtitles panel radius | about 8 | Subtitles.png | 4x | first inset 28 px |
| Effect panel radius | about 4 to 5 | Property 1=expanded.png | 4x | first inset 14 px |
| Context menu width / row pitch / radius | 292 / 48 / about 8 | right-click menu.png | 2x | rows at 96 px pitch; first inset 11 px |
| Font size: Player frames body | about 15 (cap height 11.25) | Player.png | 4x | digit height 45 px of "00:02:10" |
| Font size: Settings body / heading / small | 14 / 16 / 12 | Settings - global.png | 3x | cap height of "I" = 31 px; heading "A" = 35 px; "OFF" "O" = 27 px |
| Font size: menu and subtitle panel body | about 13 to 14 | right-click menu.png, Subtitles.png | 2x / 4x | cap heights 20 px at 2x, 38 px at 4x |

Spacing scale in use across frames: 2, 4, 8, 12, 16, 20, 24, 32, 40, 48 (the smallest steps are borders and gaps, 8 is the dominant padding).

### Values for `RedesignStyle` and `VLCStyle` (Task 4 and Task 9 copy from here)

Task 4 defines `RedesignStyle` properties with these names; Task 9 sets the three `VLCStyle` radii and the control bar height. Values are design px (before `MainCtx.dp`). All `PROVISIONAL (PNG export)` unless marked.

| Property | Value | Basis |
|---|---|---|
| `spacingXS` | 4 | PROVISIONAL (rounded): borders and hairline gaps of 2 to 4 px recur (slider border 2, toggle gap 2, 4 px control insets) |
| `spacingS` | 8 | dominant padding: Settings modal inner padding 8, Player-1 window margin 8, sidebar row inset 6 to 8 |
| `spacingM` | 16 | PROVISIONAL (rounded from observed 12/16/20 gaps; not a single measured value) |
| `spacingL` | 24 | Settings content right padding 24, 24 px section gaps |
| `spacingXL` | 32 | Settings content left padding 32, field height 32 |
| `radiusS` | 4 | slider thumb 4, inner dropdown/field radius about 4 to 5, swatch 3 |
| `radiusM` | 8 | search field 8, sidebar panels 6 to 8, context menu 8, subtitle panel 8, play button 7 |
| `radiusL` | 16 | modal about 12 to 18 (uncertain), grid tile 10 is between M and L and is exposed separately as `gridCover_radius` |
| `controlBarHeight` | 55 | Player.png |
| `railWidthCollapsed` | 50 | Player.png rail |
| `railWidthExpanded` | 200 | Player-1.png floating sidebar with labels |
| `panelWidthDefault` | 377 | Player.png library panel (x 50..427) |
| `panelWidthMin` | 300 | NOT MEASURED: no frame shows resize limits. Proposed value, owner to confirm |
| `panelWidthMax` | 480 | NOT MEASURED. Proposed value, owner to confirm |
| `VLCStyle.button_radius` | 7 | Player.png play button |
| `VLCStyle.gridCover_radius` | 10 | Player-1.png grid tile |
| `VLCStyle.navBoxButton_radius` | 2 | Settings sidebar selected row (no selected nav item appears in Player/Player-1); PROVISIONAL |
| control bar height (`VLCStyle`) | 55 | Player.png |

Uncertainty: the Settings frame body text (14 px at 3x) is smaller than the Player frame text (about 15 px at 4x). If the owner confirms the Settings frame was authored at a different base scale than assumed, divide every Settings and effect-panel row above by the same factor. The Player and Player-1 numbers rest on an exact 1920x1080 frame and are the safest ones.

## Font

- Family: **Inter** (SIL OFL 1.1). Visible in every frame, and the Subtitles frame lists "Inter" as the subtitle font.
- Weights bundled: Regular (400), Medium (500), SemiBold (600). Regular is the body weight; Medium appears on headings and selected rows; SemiBold on the Browse button label. The weight split is judged by eye from the PNGs, since the export carries no font metadata.
- Files: `modules/gui/qt/redesign/assets/fonts/Inter-Regular.ttf`, `Inter-Medium.ttf`, `Inter-SemiBold.ttf` (static TTFs from Inter 4.1, `extras/ttf/` of https://github.com/rsms/inter/releases/tag/v4.1) and `OFL.txt` (Inter's LICENSE.txt, SIL OFL 1.1).
- Sizes: see the last three rows of Table D. VLC keeps its own size steps in `VLCStyle`; map them to these when Task 6 runs.

## Icons

All glyphs of the icon font (`modules/gui/qt/pixmaps/VLCIcons.json`, generated into `VLCIcons.ttf` and `style/vlcicons.*` by `makeIconFont.py`) keep their names, so the whole app picks up the new look without code changes. New glyphs for the redesign are named `rd_*` and were appended to the end of the JSON (existing code points do not move).

**Sources** (per glyph, see the table; the machine-readable form is `extras/redesign/icon-map.json`):

- **Phosphor Icons 2.1.1** (MIT, https://phosphoricons.com), regular weight, from the npm package `@phosphor-icons/core` 2.1.1. Bundled files: `modules/gui/qt/redesign/assets/phosphor/regular/*.svg` (only the ones used) and `phosphor/LICENSE`. One exception to "regular only": `rd_heart_filled` uses `phosphor/fill/heart-straight-fill.svg`.
- **Custom (Figma)** icons, cut out of the owner's component sheet `docs/redesign/figma-svg/Icon.svg`. The sheet turned out to be a redrawn set in Phosphor's style, not Phosphor's own artwork (gear, volume, skip-10, sidebar, subtitles, folders and the filled transport icons differ in shape and proportions; x, plus, minus, dots, arrows and the heart are identical). Where the Figma sheet has the icon and Phosphor's drawing is visibly different, the Figma drawing is used, so that the app matches the design; where they are identical, or the sheet does not have the icon, Phosphor is used. **The licence of the Figma icons is unconfirmed** (the design file's terms are not known); ask the owner before a public release, or swap them for Phosphor icons by changing the entries in `icon-map.json` (rerun the steps below). They live in `modules/gui/qt/redesign/assets/figma-icons/`.
- **Kept upstream**: glyphs without a good equivalent in either set keep their upstream SVG (list below).

Stroke weight: the Figma icons use a 1.5 px stroke on a 24 px grid, which is 16/256 on Phosphor's grid, exactly Phosphor's regular weight (checked by overlaying identical icons: x, plus, minus, arrows coincide). No weight switch is needed.

Size: both sets fill their square the same way (24 px cell = 256 viewBox, about 1.5 px / 16 units of padding), so a Phosphor and a Figma icon have the same visual size at the same font size. They are larger than most upstream icons (which drew about 55 to 75 percent of the box): the sizes in `VLCStyle` (`icon_toolbar` 24 and so on) are unchanged, adjust them in Task 6 style work if the owner finds the icons too large.

**Pipeline** (all committed; re-run only when the map changes):

1. `python3 extras/redesign/extract_figma_icons.py docs/redesign/figma-svg/Icon.svg extras/redesign/icon-map.json modules/gui/qt/redesign/assets/figma-icons` (needs python3-shapely) turns the stroked Figma cells into one filled, overlap-free outline each.
2. `python3 extras/redesign/build_icons.py` writes the normalised SVGs (one black path, `width`/`height` equal to the `viewBox`) over `modules/gui/qt/pixmaps/icons/<file>.svg` for every mapped glyph. `--check` fails when they are out of date.
3. `python3 extras/redesign/check_icons.py modules/gui/qt/pixmaps` (CI) validates the glyph list against the SVGs.
4. `cd modules/gui/qt/pixmaps && python3 makeIconFont.py VLCIcons.json` (needs fontforge) regenerates the font. It was run in a throwaway `vlc-debian-unstable` container with `python3-fontforge` installed (nothing on the Windows host).

Phosphor icons are single outline paths without overlaps; the Figma icons are united by step 1. fontforge reports no self-intersection for any new glyph (the upstream `dropzone` has one, as before).

### Mapping: every glyph that is not kept

| VLC glyph (`VLCIcons.<key>`) | Source | Icon | Licence |
|---|---|---|---|
| `add` | Phosphor | `plus` | MIT |
| `album_cover` | custom (Figma) | `figma-icons/music-note.svg` (Icon.svg cell 6,5) | unconfirmed |
| `aspect_ratio` | Phosphor | `frame-corners` | MIT |
| `audiosub` | custom (Figma) | `figma-icons/subtitles.svg` (Icon.svg cell 3,1) | unconfirmed |
| `back` | Phosphor | `arrow-left` | MIT |
| `bookmark` | custom (Figma) | `figma-icons/bookmark.svg` (Icon.svg cell 11,12) | unconfirmed |
| `check` | custom (Figma) | `figma-icons/check.svg` (Icon.svg cell 6,9) | unconfirmed |
| `clear` | Phosphor | `x` | MIT |
| `close` | Phosphor | `x` | MIT |
| `defullscreen` | custom (Figma) | `figma-icons/fullscreen-exit.svg` (Icon.svg cell 3,4) | unconfirmed |
| `del` | Phosphor | `trash` | MIT |
| `effect_filter` | custom (Figma) | `figma-icons/faders.svg` (Icon.svg cell 5,0) | unconfirmed |
| `eject` | Phosphor | `eject` | MIT |
| `ellipsis` | Phosphor | `dots-three` | MIT |
| `enqueue` | Phosphor | `list-plus` | MIT |
| `expand_inverted` | custom (Figma) | `figma-icons/chevron-up.svg` (Icon.svg cell 5,8) | unconfirmed |
| `expand` | custom (Figma) | `figma-icons/chevron-down.svg` (Icon.svg cell 2,7) | unconfirmed |
| `faster` | Phosphor | `fast-forward` | MIT |
| `fullscreen` | custom (Figma) | `figma-icons/fullscreen.svg` (Icon.svg cell 2,4) | unconfirmed |
| `grid` | custom (Figma) | `figma-icons/grid.svg` (Icon.svg cell 10,11) | unconfirmed |
| `history` | custom (Figma) | `figma-icons/history.svg` (Icon.svg cell 4,3) | unconfirmed |
| `home` | custom (Figma) | `figma-icons/home.svg` (Icon.svg cell 4,4) | unconfirmed |
| `info` | custom (Figma) | `figma-icons/info.svg` (Icon.svg cell 6,10) | unconfirmed |
| `list` | custom (Figma) | `figma-icons/list.svg` (Icon.svg cell 11,11) | unconfirmed |
| `more` | Phosphor | `dots-three` | MIT |
| `next` | custom (Figma) | `figma-icons/skip-next-filled.svg` (Icon.svg cell 3,2) | unconfirmed |
| `pause_filled` | custom (Figma) | `figma-icons/pause-filled.svg` (Icon.svg cell 2,2) | unconfirmed |
| `play_filled` | custom (Figma) | `figma-icons/play-filled.svg` (Icon.svg cell 9,1) | unconfirmed |
| `play` | custom (Figma) | `figma-icons/play.svg` (Icon.svg cell 10,1) | unconfirmed |
| `ic_fluent_chevron_down_24` | custom (Figma) | `figma-icons/chevron-down.svg` (Icon.svg cell 2,7) | unconfirmed |
| `ic_fluent_chevron_left_24` | custom (Figma) | `figma-icons/chevron-left.svg` (Icon.svg cell 7,8) | unconfirmed |
| `ic_fluent_chevron_right_24` | custom (Figma) | `figma-icons/chevron-right.svg` (Icon.svg cell 6,8) | unconfirmed |
| `ic_fluent_chevron_up_24` | custom (Figma) | `figma-icons/chevron-up.svg` (Icon.svg cell 5,8) | unconfirmed |
| `panel_left` | custom (Figma) | `figma-icons/sidebar.svg` (Icon.svg cell 11,4) | unconfirmed |
| `playlist` | custom (Figma) | `figma-icons/queue-play.svg` (Icon.svg cell 7,0) | unconfirmed |
| `previous` | custom (Figma) | `figma-icons/skip-previous-filled.svg` (Icon.svg cell 7,2) | unconfirmed |
| `profile_new` | Phosphor | `user-plus` | MIT |
| `record` | custom (Figma) | `figma-icons/record.svg` (Icon.svg cell 3,12) | unconfirmed |
| `remove` | Phosphor | `minus` | MIT |
| `renderer` | Phosphor | `screencast` | MIT |
| `repeat_all` | custom (Figma) | `figma-icons/repeat.svg` (Icon.svg cell 1,8) | unconfirmed |
| `repeat_one` | Phosphor | `repeat-once` | MIT |
| `search` | custom (Figma) | `figma-icons/search.svg` (Icon.svg cell 11,9) | unconfirmed |
| `settings` | custom (Figma) | `figma-icons/gear.svg` (Icon.svg cell 0,0) | unconfirmed |
| `shuffle` | custom (Figma) | `figma-icons/shuffle.svg` (Icon.svg cell 3,8) | unconfirmed |
| `skip_back` | custom (Figma) | `figma-icons/replay-10.svg` (Icon.svg cell 11,2) | unconfirmed |
| `skip_for` | custom (Figma) | `figma-icons/forward-10.svg` (Icon.svg cell 9,2) | unconfirmed |
| `slower` | Phosphor | `rewind` | MIT |
| `snapshot` | Phosphor | `camera` | MIT |
| `stop` | custom (Figma) | `figma-icons/stop-filled.svg` (Icon.svg cell 5,2) | unconfirmed |
| `time` | Phosphor | `clock` | MIT |
| `topbar_discover` | Phosphor | `globe` | MIT |
| `topbar_music` | custom (Figma) | `figma-icons/music-library.svg` (Icon.svg cell 1,5) | unconfirmed |
| `topbar_network` | custom (Figma) | `figma-icons/broadcast.svg` (Icon.svg cell 4,6) | unconfirmed |
| `topbar_sort` | Phosphor | `arrows-down-up` | MIT |
| `topbar_video` | custom (Figma) | `figma-icons/folder-play.svg` (Icon.svg cell 1,6) | unconfirmed |
| `chevron_up` | custom (Figma) | `figma-icons/chevron-up.svg` (Icon.svg cell 5,8) | unconfirmed |
| `chevron_down` | custom (Figma) | `figma-icons/chevron-down.svg` (Icon.svg cell 2,7) | unconfirmed |
| `tv` | custom (Figma) | `figma-icons/tv-play.svg` (Icon.svg cell 8,6) | unconfirmed |
| `visualization` | custom (Figma) | `figma-icons/spectrum.svg` (Icon.svg cell 3,13) | unconfirmed |
| `volume_high` | custom (Figma) | `figma-icons/volume-high.svg` (Icon.svg cell 6,3) | unconfirmed |
| `volume_low` | custom (Figma) | `figma-icons/volume-low.svg` (Icon.svg cell 8,3) | unconfirmed |
| `volume_medium` | custom (Figma) | `figma-icons/volume-medium.svg` (Icon.svg cell 7,3) | unconfirmed |
| `volume_muted` | custom (Figma) | `figma-icons/volume-muted.svg` (Icon.svg cell 9,3) | unconfirmed |
| `volume_zero` | custom (Figma) | `figma-icons/volume-zero.svg` (Icon.svg cell 8,3) without the volume ticks | unconfirmed |
| `ic_fluent_document_add_24_regular` | Phosphor | `file-plus` | MIT |
| `ic_fluent_document_copy_24_regular` | Phosphor | `copy` | MIT |
| `ic_fluent_arrow_download_24_regular` | Phosphor | `download-simple` | MIT |
| `ic_fluent_arrow_sync_24_regular` | custom (Figma) | `figma-icons/sync.svg` (Icon.svg cell 1,3) | unconfirmed |
| `ic_fluent_folder_open_24_regular` | custom (Figma) | `figma-icons/folder-open.svg` (Icon.svg cell 6,4) | unconfirmed |
| `medialibrary_add` | custom (Figma) | `figma-icons/folder-plus.svg` (Icon.svg cell 7,4) | unconfirmed |
| `medialibrary_remove` | Phosphor | `folder-simple-minus` | MIT |
| `ic_fluent_text_change_case_24_regular` | Phosphor | `text-aa` | MIT |
| `rd_heart` | Phosphor | `heart-straight` | MIT |
| `rd_heart_filled` | Phosphor | `heart-straight-fill` (fill weight) | MIT |
| `rd_divider` | Phosphor | `line-vertical` | MIT |
| `rd_replay` | custom (Figma) | `figma-icons/undo.svg` (Icon.svg cell 3,3) | unconfirmed |
| `rd_folder` | custom (Figma) | `figma-icons/folder.svg` (Icon.svg cell 5,4) | unconfirmed |
| `rd_artist` | custom (Figma) | `figma-icons/artist.svg` (Icon.svg cell 1,10) | unconfirmed |
| `rd_playlist_label` | custom (Figma) | `figma-icons/queue-play.svg` (Icon.svg cell 7,0) | unconfirmed |
| `rd_queue` | custom (Figma) | `figma-icons/list-bullets.svg` (Icon.svg cell 11,0) | unconfirmed |
| `rd_subtitles` | custom (Figma) | `figma-icons/subtitles.svg` (Icon.svg cell 3,1) | unconfirmed |
| `rd_audio` | custom (Figma) | `figma-icons/waveform.svg` (Icon.svg cell 6,1) | unconfirmed |
| `rd_sidebar` | custom (Figma) | `figma-icons/sidebar.svg` (Icon.svg cell 11,4) | unconfirmed |
| `rd_menu` | Phosphor | `dots-three` | MIT |
| `rd_library` | custom (Figma) | `figma-icons/folder-play.svg` (Icon.svg cell 1,6) | unconfirmed |
| `rd_pin` | Phosphor | `push-pin` | MIT |

87 glyphs are mapped (30 Phosphor, 57 custom Figma; the 57 use 49 distinct Figma drawings), 24 are kept upstream.

### New `rd_*` glyphs

`rd_heart`, `rd_heart_filled`, `rd_divider`, `rd_replay`, `rd_folder`, `rd_artist`, `rd_playlist_label`, `rd_queue`, `rd_subtitles`, `rd_audio`, `rd_sidebar`, `rd_menu`, `rd_library`, `rd_pin`.

Differences from the first plan: `rd_menu` is the three-dots icon (the main menu button of the title bar in Player-1.png) instead of a list; `rd_heart` and `rd_heart_filled` use Phosphor's `heart-straight` pair (it coincides with the Figma heart, `heart` does not); `rd_divider` is only the picker label of the divider control (the control itself draws a 1 px rule).

### Kept upstream (no equivalent in the Figma sheet or Phosphor)

`active_indicator`, `atob`, `breadcrumb_sep`, `breadcrumb_prev`, `dropzone`, `dvd_menu`, `dvd_next`, `dvd_prev`, `next_frame`, `previous_frame`, `ok`, `ic_fluent_arrow_move`, `play_reverse`, `playlist_clear`, `space`, `stream`, `tvtelx`, `transparency`, `circle`, `window_close`, `window_maximize`, `window_minimize`, `window_restore`, `regex`.

Reasons: window controls (`window_*`) and the tiny breadcrumb and indicator shapes are drawn for 12 px or smaller sizes; `play_reverse`, `next_frame`, `previous_frame`, `dvd_*`, `atob`, `tvtelx`, `transparency`, `regex`, `ok`, `space`, `circle`, `stream`, `dropzone`, `playlist_clear`, `ic_fluent_arrow_move` are VLC-specific functions without a counterpart. `play_filled`, `pause_filled`, `stop`, `next` and `previous` are mapped to the Figma filled shapes, not to Phosphor's fill weight (not bundled).

### Not covered

The C++ menus (`QMenu` actions) use a separate SVG set in `modules/gui/qt/pixmaps/menu/` (`:/menu/...`), which is not part of the icon font and is unchanged; so are the preferences and add-on images.
