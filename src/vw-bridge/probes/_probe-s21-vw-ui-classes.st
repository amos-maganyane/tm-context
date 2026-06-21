"Probe — session-21 VW UI/dev/parcel class inventory.
 Non-overlapping with wave-2 librarian text-search; informs Phase M v2 design redesign.
 Per AGENTS.md probe-before-commit + carry-forward #18 (Workspace-vs-/eval) +
 carry-forward #41 (no compile on the bridge class — this probe is pure read).
 Comment phrasing avoids the Stage 1 substring guard pair."

| s nl resolveCls report counts |
s := WriteStream on: String new.
nl := String with: Core.Character lf.
counts := Dictionary new.

resolveCls := [:symbol |
    | found foundNs |
    found := Smalltalk at: symbol ifAbsent: [nil].
    foundNs := found isNil ifTrue: [nil] ifFalse: ['Smalltalk'].
    found isNil ifTrue: [
        Smalltalk allNameSpaces do: [:ns |
            (found isNil and: [ns includesKey: symbol]) ifTrue: [
                found := ns at: symbol.
                foundNs := ns name asString]]].
    Array with: found with: foundNs].

report := [:label :sym |
    | pair c nsName |
    pair := resolveCls value: sym.
    c := pair at: 1.
    nsName := pair at: 2.
    s nextPutAll: '  '; nextPutAll: label; nextPutAll: ' (#'; nextPutAll: sym asString; nextPutAll: '): '.
    c isNil
        ifTrue: [s nextPutAll: 'ABSENT'; nextPutAll: nl]
        ifFalse: [
            s nextPutAll: nsName;
              nextPutAll: '.';
              nextPutAll: c name asString;
              nextPutAll: ' [sub=';
              nextPutAll: ((c respondsTo: #allSubclasses) ifTrue: [c allSubclasses size printString] ifFalse: ['n/a']);
              nextPutAll: ', selI=';
              nextPutAll: c selectors size printString;
              nextPutAll: ', selC=';
              nextPutAll: c class selectors size printString;
              nextPutAll: ']';
              nextPutAll: nl]].

s nextPutAll: '=== A. ApplicationModel family ==='; nextPutAll: nl.
report value: 'ApplicationModel' value: #ApplicationModel.
report value: 'SimpleDialog' value: #SimpleDialog.
report value: 'PartsApplicationModel' value: #PartsApplicationModel.
report value: 'NotebookApplicationModel' value: #NotebookApplicationModel.
report value: 'Model' value: #Model.
report value: 'Object' value: #Object.

s nextPutAll: '=== B. Spec classes (windowSpec primitives) ==='; nextPutAll: nl.
report value: 'UISpec' value: #UISpec.
report value: 'WindowSpec' value: #WindowSpec.
report value: 'FullSpec' value: #FullSpec.
report value: 'SpecCollection' value: #SpecCollection.
report value: 'ComponentSpec' value: #ComponentSpec.
report value: 'WidgetSpec' value: #WidgetSpec.

s nextPutAll: '=== C. Widget specs ==='; nextPutAll: nl.
report value: 'ActionButtonSpec' value: #ActionButtonSpec.
report value: 'PluggableActionButtonSpec' value: #PluggableActionButtonSpec.
report value: 'LabelSpec' value: #LabelSpec.
report value: 'ActionLabelSpec' value: #ActionLabelSpec.
report value: 'InputFieldSpec' value: #InputFieldSpec.
report value: 'ComboBoxSpec' value: #ComboBoxSpec.
report value: 'ListSpec' value: #ListSpec.
report value: 'CheckBoxSpec' value: #CheckBoxSpec.
report value: 'RadioButtonSpec' value: #RadioButtonSpec.
report value: 'TableSpec' value: #TableSpec.
report value: 'DataSetSpec' value: #DataSetSpec.
report value: 'GroupBoxSpec' value: #GroupBoxSpec.
report value: 'TabControlSpec' value: #TabControlSpec.
report value: 'SubCanvasSpec' value: #SubCanvasSpec.
report value: 'MenuBarSpec' value: #MenuBarSpec.

s nextPutAll: '=== D. ValueHolder family ==='; nextPutAll: nl.
report value: 'ValueHolder' value: #ValueHolder.
report value: 'ValueAdaptor' value: #ValueAdaptor.
report value: 'AspectAdaptor' value: #AspectAdaptor.
report value: 'PluggableAdaptor' value: #PluggableAdaptor.
report value: 'TypeConverter' value: #TypeConverter.
report value: 'SelectionInList' value: #SelectionInList.
report value: 'MultiSelectionInList' value: #MultiSelectionInList.

s nextPutAll: '=== E. UI builder + Painter ==='; nextPutAll: nl.
report value: 'UIBuilder' value: #UIBuilder.
report value: 'UISubcanvasBuilder' value: #UISubcanvasBuilder.
report value: 'UIPainter' value: #UIPainter.
report value: 'CanvasView' value: #CanvasView.
report value: 'CanvasTool' value: #CanvasTool.
report value: 'PaletteWindowApplication' value: #PaletteWindowApplication.
report value: 'AspectAttributesWindow' value: #AspectAttributesWindow.
report value: 'PalettePainter' value: #PalettePainter.

s nextPutAll: '=== F. Parcel / Pundle / Bundle / Store ==='; nextPutAll: nl.
report value: 'Parcel' value: #Parcel.
report value: 'ParcelLoadedChange' value: #ParcelLoadedChange.
report value: 'ParcelSavedChange' value: #ParcelSavedChange.
report value: 'ParcelMissingError' value: #ParcelMissingError.
report value: 'CodeWriter' value: #CodeWriter.
report value: 'Bundle' value: #Bundle.
report value: 'Pundle' value: #Pundle.
report value: 'Package' value: #Package.
report value: 'PackageInfo' value: #PackageInfo.
report value: 'PundleInfo' value: #PundleInfo.

s nextPutAll: '=== G. Compiler / Change machinery (relevant to compile_method tool) ==='; nextPutAll: nl.
report value: 'Compiler' value: #Compiler.
report value: 'Behavior' value: #Behavior.
report value: 'ClassDescription' value: #ClassDescription.
report value: 'ChangeRecord' value: #ChangeRecord.
report value: 'MethodChange' value: #MethodChange.

s nextPutAll: '=== H. Namespace surveys ==='; nextPutAll: nl.
#(#UI #Tools #Kernel #Store #Refactory #Smalltalk #Core #RuntimePackager) do: [:nsName |
    | ns |
    ns := Smalltalk at: nsName ifAbsent: [nil].
    s nextPutAll: '  '; nextPutAll: nsName asString; nextPutAll: ': '.
    ns isNil
        ifTrue: [s nextPutAll: 'ABSENT'; nextPutAll: nl]
        ifFalse: [
            s nextPutAll: ns keys size printString; nextPutAll: ' keys'; nextPutAll: nl]].

s nextPutAll: '=== I. Application MAS subclass counts ==='; nextPutAll: nl.
[
    | appM dialogM |
    appM := Smalltalk at: #ApplicationModel ifAbsent: [
        UI at: #ApplicationModel ifAbsent: [nil]].
    dialogM := Smalltalk at: #SimpleDialog ifAbsent: [
        UI at: #SimpleDialog ifAbsent: [nil]].
    appM isNil ifFalse: [
        s nextPutAll: '  ApplicationModel allSubclasses size: '; 
          nextPutAll: appM allSubclasses size printString; nextPutAll: nl].
    dialogM isNil ifFalse: [
        s nextPutAll: '  SimpleDialog allSubclasses size: ';
          nextPutAll: dialogM allSubclasses size printString; nextPutAll: nl]]
    on: Core.Exception do: [:ex | 
        s nextPutAll: '  ERR computing subclass counts: '; 
          nextPutAll: ex description; nextPutAll: nl].

s contents
