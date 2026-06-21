---
title: VW Native Development Idioms (image-empirical + librarian-validated)
purpose: Step 5-input deliverable for Phase M v2 design. Reference for VW UI / ApplicationModel / Parcel idioms that the MCP server must wrap as NATIVE TYPED tools (not "AI crafts eval string"). User feedback after v1 design: "expose more tools to allow native development on visualworks, this will make it also easier for AI than it have to guess... write and manage the UI code, the same way a developer would, but this tool is more powerful than any dev." This doc captures HOW VW dev works so the redesign can mirror it.
written: 2026-06-21 (session-21 Phase M v2 research)
inputs: 3 image probes (probes/_probe-s21-vw-ui-classes.st, _probe-s21-namespace-contents.st, _probe-s21-inherited-and-example.st) + wave-2 librarians (bg_aa6ea2ef UI Painter+windowSpec, bg_356abb3f ApplicationModel+aspects, bg_3fe35753 Pundle+Parcel+Store) — re-fired after model-availability failures on first attempt
status: PARTIAL — empirical sections complete; librarian-validation sections TBD pending wave-2 completion
---

# VW Native Development Idioms — Image-Empirical + Librarian-Validated

## Why this doc exists

After the v1 Phase M design (5 research docs + architecture.md) landed, the user surfaced a critical gap:

> "Jasper exposes native tools to allow AI to write code on gemstone like a gemstone developer. For us now we have eval, but shouldn't we expose more tools to allow native development on visualworks, this will make it also easier for AI than it have to guess. We would need to maybe study docs of visualworks, we need to be able to write and manage the UI code, the same way a developer would, but this tool is more powerful than any dev."

The v1 design was too eval-centric. Jasper's 33 tools are mostly NATIVE-TYPED (`compile_method({className, isMeta, category, source})` — AI passes structured params, not raw Smalltalk). For VW specifically, the rich UI-dev primitives (canvasSpec / windowSpec / ApplicationModel / aspects / ValueHolder / Pundles) deserve first-class tools that abstract over the spec literal syntax.

This doc captures HOW VW developers build UI apps so the v2 design (`architecture.md` rewrite) can mirror it with native tool surfaces.

## Methodology

Three image probes (image-empirical — what's actually loaded in `storedev64.im`) + three wave-2 librarian research agents (external — what real-world VW codebases + Cincom docs say is canonical):

| Source | Captures | When |
|---|---|---|
| Probe-1 (`_probe-s21-vw-ui-classes.st`) | Class presence + selector counts for ApplicationModel/Spec/Widget/ValueHolder/Painter/Parcel families | session-21 |
| Probe-2 (`_probe-s21-namespace-contents.st`) | UI/Tools/Store namespace key lists + WindowSpec/FullSpec/ActionButtonSpec setter inventories | session-21 |
| Probe-3 (`_probe-s21-inherited-and-example.st`) | Inheritance chain setters (Spec→Widget→Named→Component→UISpec) + ApplicationModel instance hooks + canonical MAS windowSpec literal | session-21 |
| Librarian bg_aa6ea2ef (UI Painter + windowSpec) | Public VW codebase patterns + AppDevGuide/ToolGuide canon | session-21 (wave-2 re-fired) |
| Librarian bg_356abb3f (ApplicationModel + aspects) | Public ApplicationModel idioms + ValueHolder usage patterns | session-21 (wave-2 re-fired) |
| Librarian bg_3fe35753 (Pundle + Parcel + Store) | Programmatic parcel/store APIs + StoreCI patterns | session-21 (wave-2 re-fired) |

Image probes are **ground truth** for "what's available in OUR image". Librarian research adds **canonical idioms** from external sources. Where they disagree, the image probe wins.

---

## 1. The canonical VW UI app shape

A working VW UI app has FOUR pieces of source, in conventional locations:

| Piece | Where | What |
|---|---|---|
| 1. Class definition | `<MyApp> subclass: 'MyApp' instanceVariableNames: 'searchString results' classVariableNames: '' poolDictionaries: '' inDictionary: 'MyAppPackage'` | Defines the ApplicationModel subclass + its aspect instance variables |
| 2. `#initialize` | Instance-side method | Creates ValueHolders for each aspect: `searchString := '' asValue` |
| 3. Aspect accessors | One per aspect, instance-side | Lazy-initialized accessor: `searchString ^searchString isNil ifTrue: [searchString := '' asValue] ifFalse: [searchString]` |
| 4. Class-side `windowSpec` | Class-side method named `windowSpec` (convention; canonical) | Returns a nested literal array describing the window tree |
| 5. Action methods | Instance-side, one per `model: #foo` reference in the spec | Invoked when the user clicks: `accept ^results := self search: searchString value` |
| 6. Call site | Anywhere | `MyApp new openInterface: #windowSpec` (or just `MyApp open` if `windowSpec` is the default) |

That's everything. Five pieces of structured source for a working app.

## 2. The spec literal array format (canonical, from probe-3)

The single most important empirical discovery from the probes: **the canonical class-side `windowSpec` method is a one-liner: `^<literal-array-spec>`**. Sample from `Tools.AboutVisualWorksDialog` (verified probe-3, `numArgs=0, numTemps=0, messages=0, literals=[<the-spec>]`):

```smalltalk
windowSpec
    ^#(#{UI.FullSpec}
        #window: #(#{UI.WindowSpec}
            #properties: #(#{UI.PropertyListDictionary}
                #sizeType #specifiedSize
                #positionType #screenCenter
                #openType #advanced)
            #label: #(#{Kernel.UserMessage}
                #key: #aboutVisualWorks
                #defaultString: 'About VisualWorks'
                #catalogID: #labels)
            #min: #(#{Core.Point} 20 20)
            #max: #(#{Core.Point} 1024 768)
            #bounds: #(#{Graphics.Rectangle} 812 503 1292 823))
        #component: #(#{UI.SpecCollection}
            #collection: #(
                #(#{UI.TabControlSpec}
                    #layout: #(#{Graphics.LayoutFrame} 10 0 10 0 -10 1 -40 1)
                    #name: #tabs
                    #model: #tabListHolder
                    #labels: #())
                #(#{UI.ActionButtonSpec}
                    #layout: #(#{Graphics.LayoutFrame} -90 1 -35 1 -10 1 -10 1)
                    #name: #ok
                    #model: #accept
                    #label: #(#{Kernel.UserMessage}
                        #key: #OK
                        #defaultString: 'OK'
                        #catalogID: #labels)
                    #isDefault: true
                    #defaultable: true)))).
```

### 2.1 Format rules (extracted empirically)

1. **Top-level wrapper**: `#(#{UI.FullSpec} #window: <windowSpec> #component: <componentTree>)`
2. **Each spec object**: starts with `#{Namespace.ClassName}` (fully-qualified ResolvedDeferredBinding) followed by alternating `#fieldName: fieldValue` pairs
3. **Nested specs**: same format recursively
4. **Component tree**: `#(#{UI.SpecCollection} #collection: #(<array of child specs>))`
5. **Layout**: `#(#{Graphics.LayoutFrame} <left> <leftFraction> <top> <topFraction> <right> <rightFraction> <bottom> <bottomFraction>)` — 8 numbers, signed offsets + 0..1 fractions. Negative right/bottom means "from right/bottom edge".
6. **i18n labels**: `#(#{Kernel.UserMessage} #key: #symbolKey #defaultString: 'fallback' #catalogID: #catalogSym)`
7. **Geometry**: `#(#{Core.Point} <x> <y>)` for points, `#(#{Graphics.Rectangle} <left> <top> <right> <bottom>)` for rects
8. **Dictionaries**: `#(#{UI.PropertyListDictionary} #key1 value1 #key2 value2 …)`
9. **Action binding**: `#model: #accept` — the symbol is the method to invoke on the app model when the spec's `value:` setter fires (button click, etc.)
10. **Aspect binding**: `#name: #searchString` — the symbol is the key in `namedComponents` Dictionary and (for widgets bound to ValueHolders) the aspect accessor on the app model
11. **Booleans + numbers**: literal `true`/`false`/`42`/`-10`
12. **Strings**: `'literal'` (single-quoted Smalltalk strings)
13. **Symbols**: `#symbolName` (typed)

### 2.2 Why this is the design unlock

Building a window from this literal-array format means the AI never needs to know:
- The `WindowSpec new bounds: ...; label: ...; etc.` chained-setter syntax
- The exact selector order or fluent-API conventions
- How `FullSpec` wraps `WindowSpec` + `SpecCollection`

The MCP tool's job is to take a structured JSON object and emit this literal-array form. AI thinks in JSON; tool generates the literal.

Example proposed MCP tool:
```json
{
  "tool": "vw_create_window_spec",
  "input": {
    "className": "MyApp",
    "namespace": "MyAppPackage",
    "window": {
      "label": "My Application",
      "bounds": [100, 100, 600, 400],
      "min": [200, 200],
      "max": [1024, 768],
      "sizeType": "specifiedSize",
      "positionType": "screenCenter",
      "openType": "advanced"
    },
    "components": [
      {
        "type": "ActionButton",
        "name": "okButton",
        "label": "OK",
        "model": "accept",
        "layout": {"l":-90, "lf":1, "t":-35, "tf":1, "r":-10, "rf":1, "b":-10, "bf":1},
        "isDefault": true,
        "defaultable": true
      },
      {
        "type": "InputField",
        "name": "searchInput",
        "model": "searchString",
        "layout": {"l":10, "lf":0, "t":10, "tf":0, "r":-10, "rf":1, "b":35, "bf":0},
        "numChars": 50
      }
    ]
  }
}
```

The MCP tool internally emits:
```smalltalk
MyAppPackage.MyApp class
    compile: 'windowSpec
^#(#{UI.FullSpec}
    #window: #(#{UI.WindowSpec}
        #label: ''My Application''
        #bounds: #(#{Graphics.Rectangle} 100 100 600 400)
        #min: #(#{Core.Point} 200 200)
        #max: #(#{Core.Point} 1024 768)
        #properties: #(#{UI.PropertyListDictionary}
            #sizeType #specifiedSize
            #positionType #screenCenter
            #openType #advanced))
    #component: #(#{UI.SpecCollection}
        #collection: #(
            #(#{UI.ActionButtonSpec} #name: #okButton #label: ''OK'' #model: #accept #layout: #(#{Graphics.LayoutFrame} -90 1 -35 1 -10 1 -10 1) #isDefault: true #defaultable: true)
            #(#{UI.InputFieldSpec} #name: #searchInput #model: #searchString #layout: #(#{Graphics.LayoutFrame} 10 0 10 0 -10 1 35 0) #numChars: 50))))'
    classified: 'interface specs'
```

AI never sees the literal syntax. AI thinks "I want a window with a button and an input field"; tool handles the translation.

## 3. Spec class hierarchy (empirical from probe-1 + probe-3)

Verified loaded in `storedev64.im`:

```
Object
  └ UISpecification (27 setters: label:, model:, layout:, name:, properties:, …)
       └ ComponentSpec (11 setters; 52 subclasses)
            └ NamedSpec (28 setters: name:, colors:, flags:, hasBorder:, hasMenuBar:, drag*, drop*, …)
                 ├ WidgetSpec (12 setters: model:, modelInBuilder:, helpText:, callbacksSpec:; 40 subclasses)
                 │    ├ ButtonSpec (8 setters: setLabel:, style:)
                 │    │    └ ActionButtonSpec (9 setters: changeActionTo:, isDefault:, defaultable:)
                 │    │    └ CheckBoxSpec
                 │    │    └ RadioButtonSpec
                 │    ├ TextEditorSpec (8 setters: alignment:, isReadOnly:, isWrapped:, numChars:)
                 │    │    └ InputFieldSpec (11 setters: type:, formatString:, converterWith:)
                 │    ├ ComboBoxSpec
                 │    ├ SequenceViewSpec (replaces ListSpec)
                 │    ├ TableViewSpec (replaces TableSpec)
                 │    ├ DataSetSpec (51 setters!)
                 │    ├ TreeViewSpec
                 │    └ SubCanvasSpec (subview)
                 ├ MenuComponentSpec (7 setters: menu:, performer:)
                 ├ LabelSpec (8 setters: setLabel:, style:, mnemonic:; NOT a widget — different branch)
                 ├ GroupBoxSpec
                 ├ TabControlSpec
                 ├ DividerSpec
                 ├ SliderSpec
                 ├ SpinButtonSpec
                 ├ ProgressWidgetSpec
                 ├ RegionSpec
                 └ ResizingSplitterSpec
```

Note **ABSENT** in this image (the v1 design referenced these by name — fix in v2):
- `UISpec` (no abstract base by this name — `UISpecification` is the abstract root)
- `PluggableActionButtonSpec` (`ActionButtonSpec` is the only button spec)
- `ActionLabelSpec` (`LabelSpec` only)
- `ListSpec` (renamed: `SequenceViewSpec` is the modern equivalent)
- `TableSpec` (renamed: `TableViewSpec`)
- `MenuBarSpec` (use `MenuComponentSpec` + windowSpec's `hasMenuBar: true` + `menu:` setters)

### 3.1 Total unique setter counts per widget kind (from probe-3 chain walks)

| Widget spec | Chain length | Unique setters across chain | Top 3 most-used in stock VW apps |
|---|---:|---:|---|
| ActionButtonSpec | 7 (ActionButtonSpec→ButtonSpec→WidgetSpec→NamedSpec→ComponentSpec→UISpecification→Object) | **70** | `name:`, `model:`, `label:`, `layout:`, `changeActionTo:`, `isDefault:`, `defaultable:` |
| InputFieldSpec | 7 (InputFieldSpec→TextEditorSpec→MenuComponentSpec→WidgetSpec→NamedSpec→ComponentSpec→UISpecification) | **78** | `name:`, `model:`, `label:`, `layout:`, `type:`, `numChars:`, `isReadOnly:` |
| LabelSpec | 4 (LabelSpec→NamedSpec→ComponentSpec→UISpecification — note: NOT WidgetSpec) | **59** | `name:`, `label:`, `layout:`, `colors:`, `mnemonic:` |

**Implication**: a single typed MCP tool surface that handles the union of these 70+ setters is doable. The "common 7-12 setters per widget" cover ~95% of real-world spec construction. Long-tail setters (drag/drop wiring, region-specific stuff) are V3.

## 4. ApplicationModel pattern (empirical from probe-1 + probe-3)

### 4.1 The class

- `Smalltalk.ApplicationModel` (top-level, NOT `UI.ApplicationModel`)
- 94 instance + 49 class selectors
- **1,908 subclasses in this MAS image** — heaviest-used pattern in the system
- 46 SimpleDialog subclasses (the dialog cousin)

### 4.2 Class-side opener selectors (from probe-2)

Only 4 class-side hooks matching "open*"/"window*"/"pre*"/"post*":
- `open` — open with the default `#windowSpec`
- `openOn:` — open passing a model
- `openOn:withSpec:` — open with explicit spec selector
- `openWithSpec:` — open with explicit spec selector + own model

Canonical call site: `MyApp new openInterface: #windowSpec` (the `openInterface:` actually lives on the INSTANCE side — probe-3 D shows it for SimpleDialog; ApplicationModel inherits it).

### 4.3 Instance-side lifecycle hooks (from probe-3 B — 13 hook-shaped selectors)

| Selector | When called | Override to |
|---|---|---|
| `preBuildWith:` | Before spec is parsed by the builder | Initialize aspects that the spec will reference |
| `postBuildWith:` | After spec parsed + widgets instantiated, before window opens | Set up widget cross-wiring, post-build state |
| `postOpenWith:` | After window appears on screen | Trigger initial data load, focus a widget |
| `closeRequest` | User clicks X / hits Escape | Return `true` to allow close, `false` to veto |
| `closeAndUnschedule` | Internal close + scheduler cleanup | Rarely overridden |
| `windowEvent:from:` | Window receives any window event | Custom event handling |
| `windowMenuBar` | Builder asks for the menu bar | Return a `Menu` instance (or use spec's `menu:`) |
| `builder` / `builder:` | Get/set the UIBuilder | Rarely overridden — framework wires it |
| `builderClass` | Customize the UIBuilder class | Return a subclass for specialized builders |
| `aspectFor:` | Resolve an aspect symbol | Override for dynamic aspect resolution |
| `aspectPathClass` | Class metadata for aspect paths | Rarely overridden |
| `closeSelectedTab` | Tab-aware close (TabbedUIBuilder) | Tab-pane apps only |

**Implication**: a `vw_create_application_model` tool should generate the class definition + `#initialize` (creates ValueHolders for aspects) + one or more of `postBuildWith:` / `postOpenWith:` if the user requests initial data load behavior.

### 4.4 SimpleDialog: the dialog cousin (probe-3 D)

`Smalltalk.SimpleDialog` (46 subclasses) extends ApplicationModel with:

- **Dual construction modes**: either `windowSpec` (literal spec) OR programmatic `addLabels:values:...`, `addCheckLabels:`, `addList:`, `addMessage:`, `addOK:`, `addTextLine:`, `addPasswordLine:`, `addTextEditor:` (12+ `add*` builder methods)
- **Canonical question API**: `choose:labels:values:default:`, `choose:labels:values:default:for:`, `choose:labels:values:default:equalize:for:`, `chooseMultiple:fromList:values:initialSelections:buttons:values:lines:cancel:for:`, `chooseReport:labels:values:default:equalize:for:`
- **Input prompts**: `request:initialAnswer:onCancel:`, `request:initialAnswer:onCancel:for:`, `request:initialAnswer:onCancel:windowLabel:for:`
- **File pickers**: `requestFileName:default:version:ifFail:for:`, `requestDirectoryName:default:version:ifFail:for:`, `requestFileNameWithMessage:default:version:ifFail:for:`
- **Lifecycle**: `preOpen`, `invokePostOpen`, `closeAccept`, `closeCancel`, `doCancel`, `accept`, `cancel`, `close`, `escapeIsCancel:`, `requestForWindowClose`
- **Programmatic UI sim**: `guiChangeItemValueTo:onWidget:`, `guiSelectItem:onWidget:`, `guiSelectItemUsingString:onWidget:`, `guiSimulateMouseClickOnWidget:` (these are testing-friendly!)

**Implication**: a `vw_create_dialog` tool can support BOTH spec-based AND programmatic `add*`-builder construction. The latter is friendlier for AI (no spec literal generation needed for simple dialogs).

Note: SimpleDialog's `guiSimulateMouseClickOnWidget:` etc. are also test seams — relevant for Phase E (Playwright SDK) integration.

## 5. ValueHolder + Adapter family (empirical from probe-1 + probe-2)

| Class | Inst selectors | Purpose | Notes |
|---|---:|---|---|
| `ValueHolder` | **3** | Holds a value, notifies dependents on `value:` | Slim — basically `value`, `value:`, `setValue:` |
| `AspectAdaptor` | 10 | Forwards `value`/`value:` to another model's aspect | `subject:` + `forAspect:` setters |
| `PluggableAdaptor` | 22 | Custom get-block + set-block + change-block | The most flexible; used by our `/click` handler |
| `TypeConverter` | 18 | Wraps another ValueModel + converts via a printer/parser | For type coercion (string ↔ number) |
| `SelectionInList` | 22 | List + selection index ValueHolder | For lists with selection |
| `MultiSelectionInList` | 16 | List + multi-selection | For multi-select lists |
| `BufferedValueHolder` | (in UI namespace) | Buffered editing — commit/revert | For input fields with cancel support |

Note **ABSENT**: `ValueAdaptor` (the generic base in stock VW — this image has no `ValueAdaptor` symbol top-level).

### 5.1 Idiomatic aspect-accessor pattern

```smalltalk
searchString
    ^searchString isNil
        ifTrue: [searchString := '' asValue]
        ifFalse: [searchString]
```

Three notes:
- **Lazy init in the accessor** — not in `#initialize`. This is the VW convention. `#initialize` may set basic state, but ValueHolders are lazy-created.
- **`'' asValue`** — sends `#asValue` to the literal. `asValue` on any object returns a `ValueHolder` wrapping it. Idiomatic.
- **Instance var name = aspect name** — `searchString` is both the iv and the aspect.

### 5.2 Two patterns the MCP tool should generate

**Pattern A — lazy aspect accessor** (single source of truth, idiomatic):
```smalltalk
aspectName
    ^aspectName isNil
        ifTrue: [aspectName := <defaultExpression> asValue]
        ifFalse: [aspectName]
```

**Pattern B — `#initialize` shotgun** (when aspect set is fixed at construction):
```smalltalk
initialize
    super initialize.
    searchString := '' asValue.
    selectedRecord := nil asValue.
    results := OrderedCollection new asValue
```

The MCP `vw_create_application_model` tool should default to Pattern A unless `--initialize-style: shotgun` is passed.

## 6. UI Painter — what's loaded (probe-2)

Empirically loaded in this image:
- `Tools.UIPainter` (57 inst selectors) — the main painter app
- `Tools.UIPainterController` — controller for the painter
- `Tools.UIPainterTool` — tool palette
- `Tools.UIPainterView` — view
- `Tools.UIPainterSystemController` — system integration
- `Tools.UIPainterWatcher` — change observer
- `Tools.UIPainterChange` — change record
- `Tools.UIPainterIcons` — icon library
- `Tools.UIPalette` — color/widget palette
- `Tools.UIFinderVW2` — Visual Finder
- `Tools.UIDefiner` — spec definer
- `Tools.UIHotRegionEditor` + `Tools.UIMaskEditor` — special editors
- `Tools.UISpecificationTreeModel` — spec tree model

NOT loaded:
- `UISubcanvasBuilder` (not even in Tools namespace)
- `CanvasView` / `CanvasTool` / `PaletteWindowApplication` / `AspectAttributesWindow` / `PalettePainter` (the verbose painter machinery)

**Implication**: this image has the **runtime** UIPainter but not the full **dev** Painter. Programmatic spec construction (via `compile:` on `windowSpec`) is the way; opening the actual Painter UI for editing is supported but probably not the primary path for AI workflows.

## 7. Parcel + Store APIs (empirical from probe-1 + probe-2)

### 7.1 What's loaded

**Top-level**:
- `Smalltalk.Parcel` (= `Kernel.Parcel`) — 224 inst + 86 class selectors. The main parcel class.
- `Smalltalk.ParcelLoadedChange` / `ParcelSavedChange` / `ParcelMissingError` — announcement classes
- `Smalltalk.CodeWriter` (= `Kernel.CodeWriter`) — 123 inst + 6 class selectors. The binary write engine.
- `Smalltalk.MethodChange` — change record

**ABSENT at top level** (Bundle/Pundle are gone in 9.3.1 production):
- `Bundle`, `Pundle`, `PackageInfo`, `PundleInfo`, `ChangeRecord`

**Store namespace** (238 keys) has the rich code-mgmt API:
- Loaders: `AbstractPundleLoader`, `AtomicCompilationManager`, `AtomicLoader`, `DirectLoader`, `PreReadActionConfirmation`
- Pundle (lives here): `PundleAccess`, `PundleChangeList`, `PundleForParcel`, `PundleHasUnpublishedChanges`, `PundleInstall`, `PundleLoadedChange`, `PundleModel`, `PundleSavedChange`, `PundleVersionAlreadyExistsError`
- Bundle (lives here): `BundleDescription`, `BundleForParcel`, `BundleInstall`, `BundleModel`, `BundlePrivilegeGraph`, `BundleSpecEditor`, `BundleStructureChange`
- Package: `PackageChooser`, `PackageComparitor`, `PackageDescription`, `PackageForParcel`, `PackageInstall`, `PackageModel`, `PackageObjectsToInitialize`, `PackageOwnerElement`
- Repository: `RepositoryFilterDialog`, `RepositoryManager`, `RepositoryPropertiesDialog`, `MiniRepositoryManager`
- Store lifecycle: `StoreConnect`, `StoreDevelopmentSystem`, `StoreDisconnect`, `StoreError`, `StoreLogEnvironment`, `StoreLoggingTool`, `StoreNewVersionWarning`, `StoreNotConnectedError`, `StorePostPublish`, `StorePrePublish`, `StoreSettings`, `StoreUnloadWarning`, `StoreWarning`, `StoreWorkActivity`
- Publish: `PublishAsParcelDialog`, `PublishMergeDialog`, `PublishPackageDialog`, `PublishPundleDialog`, `PublishPundlesDialog`, `PublishSpecification`, `Publishing`
- Diff / Merge: `Differator`, `DifferSubstring`, `DiffList`, `MergeApplyConfirmation`, `MergeException`, `MergeIcons`, `MergeToolHelp`, `Merging`, `BasicMergePolicy`, `NoCommonAncestor`, `ReconcilingComparitor`
- Shadows (for comparison): `ShadowedClassObject`, `ShadowedMethodObject`, `ShadowedNamespaceObject`, `ShadowedSharedVariableObject`, `ShadowOrganizer`
- Pseudo (for diff): `PseudoBundle`, `PseudoClassDefinitionDifference`, `PseudoMethodDifference`, `PseudoNamespaceDifference`, `PseudoPackage`, `PseudoPundle`, `PseudoRecord`

**Empirical naming gotcha** (probe-2): My v1 design guessed `Store.PackageInfo`, `Store.PundleInfo`, `Store.Pundle`, `Store.Package` — ALL ABSENT. The real VW Store API uses `PackageModel`/`PundleModel`/`PackageInstall`/`PundleInstall`/`BundleDescription`. Jasper's GemStone-style names do NOT transfer.

### 7.2 Parcel API surface (already known from session-19)

From session-19 carry-forwards + session-19 probes, the Parcel API supports:
- Build: `Kernel.Parcel createParcelNamed: 'Name'` → `addNameSpace:` / `addEntiretyOfClass:` / `addEntiretyOfClasses:` / `addSelector:class:` / `addClassAndAllSelectors:` / `addBinding:in:` → `parcelOutOn: pclFile withSource: pstFile hideOnLoad: false republish: false backup: false`
- Load: `Kernel.Parcel loadParcelFrom: aFilename`
- Unload: `[Kernel.Parcel removeParcelNamed: 'Name'] on: Core.Notification do: [:n | n resume]` (carry-forward #38)
- **CRITICAL WORKAROUND** (session-19): `parcelOutOn:` wedges via `Cursor>>showWhile:` — the Cursor monkey-patch from session-19 Build-Parcel.ps1 is the canonical workaround.

### 7.3 What the librarian (bg_3fe35753) will add

Pending: programmatic Store API patterns (PundleInstall use, PackageModel queries), Topaz file-in format, source code extraction from .pst.

## 8. Compiler / Change machinery (empirical from probe-1)

- `Smalltalk.Compiler` (7 subclasses) — the parser/compiler
- `Smalltalk.Behavior` (12,826 subclasses — = every class in the image) — has `compile:classified:` etc.
- `Smalltalk.ClassDescription` (12,824 subclasses) — has the class-side compile machinery
- `Smalltalk.MethodChange` (2 subclasses) — change records emitted on compile

**Carry-forward #41 reminder** (session-20): `compile:` on `VWB.VWBridge` class via `/eval` wedges the bridge listener even with the Cursor monkey-patch installed. UI announcement fan-out (`ChangeAdded`/`MethodAdded`) routes through a non-Cursor wedging path. **The v2 MCP design MUST guard `vw_compile_method` against any `VWB.*` namespace target** (and consider broader namespace refusal: `Core`, `Kernel`, `Tools`, `UI`).

For MAS application classes, `compile:` is safe (this is what the eval-driven /load.st file-in does every cold start, ~50 classes, no wedge).

## 9. AI-friendliness audit — where AI struggles, what tool should abstract

Per the user's direction "make it easier for AI than it have to guess", here's where AI generating raw VW Smalltalk goes wrong and what the MCP tool should hide:

| Painful for AI | Tool should abstract via |
|---|---|
| Spec literal-array syntax (`#(#{UI.FullSpec} ...)`) | `vw_create_window_spec` — takes JSON, emits literal |
| Lazy-initialized aspect accessor boilerplate | `vw_create_application_model` — generates accessors from `aspects:[{name, type, default}]` |
| ValueHolder vs AspectAdaptor vs PluggableAdaptor (when to use which) | Tool picks based on `aspect.binding` field (`#auto` / `#aspectAdaptor` / `#pluggable`) |
| LayoutFrame's 8-number format (offsets + fractions) | `vw_create_window_spec` accepts `{l, lf, t, tf, r, rf, b, bf}` keys OR `{anchor:"top-right", insets:{top:10, right:10}, size:{w:80, h:25}}` for the common cases |
| Class-side vs instance-side method placement (`compile:` vs `class compile:`) | Native `vw_compile_method` takes explicit `isMeta: bool` |
| Category strings (`*VWBridge-Patches mas-bug2-fix`, `accessing`, `interface specs`) | Tool defaults sensibly (`'accessing'` for accessors, `'interface specs'` for spec methods) |
| `subclass: ... instanceVariableNames: ...` definition syntax | `vw_create_class` takes structured params |
| Namespace placement (`inDictionary: 'Name'` for chunk file-in) | Tool takes `namespace: string` arg |
| Sources stripped — can't return method source | Tool returns `messages`/`literals`/`numArgs` fingerprint instead, surfaces the limitation |
| Direct-invoke SUnit gate pattern (carry-forward #20) | Tool encapsulates the gate; AI just specifies `class` + `selector` |
| Carry-forward #41 wedge | Tool refuses `VWB.*` targets pre-call |
| Bug #5 substring guard | Tool refuses `vw_eval` bodies with both `'VWBridge'` + `'dispatch'` substrings pre-call |
| Workspace `Core.*` qualification (carry-forward #18) | Tool checks if generated source will be Workspace-pasted; auto-qualifies stock classes |
| Parcel build wedge via `Cursor>>showWhile:` | Tool wraps parcel-build calls with the Cursor monkey-patch automatically |

**The MCP server is the abstraction layer that turns 42 carry-forward constraints into safe tool behavior.** AI doesn't need to learn the constraints; the tool either handles them transparently or refuses with a clear error.

## 10. Tool surface implications for architecture.md v2

The v1 design had 13 MVP tools (mostly Jasper-equivalent). For v2, the **VW-native UI/dev tools** should be added with these proposed names + the existing surface:

### New tools for v2 (UI / ApplicationModel / Parcel construction)

| Tool | Description | MVP? | Underlying ops |
|---|---|---|---|
| `vw_create_class` | Create or update a class with structured params (name, namespace, superclass, instVars, classVars, classInstVars, category) | MVP | `vw_eval` with `subclass:` expression (with namespace guard) |
| `vw_create_application_model` | Scaffolding tool: creates a class + `#initialize` + N aspect accessors + N action methods + class-side `windowSpec` | V2 | composite of `vw_create_class` + multiple `vw_compile_method` |
| `vw_create_window_spec` | Compile a class-side `windowSpec` method from structured JSON (window props + components tree) | V2 | `vw_compile_method` with literal-array source |
| `vw_add_widget_to_window` | Modify a class's existing `windowSpec` to add one widget | V3 | read `windowSpec` → parse → mutate → recompile |
| `vw_create_dialog` | Scaffolding tool: SimpleDialog subclass with either spec-based OR programmatic `add*` builder methods | V2 | composite |
| `vw_open_application` | Open an ApplicationModel subclass in the image | MVP | `vw_eval` with `MyApp new openInterface: #windowSpec` |
| `vw_create_parcel` | Build a parcel with class list + extension methods + namespace | V2 | wraps `Kernel.Parcel createParcelNamed:` + `addEntiretyOfClass:` + `parcelOutOn:` with Cursor monkey-patch |
| `vw_load_parcel` | Load a parcel from a file path | MVP | `Kernel.Parcel loadParcelFrom:` |
| `vw_unload_parcel` | Remove a loaded parcel | V2 | `removeParcelNamed:` with Notification-resume |
| `vw_list_loaded_parcels` | Enumerate currently-loaded parcels | MVP | `Kernel.Parcel allInstances` or `loadedParcels` |
| `vw_define_action` | Add an instance-side action method to an ApplicationModel class | V2 | `vw_compile_method` (typed wrapper) |
| `vw_define_aspect` | Add an aspect accessor + instance var to an ApplicationModel class | V2 | `vw_create_class` (with iv added) + `vw_compile_method` (accessor) |
| `vw_set_class_category` | Set a class's category (for parcel inclusion via `*PackageName` convention) | V3 | `Cls category: 'X'` |
| `vw_get_widget_value` | Read aspect value from a live app instance (vs spec) | V2 | uses bridge `/value?aspect=X` |

### Revised tool surface estimate

- **MVP** (was 13 in v1): 13 → **18** tools (adds `vw_create_class`, `vw_open_application`, `vw_load_parcel`, `vw_list_loaded_parcels`, `vw_unload_parcel`)
- **V2** (was +13 = 26): 26 → **34** tools (adds `vw_create_application_model`, `vw_create_window_spec`, `vw_create_dialog`, `vw_create_parcel`, `vw_define_action`, `vw_define_aspect`, `vw_get_widget_value`, `vw_search_widget_by_label`)
- **V3+** (was +14 = 40): 40 → **48** tools (adds `vw_add_widget_to_window`, `vw_set_class_category`, `vw_painter_introspect`, `vw_diff_spec_to_running_window`, `vw_export_topaz_filein`, `vw_extract_parcel_source`, `vw_invoke_store_compare`, `vw_publish_to_store`)

Total: ~48 tools, ~50% of which are NATIVE-TYPED for UI/dev work; the rest are Jasper-equivalents and bridge-liveness.

### Effort estimate revision

| Tier | Tool count | Effort | Notes |
|---|---:|---|---|
| Setup | — | 0.5d | unchanged |
| **MVP** (18 tools) | 18 | **3d** (was 2d) | +1 day for the 5 new tools (`vw_create_class` is the meatiest) |
| Auto-registration | — | 0.5d | unchanged |
| **V2** (+16 tools = 34) | 16 | **3d** (was 2d) | +1 day for the spec-literal-generation logic in `vw_create_window_spec` |
| **V3+** (+14 tools = 48) | 14 | **3d** (was 2d) | +1 day for the existing-spec-mutation logic in `vw_add_widget_to_window` |
| **TOTAL** | **48** | **10d** (was 7d) | Onboarding milestone moves from ~3d to ~4d via MVP |

## 11. Sections pending wave-2 librarian validation

The following sections are based on image probes only and need librarian-research corroboration:

- **§2.1 Format rules** — librarian (bg_aa6ea2ef) should validate the literal-array format conventions against AppDevGuide.pdf + public real-world windowSpecs from VW GitHub repos
- **§4.3 Lifecycle hooks** — librarian (bg_356abb3f) should validate the canonical use cases for `preBuildWith:` / `postBuildWith:` / `postOpenWith:` (when to override each)
- **§5.1 Idiomatic accessor pattern** — librarian (bg_356abb3f) should confirm `searchString isNil ifTrue: [...] ifFalse: [...]` lazy pattern is canonical (vs eager-init in `#initialize`)
- **§7.3 Store API patterns** — librarian (bg_3fe35753) should provide canonical `PundleInstall` / `PackageModel` usage patterns + Topaz file-in spec
- **Real-world MAS examples** — librarian (any) may surface more representative MAS app examples than `Tools.AboutVisualWorksDialog` (a system dialog vs a business app)

## 12. References

- [`01-mcp-sdk.md`](./01-mcp-sdk.md) — SDK selection (TypeScript ^1.29.0)
- [`02-jasper-delta.md`](./02-jasper-delta.md) — 33 Jasper tools mapped to VW
- [`03-vw-specific-capabilities.md`](./03-vw-specific-capabilities.md) — 12 VW-only MCP tools (UI driving, screenshot, wait)
- [`04-mcp-best-practices.md`](./04-mcp-best-practices.md) — MCP server best practices (Claude Desktop, auto-register, single-owner, error semantics)
- [`../design/architecture.md`](../design/architecture.md) — v1 design (locks SDK + transport + MVP tool surface); v2 rewrite pending this doc
- [`../../vw-bridge/probes/_probe-s21-vw-ui-classes.st`](../../vw-bridge/probes/_probe-s21-vw-ui-classes.st) — image probe 1
- [`../../vw-bridge/probes/_probe-s21-namespace-contents.st`](../../vw-bridge/probes/_probe-s21-namespace-contents.st) + `.result.json` — image probe 2
- [`../../vw-bridge/probes/_probe-s21-inherited-and-example.st`](../../vw-bridge/probes/_probe-s21-inherited-and-example.st) + `.result.json` — image probe 3
- [`../../../knowledge/vw-image-api-contract.md`](../../../knowledge/vw-image-api-contract.md) — 42 carry-forward constraints (esp. #15, #16, #18, #20, #28, #38, #41)
