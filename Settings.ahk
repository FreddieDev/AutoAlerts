#SingleInstance Force

global SettingsName := "AutoAlerts.ini"
global SettingsSectionNames :=

; Create the ListView with two columns, Name and Size:
Gui Font, s10 Norm, Microsoft Sans Serif
Gui, Add, Text,, Double click entries to delete them:
Gui, Add, ListView, r20 w700 gAutoAlertEntriesList, Target|Close|Action


; Adds trailing spaces to the end of a string if the string length
; is less than that of the padding string.
; This ensures columns have a minimum width, so the listview doesn't look
; cramped if all entries are narrow
SpacePadString(strToPad) {
	maxPadding := "                    "
	if (StrLen(strToPad) < StrLen(maxPadding)) {
		return strToPad . SubStr(maxPadding, StrLen(strToPad) + 1)
	} else {
		return strToPad
	}
}

LoadAutoAlertItems() {
	global
	
	; Save section names to global var
	; This means their indexes will stay in sync if one is later deleted, even
	; if the user adds another window in the background while this GUI is open
	IniRead, SettingsSectionNames, %SettingsName%
	
	; Clear the list view
	LV_Delete()
	
	UserHasSections := false
	Loop, Parse, SettingsSectionNames, `n, `r
	{
		UserHasSections := true
		
		IniRead, autoHandle, %SettingsName%, %A_LoopField%, AutoHandle, 0
		if (!autoHandle) {
			return ; Stop running if not enabled for window
		}
		
		IniRead, readableName, %SettingsName%, %A_LoopField%, ReadableName, unnamed
		IniRead, shouldDismiss, %SettingsName%, %A_LoopField%, ShouldDismiss, 0
		IniRead, shouldDoAction, %SettingsName%, %A_LoopField%, ShouldDoAction, 0
		IniRead, actionToClick, %SettingsName%, %A_LoopField%, ActionToClick, unbound
		
		shouldDismissStr := shouldDismiss ? "ENABLED " : ""
		actionToClickStr := shouldDoAction ? actionToClick . " " : ""
		
		LV_Add("", SpacePadString(readableName . " "), SpacePadString(shouldDismissStr), SpacePadString(actionToClickStr))
	}
	
	return UserHasSections
}

LoadedItems := LoadAutoAlertItems()

if (!LoadedItems) {
	MsgBox, 16, AutoAlerts, You haven't configured AutoAlerts for any windows yet!
	return
}

LV_ModifyCol()  ; Auto-size each column to fit its contents.

; Display the window and return. The script will be notified whenever the user double clicks a row.
Gui, Show,,AutoAlerts settings
return

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
		LoadAutoAlertItems()
	}
	return