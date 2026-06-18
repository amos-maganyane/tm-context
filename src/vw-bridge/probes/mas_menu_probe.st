"=== MAS Menu Structure Probe v3 - READ-ONLY ===
 Goal: learn HOW the masApp mainMenu MenuItems dispatch their actions
 (since v2 showed all top-level MenuItem value=nil, the standard
 'app perform: aSymbol' click model doesn't apply directly), AND
 enumerate the submenu structure so we can find 'Client & Contract'
 nested under 'Party & Contract'.

 Specifically dumps:
   - The full Menu structure recursively (top items + submenus + grandchildren)
   - For Party & Contract (item #1), every instance variable name + value
     printString (truncated) - to find any action-carrying ivar that
     isn't exposed via a public accessor
   - For its MenuBarButtonView (the visual side), the same instVar dump

 RUN: paste into a VW Workspace and Do It, OR:
   'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\probes\mas_menu_probe.st' asFilename fileIn
 WRITES: C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\probes\mas_menu_results.txt
 SAFETY: read-only. No menu activation, no UI mutation, no clicks."

| err nl out emit lookup attr trunc dumpIVars dumpMenuTree
  mgr masCtrl masApp masView masMenu firstItem menuBar firstBtn outFile transcript |

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
        ifTrue: [[(obj perform: sel) printString] on: err do: [:ex | '-']]
        ifFalse: ['-']].

dumpIVars := [:obj :label |
    emit value: ''.
    emit value: ('--- ' , label , '  (' , obj class name asString , ') instance variables ---').
    [obj class allInstVarNames do: [:n |
        | v |
        v := [obj instVarNamed: n] on: err do: [:ex | '<err: ' , ex description , '>'].
        emit value: ('  ' , n , '  =  ' ,
            (trunc value: (v == nil ifTrue: ['nil'] ifFalse: [[v printString] on: err do: [:ex | '<print err>']]) value: 120))]]
        on: err do: [:ex | emit value: ('  (instVar dump failed: ' , ex description , ')')]].

dumpMenuTree := [:menu :prefix :depth |
    | items |
    depth > 5 ifTrue: [emit value: (prefix , '  *** depth cap ***')]
        ifFalse: [
            items := [menu items] on: err do: [:ex | nil].
            items == nil
                ifTrue: [emit value: (prefix , '  (no items)')]
                ifFalse: [
                    items doWithIndex: [:it :i |
                        | sub |
                        emit value: (prefix , i printString , '. ' ,
                            (attr value: it value: #label) ,
                            '   value=' , (attr value: it value: #value) ,
                            '   nameKey=' , (attr value: it value: #nameKey) ,
                            '   enabled=' , (attr value: it value: #enabled)).
                        sub := (it respondsTo: #submenu)
                            ifTrue: [[it submenu] on: err do: [:ex | nil]]
                            ifFalse: [nil].
                        sub ~~ nil ifTrue: [
                            emit value: (prefix , '   -> submenu (' , sub class name asString , ')').
                            dumpMenuTree value: sub value: (prefix , '     ') value: depth + 1]]]]].

emit value: '=== MAS MENU PROBE v3 ==='.

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

                "--- 1. Full menu tree recursion ---"
                masMenu := (masApp respondsTo: #mainMenu)
                    ifTrue: [[masApp mainMenu] on: err do: [:ex | nil]]
                    ifFalse: [nil].
                emit value: ''.
                emit value: '--- masApp mainMenu structure (recursive) ---'.
                masMenu == nil
                    ifTrue: [emit value: '  (mainMenu is nil)']
                    ifFalse: [
                        emit value: ('  class: ' , masMenu class name asString).
                        dumpMenuTree value: masMenu value: '  ' value: 0].

                "--- 2. Party & Contract MenuItem: every instance variable ---"
                firstItem := (masMenu ~~ nil and: [(masMenu respondsTo: #items)])
                    ifTrue: [[masMenu items first] on: err do: [:ex | nil]]
                    ifFalse: [nil].
                firstItem ~~ nil ifTrue: [
                    dumpIVars value: firstItem value: 'Party & Contract MenuItem'].

                "--- 3. Selectors that suggest action dispatch on the MenuItem ---"
                emit value: ''.
                emit value: '--- Action-related selectors that respond on Party & Contract item ---'.
                firstItem ~~ nil ifTrue: [
                    #(action perform send selector receiver target block actionBlock submenu) do: [:sel |
                        (firstItem respondsTo: sel) ifTrue: [
                            | v |
                            v := [firstItem perform: sel] on: err do: [:ex | '<err: ' , ex description , '>'].
                            emit value: ('  ' , sel asString , ' -> ' ,
                                (trunc value: (v == nil ifTrue: ['nil'] ifFalse: [v printString]) value: 100))]]].

                "--- 4. MenuBar visual side: first MenuBarButtonView ---"
                menuBar := (masView respondsTo: #menuBar)
                    ifTrue: [[masView menuBar] on: err do: [:ex | nil]]
                    ifFalse: [nil].
                firstBtn := nil.
                menuBar ~~ nil ifTrue: [
                    "Navigate menuBar -> components/items/subViews -> first wrapper -> first widget"
                    | barChildren firstWrapper |
                    barChildren := nil.
                    #(items components subViews) do: [:sel |
                        (barChildren == nil and: [menuBar respondsTo: sel]) ifTrue: [
                            barChildren := [menuBar perform: sel] on: err do: [:ex | nil]]].
                    (barChildren ~~ nil and: [barChildren size > 0]) ifTrue: [
                        firstWrapper := barChildren first.
                        (firstWrapper respondsTo: #subViews) ifTrue: [
                            | subs |
                            subs := [firstWrapper subViews] on: err do: [:ex | #()].
                            subs size > 0 ifTrue: [firstBtn := subs first]].
                        firstBtn == nil ifTrue: [
                            (firstWrapper respondsTo: #widget) ifTrue: [
                                firstBtn := [firstWrapper widget] on: err do: [:ex | nil]]]]].

                firstBtn ~~ nil
                    ifTrue: [
                        emit value: ''.
                        emit value: ('--- First MenuBarButtonView (visual Party & Contract) ---').
                        emit value: ('  class: ' , firstBtn class name asString).
                        dumpIVars value: firstBtn value: 'First MenuBarButtonView'.
                        emit value: ''.
                        emit value: '--- Action-related selectors that respond on the MenuBarButtonView ---'.
                        #(model controller action perform press click invoke triggerEvent) do: [:sel |
                            (firstBtn respondsTo: sel) ifTrue: [
                                | v |
                                v := [firstBtn perform: sel] on: err do: [:ex | '<err: ' , ex description , '>'].
                                emit value: ('  ' , sel asString , ' -> ' ,
                                    (trunc value: (v == nil ifTrue: ['nil'] ifFalse: [v printString]) value: 100))]]]
                    ifFalse: [emit value: ''. emit value: '*** could not locate first MenuBarButtonView ***']]].

emit value: ''.
emit value: '=== PROBE v3 DONE ==='.

outFile := 'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\probes\mas_menu_results.txt' asFilename writeStream.
[outFile nextPutAll: out contents] ensure: [outFile close].

transcript := lookup value: #Transcript.
transcript == nil ifFalse: [
    transcript cr; show: out contents.
    transcript cr; show: 'Saved: C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\probes\mas_menu_results.txt'; cr]
