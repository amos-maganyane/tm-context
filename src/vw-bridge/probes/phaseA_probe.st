"=== Phase A API Discovery Probe v1 ==="
"Paste into VW workspace, Ctrl+E (Do It), check Transcript."
"Tests: Display, event classes, PNG encoding, Base64, widget interaction APIs"

| err out |

err := Core.Error.
out := Core.WriteStream on: Core.String new.

out cr; cr; show: '=== PHASE A API PROBE v1 ==='; cr.

"--- Display ---"
| display |
display := Root.Smalltalk at: #Display ifAbsent: [nil].
display == nil ifTrue: [
    display := [Root.Smalltalk.Screen default] on: err do: [:e | nil]].
out cr; show: 'Display: '; show: (display == nil ifTrue: ['- MISSING'] ifFalse: ['+ ' , display class name asString]).

"--- Screen image capture ---"
display ~~ nil ifTrue: [
    [| form |
    form := display contentsOfArea: display boundingBox.
    out cr; show: 'Display>>contentsOfArea: '; show: form class name asString.
    out cr; show: '  Form extent: '; show: form extent printString.
    out cr; show: '  Form depth: '; show: form depth printString] on: err do: [:e |
        out cr; show: 'Display>>contentsOfArea: - FAILED: '; show: e description asString]].

"--- PNG encoding ---"
| pngWriter |
pngWriter := Root.Smalltalk at: #PNGReadWriter ifAbsent: [nil].
pngWriter == nil ifTrue: [
    pngWriter := Root.Smalltalk at: #ImageReadWriter ifAbsent: [nil]].
pngWriter == nil ifTrue: [
    #(Graphics UI) do: [:ns |
        | n |
        n := Root.Smalltalk at: ns ifAbsent: [nil].
        n ~~ nil ifTrue: [
            pngWriter == nil ifTrue: [pngWriter := n at: #PNGReadWriter ifAbsent: [nil]].
            pngWriter == nil ifTrue: [pngWriter := n at: #ImageReadWriter ifAbsent: [nil]]]]].
out cr; show: 'PNGReadWriter: '; show: (pngWriter == nil ifTrue: ['- MISSING'] ifFalse: ['+ ' , pngWriter name]).

"--- Base64 ---"
| b64 |
b64 := Root.Smalltalk at: #Base64MimeConverter ifAbsent: [nil].
b64 == nil ifTrue: [b64 := Root.Smalltalk at: #Base64Encoder ifAbsent: [nil]].
b64 == nil ifTrue: [b64 := Root.Smalltalk at: #MIMEBase64 ifAbsent: [nil]].
#(Net Core) do: [:ns |
    | n |
    n := Root.Smalltalk at: ns ifAbsent: [nil].
    n ~~ nil ifTrue: [
        b64 == nil ifTrue: [b64 := n at: #Base64MimeConverter ifAbsent: [nil]].
        b64 == nil ifTrue: [b64 := n at: #Base64Encoder ifAbsent: [nil]]]]].
out cr; show: 'Base64: '; show: (b64 == nil ifTrue: ['- MISSING (will implement manually)'] ifFalse: ['+ ' , b64 name]).

"--- Event classes (for click synthesis) ---"
#(ButtonPress ButtonRelease ButtonPressEvent ButtonReleaseEvent
   MouseButtonEvent InputEvent InputState
   WindowEvent KeyboardEvent KeyPress KeyRelease)
do: [:sym |
    | cls |
    cls := Root.Smalltalk at: sym ifAbsent: [nil].
    cls == nil ifTrue: [
        #(UI Graphics Kernel) do: [:ns |
            | n |
            n := Root.Smalltalk at: ns ifAbsent: [nil].
            n ~~ nil ifTrue: [
                cls == nil ifTrue: [cls := n at: sym ifAbsent: [nil]]]]].
    out cr; show: '  '; show: sym; show: ': '; show: (cls == nil ifTrue: ['-'] ifFalse: ['+' , cls name])].

"--- Widget controller selectors ---"
| sc |
sc := Root.Smalltalk at: #ScheduledControllers ifAbsent: [nil].
sc ~~ nil ifTrue: [
    [| ctrl app builder wrappers |
    ctrl := sc scheduledControllers first.
    app := ctrl model.
    app ~~ nil ifTrue: [
        builder := [app builder] on: err do: [:e | nil].
        builder ~~ nil ifTrue: [
            wrappers := [builder namedComponents] on: err do: [:e | nil].
            wrappers ~~ nil ifTrue: [
                | wrapper widget |
                wrapper := wrappers values detect: [:w |
                    [w spec class name = 'ActionButtonSpec'] on: err do: [:e | false]] ifNone: [nil].
                wrapper ~~ nil ifTrue: [
                    widget := [wrapper widget] on: err do: [:e | nil].
                    widget ~~ nil ifTrue: [
                        out cr; show: '--- Button widget controller API ---'.
                        out cr; show: '  widget class: '; show: widget class name asString.
                        [| ctrl |
                        ctrl := widget controller.
                        out cr; show: '  controller class: '; show: ctrl class name asString.
                        out cr; show: '  respondsTo #performAction: '; show: (ctrl respondsTo: #performAction) printString.
                        out cr; show: '  respondsTo #performActionFor: '; show: (ctrl respondsTo: #performActionFor:) printString.
                        out cr; show: '  respondsTo #dispatchEvent: '; show: (ctrl respondsTo: #dispatchEvent:) printString.
                        out cr; show: '  respondsTo #handleEvent: '; show: (ctrl respondsTo: #handleEvent:) printString] on: err do: [:e |
                            out cr; show: '  controller error: '; show: e description asString]]].
                "--- InputFieldView ---"
                wrapper := wrappers values detect: [:w |
                    [w spec class name = 'InputFieldSpec'] on: err do: [:e | false]] ifNone: [nil].
                wrapper ~~ nil ifTrue: [
                    widget := [wrapper widget] on: err do: [:e | nil].
                    widget ~~ nil ifTrue: [
                        out cr; show: '--- InputField widget API ---'.
                        out cr; show: '  widget class: '; show: widget class name asString.
                        | model |
                        model := [widget model] on: err do: [:e | nil].
                        model ~~ nil ifTrue: [
                            out cr; show: '  model class: '; show: model class name asString.
                            out cr; show: '  respondsTo #value: '; show: (model respondsTo: #value:) printString].
                        out cr; show: '  respondsTo #controller: '; show: (widget respondsTo: #controller) printString.
                        out cr; show: '  respondsTo #takeKeyboardFocus: '; show: (widget respondsTo: #takeKeyboardFocus) printString]]]]]]] on: err do: [:e |
                            out cr; show: 'Widget probe error: '; show: e description asString]].

"--- Filename / temp file writing ---"
| fn |
fn := Root.Smalltalk at: #Filename ifAbsent: [nil].
fn == nil ifTrue: [
    #(OS) do: [:ns |
        | n |
        n := Root.Smalltalk at: ns ifAbsent: [nil].
        n ~~ nil ifTrue: [
            fn == nil ifTrue: [fn := n at: #Filename ifAbsent: [nil]]]]].
out cr; show: 'Filename: '; show: (fn == nil ifTrue: ['- MISSING'] ifFalse: ['+ ' , fn name]).
fn ~~ nil ifTrue: [
    [| tmp f |
    tmp := fn named: 'C:\Users\ammaganyane\forge\probe_write_test.txt'.
    f := [tmp writeStream] on: err do: [:e | nil].
    f ~~ nil ifTrue: [
        f nextPutAll: 'test'; close; close.
        out cr; show: 'Filename>>writeStream: OK'].
    f == nil ifTrue: [
        out cr; show: 'Filename>>writeStream: FAILED']] on: err do: [:e |
        out cr; show: 'Filename test FAILED: '; show: e description asString]].

out cr; cr; show: '=== PROBE DONE ==='.
Transcript cr; show: out contents
