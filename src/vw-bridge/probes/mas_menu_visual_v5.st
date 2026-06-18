"=== MAS Menu Visual-Side Probe v5 - READ-ONLY ===
 v4 only tried menuBar.subViews (got 0). v2 widget tree showed 11
 BoundedWrappers under that same MenuBar, so the children live under
 a different selector (likely #components or #items). v5 tries multiple
 in order and ALSO dumps menuBar instVars as a fallback, so we always
 learn something even if every accessor returns empty.

 RUN: 'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\probes\mas_menu_visual_v5.st' asFilename fileIn
 WRITES: C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\probes\mas_menu_visual_v5.txt
 SAFETY: read-only."

| err nl out emit lookup attr trunc dumpIVars findChildren dumpMenuItems
  mgr masCtrl masApp masView menuBar barChildren firstBtn firstController
  innerSelectorUsed barSelectorUsed outFile transcript |

err := Core.Error.
nl := Core.String with: (Core.Character value: 13) with: (Core.Character value: 10).
out := Core.WriteStream on: Core.String new.
emit := [:line | out nextPutAll: line; nextPutAll: nl].
lookup := [:sym | Root.Smalltalk at: sym ifAbsent: [nil]].

trunc := [:str :n |
    | s |
    s := str asString.
    s size > n ifTrue: [(s copyFrom: 1 to: n) , '...'] ifFalse: [s]].

attr := [:obj :sel |
    (obj ~~ nil and: [obj respondsTo: sel])
        ifTrue: [[(obj perform: sel) printString] on: err do: [:ex | '<err>']]
        ifFalse: ['-']].

dumpIVars := [:obj :label |
    emit value: ''.
    emit value: ('--- ' , label , '  (' , obj class name asString , ') instance variables ---').
    [obj class allInstVarNames do: [:n |
        | v |
        v := [obj instVarNamed: n] on: err do: [:ex | '<err: ' , ex description , '>'].
        emit value: ('  ' , n , '  =  ' ,
            (trunc value:
                (v == nil
                    ifTrue: ['nil']
                    ifFalse: [[v printString] on: err do: [:ex | '<print err>']])
                value: 140))]]
        on: err do: [:ex | emit value: ('  (instVar dump failed: ' , ex description , ')')]].

"Try selectors in order, return the first NON-EMPTY collection.
 Reports which selector was used via the trailing Core.Array 2nd slot."
findChildren := [:obj :selectorList |
    | result usedSel |
    result := nil.
    usedSel := nil.
    selectorList do: [:sel |
        result == nil ifTrue: [
            (obj ~~ nil and: [obj respondsTo: sel]) ifTrue: [
                | c |
                c := [obj perform: sel] on: err do: [:ex | nil].
                (c ~~ nil and: [(c respondsTo: #size) and: [c size > 0]]) ifTrue: [
                    result := c.
                    usedSel := sel]]]].
    Core.Array with: result with: usedSel].

dumpMenuItems := [:menu :prefix |
    | found items selUsed |
    found := findChildren value: menu value: #(items menuItems components subViews).
    items := found at: 1.
    selUsed := found at: 2.
    items == nil
        ifTrue: [emit value: (prefix , '(no items via items/menuItems/components/subViews)')]
        ifFalse: [
            emit value: (prefix , 'items count: ' , items size printString , '  (via ' , selUsed asString , ')').
            items doWithIndex: [:item :i |
                | sub |
                emit value: (prefix , '  ' , i printString , '. ' ,
                    ([item class name asString] on: err do: [:ex | '?']) ,
                    '  label=' , (attr value: item value: #label) ,
                    '  value=' , (attr value: item value: #value) ,
                    '  rawLabel=' , (attr value: item value: #rawLabel) ,
                    '  enabled=' , (attr value: item value: #enabled)).
                sub := (item respondsTo: #submenu)
                    ifTrue: [[item submenu] on: err do: [:ex | nil]]
                    ifFalse: [nil].
                sub ~~ nil ifTrue: [
                    emit value: (prefix , '       -> submenu: ' , sub class name asString , '  itemCount=' ,
                        ([sub items size printString] on: err do: [:ex | '?']))]]]].

emit value: '=== MAS MENU VISUAL-SIDE PROBE v5 ==='.

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
                masApp := [masCtrl model] on: err do: [:ex | nil].
                (masApp == nil or: [([masApp builder] on: err do: [:ex | nil]) == nil])
                    ifTrue: [masApp := [masCtrl view application] on: err do: [:ex | nil]].
                masView := [masCtrl view] on: err do: [:ex | nil].
                emit value: ('MAS app: ' , (masApp == nil ifTrue: ['nil'] ifFalse: [masApp class name asString])).
                emit value: ('MAS view: ' , (masView == nil ifTrue: ['nil'] ifFalse: [masView class name asString])).

                menuBar := (masView respondsTo: #menuBar)
                    ifTrue: [[masView menuBar] on: err do: [:ex | nil]]
                    ifFalse: [nil].
                emit value: ('menuBar: ' , (menuBar == nil ifTrue: ['nil'] ifFalse: [menuBar class name asString])).

                "Fallback: dump menuBar instVars so we always see something."
                menuBar ~~ nil ifTrue: [dumpIVars value: menuBar value: 'menuBar'].

                menuBar == nil
                    ifTrue: [emit value: 'No menuBar - aborting menu enumeration.']
                    ifFalse: [
                        | found |
                        emit value: ''.
                        emit value: '--- menuBar children (via fallback selectors) ---'.
                        found := findChildren value: menuBar value: #(items components subViews menuItems).
                        barChildren := found at: 1.
                        barSelectorUsed := found at: 2.
                        barChildren == nil
                            ifTrue: [emit value: '  *** menuBar exposes NO non-empty children via items/components/subViews/menuItems ***']
                            ifFalse: [
                                emit value: ('  found ' , barChildren size printString ,
                                    ' children via menuBar>>' , barSelectorUsed asString).

                                barChildren doWithIndex: [:wrapper :i |
                                    | btn lbl mh fc |
                                    fc := findChildren value: wrapper value: #(subViews components items widget).
                                    btn := (fc at: 1) == nil ifTrue: [nil]
                                        ifFalse: [
                                            ((fc at: 1) isKindOf: Core.Collection)
                                                ifTrue: [(fc at: 1) first]
                                                ifFalse: [fc at: 1]].
                                    innerSelectorUsed := fc at: 2.
                                    emit value: ''.
                                    emit value: ('  [' , i printString , '] wrapper=' , wrapper class name asString ,
                                        '  inner-via=' , (innerSelectorUsed == nil ifTrue: ['none'] ifFalse: [innerSelectorUsed asString]) ,
                                        '  inner=' , (btn == nil ifTrue: ['nil'] ifFalse: [btn class name asString])).
                                    btn ~~ nil ifTrue: [
                                        lbl := (btn respondsTo: #label)
                                            ifTrue: [[btn label printString] on: err do: [:ex | '?']]
                                            ifFalse: ['-'].
                                        mh := (btn respondsTo: #menuHolder)
                                            ifTrue: [[btn menuHolder] on: err do: [:ex | nil]]
                                            ifFalse: [nil].
                                        emit value: ('       label: ' , lbl).
                                        emit value: ('       menuHolder: ' , (mh == nil ifTrue: ['nil'] ifFalse: [mh class name asString])).
                                        mh ~~ nil ifTrue: [dumpMenuItems value: mh value: '       ']]].

                                "Deep dive into button #1 (Party & Contract)"
                                firstBtn := nil.
                                barChildren size > 0 ifTrue: [
                                    | fc |
                                    fc := findChildren value: (barChildren at: 1) value: #(subViews components items widget).
                                    (fc at: 1) ~~ nil ifTrue: [
                                        firstBtn := ((fc at: 1) isKindOf: Core.Collection)
                                            ifTrue: [(fc at: 1) first]
                                            ifFalse: [fc at: 1]]].
                                firstBtn ~~ nil ifTrue: [
                                    firstController := [firstBtn controller] on: err do: [:ex | nil].
                                    emit value: ''.
                                    emit value: '=== DEEP-DIVE: Party & Contract MenuBarButton ==='.
                                    emit value: ('button: ' , firstBtn class name asString).
                                    emit value: ('controller: ' , (firstController == nil ifTrue: ['nil'] ifFalse: [firstController class name asString])).
                                    firstController ~~ nil ifTrue: [
                                        dumpIVars value: firstController value: 'MenuBarButtonController'.
                                        emit value: ''.
                                        emit value: '--- Click/dispatch selectors that respond on controller ---'.
                                        #(select activate invoke show showMenu displayPopupMenu pressed buttonPressed
                                           performAction sendValue trigger doIt redButtonPressedEvent:)
                                            do: [:sel |
                                                emit value: ('  ' , sel asString , '  respondsTo: ' ,
                                                    (firstController respondsTo: sel) printString)].
                                        emit value: ''.
                                        emit value: '--- MenuBarButtonController method categories ---'.
                                        [firstController class organization categories do: [:cat |
                                            | sels |
                                            sels := firstController class organization listAtCategoryNamed: cat.
                                            emit value: ('  [' , cat , ']  ' ,
                                                (sels == nil ifTrue: ['-'] ifFalse: [sels printString]))]]
                                            on: err do: [:ex | emit value: '  (cat dump failed: ' , ex description , ')']]]]]]].

emit value: ''.
emit value: '=== PROBE v5 DONE ==='.

outFile := 'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\probes\mas_menu_visual_v5.txt' asFilename writeStream.
[outFile nextPutAll: out contents] ensure: [outFile close].

transcript := lookup value: #Transcript.
transcript == nil ifFalse: [
    transcript cr; show: out contents.
    transcript cr; show: 'Saved: C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\probes\mas_menu_visual_v5.txt'; cr]
