"=== VWBridge-Patches v0.9.2 Phase P P2 ==="
"SimpleDialog override extracted from VWBridge.st during Phase P P2 (Stage 1
 source-split). Assigned to the VWBridge-Patches package via the *PackageName
 category prefix on the methodsFor: chunk so it can be loaded and unloaded
 independently of VWBridge-Core.

 Method body and behavior are unchanged from the original v0.8.12 fix.
 The only difference is the chunk-header category went from 'mas-bug2-fix'
 to '*VWBridge-Patches mas-bug2-fix' to retag the method into the new package.

 See knowledge/vw-bridge-known-issues.md Bug #2 for the full investigation."

"v0.8.12 Bug #2 Symptom A fix - SimpleDialog override (see method comment + knowledge/vw-bridge-known-issues.md Bug #2)"
Transcript cr; show: '[v0.9.2/Patches] Installing SimpleDialog>>choose:labels:values:default:for: override (Bug #2 Symptom A fix)'; cr!

!SimpleDialog methodsFor: '*VWBridge-Patches mas-bug2-fix'!

choose: aLabel labels: labels values: values default: defaultValue for: aWindow
	"v0.8.12 Bug #2 Symptom A fix: synthesize boolean return from accept/cancel
	 ValueHolders when the framework's force-close yields nil. Conservative -
	 only fires for confirm-shaped values (Array with: true with: false).
	 All other nil results pass through unchanged.

	 WHY: closeAndUnschedule + purgeDeadWindows (v0.8.11) wakes the wedged
	 modal loop cleanly, but the framework hardcodes a nil return on
	 force-close exit regardless of accept/cancel state. Pre-probe (session-7)
	 confirmed both ValueHolders retain their bridge-set value through the
	 unwind. See knowledge/vw-bridge-known-issues.md Bug #2 for the full
	 investigation.

	 equalize: false matches the conventional default. The original frame 22
	 method is a 1-message delegator; the equalize: argument is a bytecode
	 pushSpecial (true/false/nil) and could not be decoded with stripped
	 sources. If wrong, cosmetic button-width difference only."
	| result confirmShaped |
	result := self
		choose: aLabel
		labels: labels
		values: values
		default: defaultValue
		equalize: false
		for: aWindow.
	confirmShaped := (values size = 2)
		and: [(values at: 1) == true
			and: [(values at: 2) == false]].
	(result == nil and: [confirmShaped]) ifTrue: [
		self accept value ifTrue: [^true].
		self cancel value ifTrue: [^false]].
	^result! !
