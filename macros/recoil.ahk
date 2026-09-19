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

; Структура паттерна: [interval_ms, offset1, offset2, ...]
weapons := {}
; AK реальный паттерн:
weapons["AK"] := [40, -8, -9, -10, -9, -8, -7, -6, -5, -5, -4, -3, -3, -2, -2]
weapons["LR-300"] := [40, -3, -3, -4, -5, -6, -6, -5, -4, -3, -2]
weapons["Assault Rifle"] := [40, -3, -3, -4, -5, -6, -6, -5, -4, -3]
weapons["M39"] := [45, -2, -2, -3, -3, -4, -4, -3, -2]
weapons["L96"] := [60, -6, -5, -5, -6]
weapons["Bolt Action Rifle"] := [60, -6, -6, -7]
weapons["Semi-Automatic Rifle"] := [50, -4, -4, -5, -5]
weapons["MP5A4"] := [30, -2, -3, -3, -4, -3, -2]
weapons["Thompson"] := [35, -3, -3, -4, -4, -3]
weapons["Custom SMG"] := [30, -2, -3, -3, -4]
weapons["Pump shotgun"] := [80, -8, -7, -9]
weapons["Double Barrel Shotgun"] := [90, -12, -10]
weapons["Waterpipe Shotgun"] := [85, -10, -9]
weapons["Spas-12"] := [75, -9, -9]
weapons["Semi-Automatic Pistol"] := [70, -6, -5]
weapons["Revolver"] := [70, -7, -6]
weapons["Python"] := [70, -8, -7]
weapons["M249"] := [28, -2, -3, -4, -5, -6, -6, -5, -4, -3]

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
Gui, Add, GroupBox, x10 y44 w440 h72, Aim settings
Gui, Add, Text, x20 y64, Sensitivity
Gui, Add, Slider, x120 y66 vSensSlider Range20-200 w240 gOnSensChange,100
Gui, Add, Text, x370 y64 vSensText c0xCFE8FF w60, 1.00
Gui, Add, Text, x20 y92, FOV
Gui, Add, Edit, x120 y90 vFOVEdit w80 gOnFOVChange, %FOV%
Gui, Add, Text, x210 y92 w220 c0x9FB8C8, (Field of view — affects aim scaling)

; Weapons block
Gui, Add, GroupBox, x10 y124 w440 h280, Weapons
; create two-column grid of buttons with improved spacing and color hint
weapList := ["AK","LR-300","Assault Rifle","M39","L96","Bolt Action Rifle","Semi-Automatic Rifle","MP5A4","Thompson","Custom SMG","Pump shotgun","Double Barrel Shotgun","Waterpipe Shotgun","Spas-12","Semi-Automatic Pistol","Revolver","Python","M249"]
row := 0
col := 0
for index, name in weapList {
    xPos := 20 + (col * 210)
    yPos := 154 + (row * 34)
    ; styled button: use larger size and bold label for readability
    Gui, Add, Button, x%xPos% y%yPos% w200 h28 gWeaponSelect vBtn%index% +Center, %name%
    col += 1
    if (col >= 2) {
        col := 0
        row += 1
    }
}

; Scope modifiers and profile controls
Gui, Add, GroupBox, x10 y414 w440 h88, Extras
Gui, Add, Text, x20 y434, Scope modifier
Gui, Add, DropDownList, x140 y430 vScopeDD gOnScopeChange w150, None||8x|Holo|Hand|Silencer
Gui, Add, Button, x310 y428 w120 h26 gToggleScopeTooltip, ?
Gui, Add, Button, x20 y464 w100 gSaveProfile, Save profile
Gui, Add, Button, x130 y464 w100 gLoadProfile, Load profile
Gui, Add, Button, x240 y464 w100 gResetAll, Reset
Gui, Add, Button, x350 y464 w90 gExitApp, Exit

; Status bar
Gui, Add, Text, x10 y512 w440 h28 vStatusText c0xA7FFB2, Status: OFF    Hotkey: F8

; Tooltips and initial control values
ToolTip, Hotkey F8 toggles macro. Hold LMB to apply recoil compensation., 5, 580

Gui, Show, w460 h560, Recoil macros — GUI
return

; --- GUI callbacks ---
OnSensChange:
    GuiControlGet, SensSlider
    Sens := SensSlider / 100.0
    GuiControl,, SensText, %Round(Sens, 2)
return

OnFOVChange:
    GuiControlGet, FOVEdit
    FOV := FOVEdit
return

OnScopeChange:
    GuiControlGet, ScopeDD
    ScopeMod := ScopeDD
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
    GuiControl,, StatusText, %"Selected: " . CurrentWeapon . " | Status: " . (Enabled?"ON":"OFF")
return

SaveProfile:
    FileCreateDir, profiles
    InputBox, profname, Save profile, Enter profile name:, , 300, 150
    if (ErrorLevel)
        return
    path := A_ScriptDir "\\profiles\\" profname ".ini"
    IniWrite, %Sens%, %path%, general, sensitivity
    IniWrite, %FOV%, %path%, general, fov
    IniWrite, %CurrentWeapon%, %path%, general, weapon
    IniWrite, %ScopeMod%, %path%, general, scope
    ; Save each weapon pattern as a comma-separated line
    for k, v in weapons {
        s := ""
        for i, val in v
            s .= val ","
        IniWrite, %s%, %path%, weapon_pat, %k%
    }
    MsgBox, Profile saved: %path%
return

LoadProfile:
    FileSelectFile, file, 3, %A_ScriptDir%\\profiles, Select profile INI, INI Files (*.ini)
    if (file = "")
        return
    IniRead, Sens, %file%, general, sensitivity, %Sens%
    IniRead, FOV, %file%, general, fov, %FOV%
    IniRead, CurrentWeapon, %file%, general, weapon, %CurrentWeapon%
    IniRead, ScopeMod, %file%, general, scope, %ScopeMod%
    GuiControl,, SensSlider, % Round(Sens*100) %
    GuiControl,, SensText, %Round(Sens, 2)
    GuiControl,, FOVEdit, %FOV%
    GuiControl,, ScopeDD, %ScopeMod%
    ; Load weapon patterns if present (basic parser)
    Loop, Read, %file%
    {
        line := A_LoopReadLine
        if InStr(line, "=") {
            StringSplit, parts, line, =
            key := parts1
            val := parts2
            if InStr(key, "weapon_pat") {
                ; key format: weapon_pat[weaponName]
                ; skip sophisticated parsing for now
            }
        }
    }
    GuiControl,, StatusText, %"Loaded: " . file
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
F8::
    Enabled := !Enabled
    GuiControl,, StatusText, %"Status: " . (Enabled?"ON":"OFF") . " | Weapon: " . CurrentWeapon
return

~LButton::
    if (!Enabled)
        return
    ; Only compensate while held
    SetMouseDelay, -1
    ; get pattern for current weapon
    pattern := weapons[CurrentWeapon]
    if (!pattern)
    {
        ; fallback
        pattern := [40, -3, -3, -3, -4]
    }
    interval := pattern[1]
    index := 2
    Loop
    {
        if !GetKeyState("LButton","P")
            break
        ; compute offset
        offset := pattern[index]
        if (offset = "")
        {
            index := 2
            offset := pattern[index]
        }
        ; apply modifiers: sensitivity and scope
        mul := ScopeMod != "" ? scopemods[ScopeMod] : 1.0
        ymove := Round(offset * Sens * mul)
        ; move mouse relatively
        DllCall("mouse_event", UInt,0x0001, Int,0, Int, ymove, UInt,0, UInt,0)
        Sleep, interval
        index += 1
    }
return

; End of script
