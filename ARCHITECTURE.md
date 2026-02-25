# YeOlde - MCM Settings: Architecture & Script Reference

## Overview

**YeOlde - MCM Settings** is a Skyrim SE mod that extends SkyUI's MCM (Mod Configuration Menu) framework to add:

1. **Show/Hide** — Toggle which mod menus appear in the MCM list at runtime.
2. **Backup/Restore** — Snapshot every mod's MCM settings to JSON and restore them later.
3. **Backup Mod selection** — Choose which mods are included or excluded from backup runs.
4. **Backup Slots** — Five named save slots for storing different configuration snapshots.
5. **Per-Mod backup/restore** — Back up or restore a single mod's settings independently.
6. **Edit Backups** — Inspect and manually edit the stored JSON values in-game.
7. **Debugging** — Force-reset the MCM configuration manager.

The mod works by sitting on top of SkyUI's internal scripts (`SKI_ConfigManager`, `SKI_ConfigBase`) and hooking into the same event/registration machinery that every other MCM-enabled mod uses.

---

## Script Inventory

| Script | Type | Role |
|---|---|---|
| `SKI_ConfigManager` | Quest script (DO NOT MODIFY) | Central MCM coordinator. Owns all mod registrations, dispatches SkyUI Flash UI events. |
| `SKI_ConfigBase` | Script (DO NOT MODIFY) | Base class for every MCM menu. Provides `Add*Option()` building blocks. |
| `YeOlde_SKI_ConfigBase` | extends `SKI_ConfigBase` | YeOlde's patched base class. Overrides `GetForceTextOptionMaxAttempts` and `OpenConfig`. |
| `yeolde_mcm_settings` | extends `YeOlde_SKI_ConfigBase` | The YeOlde MCM page itself. Renders all four + one pages, handles user interactions. |
| `YeOldeConfig` | Static utility (hidden) | Loads/saves `yeolde_config.json`. Classifies each mod's backup compatibility. |
| `yeolde_patches` | extends Quest (interface stub) | Abstract interface. The real implementation lives in the patches FOMOD. Handles mod-specific backup/restore workarounds. |
| `BackupConfig` | Static utility (hidden) | Reads/writes backup data from `mods/` directory and named slot files. Manages slot metadata. |
| `ModConfig` | Static utility (hidden) | JSON data model: a "mod" is a `JMap` keyed by page name. |
| `PageConfig` | Static utility (hidden) | JSON data model: a "page" is a `JMap` keyed by option ID string. |
| `OptionConfig` | Static utility (hidden) | JSON data model: an "option" is a `JMap` with `id`, `optionType`, `strValue`, `fltValue`, `stateOption`. |
| `YeOldeBackupHelpers` | Static utility (hidden) | Type-aware JMap read/write helpers (`backupInt`, `backupStr`, `setTypedValue`, `readAnyValueAsString`). |
| `YeOldeBackupThreadManager` | extends Quest | Backup thread pool. Assigns mods to the next free worker thread. |
| `YeOldeRestoreThreadManager` | extends Quest | Restore thread pool. Mirrors `YeOldeBackupThreadManager` for restores. |
| `YeOldeBackupThread` | extends Quest (hidden base) | Abstract worker thread. Holds per-mod task state. Both backup and restore use this base. |
| `YeOldeBackupThread1`–`6` | extends `YeOldeBackupThread` | Six concrete worker threads that run backup/restore tasks concurrently. |

---

## How SkyUI's MCM Framework Works (Required Background)

SkyUI's MCM is built on a Flash-based UI (`Journal Menu`). When the player opens the journal:

1. The **Flash UI** sends events to `SKI_ConfigManager` (a Quest script registered via `RegisterForModEvent`).
2. `SKI_ConfigManager` maintains two parallel arrays of 128 slots each:
   - `_modConfigs[128]` / `_modNames[128]` — currently **visible** mods in the MCM list.
   - `_allMods[128]` / `_allNames[128]` / `_isModEnabled[128]` — **all ever-registered** mods (YeOlde addition), including hidden ones.
3. Every mod that wants an MCM entry calls `SKI_ConfigBase.OnConfigInit()` → `RegisterMod()` on the manager.
4. When the player selects a mod from the MCM list, `SKI_ConfigManager` sets `_activeConfig` to that mod's `SKI_ConfigBase` script and calls `OpenConfig()` → `OnPageReset(page)`.
5. Each `Add*Option()` call inside `OnPageReset` tells Flash to draw a widget and returns an integer **option ID**.
6. When the player interacts with a widget, Flash fires another event → `SKI_ConfigManager` → `_activeConfig.OnOptionSelect(optionID)` etc.

---

## Script Connection Map

```
Player opens Journal
        │
        ▼
SKI_ConfigManager (Quest)
   ├─ Maintains _modNames[], _allNames[], _allMods[], _isModEnabled[]
   ├─ Receives Flash events: SKICP_modSelected, SKICP_pageSelected, SKICP_optionSelected …
   ├─ Dispatches to → _activeConfig (SKI_ConfigBase instance)
   │
   ├─ YeOlde additions:
   │   ├─ GetAllModNames()             → read by yeolde_mcm_settings
   │   ├─ GetAllEnabledModFlags()      → read by yeolde_mcm_settings
   │   ├─ EnableModByName() / DisableModByName()  ← called by yeolde_mcm_settings
   │   ├─ BackupAllModValues()         → spawns YeOldeBackupThreadManager
   │   ├─ RestoreAllModValues()        → spawns YeOldeRestoreThreadManager
   │   ├─ BackupSingleMod()            → single-mod variant
   │   ├─ RestoreSingleMod()           → single-mod variant
   │   ├─ InitializeModSelectionList() → loads/creates _jModSelection JArray
   │   └─ GenerateDefaultModSelectionList() → auto-populates based on YeOldeConfig
   │
   └─ _backup_mod property (yeolde_mcm_settings) for UI feedback during backup

yeolde_mcm_settings (extends YeOlde_SKI_ConfigBase)
   ├─ Pages: "Show/hide menus", "Backup/Restore menus",
   │         "Backup Mod selection", "Debugging options", "Edit Backups"
   ├─ OnPageReset()   → draws UI for the current page
   ├─ OnOptionSelect() → handles toggle/button clicks
   ├─ AddModStatus() / ShowBackupInfoMsg() → live status during backup runs
   ├─ OnBackupRequest() / OnRestoreRequest() → called by backup threads for THIS mod's own settings
   └─ State objects: MCMValuesBackup, ImportMCMValues, ForceMCMReset,
                     SlotSelector, SlotNameInput, LoadSlot, DeleteSlot,
                     PerModSelector, PerModBackup, PerModRestore,
                     EditImport, EditSelectMod, EditSelectPage, EditSelectKey, EditModifyValue …

YeOldeConfig (static)
   └─ Reads yeolde_config.json → classifies each mod:
       ok / error / selfpatch / internal / patch

yeolde_patches (extends Quest — interface stub in source, real impl in patches FOMOD)
   ├─ isPatchAvailable(modName) → true if a patch exists for this mod
   ├─ OnBackupRequest(modMenu, jMod)  → runs mod-specific backup logic
   └─ OnRestoreRequest(modMenu, jMod) → runs mod-specific restore logic

BackupConfig (static)
   ├─ Mod backup files:  JContainers.userDirectory()/yeolde-settings/mods/<ModName>.json
   ├─ Slot files:        JContainers.userDirectory()/yeolde-settings/slot_0..4.json
   └─ Functions: CreateImportInstance, SaveActiveToSlot, LoadSlotToActive,
                 GetSlotName, GetSlotTimestamp, GetSlotModCount, DeleteSlot …

ModConfig / PageConfig / OptionConfig (static)
   └─ Thin wrappers around JContainers JMap operations (no disk I/O of their own)

YeOldeBackupHelpers (static)
   └─ Type-aware read/write: backupInt/Flt/Str/Bool, setTypedValue, readAnyValueAsString

YeOldeBackupThreadManager (extends Quest)
   ├─ Holds references to _thread1 … _thread6
   ├─ doBackupTaskAsync(modMenu) → assigns to next free thread
   └─ wait_all() → raises YeOlde_OnBackupRequest event, polls until all threads finish

YeOldeBackupThread1–6 (extends YeOldeBackupThread)
   ├─ doBackupAsync() → marks thread busy, stores task vars
   ├─ OnBackupRequest event → calls modMenu.BackupAllPagesOptions(_patcher)
   │                        → raises YeOlde_BackupCompletedCallback
   ├─ doRestoreAsync() / OnRestoreRequest event → calls modMenu.RestorePages(jMod, _patcher)
   │                        → raises YeOlde_RestoreCompletedCallback
   └─ forceBackUnlock() / forceRestUnlock() → timeout safety valves (60 s)

YeOldeRestoreThreadManager
   └─ Identical structure to YeOldeBackupThreadManager but for restores.
      Uses same thread objects (YeOldeBackupThread1–6) on a different Quest.
```

---

## Detailed Script Descriptions

### `SKI_ConfigManager` (DO NOT MODIFY)

The central hub. All MCM activity passes through this Quest script.

**State machine:** Runs in state `""` normally; enters `BUSY` state during `EnableMod`/`DisableMod`/`RegisterMod` to block re-entrant calls.

**Key arrays (all 128-slot fixed Papyrus arrays):**

| Array | Description |
|---|---|
| `_modConfigs[128]` | SKI_ConfigBase references currently **visible** in MCM |
| `_modNames[128]` | Display names matching `_modConfigs` |
| `_allMods[128]` | All ever-registered mod scripts (YeOlde addition) |
| `_allNames[128]` | All names, including hidden mods (YeOlde addition) |
| `_isModEnabled[128]` | Whether each mod is currently visible (YeOlde addition) |

**YeOlde-added functions:**

- `GetAllModNames()` / `GetAllEnabledModFlags()` — exposing `_allNames` / `_isModEnabled` to `yeolde_mcm_settings`.
- `EnableModByName(name)` / `DisableModByName(name)` — add/remove a mod from the visible `_modConfigs`/`_modNames` arrays and push the updated list to Flash UI.
- `BackupAllModValues(settings_mod)` — iterates `_allMods`, skips blacklisted mods, delegates to `YeOldeBackupThreadManager`.
- `RestoreAllModValues(settings_mod)` — reads `mods/` directory, maps filenames back to mod indices, delegates to `YeOldeRestoreThreadManager`.
- `BackupSingleMod(modName, settings_mod)` / `RestoreSingleMod(...)` — single-mod variants used by the per-mod UI.
- `InitializeModSelectionList()` — loads `yeolde_mod_selection.json` from disk into `_jModSelection`; calls `GenerateDefaultModSelectionList()` if the file is absent.
- `GenerateDefaultModSelectionList()` — walks `_allNames`, includes mods that are **not** listed as risky in `yeolde_config.json` (or have a working internal/external patch), writes result to `yeolde_mod_selection.json`.
- `IsModBlackListed(mod)` — returns `true` if the mod is **not** in `_jModSelection` (i.e., excluded from backup).
- `IsBackupRestorePatchActive(modName, index)` — asks `yeolde_patches.isPatchAvailable(modName)`.
- `FindModIndexByFileName(filename)` — resolves a `.json` filename back to an index in `_allNames`.
- `BackupCompletedCallback` / `RestoreCompletedCallback` — ModEvent listeners. Increments counters, calls `ShowBackupModStatus` on `_backup_mod` (the UI script).
- `ForceResetFromMCMMenu()` — safe ForceReset wrapper usable while inside menu mode.
- `SortArray(string[])` — bubble sort for mod name arrays.

---

### `SKI_ConfigBase` (DO NOT MODIFY)

Base class for every MCM config menu in the game. `yeolde_mcm_settings` and all third-party mods inherit from this (or from `YeOlde_SKI_ConfigBase`).

**Key properties:**
- `ModName` — the display name shown in the MCM list.
- `Pages[]` — array of page names.
- `CurrentPage` — currently selected page.
- `ConfigManager` — reference to `SKI_ConfigManager`.

**Key functions provided to subclasses:**
- `AddHeaderOption(text)`, `AddTextOption(text, value)`, `AddToggleOption(text, checked)`, `AddMenuOption(text, value)`, `AddInputOption(text, value)`, `AddSliderOption(text, value, fmt)` — each returns an option ID integer.
- `SetCursorFillMode(mode)`, `SetCursorPosition(pos)` — control layout flow.
- `SetToggleOptionValue(id, val)`, `ResetTextOptionValues(id, ...)` etc. — update widget values in-place.
- `ShowMessage(text, withCancel)` — blocking message box.
- `ForcePageReset()` — tells Flash to regenerate the current page.

**Events subclasses override:**
- `OnConfigInit()` — called once, typically to set `ModName` and `Pages`.
- `OnPageReset(page)` — called each time a page is opened; must call `Add*Option()` to populate it.
- `OnOptionSelect(option)` / `OnOptionHighlight(option)` / `OnOptionDefault(option)` — user interaction callbacks.
- `OnOptionSliderAccept`, `OnOptionMenuAccept`, `OnOptionInputAccept`, `OnOptionColorAccept` — for specific option types.
- `BackupAllPagesOptions(patcher)` — called by backup threads to serialize this mod's settings to JContainers JSON.
- `RestorePages(jMod, patcher)` — called by restore threads to re-apply settings from JSON.

---

### `YeOlde_SKI_ConfigBase` (extends `SKI_ConfigBase`)

A thin compatibility shim used by YeOlde's own scripts. **Third-party mods are not modified** — they keep their original `SKI_ConfigBase` parent.

Overrides:
- `GetForceTextOptionMaxAttempts()` → returns `50` (up from `20`). Allows the force-text cycling algorithm more attempts when restoring text/menu options that require many iterations.
- `OpenConfig()` → calls `parent.OpenConfig()` then immediately re-sends page names from `GetPageNames()` to fix a corruption bug where `Pages` can become `None` after a game reload.
- `GetPageNames()` → virtual stub returning `None`; child scripts override this to return their page list.

---

### `yeolde_mcm_settings` (extends `YeOlde_SKI_ConfigBase`)

The main UI script. Registered as `"YeOlde - MCM Settings"` in the MCM.

**Pages (in order):**
1. `"Show/hide menus"` — Toggle visibility of each mod's MCM entry.
2. `"Backup/Restore menus"` — Backup, restore, slot management, per-mod operations, live status.
3. `"Backup Mod selection"` — Include/exclude each mod from backup runs.
4. `"Debugging options"` — Force-reset MCM.
5. `"Edit Backups"` — Browse, inspect, and modify stored backup JSON values in-game.

**Key instance variables:**

| Variable | Purpose |
|---|---|
| `_modNames[128]` | Refreshed every `OnPageReset` from `ConfigManager.GetAllModNames()` |
| `_modEnableFlags[128]` | Refreshed from `ConfigManager.GetAllEnabledModFlags()` |
| `_modMenuToggle[128]` | Option IDs for show/hide toggles (indexed by `_modNames` position) |
| `_modBlacklistToggle[128]` | Option IDs for backup-selection toggles |
| `_modBlacklistEnableFlags[128]` | Current checked state for each mod in backup selection |
| `_modSearchFilter` | Current search string for filtering the show/hide list |
| `_selectedSlotIndex` | Which of the 5 backup slots is active (0–4) |
| `_perModNames[]` / `_perModSelectedIdx` | Per-mod backup/restore selector state |
| `_modMenuBackupInfos[40]` / `_modMenuBackupInfosIndex` | Text option IDs for the live status panel |
| `_editModList`, `_editKeyList`, `_editPageList` … | Edit Backups page state |

**`OnPageReset` structure:**

```
OnPageReset(a_page):
  1. If page == "": show splash image + version text, return.
  2. EnsurePages() — guarantee Pages[] is populated (fix for save-load corruption).
  3. UnloadCustomContent() — remove previous splash DDS.
  4. EnsureCriticalArrays() — ensure internal arrays are initialized.
  5. _modNames  = ConfigManager.GetAllModNames()
  6. _modEnableFlags = ConfigManager.GetAllEnabledModFlags()
  7. Build compact sortedModNames[] and sortedIndices[] by iterating _modNames,
     skipping empty strings (uses Utility.CreateStringArray(128,"") + fill loop).

  if "Show/hide menus":
     - Adds search filter input.
     - Applies _modSearchFilter to build filteredMods[]/filteredIndices[].
     - Draws toggle per mod. _modMenuToggle[modIndex] = AddToggleOption(...)

  elseif "Backup/Restore menus":
     - Slot selector menu, slot name input, load/save/delete slot buttons.
     - Per-mod selector + backup/restore buttons.
     - Backup all / Restore all buttons.
     - Live status text panel (40 rows via _modMenuBackupInfos[]).

  elseif "Backup Mod selection":
     - Builds local JArray: JArray.objectWithStrings(_modNames) → unique → erase "" → asStringArray
       giving backupSortedMods[] with exact unique-mod count.
     - Reads _jModSelection = JValue.readFromFile(GetDefaultModSelectionFilePath()).
     - Draws toggle per mod. _modBlacklistToggle[modIndex] = AddToggleOption(...)
     - _modBlacklistEnableFlags[modIndex] = (mod IS in _jModSelection)

  elseif "Debugging options":
     - Single "Force MCM reset" text button.

  elseif "Edit Backups":
     - Import button, mod selector, page/key navigators, value editor.
```

**`OnOptionSelect` key logic:**

- *Show/hide page:* Finds which `_modMenuToggle[i]` matched, calls `ConfigManager.EnableModByName` or `DisableModByName`, updates `_modEnableFlags[i]`.
- *Backup Mod selection page:* Finds which `_modBlacklistToggle[i]` matched, flips `_modBlacklistEnableFlags[i]`, then add/remove-all-occurrences in `_jModSelection` JArray, writes to file.

**`OnOptionDefault` key logic:**

- *Show/hide:* Calls `EnableModByName` (reset = make visible).
- *Backup Mod selection:* Sets `_modBlacklistEnableFlags[i] = false` (reset = excluded).

**Backup/restore coordination:**

- `OnBackupRequest(jMod)` — called by a backup thread when it reaches the `YeOlde - MCM Settings` mod itself. Serializes `_modEnableFlags` (the show/hide toggle states) into `jMod` as `{modName: 0|1}` entries.
- `OnRestoreRequest(jMod)` — reads back those flags and calls `EnableModByName`/`DisableModByName` for any that differ.

---

### `YeOldeConfig` (static utility)

Loads `<JContainers.userDirectory()>/yeolde-settings/yeolde_config.json`.

**Config JSON structure:**
```json
{
  "version": 1,
  "mods": {
    "ModName": { "backup type": "ok|error|internal|patch|selfpatch", "patch state": "AMOT" },
    ...
  }
}
```

**Backup type meanings:**

| Type | Meaning |
|---|---|
| `ok` | Standard SkyUI backup works fine for this mod |
| `error` | Backup is known to fail or produce bad results |
| `internal` | Handled by a built-in YeOlde patch (identified by `patch state` key) |
| `patch` | Handled by an external patch from the patches FOMOD |
| `selfpatch` | Mod provides its own backup/restore (e.g., Campfire, Frostfall) |

**Key queries used at runtime:**
- `isModOK` — safe to include without patches.
- `isModNeedPatch` — needs external patch FOMOD.
- `isModNeedInternalPatch` — handled by built-in patch; can be included if `yeolde_patches` has it.
- `isModWillFail` — exclude by default.
- `isModSelfBackup` — has its own backup; can be included.

`GenerateDefaultModSelectionList()` in `SKI_ConfigManager` uses these queries to auto-build a sensible inclusion list on first install.

---

### `yeolde_patches` (interface stub — real implementation in patches FOMOD)

The source file here is a stub that logs an error if compiled and used. The real implementation is compiled separately in the `YeOlde_-_MCM_Settings_patches` FOMOD and ships per-mod patches.

Interface:
```
IsInitialized : bool
initialize(jConfig)
isPatchAvailable(modName) : bool
setActivePatch(modName) : bool
OnBackupRequest(modMenu, jMod) : int   ; 0 = success
OnRestoreRequest(modMenu, jMod) : int  ; 0 = success
```

Each concrete patch knows the internal variable names for a specific mod and reads/writes them directly to `jMod` since the generic `BackupAllPagesOptions`/`RestorePages` approach doesn't work for that mod.

---

### `BackupConfig` (static utility)

Manages the on-disk backup storage layout.

**File layout on disk:**
```
<JContainers.userDirectory()>/yeolde-settings/
  mods/
    ModName.json      ← one file per mod (active backup)
  slot_0.json         ← named backup slot 0
  slot_1.json
  ...
  slot_4.json
  yeolde_mod_selection.json   ← JArray of mod names included in backup
  yeolde_config.json          ← mod classification data
```

**A slot file structure:**
```json
{
  "_yeolde_meta": { "name": "My Preset", "timestamp": "Day 14, 8:00" },
  "ModName.json": { ... mod backup data ... },
  ...
}
```

**Key operations:**
- `CreateImportInstance()` — reads all `mods/*.json` files into a single `JMap` keyed by filename using `JValue.readFromDirectory`.
- `SaveActiveToSlot(index, name)` — reads current `mods/` into memory, adds `_yeolde_meta`, writes to `slot_N.json`.
- `LoadSlotToActive(index)` — strips `_yeolde_meta` from a slot, clears `mods/`, writes each mod back as an individual file.
- `GetSlotName/Timestamp/ModCount(index)` — reads slot metadata without loading full backup data.
- `RemoveModFilesFromDisk()` / `DeleteModBackup(modName)` / `DeleteSlot(index)` / `DeleteAllBackups()` — cleanup functions.

---

### `ModConfig` / `PageConfig` / `OptionConfig` (data model, all static)

These scripts are pure wrappers around `JContainers` JMap operations. They define the hierarchical structure of a backup file.

**Hierarchy:**
```
jBackup (JMap)
  └─ ModName → jMod (JMap)          ModConfig
       └─ PageName → jPage (JMap)   PageConfig
            └─ "optionID" → jOpt    OptionConfig
                 ├─ id: int
                 ├─ optionType: int  (0=toggle,1=slider,2=menu,3=text/input,4=color,…)
                 ├─ strValue: string
                 ├─ fltValue: float  (also used for int/bool via cast)
                 └─ stateOption: string
```

---

### `YeOldeBackupHelpers` (static utility)

Convenience wrappers for type-aware reads/writes so backup/restore code doesn't need to know the JMap type to use:

- `backupInt/Flt/Str/Bool(jMod, key, value)` — write a typed value.
- `setTypedValue(jMod, key, value, type)` — write based on a runtime type integer (0=string, 1=int, 2=float, 3=bool).
- `readAnyValueAsString(jMod, key)` — try string → int → float, return first non-empty result as string.

Used primarily by the Edit Backups feature when writing user-entered text back to the correct type.

---

### `YeOldeBackupThreadManager` / `YeOldeRestoreThreadManager`

Both extend `Quest` and live on the same Quest object as the six `YeOldeBackupThread1–6` scripts (accessed via Papyrus Quest-cast syntax: `YeOldeBackupQuest as YeOldeBackupThread1`).

**Backup flow:**
1. `Initialize(settings_mod, patcher, jConfig)` — stores references, registers for `YeOlde_OnBackupRequest` ModEvent.
2. `doBackupTaskAsync(modMenu)` — scans thread1→6 for the first `!queued()` thread, calls `thread.doBackupAsync(...)`. If all six are busy, calls `wait_all()` first.
3. `wait_all()` — raises `YeOlde_OnBackupRequest` event (which wakes all queued threads simultaneously), then polls every 0.1 s until all threads report `!queued()`. Timeout at 60 s with `forceBackUnlock()` safety.

**Restore flow:** Identical structure through `YeOldeRestoreThreadManager` using `YeOlde_OnRestoreRequest`/`YeOlde_RestoreCompletedCallback` events.

---

### `YeOldeBackupThread` / `YeOldeBackupThread1–6`

Each is a Quest script that extends `YeOldeBackupThread`. All six share the same base implementation; they are differentiated only by script name (required by Papyrus to cast a Quest as multiple scripts).

**Thread state machine:**
```
Idle (_thread_queued = false)
  │  doBackupAsync() called
  ▼
Queued (_thread_queued = true, task vars set)
  │  YeOlde_OnBackupRequest event fires
  ▼
Running (OnBackupRequest event handler executes)
  │  modMenu.BackupAllPagesOptions(_patcher)
  │  Raises YeOlde_BackupCompletedCallback(result, modName)
  │  clear_thread_vars()
  ▼
Idle (_thread_queued = false)
```

**What `BackupAllPagesOptions(patcher)` does** (implemented in `SKI_ConfigBase`):
- Iterates the mod's `Pages[]`.
- For each page, calls `SetupPage(page)` to force-populate option IDs, then queries each option's current value.
- Serializes into a `jMod` JMap using the `ModConfig/PageConfig/OptionConfig` hierarchy.
- If `patcher.isPatchAvailable(ModName)`, calls `patcher.OnBackupRequest(self, jMod)` for any patch overrides.
- Writes final `jMod` to `mods/<ModName>.json`.

**What `RestorePages(jMod, patcher)` does:**
- Reads the mod's page/option tree from `jMod`.
- For each option, calls the appropriate `Force*Option` function (e.g., `ForceToggleValueTo`, `ForceInputValueTo`).
- The `ForceTextOption` variant cycles through text states up to `GetForceTextOptionMaxAttempts()` times (50 with YeOlde patch) until the value matches.

---

## End-to-End Data Flows

### Flow 1: Mod registers with MCM (game load)

```
Any mod's OnConfigInit()
  → SKI_ConfigBase.OnConfigInit()
    → ConfigManager.RegisterMod(self, ModName)
      → _allMods[nextID] = self
      → _modConfigs[nextID] = self  (if enabled)
      → _allNames[nextID] = ModName
      → _isModEnabled[nextID] = true
```

### Flow 2: Player opens Show/Hide page and hides a mod

```
Player clicks toggle for "OBIS - Bandits"
  → Flash sends SKICP_optionSelected(optionID)
  → SKI_ConfigManager.OnOptionSelect(optionID)
    → _activeConfig.OnOptionSelect(optionID)
      → yeolde_mcm_settings.OnOptionSelect(optionID)
        → matches _modMenuToggle[i] for "OBIS - Bandits"
        → _modEnableFlags[i] = false
        → ConfigManager.DisableModByName("OBIS - Bandits")
          → _modConfigs[i] = none, _modNames[i] = ""
          → UI.InvokeStringA("Journal Menu", ".setModNames", _modNames)
            → Flash removes OBIS from the list
```

### Flow 3: Backup all mods

```
Player clicks "Backup all configs"
  → MCMValuesBackup.OnSelectST()
    → ConfigManager.BackupAllModValues(yeolde_mcm_settings)
      → InitializeModSelectionList()  (loads _jModSelection)
      → YeOldeConfig.Load()           (loads _jConfig)
      → BackupConfig.RemoveModFilesFromDisk()
      → threadMgr.Initialize(...)
      → RegisterForModEvent("YeOlde_BackupCompletedCallback")
      → For each _allMods[i] != none:
          if IsModBlackListed(modName): log "skipped"
          else: threadMgr.doBackupTaskAsync(_allMods[i])
      → threadMgr.wait_all()
        → raises YeOlde_OnBackupRequest event
        → all queued threads fire OnBackupRequest simultaneously
          → each calls modMenu.BackupAllPagesOptions(_patcher)
            → writes mods/<ModName>.json
          → each raises YeOlde_BackupCompletedCallback(result, modName)
        → SKI_ConfigManager.BackupCompletedCallback updates counters
        → yeolde_mcm_settings.ShowBackupModStatus shows live status
      → BackupConfig.SaveActiveToSlot(_selectedSlotIndex, slotName)
      → ShowMessage("Backup completed and saved to Slot N.")
```

### Flow 4: Restore all mods

```
Player clicks "Restore all configs"
  → ImportMCMValues.OnSelectST()
    → ConfigManager.RestoreAllModValues(yeolde_mcm_settings)
      → YeOldeConfig.Load()
      → BackupConfig.CreateImportInstance()  (reads mods/*.json → jBackup JMap)
      → threadMgr.Initialize(...)
      → RegisterForModEvent("YeOlde_RestoreCompletedCallback")
      → For each key in JMap.allKeysPArray(jBackup):
          modIndex = FindModIndexByFileName(key)
          jMod = JMap.getObj(jBackup, key)
          threadMgr.doRestoreTaskAsync(_allMods[modIndex], jMod)
      → threadMgr.wait_all()
        → raises YeOlde_OnRestoreRequest event
        → all queued threads fire OnRestoreRequest simultaneously
          → each calls modMenu.RestorePages(jMod, _patcher)
            → ForceToggle/Text/Slider/etc. to restore values
          → each raises YeOlde_RestoreCompletedCallback
      → ShowMessage("Restore completed. Please exit MCMenu.")
```

### Flow 5: Backup Mod selection – toggle a mod's inclusion

```
Player toggles "Wildcat Combat" off on the Backup Mod selection page
  → OnOptionSelect(optionID)
    → matches _modBlacklistToggle[wildcatIndex]
    → _modBlacklistEnableFlags[wildcatIndex] = false (now excluded)
    → SetToggleOptionValue(optionID, false)
    → jModSelection = JValue.readFromFile(yeolde_mod_selection.json)
    → while JArray.findStr(jModSelection, "Wildcat Combat") > -1:
        JArray.eraseIndex(jModSelection, idx)
    → JValue.writeToFile(jModSelection, yeolde_mod_selection.json)
```

---

## JSON File Structures

### `yeolde_config.json`
```json
{
  "version": 1,
  "mods": {
    "Honed Metal":   { "backup type": "ok" },
    "Wildcat Combat":{ "backup type": "internal", "patch state": "Wildcat" },
    "3PCO - 3rd Person Camera Overhaul": { "backup type": "error" }
  }
}
```

### `yeolde_mod_selection.json`
```json
["Honed Metal", "iEquip", "Minty Lightning", ...]
```
An ordered JArray of mod display names that ARE included in backup runs. Missing = excluded (blacklisted).

### `mods/<ModName>.json`
```json
{
  "Page 1": {
    "12345": { "id": 12345, "optionType": 0, "fltValue": 1.0, "strValue": "", "stateOption": "" },
    "12346": { "id": 12346, "optionType": 1, "fltValue": 0.75, "strValue": "", "stateOption": "" }
  },
  "Page 2": { ... }
}
```

### `slot_N.json`
```json
{
  "_yeolde_meta": { "name": "Combat preset", "timestamp": "Day 120, 14:00" },
  "Wildcat Combat.json": { ... same structure as mods/<ModName>.json ... },
  "Honed Metal.json": { ... }
}
```

---

## Compilation Notes

- Compiler: `PapyrusCompiler.exe` from Skyrim SE CK.
- **Must** pass `-f="TESV_Papyrus_Flags.flg"` and `-i="<imports path>"` or the `hidden` property flag causes a fatal compile error.
- Use `do_compile.bat` (in project root) — it has correct flags and import paths and skips `ski_configbase.psc` / `ski_configmanager.psc`.
- `compile-psc.ps1` delegates to `do_compile.bat`.
- Output PEX files go to `YeOlde_-_MCM_Settings\scripts\`.
- Packaged with `build_zip.ps1 -Version vXX`.
