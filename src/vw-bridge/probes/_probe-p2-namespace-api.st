"Probe P2 namespace API lifecycle - confirms (a) defineNameSpace:private:imports:category: works, (b) defineClass: inside the new namespace works, (c) namespaced class lookup works, (d) removeFromSystem on the class works, (e) namespace itself can be removed. Critical because Oracle's Stage 2 design depends on all five working. Creates scratch VWBProbeNS namespace + ProbeClass, cleans up at end."
| s nl resultA resultB probeNS |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

"1. Selector availability on Root.Smalltalk class."
s nextPutAll: '-- defineNameSpace selector availability --'; nextPutAll: nl.
#(#defineNameSpace:private:imports:category: #defineNameSpace:imports:category: #defineNameSpace: #addNamespace:) do: [:sel |
    s nextPutAll: '  Root.Smalltalk class canUnderstand: '; nextPutAll: sel asString; nextPutAll: ' = '.
    s nextPutAll: (Root.Smalltalk class canUnderstand: sel) printString; nextPutAll: nl].

"2. Attempt creating scratch namespace VWBProbeNS."
s nextPutAll: nl; nextPutAll: '-- Create namespace VWBProbeNS --'; nextPutAll: nl.
resultA := [Root.Smalltalk 
    defineNameSpace: #VWBProbeNS 
    private: false 
    imports: '' 
    category: 'VWBridge-ProbeStaging'] on: Error do: [:ex | 'ERR ' , ex description].
s nextPutAll: '  defineNameSpace result class: '; nextPutAll: resultA class name; nextPutAll: nl.
s nextPutAll: '  Smalltalk at: VWBProbeNS = '; nextPutAll: (Smalltalk at: #VWBProbeNS ifAbsent: ['<MISSING>']) printString; nextPutAll: nl.
probeNS := Smalltalk at: #VWBProbeNS ifAbsent: [nil].
probeNS notNil ifTrue: [
    s nextPutAll: '  VWBProbeNS class: '; nextPutAll: probeNS class name; nextPutAll: nl].

"3. Define a scratch class INSIDE VWBProbeNS."
s nextPutAll: nl; nextPutAll: '-- Define VWBProbeNS.ProbeClass --'; nextPutAll: nl.
probeNS notNil ifTrue: [
    resultB := [probeNS 
        defineClass: #ProbeClass 
        superclass: #{Core.Object} 
        indexedType: #none 
        private: false 
        instanceVariableNames: '' 
        classInstanceVariableNames: '' 
        imports: '' 
        category: 'VWBridge-ProbeStaging'] on: Error do: [:ex | 'ERR ' , ex description].
    s nextPutAll: '  defineClass result class: '; nextPutAll: resultB class name; nextPutAll: nl.
    "Try multiple lookup paths."
    [s nextPutAll: '  probeNS at: ProbeClass = '; nextPutAll: (probeNS at: #ProbeClass ifAbsent: ['<MISSING>']) printString; nextPutAll: nl]
        on: Error do: [:e | s nextPutAll: '  probeNS lookup ERR'; nextPutAll: nl]].

"4. Instantiate + verify behavior."
s nextPutAll: nl; nextPutAll: '-- Instantiate ProbeClass --'; nextPutAll: nl.
[| inst |
 inst := (probeNS at: #ProbeClass) new.
 s nextPutAll: '  inst class: '; nextPutAll: inst class name; nextPutAll: nl.
 s nextPutAll: '  inst class environment: '; nextPutAll: inst class environment name; nextPutAll: nl]
    on: Error do: [:e | s nextPutAll: '  instantiate ERR '; nextPutAll: e messageText; nextPutAll: nl].

"5. Cleanup: remove ProbeClass via removeFromSystem."
s nextPutAll: nl; nextPutAll: '-- Cleanup: ProbeClass removeFromSystem --'; nextPutAll: nl.
[| cls |
 cls := probeNS at: #ProbeClass ifAbsent: [nil].
 cls notNil
    ifTrue: [
        cls removeFromSystem.
        s nextPutAll: '  removeFromSystem OK'; nextPutAll: nl.
        s nextPutAll: '  post-removal lookup: '; nextPutAll: (probeNS at: #ProbeClass ifAbsent: ['<GONE>']) printString; nextPutAll: nl]
    ifFalse: [s nextPutAll: '  ProbeClass already absent'; nextPutAll: nl]]
    on: Error do: [:e | s nextPutAll: '  ERR '; nextPutAll: e messageText; nextPutAll: nl].

"6. Cleanup: remove the empty namespace."
s nextPutAll: nl; nextPutAll: '-- Cleanup: VWBProbeNS namespace removal --'; nextPutAll: nl.
"Try removeFromSystem first."
[probeNS removeFromSystem.
 s nextPutAll: '  probeNS removeFromSystem OK'; nextPutAll: nl]
    on: Error do: [:e | 
        s nextPutAll: '  removeFromSystem ERR '; nextPutAll: e messageText; nextPutAll: nl.
        "Fallback to Smalltalk removeKey:"
        [Smalltalk removeKey: #VWBProbeNS.
         s nextPutAll: '  Smalltalk removeKey: VWBProbeNS OK'; nextPutAll: nl]
            on: Error do: [:e2 | s nextPutAll: '  removeKey ERR '; nextPutAll: e2 messageText; nextPutAll: nl]].
s nextPutAll: '  final Smalltalk at: VWBProbeNS = '; nextPutAll: (Smalltalk at: #VWBProbeNS ifAbsent: ['<GONE>']) printString; nextPutAll: nl.

s contents