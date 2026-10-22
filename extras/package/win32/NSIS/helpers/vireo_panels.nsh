;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Vireo: sharp welcome / finish side panel at every display scaling ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Modern UI loads one bitmap (MUI_WELCOMEFINISHPAGE_BITMAP, 164 x 314) and stretches it to
; the control, which Windows scales with the display (150% = 246 x 471): the panel gets
; blurry. extras/redesign/make-icons.cpp renders the panel from the vector artwork at
; 100, 125, 150, 175 and 200% (164x314, 205x393, 246x471, 287x550, 328x628, each natively,
; none resampled). The installer and uninstaller extract them to $PLUGINSDIR in .onInit /
; un.onInit, and the SHOW callback of the welcome and finish pages loads the smallest panel
; that is at least as wide as the control, at the control's exact size, and puts it on the
; control. The 100% file stays MUI_WELCOMEFINISHPAGE_BITMAP: it is the fallback if anything
; below fails.

; Reserve files for solid compression: put the panels at the head of the data block, so
; extracting them in .onInit does not decompress the whole payload before the first page.
; (This file is included before the first Section, which ReserveFile requires.)
ReserveFile "NSIS\vireo_branding.bmp"
ReserveFile "NSIS\vireo_branding_125.bmp"
ReserveFile "NSIS\vireo_branding_150.bmp"
ReserveFile "NSIS\vireo_branding_175.bmp"
ReserveFile "NSIS\vireo_branding_200.bmp"

; Extract the five panels (call from .onInit and from un.onInit).
!macro VIREO_EXTRACT_PANELS
  InitPluginsDir
  File "/oname=$PLUGINSDIR\vireo_panel_100.bmp" "NSIS\vireo_branding.bmp"
  File "/oname=$PLUGINSDIR\vireo_panel_125.bmp" "NSIS\vireo_branding_125.bmp"
  File "/oname=$PLUGINSDIR\vireo_panel_150.bmp" "NSIS\vireo_branding_150.bmp"
  File "/oname=$PLUGINSDIR\vireo_panel_175.bmp" "NSIS\vireo_branding_175.bmp"
  File "/oname=$PLUGINSDIR\vireo_panel_200.bmp" "NSIS\vireo_branding_200.bmp"
!macroend

; Callback body: _IMG is the image control (HWND), _BMP the variable in which Modern UI keeps
; the bitmap handle it frees when the page is left (so it must hold the new handle).
!macro VIREO_PANEL_BODY _IMG _BMP
  Push $0
  Push $1
  Push $2
  Push $3
  Push $4
  Push $5
  Push $6

  ; size of the control in pixels
  System::Call '*(i,i,i,i) p.r0'
  System::Call 'user32::GetClientRect(p ${_IMG}, p r0)'
  System::Call '*$0(i,i,i.r1,i.r2)'
  System::Free $0

  ; if that failed: the size follows from the window DPI (GetDpiForWindow, Windows 10 1607 and
  ; later, else the DPI of the screen), 100% is 164 x 314
  ${If} $1 < 1
  ${OrIf} $2 < 1
    System::Call 'user32::GetDpiForWindow(p ${_IMG}) i .r3'
    ${If} $3 < 96
      System::Call 'user32::GetDC(p 0) p .r4'
      System::Call 'gdi32::GetDeviceCaps(p r4, i 88) i .r3'   ; LOGPIXELSX
      System::Call 'user32::ReleaseDC(p 0, p r4)'
    ${EndIf}
    ${If} $3 < 96
      StrCpy $3 96
    ${EndIf}
    IntOp $1 164 * $3
    IntOp $1 $1 + 95
    IntOp $1 $1 / 96
    IntOp $2 314 * $3
    IntOp $2 $2 + 95
    IntOp $2 $2 / 96
  ${EndIf}

  ; the smallest panel that is at least as wide as the control (the largest if none is)
  StrCpy $4 100
  ${If} $1 > 164
    StrCpy $4 125
  ${EndIf}
  ${If} $1 > 205
    StrCpy $4 150
  ${EndIf}
  ${If} $1 > 246
    StrCpy $4 175
  ${EndIf}
  ${If} $1 > 287
    StrCpy $4 200
  ${EndIf}

  ; load it at the control's size, put it on the control, release the old bitmap
  System::Call 'user32::LoadImage(p 0, t "$PLUGINSDIR\vireo_panel_$4.bmp", i 0, i r1, i r2, i 0x10) p .r5'
  ${If} $5 <> 0
    SendMessage ${_IMG} 0x172 0 $5 $6     ; STM_SETIMAGE, IMAGE_BITMAP
    ${If} $6 <> 0
    ${AndIf} $6 <> $5
      System::Call 'gdi32::DeleteObject(p r6)'
    ${EndIf}
    StrCpy ${_BMP} $5
  ${EndIf}

  Pop $6
  Pop $5
  Pop $4
  Pop $3
  Pop $2
  Pop $1
  Pop $0
!macroend

; SHOW callbacks (MUI_PAGE_CUSTOMFUNCTION_SHOW). The uninstaller has no welcome page.
Function VireoWelcomeShow
  !insertmacro VIREO_PANEL_BODY $mui.WelcomePage.Image $mui.WelcomePage.Image.Bitmap
FunctionEnd

Function VireoFinishShow
  !insertmacro VIREO_PANEL_BODY $mui.FinishPage.Image $mui.FinishPage.Image.Bitmap
FunctionEnd

Function un.VireoFinishShow
  !insertmacro VIREO_PANEL_BODY $mui.FinishPage.Image $mui.FinishPage.Image.Bitmap
FunctionEnd
