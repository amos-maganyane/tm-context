"=== MAS Full Widget Tree Probe v2 - READ-ONLY ===
 Goal: enumerate the FULL widget surface of the MAS launcher window so
 we can locate 'Party & Contract' and decide what bridge extension is
 actually needed.

 Differences from v1:
   - Walks BOTH #subViews AND #components (CompositePart children live
     in #components, not #subViews - v1 missed this).
   - Probes the launcher's menuBar / mainMenu (menus aren't in
     namedComponents at all - flagged in E2E-DISTANCE.md).
   - For each node: class, spec class, spec.label, spec.name (aspect),
     model class, application class, spec.action selector.
   - Depth-capped at 25 and node-capped at 500 to prevent runaway.

 RUN: paste into a VW Workspace and Do It, OR:
   'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\probes\mas_widget_tree_probe.st' asFilename fileIn
 WRITES: C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\probes\mas_widget_tree_results.txt
 SAFETY: read-only. No clicks, no value sets, no UI mutation."

| err nl out emit lookup nodeCount stopWalking
  walkNode dumpMenu attr
  mgr masCtrl masApp masView outFile transcript |

err := Core.Error.
nl := Core.String with: (Core.Character value: 13) with: (Core.Character value: 10).
out := Core.WriteStream on: Core.String new.
emit := [:line | out nextPutAll: line; nextPutAll: nl].
lookup := [:sym | Root.Smalltalk at: sym ifAbsent: [nil]].
nodeCount := 0.
stopWalking := false.

"Safe attribute extractor: send selector if responds, return printString or '-'."
attr := [:obj :sel |
    (obj ~~ nil and: [obj respondsTo: sel])
        ifTrue: [[(obj perform: sel) printString] on: err do: [:ex | '-']]
        ifFalse: ['-']].

walkNode := [:node :depth :path |
    stopWalking ifFalse: [
        nodeCount := nodeCount + 1.
        (nodeCount > 500 or: [depth > 25])
            ifTrue: [
                emit value: '*** walk stopped (depth or node cap reached) ***'.
                stopWalking := true]
            ifFalse: [
                | indent cls spec specCls lbl aspect actionSel modelCls appCls
                  children subs comps comp |
                indent := Core.String new: depth * 2 withAll: (Core.Character value: 32).
                cls := [node class name asString] on: err do: [:ex | '?'].
                spec := [node spec] on: err do: [:ex | nil].
                specCls := spec == nil ifTrue: ['-'] ifFalse: [[spec class name asString] on: err do: [:ex | '?']].
                lbl := attr value: spec value: #label.
                aspect := attr value: spec value: #name.
                actionSel := attr value: spec value: #action.
                modelCls := [
                    | m |
                    m := [node model] on: err do: [:ex | nil].
                    m == nil ifTrue: ['-'] ifFalse: [m class name asString]
                ] on: err do: [:ex | '-'].
                appCls := [
                    | a |
                    a := [node application] on: err do: [:ex | nil].
                    a == nil ifTrue: ['-'] ifFalse: [a class name asString]
                ] on: err do: [:ex | '-'].
                emit value: (indent , '[' , path , '] ' , cls ,
                    '  spec=' , specCls ,
                    '  aspect=' , aspect ,
                    '  label=' , lbl ,
                    '  action=' , actionSel ,
                    '  model=' , modelCls ,
                    '  app=' , appCls).

                "Gather children from subViews + components + component, dedup."
                children := Core.OrderedCollection new.
                subs := (node respondsTo: #subViews)
                    ifTrue: [[node subViews] on: err do: [:ex | #()]]
                    ifFalse: [#()].
                subs do: [:c | (c ~~ nil and: [(children includes: c) not]) ifTrue: [children add: c]].
                comps := (node respondsTo: #components)
                    ifTrue: [[node components] on: err do: [:ex | #()]]
                    ifFalse: [#()].
                comps do: [:c | (c ~~ nil and: [(children includes: c) not]) ifTrue: [children add: c]].
                (node respondsTo: #component) ifTrue: [
                    comp := [node component] on: err do: [:ex | nil].
                    (comp ~~ nil and: [(children includes: comp) not]) ifTrue: [children add: comp]].

                children doWithIndex: [:c :i |
                    walkNode value: c value: depth + 1 value: (path , '.' , i printString)]]]].

dumpMenu := [:menu :sourceLabel |
    emit value: ''.
    emit value: ('--- Menu from ' , sourceLabel , ' ---').
    menu == nil
        ifTrue: [emit value: '  (nil)']
        ifFalse: [
            | items |
            emit value: ('  class: ' , menu class name asString).
            items := nil.
            #(items menuItems components) do: [:sel |
                (items == nil and: [menu respondsTo: sel]) ifTrue: [
                    items := [menu perform: sel] on: err do: [:ex | nil]]].
            items == nil
                ifTrue: [emit value: '  (no items/menuItems/components selector found)']
                ifFalse: [
                    emit value: ('  count: ' , ([items size printString] on: err do: [:ex | '?'])).
                    items doWithIndex: [:item :i |
                        emit value: ('  ' , i printString , '. ' ,
                            ([item class name asString] on: err do: [:ex | '?']) ,
                            '  label=' , (attr value: item value: #label) ,
                            '  value=' , (attr value: item value: #value) ,
                            '  rawLabel=' , (attr value: item value: #rawLabel))]]]].

emit value: '=== MAS FULL WIDGET TREE PROBE v2 ==='.

mgr := lookup value: #ScheduledControllers.
mgr == nil
    ifTrue: [emit value: 'ScheduledControllers missing.']
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
                emit value: ('Controller class: ' , masCtrl class name asString).
                masApp := [masCtrl model] on: err do: [:ex | nil].
                (masApp == nil or: [([masApp builder] on: err do: [:ex | nil]) == nil])
                    ifTrue: [masApp := [masCtrl view application] on: err do: [:ex | nil]].
                emit value: ('MAS app class: ' ,
                    (masApp == nil ifTrue: ['nil'] ifFalse: [masApp class name asString])).
                masView := [masCtrl view] on: err do: [:ex | nil].
                emit value: ('MAS root view class: ' ,
                    (masView == nil ifTrue: ['nil'] ifFalse: [masView class name asString])).

                "Probe possible menu bar locations."
                masView ~~ nil ifTrue: [
                    #(menuBar mainMenu menu windowMenu) do: [:sel |
                        (masView respondsTo: sel) ifTrue: [
                            | mb |
                            mb := [masView perform: sel] on: err do: [:ex | nil].
                            mb ~~ nil ifTrue: [dumpMenu value: mb value: 'masView>>' , sel asString]]]].
                masApp ~~ nil ifTrue: [
                    #(menuBar mainMenu menu) do: [:sel |
                        (masApp respondsTo: sel) ifTrue: [
                            | mb |
                            mb := [masApp perform: sel] on: err do: [:ex | nil].
                            mb ~~ nil ifTrue: [dumpMenu value: mb value: 'masApp>>' , sel asString]]]].

                "Walk the full view tree (subViews + components)."
                masView ~~ nil ifTrue: [
                    emit value: ''.
                    emit value: '--- Full widget tree (subViews + components combined, dedup) ---'.
                    walkNode value: masView value: 0 value: 'root'.
                    emit value: ''.
                    emit value: ('--- Walked ' , nodeCount printString , ' nodes ---')]]].

emit value: ''.
emit value: '=== PROBE v2 DONE ==='.

outFile := 'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\probes\mas_widget_tree_results.txt' asFilename writeStream.
[outFile nextPutAll: out contents] ensure: [outFile close].

transcript := lookup value: #Transcript.
transcript == nil ifFalse: [
    transcript cr; show: out contents.
    transcript cr; show: 'Saved: C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\probes\mas_widget_tree_results.txt'; cr]
