"=== Dialog discovery probe ==="
"Probe for VW dialog/modal mechanisms. Goal: find where Dialog confirm: stores
 its active modal so the bridge can enumerate + dismiss programmatically.

 Run from a VW workspace via:
     'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\probes\dialog-discovery-probe.st' asFilename fileIn

 SAFE TO RUN ANYTIME (read-only introspection - no UI changes, no commits).
 Writes findings to .dialog-probe.txt in the vw-bridge folder.

 BEST RUN WHILE A MODAL IS UP (instance-level data captures the live modal).
 Also useful to run with no modal up (provides class-level baseline)."!

"=== Body ==="
| info f candidates classData procData |
info := Core.OrderedCollection new.
info add: '=== Run time: ', (Core.Time now printString), ' ==='.

"--- (1) ACTIVE CONTROLLER PROCESS state ---"
info add: ''.
info add: '=== [1] ScheduledControllers state ==='.
info add: 'activeControllerProcess = ', ([ScheduledControllers activeControllerProcess printString] on: Core.Error do: [:ex | 'ERR: ', ex description]).
info add: 'active = ', ([ScheduledControllers active printString] on: Core.Error do: [:ex | 'ERR']).
info add: 'scheduledControllers count = ', ([ScheduledControllers scheduledControllers size printString] on: Core.Error do: [:ex | 'ERR']).
[ScheduledControllers scheduledControllers doWithIndex: [:ctrl :i |
	info add: '  ', i printString, '. ctrl=', ctrl class name asString,
		' view=', ([ctrl view class name asString] on: Core.Error do: [:ex | '?']),
		' label=', ([ctrl view label asString] on: Core.Error do: [:ex | '?'])]] on: Core.Error do: [:ex | info add: '  ERR enumerating: ', ex description].

"--- (2) CANDIDATE DIALOG CLASSES ---"
info add: ''.
info add: '=== [2] Candidate dialog/modal classes ==='.
candidates := #(SystemDialog SimpleDialog Dialog ConfirmationDialog DialogView PopUpView DialogWindow SimplePopUpController PopUpController WindowManager ScreenController PromptViewController WarningHolder ChoiceBox).
candidates do: [:cn |
	| cls |
	cls := [Root.Smalltalk at: cn ifAbsent: [nil]] on: Core.Error do: [:ex | nil].
	cls == nil
		ifTrue: [info add: cn asString, ' = ABSENT']
		ifFalse: [
			info add: cn asString, ' = ', cls printString.
			"Try class-side activeDialogs / active / instances accessors"
			#(activeDialogs active activeDialog default current allDialogs openDialogs) do: [:sel |
				(cls class canUnderstand: sel) ifTrue: [
					info add: '  ', cn asString, ' class>>', sel asString, ' = ',
						([(cls perform: sel) printString] on: Core.Error do: [:ex | 'ERR: ', ex description])]].
			"allInstances count (rough modal-count guess)"
			info add: '  ', cn asString, ' allInstances count = ',
				([cls allInstances size printString] on: Core.Error do: [:ex | 'ERR'])]].

"--- (3) DOES ANY CANDIDATE CLASS IMPLEMENT #confirm: ON THE CLASS SIDE? ---"
info add: ''.
info add: '=== [3] Class-side #confirm: implementors among candidates ==='.
candidates do: [:cn |
	| cls |
	cls := [Root.Smalltalk at: cn ifAbsent: [nil]] on: Core.Error do: [:ex | nil].
	(cls ~~ nil and: [cls class canUnderstand: #confirm:]) ifTrue: [
		info add: '  ', cn asString, ' class>>confirm: -> implementer chain: ',
			([(cls class whichClassIncludesSelector: #confirm:) printString] on: Core.Error do: [:ex | '?'])]].

"--- (4) INSTANCE COUNTS for window-like classes (find modal view) ---"
info add: ''.
info add: '=== [4] Instance counts for view-like classes ==='.
#(ApplicationWindow ScheduledWindow PopUpView DialogView ApplicationModel) do: [:cn |
	| cls |
	cls := [Root.Smalltalk at: cn ifAbsent: [nil]] on: Core.Error do: [:ex | nil].
	cls ~~ nil ifTrue: [
		info add: cn asString, ' allInstances count = ',
			([cls allInstances size printString] on: Core.Error do: [:ex | 'ERR'])]].

"--- (5) PROCESSES (modal event loops show up as named processes) ---"
info add: ''.
info add: '=== [5] All Process instances (modal often = its own process) ==='.
[Core.Process allInstances doWithIndex: [:p :i |
	info add: '  ', i printString, '. name=', ([p name asString] on: Core.Error do: [:ex | '?']),
		' state=', ([p state asString] on: Core.Error do: [:ex | '?']),
		' pri=', ([p priority printString] on: Core.Error do: [:ex | '?'])]] on: Core.Error do: [:ex | info add: 'ERR: ', ex description].

"--- (6) SAMPLE A LIVE MODAL VIEW (if any) - look in allInstances for unusual views ---"
info add: ''.
info add: '=== [6] Recently-created small windows (heuristic: bounds < 500x300 = likely modal) ==='.
[(Root.Smalltalk at: #ApplicationWindow ifAbsent: [nil]) ~~ nil ifTrue: [
	ApplicationWindow allInstances do: [:w |
		| box wd ht |
		box := [w displayBox] on: Core.Error do: [:ex | nil].
		box ~~ nil ifTrue: [
			wd := box width.
			ht := box height.
			((wd < 500 and: [ht < 300]) and: [(w respondsTo: #label) and: [([w label asString size > 0] on: Core.Error do: [:ex | false])]]) ifTrue: [
				info add: '  CANDIDATE: ', w printString, ' label=', ([w label asString] on: Core.Error do: [:ex | '?']),
					' bounds=', box printString]]]]] on: Core.Error do: [:ex | info add: 'ERR: ', ex description].

"--- WRITE TO FILE ---"
f := [('C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\.dialog-probe.txt' asFilename) writeStream] on: Core.Error do: [:ex | nil].
f == nil
	ifTrue: [Transcript cr; show: 'WARN: could not open .dialog-probe.txt for write'; cr]
	ifFalse: [
		[f lineEndTransparent] on: Core.Error do: [:ex | nil].
		info do: [:line | f nextPutAll: line; nextPut: (Core.Character value: 10)].
		f close.
		Transcript cr; show: 'Probe written to .dialog-probe.txt (', info size printString, ' lines)'; cr]!
