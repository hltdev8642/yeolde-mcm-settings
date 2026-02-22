scriptname yeolde_mcm_settings extends YeOlde_SKI_ConfigBase

import Game

; ============================================================================
; VARIABLES
; ============================================================================

string[]        _modNames
bool[]          _modEnableFlags
int[]           _modMenuToggle
int[]           _modMenuBackupInfos
int             _modMenuBackupInfosIndex
int             _modMenuBackupInfosNbSup = 0

int[]           _modBlacklistToggle
bool[]          _modBlacklistEnableFlags

; Backup Slot Variables (Feature 4 + 5)
int             _selectedSlotIndex = 0
string[]        _slotDisplayNames

; Edit Backups Variables (Feature 7 - UX Overhaul)
int             _lastImportedBackup = 0
string          _lastEditRaw = ""
string[]        _editModList
string[]        _editKeyList
int             _editSelectedModIdx = -1
int             _editSelectedKeyIdx = -1
string          _editNewValue = ""
int             _editType = 0 ; 0=string,1=int,2=float,3=bool
int             _editModCountOpt = 0
int             _editKeyCountOpt = 0
int             _editCurrentValueOpt = 0

; Nested (paged) edit data tracking
bool            _editIsNested = false
string[]        _editPageList
int             _editSelectedPageIdx = -1
string[]        _editOptionIds
int             _editPageCountOpt = 0

; Per-Mod Backup Variables (Feature 6)
string[]        _perModNames
int             _perModSelectedIdx = -1

; Mod Search Variables (Feature 9)
string          _modSearchFilter = ""

; Edit Type Names
string[]        _editTypeNames

string property COLOR_BACKUP_PATCH_NEEDED = "#F1BC7A" autoreadonly hidden
string property COLOR_BACKUP_PATCH_OK = "#92F1AA" autoreadonly hidden
string property COLOR_BACKUP_SELF_BACKUP = "#777777" autoreadonly hidden
string property COLOR_BACKUP_FAIL = "#d45858" autoreadonly hidden
string property COLOR_BACKUP_UNKNOWN = "#DDDDDD" autoreadonly hidden


; ============================================================================
; INITIALIZATION
; ============================================================================

; Version 7 = v12: bypass corrupted Pages property via GetPageNames()
int function GetVersion()
    return 7
endFunction

; @overrides SKI_ConfigBase
event OnConfigInit()
    Debug.Trace(self + ": OnConfigInit()")
    InitializeVariables()
endEvent

; Called automatically when GetVersion() returns a higher number than saved
event OnVersionUpdate(int a_version)
    Debug.Trace(self + ": OnVersionUpdate(" + a_version + ")")
    if (a_version >= 2)
        InitializeVariables()
    endif
endEvent

; @implements SKI_QuestBase
event OnGameReload()
    Debug.Trace(self + ": OnGameReload() START")
    parent.OnGameReload()
    EnsurePages()
    EnsureCriticalArrays()

    ; Ensure slot display names are initialized.
    if (_slotDisplayNames == None || _slotDisplayNames.Length != 5)
        _slotDisplayNames = new String[5]
        _slotDisplayNames[0] = "Slot 1 (empty)"
        _slotDisplayNames[1] = "Slot 2 (empty)"
        _slotDisplayNames[2] = "Slot 3 (empty)"
        _slotDisplayNames[3] = "Slot 4 (empty)"
        _slotDisplayNames[4] = "Slot 5 (empty)"
    endif
    Debug.Trace(self + ": OnGameReload() DONE")
endEvent

; Pages are now supplied via GetPageNames() override in OpenConfig().
; The Pages auto property is not written to — it can be corrupted in saves
; when the parent script's variable layout changes between versions.
function EnsurePages()
    ; no-op: GetPageNames() supplies page names directly to OpenConfig()
endFunction

; Override parent virtual to supply page names without writing to the
; Pages auto property, which avoids save-game variable corruption.
string[] function GetPageNames()
    string[] p = new String[5]
    p[0] = "Show/hide menus"
    p[1] = "Backup/Restore menus"
    p[2] = "Backup Mod selection"
    p[3] = "Debugging options"
    p[4] = "Edit Backups"
    return p
endFunction

; Guarantee all working arrays exist. Prevents None-array crashes if
; InitializeVariables() was skipped (same version) or save data was lost.
function EnsureCriticalArrays()
    if (_modMenuToggle == None || _modMenuToggle.Length != 128)
        _modMenuToggle = Utility.CreateIntArray(128, 0)
    endif
    if (_modBlacklistToggle == None || _modBlacklistToggle.Length != 128)
        _modBlacklistToggle = Utility.CreateIntArray(128, 0)
    endif
    if (_modBlacklistEnableFlags == None || _modBlacklistEnableFlags.Length != 128)
        _modBlacklistEnableFlags = Utility.CreateBoolArray(128)
    endif
    if (_editTypeNames == None || _editTypeNames.Length != 4)
        _editTypeNames = new String[4]
        _editTypeNames[0] = "String"
        _editTypeNames[1] = "Int"
        _editTypeNames[2] = "Float"
        _editTypeNames[3] = "Bool"
    endif
    if (_slotDisplayNames == None || _slotDisplayNames.Length != 5)
        _slotDisplayNames = new String[5]
        _slotDisplayNames[0] = "Slot 1 (empty)"
        _slotDisplayNames[1] = "Slot 2 (empty)"
        _slotDisplayNames[2] = "Slot 3 (empty)"
        _slotDisplayNames[3] = "Slot 4 (empty)"
        _slotDisplayNames[4] = "Slot 5 (empty)"
    endif
endFunction

; Shared init logic used by both OnConfigInit and OnVersionUpdate
function InitializeVariables()
    _modMenuToggle = Utility.CreateIntArray(128, 0)
    _modBlacklistToggle = Utility.CreateIntArray(128, 0)
    _modBlacklistEnableFlags = Utility.CreateBoolArray(128)
    _modMenuBackupInfosIndex = 0

    _editTypeNames = new String[4]
    _editTypeNames[0] = "String"
    _editTypeNames[1] = "Int"
    _editTypeNames[2] = "Float"
    _editTypeNames[3] = "Bool"

    _slotDisplayNames = new String[5]
    _slotDisplayNames[0] = "Slot 1 (empty)"
    _slotDisplayNames[1] = "Slot 2 (empty)"
    _slotDisplayNames[2] = "Slot 3 (empty)"
    _slotDisplayNames[3] = "Slot 4 (empty)"
    _slotDisplayNames[4] = "Slot 5 (empty)"

    _selectedSlotIndex = 0
    _editSelectedModIdx = -1
    _editSelectedKeyIdx = -1
    _editIsNested = false
    _editPageList = None
    _editSelectedPageIdx = -1
    _editOptionIds = None
    _perModSelectedIdx = -1
    _modSearchFilter = ""
    _editNewValue = ""
    _editType = 0
    _lastEditRaw = ""

    ; Pages are set via GetPageNames() override — do not write to Pages property.
endFunction


; ============================================================================
; INLINE HELPERS (replaces dead YeOldeBackupHelpers calls)
; ============================================================================

; Read any JMap value as a display string
string function ReadValueAsString(int jObj, string keyName)
    if (!JMap.hasKey(jObj, keyName))
        return ""
    endif
    string s = JMap.getStr(jObj, keyName)
    if (s != "")
        return s
    endif
    int iv = JMap.getInt(jObj, keyName)
    if (iv != 0)
        return iv as string
    endif
    float fv = JMap.getFlt(jObj, keyName)
    if (fv != 0.0)
        return fv as string
    endif
    return "0"
endfunction

; Set a typed value in a JMap
function SetTypedValue(int jObj, string keyName, string value, int a_type)
    if (a_type == 1)
        JMap.setInt(jObj, keyName, value as int)
    elseif (a_type == 2)
        JMap.setFlt(jObj, keyName, value as float)
    elseif (a_type == 3)
        if (value == "1" || value == "true" || value == "True")
            JMap.setInt(jObj, keyName, 1)
        else
            JMap.setInt(jObj, keyName, 0)
        endif
    else
        JMap.setStr(jObj, keyName, value)
    endif
endfunction

; Read value from a nested (paged) backup option
string function ReadNestedOptionValue(int jMod, string pageName, string optId)
    int jPage = JMap.getObj(jMod, pageName)
    if (jPage <= 0)
        return ""
    endif
    int jOpt = JMap.getObj(jPage, optId)
    if (jOpt <= 0)
        return ""
    endif
    string sv = JMap.getStr(jOpt, "strValue")
    float fv = JMap.getFlt(jOpt, "fltValue")
    if (sv != "")
        return sv
    endif
    return fv as string
endfunction

; Write value to a nested (paged) backup option
function WriteNestedOptionValue(int jMod, string pageName, string optId, string value, int a_type)
    int jPage = JMap.getObj(jMod, pageName)
    if (jPage <= 0)
        return
    endif
    int jOpt = JMap.getObj(jPage, optId)
    if (jOpt <= 0)
        return
    endif
    if (a_type == 0)
        JMap.setStr(jOpt, "strValue", value)
    elseif (a_type == 1)
        JMap.setFlt(jOpt, "fltValue", value as float)
    elseif (a_type == 2)
        JMap.setFlt(jOpt, "fltValue", value as float)
    elseif (a_type == 3)
        if (value == "1" || value == "true" || value == "True")
            JMap.setFlt(jOpt, "fltValue", 1.0)
        else
            JMap.setFlt(jOpt, "fltValue", 0.0)
        endif
    endif
endfunction

; Refresh slot display names from disk
function RefreshSlotNames()
    if (_slotDisplayNames == None || _slotDisplayNames.Length != 5)
        _slotDisplayNames = new String[5]
        _slotDisplayNames[0] = "Slot 1 (empty)"
        _slotDisplayNames[1] = "Slot 2 (empty)"
        _slotDisplayNames[2] = "Slot 3 (empty)"
        _slotDisplayNames[3] = "Slot 4 (empty)"
        _slotDisplayNames[4] = "Slot 5 (empty)"
    endif
    int i = 0
    while (i < 5)
        string name = BackupConfig.GetSlotName(i)
        string ts = BackupConfig.GetSlotTimestamp(i)
        if (name == "<Empty>")
            _slotDisplayNames[i] = "Slot " + (i + 1) + " (empty)"
        else
            int mCount = BackupConfig.GetSlotModCount(i)
            string label = name
            if (mCount > 0)
                label += " (" + mCount + " mods)"
            endif
            if (ts != "")
                label += " [" + ts + "]"
            endif
            _slotDisplayNames[i] = label
        endif
        i += 1
    endwhile
endfunction


; @implements SKI_ConfigBase
event OnPageReset(string a_page)
	{Called when a new page is selected, including the initial empty page}
    Debug.Trace(self + ": OnPageReset('" + a_page + "')")

    ; Guarantee all 5 tabs are registered before SKI pushes Pages to the UI.
    ; OpenConfig() calls OnPageReset("") BEFORE .setPageNames(Pages), so this
    ; is the correct timing to fix a stale Pages array from an older save.
    EnsurePages()

    if a_page == ""
		self.LoadCustomContent("yeolde/settings_splash.dds", 0.000000, 0.000000)
		return
    endIf

    self.UnloadCustomContent()

    ; Guarantee all working arrays exist before any page logic.
    EnsureCriticalArrays()

    ; Safety: if ConfigManager isn't ready yet, show a wait message
    if (ConfigManager == None)
        Debug.Trace(self + ": ConfigManager is None")
        AddHeaderOption("MCM is still loading...")
        AddTextOption("Please close and reopen MCM.", "")
        return
    endif

    _modNames = ConfigManager.GetAllModNames()
    _modEnableFlags = ConfigManager.GetAllEnabledModFlags()

    if (_modNames == None || _modNames.Length == 0)
        Debug.Trace(self + ": No mods from ConfigManager")
        AddHeaderOption("No MCM mods detected")
        return
    endif

    Debug.Trace(self + ": " + _modNames.Length + " mods, building '" + a_page + "'")

    int jModNames = JArray.objectWithStrings(_modNames)
    string[] sortedModNames
    if (jModNames > 0)
        JArray.unique(jModNames)
        int emptyIndex = JArray.findStr(jModNames, "")
        if (emptyIndex >= 0)
            JArray.eraseIndex(jModNames, emptyIndex)
        endif
        sortedModNames = JArray.asStringArray(jModNames)
    endif

    ; Fallback: if JContainers failed or the array collapsed, use the raw mod list
    if (sortedModNames == None || sortedModNames.Length == 0)
        Debug.Trace(self + ": JArray processing failed (handle=" + jModNames + "), using raw mod list")
        sortedModNames = _modNames
    endif
    int nbMods = sortedModNames.Length
    if a_page == "Show/hide menus"

        ;; Search filter + headers
        SetCursorFillMode(TOP_TO_BOTTOM)
        AddInputOptionST("ModSearchFilter", "Search mods:", _modSearchFilter, 0)
        AddHeaderOption("Available MCM Menus")

        ;; Build filtered mod list
        int filteredCount = 0
        string[] filteredMods = Utility.CreateStringArray(128, "")
        int fi = 0
        while (fi < nbMods)
            bool matchFilter = false
            if (_modSearchFilter == "")
                matchFilter = true
            elseif (StringUtil.Find(sortedModNames[fi], _modSearchFilter) >= 0)
                matchFilter = true
            endif
            if (matchFilter)
                filteredMods[filteredCount] = sortedModNames[fi]
                filteredCount += 1
            endif
            fi += 1
        endwhile

        ;; 1st column: first half of filtered mods
        int i = 0
        while (i < filteredCount / 2)
            int modIndex = _modNames.Find(filteredMods[i])
            if (modIndex > -1)
                int flag = OPTION_FLAG_NONE
                if (_modNames[modIndex] == self.ModName)
                    flag = OPTION_FLAG_DISABLED
                endif
                _modMenuToggle[modIndex] = AddToggleOption(_modNames[modIndex], _modEnableFlags[modIndex], flag)
            endif
            i += 1
        endwhile

        ;; 2nd column
        SetCursorPosition(1)
        AddEmptyOption()
        AddHeaderOption("")

        while (i < filteredCount)
            int modIndex = _modNames.Find(filteredMods[i])
            if (modIndex > -1)
                int flag = OPTION_FLAG_NONE
                if (_modNames[modIndex] == self.ModName)
                    flag = OPTION_FLAG_DISABLED
                endif
                _modMenuToggle[modIndex] = AddToggleOption(_modNames[modIndex], _modEnableFlags[modIndex], flag)
            endif
            i += 1
        endwhile

    elseif a_page == "Backup/Restore menus"
        Quest qLAL = Quest.GetQuest("ARTHLALChargenQuest")
        Quest qUnbound = Quest.GetQuest("SkyrimUnbound")

        if (qLAL && !qLAL.IsCompleted())
            SetCursorFillMode(TOP_TO_BOTTOM)
            AddTextOption("'Live Another Life' intro must be completed", "")
            AddTextOption("before using the backup/restore tool", "")
        elseIf (qUnbound && !qUnbound.IsCompleted())
            SetCursorFillMode(TOP_TO_BOTTOM)
            AddTextOption("'Skyrim Unbound' intro must be completed", "")
            AddTextOption("before using the backup/restore tool", "")
        else
            SetCursorFillMode(LEFT_TO_RIGHT)

            ; Main backup/restore buttons
            AddTextOptionST("MCMValuesBackup", "Backup all configs", "Press to backup")
            AddTextOptionST("ImportMCMValues", "Restore all configs", "Press to restore")

            ; Backup Slots Section (Features 4 + 5)
            AddHeaderOption("Backup Slots")
            AddHeaderOption("")

            RefreshSlotNames()
            AddMenuOptionST("SlotSelector", "Active Slot", _slotDisplayNames[_selectedSlotIndex])
            string slotTs = BackupConfig.GetSlotTimestamp(_selectedSlotIndex)
            if (slotTs == "")
                slotTs = "(no backup)"
            endif
            AddTextOption("Last Backup", slotTs)

            AddInputOptionST("SlotNameInput", "Rename Slot", BackupConfig.GetSlotName(_selectedSlotIndex), 0)
            AddTextOptionST("DeleteSlot", "Delete Slot", "Press")

            AddTextOptionST("LoadSlot", "Load Slot for Restore", "Press")
            int slotModCount = BackupConfig.GetSlotModCount(_selectedSlotIndex)
            AddTextOption("Mods in Slot", slotModCount as string)

            ; Per-Mod Section (Feature 6)
            AddHeaderOption("Per-Mod Backup/Restore")
            AddHeaderOption("")

            _perModNames = sortedModNames
            string perModDisplay = "(none)"
            if (_perModSelectedIdx >= 0 && _perModSelectedIdx < _perModNames.Length)
                perModDisplay = _perModNames[_perModSelectedIdx]
            endif
            AddMenuOptionST("PerModSelector", "Select Mod", perModDisplay)
            AddEmptyOption()
            AddTextOptionST("PerModBackup", "Backup this mod", "Press")
            AddTextOptionST("PerModRestore", "Restore this mod", "Press")

            ; Status Section
            AddHeaderOption("Task Status")
            AddHeaderOption("")

            _modMenuBackupInfos = Utility.CreateIntArray(nbMods, 0)
            int iInfo = 0
            while (iInfo < nbMods)
                _modMenuBackupInfos[iInfo] = AddTextOption("", "", OPTION_FLAG_HIDDEN)
                iInfo += 1
            endwhile
        endIf

    elseif a_page == "Backup Mod selection"
        int jConfig = YeOldeConfig.Load()
        if (YeOldeConfig.isNewFileVersionAvailable(jConfig))
            bool doContinue = ShowMessage("A new patch list is available. Do you want to update your file to the latest version?")
            if (doContinue)
                JValue.release(jConfig)
                JValue.zeroLifetime(jConfig)
                jConfig = YeOldeConfig.CreateDefaultConfigFile()
            endif
        endif

        int jModSelection = JValue.readFromFile(YeOldeConfig.GetDefaultModSelectionFilePath())

        if (jModSelection == 0)
            jModSelection = JArray.object()
        endif

        ;; 1st column
        SetCursorFillMode(TOP_TO_BOTTOM)
        AddTextOptionST("DefaultModSelectionList", "Reset Selection to default", "Set to default")
        AddEmptyOption()
        AddHeaderOption("Backup Selection")

        int i = 0
        while (i < sortedModNames.Length / 2)
            int modIndex = _modNames.Find(sortedModNames[i])
            string color = COLOR_BACKUP_UNKNOWN
            if (modIndex > -1)
                if (YeOldeConfig.isModNeedPatch(jConfig, _modNames[modIndex]))
                    if (ConfigManager.IsBackupRestorePatchActive(_modNames[modIndex], modIndex))
                        color = COLOR_BACKUP_PATCH_OK
                    else
                        color = COLOR_BACKUP_PATCH_NEEDED
                    endif
                elseif (YeOldeConfig.isModWillFail(jConfig, _modNames[modIndex]))
                        color = COLOR_BACKUP_FAIL
                elseif (YeOldeConfig.isModSelfBackup(jConfig, _modNames[modIndex]))
                        color = COLOR_BACKUP_SELF_BACKUP
                elseif (YeOldeConfig.isModOK(jConfig, _modNames[modIndex]) || YeOldeConfig.isModNeedInternalPatch(jConfig, _modNames[modIndex]))
                        color = COLOR_BACKUP_PATCH_OK
                endif
                string name = "<font color='"+ color + "'>" + _modNames[modIndex] + "</font>"
                _modBlacklistEnableFlags[modIndex] = (JArray.findStr(jModSelection, sortedModNames[i]) > -1)
                _modBlacklistToggle[modIndex] = AddToggleOption(name, _modBlacklistEnableFlags[modIndex])
            endif
            i += 1
        endwhile

        JValue.release(jModSelection)
        JValue.zeroLifetime(jModSelection)

        ;; 2nd column
        SetCursorPosition(1)
        AddTextOption("Legend: | <font color='" + COLOR_BACKUP_SELF_BACKUP + "'>Self backup system</font> | <font color='" + COLOR_BACKUP_UNKNOWN + "'>Status unknown</font> |", "")
        AddTextOption("      | <font color='" + COLOR_BACKUP_PATCH_NEEDED + "'>Patch available</font> | <font color='" + COLOR_BACKUP_PATCH_OK + "'>Mod OK</font> | <font color='" + COLOR_BACKUP_FAIL + "'>Not compatible</font> |", "")
        AddHeaderOption("")

        while (i < sortedModNames.Length)
            int modIndex = _modNames.Find(sortedModNames[i])
            string color = COLOR_BACKUP_UNKNOWN
            if (modIndex > -1)
                if (YeOldeConfig.isModNeedPatch(jConfig, _modNames[modIndex]))
                    if (ConfigManager.IsBackupRestorePatchActive(_modNames[modIndex], modIndex))
                        color = COLOR_BACKUP_PATCH_OK
                    else
                        color = COLOR_BACKUP_PATCH_NEEDED
                    endif
                elseif (YeOldeConfig.isModWillFail(jConfig, _modNames[modIndex]))
                        color = COLOR_BACKUP_FAIL
                elseif (YeOldeConfig.isModSelfBackup(jConfig, _modNames[modIndex]))
                        color = COLOR_BACKUP_SELF_BACKUP
                elseif (YeOldeConfig.isModOK(jConfig, _modNames[modIndex]) || YeOldeConfig.isModNeedInternalPatch(jConfig, _modNames[modIndex]))
                        color = COLOR_BACKUP_PATCH_OK
                endif
                string name = "<font color='"+ color + "'>" + _modNames[modIndex] + "</font>"
                _modBlacklistEnableFlags[modIndex] = (JArray.findStr(jModSelection, sortedModNames[i]) > -1)
                _modBlacklistToggle[modIndex] = AddToggleOption(name, _modBlacklistEnableFlags[modIndex])
            endif
            i += 1
        endwhile

    elseif a_page == "Debugging options"
        SetCursorFillMode(TOP_TO_BOTTOM)
        AddHeaderOption("MCM menus visibility")
        AddTextOptionST("ForceMCMReset", "Show all MCM menus", "Press to reset")
    elseif a_page == "Edit Backups"
        SetCursorFillMode(LEFT_TO_RIGHT)

        ; Row 1: Section headers
        AddHeaderOption("Backup Editor")
        AddHeaderOption("Info")

        ; Row 2: Import + mod count
        AddTextOptionST("EditImport", "Import Backups", "Press to import")
        int modCount = 0
        if (_editModList != None)
            modCount = _editModList.Length
        endif
        _editModCountOpt = AddTextOption("Mods in backup", modCount as string)

        ; Row 3: Mod selector + key count
        string currentModName = "(none)"
        if (_editSelectedModIdx >= 0 && _editModList != None && _editSelectedModIdx < _editModList.Length)
            currentModName = _editModList[_editSelectedModIdx]
        endif
        AddMenuOptionST("EditSelectMod", "Select Mod", currentModName)
        int keyCount = 0
        if (_editKeyList != None)
            keyCount = _editKeyList.Length
        endif
        _editKeyCountOpt = AddTextOption("Keys", keyCount as string)

        ; Row 4: Page selector (for nested/paged mod data)
        string currentPageName = "(n/a)"
        if (_editIsNested)
            if (_editSelectedPageIdx >= 0 && _editPageList != None && _editSelectedPageIdx < _editPageList.Length)
                currentPageName = _editPageList[_editSelectedPageIdx]
            else
                currentPageName = "(select page)"
            endif
        endif
        AddMenuOptionST("EditSelectPage", "Select Page", currentPageName)
        int pageCount = 0
        if (_editPageList != None)
            pageCount = _editPageList.Length
        endif
        _editPageCountOpt = AddTextOption("Pages", pageCount as string)

        ; Row 5: Key selector
        string currentKeyName = "(none)"
        if (_editSelectedKeyIdx >= 0 && _editKeyList != None && _editSelectedKeyIdx < _editKeyList.Length)
            currentKeyName = _editKeyList[_editSelectedKeyIdx]
        endif
        AddMenuOptionST("EditSelectKey", "Select Key", currentKeyName)
        AddEmptyOption()

        ; Row 6: Current value display
        string currentVal = ""
        if (_editSelectedModIdx >= 0 && _editSelectedKeyIdx >= 0 && _lastImportedBackup > 0)
            if (_editModList != None && _editKeyList != None)
                if (_editSelectedModIdx < _editModList.Length && _editSelectedKeyIdx < _editKeyList.Length)
                    int jMod = JMap.getObj(_lastImportedBackup, _editModList[_editSelectedModIdx])
                    if (jMod > 0)
                        if (_editIsNested && _editPageList != None && _editSelectedPageIdx >= 0 && _editOptionIds != None)
                            if (_editSelectedKeyIdx < _editOptionIds.Length)
                                currentVal = ReadNestedOptionValue(jMod, _editPageList[_editSelectedPageIdx], _editOptionIds[_editSelectedKeyIdx])
                            endif
                        else
                            currentVal = ReadValueAsString(jMod, _editKeyList[_editSelectedKeyIdx])
                        endif
                    endif
                endif
            endif
        endif
        _editCurrentValueOpt = AddTextOption("Current Value", currentVal)
        AddEmptyOption()

        ; Row 6: Edit section headers
        AddHeaderOption("Edit Value")
        AddHeaderOption("Actions")

        ; Row 7: Value type dropdown + delete mod button
        AddMenuOptionST("EditValueType", "Value Type", _editTypeNames[_editType])
        AddTextOptionST("EditDeleteMod", "Delete Mod Backup", "Press")

        ; Row 8: New value input + delete all button
        AddInputOptionST("EditNewValue", "New Value", _editNewValue, 0)
        AddTextOptionST("EditDeleteAll", "Delete All Backups", "Press")

        ; Row 9: Apply button
        AddTextOptionST("EditApply", "Apply Edit", "Press to apply")
        AddEmptyOption()

        ; Row 10: Quick edit section header
        AddHeaderOption("Quick Edit (Legacy)")
        AddHeaderOption("")

        ; Row 11: Quick input + apply
        AddInputOptionST("EditQuickInput", "mod|key|value", _lastEditRaw, 0)
        AddTextOptionST("EditQuickApply", "Apply Quick Edit", "Press")
    endif
endEvent

; @implements SKI_ConfigBase
event OnOptionSelect(int a_option)
    {Called when the user selects a non-dialog option}

    if (CurrentPage == Pages[0]) ; "Show/hide menus"
        int i = 0
        while (i<_modMenuToggle.Length)
            if (a_option == _modMenuToggle[i])
                int result = 0
                bool newState = !_modEnableFlags[i]

                if (newState)
                    result = ConfigManager.EnableModByName(_modNames[i])
                else
                    result = ConfigManager.DisableModByName(_modNames[i])
                    endif

                if(result > -1)
                    _modEnableFlags[i] = newState
                    SetToggleOptionValue(a_option, newState)
                else
                    Log("SkyUI is busy, please try again...")
                endif
                return
            endif
            i += 1
        endwhile

    elseif (CurrentPage == Pages[2]) ; "Backup blacklist"
        int i = 0
        while (i<_modBlacklistToggle.Length)
            if (a_option == _modBlacklistToggle[i])
                _modBlacklistEnableFlags[i] = !_modBlacklistEnableFlags[i]
                int jModSelection = JValue.readFromFile(YeOldeConfig.GetDefaultModSelectionFilePath())

                if (jModSelection == 0)
                    jModSelection = JArray.object()
                endif

                if (_modBlacklistEnableFlags[i])
                    JArray.addStr(jModSelection, _modNames[i])
                else
                    int index = JArray.findStr(jModSelection, _modNames[i])
                    if (index > -1)
                        JArray.eraseIndex(jModSelection, index)
                    endif
                endif

		        JArray.sort(jModSelection)
                JValue.writeToFile(jModSelection, YeOldeConfig.GetDefaultModSelectionFilePath())
                JValue.release(jModSelection)
                JValue.zeroLifetime(jModSelection)

                SetToggleOptionValue(a_option, _modBlacklistEnableFlags[i])
                return
            endif

            i += 1
        endwhile
    endif
endEvent

; @implements SKI_ConfigBase
event OnOptionDefault(int a_option)
	{Called when resetting an option to its default value}

    if (CurrentPage == Pages[0]) ; "Backup blacklist"
        int i = 0
        while (i<_modMenuToggle.Length)
            if (a_option == _modMenuToggle[i])
                int result = ConfigManager.EnableModByName(_modNames[i])

                if(result > -1)
                    _modEnableFlags[i] = true
                    SetToggleOptionValue(a_option, true)
                else
                    Log("SkyUI is busy, please try again...")
                endif
                return
            endif

            i += 1
        endwhile
    elseif (CurrentPage == Pages[2]) ; "Backup blacklist"
        int i = 0
        while (i<_modBlacklistToggle.Length)
            if (a_option == _modBlacklistToggle[i])
                _modBlacklistEnableFlags[i] = false
                SetToggleOptionValue(a_option, false)
            endif

            i += 1
        endwhile
    endif
endEvent


function UpdateInfoMsg(string msg)
	ForceInfoText(msg)
endfunction

bool _statusBusy = false
function AddModStatus(string a_name, string a_status, int a_errorNO)
    ; Log("AddModStatus(" + a_name + ", " + a_status + ", " + a_errorNO + ")")
    while (_statusBusy)
        Utility.WaitMenuMode(0.1)
    endwhile
    _statusBusy = true

    if (a_name != "")
        string statusMsg = a_name
        int flag = OPTION_FLAG_NONE
        if (a_status == "failed")
            statusMsg = "<font color='" + COLOR_BACKUP_FAIL + "'>" + statusMsg + " (FAILED, Error No. " + a_errorNO + ")</font>"
        elseif (a_status == "skipped")
            statusMsg = "<font color='" + COLOR_BACKUP_SELF_BACKUP + "'>" + statusMsg + " (SKIPPED)</font>"
        elseif (a_status == "success")
            statusMsg = "<font color='" + COLOR_BACKUP_PATCH_OK + "'>" + statusMsg + " (OK)</font>"
        endif

        ; if (_modMenuBackupInfosIndex < (_modMenuBackupInfos.Length - 1))
        ResetTextOptionValues(_modMenuBackupInfos[_modMenuBackupInfosIndex], statusMsg, "")
        SetOptionFlags(_modMenuBackupInfos[_modMenuBackupInfosIndex], flag)
        _modMenuBackupInfosIndex += 1
        ; else
        ;     _modMenuBackupInfosNbSup += 1
        ;     ResetTextOptionValues(_modMenuBackupInfos[_modMenuBackupInfosIndex], " + " + _modMenuBackupInfosNbSup + " mod(s)", "")
        ;     SetOptionFlags(_modMenuBackupInfos[_modMenuBackupInfosIndex], flag)
        ; endif
    endif

    _statusBusy = false
endfunction


function ClearSkippedModList()
    _modMenuBackupInfosIndex = 0
    int i = 0
    while (i<_modMenuBackupInfos.Length)
        if (_modMenuBackupInfos[i] > 0)
            ResetTextOptionValues(_modMenuBackupInfos[i], " ", " ")
        endif
        i += 1
    endwhile
endfunction


bool function IsBackupRestoreEnabled()
    {When returning true, it means that this mod supports backup and restore tasks.}
    return true
endfunction


int function OnBackupRequest(int jMod)
    int jModNames = JArray.objectWithStrings(_modNames)
    JArray.unique(jModNames)
    int emptyIndex = JArray.findStr(jModNames, "")
    JArray.eraseIndex(jModNames, emptyIndex) ; Remove the string ""
    string[] sortedModNames = JArray.asStringArray(jModNames)

    int i = 0
    while (i < sortedModNames.Length)
        int modIndex = _modNames.Find(sortedModNames[i])
        if (modIndex > -1)
            JMap.setInt(jMod, _modNames[modIndex], _modEnableFlags[modIndex] as int)
        endif
        i += 1
    endwhile
    return RESULT_SUCCESS
endfunction


int function OnRestoreRequest(int jMod)
    Log("OnRestoreRequest(" + jMod + ")")
    int i = 0
    while (i<_modNames.Length)
        if (JMap.hasKey(jMod, _modNames[i]))
            int result = 0
            bool newState = JMap.getInt(jMod, _modNames[i]) as bool

            if(newState != _modEnableFlags[i])
                if (newState)
                    result = ConfigManager.EnableModByName(_modNames[i])
                else
                    result = ConfigManager.DisableModByName(_modNames[i])
                endif

                if (!result)
                    Log("Error: Can't change Visible state for mod '" + _modNames[i] + "'")
                endif

                _modEnableFlags[i] = newState
            endif
        endif
        i += 1
    endwhile

    return RESULT_SUCCESS
endfunction


state DefaultModSelectionList
    event  OnSelectST()
        SetTextOptionValueST("Working...")
        ConfigManager.GenerateDefaultModSelectionList()
        ForcePageReset()
	endEvent

	event OnDefaultST()
        SetTextOptionValueST("Set default")
    endEvent

	event OnHighlightST()
        SetInfoText("Default blacklist will automatically skip mods with risk of failure. Based on yeolde_config.json file content.")
	endEvent
endState


state ImportMCMValues
    event OnSelectST()
        bool doContinue = ShowMessage("Please wait until the restoration is completed (a message will show).")
        if (doContinue)
            SetTextOptionValueST("working...")
            ClearSkippedModList()
            ConfigManager.RestoreAllModValues(self)
            ShowMessage("The restore task is now completed. Please exit MCMenu to complete restoration.", false)
            SetTextOptionValueST("Exit to complete")
            ; Input.TapKey(15) ; press TAB to exit current menu
        endif
	endEvent

	event OnDefaultST()
		SetTextOptionValueST("Press to restore")
	endEvent

	event OnHighlightST()
		SetInfoText("Restore all configs from the active backup. Use 'Load Slot' first to restore from a specific slot.")
	endEvent
endState

state ForceMCMReset
    event OnSelectST()
        SetTextOptionValueST("reseting...")
        ConfigManager.ForceResetFromMCMMenu()
		SetTextOptionValueST("Press to reset")
	endEvent

	event OnDefaultST()
		SetTextOptionValueST("Press to reset")
	endEvent

	event OnHighlightST()
		SetInfoText("Press the button, leave the menu and wait a minute or so. Every MCM menus will reset to default.")
	endEvent
endState

state MCMValuesBackup
    event OnSelectST()
        bool doContinue = ShowMessage("Please wait until the backup is completed (a message will show).")
        if (doContinue)
            SetTextOptionValueST("working...")
            _modMenuBackupInfosNbSup = 0
            ClearSkippedModList()
            ConfigManager.BackupAllModValues(self)

            ; Auto-save to active slot after backup (Feature 4 + 5)
            string slotName = BackupConfig.GetSlotName(_selectedSlotIndex)
            if (slotName == "<Empty>")
                slotName = "Slot " + (_selectedSlotIndex + 1)
            endif
            BackupConfig.SaveActiveToSlot(_selectedSlotIndex, slotName)

            ShowMessage("Backup completed and saved to " + slotName + ".", false)
            RefreshSlotNames()
            ForcePageReset()
        endif
	endEvent

	event OnDefaultST()
		SetTextOptionValueST("Press to backup")
	endEvent

	event OnHighlightST()
		SetInfoText("Backup all MCM configs. Saves to the active slot automatically.")
	endEvent
endState

function Log(string a_msg)
	Debug.Trace(self + ": " + a_msg)
endFunction


; ============================================================================
; MOD SEARCH FILTER STATE (Feature 9)
; ============================================================================

state ModSearchFilter
    event OnInputOpenST()
        SetInputDialogStartText(_modSearchFilter)
    endEvent

    event OnInputAcceptST(String a_input)
        _modSearchFilter = a_input
        ForcePageReset()
    endEvent

    event OnHighlightST()
        SetInfoText("Type to filter the mod list. Leave empty to show all mods.")
    endEvent
endState


; ============================================================================
; BACKUP SLOT STATES (Features 4 + 5)
; ============================================================================

state SlotSelector
    event OnMenuOpenST()
        RefreshSlotNames()
        SetMenuDialogOptions(_slotDisplayNames)
        SetMenuDialogStartIndex(_selectedSlotIndex)
        SetMenuDialogDefaultIndex(0)
    endEvent

    event OnMenuAcceptST(int a_index)
        if (a_index >= 0 && a_index < 5)
            _selectedSlotIndex = a_index
            SetMenuOptionValueST(_slotDisplayNames[a_index])
            ForcePageReset()
        endif
    endEvent

    event OnHighlightST()
        SetInfoText("Select which backup slot to use. Each slot holds a full snapshot of all MCM settings.")
    endEvent
endState


state SlotNameInput
    event OnInputOpenST()
        string currentName = BackupConfig.GetSlotName(_selectedSlotIndex)
        if (currentName == "<Empty>")
            currentName = "Slot " + (_selectedSlotIndex + 1)
        endif
        SetInputDialogStartText(currentName)
    endEvent

    event OnInputAcceptST(String a_input)
        if (a_input != "")
            string slotPath = BackupConfig.GetSlotFilePath(_selectedSlotIndex)
            int jSlot = JValue.readFromFile(slotPath)
            if (jSlot > 0)
                int jMeta = JMap.getObj(jSlot, "_yeolde_meta")
                if (jMeta == 0)
                    jMeta = JMap.object()
                    JMap.setObj(jSlot, "_yeolde_meta", jMeta)
                endif
                JMap.setStr(jMeta, "name", a_input)
                JValue.writeToFile(jSlot, slotPath)
                JValue.release(jSlot)
                SetInputOptionValueST(a_input, false, "")
                RefreshSlotNames()
                ForcePageReset()
            else
                SetInputOptionValueST("(slot empty)", false, "")
            endif
        endif
    endEvent

    event OnHighlightST()
        SetInfoText("Give the current backup slot a descriptive name.")
    endEvent
endState


state DeleteSlot
    event OnSelectST()
        string slotName = BackupConfig.GetSlotName(_selectedSlotIndex)
        if (slotName == "<Empty>")
            SetTextOptionValueST("Already empty")
            return
        endif

        bool doContinue = ShowMessage("Delete slot '" + slotName + "'? This cannot be undone.")
        if (doContinue)
            BackupConfig.DeleteSlot(_selectedSlotIndex)
            SetTextOptionValueST("Deleted!")
            ForcePageReset()
        else
            SetTextOptionValueST("Press")
        endif
    endEvent

    event OnDefaultST()
        SetTextOptionValueST("Press")
    endEvent

    event OnHighlightST()
        SetInfoText("Delete the currently selected backup slot permanently.")
    endEvent
endState


state LoadSlot
    event OnSelectST()
        string slotName = BackupConfig.GetSlotName(_selectedSlotIndex)
        if (slotName == "<Empty>")
            SetTextOptionValueST("Slot is empty")
            return
        endif

        bool doContinue = ShowMessage("Load '" + slotName + "' to active backup? This replaces current backup data.")
        if (doContinue)
            SetTextOptionValueST("Loading...")
            BackupConfig.LoadSlotToActive(_selectedSlotIndex)
            RefreshSlotNames()
            SetTextOptionValueST("Loaded!")
            ShowMessage("Slot loaded. Use 'Restore all configs' to apply the settings.", false)
        else
            SetTextOptionValueST("Press")
        endif
    endEvent

    event OnDefaultST()
        SetTextOptionValueST("Press")
    endEvent

    event OnHighlightST()
        SetInfoText("Load this slot's data to the active backup folder. Use 'Restore all configs' afterwards to apply.")
    endEvent
endState


; ============================================================================
; PER-MOD BACKUP/RESTORE STATES (Feature 6)
; ============================================================================

state PerModSelector
    event OnMenuOpenST()
        if (_perModNames == None || _perModNames.Length == 0)
            string[] empty = new String[1]
            empty[0] = "(no mods available)"
            SetMenuDialogOptions(empty)
            SetMenuDialogStartIndex(0)
        else
            SetMenuDialogOptions(_perModNames)
            if (_perModSelectedIdx >= 0)
                SetMenuDialogStartIndex(_perModSelectedIdx)
            else
                SetMenuDialogStartIndex(0)
            endif
        endif
        SetMenuDialogDefaultIndex(0)
    endEvent

    event OnMenuAcceptST(int a_index)
        if (_perModNames != None && a_index >= 0 && a_index < _perModNames.Length)
            _perModSelectedIdx = a_index
            SetMenuOptionValueST(_perModNames[a_index])
        endif
    endEvent

    event OnHighlightST()
        SetInfoText("Select a specific mod to backup or restore individually.")
    endEvent
endState


state PerModBackup
    event OnSelectST()
        if (_perModSelectedIdx < 0 || _perModNames == None)
            SetTextOptionValueST("Select a mod first")
            return
        endif

        string modName = _perModNames[_perModSelectedIdx]
        bool doContinue = ShowMessage("Backup settings for '" + modName + "'?")
        if (doContinue)
            SetTextOptionValueST("working...")
            ClearSkippedModList()
            ConfigManager.BackupSingleMod(modName, self)

            ; Update the active slot so it reflects the freshly backed-up mod data.
            string slotName = BackupConfig.GetSlotName(_selectedSlotIndex)
            if (slotName == "<Empty>" || slotName == "<No Name>")
                slotName = "Slot " + (_selectedSlotIndex + 1)
            endif
            BackupConfig.SaveActiveToSlot(_selectedSlotIndex, slotName)
            RefreshSlotNames()

            SetTextOptionValueST("Done!")
        else
            SetTextOptionValueST("Press")
        endif
    endEvent

    event OnDefaultST()
        SetTextOptionValueST("Press")
    endEvent

    event OnHighlightST()
        SetInfoText("Backup only the selected mod's MCM settings.")
    endEvent
endState


state PerModRestore
    event OnSelectST()
        if (_perModSelectedIdx < 0 || _perModNames == None)
            SetTextOptionValueST("Select a mod first")
            return
        endif

        string modName = _perModNames[_perModSelectedIdx]
        bool doContinue = ShowMessage("Restore settings for '" + modName + "'? Exit MCM after to complete.")
        if (doContinue)
            SetTextOptionValueST("working...")
            ClearSkippedModList()
            ConfigManager.RestoreSingleMod(modName, self)
            SetTextOptionValueST("Exit to complete")
        else
            SetTextOptionValueST("Press")
        endif
    endEvent

    event OnDefaultST()
        SetTextOptionValueST("Press")
    endEvent

    event OnHighlightST()
        SetInfoText("Restore only the selected mod's MCM settings from its backup file.")
    endEvent
endState


; ============================================================================
; EDIT BACKUPS STATES (Feature 7 - Complete UX Overhaul)
; ============================================================================

state EditImport
    event OnSelectST()
        SetTextOptionValueST("working...")
        int jBackup = BackupConfig.CreateImportInstance()
        if (jBackup == 0)
            SetTextOptionValueST("No backups found")
            _editModList = None
            _editKeyList = None
            _editSelectedModIdx = -1
            _editSelectedKeyIdx = -1
            _editIsNested = false
            _editPageList = None
            _editSelectedPageIdx = -1
            _editOptionIds = None
            return
        endif

        _editModList = BackupConfig.Mods(jBackup)
        int nb = 0
        if (_editModList != None)
            nb = _editModList.Length
        endif

        if (nb == 0)
            SetTextOptionValueST("No mods in backups")
            _editModList = None
        else
            _lastImportedBackup = jBackup
            _editSelectedModIdx = -1
            _editSelectedKeyIdx = -1
            _editKeyList = None
            _editIsNested = false
            _editPageList = None
            _editSelectedPageIdx = -1
            _editOptionIds = None
            SetTextOptionValueST("Imported " + nb + " mod(s)")
            SetTextOptionValue(_editModCountOpt, nb as string)
        endif
    endEvent

    event OnDefaultST()
        SetTextOptionValueST("Press to import")
    endEvent

    event OnHighlightST()
        SetInfoText("Import backup files for inspection and editing.")
    endEvent
endState


state EditSelectMod
    event OnMenuOpenST()
        if (_editModList == None || _editModList.Length == 0)
            string[] placeholder = new String[1]
            placeholder[0] = "(import first)"
            SetMenuDialogOptions(placeholder)
            SetMenuDialogStartIndex(0)
        else
            SetMenuDialogOptions(_editModList)
            if (_editSelectedModIdx >= 0)
                SetMenuDialogStartIndex(_editSelectedModIdx)
            else
                SetMenuDialogStartIndex(0)
            endif
        endif
        SetMenuDialogDefaultIndex(0)
    endEvent

    event OnMenuAcceptST(int a_index)
        if (_editModList == None || _editModList.Length == 0)
            return
        endif

        if (a_index >= 0 && a_index < _editModList.Length)
            _editSelectedModIdx = a_index
            _editSelectedKeyIdx = -1
            _editSelectedPageIdx = -1
            SetMenuOptionValueST(_editModList[a_index])

            ; Load keys for this mod (detect nested vs flat structure)
            if (_lastImportedBackup > 0)
                int jMod = JMap.getObj(_lastImportedBackup, _editModList[a_index])
                if (jMod > 0)
                    string[] topKeys = JMap.allKeysPArray(jMod)
                    bool isNested = false
                    if (topKeys != None && topKeys.Length > 0)
                        int testObj = JMap.getObj(jMod, topKeys[0])
                        if (testObj > 0)
                            isNested = true
                        endif
                    endif

                    _editIsNested = isNested
                    if (isNested)
                        _editPageList = topKeys
                        _editKeyList = None
                        _editOptionIds = None
                        int totalKeys = 0
                        int pi = 0
                        while (pi < topKeys.Length)
                            int jPage = JMap.getObj(jMod, topKeys[pi])
                            if (jPage > 0)
                                totalKeys += JMap.count(jPage)
                            endif
                            pi += 1
                        endwhile
                        SetTextOptionValue(_editKeyCountOpt, totalKeys as string)
                    else
                        _editPageList = None
                        _editKeyList = topKeys
                        _editOptionIds = None
                        int keyCountVal = 0
                        if (topKeys != None)
                            keyCountVal = topKeys.Length
                        endif
                        SetTextOptionValue(_editKeyCountOpt, keyCountVal as string)
                    endif
                else
                    _editIsNested = false
                    _editKeyList = None
                    _editPageList = None
                    _editOptionIds = None
                    SetTextOptionValue(_editKeyCountOpt, "0")
                endif
            endif

            SetTextOptionValue(_editCurrentValueOpt, "")
            ForcePageReset()
        endif
    endEvent

    event OnHighlightST()
        SetInfoText("Select a mod from the imported backup to inspect or edit.")
    endEvent
endState


state EditSelectPage
    event OnMenuOpenST()
        if (_editPageList == None || _editPageList.Length == 0)
            string[] placeholder = new String[1]
            placeholder[0] = "(select mod first)"
            SetMenuDialogOptions(placeholder)
            SetMenuDialogStartIndex(0)
        else
            SetMenuDialogOptions(_editPageList)
            if (_editSelectedPageIdx >= 0)
                SetMenuDialogStartIndex(_editSelectedPageIdx)
            else
                SetMenuDialogStartIndex(0)
            endif
        endif
        SetMenuDialogDefaultIndex(0)
    endEvent

    event OnMenuAcceptST(int a_index)
        if (_editPageList == None || _editPageList.Length == 0)
            return
        endif

        if (a_index >= 0 && a_index < _editPageList.Length)
            _editSelectedPageIdx = a_index
            _editSelectedKeyIdx = -1
            SetMenuOptionValueST(_editPageList[a_index])

            ; Load options for this page
            if (_lastImportedBackup > 0 && _editModList != None && _editSelectedModIdx >= 0)
                int jMod = JMap.getObj(_lastImportedBackup, _editModList[_editSelectedModIdx])
                if (jMod > 0)
                    int jPage = JMap.getObj(jMod, _editPageList[a_index])
                    if (jPage > 0)
                        string[] optIds = JMap.allKeysPArray(jPage)
                        int numOpts = 0
                        if (optIds != None)
                            numOpts = optIds.Length
                        endif
                        _editOptionIds = optIds
                        ; Build display names from state option or option ID
                        _editKeyList = Utility.CreateStringArray(numOpts, "")
                        int oi = 0
                        while (oi < numOpts)
                            int jOpt = JMap.getObj(jPage, optIds[oi])
                            if (jOpt > 0)
                                string stName = JMap.getStr(jOpt, "stateOption")
                                if (stName != "")
                                    _editKeyList[oi] = stName
                                else
                                    _editKeyList[oi] = "#" + optIds[oi]
                                endif
                            else
                                _editKeyList[oi] = optIds[oi]
                            endif
                            oi += 1
                        endwhile
                        SetTextOptionValue(_editKeyCountOpt, numOpts as string)
                    else
                        _editKeyList = None
                        _editOptionIds = None
                        SetTextOptionValue(_editKeyCountOpt, "0")
                    endif
                endif
            endif

            SetTextOptionValue(_editCurrentValueOpt, "")
            ForcePageReset()
        endif
    endEvent

    event OnHighlightST()
        SetInfoText("Select a page within the mod's backup data to browse its options.")
    endEvent
endState


state EditSelectKey
    event OnMenuOpenST()
        if (_editKeyList == None || _editKeyList.Length == 0)
            string[] placeholder = new String[1]
            if (_editIsNested && _editSelectedModIdx >= 0 && _editSelectedPageIdx < 0)
                placeholder[0] = "(select page first)"
            else
                placeholder[0] = "(select mod first)"
            endif
            SetMenuDialogOptions(placeholder)
            SetMenuDialogStartIndex(0)
        else
            SetMenuDialogOptions(_editKeyList)
            if (_editSelectedKeyIdx >= 0)
                SetMenuDialogStartIndex(_editSelectedKeyIdx)
            else
                SetMenuDialogStartIndex(0)
            endif
        endif
        SetMenuDialogDefaultIndex(0)
    endEvent

    event OnMenuAcceptST(int a_index)
        if (_editKeyList == None || _editKeyList.Length == 0)
            return
        endif

        if (a_index >= 0 && a_index < _editKeyList.Length)
            _editSelectedKeyIdx = a_index
            SetMenuOptionValueST(_editKeyList[a_index])

            ; Show current value
            if (_lastImportedBackup > 0 && _editModList != None && _editSelectedModIdx >= 0)
                int jMod = JMap.getObj(_lastImportedBackup, _editModList[_editSelectedModIdx])
                if (jMod > 0)
                    string val = ""
                    if (_editIsNested && _editPageList != None && _editSelectedPageIdx >= 0 && _editOptionIds != None)
                        if (a_index < _editOptionIds.Length)
                            val = ReadNestedOptionValue(jMod, _editPageList[_editSelectedPageIdx], _editOptionIds[a_index])
                        endif
                    else
                        val = ReadValueAsString(jMod, _editKeyList[a_index])
                    endif
                    SetTextOptionValue(_editCurrentValueOpt, val)
                endif
            endif
        endif
    endEvent

    event OnHighlightST()
        SetInfoText("Select a setting key to view or edit its value.")
    endEvent
endState


state EditValueType
    event OnMenuOpenST()
        SetMenuDialogOptions(_editTypeNames)
        SetMenuDialogStartIndex(_editType)
        SetMenuDialogDefaultIndex(0)
    endEvent

    event OnMenuAcceptST(int a_index)
        if (a_index >= 0 && a_index < 4)
            _editType = a_index
            SetMenuOptionValueST(_editTypeNames[a_index])
        endif
    endEvent

    event OnHighlightST()
        SetInfoText("Select the data type: String, Int, Float, or Bool.")
    endEvent
endState


state EditNewValue
    event OnInputOpenST()
        SetInputDialogStartText(_editNewValue)
    endEvent

    event OnInputAcceptST(String a_input)
        _editNewValue = a_input
        SetInputOptionValueST(a_input, false, "")
    endEvent

    event OnHighlightST()
        SetInfoText("Enter the new value. For Bool type, use 1/0 or true/false.")
    endEvent
endState


state EditApply
    event OnSelectST()
        if (_editSelectedModIdx < 0 || _editModList == None)
            SetTextOptionValueST("Select a mod first")
            return
        endif
        if (_editSelectedKeyIdx < 0 || _editKeyList == None)
            SetTextOptionValueST("Select a key first")
            return
        endif
        if (_editNewValue == "")
            SetTextOptionValueST("Enter a value first")
            return
        endif

        string modName = _editModList[_editSelectedModIdx]

        int jBackup = _lastImportedBackup
        if (jBackup == 0)
            SetTextOptionValueST("No backup loaded")
            return
        endif

        int jMod = JMap.getObj(jBackup, modName)
        if (jMod == 0)
            SetTextOptionValueST("Mod data not found")
            return
        endif

        string newDisplayVal = ""
        if (_editIsNested)
            if (_editPageList == None || _editSelectedPageIdx < 0 || _editOptionIds == None)
                SetTextOptionValueST("Select a page first")
                return
            endif
            string pageName = _editPageList[_editSelectedPageIdx]
            string optId = _editOptionIds[_editSelectedKeyIdx]
            WriteNestedOptionValue(jMod, pageName, optId, _editNewValue, _editType)
            newDisplayVal = ReadNestedOptionValue(jMod, pageName, optId)
        else
            string keyName = _editKeyList[_editSelectedKeyIdx]
            SetTypedValue(jMod, keyName, _editNewValue, _editType)
            newDisplayVal = ReadValueAsString(jMod, keyName)
        endif

        JValue.writeToFile(jMod, BackupConfig.GetDefaultBackupModDirectory() + modName)
        SetTextOptionValue(_editCurrentValueOpt, newDisplayVal)
        SetTextOptionValueST("Saved!")
    endEvent

    event OnDefaultST()
        SetTextOptionValueST("Press to apply")
    endEvent

    event OnHighlightST()
        SetInfoText("Apply the new value and save to disk. Changes take effect on next restore.")
    endEvent
endState


state EditDeleteMod
    event OnSelectST()
        if (_editSelectedModIdx < 0 || _editModList == None)
            SetTextOptionValueST("Select a mod first")
            return
        endif

        string modName = _editModList[_editSelectedModIdx]
        bool doContinue = ShowMessage("Delete backup for '" + modName + "'? This cannot be undone.")
        if (doContinue)
            BackupConfig.DeleteModBackup(modName)
            if (_lastImportedBackup > 0)
                JMap.removeKey(_lastImportedBackup, modName)
            endif
            _editSelectedModIdx = -1
            _editSelectedKeyIdx = -1
            _editKeyList = None
            _editIsNested = false
            _editPageList = None
            _editSelectedPageIdx = -1
            _editOptionIds = None
            SetTextOptionValueST("Deleted!")
            ForcePageReset()
        else
            SetTextOptionValueST("Press")
        endif
    endEvent

    event OnDefaultST()
        SetTextOptionValueST("Press")
    endEvent

    event OnHighlightST()
        SetInfoText("Permanently delete the backup file for the selected mod.")
    endEvent
endState


state EditDeleteAll
    event OnSelectST()
        bool doContinue = ShowMessage("Delete ALL backup files? This cannot be undone!")
        if (doContinue)
            BackupConfig.DeleteAllBackups()
            _lastImportedBackup = 0
            _editModList = None
            _editKeyList = None
            _editSelectedModIdx = -1
            _editSelectedKeyIdx = -1
            _editIsNested = false
            _editPageList = None
            _editSelectedPageIdx = -1
            _editOptionIds = None
            SetTextOptionValueST("All deleted!")
            ForcePageReset()
        else
            SetTextOptionValueST("Press")
        endif
    endEvent

    event OnDefaultST()
        SetTextOptionValueST("Press")
    endEvent

    event OnHighlightST()
        SetInfoText("WARNING: Permanently delete ALL backup files. Cannot be undone!")
    endEvent
endState


state EditQuickInput
    event OnInputOpenST()
        SetInputDialogStartText(_lastEditRaw)
    endEvent

    event OnInputAcceptST(String a_input)
        _lastEditRaw = a_input
        SetInputOptionValueST(a_input, false, "")
    endEvent

    event OnHighlightST()
        SetInfoText("Legacy quick edit: Enter mod|key|value (pipe-separated).")
    endEvent
endState


state EditQuickApply
    event OnSelectST()
        if (_lastEditRaw == "")
            SetTextOptionValueST("No edit provided")
            return
        endif

        ; Manual pipe parsing using StringUtil
        int pipe1 = StringUtil.Find(_lastEditRaw, "|", 0)
        if (pipe1 < 0)
            SetTextOptionValueST("Invalid format (need |)")
            return
        endif

        int pipe2 = StringUtil.Find(_lastEditRaw, "|", pipe1 + 1)
        if (pipe2 < 0)
            SetTextOptionValueST("Invalid format (need 2 |)")
            return
        endif

        string modName = StringUtil.Substring(_lastEditRaw, 0, pipe1)
        string keyName = StringUtil.Substring(_lastEditRaw, pipe1 + 1, pipe2 - pipe1 - 1)
        string newVal = StringUtil.Substring(_lastEditRaw, pipe2 + 1)

        int jBackup = _lastImportedBackup
        if (jBackup == 0)
            jBackup = BackupConfig.CreateImportInstance()
            if (jBackup == 0)
                SetTextOptionValueST("No backup available")
                return
            endif
            _lastImportedBackup = jBackup
        endif

        ; Keys in the imported backup include the .json extension (from readFromDirectory).
        ; Normalise so the quick-edit input (which omits the extension) still finds the right entry.
        string lookupName = modName
        if (JMap.getObj(jBackup, modName) == 0 && StringUtil.Find(modName, ".json") < 0)
            lookupName = modName + ".json"
        endif

        int jMod = JMap.getObj(jBackup, lookupName)
        if (jMod == 0)
            jMod = JMap.object()
            JMap.setObj(jBackup, lookupName, jMod)
        endif

        SetTypedValue(jMod, keyName, newVal, _editType)
        ; Ensure the saved file always has the .json extension.
        string savePath = lookupName
        if (StringUtil.Find(savePath, ".json") < 0)
            savePath = savePath + ".json"
        endif
        JValue.writeToFile(jMod, BackupConfig.GetDefaultBackupModDirectory() + savePath)

        SetTextOptionValueST("Saved to " + modName)
    endEvent

    event OnDefaultST()
        SetTextOptionValueST("Press")
    endEvent

    event OnHighlightST()
        SetInfoText("Apply the quick edit string (mod|key|value) with the selected value type.")
    endEvent
endState