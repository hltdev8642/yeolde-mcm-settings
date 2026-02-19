Scriptname Form Hidden

; Core
Int Function GetFormID() native
Bool Function IsNone() native
String Function GetName() native
Function SetName(String asName) native

; State machine (built-in but declared for compiler)
Function GotoState(String newState) native
String Function GetState() native

; SKSE Mod Events
Function RegisterForModEvent(String eventName, String callbackName) native
Function UnregisterForModEvent(String eventName) native
Function UnregisterForAllModEvents() native
Function SendModEvent(String eventName, String strArg = "", Float numArg = 0.0) native

; SKSE Update events
Function RegisterForSingleUpdate(Float afInterval) native
Function RegisterForUpdate(Float afInterval) native
Function UnregisterForUpdate() native

; SKSE Menu events
Function RegisterForMenu(String menuName) native
Function UnregisterForMenu(String menuName) native
Function UnregisterForAllMenus() native

; SKSE Sleep events
Function RegisterForSleep() native
Function UnregisterForSleep() native
