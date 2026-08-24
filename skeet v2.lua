local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")

local FONT = Enum.Font.Arial
local FONT_BOLD = Enum.Font.ArialBold

local TITLE_H = 12
local ROW_PAD = 2
local COLLAPSED_H = 72
local DEFAULT_SIZE = Vector2.new(660, 480)

local Theme = {
	Accent = Color3.fromRGB(147, 197, 57),
	WindowBg = Color3.fromRGB(13, 13, 13),
	Pinstripe = Color3.fromRGB(21, 21, 21),
	GroupBg = Color3.fromRGB(17, 17, 17),
	BorderOuter = Color3.fromRGB(10, 10, 10),
	BorderInner = Color3.fromRGB(48, 48, 48),
	PopupBorderInner = Color3.fromRGB(60, 60, 60),
	TabBg = Color3.fromRGB(12, 12, 12),
	Text = Color3.fromRGB(213, 213, 213),
	TextDim = Color3.fromRGB(100, 100, 100),
	TextHover = Color3.fromRGB(185, 185, 185),
	TextSoft = Color3.fromRGB(162, 162, 162),
	TextShadow = Color3.fromRGB(2, 2, 2),
	KeyIdle = Color3.fromRGB(90, 90, 90),
	Listening = Color3.fromRGB(255, 16, 16),
	FrameTop = Color3.fromRGB(31, 31, 31),
	FrameBottom = Color3.fromRGB(36, 36, 36),
	FrameTopHover = Color3.fromRGB(41, 41, 41),
	FrameBottomHover = Color3.fromRGB(46, 46, 46),
	FrameTopActive = Color3.fromRGB(51, 51, 51),
	FrameBottomActive = Color3.fromRGB(56, 56, 56),
	CheckTop = Color3.fromRGB(76, 76, 76),
	CheckBottom = Color3.fromRGB(51, 51, 51),
	CheckTopHover = Color3.fromRGB(86, 86, 86),
	CheckBottomHover = Color3.fromRGB(61, 61, 61),
	TrackTop = Color3.fromRGB(52, 52, 52),
	TrackBottom = Color3.fromRGB(68, 68, 68),
	TrackTopHover = Color3.fromRGB(62, 62, 62),
	TrackBottomHover = Color3.fromRGB(78, 78, 78),
	ItemHover = Color3.fromRGB(24, 24, 24),
	ScrollbarGrab = Color3.fromRGB(65, 65, 65),
	PopupBg = Color3.fromRGB(40, 40, 40),
	AlphaTrackBg = Color3.fromRGB(26, 26, 26),
	RainbowA = Color3.fromRGB(55, 177, 218),
	RainbowB = Color3.fromRGB(201, 84, 192),
	RainbowC = Color3.fromRGB(204, 227, 54),
}

local library = {
	Windows = {},
	AccentListeners = {},
	Accent = Theme.Accent,
}

local window = {}
local tabs = {}
local subtabs = {}
local groupboxes = {}

window.__index = window
tabs.__index = tabs
subtabs.__index = subtabs
groupboxes.__index = groupboxes

local function Resolve(props, keys, default)
	if not props then
		return default
	end
	for _, key in ipairs(keys) do
		local value = props[key]
		if value ~= nil then
			return value
		end
	end
	return default
end

local function Create(class, props)
	local inst = Instance.new(class)
	if props then
		for key, value in pairs(props) do
			if key ~= "Parent" then
				inst[key] = value
			end
		end
		inst.Parent = props.Parent
	end
	return inst
end

local function Connect(store, signal, fn)
	local conn = signal:Connect(fn)
	if store and store.Connections then
		table.insert(store.Connections, conn)
	end
	return conn
end

local function Stroke(inst, color, thickness)
	return Create("UIStroke", {
		Color = color or Theme.BorderOuter,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = inst,
	})
end

local function VGradient(inst, top, bottom)
	return Create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(top, bottom),
		Parent = inst,
	})
end

local function Darken(color, factor)
	return Color3.new(color.R * factor, color.G * factor, color.B * factor)
end

local function GetTextWidth(text, size, font)
	local ok, result = pcall(function()
		return TextService:GetTextSize(text, size, font, Vector2.new(10000, 10000)).X
	end)
	if ok and result then
		return result
	end
	return #text * size * 0.55
end

local function ShadowText(parent, order, props)
	local z = order or 1
	local shadowProps = {}
	for key, value in pairs(props) do
		shadowProps[key] = value
	end
	shadowProps.TextColor3 = Theme.TextShadow
	shadowProps.ZIndex = z
	shadowProps.Position = UDim2.new(
		props.Position.X.Scale,
		props.Position.X.Offset + 1,
		props.Position.Y.Scale,
		props.Position.Y.Offset + 1
	)
	shadowProps.Parent = parent
	Create("TextLabel", shadowProps)

	props.ZIndex = z + 1
	props.Parent = parent
	return Create("TextLabel", props)
end

local function Pinstripe(parent, width)
	local holder = Create("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(0, width - 2, 1, -2),
		ClipsDescendants = true,
		Parent = parent,
	})
	for x = 1, width - 3, 2 do
		Create("Frame", {
			BackgroundColor3 = Theme.Pinstripe,
			BorderSizePixel = 0,
			Position = UDim2.new(0, x, 0, 0),
			Size = UDim2.new(0, 1, 1, 0),
			Parent = holder,
		})
	end
	return holder
end

local function GetMouse()
	return UserInputService:GetMouseLocation()
end

local function InBounds(position, size, point)
	return point.X >= position.X
		and point.Y >= position.Y
		and point.X <= position.X + size.X
		and point.Y <= position.Y + size.Y
end

local function GetViewport()
	local camera = workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	return Vector2.new(1920, 1080)
end

local function ParseHex(text)
	text = string.gsub(text or "", "#", "")
	text = string.gsub(text, "%s", "")
	if #text ~= 6 then
		return nil
	end
	local r = tonumber(string.sub(text, 1, 2), 16)
	local g = tonumber(string.sub(text, 3, 4), 16)
	local b = tonumber(string.sub(text, 5, 6), 16)
	if r and g and b then
		return Color3.fromRGB(r, g, b)
	end
	return nil
end

function library:OnAccent(target, fn)
	table.insert(self.AccentListeners, { Target = target, Fn = fn })
end

function library:SetAccent(color)
	if typeof(color) ~= "Color3" then
		return
	end
	self.Accent = color
	for _, listener in ipairs(self.AccentListeners) do
		pcall(listener.Fn, color)
	end
end

function library:Unload()
	for index = #self.Windows, 1, -1 do
		self.Windows[index]:Unload()
	end
end

local function ResolveParent()
	if type(gethui) == "function" then
		local ok, ui = pcall(gethui)
		if ok and ui then
			return ui
		end
	end
	local ok, coreGui = pcall(function()
		return game:GetService("CoreGui")
	end)
	if ok and coreGui then
		local writeOk = pcall(function()
			local probe = Instance.new("Folder")
			probe.Parent = coreGui
			probe:Destroy()
		end)
		if writeOk then
			return coreGui
		end
	end
	local player = game:GetService("Players").LocalPlayer
	return player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui")
end

function library:CreateWindow(props)
	props = props or {}

	local size = Resolve(props, {"Size", "size"}, DEFAULT_SIZE)
	if typeof(size) ~= "Vector2" then
		size = DEFAULT_SIZE
	end

	local self = setmetatable({}, window)
	self.Connections = {}
	self.Tabs = {}
	self.ActiveTab = nil
	self.ActivePopup = nil
	self.PopupConns = nil
	self.Collapsed = false
	self.ExpandedSize = nil
	self.Unloaded = false
	self.ToggleKey = Resolve(props, {"ToggleKey", "togglekey", "Key", "key"}, Enum.KeyCode.Insert)

	local viewport = GetViewport()
	local startX = math.floor(math.clamp((viewport.X - size.X) / 2, 0, viewport.X))
	local startY = math.floor(math.clamp((viewport.Y - size.Y) / 2, 0, viewport.Y))

	self.Gui = Create("ScreenGui", {
		Name = "skeet_v2",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 999,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = ResolveParent(),
	})

	self.Root = Create("Frame", {
		BackgroundColor3 = Theme.WindowBg,
		BorderSizePixel = 0,
		Position = UDim2.new(0, startX, 0, startY),
		Size = UDim2.new(0, size.X, 0, size.Y),
		ClipsDescendants = true,
		Parent = self.Gui,
	})
	Stroke(self.Root, Theme.BorderOuter, 1)

	Pinstripe(self.Root, size.X)

	local innerLine = Create("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		Parent = self.Root,
	})
	Stroke(innerLine, Theme.PopupBorderInner, 1)

	local rainbow = Create("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 6, 0, 4),
		Size = UDim2.new(1, -12, 0, 2),
		Parent = self.Root,
	})
	Create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Theme.RainbowA),
			ColorSequenceKeypoint.new(0.5, Theme.RainbowB),
			ColorSequenceKeypoint.new(1, Theme.RainbowC),
		}),
		Parent = rainbow,
	})

	Create("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.57,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = rainbow,
	})

	self.TitleBar = Create("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 0, 10),
		Size = UDim2.new(1, -16, 0, 22),
		Parent = self.Root,
	})

	local name = Resolve(props, {"Name", "name", "Title", "title"}, "skeet")
	ShadowText(self.TitleBar, 2, {
		Text = name,
		Font = FONT_BOLD,
		TextSize = 12,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 2, 0, 0),
		Size = UDim2.new(1, -110, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	self.MinButton = Create("TextButton", {
		BackgroundColor3 = Theme.TabBg,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Position = UDim2.new(1, -54, 0, 3),
		Size = UDim2.new(0, 24, 0, 16),
		Parent = self.TitleBar,
	})
	Stroke(self.MinButton, Theme.BorderInner, 1)

	self.MinLabel = Create("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		Font = FONT,
		TextSize = 12,
		Text = "\u{2013}",
		TextColor3 = Theme.TextDim,
		Parent = self.MinButton,
	})

	self.CloseButton = Create("TextButton", {
		BackgroundColor3 = Theme.TabBg,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Position = UDim2.new(1, -28, 0, 3),
		Size = UDim2.new(0, 24, 0, 16),
		Parent = self.TitleBar,
	})
	Stroke(self.CloseButton, Theme.BorderInner, 1)

	self.CloseLabel = Create("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		Font = FONT,
		TextSize = 12,
		Text = "\u{00D7}",
		TextColor3 = Theme.TextDim,
		Parent = self.CloseButton,
	})

	self.TabBar = Create("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 0, 36),
		Size = UDim2.new(1, -16, 0, 32),
		ClipsDescendants = true,
		Parent = self.Root,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = self.TabBar,
	})

	self.Content = Create("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 0, 72),
		Size = UDim2.new(1, -16, 1, -80),
		ClipsDescendants = true,
		Parent = self.Root,
	})

	self.Catcher = Create("TextButton", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		Size = UDim2.new(1, 0, 1, 0),
		Visible = false,
		AutoButtonColor = false,
		Parent = self.Root,
	})

	self.Overlay = Create("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		Visible = false,
		Parent = self.Root,
	})

	Connect(self, self.Catcher.Activated, function()
		self:ClosePopup()
	end)

	Connect(self, self.MinButton.Activated, function()
		self:SetCollapsed(not self.Collapsed)
	end)

	Connect(self, self.CloseButton.Activated, function()
		self:Unload()
	end)

	Connect(self, self.MinButton.MouseEnter, function()
		self.MinLabel.TextColor3 = Theme.TextHover
	end)
	Connect(self, self.MinButton.MouseLeave, function()
		self.MinLabel.TextColor3 = Theme.TextDim
	end)
	Connect(self, self.CloseButton.MouseEnter, function()
		self.CloseLabel.TextColor3 = Theme.TextHover
	end)
	Connect(self, self.CloseButton.MouseLeave, function()
		self.CloseLabel.TextColor3 = Theme.TextDim
	end)

	local dragState = nil
	Connect(self, self.TitleBar.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self:ClosePopup()
			local mouse = GetMouse()
			dragState = {
				DX = mouse.X - self.Root.Position.X.Offset,
				DY = mouse.Y - self.Root.Position.Y.Offset,
			}
		end
	end)

	Connect(self, UserInputService.InputChanged, function(input)
		if not dragState then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local mouse = GetMouse()
			local bounds = GetViewport()
			local x = math.clamp(mouse.X - dragState.DX, -self.Root.AbsoluteSize.X + 120, bounds.X - 120)
			local y = math.clamp(mouse.Y - dragState.DY, 0, bounds.Y - 40)
			self.Root.Position = UDim2.new(0, math.floor(x), 0, math.floor(y))
		end
	end)

	Connect(self, UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragState = nil
		end
	end)

	Connect(self, UserInputService.InputBegan, function(input, processed)
		if processed or self.Unloaded then
			return
		end
		if input.KeyCode == self.ToggleKey then
			self:Toggle()
		end
	end)

	table.insert(library.Windows, self)
	return self
end

function window:ClosePopup()
	if self.PopupConns then
		for _, conn in ipairs(self.PopupConns) do
			pcall(function()
				conn:Disconnect()
			end)
		end
		self.PopupConns = nil
	end
	if self.ActivePopup then
		self.ActivePopup.Visible = false
		self.ActivePopup = nil
	end
	self.Overlay.Visible = false
	self.Catcher.Visible = false
end

function window:OpenPopup(popupFrame, anchor, scrollables, width)
	self:ClosePopup()

	if width then
		popupFrame.Size = UDim2.new(0, width, 0, popupFrame.Size.Y.Offset)
	end

	local rootPos = self.Root.AbsolutePosition
	local rootSize = self.Root.AbsoluteSize
	local anchorPos = anchor.AbsolutePosition
	local anchorSize = anchor.AbsoluteSize
	local popupWidth = popupFrame.Size.X.Offset
	local popupHeight = popupFrame.Size.Y.Offset

	local x = anchorPos.X - rootPos.X
	local y = anchorPos.Y - rootPos.Y + anchorSize.Y + 2

	if x + popupWidth > rootSize.X - 4 then
		x = rootSize.X - popupWidth - 4
	end
	if x < 4 then
		x = 4
	end
	if y + popupHeight > rootSize.Y - 4 then
		y = anchorPos.Y - rootPos.Y - popupHeight - 2
	end
	if y < 4 then
		y = 4
	end

	popupFrame.Position = UDim2.new(0, math.floor(x), 0, math.floor(y))
	popupFrame.Visible = true
	self.Overlay.Visible = true
	self.Catcher.Visible = true
	self.ActivePopup = popupFrame
	self.PopupConns = {}

	table.insert(self.PopupConns, UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local mouse = GetMouse()
			if not InBounds(rootPos, rootSize, mouse) then
				self:ClosePopup()
			end
		end
	end))

	if scrollables then
		for _, scrollable in ipairs(scrollables) do
			if scrollable and scrollable.Parent then
				table.insert(
					self.PopupConns,
					scrollable:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
						self:ClosePopup()
					end)
				)
			end
		end
	end
end

function window:CreateTab(props)
	local tabName = Resolve(props, {"Name", "name", "Text", "text", "Title", "title"}, "Tab")
	local icon = Resolve(props, {"Icon", "icon"}, nil)

	local tab = setmetatable({}, tabs)
	tab.Window = self
	tab.Active = false
	tab.Subtabs = {}
	tab.ActiveSubtab = nil

	local textWidth = GetTextWidth(tabName, 12, FONT)
	local cellWidth = math.max(64, (icon and 22 or 0) + textWidth + 28)

	tab.Cell = Create("TextButton", {
		BackgroundColor3 = Theme.TabBg,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Size = UDim2.new(0, cellWidth, 0, 32),
		LayoutOrder = #self.Tabs + 1,
		Parent = self.TabBar,
	})
	Stroke(tab.Cell, Theme.BorderInner, 1)

	local cellInner = Create("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		Parent = tab.Cell,
	})
	Stroke(cellInner, Color3.fromRGB(0, 0, 0), 1)

	if icon then
		Create("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 8, 0.5, -9),
			Size = UDim2.new(0, 18, 0, 18),
			Image = icon,
			Parent = tab.Cell,
		})
	end

	tab.CellLabel = Create("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, icon and 30 or 0, 0, 0),
		Size = UDim2.new(1, icon and -34 or 0, 1, 0),
		Font = FONT,
		TextSize = 12,
		Text = tabName,
		TextColor3 = Theme.TextDim,
		TextXAlignment = icon and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = tab.Cell,
	})

	tab.Content = Create("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		Visible = false,
		Parent = self.Content,
	})

	Connect(self, tab.Cell.Activated, function()
		tab:Select()
	end)
	Connect(self, tab.Cell.MouseEnter, function()
		if not tab.Active then
			tab.CellLabel.TextColor3 = Theme.TextHover
		end
	end)
	Connect(self, tab.Cell.MouseLeave, function()
		if not tab.Active then
			tab.CellLabel.TextColor3 = Theme.TextDim
		end
	end)

	table.insert(self.Tabs, tab)

	if #self.Tabs == 1 then
		tab:Select()
	end

	return tab
end

function tabs:Select()
	local owner = self.Window
	if not owner then
		return
	end
	for _, tab in ipairs(owner.Tabs) do
		local active = (tab == self)
		tab.Active = active
		tab.Content.Visible = active
		tab.Cell.BackgroundTransparency = active and 1 or 0
		tab.CellLabel.TextColor3 = active and Theme.Text or Theme.TextDim
	end
	owner.ActiveTab = self
	owner:ClosePopup()
end

function tabs:CreateSubTab(props)
	local subName = Resolve(props, {"Name", "name", "Text", "text", "Title", "title"}, "Subtab")
	local hidden = Resolve(props, {"Hidden", "hidden"}, false) == true
	local owner = self.Window

	local sub = setmetatable({}, subtabs)
	sub.Tab = self
	sub.Window = owner
	sub.Active = false
	sub.Hidden = hidden
	sub.LeftCount = 0
	sub.RightCount = 0

	if #self.Subtabs == 0 then
		self.SubtabBar = Create("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 24),
			Visible = false,
			Parent = self.Content,
		})
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = self.SubtabBar,
		})
		self.SubtabArea = Create("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 26),
			Size = UDim2.new(1, 0, 1, -26),
			Parent = self.Content,
		})
	end

	if not hidden then
		local textWidth = GetTextWidth(subName, 12, FONT)

		sub.Button = Create("TextButton", {
			BackgroundColor3 = Theme.ItemHover,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			Size = UDim2.new(0, textWidth + 20, 0, 24),
			LayoutOrder = #self.Subtabs + 1,
			Parent = self.SubtabBar,
		})

		sub.Label = Create("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			Font = FONT,
			TextSize = 12,
			Text = subName,
			TextColor3 = Theme.TextDim,
			Parent = sub.Button,
		})

		sub.Underline = Create("Frame", {
			BackgroundColor3 = library.Accent,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, -textWidth / 2, 1, -2),
			Size = UDim2.new(0, textWidth, 0, 2),
			Visible = false,
			Parent = sub.Button,
		})

		Connect(owner, sub.Button.Activated, function()
			sub:Select()
		end)
		Connect(owner, sub.Button.MouseEnter, function()
			if not sub.Active then
				sub.Button.BackgroundTransparency = 0
				sub.Button.BackgroundColor3 = Theme.ItemHover
				sub.Label.TextColor3 = Theme.TextHover
			end
		end)
		Connect(owner, sub.Button.MouseLeave, function()
			if not sub.Active then
				sub.Button.BackgroundTransparency = 1
				sub.Label.TextColor3 = Theme.TextDim
			end
		end)
	end

	sub.Content = Create("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		Visible = false,
		Parent = self.SubtabArea,
	})

	sub.LeftColumn = Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(0.5, -9, 1, 0),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.ScrollbarGrab,
		ScrollBarImageTransparency = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = sub.Content,
	})
	Create("UIListLayout", {
		Padding = UDim.new(0, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = sub.LeftColumn,
	})

	sub.RightColumn = Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 9, 0, 0),
		Size = UDim2.new(0.5, -9, 1, 0),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.ScrollbarGrab,
		ScrollBarImageTransparency = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = sub.Content,
	})
	Create("UIListLayout", {
		Padding = UDim.new(0, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = sub.RightColumn,
	})

	if sub.Underline then
		library:OnAccent(owner, function(color)
			sub.Underline.BackgroundColor3 = color
		end)
	end

	table.insert(self.Subtabs, sub)

	local explicitCount = 0
	for _, existing in ipairs(self.Subtabs) do
		if not existing.Hidden then
			explicitCount = explicitCount + 1
		end
	end

	if explicitCount > 1 then
		self.SubtabBar.Visible = true
	end

	if #self.Subtabs == 1 then
		sub:Select()
	end

	return sub
end

function tabs:CreateGroupbox(props)
	local hasExplicit = false
	for _, sub in ipairs(self.Subtabs) do
		if not sub.Hidden then
			hasExplicit = true
			break
		end
	end

	local target
	if hasExplicit then
		target = self.ActiveSubtab or self.Subtabs[1]
	else
		if not self.DefaultSubtab then
			self.DefaultSubtab = self:CreateSubTab({Name = "Default", Hidden = true})
		end
		target = self.DefaultSubtab
	end

	return target:CreateGroupbox(props)
end

function subtabs:Select()
	local parentTab = self.Tab
	for _, sub in ipairs(parentTab.Subtabs) do
		local active = (sub == self)
		sub.Active = active
		sub.Content.Visible = active
		if sub.Button then
			sub.Button.BackgroundTransparency = 1
			sub.Label.TextColor3 = active and Theme.Text or Theme.TextDim
			sub.Underline.Visible = active
		end
	end
	parentTab.ActiveSubtab = self
	if self.Window then
		self.Window:ClosePopup()
	end
end

function subtabs:CreateGroupbox(props)
	local groupName = Resolve(props, {"Name", "name", "Text", "text", "Title", "title"}, "Groupbox")
	local side = string.lower(tostring(Resolve(props, {"Side", "side", "Column", "column"}, "Left")))
	local height = Resolve(props, {"Size", "size", "Height", "height"}, 300)
	if type(height) ~= "number" or height < 60 then
		height = 300
	end

	local owner = self.Window
	local gb = setmetatable({}, groupboxes)
	gb.Subtab = self
	gb.Window = owner
	gb.Connections = owner.Connections
	gb.Order = 0

	local isRight = (side == "right" or side == "2")
	gb.Column = isRight and self.RightColumn or self.LeftColumn

	if isRight then
		self.RightCount = self.RightCount + 1
		gb.ColumnOrder = self.RightCount
	else
		self.LeftCount = self.LeftCount + 1
		gb.ColumnOrder = self.LeftCount
	end

	gb.Container = Create("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height + 6),
		ClipsDescendants = false,
		LayoutOrder = gb.ColumnOrder,
		Parent = gb.Column,
	})

	local outer = Create("Frame", {
		BackgroundColor3 = Theme.GroupBg,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 6),
		Size = UDim2.new(1, 0, 1, -6),
		Parent = gb.Container,
	})
	Stroke(outer, Theme.BorderOuter, 1)

	local inner = Create("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		Parent = outer,
	})
	Stroke(inner, Theme.BorderInner, 1)

	gb.Scroll = Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 1, 0, TITLE_H),
		Size = UDim2.new(1, -2, 1, -(TITLE_H + 1)),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.ScrollbarGrab,
		ScrollBarImageTransparency = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ClipsDescendants = true,
		Parent = inner,
	})
	Create("UIListLayout", {
		Padding = UDim.new(0, ROW_PAD),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = gb.Scroll,
	})

	local titleWidth = GetTextWidth(groupName, 12, FONT_BOLD)

	Create("Frame", {
		BackgroundColor3 = Theme.GroupBg,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 10, 0, 5),
		Size = UDim2.new(0, titleWidth + 14, 0, 14),
		ZIndex = 3,
		Parent = gb.Container,
	})

	ShadowText(gb.Container, 3, {
		Text = groupName,
		Font = FONT_BOLD,
		TextSize = 12,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 16, 0, 0),
		Size = UDim2.new(0, titleWidth + 30, 0, 12),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	return gb
end

local function NextOrder(gb)
	gb.Order = gb.Order + 1
	return gb.Order
end

local function CreateRow(gb, height, interactive)
	local props = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = NextOrder(gb),
		Parent = gb.Scroll,
	}
	if interactive then
		props.Text = ""
		props.AutoButtonColor = false
		return Create("TextButton", props)
	end
	return Create("Frame", props)
end

function groupboxes:CreateToggle(props)
	local elementName = Resolve(props, {"Name", "name", "Text", "text"}, "Toggle")
	local state = Resolve(props, {"Default", "default", "State", "state"}, false) == true
	local callback = Resolve(props, {"Callback", "callback", "Function", "function"}, nil)

	local row = CreateRow(self, 16, true)

	Create("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 0, 1),
		Size = UDim2.new(0, 14, 0, 14),
		Parent = row,
	})

	local box = row:FindFirstChildOfClass("Frame")
	local fill = Create("Frame", {
		BorderSizePixel = 0,
		Position = UDim2.new(0, 3, 0, 3),
		Size = UDim2.new(0, 8, 0, 8),
		Parent = box,
	})
	local fillGradient = VGradient(fill, Theme.CheckTop, Theme.CheckBottom)
	Stroke(fill, Theme.BorderOuter, 1)

	Create("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 27, 0, 0),
		Size = UDim2.new(1, -35, 1, 0),
		Font = FONT,
		TextSize = 12,
		Text = elementName,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})

	local element = {Type = "Toggle", Row = row}
	element.State = state
	local hovered = false

	local function paint()
		local top, bottom
		if element.State then
			top = library.Accent
			bottom = Darken(library.Accent, 0.6)
		elseif hovered then
			top = Theme.CheckTopHover
			bottom = Theme.CheckBottomHover
		else
			top = Theme.CheckTop
			bottom = Theme.CheckBottom
		end
		fillGradient.Color = ColorSequence.new(top, bottom)
	end

	Connect(self.Window, row.MouseEnter, function()
		hovered = true
		paint()
	end)
	Connect(self.Window, row.MouseLeave, function()
		hovered = false
		paint()
	end)
	Connect(self.Window, row.Activated, function()
		element.State = not element.State
		paint()
		if callback then
			pcall(callback, element.State)
		end
	end)

	library:OnAccent(self.Window, paint)

	function element:Get()
		return element.State
	end

	function element:Set(value, fire)
		element.State = value == true
		paint()
		if fire and callback then
			pcall(callback, element.State)
		end
	end

	function element:SetVisible(visible)
		row.Visible = visible == true
	end

	paint()
	return element
end

function groupboxes:CreateSlider(props)
	local elementName = Resolve(props, {"Name", "name", "Text", "text"}, "Slider")
	local minValue = Resolve(props, {"Min", "min", "Minimum", "minimum"}, 0)
	local maxValue = Resolve(props, {"Max", "max", "Maximum", "maximum"}, 100)
	if type(minValue) ~= "number" or type(maxValue) ~= "number" then
		minValue, maxValue = 0, 100
	end
	if maxValue < minValue then
		minValue, maxValue = maxValue, minValue
	end
	local step = Resolve(props, {"Step", "step", "Tick", "tick", "Decimals", "decimals"}, 1)
	if type(step) ~= "number" or step <= 0 then
		step = 1
	end
	local suffix = Resolve(props, {"Suffix", "suffix", "Unit", "unit"}, "")
	local value = Resolve(props, {"Default", "default", "State", "state", "Value", "value"}, minValue)
	local callback = Resolve(props, {"Callback", "callback", "Function", "function"}, nil)

	local decimals = 0
	local stepScale = step
	while stepScale < 0.9999 and decimals < 6 do
		stepScale = stepScale * 10
		decimals = decimals + 1
	end

	local row = CreateRow(self, 34, false)

	Create("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 0, 0),
		Size = UDim2.new(1, -16, 0, 12),
		Font = FONT,
		TextSize = 12,
		Text = elementName,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})

	local track = Create("TextButton", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Position = UDim2.new(0, 8, 0, 17),
		Size = UDim2.new(1, -16, 0, 14),
		ClipsDescendants = true,
		Parent = row,
	})
	local trackGradient = VGradient(track, Theme.TrackTop, Theme.TrackBottom)
	Stroke(track, Theme.BorderOuter, 1)

	local fill = Create("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.new(0, 0, 1, 0),
		Parent = track,
	})
	local fillGradient = VGradient(fill, library.Accent, Darken(library.Accent, 0.55))

	local valueShadow = Create("TextLabel", {
		BackgroundColor3 = Theme.TextShadow,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 1),
		Size = UDim2.new(0, 90, 0, 12),
		Font = FONT_BOLD,
		TextSize = 11,
		Text = "",
		TextColor3 = Theme.TextShadow,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 2,
		Parent = track,
	})

	local valueLabel = Create("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 1, 0, 0),
		Size = UDim2.new(0, 90, 0, 12),
		Font = FONT_BOLD,
		TextSize = 11,
		Text = "",
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
		Parent = track,
	})

	local element = {Type = "Slider", Row = row}
	element.Value = value
	local hovered = false
	local dragging = false

	local function Quantize(input)
		input = math.clamp(input, minValue, maxValue)
		local quantized = math.floor(input / step + 0.5) * step
		quantized = math.clamp(quantized, minValue, maxValue)
		return quantized
	end

	local function Format(current)
		local text
		if decimals > 0 then
			text = string.format("%0." .. decimals .. "f", current)
		else
			text = tostring(math.floor(current + 0.5))
		end
		return text .. suffix
	end

	local function paint()
		local range = maxValue - minValue
		local alpha = 1
		if range > 0 then
			alpha = (element.Value - minValue) / range
		end
		local trackWidth = track.AbsoluteSize.X
		local fillWidth = math.floor(alpha * trackWidth + 0.5)
		fill.Size = UDim2.new(0, fillWidth, 1, 0)

		local labelX = math.clamp(fillWidth - 45, 0, math.max(trackWidth - 90, 0))
		valueShadow.Position = UDim2.new(0, labelX + 1, 0, 1)
		valueLabel.Position = UDim2.new(0, labelX, 0, 0)
		valueShadow.Text = Format(element.Value)
		valueLabel.Text = Format(element.Value)

		local top, bottom
		if hovered or dragging then
			top = Theme.TrackTopHover
			bottom = Theme.TrackBottomHover
		else
			top = Theme.TrackTop
			bottom = Theme.TrackBottom
		end
		trackGradient.Color = ColorSequence.new(top, bottom)
		fillGradient.Color = ColorSequence.new(library.Accent, Darken(library.Accent, 0.55))
	end

	local function UpdateFromMouse()
		local mouse = GetMouse()
		local pos = track.AbsolutePosition
		local width = track.AbsoluteSize.X
		if width <= 0 then
			return
		end
		local alpha = math.clamp((mouse.X - pos.X) / width, 0, 1)
		local newValue = Quantize(minValue + alpha * (maxValue - minValue))
		if newValue ~= element.Value then
			element.Value = newValue
			paint()
			if callback then
				pcall(callback, element.Value)
			end
		end
	end

	Connect(self.Window, track.MouseEnter, function()
		hovered = true
		paint()
	end)
	Connect(self.Window, track.MouseLeave, function()
		hovered = false
		paint()
	end)
	Connect(self.Window, track.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			UpdateFromMouse()
		end
	end)
	Connect(self.Window, UserInputService.InputChanged, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			UpdateFromMouse()
		end
	end)
	Connect(self.Window, UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			paint()
		end
	end)
	Connect(self.Window, track:GetPropertyChangedSignal("AbsoluteSize"), paint)

	library:OnAccent(self.Window, paint)

	function element:Get()
		return element.Value
	end

	function element:Set(newValue, fire)
		element.Value = Quantize(tonumber(newValue) or minValue)
		paint()
		if fire and callback then
			pcall(callback, element.Value)
		end
	end

	function element:SetVisible(visible)
		row.Visible = visible == true
	end

	element.Value = Quantize(value)
	paint()
	return element
end

function groupboxes:CreateDropdown(props)
	local elementName = Resolve(props, {"Name", "name", "Text", "text"}, "Dropdown")
	local options = Resolve(props, {"Options", "options", "List", "list"}, {})
	if type(options) ~= "table" or #options == 0 then
		options = {"None"}
	end
	local selectedIndex = Resolve(props, {"Default", "default", "State", "state"}, 1)
	if type(selectedIndex) ~= "number" or selectedIndex < 1 or selectedIndex > #options then
		selectedIndex = 1
	end
	local callback = Resolve(props, {"Callback", "callback", "Function", "function"}, nil)

	local owner = self.Window
	local row = CreateRow(self, 36, false)

	Create("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 0, 0),
		Size = UDim2.new(1, -16, 0, 12),
		Font = FONT,
		TextSize = 12,
		Text = elementName,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})

	local frame = Create("TextButton", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Position = UDim2.new(0, 8, 0, 16),
		Size = UDim2.new(1, -16, 0, 20),
		Parent = row,
	})
	local frameGradient = VGradient(frame, Theme.FrameTop, Theme.FrameBottom)
	Stroke(frame, Theme.BorderOuter, 1)

	local preview = Create("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 6, 0, 0),
		Size = UDim2.new(1, -26, 1, 0),
		Font = FONT,
		TextSize = 12,
		Text = options[selectedIndex],
		TextColor3 = Theme.TextSoft,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})

	Create("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -16, 0, 0),
		Size = UDim2.new(0, 12, 1, 0),
		Font = FONT,
		TextSize = 10,
		Text = "\u{25BC}",
		TextColor3 = Theme.TextSoft,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = frame,
	})

	local element = {Type = "Dropdown", Row = row}
	element.Index = selectedIndex
	local frameHovered = false

	local function paintFrame()
		if frameHovered or owner.ActivePopup == popup then
			frameGradient.Color = ColorSequence.new(Theme.FrameTopHover, Theme.FrameBottomHover)
		else
			frameGradient.Color = ColorSequence.new(Theme.FrameTop, Theme.FrameBottom)
		end
	end

	local popup = Create("Frame", {
		BackgroundColor3 = Theme.PopupBg,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 100, 0, math.min(#options, 10) * 18 + 6),
		Visible = false,
		ZIndex = 5,
		Parent = owner.Overlay,
	})
	Stroke(popup, Theme.BorderOuter, 1)

	local popupInner = Create("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 5,
		Parent = popup,
	})
	Stroke(popupInner, Theme.PopupBorderInner, 1)

	local list = Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 2, 0, 2),
		Size = UDim2.new(1, -4, 1, -4),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.ScrollbarGrab,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 5,
		Parent = popupInner,
	})
	Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})

	local itemLabels = {}

	local function paintItems()
		for index, label in ipairs(itemLabels) do
			if index == element.Index then
				label.TextColor3 = library.Accent
			else
				label.TextColor3 = Theme.TextSoft
			end
		end
	end

	for index, option in ipairs(options) do
		local item = Create("TextButton", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			Size = UDim2.new(1, 0, 0, 18),
			ZIndex = 6,
			LayoutOrder = index,
			Parent = list,
		})

		local itemLabel = Create("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 6, 0, 0),
			Size = UDim2.new(1, -12, 1, 0),
			Font = FONT,
			TextSize = 12,
			Text = tostring(option),
			TextColor3 = Theme.TextSoft,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 6,
			Parent = item,
		})
		itemLabels[index] = itemLabel

		Connect(owner, item.MouseEnter, function()
			item.BackgroundTransparency = 0
			item.BackgroundColor3 = Theme.ItemHover
			itemLabel.TextColor3 = library.Accent
		end)
		Connect(owner, item.MouseLeave, function()
			item.BackgroundTransparency = 1
			if index == element.Index then
				itemLabel.TextColor3 = library.Accent
			else
				itemLabel.TextColor3 = Theme.TextSoft
			end
		end)
		Connect(owner, item.Activated, function()
			element.Index = index
			preview.Text = tostring(options[index])
			paintItems()
			owner:ClosePopup()
			paintFrame()
			if callback then
				pcall(callback, options[index], index)
			end
		end)
	end

	Connect(owner, frame.Activated, function()
		if owner.ActivePopup == popup then
			owner:ClosePopup()
		else
			owner:OpenPopup(popup, frame, {self.Scroll, self.Column}, frame.AbsoluteSize.X)
		end
		paintFrame()
	end)
	Connect(owner, frame.MouseEnter, function()
		frameHovered = true
		paintFrame()
	end)
	Connect(owner, frame.MouseLeave, function()
		frameHovered = false
		paintFrame()
	end)

	library:OnAccent(owner, paintItems)

	function element:Get()
		return options[element.Index]
	end

	function element:GetIndex()
		return element.Index
	end

	function element:Set(value, fire)
		local index = nil
		if type(value) == "number" then
			index = value
		elseif type(value) == "string" then
			for i, option in ipairs(options) do
				if option == value then
					index = i
					break
				end
			end
		end
		if index and index >= 1 and index <= #options then
			element.Index = index
			preview.Text = tostring(options[index])
			paintItems()
			if fire and callback then
				pcall(callback, options[index], index)
			end
		end
	end

	function element:SetVisible(visible)
		row.Visible = visible == true
	end

	paintItems()
	return element
end

function groupboxes:CreateMultibox(props)
	local elementName = Resolve(props, {"Name", "name", "Text", "text"}, "Multibox")
	local options = Resolve(props, {"Options", "options", "List", "list"}, {})
	if type(options) ~= "table" or #options == 0 then
		options = {"None"}
	end
	local defaults = Resolve(props, {"Default", "default", "State", "state", "Defaults"}, nil)
	local callback = Resolve(props, {"Callback", "callback", "Function", "function"}, nil)

	local owner = self.Window
	local row = CreateRow(self, 36, false)

	Create("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 0, 0),
		Size = UDim2.new(1, -16, 0, 12),
		Font = FONT,
		TextSize = 12,
		Text = elementName,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})

	local frame = Create("TextButton", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Position = UDim2.new(0, 8, 0, 16),
		Size = UDim2.new(1, -16, 0, 20),
		Parent = row,
	})
	local frameGradient = VGradient(frame, Theme.FrameTop, Theme.FrameBottom)
	Stroke(frame, Theme.BorderOuter, 1)

	local preview = Create("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 6, 0, 0),
		Size = UDim2.new(1, -26, 1, 0),
		Font = FONT,
		TextSize = 12,
		Text = "",
		TextColor3 = Theme.TextSoft,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})

	Create("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -16, 0, 0),
		Size = UDim2.new(0, 12, 1, 0),
		Font = FONT,
		TextSize = 10,
		Text = "\u{25BC}",
		TextColor3 = Theme.TextSoft,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = frame,
	})

	local element = {Type = "Multibox", Row = row}
	element.Selected = {}

	local popup = Create("Frame", {
		BackgroundColor3 = Theme.PopupBg,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 100, 0, math.min(#options, 10) * 18 + 6),
		Visible = false,
		ZIndex = 5,
		Parent = owner.Overlay,
	})
	Stroke(popup, Theme.BorderOuter, 1)

	local popupInner = Create("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 5,
		Parent = popup,
	})
	Stroke(popupInner, Theme.PopupBorderInner, 1)

	local list = Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 2, 0, 2),
		Size = UDim2.new(1, -4, 1, -4),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.ScrollbarGrab,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 5,
		Parent = popupInner,
	})
	Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})

	local checkFills = {}
	local checkGradients = {}

	local function GetSelected()
		local selected = {}
		for index, option in ipairs(options) do
			if element.Selected[index] then
				table.insert(selected, tostring(option))
			end
		end
		return selected
	end

	local function paintPreview()
		local selected = GetSelected()
		if #selected > 0 then
			preview.Text = table.concat(selected, ", ")
		else
			preview.Text = "-"
		end
	end

	local function paintCheck(index)
		local fill = checkFills[index]
		local gradient = checkGradients[index]
		if not fill then
			return
		end
		if element.Selected[index] then
			gradient.Color = ColorSequence.new(library.Accent, Darken(library.Accent, 0.6))
		else
			gradient.Color = ColorSequence.new(Theme.CheckTop, Theme.CheckBottom)
		end
	end

	local frameHovered = false
	local function paintFrame()
		if frameHovered or owner.ActivePopup == popup then
			frameGradient.Color = ColorSequence.new(Theme.FrameTopHover, Theme.FrameBottomHover)
		else
			frameGradient.Color = ColorSequence.new(Theme.FrameTop, Theme.FrameBottom)
		end
	end

	for index, option in ipairs(options) do
		local item = Create("TextButton", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			Size = UDim2.new(1, 0, 0, 18),
			ZIndex = 6,
			LayoutOrder = index,
			Parent = list,
		})

		local checkOuter = Create("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 5, 0, 4),
			Size = UDim2.new(0, 10, 0, 10),
			ZIndex = 6,
			Parent = item,
		})
		local checkFill = Create("Frame", {
			BorderSizePixel = 0,
			Position = UDim2.new(0, 2, 0, 2),
			Size = UDim2.new(0, 6, 0, 6),
			ZIndex = 6,
			Parent = checkOuter,
		})
		checkGradients[index] = VGradient(checkFill, Theme.CheckTop, Theme.CheckBottom)
		Stroke(checkFill, Theme.BorderOuter, 1)
		checkFills[index] = checkFill

		Create("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 20, 0, 0),
			Size = UDim2.new(1, -26, 1, 0),
			Font = FONT,
			TextSize = 12,
			Text = tostring(option),
			TextColor3 = Theme.TextSoft,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 6,
			Parent = item,
		})

		Connect(owner, item.MouseEnter, function()
			item.BackgroundTransparency = 0
			item.BackgroundColor3 = Theme.ItemHover
		end)
		Connect(owner, item.MouseLeave, function()
			item.BackgroundTransparency = 1
		end)
		Connect(owner, item.Activated, function()
			element.Selected[index] = not element.Selected[index] and true or nil
			paintCheck(index)
			paintPreview()
			if callback then
				pcall(callback, GetSelected())
			end
		end)
	end

	Connect(owner, frame.Activated, function()
		if owner.ActivePopup == popup then
			owner:ClosePopup()
		else
			owner:OpenPopup(popup, frame, {self.Scroll, self.Column}, frame.AbsoluteSize.X)
		end
		paintFrame()
	end)
	Connect(owner, frame.MouseEnter, function()
		frameHovered = true
		paintFrame()
	end)
	Connect(owner, frame.MouseLeave, function()
		frameHovered = false
		paintFrame()
	end)

	library:OnAccent(owner, function(color)
		for index in ipairs(options) do
			paintCheck(index)
		end
	end)

	function element:Get()
		return GetSelected()
	end

	function element:Set(selectedValues, fire)
		element.Selected = {}
		if type(selectedValues) == "table" then
			for _, value in ipairs(selectedValues) do
				for index, option in ipairs(options) do
					if option == value or index == value then
						element.Selected[index] = true
						break
					end
				end
			end
		end
		for index in ipairs(options) do
			paintCheck(index)
		end
		paintPreview()
		if fire and callback then
			pcall(callback, GetSelected())
		end
	end

	function element:SetVisible(visible)
		row.Visible = visible == true
	end

	if type(defaults) == "table" then
		element:Set(defaults, false)
	else
		paintPreview()
	end

	return element
end

local function KeyName(key)
	if typeof(key) ~= "EnumItem" then
		return "none"
	end
	if key.EnumType == Enum.UserInputType then
		local name = key.Name
		if string.sub(name, 1, 7) == "MouseButton" then
			return "Mouse" .. string.sub(name, 12)
		end
		return name
	end
	return key.Name
end

local function KeyMatches(key, input)
	if typeof(key) ~= "EnumItem" then
		return false
	end
	if key.EnumType == Enum.KeyCode then
		return input.KeyCode == key
	end
	if key.EnumType == Enum.UserInputType then
		return input.UserInputType == key
	end
	return false
end

function groupboxes:CreateKeybind(props)
	local elementName = Resolve(props, {"Name", "name", "Text", "text"}, "Keybind")
	local key = Resolve(props, {"Default", "default", "State", "state", "Key", "key"}, nil)
	local mode = Resolve(props, {"Mode", "mode"}, "Hold")
	if mode ~= "Hold" and mode ~= "Toggle" and mode ~= "Always" then
		mode = "Hold"
	end
	local callback = Resolve(props, {"Callback", "callback", "Function", "function"}, nil)

	local owner = self.Window
	local row = CreateRow(self, 16, true)

	Create("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 0, 0),
		Size = UDim2.new(1, -110, 1, 0),
		Font = FONT,
		TextSize = 12,
		Text = elementName,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})

	local keyLabel = Create("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -98, 0, 0),
		Size = UDim2.new(0, 90, 1, 0),
		Font = FONT,
		TextSize = 11,
		Text = "",
		TextColor3 = Theme.KeyIdle,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})

	local element = {Type = "Keybind", Row = row}
	element.Key = (typeof(key) == "EnumItem") and key or nil
	element.Mode = mode
	element.Active = false
	element.Listening = false

	local trackConns = {}
	local listenConn = nil

	local function paint()
		if element.Listening then
			keyLabel.Text = "[-]"
			keyLabel.TextColor3 = Theme.Listening
		elseif element.Active and element.Key then
			keyLabel.Text = KeyName(element.Key)
			keyLabel.TextColor3 = library.Accent
		else
			keyLabel.Text = KeyName(element.Key)
			keyLabel.TextColor3 = Theme.KeyIdle
		end
	end

	local function Fire(state)
		if callback then
			pcall(callback, state)
		end
	end

	local function ClearTracking()
		for _, conn in ipairs(trackConns) do
			pcall(function()
				conn:Disconnect()
			end)
		end
		trackConns = {}
	end

	local function BindTracking()
		ClearTracking()
		local wasActive = element.Active
		element.Active = (element.Mode == "Always" and element.Key ~= nil)
		if wasActive ~= element.Active then
			Fire(element.Active)
		end
		if not element.Key or element.Mode == "Always" then
			return
		end

		local function CanTrigger(processed)
			if element.Listening then
				return false
			end
			if processed then
				return false
			end
			return true
		end

		if element.Mode == "Hold" then
			table.insert(trackConns, Connect(owner, UserInputService.InputBegan, function(input, processed)
				if KeyMatches(element.Key, input) and CanTrigger(processed) then
					element.Active = true
					paint()
					Fire(true)
				end
			end))
			table.insert(trackConns, Connect(owner, UserInputService.InputEnded, function(input)
				if KeyMatches(element.Key, input) and element.Active then
					element.Active = false
					paint()
					Fire(false)
				end
			end))
		elseif element.Mode == "Toggle" then
			table.insert(trackConns, Connect(owner, UserInputService.InputBegan, function(input, processed)
				if KeyMatches(element.Key, input) and CanTrigger(processed) then
					element.Active = not element.Active
					paint()
					Fire(element.Active)
				end
			end))
		end
	end

	local function StopListening()
		element.Listening = false
		if listenConn then
			pcall(function()
				listenConn:Disconnect()
			end)
			listenConn = nil
		end
	end

	local function StartListening()
		if element.Listening then
			return
		end
		element.Listening = true
		paint()

		listenConn = UserInputService.InputBegan:Connect(function(input, processed)
			local inputType = input.UserInputType
			if inputType == Enum.UserInputType.Keyboard then
				if input.KeyCode == Enum.KeyCode.Escape then
					element.Key = nil
					StopListening()
					BindTracking()
					paint()
				elseif not processed then
					element.Key = input.KeyCode
					StopListening()
					BindTracking()
					paint()
				end
			elseif inputType == Enum.UserInputType.MouseButton1
				or inputType == Enum.UserInputType.MouseButton2
				or inputType == Enum.UserInputType.MouseButton3 then
				element.Key = inputType
				StopListening()
				BindTracking()
				paint()
			end
		end)
		table.insert(owner.Connections, listenConn)
	end

	local modePopup = Create("Frame", {
		BackgroundColor3 = Theme.PopupBg,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 80, 0, 3 * 18 + 6),
		Visible = false,
		ZIndex = 5,
		Parent = owner.Overlay,
	})
	Stroke(modePopup, Theme.BorderOuter, 1)

	local modeInner = Create("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 5,
		Parent = modePopup,
	})
	Stroke(modeInner, Theme.PopupBorderInner, 1)

	local modeLabels = {}

	local function paintModes()
		for index, label in ipairs(modeLabels) do
			label.TextColor3 = (index == element.ModeIndex) and library.Accent or Theme.TextSoft
		end
	end

	local modeNames = {"Hold", "Toggle", "Always"}
	for index, modeName in ipairs(modeNames) do
		local item = Create("TextButton", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			Size = UDim2.new(1, 0, 0, 18),
			ZIndex = 6,
			LayoutOrder = index,
			Parent = modeInner,
		})

		local itemLabel = Create("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 6, 0, 0),
			Size = UDim2.new(1, -12, 1, 0),
			Font = FONT,
			TextSize = 12,
			Text = modeName,
			TextColor3 = Theme.TextSoft,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 6,
			Parent = item,
		})
		modeLabels[index] = itemLabel

		Connect(owner, item.MouseEnter, function()
			item.BackgroundTransparency = 0
			item.BackgroundColor3 = Theme.ItemHover
		end)
		Connect(owner, item.MouseLeave, function()
			item.BackgroundTransparency = 1
		end)
		Connect(owner, item.Activated, function()
			element.Mode = modeName
			element.ModeIndex = index
			paintModes()
			owner:ClosePopup()
			BindTracking()
		end)
	end

	Connect(owner, row.Activated, function()
		StartListening()
	end)
	Connect(owner, row.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			owner:OpenPopup(modePopup, keyLabel, {self.Scroll, self.Column})
		end
	end)

	library:OnAccent(owner, paint)

	function element:Get()
		return {Key = element.Key, Mode = element.Mode, Active = element.Active}
	end

	function element:Set(config, fire)
		if type(config) ~= "table" then
			return
		end
		if typeof(config.Key) == "EnumItem" or config.Key == nil then
			element.Key = config.Key
		end
		if config.Mode == "Hold" or config.Mode == "Toggle" or config.Mode == "Always" then
			element.Mode = config.Mode
		end
		BindTracking()
		paint()
		if fire and callback then
			pcall(callback, element.Active)
		end
	end

	function element:SetVisible(visible)
		row.Visible = visible == true
	end

	element.ModeIndex = (element.Mode == "Toggle") and 2 or (element.Mode == "Always") and 3 or 1
	paintModes()
	BindTracking()
	paint()
	return element
end

function groupboxes:CreateColorpicker(props)
	local elementName = Resolve(props, {"Name", "name", "Text", "text"}, "Color")
	local defaultColor = Resolve(props, {"Default", "default", "State", "state"}, Color3.fromRGB(147, 197, 57))
	if typeof(defaultColor) ~= "Color3" then
		defaultColor = Color3.fromRGB(147, 197, 57)
	end
	local defaultAlpha = Resolve(props, {"Alpha", "alpha", "Transparency"}, 1)
	if type(defaultAlpha) ~= "number" then
		defaultAlpha = 1
	end
	defaultAlpha = math.clamp(defaultAlpha, 0, 1)
	local callback = Resolve(props, {"Callback", "callback", "Function", "function"}, nil)

	local owner = self.Window
	local row = CreateRow(self, 16, false)

	Create("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 0, 0),
		Size = UDim2.new(1, -48, 1, 0),
		Font = FONT,
		TextSize = 12,
		Text = elementName,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})

	local swatch = Create("TextButton", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Position = UDim2.new(1, -32, 0, 3),
		Size = UDim2.new(0, 24, 0, 10),
		Parent = row,
	})
	local swatchGradient = VGradient(swatch, defaultColor, Darken(defaultColor, 0.6))
	Stroke(swatch, Theme.BorderOuter, 1)

	local element = {Type = "Colorpicker", Row = row}
	local h, s, v = defaultColor:ToHSV()
	element.Alpha = defaultAlpha

	local popup = Create("Frame", {
		BackgroundColor3 = Theme.PopupBg,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 170, 0, 196),
		Visible = false,
		ZIndex = 5,
		Parent = owner.Overlay,
	})
	Stroke(popup, Theme.BorderOuter, 1)

	local svBase = Create("Frame", {
		BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 0, 8),
		Size = UDim2.new(0, 154, 0, 120),
		ZIndex = 6,
		Parent = popup,
	})
	Stroke(svBase, Theme.BorderOuter, 1)

	local svWhite = Create("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 7,
		Parent = svBase,
	})
	Create("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1)),
		Transparency = NumberSequence.new(0, 1),
		Parent = svWhite,
	})

	local svBlack = Create("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 8,
		Parent = svBase,
	})
	Create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.new(0, 0, 0)),
		Transparency = NumberSequence.new(1, 0),
		Parent = svBlack,
	})

	local svCursor = Create("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 9, 0, 9),
		ZIndex = 9,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = svBase,
	})
	Stroke(svCursor, Color3.new(1, 1, 1), 1)

	local hueBar = Create("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 0, 134),
		Size = UDim2.new(0, 154, 0, 10),
		ZIndex = 6,
		Parent = popup,
	})
	Stroke(hueBar, Theme.BorderOuter, 1)
	Create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(0.166, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0, 255, 0)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
			ColorSequenceKeypoint.new(0.666, Color3.fromRGB(0, 0, 255)),
			ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255, 0, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
		}),
		Parent = hueBar,
	})

	local hueCursor = Create("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, -1),
		Size = UDim2.new(0, 3, 0, 12),
		ZIndex = 7,
		Parent = hueBar,
	})
	Stroke(hueCursor, Color3.new(0, 0, 0), 1)

	local alphaBar = Create("Frame", {
		BackgroundColor3 = Theme.AlphaTrackBg,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 0, 150),
		Size = UDim2.new(0, 154, 0, 10),
		ZIndex = 6,
		Parent = popup,
	})
	Stroke(alphaBar, Theme.BorderOuter, 1)

	local alphaFill = Create("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 7,
		Parent = alphaBar,
	})
	local alphaGradient = Create("UIGradient", {
		Color = ColorSequence.new(defaultColor, defaultColor),
		Transparency = NumberSequence.new(1, 0),
		Parent = alphaFill,
	})

	local alphaCursor = Create("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, -1),
		Size = UDim2.new(0, 3, 0, 12),
		ZIndex = 8,
		Parent = alphaBar,
	})
	Stroke(alphaCursor, Color3.new(0, 0, 0), 1)

	local hexFrame = Create("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 0, 168),
		Size = UDim2.new(0, 74, 0, 18),
		ZIndex = 6,
		Parent = popup,
	})
	local hexGradient = VGradient(hexFrame, Theme.FrameTop, Theme.FrameBottom)
	local hexStroke = Stroke(hexFrame, Theme.BorderOuter, 1)

	local hexBox = Create("TextBox", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 6, 0, 0),
		Size = UDim2.new(1, -12, 1, 0),
		Font = FONT,
		TextSize = 11,
		Text = "",
		PlaceholderText = "#RRGGBB",
		PlaceholderColor3 = Theme.TextDim,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		ZIndex = 7,
		Parent = hexFrame,
	})

	local alphaLabel = Create("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 90, 0, 168),
		Size = UDim2.new(0, 72, 0, 18),
		Font = FONT,
		TextSize = 11,
		Text = "",
		TextColor3 = Theme.TextSoft,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = popup,
	})

	local function Refresh(fire)
		local color = Color3.fromHSV(h, s, v)
		element.Color = color

		svBase.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		svCursor.Position = UDim2.new(0, s * 153, 0, (1 - v) * 119)
		hueCursor.Position = UDim2.new(0, math.clamp(h * 151, 0, 151), 0, -1)
		alphaGradient.Color = ColorSequence.new(color, color)
		alphaCursor.Position = UDim2.new(0, math.clamp(element.Alpha * 151, 0, 151), 0, -1)

		swatchGradient.Color = ColorSequence.new(color, Darken(color, 0.6))

		if UserInputService:GetFocusedTextBox() ~= hexBox then
			hexBox.Text = string.format("#%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
		end
		alphaLabel.Text = tostring(math.floor(element.Alpha * 100 + 0.5)) .. "%"

		if fire and callback then
			pcall(callback, color, element.Alpha)
		end
	end

	local function DragControl(control, handler)
		local active = false
		Connect(owner, control.InputBegan, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				active = true
				handler()
			end
		end)
		Connect(owner, UserInputService.InputChanged, function(input)
			if active and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				handler()
			end
		end)
		Connect(owner, UserInputService.InputEnded, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				active = false
			end
		end)
	end

	DragControl(svBase, function()
		local mouse = GetMouse()
		local pos = svBase.AbsolutePosition
		local size = svBase.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		s = math.clamp((mouse.X - pos.X) / size.X, 0, 1)
		v = math.clamp(1 - (mouse.Y - pos.Y) / size.Y, 0, 1)
		Refresh(true)
	end)

	DragControl(hueBar, function()
		local mouse = GetMouse()
		local pos = hueBar.AbsolutePosition
		local size = hueBar.AbsoluteSize
		if size.X <= 0 then
			return
		end
		h = math.clamp((mouse.X - pos.X) / size.X, 0, 1)
		Refresh(true)
	end)

	DragControl(alphaBar, function()
		local mouse = GetMouse()
		local pos = alphaBar.AbsolutePosition
		local size = alphaBar.AbsoluteSize
		if size.X <= 0 then
			return
		end
		element.Alpha = math.clamp((mouse.X - pos.X) / size.X, 0, 1)
		Refresh(true)
	end)

	Connect(owner, hexBox.FocusLost, function(enterPressed)
		hexStroke.Color = Theme.BorderOuter
		hexGradient.Color = ColorSequence.new(Theme.FrameTop, Theme.FrameBottom)
		local parsed = ParseHex(hexBox.Text)
		if parsed then
			local ph, ps, pv = parsed:ToHSV()
			h, s, v = ph, ps, pv
			Refresh(true)
		else
			Refresh(false)
		end
	end)

	Connect(owner, hexBox.Focused, function()
		hexStroke.Color = library.Accent
		hexGradient.Color = ColorSequence.new(Theme.FrameTopHover, Theme.FrameBottomHover)
	end)

	Connect(owner, swatch.Activated, function()
		if owner.ActivePopup == popup then
			owner:ClosePopup()
		else
			owner:OpenPopup(popup, swatch, {self.Scroll, self.Column})
		end
	end)

	function element:Get()
		return element.Color or defaultColor
	end

	function element:GetAlpha()
		return element.Alpha
	end

	function element:Set(newColor, newAlpha, fire)
		if typeof(newColor) == "Color3" then
			local nh, ns, nv = newColor:ToHSV()
			h, s, v = nh, ns, nv
		end
		if type(newAlpha) == "number" then
			element.Alpha = math.clamp(newAlpha, 0, 1)
		end
		Refresh(fire == true)
	end

	function element:SetVisible(visible)
		row.Visible = visible == true
	end

	Refresh(false)
	return element
end

function groupboxes:CreateButton(props)
	local elementName = Resolve(props, {"Name", "name", "Text", "text"}, "Button")
	local callback = Resolve(props, {"Callback", "callback", "Function", "function"}, nil)

	local row = CreateRow(self, 24, false)

	local button = Create("TextButton", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Position = UDim2.new(0, 8, 0, 1),
		Size = UDim2.new(1, -16, 0, 22),
		Parent = row,
	})
	local gradient = VGradient(button, Theme.FrameTop, Theme.FrameBottom)
	Stroke(button, Theme.BorderOuter, 1)

	Create("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		Font = FONT,
		TextSize = 12,
		Text = elementName,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = button,
	})

	local element = {Type = "Button", Row = row}

	local function paint(state)
		if state == "active" then
			gradient.Color = ColorSequence.new(Theme.FrameTopActive, Theme.FrameBottomActive)
		elseif state == "hover" then
			gradient.Color = ColorSequence.new(Theme.FrameTopHover, Theme.FrameBottomHover)
		else
			gradient.Color = ColorSequence.new(Theme.FrameTop, Theme.FrameBottom)
		end
	end

	Connect(self.Window, button.MouseEnter, function()
		paint("hover")
	end)
	Connect(self.Window, button.MouseLeave, function()
		paint("idle")
	end)
	Connect(self.Window, button.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			paint("active")
		end
	end)
	Connect(self.Window, button.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			paint("hover")
		end
	end)
	Connect(self.Window, button.Activated, function()
		if callback then
			pcall(callback)
		end
	end)

	function element:SetVisible(visible)
		row.Visible = visible == true
	end

	function element:Trigger()
		if callback then
			pcall(callback)
		end
	end

	return element
end

function groupboxes:CreateLabel(props)
	local text = Resolve(props, {"Text", "text", "Name", "name"}, "Label")
	local color = Resolve(props, {"Color", "color"}, Theme.Text)

	local row = CreateRow(self, 14, false)

	local label = Create("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 0, 0),
		Size = UDim2.new(1, -16, 1, 0),
		Font = FONT,
		TextSize = 12,
		Text = tostring(text),
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})

	local element = {Type = "Label", Row = row}

	function element:SetText(newText)
		label.Text = tostring(newText)
	end

	function element:SetVisible(visible)
		row.Visible = visible == true
	end

	return element
end

function groupboxes:CreateSeparator(props)
	local sepName = Resolve(props, {"Name", "name", "Text", "text"}, nil)

	local row = CreateRow(self, 11, false)

	Create("Frame", {
		BackgroundColor3 = Theme.BorderInner,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 0, 5),
		Size = UDim2.new(1, -16, 0, 1),
		Parent = row,
	})

	if sepName then
		local textWidth = GetTextWidth(tostring(sepName), 10, FONT)
		Create("TextLabel", {
			BackgroundColor3 = Theme.GroupBg,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, -(textWidth + 12) / 2, 0, 0),
			Size = UDim2.new(0, textWidth + 12, 0, 11),
			Font = FONT,
			TextSize = 10,
			Text = tostring(sepName),
			TextColor3 = Theme.TextDim,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = row,
		})
	end

	local element = {Type = "Separator", Row = row}

	function element:SetVisible(visible)
		row.Visible = visible == true
	end

	return element
end

function groupboxes:CreateTextBox(props)
	local elementName = Resolve(props, {"Name", "name", "Text", "text"}, "TextBox")
	local placeholder = Resolve(props, {"Placeholder", "placeholder"}, "")
	local defaultText = Resolve(props, {"Default", "default", "State", "state", "Value", "value"}, "")
	local callback = Resolve(props, {"Callback", "callback", "Function", "function"}, nil)

	local row = CreateRow(self, 38, false)

	Create("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 0, 0),
		Size = UDim2.new(1, -16, 0, 12),
		Font = FONT,
		TextSize = 12,
		Text = elementName,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})

	local frame = Create("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 0, 16),
		Size = UDim2.new(1, -16, 0, 20),
		Parent = row,
	})
	local gradient = VGradient(frame, Theme.FrameTop, Theme.FrameBottom)
	local stroke = Stroke(frame, Theme.BorderOuter, 1)

	local box = Create("TextBox", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 6, 0, 0),
		Size = UDim2.new(1, -12, 1, 0),
		Font = FONT,
		TextSize = 12,
		Text = tostring(defaultText),
		PlaceholderText = tostring(placeholder),
		PlaceholderColor3 = Theme.TextDim,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ClearTextOnFocus = false,
		Parent = frame,
	})

	local element = {Type = "TextBox", Row = row}

	Connect(self.Window, box.Focused, function()
		stroke.Color = library.Accent
		gradient.Color = ColorSequence.new(Theme.FrameTopHover, Theme.FrameBottomHover)
	end)

	Connect(self.Window, box.FocusLost, function(enterPressed)
		stroke.Color = Theme.BorderOuter
		gradient.Color = ColorSequence.new(Theme.FrameTop, Theme.FrameBottom)
		if callback then
			pcall(callback, box.Text, enterPressed)
		end
	end)

	function element:Get()
		return box.Text
	end

	function element:Set(newText, fire)
		box.Text = tostring(newText)
		if fire and callback then
			pcall(callback, box.Text, false)
		end
	end

	function element:SetVisible(visible)
		row.Visible = visible == true
	end

	return element
end

return library
