; Stub for the SKSE/Skyrim Debug script - required for compilation only.
; Provides Debug.Trace and Debug.Notification used across SkyUI and YeOlde scripts.
Scriptname Debug Hidden

Function Trace(string asTextToPrint, int aiSeverity = 0) native global
Function Notification(string asNotification) native global
Function MessageBox(string asMessageBoxText) native global
