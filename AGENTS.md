# AGENTS.md

Skeet Framework: a single-file Roblox/Luau GUI library (skeet/gamesense visual style) meant to be injected into a Roblox executor. Not a normal app repo — no build, lint, test, or typecheck. All verification is manual or via an in-game executor. A local `lua`/`luac` is available for parse-only checks (`luac -p`).

## Layout
- `skeet lib.lua` — the entire library. Source of truth for behavior. Returns a `library` table.
- `example.lua` — usage walkthrough; load the lib then run this to exercise every element type.
- `README.md` — API reference, but **partially stale**; prefer the lib code when they disagree.

## Critical gotchas
- Runs only inside a Roblox executor: `local library = loadstring(game:HttpGet("URL"))()`. Depends on executor file APIs (`writefile/readfile/makefolder/listfiles`) and `game`, `Instance`, `TweenService`, `UserInputService`, `CoreGui`.
- Stale README claims you should NOT trust:
  - Default reveal/toggle key is actually `Enum.KeyCode.Insert`, NOT `Z` as README said. Use `window:SetToggleKey(Enum.KeyCode...)` to change it programmatically.
  - Config path is `Skeet/Configs/<GameId>/<name>.json`; window state (last pos + selected config) is `Skeet/isettings.json` — NOT README's old `PuppyWare/Configs/config.json`. Code creates the `Skeet/` folder tree on window creation.
- Object model: `library:CreateWindow` → `window:CreatePage` (alias `CreateTab`) → `page:CreateSection` → element creators (`CreateToggle/Slider/Dropdown/Multibox/Keybind/Colorpicker/Button/TextBox`). A Settings page is auto-appended to every window (config save/load, toggle key, blur, accent color, server utilities).
- Property keys are flexible casing (e.g. section accepts `name/.Name/.title/.Title`), but the README shows PascalCase (`Name`, `State`, `Min`, `Max`, `Callback`).
- Page columns (`Page.Left`/`Page.Right`) are now `ScrollingFrame`s with `AutomaticCanvasSize = "Y"` and `ScrollBarThickness = 0`. Popups (dropdowns, colorpickers, multiboxes) are reparented to `Page["Page"]` (a non-scrolling overlay frame) so they are never clipped by the column scroll viewport. Do not parent popups to `Section.Extra` directly — they will be clipped when the column scrolls. Use `utility:ReparentPopup(instance, parent)` to move a popup to the page overlay while preserving its absolute position.
- The Toggle Keybind settings callback receives a boolean (`true`/`false`) when the key is actively pressed/released (Hold/Toggle modes), not just a `{type, value}` table on `Set`. Always guard with `type(val) == "table"` before indexing `val[1]`.
- Window state auto-save (position, last tab, collapsed sections) is controlled by `Window.AutoSave` (default `true`). The Settings page includes a "Save UI State" toggle. When disabled, `isettings.json` is not written for those fields and saved state is not restored on load.
- `Window:AddInstance` registers a hand-built GUI so it fades and is destroyed on `Unload`. `Window:RegisterConnection` registers an external RBXScriptConnection to be disconnected on `Unload`. Both are scoped per-window.
- `Fade` handles `Frame` and `ViewportFrame` classes for background transparency tweening.
- Slider uses a `Step` quantization value (aliases `Decimals`, `Tick`), clamped; `math.round(x/Step)*Step`. `Min==Max` is guarded to fill the whole track.

## Config engine (easy to miss)
- ONLY elements with a `Name` are persisted. Each creator registers into `Window.Elements[<Name>]` — keys are the element `Name`, so **names must be unique per window** or elements silently overwrite each other.
- Persisted types: Toggle, Slider, Dropdown, Multibox, Keybind, Colorpicker. **Button and TextBox are NOT saved/loaded.**
- Colorpicker stored as `[R,G,B]` floats (0–1); Keybind as `{type, value}`.
- Save/load helpers `utility:SaveSettings`/`GetSettings` guard on whether `writefile`/`readfile` exist — on executors without file API they silently no-op.

## Editing conventions
- This is plain Luau with object-oriented style (metatables via `library.__index`, `pages.__index`, `sections.__index`). Keep creators returning objects with `:Get()`/`:Set()`.
- Resource/manage tables: `library.Renders` (GUI instances) and `library.Connections` (RBXScriptConnections) tracked centrally; use `utility:CreateConnection`/`utility:DestroyObject` and keep `Window:Unload()` leak-free. Rainbow accent loop stops on `Unload`; accent writes are `pcall`-guarded for destroyed instances.
- Property reads are centralized via `utility:Resolve(Properties, {aliases...}, default)`; shared label builders `utility:AddLabel/AddTitle`. Prefer these over hand-duplicated `Properties.x or Properties.X or ...` chains and repeated TextLabel blocks.
- `utility:ReparentPopup(Popup, Parent)` moves a popup frame to a non-scrolling parent (typically `Content.Page["Page"]`) while preserving its screen position, preventing clipping by ScrollingFrame columns.