local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/NexSync-dev/test.guilib/refs/heads/main/skeet.lua"))()

local window = library:CreateWindow({})

local combat = window:CreatePage({Icon = "rbxassetid://8547236654"})
local visuals = window:CreatePage({Icon = "rbxassetid://8547254518"})
local misc = window:CreatePage({Icon = "rbxassetid://8547249956"})

local aimbotSection = combat:CreateSection({Name = "Aimbot", Size = 280, Side = "Left"})

aimbotSection:CreateToggle({
	Name = "Enable Aimbot",
	State = false,
	Callback = function(value)
		print("Aimbot:", value)
	end
})

aimbotSection:CreateDropdown({
	Name = "Target Priority",
	State = 1,
	Options = {"Closest", "Lowest HP", "Highest Threat"},
	Callback = function(value)
		print("Priority:", value)
	end
})

aimbotSection:CreateSlider({
	Name = "FOV Radius",
	State = 120,
	Min = 10,
	Max = 500,
	Step = 1,
	Suffix = "px",
	Callback = function(value)
		print("FOV:", value)
	end
})

aimbotSection:CreateSlider({
	Name = "Smoothing",
	State = 5,
	Min = 1,
	Max = 20,
	Step = 0.5,
	Suffix = "x",
	Callback = function(value)
		print("Smoothing:", value)
	end
})

aimbotSection:CreateKeybind({
	Name = "Aimbot Key",
	State = {"UserInputType", "MouseButton2"},
	Mode = "Hold",
	Callback = function(value)
		print("Aimbot Key:", value)
	end
})

aimbotSection:CreateColorpicker({
	Name = "FOV Color",
	State = Color3.fromRGB(255, 0, 0),
	Callback = function(color)
		print("FOV Color:", color)
	end
})

local weaponSection = combat:CreateSection({Name = "Weapon", Size = 200, Side = "Right"})

weaponSection:CreateToggle({
	Name = "No Recoil",
	State = false,
	Callback = function(value)
		print("No Recoil:", value)
	end
})

weaponSection:CreateToggle({
	Name = "No Spread",
	State = false,
	Callback = function(value)
		print("No Spread:", value)
	end
})

weaponSection:CreateToggle({
	Name = "Rapid Fire",
	State = false,
	Callback = function(value)
		print("Rapid Fire:", value)
	end
})

weaponSection:CreateSlider({
	Name = "Fire Rate Multiplier",
	State = 1,
	Min = 1,
	Max = 10,
	Step = 0.5,
	Suffix = "x",
	Callback = function(value)
		print("Fire Rate:", value)
	end
})

weaponSection:CreateButton({
	Name = "Reset Weapon Stats",
	Callback = function()
		print("Weapon stats reset!")
	end
})

local espSection = visuals:CreateSection({Name = "Player ESP", Size = 330, Side = "Left"})

espSection:CreateToggle({
	Name = "Bounding Box",
	State = true,
	Callback = function(value)
		print("Box ESP:", value)
	end
})

espSection:CreateToggle({
	Name = "Name Tags",
	State = true,
	Callback = function(value)
		print("Name Tags:", value)
	end
})

espSection:CreateToggle({
	Name = "Health Bar",
	State = true,
	Callback = function(value)
		print("Health Bar:", value)
	end
})

espSection:CreateToggle({
	Name = "Tracers",
	State = false,
	Callback = function(value)
		print("Tracers:", value)
	end
})

espSection:CreateToggle({
	Name = "Skeleton",
	State = false,
	Callback = function(value)
		print("Skeleton:", value)
	end
})

espSection:CreateColorpicker({
	Name = "ESP Color",
	State = Color3.fromRGB(50, 200, 100),
	Callback = function(color)
		print("ESP Color:", color)
	end
})

espSection:CreateMultibox({
	Name = "Show Info",
	State = {1, 3},
	Options = {"Name", "Health", "Distance", "Weapon", "Team"},
	Callback = function(value)
		print("Show Info:", value)
	end
})

espSection:CreateSlider({
	Name = "Max Distance",
	State = 500,
	Min = 50,
	Max = 2000,
	Step = 10,
	Suffix = " studs",
	Callback = function(value)
		print("Max Distance:", value)
	end
})

espSection:CreateSlider({
	Name = "Transparency",
	State = 0,
	Min = 0,
	Max = 100,
	Step = 1,
	Suffix = "%",
	Callback = function(value)
		print("Transparency:", value)
	end
})

local effectsSection = visuals:CreateSection({Name = "Effects", Size = 200, Side = "Right"})

effectsSection:CreateToggle({
	Name = "Fullbright",
	State = false,
	Callback = function(value)
		print("Fullbright:", value)
	end
})

effectsSection:CreateToggle({
	Name = "Remove Fog",
	State = false,
	Callback = function(value)
		print("Remove Fog:", value)
	end
})

effectsSection:CreateDropdown({
	Name = "Sky Override",
	State = 1,
	Options = {"None", "Night", "Sunset", "Galaxy"},
	Callback = function(value)
		print("Sky Override:", value)
	end
})

effectsSection:CreateSlider({
	Name = "Ambient Brightness",
	State = 50,
	Min = 0,
	Max = 100,
	Step = 1,
	Suffix = "%",
	Callback = function(value)
		print("Brightness:", value)
	end
})

local utilitySection = misc:CreateSection({Name = "Utilities", Size = 250, Side = "Left"})

utilitySection:CreateToggle({
	Name = "Anti-AFK",
	State = false,
	Callback = function(value)
		print("Anti-AFK:", value)
	end
})

utilitySection:CreateToggle({
	Name = "Infinite Jump",
	State = false,
	Callback = function(value)
		print("Inf Jump:", value)
	end
})

utilitySection:CreateSlider({
	Name = "Walk Speed",
	State = 16,
	Min = 0,
	Max = 200,
	Step = 1,
	Suffix = "",
	Callback = function(value)
		print("Walk Speed:", value)
	end
})

utilitySection:CreateSlider({
	Name = "Jump Power",
	State = 50,
	Min = 0,
	Max = 500,
	Step = 1,
	Suffix = "",
	Callback = function(value)
		print("Jump Power:", value)
	end
})

utilitySection:CreateTextBox({
	Name = "Chat Message",
	State = "",
	Callback = function(value)
		print("Chat:", value)
	end
})

utilitySection:CreateButton({
	Name = "Rejoin Server",
	Callback = function()
		game:GetService("TeleportService"):Teleport(game.PlaceId, game:GetService("Players").LocalPlayer)
	end
})

local playerSection = misc:CreateSection({Name = "Player", Size = 200, Side = "Right"})

playerSection:CreateToggle({
	Name = "Noclip",
	State = false,
	Callback = function(value)
		print("Noclip:", value)
	end
})

playerSection:CreateToggle({
	Name = "Fly",
	State = false,
	Callback = function(value)
		print("Fly:", value)
	end
})

playerSection:CreateSlider({
	Name = "Fly Speed",
	State = 50,
	Min = 1,
	Max = 500,
	Step = 1,
	Suffix = "",
	Callback = function(value)
		print("Fly Speed:", value)
	end
})

playerSection:CreateKeybind({
	Name = "Fly Toggle",
	State = {"KeyCode", "F"},
	Mode = "Toggle",
	Callback = function(value)
		print("Fly Key:", value)
	end
})

-- Pop-out developer window: a fully independent second window
-- demonstrating multi-window isolation and the extension API.
-- Toggle it with F9 or the button in the Utility section.
local runService = game:GetService("RunService")
local players = game:GetService("Players")

local previewWindow = library:CreateWindow({})
previewWindow:SetToggleKey(Enum.KeyCode.F9)
local previewPage = previewWindow:CreatePage({Icon = "rbxassetid://8547254518"})
local previewSection = previewPage:CreateSection({Name = "3D Preview", Size = 300, Side = "Left"})
previewSection:CreateToggle({
	Name = "Rotate",
	State = true,
	Callback = function(value)
		print("Rotate:", value)
	end
})
previewSection:CreateButton({
	Name = "Unload Preview Window",
	Callback = function()
		previewWindow:Unload()
	end
})

local function buildModelViewer()
	local char = players.LocalPlayer.Character or players.LocalPlayer.CharacterAdded:Wait()
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local container = Instance.new("ViewportFrame")
	container.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
	container.BackgroundTransparency = 0
	container.BorderSizePixel = 0
	container.Size = UDim2.fromOffset(290, 240)
	container.CurrentCamera = Instance.new("Camera")

	local rig = char:Clone()
	rig.Parent = container
	rig.PrimaryPart = rig:FindFirstChild("HumanoidRootPart")

	local camera = container.CurrentCamera
	local angle = 0
	local connection = runService.RenderStepped:Connect(function(dt)
		if not container.Parent then return end
		local pivot = rig.PrimaryPart and rig.PrimaryPart.CFrame
		if not pivot then return end
		angle = angle + dt
		local cam = pivot * CFrame.Angles(0, angle, 0) * CFrame.new(0, 2.5, -7)
		camera.CFrame = CFrame.lookAt(cam.Position, pivot.Position + Vector3.new(0, 1, 0))
	end)

	previewWindow:RegisterConnection(connection)
	previewWindow:AddInstance(container)
	container.Parent = previewPage.Right
end

task.delay(0.5, buildModelViewer)

utilitySection:CreateButton({
	Name = "Toggle Preview",
	Callback = function()
		previewWindow.Enabled = not previewWindow.Enabled
		previewWindow:Fade(previewWindow.Enabled)
	end
})
