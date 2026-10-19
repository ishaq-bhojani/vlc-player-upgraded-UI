# VLC Reborn branding

Decision record for names, URLs and signing identity. Items marked `OWNER:` are open and are not guessed. Later tasks read this file: Task 13 (branding), Task 14 (update channel), Task 15 (release workflow).

| Item | Value | Used by |
|---|---|---|
| Product name | VLC Reborn | Task 13: `redesign_product_name` meson option, NSIS `PRODUCT_NAME`, window title, About, tray tooltip |
| Publisher | VLC Reborn contributors | Task 13: NSIS `PRODUCT_PUBLISHER` |
| Website | https://github.com/ishaq-bhojani/vlc-player-upgraded-UI | Task 13: `redesign::productWebsite()`, NSIS `PRODUCT_WEB_SITE`, About source link |
| Update URL base | https://github.com/ishaq-bhojani/vlc-player-upgraded-UI/releases/latest/download | Task 14: `UPDATE_VLC_STATUS_URL` becomes `<base>/status`; `src/misc/update.c:176-181` appends `-win-x64` |
| Icon source files | OWNER: to supply | Task 13: exe/installer `.ico` and installer bitmaps under `share/` |
| GPG key ID (update signing) | OWNER: to generate (Task 14) | Task 14: `include/vlc_pgpkey.h`; secret `UPDATE_GPG_KEY` |

## Notes

- **Update URL.** `src/misc/update.c` fetches a status file from a fixed URL and appends the platform suffix (`-win-x64` on this fork). With GitHub Releases the "latest" redirect serves assets by name, so the status file and its detached signature are published as release assets and fetched as `<base>/status-win-x64` and `<base>/status-win-x64.asc` (the asset names are produced by `extras/redesign/make-status.sh` in Task 14). The base above never changes between releases; the asset contents do.
- **Product name and upstream.** Spec section 7 says "VLC" and the cone are VideoLAN trademarks and that the fork ships under its own product name and icon ("*Name* built on VLC"). The chosen name "VLC Reborn" still contains the word VLC, and the Figma frames show the cone in the title bar. Both need an owner decision (rename, or obtain VideoLAN's permission) before the first public release. About must say the product is built on VLC and link to the source.
- **Applied by Task 13.** `meson_options.txt` option `redesign_product_name` (default `VLC Reborn`) is passed as `-DREDESIGN_PRODUCT_NAME` through `qt_cppargs` (the qt plugin) and `redesign_branding_cppargs` (unit tests), both set in `modules/gui/qt/redesign/meson.build`; `redesign/cpp/branding.hpp` has `redesign::productName()` and `productWebsite()`. QML reads `MainCtx.productName`. Everything is gated by `qt-redesign`: stock mode keeps "VLC media player". NSIS: `PRODUCT_NAME/GROUP/PUBLISHER/WEB_SITE`, install dir `Program Files\VLC Reborn`, English installer strings. The registry keys (`Software\VideoLAN\VLC`, file-association ProgIds) are unchanged on purpose, because libvlccore and the shell integration use them. **Not done / OWNER:** the installer was not built or installed (no VM; NSIS is disabled in the win64 build), so the installer check, Start menu and Apps & Features names are pending; the NSIS language files of the other 30+ languages and the exe resource strings (`bin/vlc_win32_rc.rc.in`, `modules/module.rc.in`) still say "VLC media player"; the Start menu folder is `${PRODUCT_PUBLISHER}` ("VLC Reborn contributors").
- **Icon files.** Nothing was supplied. Until the owner provides the files, Task 13 keeps the upstream icon, and the `OWNER:` marker above blocks the release workflow (Task 15) from claiming branding is done. **OWNER: replace icons** (`share/icons/vlc.ico`, the `share/icons/*` PNG/ICO set, `extras/package/win32/NSIS/vlc_branding.bmp`): the VLC cone is a VideoLAN trademark, and Task 13 left every icon file untouched.
- **GPG key.** No key was generated in this task. Task 14 creates a dedicated update-signing key (`gpg --quick-gen-key "VLC Reborn Updates <email>" dsa2048 sign never`), stores the private part only as the GitHub secret `UPDATE_GPG_KEY`, and records the key ID in the row above. The e-mail address used in the key's user ID is also an `OWNER:` decision.

## Design credits

- **Source file:** Figma community file "VLC Redesign (Community)", https://www.figma.com/design/eC0K7svcmp8c5LAM0PJiQo/VLC-Redesign--Community-?node-id=0-1
- **Designer / author:** OWNER: to record from the community page (not visible in the PNG export).
- **Licence / attribution terms:** OWNER: to confirm. The licence shown on the Figma community page was not accessible when this file was written (no Figma access for the author of this task), and the PNG export carries no licence text. Until confirmed, treat the design as "all rights reserved by the designer, used with the owner's permission" and do not ship the Figma file, its exported PNGs or its SVG icons in the repository.
- **What the repository uses from it:** measured colours, sizes and layout (recorded in `docs/redesign/tokens.md`), and the settings page structure. No Figma assets are copied.

## Third-party credits that About and the installer must show

| Component | Licence | Where it lives |
|---|---|---|
| Inter font (static Regular, Medium, SemiBold, from Inter 4.1) | SIL Open Font License 1.1 | `modules/gui/qt/redesign/assets/fonts/OFL.txt`; Task 6 loads the TTFs, Task 13 copies `OFL.txt` to the installer licence folder and lists it in About |
| VLC media player | GPL-2.0-or-later / LGPL-2.1-or-later | upstream `COPYING`, `COPYING.LIB` |
| Icon set derived from an open icon set, if the designer's SVGs are one | OWNER: to confirm | spec section 5: credit it in About |
