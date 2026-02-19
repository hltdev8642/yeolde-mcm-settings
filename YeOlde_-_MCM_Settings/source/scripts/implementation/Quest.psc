Scriptname Quest extends Form Hidden

Bool Function IsRunning() native
Bool Function IsCompleted() native
Bool Function Start() native
Bool Function Stop() native
Int Function GetCurrentStage() native
Bool Function SetCurrentStage(Int aiStage) native
Bool Function IsStageDone(Int aiStage) native
Bool Function SetCurrentStageDone(Int aiStage) native
Bool Function UpdateCurrentInstanceGlobal(Form aUpdateGlobal) native

Quest Function GetQuest(String asEditorID) global native
