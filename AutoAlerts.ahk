#Persistent  ; Keep the script running until the user exits it.
#SingleInstance force ; Only allow one instance of this script and don't prompt on replace
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

#Include lib\Settings.ahk

OnWinActiveChange(hWinEventHook, vEvent, hWnd)
{
	;EVENT_SYSTEM_FOREGROUND := 0x3
	static _ := DllCall("user32\SetWinEventHook", UInt,0x3, UInt,0x3, Ptr,0, Ptr,RegisterCallback("OnWinActiveChange"), UInt,0, UInt,0, UInt,0, Ptr)
	DetectHiddenWindows, On

	; Display debugging tooltip of currently focused window's handle
	; WinGetClass, vWinClass, % "ahk_id " hWnd
	; ToolTip, % vWinClass

	winHand := WinExist("A")
	RunSavedAction(winHand)
}

; Vars
global SettingsName := "AutoAlerts.ini"
global LastInitWinID :=
global AutoClickActionTarget :=
global AutoClickActionWHnd :=
global RunOnSave :=

; Control vars
global NewAutoAlertAutoDismiss :=
global NewAutoAlertAutoSelect :=


; Cleanup tray menu items
Menu, Tray, Tip, AutoAlerts

; Change the tray icon
MESSAGE_BOX_ICON := 3
Menu, Tray, Icon, shell32.dll, %MESSAGE_BOX_ICON%
Menu, Tray, NoStandard

; Add credits button
MenuAboutText := "About"
Menu, Tray, Add, %MenuAboutText%, MenuHandler

; Add change settings button
MenuChangeSettingsText := "Change settings"
Menu, Tray, Add, %MenuChangeSettingsText%, MenuHandler

; Creates a separator line
Menu, Tray, Add

; Add option to reload the current script (in case changes were made)
MenuReloadScriptText := "Restart"
Menu, Tray, Add, %MenuReloadScriptText%, MenuHandler

; Add option to exit the current script
MenuExitScriptText := "Exit"
Menu, Tray, Add, %MenuExitScriptText%, MenuHandler

; Set default menu option (double click tray icon to fire)
Menu, Tray, Default, %MenuChangeSettingsText%



ShowAutoAlertSetup() {
	Gui Destroy ; Cleanup existing GUIs
	
	Gui Font, s17 cBlack, Agency FB
	Gui Add, Text, x15 y11 w120 h23 +0x200, AutoAlerts

	Gui Font, s9, Verdana
	Gui Add, Text, x15 y33 w535 h18 +0x200, You held right shift for three seconds....
	Gui Add, Text, x16 y96 w408 h18 +0x200, How would you like this window handled in the future?
	
	Gui Font, s12, Consolas
	targetName := GetHumanReadableName(LastInitWinID)
	Gui Add, Text, x15 y66 w535 h31 +0x200, Window: %targetName%

	Gui Font
	; Gui Add, Button, x13 y168 w188 h42 gAutoDismiss, Auto-dismiss (click the cross)
	; Gui Add, Button, x229 y168 w178 h42 gAutoSelect, Auto-click a button
	
	Gui Add, Radio, x22 y118 w166 h23 vNewAutoAlertAutoDismiss +Checked, Auto-dismiss (click the cross)
	Gui Add, Radio, x22 y138 w120 h23 vNewAutoAlertAutoSelect, Auto-click a button
	
	Gui Add, Button, x213 y205 w80 h23 gSaveNewAutoAlert, Save
	Gui Add, Button, x301 y205 w80 h23 gSaveAndRunNewAutoAlert, Save and run
	Gui Add, Button, x388 y205 w80 h23 gCancelNewAutoAlert, Cancel

	Gui Show, w483 h244, AutoAlerts - %targetName%
}


; Runs setup to configure automatic handling of a specified window
; Returns true if setup successfully and false if setup failed/was cancelled
StartAlertRegistration(winID) {
	
	if (!IsWindowValid(winID)) {
		return
	}
	
	LastInitWinID := winID
	
	; Ask user how they want to handle these windows in the future
	ShowAutoAlertSetup()

	return true
}

; Finds a window by its ID and uses this to compile a unique persistent way
; to identify the window across launches
; Properties used include the process (exe) name, title, classname and text
GetWinSaveName(winID) {
	WinGet, WinProcPath, ProcessPath, ahk_id %winID%
	WinGet, WinControlList, ControlList, ahk_id %winID%
	WinGetClass, WinClass, ahk_id %winID%
	; WinGetPos, WinXPos, WinYPos, WinWidth, WinHeight, ahk_id %winID%
	; WinGetTitle, WinTitle, ahk_id %winID%
	; WinGetText, WinText, ahk_id %winID%
	SaveName := WinProcPath . WinClass . WinControlList ; Note title and text can take time to load and may be empty

	; Strip line breaks and white-space in string (these will break ini save file category titles)
	StringReplace, SaveName, SaveName, `n,,All
	StringReplace, SaveName, SaveName, `r,,All
	StringReplace, SaveName, SaveName, %A_Space%,,All
	StringReplace, SaveName, SaveName, %A_Tab%,,All

	return SaveName
}

; Takes a window handle and makes a semi-unique string for humans to
; easily read and understand the purpose of an AutoAlert setting
GetHumanReadableName(winID) {
	WinGet, winProcName, ProcessName, ahk_id %winID%
	WinGetTitle, winTitle, ahk_id %winID%
	return StrReplace(winProcName, ".exe") . " (" . winTitle . ")"
}

; Takes auto alert settings for a window and saves them to settings file
SaveAutoAlertSettingsForWindow(winID, autoHandle, shouldDismiss, shouldDoAction:=0, actionToClick:="") {
	global

	WinSaveName := GetWinSaveName(winID)
	ReadableName := GetHumanReadableName(winID)
	
	; IniWrite, value, ini settings file, category, setting name
	; Here, each window and its auto settings are saved under the window's save name
	IniWrite, %ReadableName%, %SettingsName%, %WinSaveName%, ReadableName 		; Human-readable string to represent the name of the auto-alert entry
	IniWrite, %autoHandle%, %SettingsName%, %WinSaveName%, AutoHandle 			; Bool toggling entire auto settings for window
	IniWrite, %shouldDismiss%, %SettingsName%, %WinSaveName%, ShouldDismiss		; Bool toggling if window should auto-close
	IniWrite, %shouldDoAction%, %SettingsName%, %WinSaveName%, ShouldDoAction	; Bool toggling if a control should be auto-clicked
	IniWrite, %actionToClick%, %SettingsName%, %WinSaveName%, ActionToClick		; If ShouldDoAction true, this string describes the control to click
}


; Returns true if window is valid for automation
IsWindowValid(winID) {

	; Check if the window has too many controls
	; if (too many controls or no controls and cant close) {
	; 	return false
	; }
	
	; Stop running if window title includes "AutoAlerts"
	WinGetTitle, windownTitle, ahk_id %winID%
	if (InStr(windownTitle, "AutoAlerts")) {
		return false
	}
	
	return true
}


; Uses a window's ID to see if it has an automated settings setup to interact with it
RunSavedAction(winID) {
	global
	
	if (!IsWindowValid(winID)) {
		return
	}

	WinSaveName := GetWinSaveName(winID)

	; MsgBox, title: %windownTitle% `r`n save name: %WinSaveName%

	; IniRead, outputVar, ini settings file, category, setting name, default value
	IniRead, autoHandle, %SettingsName%, %WinSaveName%, AutoHandle, 0
	if (!autoHandle) {
		return ; Stop running if not enabled for window
	}

	IniRead, shouldDismiss, %SettingsName%, %WinSaveName%, ShouldDismiss, 0
	if (shouldDismiss) {
		WinClose, ahk_id %winID%
		SoundPlay, %A_WinDir%\media\Speech Misrecognition.wav
		return
	}

	IniRead, shouldDoAction, %SettingsName%, %WinSaveName%, ShouldDoAction, 0
	if (shouldDoAction) {
		IniRead, actionToClick, %SettingsName%, %WinSaveName%, ActionToClick, unbound

		if (actionToClick != "") {
			ControlClick, %actionToClick%, ahk_id %winID%,,,,NA ; Click control
			SoundPlay, %A_WinDir%\media\Speech Misrecognition.wav

			return
		}
	}
}



SaveNewAutoAlert() {
	Gui, Submit ; Save the input from the user to each control's associated variable.
	
	if (NewAutoAlertAutoDismiss) {
		SaveAutoAlertSettingsForWindow(LastInitWinID, 1, 1)
		if (RunOnSave) {
			RunSavedAction(LastInitWinID)
		}
	} else {
		MsgTxt := "To select the button for auto-select, use tab to focus it then tap LEFT SHIFT"
		MsgBox, 1, AutoAlerts, %MsgTxt%

		IfMsgBox, OK
		{
			Hotkey, ~$LShift, RegisterAutoSelect, On
		} else {
			return
		}
	}
	Gui, Destroy
}



Return


~RShift::
	If rShiftIsPressed
		return
	rShiftIsPressed := true
	SetTimer, WaitForRelease, 1000		; 2 seconds
	return
~RShift Up::
	SetTimer, WaitForRelease, Off
	rShiftIsPressed := false
	return
WaitForRelease:
	SetTimer, WaitForRelease, Off
	StartAlertRegistration(WinExist("A")) ; Register focused window's handle
	return



RegisterAutoSelect:
	; Get the currently focused control for the target window
	ControlGetFocus, WinSelectedControl, ahk_id %LastInitWinID%
	if (WinSelectedControl = "") {
		return
	}
	
	Hotkey, ~$LShift, RegisterAutoSelect, Off ; Disable hotkey
	SaveAutoAlertSettingsForWindow(LastInitWinID, 1, 0, 1, WinSelectedControl) ; Save control
	if (RunOnSave) {
		RunSavedAction(LastInitWinID) ; Run the action
	}

	return


SaveNewAutoAlert:
	RunOnSave := false
	SaveNewAutoAlert()
	return
	
SaveAndRunNewAutoAlert:
	RunOnSave := true
	SaveNewAutoAlert()
	return


; Add escape key hotkey to dismiss settings UI
GuiEscape:
CancelNewAutoAlert:
GuiClose:
	Gui, Destroy
	return


; handler for setting being double clicked
AutoAlertEntriesList:
	if (A_GuiEvent = "DoubleClick")
	{
		if (A_EventInfo < 1) {
			return
		}
		
		sectionNamesArray := StrSplit(SettingsSectionNames, "`n")
		sectionToDelete := sectionNamesArray[A_EventInfo]
		IniRead, readableName, %SettingsName%, %sectionToDelete%, ReadableName, unnamed
		MsgBox, 4, AutoAlerts, Are you sure you want to delete %readableName%?
		
		IfMsgBox No
			return
		
		; Delete the section and reload the list view entries
		IniDelete, %SettingsName%, %sectionToDelete%
		Settings.LoadAutoAlertItems()
	}
	return




MenuHandler:
	if (A_ThisMenuItem = MenuReloadScriptText) {
		Reload
		return
	} else if (A_ThisMenuItem = MenuExitScriptText) {
		ExitApp
	} else if (A_ThisMenuItem = MenuChangeSettingsText) {
		Settings.Change()
	} else if (A_ThisMenuItem = MenuAboutText) {
		MsgBox,0, AutoAlerts Credits, Created by Freddie Chessell`, 2020
	}

	return
