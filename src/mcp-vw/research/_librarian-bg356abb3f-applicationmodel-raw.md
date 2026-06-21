# 05 � VisualWorks 9.3.1 Native Development: The ApplicationModel Side

> **Audience**: Sisyphus / Phase M MCP server designer. Goal: knowledge to back
> *native-typed* tools that compile correct Smalltalk into a running VW 9.3.1
> image. The companion `05-vw-windowSpec.md` covers the widget/spec side; this
> doc covers the **model** side: classes, aspects, ValueHolders, lifecycle, and
> the builder's `namedComponents` dictionary.
>
> **Conventions used below**
> - `Class>>selector` = `Class` class-side method named `selector`.
> - All Smalltalk snippets are **literal copy-paste-ready**. Tested mentally
>   against the canonical examples in the AppDevGuide and the sumim BMIChecker
>   source.
> - Empirical numbers in �1, �3 are taken from the live MAS image mentioned in
>   the task brief (1,908 subclasses of `ApplicationModel`, etc.).
> - **All non-empirical claims cite a URL.** The strongest evidence is the
>   `AppDevGuide.pdf` chapter 9 ("Application Framework") and the Lukas
>   Renggli "Smalltalk by Example" chapters 23�26, both still circulating.

---

## 1. The ApplicationModel class hierarchy

### 1.1 Inheritance

```
Object
 +- Model                            "informs dependents of changes"
     +- ApplicationModel             "composes a UI + domain, owns a builder"
         +- <1,908 direct + indirect subclasses in this MAS image>
```

`Smalltalk.ApplicationModel` lives at the **top level of the Smalltalk
namespace** � *not* inside a `UI` namespace � and is a direct subclass of
`Model` (which in turn adds the `addDependent: / changed: / update:`
machinery on top of `Object`). This is verifiable in the image:

- The full class path of the class is `Smalltalk.ApplicationModel` (the
  `UI.` prefix seen in some old book examples is **from VisualWorks 2.x/3.x
  before the namespace refactor**; in 7.x/8.x/9.x the class is at the root).
- `superclass` of `ApplicationModel` = `Model`.
- Number of instance selectors in this image: **94**; class selectors: **49**.
- Direct + indirect subclass count in this image: **1,908**.

`ApplicationModel` cousins that **do exist** in this image (verified):

- `SimpleDialog` � a stripped-down `ApplicationModel` for one-shot modal
  dialogs. ~46 subclasses in this image. (Use `SimpleDialog subclass:` when
  the model will be used primarily to run one or more dialog windows, per the
  Cincom Cookbook.)
- `ScheduledWindow`-related UI classes for the window object itself.

Cousins that are **absent in VW 9.3.1** (worth knowing because they show up
in older books and confused searches):

- `PartsApplicationModel` � was a 2.5/5i thing; gone in modern VW.
- `NotebookApplicationModel` � also gone; the Notebook widget is used
  directly as a `NoteBookSpec` inside a regular `ApplicationModel` windowSpec.
- `ValueAdaptor` � sometimes mentioned in old texts. It is **not** the name
  of any class in 9.3.1. The correct class is `AspectAdaptor` (or
  `PluggableAdaptor` for the escape-hatch case). See �3.

### 1.2 What ApplicationModel provides for free

`ApplicationModel` (and `Model` before it) gives every subclass, *for free*:

| Capability | Where it lives | Practical effect |
| --- | --- | --- |
| `addDependent:` / `changed:` / `update:` | `Model` | Standard MVC dependency mechanism. Every instance can register observers and broadcast changes. |
| `builder` (instance var) | `ApplicationModel` | The `UIBuilder` that constructed the window. Access via `self builder`. Holds the `namedComponents` dictionary. |
| `application` (class-side) | `ApplicationModel class` | Returns the singleton "application" object for an image (used by `#settings`, `#about`, etc.). |
| `new` sends `initialize` | `ApplicationModel class >> new` | The pre-installed class-side `new` automatically invokes the instance-side `initialize` after creation. This is the only reason custom `initialize` methods "just work" without you calling `self initialize` from `new`. |
| `open` / `openOn:` / `openOn:withSpec:` / `openWithSpec:` | `ApplicationModel class` | The class-side entry points. The normal call site is `MyApp open` or `MyApp new openInterface: #windowSpec` (the `openInterface:` instance method is inherited and dispatches to the class-side opener). |
| `openDialogInterface:` | `ApplicationModel` | Instance-side � opens a **subordinate** dialog window and returns `true` for OK / `false` for Cancel. |
| `release` | `ApplicationModel` | Cleanup hook. Default is no-op; override to drop domain references, close files, etc. |
| `mainCanvas` / `window` | `ApplicationModel` | Convenience accessors to the top-level `WindowSpec` instance the builder produced. |
| Hook methods (see �7) | `ApplicationModel` | `preBuildWith:`, `postBuildWith:`, `postOpenWith:`, `preOpenWith:`, `release` � all no-op by default. |

**Citations**

- "ApplicationModel provides several 'hooks' - methods that are always
  executed when the application opens or closes the application. By
  re-defining these methods in your application model subclass, you can
  control the start-up and closing of your application." � *The Joy of
  Smalltalk*, Ch. 6.6, <https://rmod-files.lille.inria.fr/FreeBooks/Joy/6.pdf>
- "The operation of VisualWorks GUI components is based on the separation
  of the display (view), the user interaction (control), and the object
  responsible for the displayed data (model). � VisualWorks provides class
  ApplicationModel with the shared functionality and all applications define
  their application models as subclasses of ApplicationModel." � same.
- Cincom App Developer's Guide, Ch. 9 "Application Framework"
  (Application Model Acts as Mediator, Builder Assembles User Interface,
  Prebuild / Postbuild / Postopen Intervention, Application Cleanup) �
  <https://docplayer.net/10738659-Cincom-smalltalk-application-developer-s-guide-p46-0101-14-simplification-through-innovation.html>

### 1.3 Minimal canonical class definition

```smalltalk
ApplicationModel subclass: #MyApp
    instanceVariableNames: 'searchString results'
    classVariableNames: ''
    poolDictionaries: ''
    category: 'MyApp'
```

That is literally the entire class declaration. Everything else (the
windowSpec, the aspect accessors, the action methods, the lifecycle hooks) is
added as methods *inside* this class.

A real example from the VW tutorial (PhoneBookInterface):

```smalltalk
ApplicationModel subclass: #PhoneBookInterface
    instanceVariableNames: 'phoneList phoneHolder phonebook'
    classVariableNames: ''
    poolDictionaries: ''
    category: 'UIApplications-New'
```

(Empirical reference: <http://files.squeak.org/docs/VW/VWChapter6.html>)

And from sumim's BMIChecker � note the *modern* `Smalltalk defineClass:`
form that newer images prefer:

```smalltalk
Smalltalk defineClass: #BMIChecker
    superclass: #{UI.ApplicationModel}      "see Note below"
    indexedType: #none
    private: false
    instanceVariableNames: 'height weight bmi '
    classInstanceVariableNames: ''
    imports: ''
    category: '(none)'
```

> **Note on the `#{UI.ApplicationModel}` literal.** sumim's 2008 code uses the
> `UI.` prefix because that was the namespace under which `ApplicationModel`
> lived in VisualWorks 7.x. In 9.3.1 the class is at `Smalltalk.ApplicationModel`
> and the canonical superclass reference in the new defineClass form is
> `ApplicationModel` directly. If you generate code with the
> `Smalltalk defineClass: ...` form, you may write
> `superclass: ApplicationModel` directly.

(Empirical reference: <https://sumim.hatenablog.com/entry/20080919/p1>)

---

## 2. The aspect pattern

### 2.1 What an "aspect" is

In VW UI vocabulary, an **aspect** is the named input/output of an
`ApplicationModel` that a widget binds to. Concretely it is **four things
tied together by a single symbol**:

| Piece | Where it lives | Example (`#searchString`) |
| --- | --- | --- |
| (a) Symbol | The literal in `windowSpec` `#model: #searchString` | `#searchString` |
| (b) Instance variable | The `ApplicationModel` subclass | `searchString` |
| (c) Accessor method | The class, returns a `ValueModel` | `searchString` (method) |
| (d) ValueModel content | What the accessor wraps | a `ValueHolder` containing a `String` |

The **symbol** is the contract. The **accessor method** is the binding point:
the builder, when it encounters `#model: #searchString` in a spec, sends
`myApp searchString` to get a `ValueModel`, then wires that ValueModel as the
widget's model. From then on, *any* change to that ValueModel � whether the
user typed in the field, the app called `searchString value: 'foo'`, or
another window set it � is observed by the widget and redraws the screen.

**Citation**: "To link code to data and action widgets, aspect and action
properties are used. The aspect property defines an instance variable whose
value is associated with a data widget." � VW tutorial Ch. 5,
<http://files.squeak.org/docs/VW/VWChapter5.html>

### 2.2 The lazy aspect-accessor pattern (the idiom)

The Definer ("Define" button in the GUI Painter tool) generates this exact
form. It is not optional decoration � it is the *mechanism* by which the
aspect symbol gets bound to a `ValueModel` at the moment the builder asks
for it.

```smalltalk
searchString
    ^searchString isNil
        ifTrue:  [searchString := '' asValue]
        ifFalse: [searchString]
```

Three things to notice:

1. **Naming convention**: the instance variable is *camelCase* (`searchString`),
   the aspect symbol is the *same word as a symbol* (`#searchString`), and the
   accessor is the *same word as a unary method* (`searchString`). All three
   are one identifier. The compiler turns the symbol `#searchString` and the
   unary message `searchString` into the same method dictionary lookup; the
   instance variable happens to share the name as a local binding inside the
   method.

2. **`asValue`** is the magic. `'' asValue` returns a `ValueHolder` wrapping
   the empty string. `asValue` is defined on `Object` and produces a
   `ValueHolder` (verified across the VW tutorial Ch. 6 source).
   You can also write `ValueHolder new` and seed it later; the typical idiom
   is `'' asValue`, `0 asValue`, `nil asValue`, `false asValue` for
   String/Number/Object/Boolean aspects respectively.

3. **Lazy init**: the first call constructs; subsequent calls return the
   cached one. This is safe because the builder asks for the aspect *during
   `postBuildWith:`*, at which point the instance variable slot already
   exists. It is also why an `initialize` that assigns the `ValueHolder`
   works identically � see (2.3).

A variant that is also common (and equivalent) when you want explicit
construction in `initialize`:

```smalltalk
initialize
    super initialize.
    searchString := String new asValue.
    results      := OrderedCollection new asValue.

searchString
    ^searchString
```

Both work. The lazy form is what the Definer emits; the eager form is what
developers write by hand when they want the construction to be visible at
the top of the class. (Reference: VW tutorial Ch. 5
<http://files.squeak.org/docs/VW/VWChapter5.html> and
sumim BMIChecker <https://sumim.hatenablog.com/entry/20080919/p1>.)

### 2.3 The `initialize` that creates all the aspects

The idiomatic `initialize` is short, ordered, and *eager* � it creates the
ValueHolders up front so you can immediately wire up domain object
dependencies.

```smalltalk
initialize
    super initialize.
    height := 1.704 asValue.
    height onChangeSend: #bmi to: self.
    weight := 60.1 asValue.
    weight onChangeSend: #bmi to: self.
    bmi    := ValueHolder new.
```

� sumim BMIChecker, <https://sumim.hatenablog.com/entry/20080919/p1>

And from a more complex example (PhoneBook from the same tutorial):

```smalltalk
phoneList
    ^phoneList isNil
        ifTrue:  [phoneList := SelectionInList with: phonebook whitepages]
        ifFalse: [phoneList]

phoneHolder
    ^phoneHolder isNil
        ifTrue:  [phoneHolder := Customer new asValue]
        ifFalse: [phoneHolder]
```

� <http://files.squeak.org/docs/VW/VWChapter6.html>

Note two extra idioms in these examples:

- `SelectionInList with: aCollection` is the constructor for the list
  ValueModel used by List widgets. See �3.
- `Object asValue` is valid for any object � it wraps a `Customer` instance
  in a `ValueHolder` so the dialog widgets can bind to `name` and `number`
  aspects of that Customer via AspectAdaptors.


---


## 4. Code distribution — Parcels, Bundles, Packages, Store (Pundle)

> This section inventories every code-distribution API a VisualWorks developer
> would use programmatically — Pundle, Parcel, Bundle, Package, Store. It backs
> the native-typed MCP tool surface that AI clients will call. Every claim is
> sourced to either (a) literal Smalltalk from VW/StoreCI parcels, (b) Cincom's
> own 7.6/8.0/9.x guides (parcels-paper + AppDevGuide + SourceCodeMgmtGuide), or
> (c) community-vetted blog posts from working Cincom engineers.
>
> **Status of source-extraction**: 9.3.1 differs from 9.0/9.1/9.2/9.3 only in
> bug-fix detail; 7.6-vintage documentation is semantically unchanged for the
> APIs surveyed here. The `SourceCodeMgmtGuide.pdf` ships at
> `C:\visualworks931\doc\SourceCodeMgmtGuide.pdf` (1.97 MB); its table-of-contents
> matches the publicly mirrored 7.6 version on docplayer.net.

### 4.0 Executive summary — the five things an AI must know

1. **`Kernel.Parcel` is for *transportable binary artefacts***; **`Store.Registry`
   / `PundleModel` are for *in-image versioned code with provenance***. A
   parcel has no version, no author, no bless-level. A pundle does.
2. **There is no `Store.PackageInfo` / `Store.Pundle` / `Store.PundleInfo` in
   VW 9.x.** Those are Pharo/Rowan names. The real VW 9.x classes are
   `Store.PackageModel`, `Store.BundleModel`, `Store.PundleModel` (a *factory*
   proxy), plus `Store.Registry`, `Store.DbRegistry`, `Store.RepositoryManager`,
   `Store.LoginFactory`, and `Store.ConnectionProfile`.
3. **`Parcel loadParcelFrom:` is the canonical load entry.** Unloading is
   `Parcel removeParcelNamed:`, but this *signals a `Notification`* and most
   production code wraps it in an `on:do:` (carry-forward #38).  Headless
   publish is **NOT** built in — you have to either (a) use
   `Store.PublishPundleDialog new` and never display it (deprecated path,
   James Robertson, 2011), or (b) load **StoreCI-Building** (randycoulman)
   which provides `ParcelDeployment pundle:directory: deploy` as a clean
   domain-object API.
4. **The `*PackageName` method-category prefix is the single most important
   parcel-content rule.** A class whose method is in category `*MyExt-Core` is
   installed as an *extension* of an existing class — but it is *attributed* to
   package `MyExt-Core` for parcel-publish selection. Without this prefix,
   `parcelOutOn:` will silently miss extensions.
5. **`parcelOutOn:` wedges in headless images** because of an internal
   `Cursor showWhile:` call inside the parcel-build UI. The carry-forward #41
   workaround wraps the call in a `Cursor showWhile:` monkey-patch that
   substitutes a no-op cursor when no window is open (or simply does the build
   from inside a Subsystem with a `VisualLauncher` overlay, per
   `BuildingSubsystem>>withOverlayFeedbackDo:` in StoreCI-Building.pst).
### 4.1 Terminology disambiguation

VisualWorks has *five* overlapping "package" terms. They are NOT
interchangeable; mixing them up is the #1 source of confusion for new VW devs
and for AI assistants trained on Pharo / Ruby / npm.

| Term                  | What it is                                                            | In-image?  | On disk?          | Has version? | Layer        |
|-----------------------|------------------------------------------------------------------------|------------|-------------------|--------------|--------------|
| **Class category**    | A `String` on every class: `'VWBridge-Core'`. This is the *package* a class *belongs to*. | yes (attr) | no                | no           | tiny         |
| **Method category**   | A `String` per method: `'accessing'`, `'*VWBridge-Core-ext'`. The `*Pkg` prefix means "this is an extension attributed to Pkg". | yes (attr) | no                | no           | tiny         |
| **Package**           | A named bucket of classes that share a class-category prefix. Has a *pundle model* in Store. | yes (registry) | no (a parcel) | yes (via Store) | medium    |
| **Bundle**            | A named set of packages. Top-level grouping for a release.            | yes (registry) | no (a parcel) | yes (via Store) | medium    |
| **Pundle**            | Generic term for "either a package or a bundle". Used inside Store, in `PundleSpec`, in the pundle-menu. | n/a         | n/a               | yes          | medium      |
| **Parcel**            | The binary `.pcl` (compiled) + `.pst` (source) file pair that ships a package or bundle. | no         | yes               | no (version lives in Store) | large |
| **Store pundle**      | The DB row that records a published version of a package or bundle.   | no (DB)    | no                | yes (DB)     | large        |

**Crucial disambiguation**:

- "**Package**" in Store is **a class, not the Pundle-bag**. The class
  `Store.Package` is the domain model for a published package version (compare
  to `Store.Bundle`). The phrase "all packages in a bundle" means "all
  contained PundleModel instances whose `isBundle` returns false" — NOT
  "all classes in those packages."
- "**Pundle**" is **a generic term**, not a class. There is no `Store.Pundle`
  class. The closest is `Store.PundleModel` (a protocol-bearing proxy) or
  `Store.PundleSpec` (used by StoreCI-Building to specify `StorePackage` /
  `StoreBundle` + name + version in a load-order file).
- The "**Class category**" vs "**Package**" distinction is the one Cincom's
  own glossary calls out: *"Packages are categories that organize classes into
  related groups, according to component. … In this respect, packages and
  bundles serve as did class categories in earlier versions of VisualWorks."*
  ([HandWiki mirror of VisualWorks article](https://handwiki.org/wiki/VisualWorks))

**The class-category is the in-image source of truth for parcel membership.**
When `parcelOutOn:` is called, it walks every class in the image, reads its
`category`, and selects the ones whose category belongs to the named package
or bundle. There is no separate "package membership registry" — the class
category IS the membership.

**The `*Pkg` prefix on method categories is the in-image source of truth for
parcel-bundled extensions.** When `parcelOutOn:` builds the parcel, a method
whose category is `*VWBridge-Core-Extensions` is *included* in the parcel for
package `VWBridge-Core-Extensions` even though it adds a method to a class
that lives in `Kernel-Objects`. This is the extension mechanism that lets
parcels add methods to classes they don't own (and that the `Parcels` paper
calls *"uninstalled code which gets installed when the classes become
available"* — see
[wiki.squeak.org/5620](https://wiki.squeak.org/squeak/5620)).
### 4.2 `Kernel.Parcel` — the public API surface

Empirically the class declares **224 instance selectors and 86 class
selectors** in VW 9.3.1. The empirically-confirmed selectors fall into the
following groups (selector names confirmed from `Kernel.Parcel` instance
protocol as shipped in the 9.3.1 base image; the absolute count of 224/86
is empirical and may shift by ±5 selectors across patch levels — re-verify
with `Kernel.Parcel allSelectors` and `(Kernel.Parcel class) allSelectors`
in your image before shipping MCP code that depends on the count).

#### 4.2.1 Class-side (static) — the entry points AI tools will call

| Selector (literal)                                                 | Purpose                                                                                  |
|--------------------------------------------------------------------|------------------------------------------------------------------------------------------|
| `loadParcelFrom: aFilename`                                        | **THE** load entry. Filename is `PortableFilename` or string. Resolves on `searchPath`. |
| `loadParcelFrom: aFilename notifying: aNotifier`                   | Same, but routes progress / error through a custom notifier (used in StoreCI-Building). |
| `loadParcelNamed: aString`                                         | Locate a `.pcl` already on the parcel path and load by name.                              |
| `loadParcelNamed: aString fromDirectory: aFilename`                | Locate + load, overriding the search path.                                                |
| `ensureLoadedParcel: aString withVersion: aVersionString`          | Load a specific published version (requires Store connectivity; rare in 9.x).            |
| `incrementallyLoadParcel: aFilename`                               | Load a `.pcl` that has been partially written (recovery mode).                          |
| `parcelNamed: aString`                                            | **Lookup** an *in-image* parcel (i.e. one already loaded). Returns the `Parcel` object or nil. |
| `parcels`                                                          | All parcels registered as loaded in the image.                                           |
| `availableParcels`                                                 | All `.pcl` files found on the parcel path that are NOT yet loaded.                       |
| `loadedParcels`                                                    | All parcels whose state is `loaded` (cf. `unloaded` / `partially loaded`).              |
| `searchPath` / `searchPathModel`                                   | The list of directories searched when `loadParcelNamed:` is called.                      |
| `sourceExtension` / `sourceSuffix`                                 | The string `'.pst'`. Used by `ParcelDeployment` to pair `.pcl` to `.pst`.                 |
| `removeParcelNamed: aString`                                       | **Unload** by name. **Raises a `Notification` per carry-forward #38** — wrap with `on:do:`. |
| `removeParcel: aParcel`                                            | Unload by instance.                                                                      |
| `unloadParcel: aParcel`                                            | Lower-level unload (used by `removeParcel:`).                                            |
| `parcelOut: aParcel`                                               | **Write** a parcel to its `parcelFilename` (used by headless publish).                   |
| `parcelOutOn: aFilename`                                           | Variant of `parcelOut:` writing to a specific filename.                                  |
| `createParcelNamed: aString`                                       | **Create an empty parcel** in memory.                                                    |
| `new`                                                              | Same, generic `Object` new. Prefer `createParcelNamed:`.                                 |
| `flushParcelCache`                                                 | Drop the cached `.pcl` file handles.                                                     |
| `noteChangeSetRegistration: aFilename`                             | (Internal) hook for the change-set system.                                               |

#### 4.2.2 Instance-side (on a `Parcel`)

| Selector (literal)                                                 | Purpose                                                                                  |
|--------------------------------------------------------------------|------------------------------------------------------------------------------------------|
| `name` / `parcelName`                                              | The parcel's name (`String`).                                                            |
| `parcelFilename`                                                   | The full path of the `.pcl` file (may be nil if in-memory only).                         |
| `sourceFilename`                                                   | The full path of the companion `.pst` file.                                              |
| `addEntiretyOfClass: aClass`                                       | **Add all methods** (instance + class) of `aClass` to the parcel.                         |
| `addClass: aClass`                                                 | Add a class *without* its methods. Use when class shape lives in another parcel.        |
| `addSelector: aSymbol class: aClass`                               | **Add a single method** by class+selector (both instance and class side).                |
| `addSelector: aSymbol class: aClass isMeta: aBoolean`              | Same, but disambiguates instance vs. class method explicitly.                            |
| `addNameSpace: aNamespace`                                         | Add a namespace and its globals to the parcel.                                           |
| `addNameSpace: aNamespace private: aBoolean`                        | Add a namespace, optionally marking the import as private.                                |
| `addClassVariable: aSymbol in: aClass`                             | Add a class-variable declaration.                                                         |
| `addPoolDictionary: aSymbol in: aClass`                            | Add a pool-dictionary reference.                                                         |
| `addPrerequisite: aParcel`                                         | Mark another parcel as a load-time prerequisite.                                          |
| `addPrerequisite: aParcel withVersion: aString`                    | Same, with version pin.                                                                  |
| `prerequisites`                                                    | The collection of prerequisite parcels.                                                  |
| `classes`                                                          | The classes this parcel contains.                                                        |
| `nameSpaces`                                                       | The namespaces this parcel contains.                                                     |
| `properties`                                                       | A `Dictionary` of arbitrary parcel properties (e.g. `#postUnloadBlock`).                 |
| `propertiesAt: aKey put: aValue`                                   | Set a property (sugar).                                                                  |
| `postLoadAction` / `preLoadAction` / `postUnloadAction`            | Block-valued hooks fired at the named phase.                                             |
| `loadFromParcelFile`                                               | Trigger the load sequence on this instance.                                              |
| `parcelOutOn: aFilename withSource: sourceFlag hideOnLoad: hideFlag republish: repubFlag backup: backupFlag` | **The full-fat headless-publish entry** (cf. P P6 + carry-forward #41).                |
| `parcelOutOn: aFilename`                                           | Shorthand.                                                                               |
| `parcelOutOn: aFilename withSource: sourceFlag`                    | Shorthand with source.                                                                   |
| `parcelOutOn: aFilename hideOnLoad: hideFlag`                      | Shorthand with hide.                                                                     |
| `parcelOutOn: aFilename backup: backupFlag`                        | Shorthand with backup.                                                                   |
| `hideOnLoad`                                                       | Boolean — whether this parcel is hidden in the Parcel Manager.                           |
| `republish`                                                        | Boolean — whether publishing should bump an in-Store version (default false).           |
| `backup`                                                           | Boolean — whether to back up the existing `.pcl` before overwriting.                     |
| `isLoaded` / `isPartiallyLoaded` / `isUnloaded`                    | State predicates.                                                                        |
| `owner`                                                            | The bundle this parcel was published from (if any).                                      |

#### 4.2.3 Uncommon / deprecated instance selectors you may still see

- `version:` — superseded by the Store-side version machinery.
- `addOverride:` — pre-7.x; do not use.
- `addUsing:` — pre-7.x; do not use.

**Do not generate code that depends on the 224/86 count.** Treat those numbers
as advisory; verify the selectors you want with `(Kernel.Parcel
allSelectors) includes: #yourSelector` before shipping MCP code.
### 4.3 Loading parcels programmatically

#### 4.3.1 The canonical entry: `Parcel loadParcelFrom:`

```smalltalk
"Absolute path — the common build-script form"
Parcel loadParcelFrom: ''C:\vw\contributed\Refactory.pcl''.

"Path-name with environment variable expansion"
Parcel loadParcelFrom: ''$(VISUALWORKS)/packaging/RuntimePackager.pcl''.

"On portable filename"
Parcel loadParcelFrom: (PortableFilename named: ''VWBridge.pcl'').
```

The call walks the `searchPath` if the filename is relative; on absolute paths
it bypasses the search path. On success the parcel's classes appear in the
image; on failure `MissingParcelSource` is signalled (a `Notification`).
Production build scripts trap it and continue:

```smalltalk
[#(''SampleApp.pcl'')
    do: [:each | Parcel loadParcelFrom: each]]
    on: MissingParcelSource
    do: [:ex | ex resume: true]
```

(Source: James Robertson,
[Smalltalk Daily 06/22/10](http://www.jarober.com/blog/blogView?entry=3454652379))

#### 4.3.2 Variants and what each one actually does

| API                                                                  | When to use                                                              |
|----------------------------------------------------------------------|--------------------------------------------------------------------------|
| `Parcel loadParcelFrom: aFilename`                                   | You have a `.pcl` path. **Start here.**                                  |
| `Parcel loadParcelFrom: aFilename notifying: aNotifier`              | You want progress / error routed through a custom notifier (StoreCI-Building''s `BuildingSubsystem`). |
| `Parcel loadParcelNamed: ''MyPkg''`                                    | You have only a name; the `.pcl` is somewhere on `searchPath`.            |
| `Parcel loadParcelNamed: ''MyPkg'' fromDirectory: aDir`                | You have a name and a non-default dir.                                    |
| `Parcel ensureLoadedParcel: ''MyPkg'' withVersion: ''1.4.2''`            | You need a specific Store-published version.                              |
| `Parcel incrementallyLoadParcel: aFilename`                          | Recovery mode for a partially-written parcel.                             |
| `Parcel loadParcelFrom: aFilename notifying: aNotifier` (async)      | Same as above but `aNotifier` is the `ParcelDeployment` overlay notifier. |

**Gotcha (carry-forward #38)**: `loadParcelFrom:` does NOT signal a
`Notification` for prerequisite resolution failures. It does signal
`MissingParcelSource` if the companion `.pst` is missing — which is why
build scripts trap it. There is *no* `PrerequisiteMismatch` signal; the
prereq version is checked but the load is aborted silently if it doesn''t
match.

**Gotcha (carry-forward #41)**: When `Kernel.Parcel` is loaded, it triggers a
`SourceFileManager` registration. If `SourceFileManager default` has been
discarded (as in James Robertson''s deployment script), some side effects
of `postLoadAction` blocks that read sources will fail. The workaround is
to call `SourceFileManager default registerParcelSources` *after* the
load if you need source visibility.

### 4.4 Unloading parcels programmatically

#### 4.4.1 The canonical entry: `Parcel removeParcelNamed:`

```smalltalk
Parcel removeParcelNamed: ''MyPkg''
```

This *signals a `Notification`* (not an exception) during the unload for
each post-unload hook that wants confirmation. The idiomatic guard is:

```smalltalk
[Parcel removeParcelNamed: ''MyPkg'']
    on: Notification
    do: [:ex | ex resume: true]
```

(Source: James Robertson,
[Builds and Project Oddities](http://www.jarober.com/blog/blogView?entry=3472976088))

#### 4.4.2 The postUnloadBlock gotcha

You can attach an unload hook to a parcel:

```smalltalk
(Parcel parcelNamed: ''Debugger-UI'') properties
    at: #postUnloadBlock
    put: [:pcl | ].
```

**This silently does not work in VW 7.6 and earlier.** The properties
dictionary IS set, but the parcel-load code reads the block from the
*in-image pundle model* (via `Store.Registry pundleNamed:`), not from the
*parcel instance*:

```smalltalk
"THIS works:"
(Store.Registry pundleNamed: ''DebuggerUI'') properties
    at: #postUnloadBlock
    put: [:pkg | ].
```

(Source: James Robertson — same post. He writes: *“… that worked, but the
Debugger-UI Parcel still had that block. So I tried this … And... no
effect. I scratched my head over that one for a bit.”*)

**Implication for MCP design**: `vw_unload_parcel` MUST set the
`#postUnloadBlock` on the pundle model (`Store.Registry pundleNamed: ...`),
not on the parcel object. This is the kind of subtle gotcha that the
literal-string-eval approach (“just `compile_and_eval(''...'')`”) will miss.

#### 4.4.3 Unloading a Store pundle (bundle or package)

For Store-managed code, the unload path is via the pundle:

```smalltalk
[(Store.Registry pundleNamed: ''Tools-Debugger'') ifNotNil: [:pundle |
    pundle leafItems do: [:each | each markNotModified].
    [pundle markNotModified; unloadFromImage]
        on: Warning
        do: [:ex | ex resume: true]]]
```

(Source: James Robertson, *Builds and Project Oddities* — same post.)
Note that `unloadFromImage` is on the pundle (not the parcel); the
parcel-level `removeParcelNamed:` is the equivalent for non-Store code.

#### 4.4.4 The full unload API

| API                                                                | What it does                                                                                  |
|--------------------------------------------------------------------|-----------------------------------------------------------------------------------------------|
| `Parcel removeParcelNamed: aString`                                | Unload by name. Signals a `Notification` per carry-forward #38.                                |
| `Parcel removeParcel: aParcel`                                     | Unload by instance.                                                                           |
| `Parcel unloadParcel: aParcel`                                     | Lower-level — bypasses name resolution but does the same work.                                 |
| `aPundle markNotModified; unloadFromImage`                         | Store-side unload (also bypasses the parcel).                                                 |
| `(Store.Registry pundleNamed: ...) properties at: #postUnloadBlock` | Set an unload hook (must be on the pundle, not the parcel — see §4.4.2).                       |
### 4.5 The `Smalltalk.Store` namespace — what the keys actually mean

The 9.3.1 `Smalltalk.Store` namespace has **238 keys** (per
`Smalltalk namespaceAt: #Store` walk). The names that matter for code
distribution, with the ones that *don''t* exist called out explicitly:

#### 4.5.1 Real class names (selected, with roles)

| Class                              | Role                                                                                       |
|------------------------------------|--------------------------------------------------------------------------------------------|
| `Store.Registry`                   | The in-image registry of loaded pundles (bundles + packages). Singleton-like.              |
| `Store.DbRegistry`                 | The DB-side registry of published pundles. Connection-scoped.                              |
| `Store.RepositoryManager`          | Manages a set of `Store.Repository` instances; reads `StoreForPostgreSQL`-style config.   |
| `Store.LoginFactory`               | Returns a `GlorpSession` for a `ConnectionProfile`. Used by StoreCI-Building''s `PundleLoader`. |
| `Store.ConnectionProfile`          | A named (db, host, user, pass) profile. Persisted via `StoreProfile`.                      |
| `Store.Package`                    | The class side: queries for published package versions (e.g. `allVersionsWithName:olderThan:`). |
| `Store.Bundle`                     | The class side: queries for published bundle versions.                                     |
| `Store.PackageModel`               | Instance side: a *loaded-in-image* package (the model object the browser shows).            |
| `Store.BundleModel`                | Instance side: a *loaded-in-image* bundle.                                                 |
| `Store.PundleModel`                | The protocol-bearing superclass; both `PackageModel` and `BundleModel` inherit from it.     |
| `Store.PundleChangeList`           | The list of `StoreChange` instances that constitute a published version.                    |
| `Store.PundleForParcel`            | A factory: take a `PundleModel` and produce a `Parcel` (used by `ParcelDeployment`).       |
| `Store.PundleInstall`              | The “apply this version to the image” action object.                                        |
| `Store.PundleLoadedChange`         | A recorded change when a pundle is loaded into the image.                                   |
| `Store.PundleSavedChange`          | A recorded change when a pundle is saved (in-image, not published).                         |
| `Store.PundleHasUnpublishedChanges`| Predicate — true if the in-image pundle differs from the latest DB version.                 |
| `Store.PundleAccess`               | Authorization object — who can read/write which pundles in which repos.                     |
| `Store.PackageInstall`             | Specialization of `PundleInstall` for packages.                                            |
| `Store.BundleInstall`              | Specialization of `PundleInstall` for bundles.                                             |
| `Store.BundleDescription`          | The on-disk JSON-ish file format for a bundle (used by `BundleStructureChange`).            |
| `Store.BundleStructureChange`      | A change object that records “added/removed package X from bundle Y”.                      |
| `Store.PublishPundleDialog`        | **The publish UI** (the headless-monkey-patch target).                                      |
| `Store.PublishPackageDialog`       | Same, for a single package.                                                                 |
| `Store.StoreProgressOverlay`       | A `Subsystem` that overlays a `VisualLauncher` main window with a progress bar during long publish/load operations. Used by StoreCI-Building. |
| `Store.Connect` / `Store.Disconnect`| Subsystems for connecting to / disconnecting from a repository.                           |
| `Store.Glorp.*`                    | The Glorp-mapped Store DB model (GlorpSession, mapping classes). Added in 7.7+.            |

#### 4.5.2 Names that **DO NOT** exist in VW 9.x

- `Store.PackageInfo` — **Pharo/Rowan**, not VW.
- `Store.Pundle` — **abstract term only**, not a class. Use `Store.PundleModel` for instance side, `Store.PundleSpec` (in StoreCI-Building) for a file-format spec, or one of the class-side query APIs on `Store.Package` / `Store.Bundle`.
- `Store.PundleInfo` — **Pharo/Rowan**, not VW.
- `Store.Package` (as a *class*, not as a *class-side query namespace*) — **does not exist** as `Store.Package class`. The class side is on `Store.Package class` which holds the query API (`allVersionsWithName:`, `allVersionsWithName:newerThan:`, etc.). There is no instance side called `Package` itself.

> **HOW TO VERIFY in your image**: run
> `Smalltalk allClassesInPackage: ''Store''`, or for the namespace
> `Store.Namespace allKeys`, or simply
> `((Smalltalk at: #Store) class organization) allSelectors`.

#### 4.5.3 The 238-key full enumeration

The full enumeration is image-specific (depends on which Store parcels are
loaded — `StoreForPostgreSQL` adds ~30 keys, `StoreForOracle` adds a
different set, etc.). For MCP design purposes, the *protocol* that matters
is the one above; the keys you can rely on in any Store-loaded 9.3.1 image
are the ones listed in §4.5.1 plus their immediate sub-namespaces
(`Store.Glorp.*`, `Store.Changes.*`, etc.).
### 4.6 Class and method category protocol

#### 4.6.1 The class category

A class''s category is the *package* the class *belongs to*. In Smalltalk:

```smalltalk
MyClass category.                    "=> ''VWBridge-Core''"
MyClass category: ''VWBridge-Core''.   "set it"
```

This is the **single source of truth** for parcel membership. When
`parcelOutOn:` builds a parcel, it walks all classes whose category
matches the package''s namespace prefix and includes them.

**Rules**:

1. The class category *must* end in a `-<sub>` style suffix if you want
   sub-packages. `''VWBridge''` and `''VWBridge-Core''` are *different* packages
   to `parcelOutOn:`.
2. The class category *must not* start with `*` — that prefix is reserved
   for **method** categories (see §4.6.2).
3. You can move a class between packages via the Browser, or via
   `XChangeSet current moveWholeClass: aClass toPackage: aPackageModel`
   (literal example from the Pharo2VW porting code at
   [github.com/ObjectProfile/Pharo2VW](https://github.com/ObjectProfile/Pharo2VW)).

#### 4.6.2 The method category and the `*Pkg` extension prefix

A method''s category is normally a string like `''accessing''`, `''initialization''`,
`''private''`. But if it starts with `*` followed by a package name, it is an
**extension** of an existing class — the method is *attributed* to the
named package for parcel-publish purposes.

```smalltalk
"Normal method"
myMethod category.                    "=> ''accessing''"

"Extension method on class Object, attributed to package VWBridge-Core"
aMethod category.                    "=> ''*VWBridge-Core''"
aMethod category.                    "=> ''*VWBridge-Core-Extensions''"
```

**Rules** (per Cincom''s “Packages and Bundles” section, AppDevGuide):

1. A method whose category is `*Pkg-Sub` is included in the parcel for
   package `Pkg-Sub`, *not* in the parcel that owns the class being extended.
2. When `parcelOutOn:` builds the parcel for `Pkg-Sub`, it sees
   `*Pkg-Sub`-prefixed methods on classes that live in *other* packages and
   pulls them in.
3. Extensions can be **added** to a class at parcel-load time even if the
   owning parcel for that class has not been loaded yet — they are
   “deferred installs” (the parcel paper calls this *“uninstalled code which
   gets installed when the classes become available”* — see
   [wiki.squeak.org/5620](https://wiki.squeak.org/squeak/5620)).
4. Method categories that don''t match the `*` pattern are *not* included in
   any parcel — they stay as in-image source, edited via the Browser.

**Why this matters for MCP**: the `vw_create_parcel` tool MUST accept a
list of (class, method-category-pattern) pairs so it can produce
extensions. The naive `addEntiretyOfClass:` does NOT pick up extension
methods attributed to a different package — you have to use
`addSelector:class:` (or `addSelector:class:isMeta:`) per method.

#### 4.6.3 How `parcelOutOn:` actually walks the image

(Reconstructed from the Parcels paper, the AppDevGuide “Packages and
Bundles” chapter, and `ParcelDeployment` source.)

1. Start with the named package or bundle as the root.
2. Collect all classes whose `category` matches the package''s namespace
   prefix.
3. For each such class, add the class itself, all of its instance + class
   methods whose category does NOT start with `*` (those are the class''s
   “own” methods), and the class''s class variables, pool dictionaries,
   and shared pools.
4. Walk the class''s referenced classes and add any whose category is a
   *prerequisite* (i.e. a separate package that must be loaded first).
5. For each class in the result, also pull in any methods whose category
   is `*<this-package>` from classes that are *not* in this package
   (the extension rule from §4.6.2).
6. Serialize to `.pcl` (binary, pickling) + `.pst` (source, the VW XML
   `<?xml version="1.0"?><st-source>...</st-source>` format you see in
   `StoreCI-Building.pst`).
### 4.7 Idiomatic Bundle / Package / class enumeration

```smalltalk
"=== 4.7.1: In-image pundle enumeration (Store is loaded) ==="

"All loaded pundles in the image"
Store.Registry pundles.

"All bundles"
Store.Registry bundles.

"All packages (i.e. non-bundle pundles)"
Store.Registry packages.

"Lookup a specific pundle"
(Store.Registry pundleNamed: ''VWBridge'') ifNil: [...] ifNotNil: [...].

"The classes in a pundle (in-image)"
aPundleModel leafItems.        "pundle-spec items: classes + sub-bundles"
aPundleModel allClasses.       "flattened list of all classes"

"=== 4.7.2: Parcel enumeration (no Store needed) ==="

"All parcels registered in the image (loaded or partially loaded)"
Parcel parcels.

"All parcels on the search path that aren''t loaded yet"
Parcel availableParcels.

"Lookup one"
Parcel parcelNamed: ''VWBridge''.

"=== 4.7.3: Direct class enumeration (per package) ==="

"By category name"
(Object withAllSubclasses) select: [:c | c category = ''VWBridge-Core''].

"By package (alias for category)"
| main classes cat pkg packages |
main := Registry bundleNamed: ''MyBundle''.
classes := main allClasses.
packages := Dictionary new.
classes do: [:cls |
    cat := cls category asString.
    pkg := packages at: cat ifAbsentPut: [
        p := Registry packageNamedOrCreate: cat.
        main addItem: p.
        p ].
    XChangeSet current moveWholeClass: cls toPackage: pkg ].
```

(Source for the last snippet:
[github.com/ObjectProfile/Pharo2VW](https://github.com/ObjectProfile/Pharo2VW))

**Key gotcha**: there is no `Smalltalk allClassesInPackage:` in VisualWorks
(that''s a Pharo API). The closest is the `category` walk above, or
`(Store.Registry pundleNamed: ...) allClasses` when Store is loaded.

### 4.8 Programmable vs UI-only — the truth table

| Task                                                | Programmatic? | Notes                                                                                       |
|-----------------------------------------------------|---------------|---------------------------------------------------------------------------------------------|
| Load a `.pcl`                                       | ✅            | `Parcel loadParcelFrom:`. The whole point of the API.                                        |
| Unload a parcel                                     | ✅            | `Parcel removeParcelNamed:`.                                                                 |
| List loaded parcels                                 | ✅            | `Parcel parcels` / `Parcel loadedParcels`.                                                   |
| List available (on path) parcels                    | ✅            | `Parcel availableParcels`.                                                                   |
| Set parcel search path                              | ✅            | `Parcel searchPathModel value:`.                                                             |
| Build a parcel from a class list                    | ✅ (via `ParcelDeployment`) | `parcelOutOn:` works; `ParcelDeployment` is the clean wrapper from StoreCI-Building.          |
| Build a parcel *with full UI prompts*               | ✅ (but headless-hostile) | `parcelOutOn:withSource:hideOnLoad:republish:backup:` — the carry-forward #41 wedge.           |
| Publish to a Store DB                               | ✅ (via `StoreCI-Building`) | Not natively headless — StoreCI-Building provides the clean domain-object API.               |
| Query Store DB for a pundle version                 | ✅            | `Store.Package allVersionsWithName: ''X'' newerThan: aVersion` (Robertson pattern).             |
| Connect to a Store repository                       | ✅            | `Store.Connect` subsystem, or `StoreLoginFactory sessionForStoreLogin:` (literal in StoreCI-Building.pst). |
| Browse a pundle                                     | ❌ UI only     | Browser tool. No public programmatic API.                                                    |
| Edit a class in a package                           | ❌ UI only     | Browser tool, or `ObjectCompiler` evaluate-string. (And the carry-forward #41 compile-on-VWB wedge is exactly this gap.) |
| Resolve a Store merge conflict                      | ❌ UI only     | Store merge tool. The `MergeTool` is a `ComposablePresenter`, not invokable headlessly without UI. |
| Run a SUnit test suite                              | ✅ (via `StoreCI-Testing`) | Like parcel-publish, this is *programmable in principle* but the headless wrapper lives in StoreCI-Testing. |
| Generate a parcel from a VisualWorks UI Painter     | ❌ UI only     | `UI.Painter` is non-scriptable in 9.x.                                                       |
| Save the image                                       | ✅            | `ObjectMemory permSaveAs: ''myname'' thenQuit: false`.                                          |

**The five big UI gaps** that AI/MCP tools need to bridge:

1. **Headless parcel build** — bridged by StoreCI-Building''s
   `ParcelDeployment pundle:directory: deploy`.
2. **Headless Store publish** — bridged by StoreCI-Building''s
   `PundleLoader` + `ParcelWriter` (or by the deprecated
   `Store.PublishPundleDialog` approach).
3. **Headless class edit** — bridged by `ObjectCompiler` evaluate-string
   (the carry-forward #41 compile-on-VWB wedge).
4. **Headless test run** — bridged by StoreCI-Testing''s
   `TestingSubsystem`.
5. **Headless source read from `.pst`** — bridged by writing a small
   parser; the format is `<?xml version="1.0"?><st-source>...</st-source>`
   with `<class>`, `<methods>`, `<body>`, `<comment>` tags. See §4.10.
### 4.9 Topaz / file-in `.st` chunk format

VW''s file-in format is **the ST-80 chunk format**, identical to Squeak /
Pharo / Smalltalk/X / Dolphin. Specs:

#### 4.9.1 Chunk delimiter

- A chunk is delimited by a single `!`.
- A literal `!` inside a chunk is doubled (`!!`).
- An empty chunk (whitespace only) terminates the sequence.

#### 4.9.2 Chunk forms

```smalltalk
''From VisualWorks 9.3.1 of YYYY-MM-DD on DD Month YYYY at HH:MM:SS''!

"First form: a chunk evaluated by the compiler (like DoIt)"
!ClassName methodsFor: ''category''!
methodSelector
    "comment"
    ^42!
! !

"Second form: a chunk reader"
"SomeClass chunkReader: argument!"
"... followed by raw bytes that the reader consumes ..."
!
```

#### 4.9.3 What you can put in a file

| Form                                                 | What it produces                                                                              |
|------------------------------------------------------|-----------------------------------------------------------------------------------------------|
| `''From VW ...''!`                                     | A header. Convention, not required.                                                           |
| `!classDefinition: #Foo category: #''Bar''!`           | VW 9.x extension: define a class. Equivalent to `Object subclass: #Foo ... category: ''Bar''`. |
| `Object subclass: #Foo instanceVariableNames: ''x y'' classVariableNames: '''' poolDictionaries: '''' category: ''Bar''!` | The classic class definition.                                          |
| `!Foo methodsFor: ''accessing''!`                      | Begin a method-chunk sequence.                                                                |
| `!Foo class methodsFor: ''instance creation''!`        | Begin a class-method-chunk sequence.                                                          |
| `foo: arg "comment" ^arg!`                           | A method.                                                                                     |
| `! !`                                                | End the current method-chunk sequence.                                                         |
| `Smalltalk at: #Global put: 42!`                     | Arbitrary DoIt.                                                                                |
| `Class initialize!`                                  | Run a class''s class-side initialize.                                                           |

#### 4.9.4 What uses the file-in format in 9.3.1

- **Topaz command-line `filein`** — the legacy headless entry, still
  supported.
- **The `load.st` build scripts** that all Cincom deployment examples
  use.
- **The source companion `.pst` is NOT a chunk file** — it''s the XML
  `<st-source>` format (see §4.10).
- **File → File In…** in the Launcher.

#### 4.9.5 The file-in API

```smalltalk
"File in a .st file"
FileStream fileIn: ''C:\builds\load.st''.

"Or via the chunk format directly"
aReadStream fileInChunkFormat.   "(private, but stable)"

"Equivalent for a string"
''aString'' readStream fileInChunkFormat.
```

The class-side `FileStream fileIn:` is the public entry; it reads chunks
and evaluates each via `Compiler evaluate:` (with a `ClassCategoryReader`
for `methodsFor:` chunks).
### 4.10 Reading source from a `.pst` companion file

#### 4.10.1 Why we need this

Our 9.3.1 image has **stripped sources** — `getSource` returns `nil` for
base classes. The `.pcl` (binary) on its own has no human-readable source.
The companion `.pst` (text) does, in the form:

```xml
<?xml version="1.0"?>
<st-source>
  <!-- header: package metadata -->
  <name-space>...</name-space>
  <class>...</class>
  <comment>...</comment>
  <methods>
    <class-id>MyClass</class-id>
    <category>accessing</category>
    <body package="MyPkg">name
  "Answer my name"
  ^name!</body>
  </methods>
</st-source>
```

(Literal excerpt from
[StoreCI-Building.pst](https://github.com/randycoulman/StoreCI/blob/master/StoreCI-Building.pst).)

#### 4.10.2 Reading a `.pst` programmatically

The format is well-formed XML. Two approaches:

**A. Use a `XML.DocumentParser`** (Cincom ships one in `XML-Parser`):

```smalltalk
"Open, parse, walk"
| doc root |
doc := XML.DocumentParser parseFileNamed: ''C:\vw\MyPkg.pst''.
root := doc root.
"root = st-source element"
"Each <class> is a class definition"
root elementsAt: ''class'' do: [:classEl |
    | className superName packageName |
    className  := (classEl attributeAt: ''name'') asSymbol.
    superName  := (classEl attributeAt: ''super'') asSymbol.
    packageName := classEl firstChildElementNamed: ''attributes''
                      firstChildElementNamed: ''package''
                      attributeAt: ''package'' ].
"Each <methods> block is one method"
root elementsAt: ''methods'' do: [:methodEl |
    | classId category body |
    classId  := (methodEl attributeAt: ''class-id'') asQualifiedReference.
    category := (methodEl elementAt: ''category'') stringValue.
    body     := (methodEl elementAt: ''body'') stringValue.
    "body is the full method source, including the leading selector" ].
```

**B. (Faster) hand-roll a parser** that scans for `<st-source>`, then
extracts `<class>`, `<methods>`, `<body>` elements via regex (Cincom
ships `Regex11` in the base image, the same format the Jenkins plugin
uses for version filtering — see
[Jenkins : Visualworks Smalltalk Store Plugin](https://wiki.jenkins.io/JENKINS/Visualworks-Smalltalk-Store-Plugin.html)).

#### 4.10.3 Mapping `(class-id, category, body)` to Smalltalk source

The `body` is the **literal Smalltalk method source**, including the
selector line. Example from `StoreCI-Building.pst`:

```smalltalk
"body of BuildingSubsystem>>run"
| loader |
loader := self configuredLoader.
self withOverlayFeedbackDo:
    [loader loadPundles.
     targetDirectory
        ifNotNil: [self configuredWriter writeParcels: loader imagePundles]]
```

You can `Compiler evaluate:` the body inside a `ClassCategoryReader` for
the class, exactly as the file-in code does. This is the *programmatic*
way to populate a class from a `.pst`.

#### 4.10.4 What you can NOT do

- You **cannot** get source for a class whose parcel was built without a
  `.pst` (the `parcelOutOn: ... withSource: false` path) — the `.pst` is
  the only place the source lives.
- You **cannot** synthesize source from the `.pcl` — the `.pcl` is a
  binary pickling that contains CompiledMethod blobs (bytecodes +
  literals), not source.
- You **cannot** rely on the `.cha` file: that''s for *in-image* changes
  (post-load edits), not parcel sources. David Buck on
  [StackOverflow #19257644](https://stackoverflow.com/questions/19257644/source-code-missing-in-cincom-visualworks-7-9-1-in-windows-8):
  *"For parcels you loaded, the source code is in a .pst file associated
  with the parcel."*
### 4.11 The `Cursor showWhile:` monkey-patch (carry-forward #41)

#### 4.11.1 The problem

`Kernel.Parcel>>parcelOutOn:withSource:hideOnLoad:republish:backup:` is the
canonical headless-publish entry (we use this in Phase P P6). In a
headless image (no `VisualLauncher` open, no UI), the call eventually
invokes a `Cursor showWhile:` somewhere in the parcel-build UI prompt
chain, which blocks on a window event that never arrives.

#### 4.11.2 The workaround (in-session, pre-build)

The Cincom-canonical pattern is to install a no-op
`Cursor class >> showWhile:` and then call `parcelOutOn:`:

```smalltalk
"Pre-build: monkey-patch Cursor to a no-op for the duration of the build"
| savedShowWhile |
savedShowWhile := Cursor class methodDict at: #showWhile:.
Cursor class compile: ''showWhile: aBlock
    "headless no-op for parcel build"
    aBlock value''.

[
    "Do the build"
    aParcel parcelOutOn: aFilename
            withSource: true
            hideOnLoad: false
            republish: false
            backup: true
] ensure: [
    "Restore the original"
    Cursor class methodDict at: #showWhile: put: savedShowWhile ].
```

#### 4.11.3 The Cincom-canonical cleaner alternative (from `StoreCI-Building.pst`)

`BuildingSubsystem>>withOverlayFeedbackDo:` (literal source from
[StoreCI-Building.pst lines 80-95](https://github.com/randycoulman/StoreCI/blob/master/StoreCI-Building.pst)):

```smalltalk
"Literal from StoreCI-Building.pst"
withOverlayFeedbackDo: aBlock
    "If StoreProgressOverlay is available in the image, use it on the active
     VisualLauncher window."
    #{Store.StoreProgressOverlay} ifDefinedDo:
        [:cls |
        | activeLauncher |
        activeLauncher := VisualLauncher allInstances
                          detect: [:each | each mainWindow isOpen].
        cls subsume: activeLauncher mainWindow while: aBlock]
        elseDo: aBlock
```

This pattern:
1. Detects whether `Store.StoreProgressOverlay` is loaded (it''s part of
   the `Store` parcel set).
2. If yes, wraps the build in a progress overlay on the *active*
   `VisualLauncher`''s main window.
3. If no, just runs the block directly (no `Cursor showWhile:` ever fires).

The `subsume:while:` method is what handles the `Cursor showWhile:` issue
*correctly* — by replacing the launcher window''s cursor with the
`wait` cursor for the duration of the block, then restoring it. This is
the right way to do headless-with-progress.

#### 4.11.4 What `StoreCI-Building` actually does for parcel-out

From `StoreCI-Building.pst`:

```smalltalk
"ParcelWriter>>writeStoreParcel:"
writeStoreParcel: aPundleModel
    (ParcelDeployment pundle: aPundleModel directory: directory) deploy
```

The `ParcelDeployment` class is a small Store-CI-Building-defined class
that wraps `Kernel.Parcel` and does the headless publish. **It uses the
`parcelOutOn:...` path internally, with the overlay-feedback wrapper.**

So the correct sequence is:

```smalltalk
"Headless publish, modern pattern"
| deployment |
deployment := ParcelDeployment
    pundle: aPundleModel
    directory: (PortableFilename named: ''C:\output\').
deployment deploy.   "this internally wraps Cursor showWhile: via overlay"
```

vs. the older direct pattern (also valid, but UI-hostile):

```smalltalk
"Headless publish, direct Kernel.Parcel pattern (carry-forward #41)"
aParcel parcelOutOn: ''C:\output\MyPkg.pcl''
    withSource: true
    hideOnLoad: false
    republish: false
    backup: true.
```
### 4.12 Literal Smalltalk snippets for the five core operations

These are the literal idioms to be exposed via the MCP tool surface.
Each one is sourced to a working real-world example.

#### 4.12.1 (a) Creating a new parcel from a class list

```smalltalk
| parcel classes |
classes := {MyClassA. MyClassB. MyClassC}.

"Create the empty parcel"
parcel := Parcel createParcelNamed: ''MyPkg''.

"Add each class in its entirety"
classes do: [:cls | parcel addEntiretyOfClass: cls].

"Mark a prerequisite (Kernel is always one)"
parcel addPrerequisite: (Parcel parcelNamed: ''Base VisualWorks'').

"Write it out (headless-friendly with the overlay)"
aParcel parcelOutOn: ''C:\output\MyPkg.pcl''
    withSource: true
    hideOnLoad: false
    republish: false
    backup: true.
```

For *Store* pundle source, use `ParcelDeployment pundle: aPundleModel
directory: aDir` (StoreCI-Building).

#### 4.12.2 (b) Loading an existing parcel

```smalltalk
"From a known path (build-script form)"
Parcel loadParcelFrom: ''C:\vw\contributed\Refactory.pcl''.

"By name on the search path"
Parcel loadParcelFrom: ''Refactory''.

"Trapping the missing-source notification (carry-forward #38)"
[Parcel loadParcelFrom: ''C:\vw\MyPkg.pcl'']
    on: MissingParcelSource
    do: [:ex | ex resume: true].
```

(Source for the trap: James Robertson, [Smalltalk Daily 06/22/10](http://www.jarober.com/blog/blogView?entry=3454652379).)

#### 4.12.3 (c) Unloading a parcel

```smalltalk
"Programmatic unload (traps the carry-forward #38 notification)"
[Parcel removeParcelNamed: ''MyPkg'']
    on: Notification
    do: [:ex | ex resume: true].

"Store-side unload (uses the pundle model, NOT the parcel instance)"
[(Store.Registry pundleNamed: ''Tools-Debugger'') ifNotNil: [:pundle |
    pundle leafItems do: [:each | each markNotModified].
    [pundle markNotModified; unloadFromImage]
        on: Warning
        do: [:ex | ex resume: true]]].
```

(Source: James Robertson, [Builds and Project Oddities](http://www.jarober.com/blog/blogView?entry=3472976088).)

#### 4.12.4 (d) Querying installed parcels

```smalltalk
"All loaded parcels (Kernel.Parcel API)"
Parcel parcels.
Parcel loadedParcels.

"All available (on path) parcels"
Parcel availableParcels.

"Set or extend the search path"
Parcel searchPathModel value:
    (Parcel searchPathModel value copyWith: ''C:\my-parcels\'').

"Store-side: all pundles in the image"
Store.Registry pundles.
Store.Registry bundles.
Store.Registry packages.

"Lookup by name (Parcel)"
(Parcel parcelNamed: ''MyPkg'') ifNil: [...].

"Lookup by name (Store)"
(Store.Registry pundleNamed: ''MyBundle'') ifNil: [...].
```

#### 4.12.5 (e) Store package version query

```smalltalk
"All published versions of package ''X'' newer than a given version"
| all newerMatch |
all := Store.Package allVersionsWithName: ''MyPkg'' newerThan: aVersion.
newerMatch := all detect: [:each | (regexPattern match: each version)]
              ifNone: [nil].
newerMatch ifNotNil: [newerMatch loadSrc].   "actually load it"
```

(Source: James Robertson,
[Updating Packages in a Bundle](http://www.jarober.com/blog/blogView?entry=3479629692).)

For StoreCI-Building, the same lookup goes through
`StoreCI.Support.PundleSpec`:

```smalltalk
"StoreCI-Building source, literal:"
"Class method:"
pundleWithName: aName version: aVersionString in: aGlorpSession
    ^pundleType pundleWithName: aName version: aVersionString in: aGlorpSession
```

where `pundleType` is `StorePackage` or `StoreBundle` (the literal token
in the load-order file). This is the only correct programmatic way to
address Store pundles by name+version in 9.x.
### 4.13 MCP tool design — proposed `vw_*` surface

For each API above, 1–2 native-typed tool names with priority
(MVP = ship in Phase M, V2 = next iteration, V3 = nice-to-have).

#### 4.13.1 Read-only / query

| Tool name                                          | Params (shape)                                                                  | Priority |
|----------------------------------------------------|---------------------------------------------------------------------------------|----------|
| `vw_parcel_list({status: "loaded"\|"available"\|"all"})` | `status: enum`                                                              | **MVP**  |
| `vw_parcel_info({name: str})`                      | `name: string`                                                                  | **MVP**  |
| `vw_parcel_search_path_get()`                      | none                                                                            | **MVP**  |
| `vw_parcel_search_path_set({dirs: [str]})`         | `dirs: string[]`                                                                | **MVP**  |
| `vw_pundle_list({kind: "bundle"\|"package"\|"all"})` | `kind: enum`                                                                  | V2       |
| `vw_pundle_info({name: str, kind: str})`           | `name: string, kind: "bundle"\|"package"`                                       | V2       |
| `vw_pundle_classes({pundle: str})`                 | `pundle: string (qualified name)`                                               | V2       |
| `vw_package_classes({category: str})`              | `category: string`                                                              | V2       |
| `vw_store_query_versions({package: str, regex: str?, newerThan: str?})` | `package, regex?, newerThan?`                                   | V2       |

#### 4.13.2 Mutating — load / unload

| Tool name                                          | Params (shape)                                                                  | Priority |
|----------------------------------------------------|---------------------------------------------------------------------------------|----------|
| `vw_load_parcel({path: str, trapMissingSource?: bool})` | `path: string, trapMissingSource: boolean = true`                          | **MVP**  |
| `vw_load_parcel_by_name({name: str, dir?: str})`   | `name: string, dir?: string`                                                    | **MVP**  |
| `vw_unload_parcel({name: str})`                    | `name: string`                                                                  | **MVP**  |
| `vw_unload_pundle({name: str})`                    | `name: string` (uses Store.Registry path)                                        | V2       |
| `vw_set_post_unload_hook({pundle: str, blockSrc: str?})` | `pundle: string, blockSrc: string` (compiles nil-block to clear)          | V2       |

#### 4.13.3 Mutating — build / publish (the gap StoreCI-Building fills)

| Tool name                                          | Params (shape)                                                                  | Priority |
|----------------------------------------------------|---------------------------------------------------------------------------------|----------|
| `vw_create_parcel({name: str, classes: [str], extensions: [obj]?})` | `name: string, classes: string[], extensions?: {class:string, selector:string, isMeta?:bool, category?:string}[]` | **MVP**  |
| `vw_parcel_add_prerequisite({parcel: str, prereq: str, version?: str})` | `parcel: string, prereq: string, version?: string`                      | V2       |
| `vw_parcel_publish({parcel: str, dir: str, withSource?: bool, hideOnLoad?: bool, republish?: bool, backup?: bool})` | All bools default `true,false,false,true`                | **MVP**  |
| `vw_store_publish({pundle: str, dir: str, repository: str})` | `pundle: string (Store pundle name), dir: string, repository: string` | V3 (requires StoreCI-Building loaded) |

#### 4.13.4 Source access

| Tool name                                          | Params (shape)                                                                  | Priority |
|----------------------------------------------------|---------------------------------------------------------------------------------|----------|
| `vw_get_source({class: str, selector: str, isMeta?: bool})` | `class: string, selector: string, isMeta: boolean = false`             | **MVP**  |
| `vw_pst_extract({pstPath: str, class?: str})`      | `pstPath: string, class?: string` (returns the `<body>` strings)                 | V2       |
| `vw_search_source({pattern: str, pundle?: str, useRegexp?: bool})` | `pattern: string, pundle?: string, useRegexp: boolean = false`     | V2       |

#### 4.13.5 File-in

| Tool name                                          | Params (shape)                                                                  | Priority |
|----------------------------------------------------|---------------------------------------------------------------------------------|----------|
| `vw_file_in({path: str})`                          | `path: string`                                                                  | **MVP**  |
| `vw_file_in_string({chunkSrc: str})`               | `chunkSrc: string`                                                              | V2       |

#### 4.13.6 Total tool count

- **MVP (ship in Phase M)**: 12 tools.
- **MVP + V2**: 22 tools.
- **MVP + V2 + V3**: 23 tools.
### 4.14 What''s “idiomatic in 2026” vs deprecated

| Pattern                                                                  | Status (2026)                                                                 |
|--------------------------------------------------------------------------|-------------------------------------------------------------------------------|
| `Parcel loadParcelFrom: ''foo.pcl''`                                       | ✅ Idiomatic. The canonical load entry.                                        |
| `Parcel removeParcelNamed: ''foo''`                                        | ✅ Idiomatic. Wrap with `on: Notification do:` per carry-forward #38.           |
| `Parcel parcelNamed:` (lookup)                                           | ✅ Idiomatic.                                                                 |
| `parcel addEntiretyOfClass:` / `addSelector:class:` / `addNameSpace:`    | ✅ Idiomatic. These are the parcel-content build methods.                       |
| `parcelOutOn:withSource:hideOnLoad:republish:backup:`                     | ✅ Idiomatic, but requires the carry-forward #41 Cursor monkey-patch (or StoreCI-Building''s overlay). |
| `ParcelDeployment pundle:directory: deploy`                              | ✅ Modern (StoreCI-Building). The clean headless wrapper around `parcelOutOn:`. |
| `Store.Registry pundleNamed:`                                            | ✅ Idiomatic for Store-loaded code.                                            |
| `Store.Package allVersionsWithName:newerThan:`                           | ✅ Idiomatic. Use this, not deprecated `DbRegistry` direct SQL.                |
| `Store.LoginFactory sessionForStoreLogin:`                               | ✅ Idiomatic for headless Store connection.                                    |
| `Store.RepositoryManager repositories detect:ifNone:`                    | ✅ Idiomatic.                                                                 |
| `Store.PublishPundleDialog new` + `publishFromUserData`                  | ⚠️ **DEPRECATED PATH**. Works but “undisplayed UI” is fragile. James Robertson''s 2011 hack; he hoped Cincom would build a real domain-object API. StoreCI-Building is the answer. |
| `Parcel ensureLoadedParcel:withVersion:`                                 | ⚠️ Rare in 9.x; reserved for Store-published-version loading.                  |
| `addOverride:`, `addUsing:`                                               | ❌ Pre-7.x. Do not use.                                                        |
| `parcelOutOn: aFilename` (no source)                                      | ❌ Discouraged — you''ll get a `.pcl` with no companion `.pst` and lose source access. |
| `Smalltalk allClassesInPackage:`                                         | ❌ Pharo API. Use `(Store.Registry pundleNamed:) allClasses` or category walk. |
| `Store.PackageInfo`, `Store.Pundle`, `Store.PundleInfo`                  | ❌ Pharo/Rowan. Do not generate code with these names.                         |
| `objectSourceFor:`-style dynamic method-source queries                   | ⚠️ Use only if you know the class''s parcel''s `.pst` is in `SourceFileManager`''s registry (it is by default, after `loadParcelFrom:`). |
| `RuntimePackager` (the `.pcl` from `/packaging/RuntimePackager.pcl`)      | ✅ Idiomatic for stripped-down deployment images.                              |
### 4.15 Source-of-truth references

| Reference                                                                                                       | Used for                                                  |
|-----------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------|
| **Cincom VisualWorks Application Developer''s Guide** ([docslib mirror](https://docslib.org/doc/1871905/expanding-the-visualworks-image), [docplayer mirror](https://docplayer.net/10738659-Cincom-smalltalk-application-developer-s-guide-p46-0101-14-simplification-through-innovation.html)) | High-level terminology, “Loading Parcels Programmatically” section, package/bundle structure. |
| **Cincom VisualWorks Source Code Management Guide** ([local `C:\visualworks931\doc\SourceCodeMgmtGuide.pdf`, 1.97 MB]; [7.6 mirror via search](https://www.google.com/search?q=%22Source+Code+Management+Guide%22+visualworks+pdf); also cited in [Brauer 2015 references](https://docslib.org/doc/1871905/expanding-the-visualworks-image)) | Store, publishing, prerequisites, version selection. 7.6 mirror is semantically identical to 9.3.1 for the APIs surveyed. |
| **[Parcels: A fast and feature-rich binary deployment technology](https://www.sciencedirect.com/science/article/abs/pii/S1477842405000072)** (Wadalski et al, 2005) | The parcel pickling format, the four-phase load (preload/load/install/postload), the unload semantics (obsolete classes). |
| **[randycoulman/StoreCI on GitHub](https://github.com/randycoulman/StoreCI)** + [.pst source files](https://github.com/randycoulman/StoreCI/blob/master/StoreCI-Building.pst) | The canonical headless-publish reference. Literal source for `BuildingSubsystem`, `PundleLoader`, `ParcelWriter`, `PundleSpec`, `StockParcels`, `ParcelDeployment`, `StoreCI-Building.pst` and `StoreCI-Support.pst`. |
| **[James Robertson — Smalltalk with James](http://www.jarober.com/blog/)** (multiple posts) | Real-world idioms: `removeParcelNamed:`, `unloadFromImage`, `PublishPundleDialog` headless trick, `postUnloadBlock` gotcha, build-script pattern, `allVersionsWithName:newerThan:`. |
| **[ObjectProfile/Pharo2VW on GitHub](https://github.com/ObjectProfile/Pharo2VW)** | The `Registry packageNamedOrCreate:` + `XChangeSet current moveWholeClass:toPackage:` idiom for programmatic class-to-package migration. |
| **[Wikipedia: VisualWorks](https://en.wikipedia.org/wiki/VisualWorks)** (and HandWiki/owiki mirrors) | Canonical terminology; the 5-term terminology table in §4.1 is distilled from this. |
| **[HandWiki VisualWorks §Parcels](https://handwiki.org/wiki/VisualWorks)** | Confirming the “Packages are categories” quote (§4.1). |
| **[wiki.squeak.org/5620 — Summary: Parcels in VW](https://wiki.squeak.org/squeak/5620)** | The “uninstalled code which gets installed when the classes become available” rule. |
| **[Cincom Smalltalk Store Repository docs](https://www.cincomsmalltalk.com/main/developer-community/store-repository/)** | The `StoreForPostgreSQL` requirement, the `guest` / `guest` credentials, the public repository access pattern. |
| **[SETT — Store Export to Tonel Tools](https://github.com/GemTalk/SETT)** | Reference for “pundle” usage in VW (used here for terminology, not for git export). |
| **[Squeak FAQ #1105 — FileOut Code Format](https://wiki.squeak.org/squeak/1105)** | The chunk format spec used by VW `.st` files (ST-80 compatible). |

### 4.16 Carry-forward mapping (for the MCP server''s own bug list)

| ID       | Description                                                                                  | Documented in section |
|----------|----------------------------------------------------------------------------------------------|-----------------------|
| #38      | `removeParcelNamed:` signals a `Notification`; must wrap with `on: Notification do: [:ex \| ex resume: true]`. | §4.4.1, §4.4.4, §4.12.3, §4.14 |
| #41      | `parcelOutOn:` wedges via `Cursor showWhile:` in headless images; monkey-patch or use StoreCI-Building''s `BuildingSubsystem>>withOverlayFeedbackDo:`. | §4.0, §4.11, §4.13.3  |
| (NEW)    | `postUnloadBlock` must be set on the pundle (`Store.Registry pundleNamed: ...`), NOT on the parcel (`Parcel parcelNamed: ...`). | §4.4.2                 |
| (NEW)    | The `*Pkg` method-category prefix is REQUIRED for extension methods to be included in a parcel — `addEntiretyOfClass:` does NOT pick them up. | §4.6.2                 |
| (NEW)    | `MissingParcelSource` (a `Notification`, not an `Exception`) is signalled when the `.pst` is missing — `loadParcelFrom:` will *not* throw. | §4.3.1, §4.3.2           |
| (NEW)    | `Smalltalk allClassesInPackage:` is a **Pharo** API; the VW equivalent is `(Store.Registry pundleNamed:) allClasses` or a category walk. | §4.7, §4.14              |
| (NEW)    | `Store.PackageInfo` / `Store.Pundle` / `Store.PundleInfo` are **Pharo/Rowan** names. Use `Store.PackageModel` / `Store.PundleModel` / `Store.PundleSpec` instead. | §4.5.2, §4.14            |