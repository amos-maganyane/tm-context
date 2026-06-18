"=== Phase A API Discovery Probe v2 - READ-ONLY ==="
"v2 fixes from v1:
 - namespace-proofed (Root.Smalltalk + Core.* qualified)
 - ALL temp declarations moved to method/block start
   (v1 had mid-block | foo | declarations - illegal Smalltalk)
 RUN: paste into a NEW VW Workspace, Select All, Do It (Ctrl+E).
 WRITES: C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\probes\phaseA_results.txt
 NON-INVASIVE: every interaction probe checks for selectors only.
 Does NOT click buttons, set values, or change image state."

| err nl out emit lookup flag check
  display form pngWriter b64 fnClass
  mgr ctrls actionFinding inputFinding outFile transcript |

err := Core.Error.
nl := Core.String with: (Core.Character value: 13) with: (Core.Character value: 10).
out := Core.WriteStream on: Core.String new.
emit := [:line | out nextPutAll: line; nextPutAll: nl].
lookup := [:sym | | v |
    v := Root.Smalltalk at: sym ifAbsent: [nil].
    v == nil ifTrue: [
        #(Core Kernel OS UI Graphics Tools Net) do: [:nsName |
            v == nil ifTrue: [
                | ns |
                ns := Root.Smalltalk at: nsName ifAbsent: [nil].
                ns == nil ifFalse: [v := ns at: sym ifAbsent: [nil]]]]].
    v].
flag := [:bool | bool ifTrue: ['  + '] ifFalse: ['  - ']].
check := [:cls :sel | cls ~~ nil and: [cls isBehavior and: [cls canUnderstand: sel]]].

emit value: '=== PHASE A API PROBE v2 ==='.
emit value: ('Version: ' , ([Root.Smalltalk version] on: err do: [:ex | 'unknown'])).

"--- DISPLAY CAPTURE ---"
emit value: ''.
emit value: '--- DISPLAY CAPTURE ---'.
display := lookup value: #Display.
display == nil ifTrue: [
    | scr |
    scr := lookup value: #Screen.
    scr == nil ifFalse: [display := [scr default] on: err do: [:ex | nil]]].
display == nil
    ifTrue: [emit value: '  - Display global missing']
    ifFalse: [
        emit value: ('  + Display class = ' , display class name asString).
        form := [display contentsOfArea: display boundingBox] on: err do: [:ex |
            emit value: ('  - contentsOfArea: failed: ' , ex description). nil].
        form == nil ifFalse: [
            emit value: ('  + Form class = ' , form class name asString).
            emit value: ('  + Form extent = ' , ([form extent printString] on: err do: [:ex | '?'])).
            emit value: ('  + Form depth = ' , ([form depth printString] on: err do: [:ex | '?']))]].

"--- PNG ENCODER ---"
emit value: ''.
emit value: '--- PNG ENCODER ---'.
pngWriter := lookup value: #PNGReadWriter.
pngWriter == nil ifTrue: [pngWriter := lookup value: #ImageReadWriter].
pngWriter == nil
    ifTrue: [emit value: '  - no PNGReadWriter or ImageReadWriter found']
    ifFalse: [
        emit value: ('  + ' , pngWriter name asString).
        emit value: ((flag value: (check value: pngWriter class value: #putForm:onStream:)) , pngWriter name , ' class>>putForm:onStream:').
        emit value: ((flag value: (check value: pngWriter class value: #putForm:onFileNamed:)) , pngWriter name , ' class>>putForm:onFileNamed:')].

"--- BASE64 ---"
emit value: ''.
emit value: '--- BASE64 ENCODER ---'.
b64 := nil.
#(Base64MimeConverter Base64Encoder MIMEBase64 Base64Coder) do: [:sym |
    b64 == nil ifTrue: [b64 := lookup value: sym]].
b64 == nil
    ifTrue: [emit value: '  - no Base64 class found (will hand-roll one)']
    ifFalse: [
        emit value: ('  + ' , b64 name asString).
        #(encode: encodeBytes: mimeEncode: encodeString:) do: [:sel |
            emit value: ((flag value: (check value: b64 class value: sel)) , b64 name , ' class>>' , sel)]].

"--- WIDGET INTERACTION SURFACE ---"
emit value: ''.
emit value: '--- WIDGET INTERACTION SURFACE (NON-INVASIVE) ---'.
emit value: '  Surveys first ActionButtonSpec and first InputFieldSpec in any open window.'.
emit value: '  Reports selectors ONLY - never invokes actions or modifies values.'.
mgr := lookup value: #ScheduledControllers.
mgr == nil
    ifTrue: [emit value: '  - ScheduledControllers missing - cannot probe interaction']
    ifFalse: [
        ctrls := [mgr scheduledControllers] on: err do: [:ex | #()].
        actionFinding := nil.
        inputFinding := nil.
        ctrls do: [:ctrl |
            | app builder comps |
            app := [ctrl model] on: err do: [:ex | nil].
            (app == nil or: [([app builder] on: err do: [:ex | nil]) == nil]) ifTrue: [
                app := [ctrl view application] on: err do: [:ex | nil]].
            builder := app == nil ifTrue: [nil] ifFalse: [[app builder] on: err do: [:ex | nil]].
            builder == nil ifFalse: [
                comps := [builder namedComponents] on: err do: [:ex | nil].
                comps == nil ifFalse: [
                    comps keysAndValuesDo: [:asp :w |
                        | specClassName |
                        specClassName := [w spec class name asString] on: err do: [:ex | ''].
                        (actionFinding == nil and: [specClassName = 'ActionButtonSpec'])
                            ifTrue: [actionFinding := Core.Array with: app with: asp with: w].
                        (inputFinding == nil and: [specClassName = 'InputFieldSpec'])
                            ifTrue: [inputFinding := Core.Array with: app with: asp with: w]]]]].

        emit value: ''.
        emit value: '--- CLICK SURFACE (first ActionButtonSpec) ---'.
        actionFinding == nil
            ifTrue: [emit value: '  - no ActionButtonSpec widget in any open window']
            ifFalse: [
                | app aspect w spec widget ctrlObj model actionSel |
                app := actionFinding at: 1.
                aspect := actionFinding at: 2.
                w := actionFinding at: 3.
                spec := [w spec] on: err do: [:ex | nil].
                widget := [w widget] on: err do: [:ex | nil].
                ctrlObj := widget == nil ifTrue: [nil] ifFalse: [[widget controller] on: err do: [:ex | nil]].
                model := widget == nil ifTrue: [nil] ifFalse: [[widget model] on: err do: [:ex | nil]].
                actionSel := spec == nil ifTrue: [nil] ifFalse: [[spec action] on: err do: [:ex | nil]].
                emit value: ('  app: ' , app class name asString , '   aspect: ' , aspect printString).
                emit value: ('  spec.label: ' , ([spec label printString] on: err do: [:ex | '?'])).
                emit value: ('  spec class: ' , (spec == nil ifTrue: ['nil'] ifFalse: [spec class name asString])).
                emit value: ('  widget class: ' , (widget == nil ifTrue: ['nil'] ifFalse: [widget class name asString])).
                emit value: ('  controller class: ' , (ctrlObj == nil ifTrue: ['nil'] ifFalse: [ctrlObj class name asString])).
                emit value: ('  model class: ' , (model == nil ifTrue: ['nil'] ifFalse: [model class name asString])).
                emit value: ('  spec action selector: ' , (actionSel == nil ifTrue: ['nil (no action)'] ifFalse: [actionSel printString])).
                emit value: '  -- click strategy 1: app perform: actionSelector --'.
                actionSel == nil ifFalse: [
                    emit value: ((flag value: (app respondsTo: actionSel)) , 'app>>' , actionSel asString)].
                emit value: '  -- click strategy 2: controller direct invocation --'.
                ctrlObj == nil ifFalse: [
                    #(performAction pressAction action invokeAction simulateClick clicked) do: [:sel |
                        emit value: ((flag value: (ctrlObj respondsTo: sel)) , ctrlObj class name asString , '>>' , sel asString)]].
                emit value: '  -- click strategy 3: model-side trigger --'.
                model == nil ifFalse: [
                    #(value value: triggerAction) do: [:sel |
                        emit value: ((flag value: (model respondsTo: sel)) , model class name asString , '>>' , sel asString)]]].

        emit value: ''.
        emit value: '--- TYPE SURFACE (first InputFieldSpec) ---'.
        inputFinding == nil
            ifTrue: [emit value: '  - no InputFieldSpec widget in any open window']
            ifFalse: [
                | app aspect w spec widget model ctrlObj |
                app := inputFinding at: 1.
                aspect := inputFinding at: 2.
                w := inputFinding at: 3.
                spec := [w spec] on: err do: [:ex | nil].
                widget := [w widget] on: err do: [:ex | nil].
                model := widget == nil ifTrue: [nil] ifFalse: [[widget model] on: err do: [:ex | nil]].
                ctrlObj := widget == nil ifTrue: [nil] ifFalse: [[widget controller] on: err do: [:ex | nil]].
                emit value: ('  app: ' , app class name asString , '   aspect: ' , aspect printString).
                emit value: ('  spec class: ' , (spec == nil ifTrue: ['nil'] ifFalse: [spec class name asString])).
                emit value: ('  widget class: ' , (widget == nil ifTrue: ['nil'] ifFalse: [widget class name asString])).
                emit value: ('  model class: ' , (model == nil ifTrue: ['nil'] ifFalse: [model class name asString])).
                emit value: ('  controller class: ' , (ctrlObj == nil ifTrue: ['nil'] ifFalse: [ctrlObj class name asString])).
                model == nil ifFalse: [
                    emit value: ('  current value (read-only): ' , ([model value printString] on: err do: [:ex | '?'])).
                    #(value: setValue: contents: setContents: setText:) do: [:sel |
                        emit value: ((flag value: (model respondsTo: sel)) , model class name asString , '>>' , sel asString)]]].
    ].

"--- FILENAME WRITING ---"
emit value: ''.
emit value: '--- FILENAME WRITING ---'.
fnClass := lookup value: #Filename.
fnClass == nil
    ifTrue: [emit value: '  - Filename missing']
    ifFalse: [
        | f w |
        emit value: ('  + Filename class: ' , fnClass name asString).
        f := [fnClass named: 'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\probes\probe_write_test.txt']
            on: err do: [:ex | nil].
        f ~~ nil ifTrue: [
            w := [f writeStream] on: err do: [:ex |
                emit value: ('  - writeStream failed: ' , ex description). nil].
            w ~~ nil ifTrue: [
                [w nextPutAll: 'phaseA-probe-ok'. w close.
                 emit value: '  + wrote probe_write_test.txt'] on: err do: [:ex |
                    emit value: ('  - write failed: ' , ex description)]]]].

emit value: ''.
emit value: '=== PHASE A PROBE DONE ==='.

outFile := 'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\probes\phaseA_results.txt' asFilename writeStream.
[outFile nextPutAll: out contents] ensure: [outFile close].

transcript := lookup value: #Transcript.
transcript == nil ifFalse: [
    transcript cr; show: out contents.
    transcript cr; show: 'Phase A results: C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\probes\phaseA_results.txt'; cr].
