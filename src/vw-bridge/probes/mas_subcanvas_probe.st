"=== MAS toolbarCanvas SubCanvas Discovery Probe - READ-ONLY ===
 Goal: find the real aspect name of 'Party & Contract' (and siblings)
 inside the toolbarCanvas SubCanvas of the MAS launcher.

 Approach:
   1. Locate the MAS launcher controller (window title contains 'MOMENTUM').
   2. Dump its top-level namedComponents (sanity vs /windows/tree output).
   3. Find the toolbarCanvas wrapper and inspect the SubCanvasSpec.
   4. Probe the wrapper's widget for selectors that reach an embedded app
      (client / application / model / component / subViews).
   5. Walk the view tree under the wrapper and report each subview's
      class + any .application it carries.
   6. Once the embedded ApplicationModel is found, dump ITS namedComponents
      - that's where we expect 'Party & Contract' to live.

 RUN: paste into a NEW VW Workspace, Select All, Do It (Ctrl+E).
 WRITES: C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\probes\mas_subcanvas_results.txt
 SAFETY: read-only. No clicks, no value sets, no UI mutation. All external
         calls wrapped in error handlers - cannot leave the image dirty."

| err nl out emit lookup describeComps walkSubViews
  mgr masCtrl masApp masBuilder masComps
  tbWrapper tbWidget spec subApp subBuilder subComps
  outFile transcript |

err := Core.Error.
nl := Core.String with: (Core.Character value: 13) with: (Core.Character value: 10).
out := Core.WriteStream on: Core.String new.
emit := [:line | out nextPutAll: line; nextPutAll: nl].
lookup := [:sym | Root.Smalltalk at: sym ifAbsent: [nil]].

describeComps := [:label :comps |
    emit value: ''.
    emit value: ('--- ' , label , ' ---').
    comps == nil
        ifTrue: [emit value: '  (nil)']
        ifFalse: [
            emit value: ('  count: ' , comps size printString).
            comps keysAndValuesDo: [:k :v |
                | specName lbl widCls |
                specName := [v spec class name asString] on: err do: [:ex | '?'].
                lbl := [v spec label printString] on: err do: [:ex | '?'].
                widCls := [v widget class name asString] on: err do: [:ex | '?'].
                emit value: ('  ' , k printString ,
                    '  spec=' , specName ,
                    '  widget=' , widCls ,
                    '  label=' , lbl)]]].

walkSubViews := [:view :depth :path |
    | indent subs app cls i |
    indent := Core.String new: depth * 2 withAll: (Core.Character value: 32).
    cls := [view class name asString] on: err do: [:ex | '?'].
    app := [view application] on: err do: [:ex | nil].
    emit value: (indent , '[' , path , '] ' , cls ,
        (app == nil ifTrue: [''] ifFalse: [' app=' , app class name asString])).
    subs := [view subViews] on: err do: [:ex | nil].
    subs ~~ nil ifTrue: [
        i := 0.
        subs do: [:sv |
            i := i + 1.
            walkSubViews value: sv value: depth + 1 value: (path , '.' , i printString)]]].

emit value: '=== MAS toolbarCanvas SUBCANVAS PROBE ==='.

mgr := lookup value: #ScheduledControllers.
mgr == nil
    ifTrue: [emit value: 'ScheduledControllers missing. Aborting.']
    ifFalse: [
        masCtrl := nil.
        ([mgr scheduledControllers] on: err do: [:ex | #()]) do: [:ctrl |
            | lbl |
            masCtrl == nil ifTrue: [
                lbl := [ctrl view label asString] on: err do: [:ex | ''].
                (lbl indexOfSubCollection: 'MOMENTUM' startingAt: 1) > 0
                    ifTrue: [masCtrl := ctrl]]].

        masCtrl == nil
            ifTrue: [emit value: 'No MOMENTUM controller found.']
            ifFalse: [
                emit value: ('Controller: ' , masCtrl printString).
                masApp := [masCtrl model] on: err do: [:ex | nil].
                (masApp == nil or: [([masApp builder] on: err do: [:ex | nil]) == nil])
                    ifTrue: [masApp := [masCtrl view application] on: err do: [:ex | nil]].

                masApp == nil
                    ifTrue: [emit value: 'No MAS application found on the controller.']
                    ifFalse: [
                        emit value: ('MAS app class: ' , masApp class name asString).
                        masBuilder := [masApp builder] on: err do: [:ex | nil].
                        masComps := masBuilder == nil
                            ifTrue: [nil]
                            ifFalse: [[masBuilder namedComponents] on: err do: [:ex | nil]].
                        describeComps value: 'Top-level MAS namedComponents' value: masComps.

                        tbWrapper := masComps == nil
                            ifTrue: [nil]
                            ifFalse: [masComps at: #toolbarCanvas ifAbsent: [nil]].
                        tbWrapper == nil
                            ifTrue: [emit value: 'No #toolbarCanvas in namedComponents.']
                            ifFalse: [
                                emit value: ''.
                                emit value: '--- toolbarCanvas wrapper ---'.
                                emit value: ('  wrapper class: ' , tbWrapper class name asString).
                                tbWidget := [tbWrapper widget] on: err do: [:ex | nil].
                                emit value: ('  widget class: ' ,
                                    (tbWidget == nil
                                        ifTrue: ['nil']
                                        ifFalse: [tbWidget class name asString])).
                                spec := [tbWrapper spec] on: err do: [:ex | nil].
                                spec == nil
                                    ifTrue: [emit value: '  (no spec)']
                                    ifFalse: [
                                        emit value: ('  spec class: ' , spec class name asString).
                                        emit value: ('  spec majorKey: ' ,
                                            ([spec majorKey printString] on: err do: [:ex | '?'])).
                                        emit value: ('  spec minorKey: ' ,
                                            ([spec minorKey printString] on: err do: [:ex | '?'])).
                                        emit value: ('  spec clientKey: ' ,
                                            ([spec clientKey printString] on: err do: [:ex | '?']))].

                                "--- Selectors on the widget that might reach an embedded app ---"
                                emit value: ''.
                                emit value: '--- Selectors that respond on tbWidget ---'.
                                tbWidget == nil
                                    ifFalse: [
                                        #(client model application component components subViews canvas subCanvas builder) do: [:sel |
                                            (tbWidget respondsTo: sel) ifTrue: [
                                                | v |
                                                v := [tbWidget perform: sel] on: err do: [:ex | '<err: ' , ex description , '>'].
                                                emit value: ('  ' , sel asString , ' -> ' ,
                                                    (v == nil
                                                        ifTrue: ['nil']
                                                        ifFalse: [
                                                            v isString
                                                                ifTrue: [v]
                                                                ifFalse: [v class name asString]]))]]].

                                "--- Walk the view tree under tbWidget, reporting any .application ---"
                                emit value: ''.
                                emit value: '--- View tree under toolbarCanvas wrapper ---'.
                                tbWidget == nil
                                    ifFalse: [walkSubViews value: tbWidget value: 0 value: 'root'].

                                "--- Try to extract the embedded app and dump its namedComponents ---"
                                subApp := nil.
                                tbWidget == nil ifFalse: [
                                    (tbWidget respondsTo: #client) ifTrue: [
                                        subApp := [tbWidget client] on: err do: [:ex | nil]].
                                    (subApp == nil and: [tbWidget respondsTo: #application])
                                        ifTrue: [
                                            | a |
                                            a := [tbWidget application] on: err do: [:ex | nil].
                                            (a ~~ nil and: [a ~~ masApp]) ifTrue: [subApp := a]].
                                    (subApp == nil and: [tbWidget respondsTo: #model])
                                        ifTrue: [
                                            | m |
                                            m := [tbWidget model] on: err do: [:ex | nil].
                                            (m ~~ nil and: [m respondsTo: #builder])
                                                ifTrue: [subApp := m]].
                                    "Last resort: walk subViews looking for one with a different .application"
                                    subApp == nil ifTrue: [
                                        ([tbWidget subViews] on: err do: [:ex | #()]) do: [:sv |
                                            subApp == nil ifTrue: [
                                                | a |
                                                a := [sv application] on: err do: [:ex | nil].
                                                (a ~~ nil and: [a ~~ masApp]) ifTrue: [subApp := a]]]]].

                                subApp == nil
                                    ifTrue: [emit value: '*** No embedded sub-application found - need a different drill-in approach ***']
                                    ifFalse: [
                                        emit value: ''.
                                        emit value: ('Embedded app class: ' , subApp class name asString).
                                        subBuilder := [subApp builder] on: err do: [:ex | nil].
                                        subComps := subBuilder == nil
                                            ifTrue: [nil]
                                            ifFalse: [[subBuilder namedComponents] on: err do: [:ex | nil]].
                                        describeComps value: 'toolbarCanvas namedComponents (the prize)' value: subComps]]]]].

emit value: ''.
emit value: '=== PROBE DONE ==='.

outFile := 'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\probes\mas_subcanvas_results.txt' asFilename writeStream.
[outFile nextPutAll: out contents] ensure: [outFile close].

transcript := lookup value: #Transcript.
transcript == nil ifFalse: [
    transcript cr; show: out contents.
    transcript cr; show: 'Saved: C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\probes\mas_subcanvas_results.txt'; cr]
