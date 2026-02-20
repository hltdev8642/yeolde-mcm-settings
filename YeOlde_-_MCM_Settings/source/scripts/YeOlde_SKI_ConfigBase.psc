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
