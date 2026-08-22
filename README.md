# Skeet Framework

A production-grade Roblox UI library with a skeet/gamesense-inspired visual style. Draggable, configurable, and fully featured out of the box.

## Quick Start

```lua
local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/NexSync-dev/test.guilib/refs/heads/main/skeet%20lib.lua"))()
local window = library:CreateWindow({})
```

Every window automatically includes a **Settings** page (last tab icon) with config save/load, theme controls, and server utilities.

---

## API Reference

### `library:CreateWindow(Properties) -> Window`

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Name` | `string` | `"skeet"` | Internal GUI name |
| `Size` | `Vector2` | `(660, 560)` | Window size in pixels |
| `Key` | `Enum.KeyCode` | `Enum.KeyCode.Insert` | Show/hide toggle key |
| `ShowSettings` | `boolean` | `true` | Append the built-in Settings page |
| `TextScale` | `number` | `1` | Multiplier applied to all text sizes |

**Returns:** A `Window` object.

---

### Window Methods

#### `Window:CreatePage(Properties) -> Page`
Alias: `Window:CreateTab(Properties)`

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Icon` | `string` | — | rbxassetid:// URL for the tab icon |
| `Size` | `UDim2` | `UDim2.new(0,50,0,50)` | Icon display size |
| `LayoutOrder` | `number` | creation order | Tab ordering |

Pages expose `Page.Left` / `Page.Right` ScrollingFrame columns (auto-sizing canvas, no visible scrollbar) and `Page["Page"]`, the non-scrolling overlay that hosts all popups so they are never clipped by column scrolling. The last open tab and collapsed sections are restored from `isettings.json` when `Save UI State` is enabled.

#### `Window:Fade(state: boolean)`
Smoothly fades the entire UI in (`true`) or out (`false`). Open-page tab highlights are re-applied after fade-in.

#### `Window:SetEnabled(state: boolean)`
Show/hide helper used by the toggle key: toggles visibility, closes any open popup, releases focused text boxes, and fades.

#### `Window:Unload()`
Destroys all GUI instances and disconnects all event connections owned by **this window only**. Multiple windows are fully independent: unloading one never affects another.

#### `Window:SetAccent(color: Color3)`
Live-updates every accent element: active toggles, slider fills, tab accent bars, section accents, top bar, and bound keybind values.

#### `Window:SetTheme({Background = ..., Text = ...})`
Partial theme update. Background derives three shades (base/light/dark) applied across chrome and sections; text recolor applies to labels whose color matches the previous text color.

#### `Window:SetToggleKey(key: Enum.KeyCode)`
Sets the show/hide toggle key programmatically (default: `Enum.KeyCode.Insert`).

#### `Window:AddInstance(instance: Instance)`
Registers an externally-built GUI instance so it is included in `Fade` and destroyed on `Unload`. Returns the instance.

#### `Window:RegisterConnection(connection: RBXScriptConnection)`
Registers an external event connection that `Unload` will disconnect. Returns the connection.

---

## Multiple Windows

Each call to `library:CreateWindow` produces an independent window (own instances, connections, accent, settings). A shared blur effect is reference-counted across windows and removed only when the last one unloads.

---

## Page Methods

### `Page:CreateSection(Properties) -> Section`

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Name` | `string` | `"New Section"` | Section header title |
| `Size` | `number` | `150` | Height in pixels |
| `Side` | `string` | `"Left"` | `"Left"` or `"Right"` column |

Sections collapse via the chevron button with an animated tween; collapsed state persists per-section in `isettings.json`. Section content scrolls internally when elements exceed `Size`.

---

## Section Methods (Elements)

All creators accept flexible property casing (`Name`/`name`, `State`/`state`, etc.). Every element returns an object with `:Get()` / `:Set(value, silent)` — pass `silent = true` to change state without firing the callback.

### `Section:CreateToggle(Properties) -> Toggle`

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Name` | `string` | `"New Toggle"` | Display label |
| `State` | `boolean` | `false` | Initial state |
| `Callback` | `function(value)` | — | Called on state change |

---

### `Section:CreateSlider(Properties) -> Slider`

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Name` | `string` | `nil` | Display label (optional; compact row if omitted) |
| `State` | `number` | `Min` | Initial value |
| `Min` / `Max` | `number` | `0` / `100` | Range (swapped automatically if inverted) |
| `Step` | `number` | `1` | Quantization step (e.g. `0.5`). Aliases: `Decimals`, `Tick` |
| `Suffix` / `Ending` | `string` | `""` | Display suffix (e.g. `"px"`, `"%"`) |
| `Callback` | `function(value)` | — | Called on value change |

The value bubble rides the track fill; dragging uses global mouse-move dispatch per window (no per-slider connections).

---

### `Section:CreateDropdown(Properties) -> Dropdown`

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Name` | `string` | `"New Dropdown"` | Display label |
| `State` | `number` | `1` | Selected index |
| `Options` | `table` | `{}` | Array of option strings |
| `Callback` | `function(index)` | — | Called with selected index |

**Methods:** `Set(index, silent?)`, `Get() -> number`, `RefreshOptions(options)` (rebuilds list), `Open()`, `Close()`, `IsOpen()`. The popup lists up to 7 rows before scrolling.

---

### `Section:CreateMultibox(Properties) -> Multibox`

Multi-select dropdown with checkbox rows.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Name` | `string` | `"New Multibox"` | Display label |
| `State` | `table` | `{}` | Selected indices (names accepted too) |
| `Options` | `table` | `{}` | Array of option strings |
| `Max` | `number` | unlimited | Maximum selections |
| `Min` | `number` | `0` | Minimum selections (padded from the first option) |
| `Callback` | `function(indices)` | — | Called with selected index array |

`Get()` returns the sorted index array; the display shows comma-joined names or `-`.

---

### `Section:CreateKeybind(Properties) -> Keybind`

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Name` | `string` | `"New Keybind"` | Display label |
| `State` | `table` | `{"KeyCode", "Insert"}` | `{"KeyCode", "F"}` or `{"UserInputType", "MouseButton2"}` |
| `Mode` | `string` | `"Always"` | `"Always"`, `"Hold"`, or `"Toggle"` |
| `Callback` | `function(value)` | — | See below |

Callback values: rebinding/clearing fires `{type, value}`-style arrays (`{"KeyCode", "F"}`); while in `Hold`/`Toggle` mode, pressing/releasing additionally fires a plain `true`/`false`. `Get()` returns `{type, value, active}`.

Left-click the keybind display to rebind; right-click the row to clear. Invalid states fall back safely instead of erroring on `Enum[...]` lookups.

---

### `Section:CreateColorpicker(Properties) -> Colorpicker`

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Name` | `string` | `"New Colorpicker"` | Display label |
| `State` | `Color3` | white | Initial color |
| `Callback` | `function(color)` | — | Called on color change |

Popup contains a saturation/value field, hue strip, and a hex input (`#RRGGBB`, applied on Enter). Cursors are clamped inside their tracks; drag handlers are registered once per picker.

---

### `Section:CreateButton(Properties) -> Button`

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Name` | `string` | `"New Button"` | Button label |
| `Callback` | `function(button)` | — | Called on click |

Full-width button with pressed-state darkening. `Button:SetText(text)` / `Button:Get()`.

Buttons are **not** persisted in configs.

---

### `Section:CreateTextBox(Properties) -> TextBox`

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Name` | `string` | `nil` | Display label (optional) |
| `State` | `string` | `""` | Initial text |
| `Placeholder` | `string` | `""` | Placeholder text |
| `MaxLength` | `number` | unlimited | Hard character cap enforced live |
| `Callback` | `function(text, enterPressed)` | — | Called on focus lost |

Text boxes are **not** persisted in configs.

---

### `Section:CreateLabel(Properties) -> Label`

Muted informational line. `Label:Set(text)` / `Label:Get()`. Not persisted.

---

## Built-in Settings Page

### Configuration Section
- **Toggle Keybind** — rebindable show/hide key (default `Insert`)
- **UI Blur** — background blur while the GUI is shown
- **Save UI State** — auto-save window position, last tab, collapsed sections to `Skeet/isettings.json` (default on)
- **Selected Config / Refresh / Save / Load** — JSON configs under `Skeet/Configs/<GameId>/`
- **Unload GUI** — destroys this window and all its connections

### Theme Section
- **Accent Color**, **Background Color**, **Text Color** pickers
- **GUI Outline** opacity slider
- **Rainbow Accent** + **Rainbow Speed** (loop stops on unload)
- **Blur Strength** (0–50)

### Server Utilities Section
- **Copy Job ID**, **Target Job ID** + **Join via Job ID**
- **Server Hop** (random), **Hop to Highest/Lowest Population** with status feedback

---

## Configuration Engine

Configs are stored as JSON via the executor's `writefile`/`readfile` APIs (silently skipped if unavailable).

**Paths:**
- Configs: `Skeet/Configs/<GameId>/<name>.json`
- Window state: `Skeet/isettings.json` (position, last tab, collapsed sections, last config)

Only elements with a unique `Name` persist: **Toggle, Slider, Dropdown, Multibox, Keybind, Colorpicker**. Colors store as `[R, G, B]` floats (0–1); keybinds as `["KeyCode", "F"]` arrays. Duplicate names silently overwrite each other's entry.

---

## Dragging & Toggle Key

Drag the window from anywhere on its body (mouse + touch); position saves on release. Press the toggle key (default **Insert**) to fade the UI; the key is rebindable from Settings or via `window:SetToggleKey(...)`.

---

## Complete Example

See [example.lua](example.lua) for a full walkthrough exercising every element type, plus a second independent window using `AddInstance`/`RegisterConnection`.

```lua
local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/NexSync-dev/test.guilib/refs/heads/main/skeet%20lib.lua"))()
local window = library:CreateWindow({})

local page = window:CreatePage({Icon = "rbxassetid://8547236654"})
local section = page:CreateSection({Name = "My Section", Size = 200, Side = "Left"})

section:CreateToggle({
    Name = "My Toggle",
    State = false,
    Callback = function(v) print("Toggle:", v) end
})

section:CreateSlider({
    Name = "My Slider",
    State = 50,
    Min = 0,
    Max = 100,
    Suffix = "%",
    Callback = function(v) print("Slider:", v) end
})

section:CreateDropdown({
    Name = "My Dropdown",
    Options = {"Option A", "Option B", "Option C"},
    Callback = function(v) print("Dropdown:", v) end
})
```

---

## Architecture Notes

- **Central registries:** `library.Renders` (weak-keyed instance records) and `library.Connections` (weak-keyed connection→window map) drive fade, theme sweeps, and leak-free `Unload`.
- **Per-window dispatch:** sliders and keybinds share one global InputBegan/InputEnded dispatcher per window instead of per-element connections; popups close through `Window.OpenContent` so only one is ever open.
- **Popup layering:** dropdown/multibox/colorpicker popups are parented to `Page["Page"]` (non-scrolling overlay, high ZIndex) and positioned/clamped against its bounds — never clipped by column scrolling.
- **Fade safety:** fade iterates the render table guarded by `Inst.Parent ~= nil`; destroyed instances are pruned by `PruneElementList` during accent/theme updates.
