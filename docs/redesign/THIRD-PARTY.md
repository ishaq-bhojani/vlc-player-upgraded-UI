# Third-party material in VLC Reborn

Components that ship inside the redesign (`modules/gui/qt/redesign/`) and are not part of VLC.
VLC itself is GPL-2.0-or-later / LGPL-2.1-or-later (`COPYING`, `COPYING.LIB`). About and the
installer must show these notices (Task 13 owns those texts).

| Component | Version | Licence | Copyright | Where |
|---|---|---|---|---|
| Phosphor Icons, https://phosphoricons.com | 2.1.1 (npm `@phosphor-icons/core`) | MIT | Copyright (c) 2023 Phosphor Icons | `modules/gui/qt/redesign/assets/phosphor/` (only the SVGs in use, plus `LICENSE`); compiled into the icon font `modules/gui/qt/pixmaps/VLCIcons.ttf` |
| Inter, https://rsms.me/inter | 4.1 | SIL Open Font License 1.1 | Copyright (c) 2016 The Inter Project Authors | `modules/gui/qt/redesign/assets/fonts/` (static TTFs and `OFL.txt`) |

## Not yet cleared

| Component | Status |
|---|---|
| Figma icons (57 glyphs of the icon font, cut out of `docs/redesign/figma-svg/Icon.svg`, stored as outlines in `modules/gui/qt/redesign/assets/figma-icons/`) | The licence of the design file is **unconfirmed** (see `docs/redesign/branding.md`, Design credits). Do not publish a release until the owner confirms the terms, or replaces these glyphs by Phosphor icons in `extras/redesign/icon-map.json`. |

## Phosphor Icons 2.1.1

Package `@phosphor-icons/core` 2.1.1, tarball integrity
`sha512-v4ARvrip4qBCImOE5rmPUylOEK4iiED9ZyKjcvzuezqMaiRASCHKcRIuvvxL/twvLpkfnEODCOJp5dM4eZilxQ==`
(from the npm registry metadata `dist.integrity`, verified). Full licence text:
`modules/gui/qt/redesign/assets/phosphor/LICENSE`.
