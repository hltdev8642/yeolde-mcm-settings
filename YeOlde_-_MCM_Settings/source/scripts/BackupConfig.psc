; ----------------------------------
; ModConfig
; Script managing a MCM Menu Mod configs for YeOlde-Settings
; ----------------
ScriptName BackupConfig hidden


string function GetDefaultBackupModDirectory() global
    return JContainers.userDirectory() + "yeolde-settings/mods/"
endfunction 

string[] function Mods(int jBackup) global
    return JMap.allKeysPArray(jBackup)
endfunction

int function getMod(int jBackup, string modName) global
    return JMap.getObj(jBackup, modName)
endfunction

int function addMod(int jBackup, string modName, bool overwrite = true) global
    int jResult = JMap.getObj(jBackup, modName)

    if (jResult == 0)
        jResult = ModConfig.createInstance(modName)
    endif
    
    ; Add the new option in jMod.pages map
    JMap.setObj(jBackup, modName, jResult)

    return jResult
endfunction

function RemoveModFilesFromDisk() global
    string[] files = JContainers.contentsOfDirectoryAtPath(GetDefaultBackupModDirectory())
    int i = 0
    while(i < files.Length)
        Log("RemoveModFilesFromDisk() -> " + files[i])
        JContainers.removeFileAtPath(files[i])
        i += 1
    endwhile
endfunction

int function CreateImportInstance() global
    int jResult = JValue.readFromDirectory(GetDefaultBackupModDirectory())
    JValue.retain(jResult)
    return jResult
endfunction

; Get the objet, or create a new one if not already defined
int function createInstance() global
    return JMap.object()
endfunction

; ============================================================================
; SLOT MANAGEMENT (5 named backup slots)
; ============================================================================

string function GetSlotFilePath(int slotIndex) global
    return JContainers.userDirectory() + "yeolde-settings/slot_" + slotIndex + ".json"
endfunction

; Save current active backup (mods/) to a named slot
function SaveActiveToSlot(int slotIndex, string slotName) global
    int jBackup = CreateImportInstance()
    if (jBackup == 0)
        Log("SaveActiveToSlot() -> No backup data found in mods/")
        return
    endif

    ; Add metadata
    int jMeta = JMap.object()
    JMap.setStr(jMeta, "name", slotName)
    JMap.setStr(jMeta, "timestamp", GetGameTimeString())
    JMap.setObj(jBackup, "_yeolde_meta", jMeta)

    JValue.writeToFile(jBackup, GetSlotFilePath(slotIndex))
    JValue.release(jBackup)
    Log("SaveActiveToSlot() -> Saved slot " + slotIndex + " as '" + slotName + "'")
endfunction

; Load a slot file to the active mods/ directory for restore
function LoadSlotToActive(int slotIndex) global
    string slotPath = GetSlotFilePath(slotIndex)
    if (!JContainers.fileExistsAtPath(slotPath))
        Log("LoadSlotToActive() -> Slot file not found: " + slotPath)
        return
    endif

    int jSlot = JValue.readFromFile(slotPath)
    if (jSlot == 0)
        Log("LoadSlotToActive() -> Failed to read slot file")
        return
    endif

    ; Remove meta key before writing individual mod files
    JMap.removeKey(jSlot, "_yeolde_meta")

    ; Clear current mods directory
    RemoveModFilesFromDisk()

    ; Write each mod as individual file
    string[] mods = JMap.allKeysPArray(jSlot)
    int i = 0
    while (i < mods.Length)
        int jMod = JMap.getObj(jSlot, mods[i])
        if (jMod > 0)
            JValue.writeToFile(jMod, GetDefaultBackupModDirectory() + mods[i])
        endif
        i += 1
    endwhile

    JValue.release(jSlot)
    Log("LoadSlotToActive() -> Loaded slot " + slotIndex + " to mods/")
endfunction

; Get the display name for a slot
string function GetSlotName(int slotIndex) global
    string slotPath = GetSlotFilePath(slotIndex)
    if (!JContainers.fileExistsAtPath(slotPath))
        return "<Empty>"
    endif

    int jSlot = JValue.readFromFile(slotPath)
    if (jSlot == 0)
        return "<Empty>"
    endif

    int jMeta = JMap.getObj(jSlot, "_yeolde_meta")
    if (jMeta == 0)
        JValue.release(jSlot)
        return "<No Name>"
    endif

    string name = JMap.getStr(jMeta, "name")
    JValue.release(jSlot)
    if (name == "")
        return "<No Name>"
    endif
    return name
endfunction

; Get the timestamp for a slot
string function GetSlotTimestamp(int slotIndex) global
    string slotPath = GetSlotFilePath(slotIndex)
    if (!JContainers.fileExistsAtPath(slotPath))
        return ""
    endif

    int jSlot = JValue.readFromFile(slotPath)
    if (jSlot == 0)
        return ""
    endif

    int jMeta = JMap.getObj(jSlot, "_yeolde_meta")
    if (jMeta == 0)
        JValue.release(jSlot)
        return ""
    endif

    string ts = JMap.getStr(jMeta, "timestamp")
    JValue.release(jSlot)
    return ts
endfunction

; Get number of mods in a slot
int function GetSlotModCount(int slotIndex) global
    string slotPath = GetSlotFilePath(slotIndex)
    if (!JContainers.fileExistsAtPath(slotPath))
        return 0
    endif

    int jSlot = JValue.readFromFile(slotPath)
    if (jSlot == 0)
        return 0
    endif

    int count = JMap.count(jSlot)
    ; Subtract 1 for the _yeolde_meta key if present
    if (JMap.hasKey(jSlot, "_yeolde_meta"))
        count -= 1
    endif
    JValue.release(jSlot)
    return count
endfunction

; Delete a single mod's backup file from disk
function DeleteModBackup(string modName) global
    string path = GetDefaultBackupModDirectory() + modName
    if (StringUtil.Find(modName, ".json") < 0)
        path += ".json"
    endif
    JContainers.removeFileAtPath(path)
    Log("DeleteModBackup() -> Removed: " + path)
endfunction

; Delete a slot file
function DeleteSlot(int slotIndex) global
    string path = GetSlotFilePath(slotIndex)
    JContainers.removeFileAtPath(path)
    Log("DeleteSlot() -> Removed slot " + slotIndex)
endfunction

; Delete all backup files from the mods/ directory
function DeleteAllBackups() global
    RemoveModFilesFromDisk()
    Log("DeleteAllBackups() -> All backup files removed")
endfunction

; ============================================================================
; TIMESTAMPS
; ============================================================================

; Get the current game time as a formatted string
string function GetGameTimeString() global
    float gameTime = Utility.GetCurrentGameTime()
    int totalHours = (gameTime * 24.0) as int
    int days = totalHours / 24
    int hours = totalHours - (days * 24)
    return "Day " + days + ", " + hours + ":00"
endfunction


function Log(string a_msg) global
	Debug.Trace("[BackupConfig <BackupConfigInstance (00000000)>]" + ": " + a_msg)
endFunction
