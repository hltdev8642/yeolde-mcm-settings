scriptname YeOlde_SKI_ConfigBase extends SKI_ConfigBase

; Extension layer for SKI_ConfigBase.
;
; Overrides are kept here so that the upstream SKI_ConfigBase implementation
; remains unmodified and can be updated independently.

; Override to raise the ForceTextOption iteration cap from 20 to 50.
; Some mods cycle through more than 20 text states before settling on the
; target value, causing restores to silently stall at the wrong value.
int function GetForceTextOptionMaxAttempts()
	return 50
endFunction

; Override OpenConfig to fix the Pages auto property being corrupted in saves
; whose variable layout doesn't match the current SKI_ConfigBase implementation.
; After the base sends Pages (which may be None) to Flash, we push the correct
; page names via GetPageNames(), overwriting whatever the base sent.
function OpenConfig()
	parent.OpenConfig()
	string[] p = GetPageNames()
	if (p != None && p.Length > 0)
		UI.InvokeStringA("Journal Menu", "_root.ConfigPanelFader.configPanel.setPageNames", p)
	endIf
endFunction

; Virtual: child scripts override this to supply page names.
; Returns None by default so mods without pages aren't affected.
string[] function GetPageNames()
	return None
endFunction
