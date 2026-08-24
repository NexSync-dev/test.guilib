local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/NexSync-dev/test.guilib/main/skeet%20v2.lua"))()

local window = library:CreateWindow({
	Name = "skeet v2",
	Size = Vector2.new(660, 480),
	ToggleKey = Enum.KeyCode.Insert
})

local rage = window:CreateTab({Name = "Ragebot"})
local visuals = window:CreateTab({Name = "Visuals"})
local misc = window:CreateTab({Name = "Misc"})

local general = rage:CreateSubTab({Name = "General"})
local points = rage:CreateSubTab({Name = "Points"})

local aimbot = general:CreateGroupbox({Name = "Aimbot", Side = "Left", Size = 320})

local enableAimbot = aimbot:CreateToggle({
	Name = "Enable aimbot",
	Default = false,
	Callback = function(state)
		print("[example] aimbot:", state)
	end
})

aimbot:CreateSlider({
	Name = "Field of view",
	Min = 0,
	Max = 180,
	Step = 1,
	Default = 90,
	Suffix = "\u{00B0}",
	Callback = function(value)
		print("[example] fov:", value)
	end
})

aimbot:CreateSlider({
	Name = "Minimum damage",
	Min = 0,
	Max = 100,
	Step = 1,
	Default = 50,
	Suffix = " hp",
	Callback = function(value)
		print("[example] min damage:", value)
	end
})

aimbot:CreateDropdown({
	Name = "Selection mode",
	Options = {"FOV", "Health", "Distance", "Highest damage"},
	Default = 1,
	Callback = function(value, index)
		print("[example] selection mode:", value, index)
	end
})

aimbot:CreateKeybind({
	Name = "Force body aim",
	Default = Enum.KeyCode.E,
	Mode = "Hold",
	Callback = function(active)
		print("[example] force body aim held:", active)
	end
})

aimbot:CreateSeparator({Name = "Safety"})

aimbot:CreateButton({
	Name = "Print current settings",
	Callback = function()
		print("[example] aimbot enabled:", enableAimbot:Get())
	end
})

aimbot:CreateLabel({Text = "click keybind to listen, escape clears, right-click for mode"})

local antiAim = general:CreateGroupbox({Name = "Anti-aim", Side = "Right", Size = 320})

antiAim:CreateDropdown({
	Name = "Pitch",
	Options = {"Off", "Down", "Up", "Zero"},
	Default = 2,
	Callback = function(value)
		print("[example] pitch:", value)
	end
})

antiAim:CreateMultibox({
	Name = "Conditions",
	Options = {"Standing", "Moving", "In air"},
	Default = {"Moving", "In air"},
	Callback = function(selected)
		print("[example] conditions:", table.concat(selected, ", "))
	end
})

antiAim:CreateColorpicker({
	Name = "Glow color",
	Default = Color3.fromRGB(147, 197, 57),
	Alpha = 1,
	Callback = function(color, alpha)
		print("[example] glow:", color, alpha)
	end
})

antiAim:CreateTextBox({
	Name = "Clan tag",
	Placeholder = "tag...",
	Callback = function(text)
		print("[example] clan tag:", text)
	end
})

antiAim:CreateSeparator()

antiAim:CreateLabel({Text = "rainbow bar + pinstripe = skeet"})

local pointsGroup = points:CreateGroupbox({Name = "Hitboxes", Side = "Left", Size = 340})

pointsGroup:CreateMultibox({
	Name = "Points",
	Options = {"Head", "Neck", "Chest", "Stomach", "Arms", "Legs"},
	Default = {"Head", "Chest"},
	Callback = function(selected)
		print("[example] points:", #selected)
	end
})

for i = 1, 14 do
	pointsGroup:CreateToggle({
		Name = "Priority " .. i,
		Default = false,
		Callback = function(state)
			print("[example] priority " .. i .. ":", state)
		end
	})
end

local esp = visuals:CreateGroupbox({Name = "Player ESP", Side = "Left", Size = 330})

esp:CreateToggle({Name = "Bounding box", Callback = function(v) print("[example] box:", v) end})
esp:CreateColorpicker({Name = "Box color", Default = Color3.fromRGB(138, 122, 255), Callback = function(c) print("[example] box color:", c) end})
esp:CreateToggle({Name = "Health bar", Default = true, Callback = function(v) print("[example] healthbar:", v) end})
esp:CreateToggle({Name = "Name", Default = true, Callback = function(v) print("[example] name:", v) end})
esp:CreateColorpicker({Name = "Name color", Default = Color3.fromRGB(213, 213, 213), Callback = function(c) print("[example] name color:", c) end})
esp:CreateToggle({Name = "Flags", Callback = function(v) print("[example] flags:", v) end})
esp:CreateToggle({Name = "Weapon text", Callback = function(v) print("[example] weapontext:", v) end})
esp:CreateToggle({Name = "Ammo", Callback = function(v) print("[example] ammo:", v) end})
esp:CreateColorpicker({Name = "Ammo color", Default = Color3.fromRGB(120, 160, 255), Callback = function(c) print("[example] ammo color:", c) end})
esp:CreateDropdown({
	Name = "Distance style",
	Options = {"Off", "Meters", "Feet"},
	Default = 2,
	Callback = function(value) print("[example] distance:", value) end
})

local effects = visuals:CreateGroupbox({Name = "Effects", Side = "Right", Size = 330})

effects:CreateToggle({Name = "Remove scope overlay", Callback = function(v) print("[example] noscope:", v) end})
effects:CreateSlider({
	Name = "Transparent walls",
	Min = 0,
	Max = 100,
	Default = 0,
	Suffix = "%",
	Callback = function(v) print("[example] walls:", v) end
})
effects:CreateButton({
	Name = "Reset effects",
	Callback = function()
		print("[example] effects reset")
	end
})

local miscGroup = misc:CreateGroupbox({Name = "Miscellaneous", Side = "Left", Size = 300})

miscGroup:CreateToggle({Name = "Bunny hop", Callback = function(v) print("[example] bhop:", v) end})
miscGroup:CreateKeybind({
	Name = "Menu key",
	Default = Enum.KeyCode.Insert,
	Mode = "Toggle",
	Callback = function(active)
		print("[example] menu key toggled:", active)
	end
})
miscGroup:CreateButton({
	Name = "Set accent to purple",
	Callback = function()
		library:SetAccent(Color3.fromRGB(178, 122, 255))
		print("[example] accent set to purple")
	end
})
miscGroup:CreateButton({
	Name = "Set accent to skeet green",
	Callback = function()
		library:SetAccent(Color3.fromRGB(147, 197, 57))
		print("[example] accent set back to green")
	end
})
miscGroup:CreateSeparator({Name = "Window"})
miscGroup:CreateButton({
	Name = "Minimize window",
	Callback = function()
		window:Minimize()
	end
})
miscGroup:CreateButton({
	Name = "Restore window",
	Callback = function()
		window:Restore()
	end
})

print("[example] skeet v2 loaded - press Insert to toggle the menu")
