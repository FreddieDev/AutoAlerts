#Persistent  ; Keep the script running until the user exits it.
#SingleInstance force ; Only allow one instance of this script and don't prompt on replace
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.


; Vars
global SettingsName := "AutoAlerts.ini"
global LastInitWinID :=



; Link Window change events to AHK handler
Gui +LastFound
hWnd := WinExist()
DllCall( "RegisterShellHookWindow", UInt,hWnd )
MsgNum := DllCall( "RegisterWindowMessage", Str,"SHELLHOOK" )
OnMessage( MsgNum, "ShellMessage" )



; Cleanup tray menu items
Menu, Tray, Tip, AutoAlerts

; Change the tray icon
MESSAGE_BOX_ICON := 3
Menu, Tray, Icon, shell32.dll, %MESSAGE_BOX_ICON%




ShowAutoAlertSetup() {
	Gui Font, s17 cBlack, Agency FB
	Gui Add, Text, x15 y11 w120 h23 +0x200, AutoAlerts

	Gui Font, s10, Verdana
	Gui Add, Text, x15 y36 w535 h31 +0x200, You held right shift for three seconds....
	Gui Add, Text, x16 y96 w408 h54 +0x200, How would you like to handle these alerts in the future?
	
	WinGetTitle, targetTitle, ahk_id %LastInitWinID%
	Gui Add, Text, x15 y66 w535 h31 +0x200, Target: %targetTitle%

	Gui Font
	Gui Add, Button, x13 y168 w198 h52 gAutoDismiss, Close (click the cross)
	Gui Add, Button, x229 y168 w198 h52 gAutoSelect, Auto-select an option

	Gui Show, w483 h254, AutoAlerts
}


; Runs setup to configure automatic handling of a specified window
; Returns true if setup successfully and false if setup failed/was cancelled
StartAlertRegistration(winID) {
	; Check if the window has too many controls
	; if (too many controls or no controls and cant close) {
	; 	return false
	; }
	
	LastInitWinID := winID
	
	; Ask user how they want to handle these windows in the future
	ShowAutoAlertSetup()

	return true
}

; Finds a window by its ID and uses this to compile a unique persistent way
; to identify the window across launches
; Properties used include the title, classname and text
GetWinSaveName(winID) {
	WinGetTitle, WinTitle, ahk_id %winID%
	WinGetClass, WinClass, ahk_id %winID%
	WinGetText, WinText, ahk_id %winID%
	; SaveName := WinTitle . WinClass . WinText
	SaveName := WinTitle . WinClass

	; Strip line breaks and white-space in string (these will break ini save file category titles)
	StringReplace, SaveName, SaveName, `n,,All
	StringReplace, SaveName, SaveName, `r,,All
	StringReplace, SaveName, SaveName, %A_Space%,,All
	StringReplace, SaveName, SaveName, %A_Tab%,,All

	return SaveName
}

SaveAutoAlertSettingsForWindow(winID, autoHandle, shouldDismiss, shouldDoAction:=0, actionToClick:="") {
	global

	WinSaveName := GetWinSaveName(winID)
	
	; IniWrite, value, ini settings file, category, setting name
	; Here, each window and its auto settings are saved under the window's save name
	IniWrite, %autoHandle%, %SettingsName%, %WinSaveName%, AutoHandle 			; Bool toggling entire auto settings for window
	IniWrite, %shouldDismiss%, %SettingsName%, %WinSaveName%, ShouldDismiss		; Bool toggling if window should auto-close
	IniWrite, %shouldDoAction%, %SettingsName%, %WinSaveName%, ShouldDoAction	; Bool toggling if a control should be auto-clicked
	IniWrite, %actionToClick%, %SettingsName%, %WinSaveName%, ActionToClick		; If ShouldDoAction true, this string describes the control to click
}


; Uses a window's ID to see if it has an automated settings setup to interact with it
RunSavedAction(winID) {
	global

	; Stop running if window title includes "AutoAlerts"
	WinGetTitle, windownTitle, ahk_id %winID%
	if (windownTitle = "AutoAlerts") {
		return
	}

	WinSaveName := GetWinSaveName(winID)
	MsgBox, title: %windownTitle% `r`n save name: %WinSaveName%

	; IniRead, outputVar, ini settings file, category, setting name, default value
	IniRead, autoHandle, %SettingsName%, %WinSaveName%, AutoHandle, 0
	if (!autoHandle) {
		return ; Stop running if not enabled for window
	}

	IniRead, shouldDismiss, %SettingsName%, %WinSaveName%, ShouldDismiss, 0
	if (shouldDismiss) {
		WinClose, ahk_id %winID%
		MsgBox, closed
		return
	}

	IniRead, shouldDoAction, %SettingsName%, %WinSaveName%, ShouldDoAction, 0
	if (shouldDoAction) {
		IniRead, actionToClick, %SettingsName%, %WinSaveName%, ActionToClick, ""

		if (actionToClick != "") {
			ControlGet, controlID, Hwnd,, actionToClick ; Find control's window handle by its text
			ControlClick, ahk_id %controlID% ; Click control
			return
		}
	}
}


Return




; Handler for window events
; Fires func if a window is created or focused
ShellMessage(wParam, lParam) {
	If (wParam=1 or wParam=4) ;  HSHELL_WINDOWCREATED or HSHELL_WINDOWACTIVATED
	{
		NewID := lParam
		SetTimer, NewWindowHandler, -1
	}
}


; Used to automatically interact with new windows
NewWindowHandler:
	winHand := WinExist("A")
	WinGetTitle, winTitle, A
	SplashTextOn,,, %winTitle%
	RunSavedAction(winHand)
	return


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





AutoDismiss:
	SaveAutoAlertSettingsForWindow(LastInitWinID, 1, 1)
	Gui, Destroy
	RunSavedAction(LastInitWinID)
	return

; UNFINISHED
AutoSelect:
	MsgTxt := "To select the button for auto-select, use tab to focus it then hold RIGHT SHIFT"
	MsgBox, 1, AutoAlerts, %MsgTxt%
	
	ControlGetFocus, WinSelectedControl, ahk_id %LastInitWinID%

	SaveAutoAlertSettingsForWindow(LastInitWinID, 1, 0, 1, "button1")

	RunSavedAction(LastInitWinID)
	Gui, Destroy
	return


; Add escape key hotkey to dismiss settings UI
GuiEscape:
GuiClose:
	Gui, Destroy
	return