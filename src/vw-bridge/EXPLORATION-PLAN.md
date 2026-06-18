# Exploration Plan — Post-Phase B

**Written:** end of session 2026-06-18, after Phase B v0.8.1 proved menu-based navigation works end-to-end on MAS.
**Prerequisites:** bridge filed in (see [`SESSION-RESUME.md`](./SESSION-RESUME.md) "FIRST ACTION on resume") and MAS launcher open (window title contains `MOMENTUM`).

---

## State going in

- `/menu/click ["Party & Contract","Client & Contract search"]` is proven; opens a `PartySearchView` "Party Search" window each time.
- TWO `Party Search` windows may currently be open in MAS from prior session test clicks — fine for inspection, dismiss via the MAS UI before fill+search if you want a clean baseline.
- `/menu/click` returns `windows.opened` / `windows.closed` inline; no need to poll `/windows` separately after a click.

For every step below, set:

```powershell
$tok = "<paste-from-Transcript>"
$h = @{"Authorization" = "Bearer $tok"}
```

---

## Step 1 — Inspect Party Search widget surface (read-only, ~5 min)

**Goal:** discover input fields, list widgets, and the search button inside Party Search so the subsequent fill+search step knows what aspects to address.

**Run:**

```powershell
$tree = (Invoke-WebRequest -Uri http://127.0.0.1:9876/windows/tree -Headers $h -UseBasicParsing).Content | ConvertFrom-Json
$pty = $tree | Where-Object { $_.appClass -eq 'PartySearchView' } | Select-Object -First 1
"widgets: $($pty.widgets.Count)"
$pty.widgets | ForEach-Object { "{0,-30}  {1,-25}  {2}" -f $_.aspect, $_.specClass, $_.label }
```

**Expected outcome:**

- A list of named components in `PartySearchView`'s top-level `namedComponents` dictionary.
- Likely includes `InputFieldSpec` entries (search fields), an `ActionButtonSpec` (the Search/Find button), maybe a `SequenceViewSpec` or `SubCanvasSpec` for the results list.
- Note the aspect names of at least one input field and the search button — feed those into Step 2.

**Possible gotcha — SubCanvas nesting:** If `widgets` is empty or returns only a `SubCanvasSpec`, Party Search probably uses the same nested-canvas pattern MasLauncher does. In that case the bridge can't reach the inner widgets via `/value` / `/click` / `/type` without a recursive aspect resolver. Workaround: run a one-off probe (see `probes/mas_subcanvas_probe.st` and `probes/mas_widget_tree_probe.st` for templates) to enumerate the nesting and figure out what aspects live where. Phase B+1 candidate: add SubCanvas recursion to `resolveAspect:inWindowMatching:`.

---

## Step 2 — End-to-end fill + search (GATED — ASK BEFORE FIRING)

**Goal:** prove the bridge can drive a real domain window end-to-end: fill a search field, click the search button, observe the result (results list populating, or a new window opening, or a "no results" dialog).

**SAFETY:** This may trigger a real database query against the GS test stone. Confirm with the user:

1. What test name / ID is safe to search for (the user knows what's in their test data).
2. Whether they want to dismiss the existing Party Search windows first.

**Do NOT enter random data** — use a name the user vouches for, ideally one that returns predictable results.

**Run (template — substitute the aspect names from Step 1 and the test value):**

```powershell
# Fill the search field
$body = @{aspect="<INPUT_ASPECT>"; windowTitle="Party Search"; value="<TEST_NAME>"} | ConvertTo-Json -Compress
Invoke-RestMethod -Uri http://127.0.0.1:9876/type -Method POST -Headers $h -Body $body -ContentType 'application/json'

# Read it back to confirm the type took
Invoke-RestMethod -Uri "http://127.0.0.1:9876/value?aspect=<INPUT_ASPECT>&windowTitle=Party Search" -Headers $h

# Click the search button
$body = @{aspect="<BUTTON_ASPECT>"; windowTitle="Party Search"} | ConvertTo-Json -Compress
Invoke-RestMethod -Uri http://127.0.0.1:9876/click -Method POST -Headers $h -Body $body -ContentType 'application/json'

# Check what windows are around now (since /click does not currently report windows.opened)
Invoke-RestMethod -Uri http://127.0.0.1:9876/windows -Headers $h | Select-Object -ExpandProperty value
```

**Expected outcome:**

- `/type` returns `{"ok":true,"aspect":"<INPUT_ASPECT>","value":"<TEST_NAME>"}`.
- The read-back `/value` returns the same value (confirms the model accepted it).
- `/click` returns `{"ok":true,"aspect":"<BUTTON_ASPECT>","method":"model_value_true","oldValue":...}`.
- After the click, one of:
  - A results list populates inside Party Search (the search field's parent window).
  - A new "Party Result" / "Search Results" window opens (visible via `/windows`).
  - A modal "no results" / error dialog appears.

**Caveats:**

- A **modal dialog** will WEDGE the bridge listener for ~5 seconds (the `onUIDo:` watchdog timeout) and then time out. If you hit this, **dismiss the modal manually in MAS** and the bridge recovers.
- `/click` does NOT currently include `windows.opened` in its response (only `/menu/click` does). Phase B+1 candidate below: add window tracking to `/click` for parity.

---

## Step 3 — 3-deep menu navigation (read-only-ish, ~5-10 min)

**Goal:** confirm the bridge's `walkMenuPath:` handles 3-level menu paths cleanly.

Party & Contract has 5 children with `hasSubmenu=True`:

| Submenu | Item count |
|---|---|
| Bulk Switch Instructions | 3 |
| Internet Instructions | 3 |
| Individual New Business | 8 |
| Outstanding Requirements | 4 |
| General reports | 11 |

(The other 15 children are leaves and were sampled in this session.)

**Discover what's inside, then click (pick a leaf with a read-only-sounding label):**

```powershell
# Enumerate
$menu = (Invoke-WebRequest -Uri "http://127.0.0.1:9876/menu?windowTitle=MOMENTUM" -Headers $h -UseBasicParsing).Content | ConvertFrom-Json
$pc = $menu.menus | Where-Object { $_.label -eq 'Party & Contract' }
$reports = $pc.items | Where-Object { $_.label -eq 'General reports' }
$reports.items | ForEach-Object { "{0,-40}  hasSubmenu={1}  value={2}" -f $_.label, $_.hasSubmenu, $_.value }

# Click a 3-deep path (replace <SAFE_LEAF> with one of the labels above - VERIFY with user it's read-only)
$body = @{path=@("Party & Contract","General reports","<SAFE_LEAF>"); windowTitle="MOMENTUM"} | ConvertTo-Json -Compress
Invoke-RestMethod -Uri http://127.0.0.1:9876/menu/click -Method POST -Headers $h -Body $body -ContentType 'application/json'
```

**Expected:**

- The walk traverses three levels of `menuItems → submenu → menuItems`.
- Response carries `dispatch:"block"` (assumption; some leaves may use `Symbol` — Step 4 confirms).
- `windows.opened` may show a new report-viewer window.

---

## Step 4 — Catalog leaf dispatch types (read-only, ~10 min)

**Goal:** confirm the assumption that all MAS menu leaves use BlockClosure values. If any leaf uses a Symbol, the bridge already handles it but the distribution is worth knowing — it tells us whether MAS uses one menu-building style consistently or mixes.

**Run:**

```powershell
$menu = (Invoke-WebRequest -Uri "http://127.0.0.1:9876/menu?windowTitle=MOMENTUM" -Headers $h -UseBasicParsing).Content | ConvertFrom-Json
$script:leaves = @()
function Walk($items, $path) {
  foreach ($it in $items) {
    if ($it.items.Count -eq 0) { $script:leaves += @{path=($path + @($it.label)); value=$it.value} }
    else { Walk $it.items ($path + @($it.label)) }
  }
}
Walk $menu.menus @()
"total leaves: $($script:leaves.Count)"
$script:leaves | Group-Object {
  if ($null -eq $_.value) { 'no-value' }
  elseif ($_.value -like 'BlockClosure*') { 'block' }
  else { 'symbol-or-other' }
} | Select-Object Name, Count
```

**Expected:** Almost all leaves classify as `block`. Any `symbol-or-other` results are anomalies worth sampling (print the path + value for a few) so we know which leaves dispatch differently.

---

## Phase B+1 candidates (not in scope, but record them)

- **Extend `/click` (and `/type`) to include `windows.opened` / `windows.closed`** for parity with `/menu/click`. Same `controllerSet` + `windowDiffBefore:after:` helpers — small change to `doClick:` and `doType:`.
- **Wait-for-window endpoint** — `POST /wait` body `{"title":"<X>","timeoutMs":<N>}` polling `controllerSet` for the target window. Supports async flows.
- **Subcanvas-aware aspect resolution** — currently `/value` / `/click` / `/type` only find aspects in the top-level `namedComponents` of a window. PartySearchView (and most MAS domain windows) likely use nested SubCanvases. When Step 1 confirms nesting, extend `resolveAspect:inWindowMatching:` to recurse into `SubCanvasSpec` widgets and look up their embedded apps' `namedComponents`.
- **Menu structure cache** — `/menu` rebuilds the tree each call (walks `menuChannel.menuItems` recursively). For a Playwright test suite that does many lookups, a 1-second cache would help. Not needed yet.
- **Per-leaf safety annotations** — could grep menu labels for mutation verbs (`add`, `delete`, `transfer`, etc.) and tag them as "needs explicit permission" in `/menu` output. Would let test runners auto-skip risky paths.
- **Modal-dialog recovery** — current behaviour: a modal wedges the listener for 5s and times out. Possible improvement: detect known-modal aspects ahead of time and surface a `"may_open_modal"` warning on `/click`.

---

## When you finish exploration

1. Update [`SESSION-RESUME.md`](./SESSION-RESUME.md) with what was learned (new findings, new endpoints if any, current open windows).
2. If you added bridge methods, file them in via a Phase B+1 patch file (or a v0.8.2 patch within `VWBridge-phaseB.st`).
3. Commit. Don't push without permission.
