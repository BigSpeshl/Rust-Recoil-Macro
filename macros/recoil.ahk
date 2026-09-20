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
global LearnMode := false
global AutoLearnSamples := []
global LearnWindow := 18
global SelectedWeaponBtn := ""
global HoverWeaponBtn := ""

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
Gui, Color, 0x0E1420 ; deep dark navy
Gui, Font, s10, Segoe UI

; Header / title band
Gui, Font, s18 Bold, Segoe UI
Gui, Add, Text, x12 y10 w876 h34 c0xE8F3FF BackgroundTrans, RECOIL CONTROL PANEL
Gui, Font, s9, Segoe UI
Gui, Add, Text, x660 y20 w200 h20 c0x8AB3D9 BackgroundTrans, live tuning // adaptive mode
Gui, Add, Text, x12 y44 w876 h2 c0x2D5D7B

; Sensitivity block
Gui, Add, GroupBox, x10 y60 w860 h130 c0x9BC7FF, AIM TUNING
Gui, Add, Text, x28 y92 c0xF2F8FF, sensitivity
Gui, Add, Slider, x180 y92 vSensSlider Range20-200 w540 gOnSensChange,100
Gui, Add, Text, x740 y92 vSensText c0xF5FAFF w90, 1.00
Gui, Add, Text, x28 y124 c0xF2F8FF, FOV
Gui, Add, Edit, x180 y122 vFOVEdit w120 gOnFOVChange, %FOV%
Gui, Add, Text, x320 y124 w520 c0xC7D8EA, field of view // affects aim scaling / recovery curve

; Weapons block
Gui, Add, GroupBox, x10 y210 w860 h500 c0x9BC7FF, WEAPON PROFILes
; create three-column grid of buttons with improved spacing and color hint
weapList := ["AK","LR-300","Assault Rifle","M39","L96","Bolt Action Rifle","Semi-Automatic Rifle","MP5A4","Thompson","Custom SMG","Pump shotgun","Double Barrel Shotgun","Waterpipe Shotgun","Spas-12","Semi-Automatic Pistol","Revolver","Python","M249"]
row := 0
col := 0
for index, name in weapList {
    xPos := 20 + (col * 280)
    yPos := 240 + (row * 40)
    Gui, Add, Button, x%xPos% y%yPos% w260 h36 gWeaponSelect vBtn%index% +Center +Border, %name%
    col += 1
    if (col >= 3) {
        col := 0
        row += 1
    }
}

; Style selected/default states for weapon buttons after creation
UpdateWeaponButtonStyles()


; Scope modifiers and profile controls
Gui, Add, GroupBox, x10 y734 w880 h170 c0x9BC7FF, EXTRAS
Gui, Add, Text, x20 y760 c0xF2F8FF, scope modifier
Gui, Add, DropDownList, x200 y756 vScopeDD gOnScopeChange w180, None||8x|Holo|Hand|Silencer
Gui, Add, Button, x420 y756 w50 h30 gPrevWeapon, <
Gui, Add, Button, x480 y756 w50 h30 gNextWeapon, >
Gui, Add, Button, x540 y756 w40 h30 gToggleScopeTooltip, ?
Gui, Add, Button, x600 y756 w120 gSaveProfile, save profile
Gui, Add, Button, x740 y756 w120 gLoadProfile, load profile
Gui, Add, Button, x20 y812 w140 gResetAll, reset
Gui, Add, Button, x180 y812 w140 gExitApp, exit
Gui, Add, Button, x340 y812 w220 h44 vLockGuiBtn gToggleGUILock, lock gui
Gui, Add, Button, x580 y812 w180 h44 vEnableBtn gToggleEnable, enable (F6)
Gui, Add, Button, x780 y812 w80 h44 vLearnBtn gToggleLearnMode, learn
Gui, Add, Text, x780 y860 w120 c0xD7E7F8, quick select // ~1-~9

; Status bar
Gui, Add, Text, x10 y908 w860 h28 c0xF3F9FF vStatusText, Selected: | Status: OFF    Hotkey: F6

; Tooltips and initial control values
ToolTip, Hotkey F6 toggles macro. Hold LMB to apply recoil compensation., 10, 940

Gui, Show, w900 h950 NA, Recoil control panel
return
;
; --- GUI callbacks ---
UpdateWeaponButtonStyles() {
    global SelectedWeaponBtn, CurrentWeapon, weapList
    for index, name in weapList {
        control := "Btn" . index
        if (name = CurrentWeapon) {
            ; selected state: cyan glow
            GuiControl, +Background0x2C86C7, %control%
            GuiControl, +c0xF3FAFF, %control%
            SelectedWeaponBtn := control
        } else {
            ; default state: dark muted background
            GuiControl, +Background0x1A2433, %control%
            GuiControl, +c0xE8F3FF, %control%
        }
    }
}

OnSensChange:
    GuiControlGet, SensSlider
    Sens := SensSlider / 100.0
    SensLabel := Round(Sens, 2)
    GuiControl,, SensText, %SensLabel%
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
    weaponName := A_GuiControl
    ControlGetText, text, %weaponName%, A
    CurrentWeapon := text
    UpdateWeaponButtonStyles()
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
    SensSliderValue := Round(Sens*100)
    SensLabel := Round(Sens, 2)
    GuiControl,, SensSlider, %SensSliderValue%
    GuiControl,, SensText, %SensLabel%
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
    UpdateWeaponButtonStyles()
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
    ; learn mode: record recoil drift while firing
    if (LearnMode) {
        static lastMouseX := 0, lastMouseY := 0
        ; Use raw OS cursor position instead of game cursor visibility.
        VarSetCapacity(pt, 8, 0)
        DllCall("GetCursorPos", "Ptr", &pt)
        mx := NumGet(pt, 0, "Int")
        my := NumGet(pt, 4, "Int")
        if (lastMouseX = 0 && lastMouseY = 0) {
            lastMouseX := mx
            lastMouseY := my
            return
        }
        dx := mx - lastMouseX
        dy := my - lastMouseY
        lastMouseX := mx
        lastMouseY := my
        if (Abs(dx) > 0 || Abs(dy) > 0) {
            AutoLearnSamples.Push({x:dx, y:dy})
            if (AutoLearnSamples.Length() > LearnWindow)
                AutoLearnSamples.RemoveAt(1)
        }
        return
    }
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
        UpdateWeaponButtonStyles()
        GuiControl,, StatusText, % "Selected: " . CurrentWeapon . " | Status: " . (Enabled ? "ON" : "OFF")
    }
}

PrevWeapon:
    global weapList, CurrentWeapon
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
    UpdateWeaponButtonStyles()
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
    UpdateWeaponButtonStyles()
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

ToggleLearnMode:
    LearnMode := !LearnMode
    GuiControl,, LearnBtn, % (LearnMode ? "Stop Learn" : "Learn")
    if (LearnMode) {
        AutoLearnSamples := []
        GuiControl,, StatusText, % "Selected: " . CurrentWeapon . " | Status: " . (Enabled ? "ON" : "OFF") . " | LEARN"
    } else {
        AutoLearnFromSamples()
        GuiControl,, StatusText, % "Selected: " . CurrentWeapon . " | Status: " . (Enabled ? "ON" : "OFF")
    }
return

AutoLearnFromSamples() {
    global AutoLearnSamples, CurrentWeapon, weapons, LearnWindow
    if (AutoLearnSamples.Length() < 4)
        return
    ; average the recoil drift (dy) over the last samples
    sumY := 0
    sumX := 0
    for i, v in AutoLearnSamples {
        sumY += v.y
        sumX += v.x
    }
    avgY := sumY / AutoLearnSamples.Length()
    avgX := sumX / AutoLearnSamples.Length()
    ; generate compensation pattern from the average direction
    stepPattern := []
    n := Max(4, Min(12, AutoLearnSamples.Length()))
    for i := 1 to n {
        stepPattern.Push( Round( -avgX / n * (i/2 + 1) ) )
    }
    ; adjust weapon profile object in-place
    if (!weapons.HasKey(CurrentWeapon))
        weapons[CurrentWeapon] := {interval:35, pattern:[0], mode:"vertical"}
    weapons[CurrentWeapon].interval := Max(15, Min(80, 35))
    weapons[CurrentWeapon].mode := "vertical"
    weapons[CurrentWeapon].pattern := []
    for i, val in stepPattern {
        weapons[CurrentWeapon].pattern.Push( Round(-avgY / Max(1, n)) )
    }
    ; keep safe range
    for i, val in weapons[CurrentWeapon].pattern {
        if (Abs(val) < 1)
            weapons[CurrentWeapon].pattern[i] := (val < 0 ? -1 : 1)
    }
    MsgBox, 64, Learning complete, Learned recoil compensation for %CurrentWeapon%.
}

; End of script
