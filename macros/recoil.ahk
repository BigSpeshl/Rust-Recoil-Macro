#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir%
#SingleInstance force
#Persistent

; Простая рабочая основа для recoil-macros (AutoHotkey v1.1+)
; ВНИМАНИЕ: использование макросов в rust может привести к бану.
; Использовать только в оффлайн/тестовых целях.

; --- Настройки по умолчанию ---
global Enabled := false
global CurrentWeapon := "LR-300"
global Sens := 1.00 ; множитель чувствительности (GUI отображает 1.00..)
global FOV := 90
global ScopeMod := "None"
global GuiLocked := false

; Структура паттерна: каждый weapon — объект {interval:, pattern: [], mode: "pair"|"vertical"}
weapons := {}
; AK — 2D S-shaped паттерн (dx,dy pairs)
weapons["AK"] := {interval:40, pattern:[ -2, -8, -1, -7, 0, -6, 1, -5, 2, -4, 2, -3, 1, -2, 0, -1 ], mode:"pair"}
weapons["LR-300"] := {interval:40, pattern:[ -3, -3, -4, -5, -6, -6, -5, -4, -3, -2 ], mode:"vertical"}
weapons["Assault Rifle"] := {interval:40, pattern:[ -3, -3, -4, -5, -6, -6, -5, -4, -3 ], mode:"vertical"}
weapons["M39"] := {interval:45, pattern:[ -2, -2, -3, -3, -4, -4, -3, -2 ], mode:"vertical"}
weapons["L96"] := {interval:60, pattern:[ -6, -5, -5, -6 ], mode:"vertical"}
weapons["Bolt Action Rifle"] := {interval:60, pattern:[ -6, -6, -7 ], mode:"vertical"}
weapons["Semi-Automatic Rifle"] := {interval:50, pattern:[ -4, -4, -5, -5 ], mode:"vertical"}
weapons["MP5A4"] := {interval:30, pattern:[ -2, -3, -3, -4, -3, -2 ], mode:"vertical"}
weapons["Thompson"] := {interval:35, pattern:[ -3, -3, -4, -4, -3 ], mode:"vertical"}
weapons["Custom SMG"] := {interval:30, pattern:[ -2, -3, -3, -4 ], mode:"vertical"}
weapons["Pump shotgun"] := {interval:80, pattern:[ -8, -7, -9 ], mode:"vertical"}
weapons["Double Barrel Shotgun"] := {interval:90, pattern:[ -12, -10 ], mode:"vertical"}
weapons["Waterpipe Shotgun"] := {interval:85, pattern:[ -10, -9 ], mode:"vertical"}
weapons["Spas-12"] := {interval:75, pattern:[ -9, -9 ], mode:"vertical"}
weapons["Semi-Automatic Pistol"] := {interval:70, pattern:[ -6, -5 ], mode:"vertical"}
weapons["Revolver"] := {interval:70, pattern:[ -7, -6 ], mode:"vertical"}
weapons["Python"] := {interval:70, pattern:[ -8, -7 ], mode:"vertical"}
weapons["M249"] := {interval:28, pattern:[ -2, -3, -4, -5, -6, -6, -5, -4, -3 ], mode:"vertical"}

; Scope modifiers
scopemods := {}
scopemods["None"] := 1.0
scopemods["8x"] := 0.6
scopemods["Holo"] := 0.95
scopemods["Hand"] := 0.9
scopemods["Silencer"] := 0.9

; GUI - styled
Gui +Resize
Gui, Color, 0x11151A ; dark background
Gui, Font, s10, Segoe UI

; Header
Gui, Font, s14 Bold, Segoe UI
Gui, Add, Text, x10 y8 w440 h28 c0xFFFFFF Center, Recoil macros — Controls
Gui, Font, s10, Segoe UI

; Sensitivity block
Gui, Add, GroupBox, x10 y44 w760 h110, Aim settings
Gui, Add, Text, x20 y64 c0xFFFFFF, Sensitivity
Gui, Add, Slider, x160 y66 vSensSlider Range20-200 w420 gOnSensChange,100
Gui, Add, Text, x600 y64 vSensText c0xFFFFFF w80, 1.00
Gui, Add, Text, x20 y96 c0xFFFFFF, FOV
Gui, Add, Edit, x160 y94 vFOVEdit w100 gOnFOVChange, %FOV%
Gui, Add, Text, x280 y96 w480 c0xFFFFFF, (Field of view — affects aim scaling)

; Weapons block
Gui, Add, GroupBox, x10 y164 w760 h440, Weapons
; create three-column grid of buttons with improved spacing and color hint
weapList := ["AK","LR-300","Assault Rifle","M39","L96","Bolt Action Rifle","Semi-Automatic Rifle","MP5A4","Thompson","Custom SMG","Pump shotgun","Double Barrel Shotgun","Waterpipe Shotgun","Spas-12","Semi-Automatic Pistol","Revolver","Python","M249"]
row := 0
col := 0
for index, name in weapList {
    xPos := 20 + (col * 250)
    yPos := 194 + (row * 36)
    ; styled button: use larger size and bold label for readability
    Gui, Add, Button, x%xPos% y%yPos% w230 h32 gWeaponSelect vBtn%index% +Center, %name%
    col += 1
    if (col >= 3) {
        col := 0
        row += 1
    }
}

; Scope modifiers and profile controls
Gui, Add, GroupBox, x10 y620 w760 h120, Extras
Gui, Add, Text, x20 y640 c0xFFFFFF, Scope modifier
Gui, Add, DropDownList, x160 y636 vScopeDD gOnScopeChange w150, None||8x|Holo|Hand|Silencer
Gui, Add, Button, x340 y636 w40 h26 gPrevWeapon, <
Gui, Add, Button, x390 y636 w40 h26 gNextWeapon, >
Gui, Add, Button, x440 y636 w30 h26 gToggleScopeTooltip, ?
Gui, Add, Button, x500 y636 w110 gSaveProfile, Save profile
Gui, Add, Button, x620 y636 w110 gLoadProfile, Load profile
Gui, Add, Button, x20 y676 w120 gResetAll, Reset
Gui, Add, Button, x160 y676 w120 gExitApp, Exit
; ON/OFF toggle button
Gui, Add, Button, x220 y676 w120 h36 vLockGuiBtn gToggleGUILock, Lock GUI
Gui, Add, Button, x360 y676 w160 h36 vEnableBtn gToggleEnable, Enable (F6)
Gui, Add, Text, x540 y676 w220 c0xFFFFFF, Quick select: press ~1-~9 to pick weapon (does not block keys)


; Status bar
Gui, Add, Text, x10 y760 w740 h28 vStatusText c0xFFFFFF, Selected: | Status: OFF    Hotkey: F6

; Tooltips and initial control values
ToolTip, Hotkey F6 toggles macro. Hold LMB to apply recoil compensation., 10, 780

Gui, Show, w780 h760 NA, Recoil macros — GUI
return

; --- GUI callbacks ---
OnSensChange:
    GuiControlGet, SensSlider
    Sens := SensSlider / 100.0
    GuiControl,, SensText, % Round(Sens, 2)
return

OnFOVChange:
    GuiControlGet, FOVEdit
    FOV := FOVEdit
return

OnScopeChange:
    GuiControlGet, ScopeDD
    ScopeMod := ScopeDD
return

ToggleScopeTooltip:
    ; Показывает подсказку по смыслу модификаторов прицела
    MsgBox, 64, Scope modifiers, 8x: stronger zoom (reduces compensation)
    MsgBox, 64, Scope modifiers, Holo: slight reduction
    MsgBox, 64, Scope modifiers, Hand: slight reduction for hip/hand aim
    MsgBox, 64, Scope modifiers, Silencer: slight reduction when silenced
return

WeaponSelect:
    Gui, Submit, NoHide
    ; Identify which button triggered
    GuiControlGet, _G_Control, Focus
    ; Focus returns control name; extract index
    ; Instead, use A_GuiControl to get label
    weaponName := A_GuiControl
    ; If button variable like Btn1 etc, get its text
    ControlGetText, text, %weaponName%, A
    CurrentWeapon := text
    GuiControl,, StatusText, % "Selected: " . CurrentWeapon . " | Status: " . (Enabled ? "ON" : "OFF")
return

SaveProfile:
    ; create profiles directory inside script folder: macros/profiles
    profilesDir := A_ScriptDir "\\profiles"
    FileCreateDir, %profilesDir%
    InputBox, profname, Save profile, Enter profile name:, , 300, 150
    if (ErrorLevel)
        return
    path := profilesDir "\\" profname ".ini"
    IniWrite, %Sens%, %path%, general, sensitivity
    IniWrite, %FOV%, %path%, general, fov
    IniWrite, %CurrentWeapon%, %path%, general, weapon
    IniWrite, %ScopeMod%, %path%, general, scope
    ; Save each weapon as interval|mode|csv_pattern
    for k, v in weapons {
        s := v.interval "," v.mode ","
        ; join pattern array
        if IsObject(v.pattern) {
            first := true
            for idx, val in v.pattern {
                if (!first)
                    s .= ","
                s .= val
                first := false
            }
        }
        IniWrite, %s%, %path%, weapon_pat, %k%
    }
    MsgBox, Profile saved: %path%
return

LoadProfile:
    ; ensure profiles dir exists and open it by default
    profilesDir := A_ScriptDir "\\profiles"
    FileCreateDir, %profilesDir%
    FileSelectFile, file, 3, %profilesDir%, Select profile INI, INI Files (*.ini)
    if (file = "")
        return
    IniRead, Sens, %file%, general, sensitivity, %Sens%
    IniRead, FOV, %file%, general, fov, %FOV%
    IniRead, CurrentWeapon, %file%, general, weapon, %CurrentWeapon%
    IniRead, ScopeMod, %file%, general, scope, %ScopeMod%
    GuiControl,, SensSlider, % Round(Sens*100)
    GuiControl,, SensText, % Round(Sens, 2)
    GuiControl,, FOVEdit, %FOV%
    GuiControl,, ScopeDD, %ScopeMod%
    ; Load weapon patterns if present (each key in [weapon_pat] section)
    for k, wname in weapList {
        IniRead, pstr, %file%, weapon_pat, %wname%,
        if (pstr != "") {
            ; format: interval,mode,comma-separated values
            pat := []
            interval := 0
            mode := "vertical"
            idx := 0
            Loop, Parse, pstr, `,
            {
                idx += 1
                if (idx = 1)
                    interval := A_LoopField + 0
                else if (idx = 2)
                    mode := A_LoopField
                else
                    pat.Push(A_LoopField + 0)
            }
            weapons[wname] := {interval: interval, pattern: pat, mode: mode}
        }
    }
    GuiControl,, StatusText, % "Loaded: " . file
return

ResetAll:
    Sens := 1.0
    FOV := 90
    ScopeMod := "None"
    GuiControl,, SensSlider, 100
    GuiControl,, SensText, 1.00
    GuiControl,, FOVEdit, 90
    GuiControl,, ScopeDD, None
    MsgBox, Reset to defaults
return

ExitApp:
    ExitApp
return

; --- Hotkeys and main loop ---
F6::
    Gosub, ToggleEnable
return

~LButton::
    if (!Enabled)
        return
    ; Only compensate while held
    SetMouseDelay, -1
    ; get pattern object for current weapon
    pObj := weapons[CurrentWeapon]
    if (!pObj)
    {
        ; fallback vertical pattern
        pObj := {interval:40, pattern:[-3,-3,-3,-4], mode:"vertical"}
    }
    interval := pObj.interval
    idx := 1 ; index into pattern array (1-based)
    Loop
    {
        if !GetKeyState("LButton","P")
            break
        ; get pattern length
        plen := pObj.pattern.Length()
        if (plen = 0)
            break
        if (pObj.mode = "pair") {
            ; read dx,dy pairs
            if (idx > plen)
                idx := 1
            dx := pObj.pattern[idx]
            dy := pObj.pattern[idx+1]
            ; fallback if odd
            if (dy = "")
                dy := 0
            idx += 2
        } else {
            ; vertical-only pattern: dy values
            if (idx > plen)
                idx := 1
            dx := 0
            dy := pObj.pattern[idx]
            idx += 1
        }
        ; apply modifiers: sensitivity and scope (scale both axes)
        mul := ScopeMod != "" ? scopemods[ScopeMod] : 1.0
        ; invert sign to COUNTER recoil: patterns describe recoil direction, so negate to move opposite
        xmove := Round(-dx * Sens * mul)
        ymove := Round(-dy * Sens * mul)
        ; move mouse relatively (dx, dy)
        DllCall("mouse_event", UInt,0x0001, Int,xmove, Int, ymove, UInt,0, UInt,0)
        Sleep, interval
    }
return


; Quick-select hotkeys (1..9) map to first weapons in weapList - non-blocking (~)
~1::
    SelectWeaponByIndex(1)
return
~2::
    SelectWeaponByIndex(2)
return
~3::
    SelectWeaponByIndex(3)
return
~4::
    SelectWeaponByIndex(4)
return
~5::
    SelectWeaponByIndex(5)
return
~6::
    SelectWeaponByIndex(6)
return
~7::
    SelectWeaponByIndex(7)
return
~8::
    SelectWeaponByIndex(8)
return
~9::
    SelectWeaponByIndex(9)
return

SelectWeaponByIndex(i){
    global weapList, CurrentWeapon
    if (i >=1 && i <= weapList.Length()) {
        CurrentWeapon := weapList[i]
        GuiControl,, StatusText, % "Selected: " . CurrentWeapon . " | Status: " . (Enabled ? "ON" : "OFF")
    }
}

PrevWeapon:
    global weapList, CurrentWeapon
    ; find current index
    idx := 0
    for k, v in weapList
        if (v = CurrentWeapon)
            idx := k
    if (idx = 0)
        idx := 1
    idx -= 1
    if (idx < 1)
        idx := weapList.Length()
    CurrentWeapon := weapList[idx]
    GuiControl,, StatusText, % "Selected: " . CurrentWeapon . " | Status: " . (Enabled ? "ON" : "OFF")
return

NextWeapon:
    global weapList, CurrentWeapon
    idx := 0
    for k, v in weapList
        if (v = CurrentWeapon)
            idx := k
    if (idx = 0)
        idx := 1
    idx += 1
    if (idx > weapList.Length())
        idx := 1
    CurrentWeapon := weapList[idx]
    GuiControl,, StatusText, % "Selected: " . CurrentWeapon . " | Status: " . (Enabled ? "ON" : "OFF")
return

ToggleEnable:
    Enabled := !Enabled
    GuiControl,, EnableBtn, % (Enabled ? "Disable" : "Enable") . " (F6)"
    GuiControl,, StatusText, % "Selected: " . CurrentWeapon . " | Status: " . (Enabled ? "ON" : "OFF") . (GuiLocked?" | GUI: LOCKED":"")
return

ToggleGUILock:
    ; Toggle click-through (when locked GUI will not receive input and keys go to game)
    Gui, +LastFound
    hwnd := WinExist()
    if (!GuiLocked) {
        ; add WS_EX_TRANSPARENT so clicks pass through
        if (A_PtrSize = 8) {
            ex := DllCall("GetWindowLongPtr", "Ptr", hwnd, "Int", -20, "Ptr")
            DllCall("SetWindowLongPtr", "Ptr", hwnd, "Int", -20, "Ptr", ex | 0x20)
        } else {
            ex := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -20, "Int")
            DllCall("SetWindowLong", "Ptr", hwnd, "Int", -20, "Int", ex | 0x20)
        }
        GuiLocked := true
        GuiControl,, LockGuiBtn, Unlock GUI
        GuiControl,, StatusText, % "Selected: " . CurrentWeapon . " | Status: " . (Enabled ? "ON" : "OFF") . " | GUI: LOCKED"
    } else {
        if (A_PtrSize = 8) {
            ex := DllCall("GetWindowLongPtr", "Ptr", hwnd, "Int", -20, "Ptr")
            DllCall("SetWindowLongPtr", "Ptr", hwnd, "Int", -20, "Ptr", ex & ~0x20)
        } else {
            ex := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -20, "Int")
            DllCall("SetWindowLong", "Ptr", hwnd, "Int", -20, "Int", ex & ~0x20)
        }
        GuiLocked := false
        GuiControl,, LockGuiBtn, Lock GUI
        GuiControl,, StatusText, % "Selected: " . CurrentWeapon . " | Status: " . (Enabled ? "ON" : "OFF")
    }
return

; End of script
