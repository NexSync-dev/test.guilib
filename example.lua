local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/NexSync-dev/test.guilib/refs/heads/main/skeet%20lib.lua"))()

local window = library:CreateWindow({})

local page = window:CreatePage({
	Icon = "rbxassetid://8547236654"
})

local mainSection = page:CreateSection({
	Name = "Main",
	Size = 430,
	Side = "Left"
})

mainSection:CreateToggle({
	Name = "Aimbot",
	State = false,
	Callback = function(state)
		print("[example] aimbot:", state)
	end
})

mainSection:CreateSlider({
	Name = "Field of View",
	Min = 30,
	Max = 360,
	State = 120,
	Callback = function(value)
		print("[example] fov:", value)
	end
})

mainSection:CreateDropdown({
	Name = "Target Part",
	Options = {"Head", "Torso", "Random"},
	State = 1,
	Callback = function(index)
		print("[example] target part index:", index)
	end
})

mainSection:CreateMultibox({
	Name = "Visuals",
	Options = {"Box", "Name", "Health", "Distance"},
	State = {1, 2},
	Callback = function(selected)
		print("[example] visuals count:", #selected)
	end
})

mainSection:CreateKeybind({
	Name = "Aimbot Keybind",
	Mode = "Hold",
	State = {"KeyCode", "E"},
	Callback = function(val)
		if type(val) == "boolean" then
			print("[example] aimbot held:", val)
		end
	end
})

mainSection:CreateColorpicker({
	Name = "Box Color",
	State = Color3.fromRGB(138, 122, 255),
	Callback = function(color)
		print("[example] box color:", color)
	end
})

local extraSection = page:CreateSection({
	Name = "Extra",
	Size = 240,
	Side = "Right"
})

extraSection:CreateTextBox({
	Name = "Config Tag",
	Placeholder = "tag...",
	Callback = function(text)
		print("[example] config tag:", text)
	end
})

extraSection:CreateButton({
	Name = "Print Settings",
	Callback = function()
		print("[example] button pressed")
	end
})

extraSection:CreateLabel({Text = "press Insert to hide"})
