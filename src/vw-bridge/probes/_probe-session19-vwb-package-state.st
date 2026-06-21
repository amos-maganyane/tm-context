"Probe session-19 step 3: discover what package(s) own the VWB classes + SimpleDialog override.
Non-destructive class-category + method-category enumeration."
| s nl dialogCls overrideCat allVwbCats |
s := WriteStream on: String new.
nl := String with: Core.Character lf.
allVwbCats := Set new.
#(#VWBridge #VWBridgeTest #VWBridgeWaitTest #VWBridgeScreenshotTest) do: [:sym | 
    | cls inst class |
    cls := VWB at: sym ifAbsent: [nil].
    cls isNil 
        ifTrue: [s nextPutAll: sym asString; nextPutAll: ' : ABSENT'; nextPutAll: nl]
        ifFalse: [
            s nextPutAll: 'VWB.'; nextPutAll: sym asString; nextPutAll: nl.
            s nextPutAll: '  class>>category='; nextPutAll: cls category printString; nextPutAll: nl.
            allVwbCats add: cls category.
            inst := OrderedCollection new.
            class := OrderedCollection new.
            cls selectors do: [:sel | 
                | cat |
                cat := cls organization categoryOfElement: sel.
                (cat notNil and: [(inst includes: cat) not]) ifTrue: [inst add: cat]].
            cls class selectors do: [:sel | 
                | cat |
                cat := cls class organization categoryOfElement: sel.
                (cat notNil and: [(class includes: cat) not]) ifTrue: [class add: cat]].
            s nextPutAll: '  inst-method-cats='; nextPutAll: inst asArray printString; nextPutAll: nl.
            s nextPutAll: '  class-method-cats='; nextPutAll: class asArray printString; nextPutAll: nl]].
s nextPutAll: '=== unique class>>category values ==='; nextPutAll: nl.
allVwbCats do: [:c | s nextPutAll: '  '; nextPutAll: c printString; nextPutAll: nl].
"SimpleDialog override - this is the critical Bug #2 fix extension"
s nextPutAll: '=== SimpleDialog>>choose:labels:values:default:for: extension ==='; nextPutAll: nl.
dialogCls := Smalltalk at: #SimpleDialog ifAbsent: [nil].
dialogCls isNil 
    ifTrue: [s nextPutAll: '  SimpleDialog class ABSENT'; nextPutAll: nl]
    ifFalse: [
        s nextPutAll: '  SimpleDialog class>>category='; nextPutAll: dialogCls category printString; nextPutAll: nl.
        (dialogCls includesSelector: #choose:labels:values:default:for:) 
            ifTrue: [
                overrideCat := dialogCls organization categoryOfElement: #choose:labels:values:default:for:.
                s nextPutAll: '  override-method-category='; nextPutAll: overrideCat printString; nextPutAll: nl]
            ifFalse: [s nextPutAll: '  override ABSENT'; nextPutAll: nl]].
s contents
