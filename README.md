# Skeet Framework

A production-grade Roblox UI library with a skeet/gamesense-inspired visual style. Draggable, configurable, and fully featured out of the box.

## Quick Start

```lua
local library = loadstring(game:HttpGet("YOUR_RAW_URL_HERE"))()
local window = library:CreateWindow({})
```

Every window automatically includes a **Settings** page (last tab icon) with:
- Toggle Keybind (rebindable)
- Save / Load Configuration (JSON to filesystem)
- Accent Color picker (live theme updates)
- Server Utilities (Copy Job ID, Join Job ID, Server Hop, Hop High/Low)

---

## API Reference

### `library:CreateWindow(Properties) -> Window`

Creates a new draggable GUI window.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| *(none)* | — | — | Currently accepts an empty table. |

**Returns:** A `Window` object.

---

### Window Methods

#### `Window:CreatePage(Properties) -> Page`
Alias: `Window:CreateTab(Properties)`

Creates a new tab page in the sidebar.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Icon` | `string` | — | rbxassetid:// URL for the tab icon |
| `Size` | `UDim2` | `UDim2.new(0,50,0,50)` | Icon display size |

#### `Window:Fade(state: boolean)`
Smoothly fades the entire UI in (true) or out (false).

#### `Window:Unload()`
Destroys all GUI instances and disconnects all event connections owned by **this window only**. Full cleanup, zero leaks. Multiple windows are fully independent: unloading one never affects another.

#### `Window:SetAccent(color: Color3)`
Globally updates the accent color on all active toggles, sliders, and dropdown highlights.

#### `Window:SetToggleKey(key: Enum.KeyCode)`
Sets the show/hide toggle key programmatically (default: `Enum.KeyCode.Insert`).

#### `Window:AddInstance(instance: Instance)`
Registers an externally-built GUI instance (e.g. a custom window you constructed yourself) so it is destroyed on `Unload` and included in `Fade`. Returns the instance. This lets you attach a fully custom GUI to the window's lifecycle.

#### `Window:RegisterConnection(connection: RBXScriptConnection)`
Registers an external event connection that `Unload` will disconnect. Returns the connection.

---

### Multiple Windows

Each call to `library:CreateWindow` produces an independent, fully functional window (own GUI instances, connections, accent, settings). Build a second window — or an entirely custom GUI attached via `AddInstance`/`RegisterConnection` — alongside the first without interference.

---

### Page Methods

#### `Page:CreateSection(Properties) -> Section`

Creates a groupbox section within a page.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Name` | `string` | `"New Section"` | Section header title |
| `Size` | `number` | `150` | Height in pixels |
| `Side` | `string` | `"Left"` | `"Left"` or `"Right"` column |

> **Note:** Each page's `Left`/`Right` columns are vertical `ScrollingFrame`s. When the
> stacked sections (and any custom GUI you parent into `Page.Left`/`Page.Right`) exceed the
> column height they scroll instead of overflowing the window — so oversized `Size` values
> on a section no longer spill outside the GUI. The old per-section scroll arrows were removed;
> scroll with the mouse wheel (or drag the scrollbar) instead.

---

### Section Methods (Elements)

#### `Section:CreateToggle(Properties) -> Toggle`

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Name` | `string` | `"New Toggle"` | Display label |
| `State` | `boolean` | `false` | Initial state |
| `Callback` | `function(value)` | — | Called on state change |

**Methods:** `Toggle:Set(bool)`, `Toggle:Get() -> bool`

---

#### `Section:CreateSlider(Properties) -> Slider`

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Name` | `string` | `nil` | Display label (optional) |
| `State` | `number` | `Min` | Initial value |
| `Min` | `number` | `0` | Minimum value |
| `Max` | `number` | `100` | Maximum value |
| `Step` | `number` | `1` | Quantization step (e.g. `0.5` allows halves). Aliases: `Decimals`, `Tick`. |
| `Suffix` | `string` | `""` | Display suffix (e.g. "px", "%") |
| `Callback` | `function(value)` | — | Called on value change |

**Methods:** `Slider:Set(number)`, `Slider:Get() -> number`

---

#### `Section:CreateDropdown(Properties) -> Dropdown`

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Name` | `string` | `"New Dropdown"` | Display label |
| `State` | `number` | `1` | Selected index |
| `Options` | `table` | `{1, 2, 3}` | Array of option strings |
| `Callback` | `function(index)` | — | Called with selected index |

**Methods:** `Dropdown:Set(index)`, `Dropdown:Get() -> number`

---

#### `Section:CreateMultibox(Properties) -> Multibox`

Multi-select dropdown.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Name` | `string` | `"New Dropdown"` | Display label |
| `State` | `table` | `{1}` | Array of selected indices |
| `Options` | `table` | `{1, 2, 3}` | Array of option strings |
| `Min` | `number` | `0` | Minimum selections allowed |
| `Max` | `number` | `1000` | Maximum selections allowed |
| `Callback` | `function(indices)` | — | Called with selected indices |

**Methods:** `Multibox:Set(table)`, `Multibox:Get() -> table`

---

#### `Section:CreateKeybind(Properties) -> Keybind`

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Name` | `string` | `"New Toggle"` | Display label |
| `State` | `table\|nil` | `nil` | `{"KeyCode", "Z"}` or `{"UserInputType", "MouseButton2"}` |
| `Mode` | `string` | `"Hold"` | `"Hold"` or `"Toggle"` |
| `Callback` | `function(value)` | — | Called on keybind change |

**Methods:** `Keybind:Set(table?)`, `Keybind:Get() -> table`
**Properties:** `Keybind.Active` (boolean, is the key actively held/toggled)

Left-click the keybind display to rebind. Right-click to clear.

---

#### `Section:CreateColorpicker(Properties) -> Colorpicker`

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Name` | `string` | `"New Toggle"` | Display label |
| `State` | `Color3` | `Color3.fromRGB(255,255,255)` | Initial color |
| `Callback` | `function(color)` | — | Called on color change |

**Methods:** `Colorpicker:Set(Color3)`, `Colorpicker:Get() -> Color3`

---

#### `Section:CreateButton(Properties) -> Button`

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Name` | `string` | `"Button"` | Button label |
| `Callback` | `function()` | — | Called on click |

---

#### `Section:CreateTextBox(Properties) -> TextBox`

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Name` | `string` | `"Text Box"` | Display label |
| `State` | `string` | `""` | Initial text |
| `Callback` | `function(text)` | — | Called on focus lost |

**Methods:** `TextBox:Set(string)`, `TextBox:Get() -> string`

---

## Built-in Settings Page

Every `CreateWindow` call automatically appends a Settings page with:

### Configuration Section
- **Toggle Keybind** — Click to rebind the show/hide key (default: `Insert`)
- **Save UI State** — Toggle auto-saving of window position, last tab and collapsed sections to `Skeet/isettings.json` (default: on). Disable if you don't want the window to remember its layout.
- **Save Configuration** — Serializes all named elements to `Skeet/Configs/<GameId>/<name>.json`
- **Load Configuration** — Deserializes and applies saved values to all named elements
- **Unload GUI** — Calls `Window:Unload()`, destroying this window and all its connections

### Theme Section
- **Accent Color** — Color picker that live-updates all accent-colored elements
- **Background Color / Text Color** — Live theme recolors
- **GUI Outline** — Outline opacity slider
- **Rainbow Accent** — Cycles the accent color
- **Rainbow Speed** — How fast the rainbow accent cycles (0.01s–0.5s per step)
- **Blur Strength** — Background blur amount (0–50) applied while the GUI is shown

### Server Utilities Section
- **Copy Job ID** — Copies current `game.JobId` to clipboard
- **Target Job ID** — Text input for a target server's job ID
- **Join via Job ID** — Teleports to the specified job ID
- **Server Hop** — Random hop to another server
- **Hop to Highest Population** — Joins the fullest available server
- **Hop to Lowest Population** — Joins the emptiest available server

---

## Configuration Engine

Configs are stored as JSON files via the executor's `writefile`/`readfile` APIs.

**Paths:**
- Configs: `Skeet/Configs/<GameId>/<name>.json` (one file per saved config, named via the "Config Name" box)
- Window state (last position + selected config + collapsed sections + last tab): `Skeet/isettings.json`

All named elements are automatically included. Color values are stored as `[R, G, B]` arrays with values in the 0-1 range. **`Button` and `TextBox` elements are NOT persisted** — only Toggle, Slider, Dropdown, Multibox, Keybind, and Colorpicker save/load. Element names must be unique per window; a duplicate `Name` silently overwrites the previous element's config entry.

---

## Dragging

The window is draggable from anywhere on the main frame body. Dragging uses `UserInputService` delta tracking and works on both mouse and touch inputs.

---

## Toggle Key

Press the toggle key (default: **Insert**) to show/hide the UI with a smooth fade animation. The key can be rebound from the Settings page or set programmatically via `window:SetToggleKey(Enum.KeyCode.F9)`.

---

## Complete Example

```lua
local library = loadstring(game:HttpGet("YOUR_RAW_URL"))()
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

section:CreateButton({
    Name = "Click Me",
    Callback = function() print("Clicked!") end
})
```

---

## Architecture Notes

- **Zero Memory Leaks:** `Window:Unload()` destroys all instances and disconnects all connections. Popup close functions (`Dropdown`, `Multibox`, `Colorpicker`) remove their temporary instances from `library.Renders` and disconnect their local connections from `library.Connections`.
- **Destroy Ordering:** Child instances are destroyed before their parents to avoid double-destroy errors.
- **Fade Safety:** The `Fade` function snapshots the render table and wraps tween calls in `pcall` to handle instances that may have been destroyed mid-iteration.
- **Slider Decoupling:** Slider hit calculation uses `AbsolutePosition` deltas relative to the container bounds rather than hardcoded pixel offsets.
- **Optimized Serialisation:** `utility:Serialise` uses indexed table accumulation and a single `table.concat` call instead of repeated string concatenation.
