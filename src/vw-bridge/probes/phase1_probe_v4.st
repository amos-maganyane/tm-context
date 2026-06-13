"=== VW WIDGET DISCOVERY PROBE v4 -- READ-ONLY ==="
"v4: ALL namespace references fully qualified. v3 hit the ambiguity
 dialog on 'Smalltalk' itself (this is a GBS image: VisualAgeCompatibility
 and GemStoneClasses shadow kernel names), so Smalltalk is now spelled
 Root.Smalltalk and the lookup helper searches sub-namespaces at runtime.
 RUN: open a NEW Workspace -> paste -> Select All -> Do It (Ctrl+E).
 If any dialog still pops up: click Cancel and report its exact text.
 Output: C:\Users\ammaganyane\forge\phase1_results.txt (file is written
 even if the Transcript is unavailable). Makes NO changes to the image."

| err nl results emit lookup flag checkInst checkMeta processor ctrlMgr transcript out |

err := Core.Error.
nl := Core.String with: (Core.Character value: 13) with: (Core.Character value: 10).
results := Core.WriteStream on: Core.String new.
emit := [:line | results nextPutAll: line; nextPutAll: nl].
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

emit value: '=== VW WIDGET PROBE v4 ==='.
emit value: ('Version: ' , ([Root.Smalltalk version] on: err do: [:ex | 'unknown'])).

emit value: ''.
emit value: '--- KEY GLOBALS (+ found / - missing, multi-namespace lookup) ---'.
#(ScheduledControllers ControlManager ApplicationModel UIBuilder
  SpecWrapper WidgetWrapper BoundedWrapper
  Socket SocketAccessor OSSocketAccessor SpOpStream IPSocketAddress
  SimpleHTTPClient HTTPServer HttpServer
  UIProcess WorldState UUID UUIDGenerator Filename Semaphore
  Processor Transcript Time Delay Random)
    do: [:sym | emit value: ((flag value: (lookup value: sym) ~~ nil) , sym)].

emit value: ''.
emit value: '--- SELECTOR CHECKS, instance side ---'.
checkInst := [:clsSym :sel | | cls ok |
    cls := lookup value: clsSym.
    ok := cls ~~ nil and: [cls isBehavior and: [cls canUnderstand: sel]].
    emit value: ((flag value: ok) , clsSym , '>>' , sel)].
checkMeta := [:clsSym :sel | | cls ok |
    cls := lookup value: clsSym.
    ok := cls ~~ nil and: [cls isBehavior and: [cls class canUnderstand: sel]].
    emit value: ((flag value: ok) , clsSym , ' class>>' , sel)].

checkInst value: #String value: #formatWith:.
checkInst value: #String value: #bindWith:.
checkInst value: #String value: #bindWithArguments:.
checkInst value: #String value: #expandMacrosWithArguments:.
checkInst value: #String value: #subStrings:.
checkInst value: #String value: #tokensBasedOn:.
checkInst value: #String value: #copyReplaceAll:with:.
checkInst value: #String value: #asFilename.
checkInst value: #OrderedCollection value: #do:separatedBy:.
checkInst value: #Array value: #doWithIndex:.
checkInst value: #Array value: #keysAndValuesDo:.
checkInst value: #BlockClosure value: #fork.
checkInst value: #BlockClosure value: #forkAt:.
checkInst value: #Semaphore value: #waitTimeoutMSecs:.
checkInst value: #Semaphore value: #waitTimeoutMilliseconds:.
checkInst value: #Semaphore value: #waitTimeoutSeconds:.
checkInst value: #Process value: #interruptWith:.
checkInst value: #SocketAccessor value: #accept.
checkInst value: #SocketAccessor value: #listenFor:.
checkInst value: #SocketAccessor value: #bindTo:.
checkInst value: #SocketAccessor value: #readAppendStream.
checkInst value: #SocketAccessor value: #readWriteStream.
checkInst value: #SocketAccessor value: #readStream.
checkInst value: #SocketAccessor value: #writeStream.

emit value: ''.
emit value: '--- SELECTOR CHECKS, class side ---'.
checkMeta value: #SocketAccessor value: #newTCPserverAtPort:.
checkMeta value: #SocketAccessor value: #newTCPclientToHost:port:.
checkMeta value: #UUID value: #new.
checkMeta value: #UUIDGenerator value: #next.
checkMeta value: #Delay value: #forMilliseconds:.
checkMeta value: #Time value: #millisecondClockValue.

emit value: ''.
emit value: '--- PROCESSOR PRIORITIES ---'.
processor := lookup value: #Processor.
processor == nil
    ifTrue: [emit value: '  - Processor not found via lookup']
    ifFalse: [
        emit value: ((flag value: ([processor userBackgroundPriority. true] on: err do: [:ex | false])) , 'Processor userBackgroundPriority').
        emit value: ((flag value: ([processor userSchedulingPriority. true] on: err do: [:ex | false])) , 'Processor userSchedulingPriority').
        emit value: ('  activePriority = ' , ([processor activePriority printString] on: err do: [:ex | '?']))].

emit value: ''.
emit value: '--- OPEN WINDOWS ---'.
ctrlMgr := lookup value: #ScheduledControllers.
ctrlMgr == nil
    ifTrue: [emit value: '  ScheduledControllers not found - cannot enumerate windows.']
    ifFalse: [
        | ctrls idx |
        ctrls := [ctrlMgr scheduledControllers] on: err do: [:ex | #()].
        emit value: ('  window count: ' , ctrls size printString).
        idx := 0.
        ctrls do: [:ctrl |
            idx := idx + 1.
            [| view label viewClass c1 c2 c1Class c2Class bounds |
             view := [ctrl view] on: err do: [:ex | nil].
             label := [view label printString] on: err do: [:ex | '(no label)'].
             viewClass := view == nil ifTrue: ['nil'] ifFalse: [[view class name asString] on: err do: [:ex | '?']].
             c1 := [ctrl model] on: err do: [:ex | nil].
             c2 := [view application] on: err do: [:ex | nil].
             c1Class := c1 == nil ifTrue: ['nil'] ifFalse: [[c1 class name asString] on: err do: [:ex | '?']].
             c2Class := c2 == nil ifTrue: ['nil'] ifFalse: [[c2 class name asString] on: err do: [:ex | '?']].
             bounds := [view displayBox printString] on: err do: [:ex | '?'].
             emit value: ('  [' , idx printString , '] ' , label).
             emit value: ('      view=' , viewClass , ' ctrlModel=' , c1Class , ' viewApp=' , c2Class).
             emit value: ('      bounds=' , bounds)]
                on: err do: [:ex | emit value: ('  [' , idx printString , '] window inspect failed: ' , ex description)]].

        emit value: ''.
        emit value: '--- WIDGET TREES (every window with a builder) ---'.
        idx := 0.
        ctrls do: [:ctrl |
            idx := idx + 1.
            [| view label c1 c2 app builder b1 b2 |
             view := [ctrl view] on: err do: [:ex | nil].
             label := [view label printString] on: err do: [:ex | '(no label)'].
             c1 := [ctrl model] on: err do: [:ex | nil].
             c2 := [view application] on: err do: [:ex | nil].
             app := nil.
             builder := nil.
             c1 == nil ifFalse: [
                 b1 := [c1 builder] on: err do: [:ex | nil].
                 b1 == nil ifFalse: [app := c1. builder := b1]].
             (builder == nil and: [c2 ~~ nil]) ifTrue: [
                 b2 := [c2 builder] on: err do: [:ex | nil].
                 b2 == nil ifFalse: [app := c2. builder := b2]].
             builder == nil
                 ifTrue: [emit value: ('  [' , idx printString , '] ' , label , ' - no builder')]
                 ifFalse: [
                     | comps |
                     comps := [builder namedComponents] on: err do: [:ex | nil].
                     comps == nil
                         ifTrue: [emit value: ('  [' , idx printString , '] ' , label , ' - builder present but namedComponents failed')]
                         ifFalse: [
                             emit value: ('  [' , idx printString , '] ' , label , ' - ' , comps size printString , ' named components (app=' , app class name asString , ')').
                             comps keysAndValuesDo: [:aspect :wrapper |
                                 | specLabel specClass widgetClass val |
                                 specLabel := [wrapper spec label printString] on: err do: [:ex | '?'].
                                 specClass := [wrapper spec class name asString] on: err do: [:ex | '?'].
                                 widgetClass := [wrapper widget class name asString] on: err do: [:ex | '?'].
                                 val := [wrapper widget model value printString] on: err do: [:ex | '?'].
                                 val size > 60 ifTrue: [val := (val copyFrom: 1 to: 57) , '...'].
                                 emit value: ('      ' , aspect printString , ' spec=' , specClass , ' widget=' , widgetClass , ' label=' , specLabel , ' value=' , val)]]]]
                on: err do: [:ex | emit value: ('  [' , idx printString , '] tree walk failed: ' , ex description)]]].

emit value: ''.
emit value: '=== PROBE DONE ==='.

out := 'C:\Users\ammaganyane\forge\phase1_results.txt' asFilename writeStream.
[out nextPutAll: results contents] ensure: [out close].

transcript := lookup value: #Transcript.
transcript == nil ifFalse: [
    transcript cr; show: results contents.
    transcript cr; show: 'Report written to C:\Users\ammaganyane\forge\phase1_results.txt'; cr].
