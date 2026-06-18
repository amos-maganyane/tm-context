"=== MAS Menu Visual-Side Probe v4 - READ-ONLY ===
 Goal: enumerate menus via the visual MenuBar path (stable per v2),
 since masApp.mainMenu in v3 returned empty items (unreliable/lazy).
 Specifically:
   1. Walk masView.menuBar.subViews -> each is a BoundedWrapper that
      wraps a MenuBarButtonView; for each, report button label,
      menuHolder class, and menuHolder items (the dropdown content).
   2. For Party & Contract (button #1):
      - Dump its MenuBarButtonController instance variables.
      - Probe likely 'click' / 'open submenu' selectors on the
        controller (read-only - we only check respondsTo:, we do NOT
        invoke the dispatch).
      - List the class method categories so we can see what protocol
        the controller exposes.

 RUN: 'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\probes\mas_menu_visual_probe.st' asFilename fileIn
 WRITES: C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\probes\mas_menu_visual_results.txt
 SAFETY: read-only. Does NOT activate menus, does NOT click."

| err nl out emit lookup attr trunc dumpIVars dumpMenuItems
  mgr masCtrl masApp masView menuBar barChildren firstBtn firstController
  outFile transcript |

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

"Try multiple item-source selectors on a Menu; return items collection or nil."
dumpMenuItems := [:menu :prefix |
    | items |
    items := nil.
    #(items menuItems components subViews) do: [:sel |
        (items == nil and: [menu respondsTo: sel]) ifTrue: [
            items := [menu perform: sel] on: err do: [:ex | nil].
            "Discard empty collections so we keep trying other selectors."
            (items ~~ nil and: [(items respondsTo: #isEmpty) and: [items isEmpty]])
                ifTrue: [items := nil]]].
    items == nil
        ifTrue: [emit value: (prefix , '(no items found via items/menuItems/components/subViews)')]
        ifFalse: [
            emit value: (prefix , 'items count: ' , items size printString , '  (via ' , items class name asString , ')').
            items doWithIndex: [:item :i |
                | sub |
                emit value: (prefix , '  ' , i printString , '. ' ,
                    ([item class name asString] on: err do: [:ex | '?']) ,
                    '  label=' , (attr value: item value: #label) ,
                    '  value=' , (attr value: item value: #value) ,
                    '  rawLabel=' , (attr value: item value: #rawLabel) ,
                    '  enabled=' , (attr value: item value: #enabled)).
                "Hint at any submenu."
                sub := (item respondsTo: #submenu)
                    ifTrue: [[item submenu] on: err do: [:ex | nil]]
                    ifFalse: [nil].
                sub ~~ nil ifTrue: [
                    emit value: (prefix , '       -> submenu: ' , sub class name asString , '  itemCount=' ,
                        ([sub items size printString] on: err do: [:ex | '?']))]]]].

emit value: '=== MAS MENU VISUAL-SIDE PROBE v4 ==='.

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

                menuBar == nil
                    ifTrue: [emit value: 'No menuBar - aborting menu enumeration.']
                    ifFalse: [
                        "--- 1. Walk every top-level menu button + its dropdown ---"
                        emit value: ''.
                        emit value: '--- Top-level menu buttons (via menuBar.subViews) ---'.
                        barChildren := [menuBar subViews] on: err do: [:ex | #()].
                        emit value: ('  count: ' , barChildren size printString).
                        barChildren doWithIndex: [:wrapper :i |
                            | btn lbl mh |
                            btn := nil.
                            (wrapper respondsTo: #subViews) ifTrue: [
                                | s |
                                s := [wrapper subViews] on: err do: [:ex | #()].
                                s size > 0 ifTrue: [btn := s first]].
                            emit value: ''.
                            emit value: ('  [' , i printString , '] wrapper=' , wrapper class name asString ,
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
                                mh ~~ nil ifTrue: [
                                    dumpMenuItems value: mh value: '       ']]].

                        "--- 2. Drill into Party & Contract (button #1) ---"
                        firstBtn := nil.
                        barChildren size > 0 ifTrue: [
                            | s |
                            s := [(barChildren at: 1) subViews] on: err do: [:ex | #()].
                            s size > 0 ifTrue: [firstBtn := s first]].
                        firstBtn ~~ nil ifTrue: [
                            firstController := [firstBtn controller] on: err do: [:ex | nil].
                            emit value: ''.
                            emit value: '=== DEEP-DIVE: Party & Contract MenuBarButton ==='.
                            emit value: ('button: ' , firstBtn class name asString).
                            emit value: ('controller: ' , (firstController == nil ifTrue: ['nil'] ifFalse: [firstController class name asString])).
                            firstController ~~ nil ifTrue: [
                                dumpIVars value: firstController value: 'MenuBarButtonController'.
                                emit value: ''.
                                emit value: '--- Click/dispatch selectors that respond on controller (read-only) ---'.
                                #(select activate invoke show showMenu displayPopupMenu pressed buttonPressed
                                   performAction sendValue trigger doIt pressed: redButtonPressedEvent:)
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
                                    on: err do: [:ex | emit value: '  (cat dump failed: ' , ex description , ')'].
                                emit value: ''.
                                emit value: '--- Click/dispatch selectors that respond on the BUTTON itself ---'.
                                #(displayPopupMenu showMenu pressed buttonPressed performAction trigger doIt
                                   selectMenu openMenu)
                                    do: [:sel |
                                        emit value: ('  ' , sel asString , '  respondsTo: ' ,
                                            (firstBtn respondsTo: sel) printString)]]]]]].

emit value: ''.
emit value: '=== PROBE v4 DONE ==='.

outFile := 'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\probes\mas_menu_visual_results.txt' asFilename writeStream.
[outFile nextPutAll: out contents] ensure: [outFile close].

transcript := lookup value: #Transcript.
transcript == nil ifFalse: [
    transcript cr; show: out contents.
    transcript cr; show: 'Saved: C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\probes\mas_menu_visual_results.txt'; cr]
