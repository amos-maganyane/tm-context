"=== VW Widget Bridge Phase B v0.8 -- adds /menu /menu/click endpoints ==="
"PREREQ:  VWBridge.st (v0.5) AND VWBridge-phaseA.st (v0.7) must already
          be filed in. File in this file LAST. It restarts the bridge.

 NEW ENDPOINTS (all require Authorization: Bearer <token> except /health):
   GET  /menu?windowTitle=X
                  Dump the full menu tree of the matched window as JSON:
                  {""ok"":true, ""menus"":[
                    {""index"":1, ""label"":""Party & Contract"", ""items"":[
                      {""index"":1, ""label"":""Client & Contract"",
                       ""value"":""openClientAndContract"",
                       ""hasSubmenu"":false, ""items"":[]}, ...]}, ...]}
   POST /menu/click
                  body: {""path"":[""Party & Contract"",""Client & Contract""],
                         ""windowTitle"":""MOMENTUM""}
                  Walks menuButtons by label, then menuHolder.items by
                  label, and dispatches  performer perform: leafItem value
                  when the leaf carries a Symbol value. Top-level items
                  (which only open submenus, value=nil) are rejected with
                  path_too_short.

 DESIGN NOTES (from mas_menu_visual_v5 probe):
   - menuBar.menuButtons gives DIRECT access to top-level
     MenuBarButtonViews (avoids unreliable BoundedWrapper drill-in).
   - menuBar.performer is the receiver for perform: dispatch (typically
     the application model, e.g. MasLauncher).
   - menuBar.menuChannel and masApp.mainMenu were observed to lose their
     items between probe runs in MAS; per-button .menuHolder is more
     stable but we still degrade gracefully if items returns nil.
   - extractLabelText: handles LabelWithAccessor (top-level buttons) AND
     plain String (sub-MenuItems) via a fallback chain.
   - Click strategy is  performer perform: selector  - simpler and more
     deterministic than menuActivation visual simulation, and does not
     pop a menu on the user's screen.
   - JSON parser extended: parseAnyValue: now recognizes [, plus a new
     parseArray:cursor: - needed because /menu/click body has a path
     array of strings.
   - dispatch:headers:body: is replaced to register the new routes and
     bump /health version to 0.8.
   - All namespace refs qualified (Root.Smalltalk, Core.*) per the GBS
     image gotcha."!

!VWBridge methodsFor: 'menu helpers'!

extractLabelText: anObject
	"Extract label text from a String or wrapper (LabelWithAccessor etc).
	 IMPORTANT: LabelWithAccessor inherits Object>>displayString which
	 returns printString - so displayString/text/string give us the
	 wrapper's full description, NOT the wrapped label. Diagnostic
	 confirmed: lbl displayString returns 'LabelWithAccessor for
	 ''Party & Contract''' (the printString) - a String that passes
	 isString but is the wrong value.
	 Strategy: parse the printString FIRST (works for the standard
	 '... for ''X''' / '... ''X''' wrapper printString conventions),
	 fall back to accessor chain only if no quoted segment is found
	 (covers Symbols and plain wrappers)."
	| err txt qch p1 p2 |
	err := self errorClass.
	anObject == nil ifTrue: [^''].
	anObject isString ifTrue: [^anObject].
	"PRIMARY: parse the printString for the first ''X'' quoted segment."
	txt := [anObject printString] on: err do: [:ex | ''].
	qch := Core.Character value: 39.
	p1 := txt indexOf: qch.
	p1 > 0 ifTrue: [
		p2 := txt indexOf: qch startingAt: p1 + 1.
		p2 > p1 ifTrue: [^txt copyFrom: p1 + 1 to: p2 - 1]].
	"FALLBACK: only if printString had no quoted segment.
	 result ~= txt guards against returning the same garbage."
	#(displayString text string) do: [:sel |
		(anObject respondsTo: sel) ifTrue: [
			| result |
			result := [anObject perform: sel] on: err do: [:ex | nil].
			(result ~~ nil and: [result isString and: [result ~= txt]])
				ifTrue: [^result]]].
	^txt!

menuItemsOf: aMenu
	"Return the items of a Menu, or nil if not enumerable.
	 VW Menu does NOT respond to #items (diagnostic-confirmed) - the
	 correct selector is #menuItems. Tries menuItems/items/components
	 in order so the helper survives future API drift."
	| err result |
	err := self errorClass.
	aMenu == nil ifTrue: [^nil].
	#(menuItems items components) do: [:sel |
		(aMenu respondsTo: sel) ifTrue: [
			result := [aMenu perform: sel] on: err do: [:ex | nil].
			result ~~ nil ifTrue: [^result]]].
	^nil!

submenuOf: aMenuItem
	"Return the submenu Menu of a MenuItem, or nil if none.
	 Tries submenu/subMenu/menu in order - submenu is the standard VW
	 accessor but kept tolerant for variant Menu item classes."
	| err result |
	err := self errorClass.
	aMenuItem == nil ifTrue: [^nil].
	#(submenu subMenu menu) do: [:sel |
		(aMenuItem respondsTo: sel) ifTrue: [
			result := [aMenuItem perform: sel] on: err do: [:ex | nil].
			result ~~ nil ifTrue: [^result]]].
	^nil!

get: aSelector or: ivarName from: anObject
	"Try the public accessor first; fall back to instVarNamed: if absent or
	 if the accessor returns nil. Defensive against VW class evolution."
	| err result |
	err := self errorClass.
	anObject == nil ifTrue: [^nil].
	(anObject respondsTo: aSelector) ifTrue: [
		result := [anObject perform: aSelector] on: err do: [:ex | nil].
		result ~~ nil ifTrue: [^result]].
	ivarName == nil ifTrue: [^nil].
	^[anObject instVarNamed: ivarName] on: err do: [:ex | nil]!

findMenuBarInWindowMatching: titleSubstring
	"Walk ScheduledControllers; return the menuBar of the first window
	 whose label contains titleSubstring. nil substring matches the first
	 window that has a menuBar. Must run on UI process."
	| mgr err matched |
	err := self errorClass.
	mgr := self globalNamed: #ScheduledControllers.
	mgr == nil ifTrue: [^nil].
	matched := nil.
	([mgr scheduledControllers] on: err do: [:ex | #()]) do: [:ctrl |
		| view title titleOK mb |
		matched == nil ifTrue: [
			view := [ctrl view] on: err do: [:ex | nil].
			view ~~ nil ifTrue: [
				title := [view label asString] on: err do: [:ex | ''].
				titleOK := titleSubstring == nil
					or: [(title indexOfSubCollection: titleSubstring startingAt: 1) > 0].
				titleOK ifTrue: [
					mb := (view respondsTo: #menuBar)
						ifTrue: [[view menuBar] on: err do: [:ex | nil]]
						ifFalse: [nil].
					mb ~~ nil ifTrue: [matched := mb]]]]].
	^matched! !

!VWBridge methodsFor: 'menu trees'!

menuTreeForMenuBar: aMenuBar
	"Build an OrderedCollection of Dictionaries describing each top-level
	 menu and its items recursively.
	 Primary source: menuBar.menuChannel.menuItems - the abstract Menu held by
	 the menuBar, whose entries are MenuItem objects with proper String
	 labels (and populated submenus when available).
	 Fallback: per-button menuHolder (used only if menuChannel is empty).
	 Uses self menuItemsOf: / self submenuOf: helpers (VW Menu does not
	 respond to #items - the right selector is #menuItems)."
	| err buttons channel channelItems result |
	err := self errorClass.
	result := Core.OrderedCollection new.
	channel := self get: #menuChannel or: 'menuChannel' from: aMenuBar.
	channelItems := self menuItemsOf: channel.
	(channelItems ~~ nil and: [channelItems isEmpty not]) ifTrue: [
		channelItems doWithIndex: [:item :i |
			| d label submenu subItems itemsCol |
			d := Core.Dictionary new.
			label := self extractLabelText: ([item label] on: err do: [:ex | nil]).
			submenu := self submenuOf: item.
			subItems := self menuItemsOf: submenu.
			itemsCol := Core.OrderedCollection new.
			subItems ~~ nil ifTrue: [
				subItems doWithIndex: [:sub :j |
					itemsCol add: (self menuItemTreeForItem: sub index: j depth: 1)]].
			d at: 'index' put: i.
			d at: 'label' put: label.
			d at: 'items' put: itemsCol.
			d at: 'source' put: 'menuChannel'.
			result add: d].
		^result].
	"Fallback path."
	buttons := self get: #menuButtons or: 'menuButtons' from: aMenuBar.
	buttons == nil ifTrue: [^result].
	buttons doWithIndex: [:btn :i |
		| d label menuHolder items itemsCol |
		d := Core.Dictionary new.
		label := self extractLabelText: ([btn label] on: err do: [:ex | nil]).
		menuHolder := self get: #menuHolder or: nil from: btn.
		items := self menuItemsOf: menuHolder.
		itemsCol := Core.OrderedCollection new.
		items ~~ nil ifTrue: [
			items doWithIndex: [:item :j |
				itemsCol add: (self menuItemTreeForItem: item index: j depth: 1)]].
		d at: 'index' put: i.
		d at: 'label' put: label.
		d at: 'items' put: itemsCol.
		d at: 'source' put: 'menuHolder'.
		result add: d].
	^result!

menuItemTreeForItem: anItem index: anIndex depth: aDepth
	"Build a Dictionary describing one MenuItem - label + value (the
	 perform: selector, nil for separators / submenu-openers) + recursively
	 the items of its submenu (if any). Depth-capped at 8.
	 Uses self submenuOf: / self menuItemsOf: helpers since VW Menu does
	 not respond to #items."
	| err d label value submenu items itemsCol |
	err := self errorClass.
	d := Core.Dictionary new.
	label := self extractLabelText: ([anItem label] on: err do: [:ex | nil]).
	value := [anItem value] on: err do: [:ex | nil].
	submenu := self submenuOf: anItem.
	items := self menuItemsOf: submenu.
	itemsCol := Core.OrderedCollection new.
	(items ~~ nil and: [aDepth < 8]) ifTrue: [
		items doWithIndex: [:sub :j |
			itemsCol add: (self menuItemTreeForItem: sub index: j depth: aDepth + 1)]].
	d at: 'index' put: anIndex.
	d at: 'label' put: label.
	d at: 'value' put: (value == nil ifTrue: [nil] ifFalse: [value asString]).
	d at: 'hasSubmenu' put: submenu ~~ nil.
	d at: 'items' put: itemsCol.
	^d! !

!VWBridge methodsFor: 'menu dispatching'!

handleMenuQuery: queryString
	"GET /menu?windowTitle=X (windowTitle optional)."
	| winTitle outcome |
	winTitle := self queryParam: 'windowTitle' from: queryString.
	outcome := self onUIDo: [self doMenuList: winTitle].
	outcome == nil ifTrue: [outcome := '{"error":"ui_timeout"}'].
	^(outcome beginsWith: '{"ok":')
		ifTrue: [self httpResponse: 200 type: 'application/json' body: outcome]
		ifFalse: [self httpResponse: 400 type: 'application/json' body: outcome]!

doMenuList: winTitle
	"Runs on UI process. Returns a JSON string."
	| menuBar tree response err |
	err := self errorClass.
	menuBar := self findMenuBarInWindowMatching: winTitle.
	menuBar == nil ifTrue: [^'{"error":"window_or_menubar_not_found"}'].
	tree := [self menuTreeForMenuBar: menuBar] on: err do: [:ex |
		^'{"error":"menu_walk_failed","message":"' , ex description , '"}'].
	response := Core.Dictionary new.
	response at: 'ok' put: true.
	response at: 'menus' put: tree.
	^self jsonFor: response!

handleMenuClickBody: bodyString
	"POST /menu/click  body: {""path"":[...,""leaf""],""windowTitle"":""X""}"
	| dict pathArray winTitle outcome |
	dict := self jsonParseFlat: bodyString.
	dict == nil ifTrue: [
		^self httpResponse: 400 type: 'application/json' body: '{"error":"invalid_json"}'].
	pathArray := dict at: 'path' ifAbsent: [nil].
	(pathArray == nil
		or: [(pathArray isKindOf: Core.Collection) not
			or: [pathArray isEmpty]]) ifTrue: [
		^self httpResponse: 400 type: 'application/json'
			body: '{"error":"missing_or_empty_path"}'].
	pathArray size < 2 ifTrue: [
		^self httpResponse: 400 type: 'application/json'
			body: '{"error":"path_too_short","message":"top-level menu items just open submenus; need leaf with value"}'].
	winTitle := dict at: 'windowTitle' ifAbsent: [dict at: 'window' ifAbsent: [nil]].
	outcome := self onUIDo: [self doMenuClickPath: pathArray inWindow: winTitle].
	outcome == nil ifTrue: [outcome := '{"error":"ui_timeout"}'].
	^(outcome beginsWith: '{"ok":')
		ifTrue: [self httpResponse: 200 type: 'application/json' body: outcome]
		ifFalse: [self httpResponse: 400 type: 'application/json' body: outcome]!

doMenuClickPath: pathArray inWindow: winTitle
	"Runs on UI process. Returns a JSON string.
	 Dispatches based on the leaf MenuItem's value type:
	   - Symbol         : performer perform: symbol  (classic MVC menu action)
	   - BlockClosure   : leafValue value             (MAS menus mostly use this -
	                      block closures built by Menu>>addItemLabel:withOperation:
	                      that capture the action via lexical scope)
	   - anything else  : reject with unsupported_leaf_value"
	| menuBar walked leafItem performer leafValue err result response dispatch blockCls |
	err := self errorClass.
	menuBar := self findMenuBarInWindowMatching: winTitle.
	menuBar == nil ifTrue: [^'{"error":"window_or_menubar_not_found"}'].
	walked := self walkMenuPath: pathArray inMenuBar: menuBar.
	(walked at: 3) ~~ nil ifTrue: [^walked at: 3].
	leafItem := walked at: 1.
	performer := walked at: 2.
	leafValue := [leafItem value] on: err do: [:ex | nil].
	leafValue == nil ifTrue: [
		^'{"error":"leaf_has_no_value","path_label":' , (self jsonFor: pathArray last) , '}'].
	dispatch := nil.
	leafValue isSymbol ifTrue: [dispatch := 'perform'].
	dispatch == nil ifTrue: [
		blockCls := self globalNamed: #BlockClosure.
		(blockCls ~~ nil and: [leafValue isKindOf: blockCls])
			ifTrue: [dispatch := 'block']].
	dispatch == nil ifTrue: [
		^'{"error":"unsupported_leaf_value","class":"' , leafValue class name asString ,
			'","value":' , (self jsonFor: leafValue printString) , '}'].
	result := dispatch = 'perform'
		ifTrue: [
			[performer perform: leafValue. nil] on: err do: [:ex |
				'{"error":"perform_failed","selector":' , (self jsonFor: leafValue asString) ,
					',"message":' , (self jsonFor: ex description) , '}']]
		ifFalse: [
			[leafValue value. nil] on: err do: [:ex |
				'{"error":"block_eval_failed","message":' , (self jsonFor: ex description) , '}']].
	result ~~ nil ifTrue: [^result].
	response := Core.Dictionary new.
	response at: 'ok' put: true.
	response at: 'path' put: pathArray asArray.
	response at: 'dispatch' put: dispatch.
	response at: 'leafValue' put: leafValue printString.
	response at: 'performer' put: performer class name asString.
	^self jsonFor: response!

walkMenuPath: pathArray inMenuBar: aMenuBar
	"Walk pathArray (Collection of Strings) through menuBar.menuChannel.menuItems
	 recursively. Each segment matches an item by label (against
	 extractLabelText:), then descends via self submenuOf: -> menuItemsOf:.
	 Returns Core.Array {leafItem, performer, errorJSON}. Exactly one of
	 {leafItem+performer, errorJSON} is non-nil.
	 Uses self menuItemsOf: / self submenuOf: helpers since VW Menu does
	 not respond to #items."
	| err performer channel currentMenu currentItem i seg items |
	err := self errorClass.
	performer := self get: #performer or: 'performer' from: aMenuBar.
	performer == nil ifTrue: [
		^Core.Array with: nil with: nil with: '{"error":"no_performer"}'].
	channel := self get: #menuChannel or: 'menuChannel' from: aMenuBar.
	channel == nil ifTrue: [
		^Core.Array with: nil with: nil with: '{"error":"no_menu_channel"}'].
	currentMenu := channel.
	currentItem := nil.
	i := 1.
	[i <= pathArray size] whileTrue: [
		currentMenu == nil ifTrue: [
			^Core.Array with: nil with: nil with:
				('{"error":"no_submenu","at_segment":' , (i - 1) printString , '}')].
		seg := pathArray at: i.
		currentItem := nil.
		items := self menuItemsOf: currentMenu.
		items ~~ nil ifTrue: [
			items do: [:item |
				| label |
				currentItem == nil ifTrue: [
					label := self extractLabelText: ([item label] on: err do: [:ex | nil]).
					label = seg ifTrue: [currentItem := item]]]].
		currentItem == nil ifTrue: [
			^Core.Array with: nil with: nil with:
				('{"error":"item_not_found","seg":' , (self jsonFor: seg) , ',"at_segment":' , i printString , '}')].
		i < pathArray size ifTrue: [currentMenu := self submenuOf: currentItem].
		i := i + 1].
	^Core.Array with: currentItem with: performer with: nil! !

!VWBridge methodsFor: 'json parsing'!

parseArray: aString cursor: cursor
	"At opening [. Returns OrderedCollection of values, or nil on error.
	 Supports nested arrays + all scalar value types via parseAnyValue:."
	| arr c |
	(self peek: aString cursor: cursor) = $[ ifFalse: [^nil].
	self advance: cursor.
	arr := Core.OrderedCollection new.
	self skipWs: aString cursor: cursor.
	c := self peek: aString cursor: cursor.
	[c ~~ nil and: [c ~= $]]] whileTrue: [
		| val |
		val := self parseAnyValue: aString cursor: cursor.
		arr add: val.
		self skipWs: aString cursor: cursor.
		(self peek: aString cursor: cursor) = $, ifTrue: [self advance: cursor].
		self skipWs: aString cursor: cursor.
		c := self peek: aString cursor: cursor].
	c == nil ifTrue: [^nil].
	self advance: cursor.
	^arr!

parseAnyValue: aString cursor: cursor
	"REPLACES v0.7. Adds $[ case for arrays (needed by /menu/click body).
	 Other behaviour unchanged - string / boolean / null / number / nested
	 object via the existing parseQuotedString:/matchKeyword: chain."
	| c start end |
	c := self peek: aString cursor: cursor.
	c == nil ifTrue: [^nil].
	c = $" ifTrue: [^self parseQuotedString: aString cursor: cursor].
	c = $[ ifTrue: [^self parseArray: aString cursor: cursor].
	c = $t ifTrue: [^self matchKeyword: 'true' as: true in: aString cursor: cursor].
	c = $f ifTrue: [^self matchKeyword: 'false' as: false in: aString cursor: cursor].
	c = $n ifTrue: [^self matchKeyword: 'null' as: nil in: aString cursor: cursor].
	start := cursor at: 1.
	[c := self peek: aString cursor: cursor.
	 c ~~ nil
		and: [(c between: $0 and: $9)
			or: [c = $- or: [c = $+ or: [c = $. or: [c = $e or: [c = $E]]]]]]]
		whileTrue: [self advance: cursor].
	end := (cursor at: 1) - 1.
	end < start ifTrue: [^nil].
	^[(aString copyFrom: start to: end) asNumber] on: self errorClass do: [:ex | nil]! !

!VWBridge methodsFor: 'dispatching'!

dispatch: requestLine headers: headers body: bodyString
	"REPLACES v0.7. Adds GET /menu and POST /menu/click; bumps /health
	 version to 0.8. All other v0.7 routes preserved."
	| parts method path queryString authResp |
	authResp := self authError: requestLine headers: headers.
	authResp ~~ nil ifTrue: [^authResp].
	parts := self split: requestLine on: (Core.Character value: 32).
	parts size < 2 ifTrue: [
		^self httpResponse: 400 type: 'application/json' body: '{"error":"bad_request"}'].
	method := parts at: 1.
	path := parts at: 2.
	queryString := ''.
	(path includes: $?) ifTrue: [
		| qi |
		qi := path indexOf: $?.
		queryString := path copyFrom: qi + 1 to: path size.
		path := path copyFrom: 1 to: qi - 1].
	method = 'GET' ifTrue: [
		path = '/health' ifTrue: [
			^self httpResponse: 200 type: 'application/json'
				body: '{"status":"ok","version":"0.8"}'].
		path = '/windows' ifTrue: [^self handleWindows].
		path = '/windows/tree' ifTrue: [^self handleTree].
		path = '/value' ifTrue: [^self handleGetValueQuery: queryString].
		path = '/menu' ifTrue: [^self handleMenuQuery: queryString].
		^self httpResponse: 404 type: 'application/json'
			body: '{"error":"not_found","path":"' , path , '"}'].
	method = 'POST' ifTrue: [
		path = '/click' ifTrue: [^self handleClickBody: bodyString].
		path = '/type'  ifTrue: [^self handleTypeBody: bodyString].
		path = '/menu/click' ifTrue: [^self handleMenuClickBody: bodyString].
		^self httpResponse: 404 type: 'application/json'
			body: '{"error":"not_found","path":"' , path , '"}'].
	method = 'PUT' ifTrue: [
		path = '/value' ifTrue: [^self handlePutValueQuery: queryString body: bodyString].
		^self httpResponse: 404 type: 'application/json'
			body: '{"error":"not_found","path":"' , path , '"}'].
	method = 'OPTIONS' ifTrue: [
		^self httpResponse: 200 type: 'text/plain' body: ''].
	^self httpResponse: 405 type: 'application/json'
		body: '{"error":"method_not_allowed","method":"' , method , '"}'! !

"=== Restart the bridge to pick up Phase B dispatcher + endpoints ==="
VWBridge stop.
VWBridge start!
