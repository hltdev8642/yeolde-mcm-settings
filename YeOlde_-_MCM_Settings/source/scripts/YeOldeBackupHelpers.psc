; Helper functions for YeOlde backup editing and type-aware writes
ScriptName YeOldeBackupHelpers hidden

int function setTypedValue(int jMod, string keyName, string value, int a_type) global
    ; a_type: 0=string,1=int,2=float,3=bool
    if (a_type == 1)
        int iv = value as int
        JMap.setInt(jMod, keyName, iv)
        return 1
    elseif (a_type == 2)
        float fv = value as float
        JMap.setFlt(jMod, keyName, fv)
        return 1
    elseif (a_type == 3)
        int bv = (value as int)
        JMap.setInt(jMod, keyName, bv)
        return 1
    else
        JMap.setStr(jMod, keyName, value)
        return 1
    endif
endfunction

string function readAnyValueAsString(int jMod, string keyName) global
    if (JMap.hasKey(jMod, keyName))
        ; Try string first
        string s = JMap.getStr(jMod, keyName)
        if (s != "")
            return s
        endif
        int i = JMap.getInt(jMod, keyName)
        if (i != 0)
            return i as string
        endif
        float f = JMap.getFlt(jMod, keyName)
        return f as string
    endif
    return ""
endfunction

; Convenience wrappers
int function backupInt(int jMod, string keyName, int value) global
    JMap.setInt(jMod, keyName, value)
    return 1
endfunction

int function backupFlt(int jMod, string keyName, float value) global
    JMap.setFlt(jMod, keyName, value)
    return 1
endfunction

int function backupStr(int jMod, string keyName, string value) global
    JMap.setStr(jMod, keyName, value)
    return 1
endfunction

int function backupBool(int jMod, string keyName, bool value) global
    JMap.setInt(jMod, keyName, value as int)
    return 1
endfunction

function Log(string a_msg) global
    Debug.Trace("[YeOldeBackupHelpers] " + a_msg)
endFunction
