"=== Dialog discovery probe v2 - read source + enumerate windows ==="
"Focuses on:
 1. SOURCE of Dialog class>>confirm: (and warn:/request:/etc) - tells us
    what class Dialog actually instantiates when a modal opens.
 2. ALL ApplicationWindow allInstances with class+label+scheduled status -
    finds the unscheduled 11 (one of which may be a modal window in cache).
 3. Dialog class-side dialog selectors that exist - informational.
 4. WindowManager allInstances and their .windows / .controllers - registry.

 Safe to run anytime (read-only, no UI changes).
 Writes to .dialog-probe-v2.txt in vw-bridge folder.

 BEST RUN WHILE A MODAL IS UP (instance section captures the live one).
 If the modal was already dismissed when probe v1 ran, re-trigger via
 /click findID before running this one - bridge listener stays responsive
 thanks to Phase B+1.A."!

"=== Body ==="
| info f dumpClassMethod schedSet |
info := Core.OrderedCollection new.
info add: '=== Run time: ', Core.Time now printString, ' ==='.

"--- helper to dump a class-side method source ---"
dumpClassMethod := [:sel |
	| cm src |
	cm := [Dialog class compiledMethodAt: sel] on: Core.Error do: [:ex | nil].
	cm == nil
		ifTrue: [info add: '  Dialog class>>', sel asString, ' - NO SUCH METHOD']
		ifFalse: [
			src := [cm sourceString] on: Core.Error do: [:ex |
					[cm getSource] on: Core.Error do: [:ex2 | nil]].
			src == nil
				ifTrue: [info add: '  Dialog class>>', sel asString, ' - source UNAVAILABLE']
				ifFalse: [
					info add: '--- Dialog class>>', sel asString, ' source: ---'.
					info add: src.
					info add: '--- end source ---'.
					info add: '']]].

"--- [1] SOURCE of Dialog class methods that open modals ---"
info add: ''.
info add: '=== [1] Source of Dialog class>>confirm: / warn: / request: ==='.
#(#confirm: #warn: #request: #request:initialAnswer: #choose:fromList:) do: dumpClassMethod.

"--- [2] All ApplicationWindow allInstances with detail ---"
info add: ''.
info add: '=== [2] ApplicationWindow allInstances - full enumeration ==='.
schedSet := Core.IdentitySet new.
[ScheduledControllers scheduledControllers do: [:c |
	[(c view) ~~ nil ifTrue: [schedSet add: c view]] on: Core.Error do: [:ex | nil]]]
		on: Core.Error do: [:ex | nil].
info add: 'scheduled view set size: ', schedSet size printString.
info add: 'ApplicationWindow allInstances count: ', ApplicationWindow allInstances size printString.
info add: '(comparison: if AW count > scheduled count, the extras are unscheduled - candidates for modals/hidden windows)'.
ApplicationWindow allInstances doWithIndex: [:w :i |
	| label cls bounds isSched ctrlClass |
	label := [w label asString] on: Core.Error do: [:ex | '?'].
	cls := [w class name asString] on: Core.Error do: [:ex | '?'].
	bounds := [w displayBox printString] on: Core.Error do: [:ex | '?'].
	isSched := schedSet includes: w.
	ctrlClass := [w controller class name asString] on: Core.Error do: [:ex | '?'].
	info add: '  ', i printString, '. sched=', isSched printString,
		' cls=', cls, ' ctrlCls=', ctrlClass, ' label=', label, ' bounds=', bounds].

"--- [3] Dialog class - which known dialog selectors exist? ---"
info add: ''.
info add: '=== [3] Dialog class - dialog selectors present ==='.
#(#confirm: #confirm:initialAnswer: #warn: #request: #request:initialAnswer:
  #choose:fromList: #choose:fromList:lines: #choose:fromList:values:
  #information: #notify: #abort: #ask:
  #activeDialog activeDialogs #lastDialog) do: [:sel |
	((Dialog class canUnderstand: sel) or: [Dialog class respondsTo: sel])
		ifTrue: [info add: '  HAS: Dialog class>>', sel asString]].

"--- [4] WindowManager allInstances + their internal collections ---"
info add: ''.
info add: '=== [4] WindowManager allInstances ==='.
(Root.Smalltalk at: #WindowManager ifAbsent: [nil]) ~~ nil ifTrue: [
	WindowManager allInstances doWithIndex: [:wm :i |
		info add: '  ', i printString, '. ', ([wm printString] on: Core.Error do: [:ex | 'ERR printing']).
		#(windows views scheduledControllers controllers components) do: [:s |
			(wm respondsTo: s) ifTrue: [
				info add: '    .', s asString, ' = ',
					([(wm perform: s) printString] on: Core.Error do: [:ex | 'ERR'])]]]].

"--- [5] WindowManager class methods of interest ---"
info add: ''.
info add: '=== [5] WindowManager class methods of interest ==='.
#(#default #active #current #allWindows) do: [:sel |
	(WindowManager class canUnderstand: sel) ifTrue: [
		info add: '  HAS: WindowManager class>>', sel asString, ' = ',
			([(WindowManager perform: sel) printString] on: Core.Error do: [:ex | 'ERR'])]].

"--- WRITE ---"
f := [('C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\.dialog-probe-v2.txt' asFilename) writeStream] on: Core.Error do: [:ex | nil].
f == nil
	ifTrue: [Transcript cr; show: 'WARN: failed to write .dialog-probe-v2.txt'; cr]
	ifFalse: [
		[f lineEndTransparent] on: Core.Error do: [:ex | nil].
		info do: [:line | f nextPutAll: line; nextPut: (Core.Character value: 10)].
		f close.
		Transcript cr; show: 'Probe v2 written to .dialog-probe-v2.txt (', info size printString, ' lines)'; cr]!
