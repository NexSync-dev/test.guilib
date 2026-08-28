local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")

local library = {
	Folder = "Skeet",
	Configs = "Configs",
	ISettingsFile = "isettings_" .. tostring(game.GameId) .. ".json",
	CurrentWindow = nil,
	Windows = {},
	Renders = setmetatable({}, {__mode = "k"}),
	Connections = setmetatable({}, {__mode = "k"}),
	BlurRefCount = 0
}
library.__index = library

function library.UpdateBlurSize()
	local Target = 0
	for _, Window in ipairs(library.Windows) do
		if not Window.Unloaded and Window.Enabled and Window.Blur then
			Target = math.max(Target, Window.BlurStrength or 24)
		end
	end
	pcall(function()
		local BlurEffect = Lighting:FindFirstChild("_SkeetLibBlur")
		if BlurEffect then
			BlurEffect.Size = Target
		end
	end)
end

local utility = {}
local pages = {}
local sections = {}
pages.__index = pages
sections.__index = sections

local FadeProperties = {
	Frame = {"BackgroundTransparency"},
	ViewportFrame = {"BackgroundTransparency"},
	ScrollingFrame = {"BackgroundTransparency", "ScrollBarImageTransparency"},
	ImageLabel = {"BackgroundTransparency", "ImageTransparency"},
	ImageButton = {"BackgroundTransparency", "ImageTransparency"},
	TextLabel = {"BackgroundTransparency", "TextTransparency"},
	TextButton = {"BackgroundTransparency", "TextTransparency"},
	TextBox = {"BackgroundTransparency", "TextTransparency"}
}

function utility:RenderObject(Window, RenderType, RenderProperties)
	local Instance2 = Instance.new(RenderType)
	local Props = {}
	local Parent = nil
	if type(RenderProperties) == "table" then
		for Key, Value in pairs(RenderProperties) do
			if Key == "Parent" then
				Parent = Value
			elseif Key ~= "RenderTime" then
				Props[Key] = Value
			end
		end
	end
	for Key, Value in pairs(Props) do
		Instance2[Key] = Value
	end
	library.Renders[Instance2] = {
		Window = Window or library.CurrentWindow,
		Props = Props,
		Hidden = false,
		Time = RenderProperties and RenderProperties.RenderTime or nil
	}
	if Parent then
		Instance2.Parent = Parent
	end
	return Instance2
end

function utility:DestroyObject(Inst)
	if Inst == nil then return end
	library.Renders[Inst] = nil
	if typeof(Inst) == "Instance" then
		Inst:Destroy()
	end
end

function utility:CreateConnection(Window, Signal, Callback)
	local Connection = Signal:Connect(Callback)
	library.Connections[Connection] = Window or library.CurrentWindow
	return Connection
end

function utility:DisconnectConnection(Connection)
	if Connection == nil then return end
	library.Connections[Connection] = nil
	if typeof(Connection) == "RBXScriptConnection" then
		Connection:Disconnect()
	end
end

function utility:MouseLocation()
	return UserInputService:GetMouseLocation()
end

function utility:ReparentPopup(Popup, Parent, ScreenPosition)
	if typeof(Popup) ~= "Instance" or typeof(Parent) ~= "Instance" then return Popup end
	Popup.Position = UDim2.fromOffset(0, 0)
	Popup.Parent = Parent
	task.defer(function()
		if Popup.Parent ~= Parent or Parent.Parent == nil then return end
		local Anchor = nil
		if typeof(ScreenPosition) == "Vector2" then
			Anchor = ScreenPosition
		else
			Anchor = Popup.AbsolutePosition
		end
		local X = Anchor.X - Parent.AbsolutePosition.X
		local Y = Anchor.Y - Parent.AbsolutePosition.Y
		Popup.Position = UDim2.fromOffset(X, Y)
		local Size = Popup.AbsoluteSize
		if Size.X > 0 and Parent.AbsoluteSize.X > 0 then
			X = math.clamp(X, 0, math.max(Parent.AbsoluteSize.X - Size.X, 0))
			Y = math.clamp(Y, 0, math.max(Parent.AbsoluteSize.Y - Size.Y, 0))
			Popup.Position = UDim2.fromOffset(X, Y)
		end
	end)
	return Popup
end

function utility:Resolve(Table, Aliases, Default)
	if not Table or typeof(Table) ~= "table" then return Default end
	for _, Key in ipairs(Aliases) do
		local Value = Table[Key]
		if Value ~= nil then return Value end
	end
	return Default
end

function utility:AddLabel(Window, Parent, Position, Size, Text, TextColor, Transparency, ZIndex, TextSize)
	return utility:RenderObject(Window, "TextLabel", {
		AnchorPoint = Vector2.new(0, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Parent,
		Position = Position,
		Size = Size,
		ZIndex = ZIndex or 3,
		Font = Enum.Font.Code,
		RichText = true,
		Text = Text,
		TextColor3 = TextColor,
		TextSize = math.round((TextSize or 9) * (Window.TextScale or 1)),
		TextStrokeTransparency = 1,
		TextTransparency = Transparency or 0,
		TextXAlignment = Enum.TextXAlignment.Left
	})
end

function utility:AddTitle(Window, Parent, Position, Size, Text, TextColor, ZIndex, TextSize)
	return utility:AddLabel(Window, Parent, Position, Size, Text, TextColor, 0, ZIndex, TextSize)
end

function utility:GetSettings(Folder, File)
	local Path = Folder .. "/" .. File
	if not readfile then return {} end
	local Ok, Data = pcall(function()
		return HttpService:JSONDecode(readfile(Path))
	end)
	if Ok and typeof(Data) == "table" then return Data end
	return {}
end

function utility:SaveSettings(Folder, File, Data)
	if not writefile then return false end
	local Ok = pcall(function()
		writefile(Folder .. "/" .. File, HttpService:JSONEncode(Data))
	end)
	return Ok
end

local function PruneElementList(List)
	local Write = 0
	for Read = 1, #List do
		local Item = List[Read]
		if Item.Object and Item.Object.Parent ~= nil then
			Write = Write + 1
			List[Write] = Item
		end
	end
	for Index = #List, Write + 1, -1 do
		List[Index] = nil
	end
end

local function DeriveShades(BaseColor)
	return {
		Light = BaseColor:Lerp(Color3.new(1, 1, 1), 0.09),
		Base = BaseColor,
		Dark = BaseColor:Lerp(Color3.new(0, 0, 0), 0.30)
	}
end

function library:CreateWindow(Properties)
	Properties = Properties or {}
	local Window = {
		Name = utility:Resolve(Properties, {"name", "Name", "title", "Title"}, "skeet"),
		Size = utility:Resolve(Properties, {"size", "Size"}, Vector2.new(660, 560)),
		Key = utility:Resolve(Properties, {"key", "Key", "togglekey", "ToggleKey"}, Enum.KeyCode.Insert),
		ShowSettings = utility:Resolve(Properties, {"showsettings", "ShowSettings"}, true),
		TextScale = utility:Resolve(Properties, {"textscale", "TextScale"}, 1),
		Pages = {},
		Accent = Color3.fromRGB(145, 65, 215),
		Theme = {
			Background = Color3.fromRGB(25, 25, 25),
			Accent = Color3.fromRGB(145, 65, 215),
			Text = Color3.fromRGB(205, 205, 205)
		},
		Enabled = true,
		Elements = {},
		AccentElements = {},
		ThemeElements = {},
		Keybinds = {},
		OpenContent = nil,
		HoldingSlider = nil,
		Blur = false,
		BlurStrength = 24,
		AutoSave = true,
		LoadClosed = false,
		PopupsFollowScroll = false,
		FirstPageSet = false,
		Unloaded = false,
		SliderDispatcherReady = false,
		KeybindDispatcherReady = false,
		SettingsData = {}
	}
	library.CurrentWindow = Window
	library.Windows[#library.Windows + 1] = Window
	local WindowObj = setmetatable(Window, library)
	WindowObj.CreateTab = WindowObj.CreatePage
	local BlurRefKey = "_SkeetLibBlur"
	local blurEffect = Lighting:FindFirstChild(BlurRefKey)
	if blurEffect == nil then
		blurEffect = Instance.new("BlurEffect")
		blurEffect.Name = BlurRefKey
		blurEffect.Size = 0
		blurEffect.Parent = Lighting
	end
	library.BlurRefCount = library.BlurRefCount + 1

	local ScreenGui = utility:RenderObject(Window, "ScreenGui", {
		Name = Window.Name .. "_" .. tostring(math.floor(os.clock() * 100000) % 100000),
		DisplayOrder = 9999,
		Enabled = true,
		IgnoreGuiInset = true,
		Parent = CoreGui,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Global
	})

	local MainSize = Window.Size
	local ScreenGui_MainFrame = utility:RenderObject(Window, "Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(10, 10, 10),
		BorderMode = Enum.BorderMode.Inset,
		BorderSizePixel = 1,
		Parent = ScreenGui,
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, MainSize.X, 0, MainSize.Y)
	})
	local ScreenGui_MainFrame_InnerBorder = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(40, 40, 40),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = ScreenGui_MainFrame,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2)
	})
	local MainFrame_InnerBorder_InnerFrame = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(12, 12, 12),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(60, 60, 60),
		BorderMode = Enum.BorderMode.Inset,
		BorderSizePixel = 1,
		Parent = ScreenGui_MainFrame,
		Position = UDim2.new(0, 3, 0, 3),
		Size = UDim2.new(1, -6, 1, -6)
	})
	local InnerBorder_InnerFrame_Tabs = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(12, 12, 12),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = MainFrame_InnerBorder_InnerFrame,
		Position = UDim2.new(0, 0, 0, 4),
		Size = UDim2.new(0, 74, 1, -4)
	})
	local InnerBorder_InnerFrame_Pages = utility:RenderObject(Window, "Frame", {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = MainFrame_InnerBorder_InnerFrame,
		Position = UDim2.new(1, 0, 0, 4),
		Size = UDim2.new(1, -73, 1, -4)
	})
	local InnerBorder_InnerFrame_TopGradient = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(12, 12, 12),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = MainFrame_InnerBorder_InnerFrame,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 0, 4)
	})
	local TopAccentBar = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Window.Accent,
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = MainFrame_InnerBorder_InnerFrame,
		Position = UDim2.new(0, 74, 0, 3),
		Size = UDim2.new(1, -74, 0, 1),
		ZIndex = 6
	})
	local InnerFrame_Tabs_List = utility:RenderObject(Window, "UIListLayout", {
		Padding = UDim.new(0, 4),
		Parent = InnerBorder_InnerFrame_Tabs,
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Top
	})
	local InnerFrame_Tabs_Padding = utility:RenderObject(Window, "UIPadding", {
		Parent = InnerBorder_InnerFrame_Tabs,
		PaddingTop = UDim.new(0, 9)
	})
	local InnerFrame_Pages_InnerBorder = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(45, 45, 45),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = InnerBorder_InnerFrame_Pages,
		Position = UDim2.new(0, 1, 0, 0),
		Size = UDim2.new(1, -1, 1, 0)
	})
	local InnerFrame_TopGradient_Gradient = utility:RenderObject(Window, "ImageLabel", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = InnerBorder_InnerFrame_TopGradient,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		Image = "rbxassetid://8508019876",
		ImageColor3 = Color3.fromRGB(255, 255, 255)
	})
	local Pages_InnerBorder_InnerFrame = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(20, 20, 20),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = InnerFrame_Pages_InnerBorder,
		Position = UDim2.new(0, 1, 0, 0),
		Size = UDim2.new(1, -1, 1, 0)
	})
	local InnerBorder_InnerFrame_Folder = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Pages_InnerBorder_InnerFrame,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 1, 0)
	})
	local InnerBorder_InnerFrame_Pattern = utility:RenderObject(Window, "ImageLabel", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Pages_InnerBorder_InnerFrame,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 1, 0),
		Image = "rbxassetid://8547666218",
		ImageColor3 = Color3.fromRGB(12, 12, 12),
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.new(0, 8, 0, 8)
	})

	function Window:SetPage(Page)
		for _, page in ipairs(Window.Pages) do
			if page.Open and page ~= Page then
				page:Set(false)
			end
		end
	end

	function Window:Fade(state)
		if Window.Unloaded then return end
		local Direction = state and Enum.EasingDirection.Out or Enum.EasingDirection.In
		local Info = TweenInfo.new(0.25, Enum.EasingStyle.Linear, Direction)
		local LiveWindows = 0
		for _, LiveWindow in ipairs(library.Windows) do
			if not LiveWindow.Unloaded then
				LiveWindows = LiveWindows + 1
			end
		end
		if LiveWindows <= 1 then
			local ActiveBlur = (blurEffect.Parent ~= nil) and blurEffect or nil
			if ActiveBlur then
				TweenService:Create(ActiveBlur, Info, {Size = (state and Window.Blur and Window.BlurStrength or 0)}):Play()
			end
		else
			task.defer(function()
				library.UpdateBlurSize()
			end)
		end
		for Inst, Record in pairs(library.Renders) do
			if Record.Window == self and not Record.Hidden and Inst.Parent ~= nil then
				local PropList = FadeProperties[Inst.ClassName]
				if PropList then
					for _, PropertyName in ipairs(PropList) do
						local Original = Record.Props[PropertyName]
						if Original ~= nil and Original < 1 then
							TweenService:Create(Inst, TweenInfo.new(Record.Time or 0.25, Enum.EasingStyle.Linear, Direction), {[PropertyName] = state and Original or 1}):Play()
						end
					end
				end
			end
		end
		if state then
			for _, page in ipairs(Window.Pages) do
				if page.Open and page.ApplyVisuals then
					page:ApplyVisuals()
				end
			end
		end
		if Window.External then
			for _, Item in ipairs(Window.External) do
				if Item.Instance and typeof(Item.Instance) == "Instance" and Item.Instance.Parent then
					pcall(function()
						for PropertyName, Original in pairs(Item.Properties) do
							TweenService:Create(Item.Instance, Info, {[PropertyName] = state and Original or 1}):Play()
						end
					end)
				end
			end
		end
	end

	function Window:Unload()
		if Window.Unloaded then return end
		Window.Unloaded = true
		Window.RainbowAccent = false
		Window.Enabled = false
		pcall(function()
			if Window.SettingsData and Window.AutoSave and writefile then
				utility:SaveSettings(library.Folder, library.ISettingsFile, Window.SettingsData)
			end
		end)
		if Window.OpenContent and Window.OpenContent.Close then
			pcall(function() Window.OpenContent:Close() end)
		end
		Window.OpenContent = nil
		if Window.ExternalConnections then
			for _, Connection in ipairs(Window.ExternalConnections) do
				if Connection and Connection.Disconnect then
					pcall(function() Connection:Disconnect() end)
				end
			end
			Window.ExternalConnections = nil
		end
		if Window.External then
			for _, Item in ipairs(Window.External) do
				if Item.Instance and typeof(Item.Instance) == "Instance" then
					Item.Instance:Destroy()
				end
			end
			Window.External = nil
		end
		local DeadConnections = {}
		for Connection, Owner in pairs(library.Connections) do
			if Owner == self then
				DeadConnections[#DeadConnections + 1] = Connection
			end
		end
		for _, Connection in ipairs(DeadConnections) do
			utility:DisconnectConnection(Connection)
		end
		local DeadRenders = {}
		for Inst, Record in pairs(library.Renders) do
			if Record.Window == self then
				DeadRenders[#DeadRenders + 1] = Inst
			end
		end
		for _, Inst in ipairs(DeadRenders) do
			utility:DestroyObject(Inst)
		end
		library.BlurRefCount = library.BlurRefCount - 1
		if library.BlurRefCount <= 0 then
			local Orphan = Lighting:FindFirstChild(BlurRefKey)
			if Orphan then Orphan:Destroy() end
			library.BlurRefCount = 0
		end
		for Index = #library.Windows, 1, -1 do
			if library.Windows[Index] == self then
				table.remove(library.Windows, Index)
			end
		end
		library.UpdateBlurSize()
		if library.CurrentWindow == self then
			library.CurrentWindow = nil
		end
	end

	function Window:AddInstance(instance)
		if not instance or typeof(instance) ~= "Instance" then return nil end
		Window.External = Window.External or {}
		local properties = {}
		for _, property in ipairs({"BackgroundTransparency", "ImageTransparency", "TextTransparency", "ScrollBarImageTransparency"}) do
			local ok, value = pcall(function() return instance[property] end)
			if ok and value ~= nil then
				properties[property] = value
			end
		end
		Window.External[#Window.External + 1] = {Instance = instance, Properties = properties}
		return instance
	end

	function Window:RegisterConnection(connection)
		if not connection or not connection.Disconnect then return nil end
		Window.ExternalConnections = Window.ExternalConnections or {}
		Window.ExternalConnections[#Window.ExternalConnections + 1] = connection
		return connection
	end

	function Window:SetToggleKey(key)
		if typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then
			Window.Key = key
		end
	end

	function Window:SetEnabled(state)
		state = state and true or false
		if Window.Unloaded or Window.Enabled == state then return end
		Window.Enabled = state
		ScreenGui_MainFrame.Visible = state
		if not state then
			GuiService.SelectedObject = nil
			pcall(function()
				local Focused = UserInputService:GetFocusedTextBox()
				if Focused then Focused:ReleaseFocus() end
			end)
			Window:CloseOpenPopup()
		end
		Window:Fade(state)
	end

	function Window:CloseOpenPopup()
		local Popup = Window.OpenContent
		Window.OpenContent = nil
		if Popup and Popup.Close then
			pcall(function() Popup:Close() end)
		end
	end

	function Window:SetAccent(newColor)
		if typeof(newColor) ~= "Color3" then return end
		self.Accent = newColor
		self.Theme.Accent = newColor
		PruneElementList(self.AccentElements)
		for _, Item in ipairs(self.AccentElements) do
			if Item.Type == "Toggle" then
				Item.Object.BackgroundColor3 = Item.Element.State and newColor or Color3.fromRGB(77, 77, 77)
			elseif Item.Type == "Slider" then
				Item.Object.BackgroundColor3 = newColor
			elseif Item.Type == "Page" then
				Item.Object.BackgroundColor3 = newColor
			elseif Item.Type == "Section" then
				Item.Object.BackgroundColor3 = newColor
			elseif Item.Type == "Border" then
				Item.Object.BackgroundColor3 = newColor
			elseif Item.Type == "Value" then
				Item.Object.TextColor3 = Item.Element.Active and newColor or Color3.fromRGB(114, 114, 114)
			end
		end
		if self.OpenContent and self.OpenContent.Refresh then
			self.OpenContent:Refresh()
		end
	end

	function Window:SetTheme(Theme)
		Theme = Theme or {}
		local OldText = self.Theme.Text
		self.Theme.Background = Theme.Background or self.Theme.Background
		self.Theme.Accent = Theme.Accent or self.Theme.Accent
		self.Theme.Text = Theme.Text or self.Theme.Text
		local Shades = DeriveShades(self.Theme.Background)
		PruneElementList(self.ThemeElements)
		for _, Item in ipairs(self.ThemeElements) do
			if Item.Type == "Background" then
				local Shade = Item.Shade or "Base"
				Item.Object.BackgroundColor3 = Shades[Shade] or self.Theme.Background
			end
		end
		if Theme.Text then
			for Inst, Record in pairs(library.Renders) do
				if Record.Window == self and Inst.ClassName == "TextLabel" and Inst.TextColor3 == OldText then
					Inst.TextColor3 = self.Theme.Text
				end
			end
		end
		self:SetAccent(self.Theme.Accent)
	end

	Window.TabsHolder = InnerBorder_InnerFrame_Tabs
	Window.PagesHolder = InnerBorder_InnerFrame_Folder
	Window.MainFrame = ScreenGui_MainFrame

	local Dragging = false
	local DragStart = Vector2.new()
	local StartPosition = UDim2.new()

	utility:CreateConnection(Window, ScreenGui_MainFrame.InputBegan, function(Input)
		if Window.OpenContent ~= nil then return end
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
			Dragging = true
			DragStart = Vector2.new(Input.Position.X, Input.Position.Y)
			StartPosition = ScreenGui_MainFrame.Position
		end
	end)

	utility:CreateConnection(Window, UserInputService.InputChanged, function(Input)
		if Dragging and (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch) then
			local Delta = Vector2.new(Input.Position.X, Input.Position.Y) - DragStart
			ScreenGui_MainFrame.Position = UDim2.new(
				StartPosition.X.Scale,
				StartPosition.X.Offset + Delta.X,
				StartPosition.Y.Scale,
				StartPosition.Y.Offset + Delta.Y
			)
		end
	end)

	utility:CreateConnection(Window, UserInputService.InputEnded, function(Input)
		if Dragging and Input.UserInputType == Enum.UserInputType.MouseButton1 then
			Dragging = false
			if not Window.AutoSave then return end
			Window.SettingsData.position = {
				XScale = ScreenGui_MainFrame.Position.X.Scale,
				XOffset = math.floor(ScreenGui_MainFrame.Position.X.Offset),
				YScale = ScreenGui_MainFrame.Position.Y.Scale,
				YOffset = math.floor(ScreenGui_MainFrame.Position.Y.Offset)
			}
			utility:SaveSettings(library.Folder, library.ISettingsFile, Window.SettingsData)
		end
	end)

	utility:CreateConnection(Window, UserInputService.InputEnded, function(Input)
		if Dragging and Input.UserInputType == Enum.UserInputType.Touch then
			Dragging = false
		end
	end)

	utility:CreateConnection(Window, UserInputService.InputBegan, function(Input)
		if Window.Unloaded then return end
		if Input.KeyCode and Input.KeyCode == Window.Key then
			if UserInputService:GetFocusedTextBox() then return end
			WindowObj:SetEnabled(not Window.Enabled)
		end
	end)

	table.insert(Window.ThemeElements, {Type = "Background", Object = ScreenGui_MainFrame, Shade = "Base"})
	table.insert(Window.ThemeElements, {Type = "Background", Object = ScreenGui_MainFrame_InnerBorder, Shade = "Light"})
	table.insert(Window.ThemeElements, {Type = "Background", Object = MainFrame_InnerBorder_InnerFrame, Shade = "Dark"})
	table.insert(Window.ThemeElements, {Type = "Background", Object = InnerBorder_InnerFrame_Tabs, Shade = "Dark"})
	table.insert(Window.ThemeElements, {Type = "Background", Object = InnerBorder_InnerFrame_TopGradient, Shade = "Dark"})
	table.insert(Window.ThemeElements, {Type = "Background", Object = InnerFrame_Pages_InnerBorder, Shade = "Light"})
	table.insert(Window.ThemeElements, {Type = "Background", Object = Pages_InnerBorder_InnerFrame, Shade = "Base"})
	table.insert(Window.AccentElements, {Type = "Border", Object = TopAccentBar})

	Window.SettingsData = utility:GetSettings(library.Folder, library.ISettingsFile)
	if Window.SettingsData.saveUIState == false then
		Window.AutoSave = false
	end
	local savedPos = Window.AutoSave and Window.SettingsData.position
	if savedPos then
		pcall(function()
			ScreenGui_MainFrame.Position = UDim2.new(savedPos.XScale or 0.5, savedPos.XOffset or 0, savedPos.YScale or 0.5, savedPos.YOffset or 0)
		end)
	end
	if utility:Resolve(Properties, {"loadclosed", "LoadClosed", "startclosed", "StartClosed"}, false) then
		Window.LoadClosed = true
	end
	if Window.LoadClosed then
		Window.Enabled = false
		ScreenGui_MainFrame.Visible = false
	end
	local ConfigFolderName = library.Folder .. "/" .. library.Configs .. "/" .. tostring(game.GameId)
	local function ApplyConfigByName(configName)
		if not readfile then
			return "load failed: no readfile"
		end
		if not configName or configName == "" then
			return "load failed: no config selected"
		end
		local success, content = pcall(function()
			return readfile(ConfigFolderName .. "/" .. configName .. ".json")
		end)
		if not success or type(content) ~= "string" then
			return "load failed: missing file"
		end
		local decoded, data = pcall(function()
			return HttpService:JSONDecode(content)
		end)
		if not decoded or typeof(data) ~= "table" then
			return "load failed: malformed json"
		end
		local applied, skipped = 0, 0
		for key, val in pairs(data) do
			local info = WindowObj.Elements[key]
			if info then
				local ok = pcall(function()
					if info.Type == "Colorpicker" then
						if type(val) == "table" and #val >= 3
							and type(val[1]) == "number" and type(val[2]) == "number" and type(val[3]) == "number" then
							info.Element:Set(Color3.fromRGB(math.clamp(math.round(val[1]), 0, 255), math.clamp(math.round(val[2]), 0, 255), math.clamp(math.round(val[3]), 0, 255)))
						else
							skipped = skipped + 1
							return
						end
					else
						info.Element:Set(val)
					end
				end)
				if ok then applied = applied + 1 else skipped = skipped + 1 end
			end
		end
		if skipped > 0 then
			return "loaded '" .. configName .. "' (" .. tostring(applied) .. ", " .. tostring(skipped) .. " skipped)"
		else
			return "loaded '" .. configName .. "' (" .. tostring(applied) .. ")"
		end
	end
	if Window.ShowSettings then
		local settings_page = WindowObj:CreatePage({Icon = "rbxassetid://8547256547", LayoutOrder = 9999, IsSettings = true})
		local menuSection = settings_page:CreateSection({Name = "Menu", Size = 180, Side = "Left"})
		local configSection = settings_page:CreateSection({Name = "Configs", Size = 260, Side = "Left"})

		local settingsSavePending = false
		local function SaveSettingsNow()
			settingsSavePending = false
			if Window.Unloaded or not Window.AutoSave then return end
			pcall(function()
				utility:SaveSettings(library.Folder, library.ISettingsFile, Window.SettingsData)
			end)
		end
		local function QueueSaveSettings()
			if Window.AutoSave == false then return end
			if settingsSavePending then return end
			settingsSavePending = true
			task.delay(0.4, function()
				if settingsSavePending then
					SaveSettingsNow()
				end
			end)
		end

		local toggleKeyElement = nil
		toggleKeyElement = menuSection:CreateKeybind({
			Name = "Toggle Keybind",
			State = {"KeyCode", "Insert"},
			Callback = function(val)
				if type(val) == "table" and val[1] == "KeyCode" and Enum.KeyCode[val[2]] then
					WindowObj.Key = Enum.KeyCode[val[2]]
					if type(val[2]) == "string" then
						Window.SettingsData.toggleKey = val[2]
						SaveSettingsNow()
					end
				end
			end
		})

		menuSection:CreateToggle({
			Name = "UI Blur",
			State = Window.SettingsData.uiBlur == true,
			Callback = function(state)
				WindowObj.Blur = state
				library.UpdateBlurSize()
				Window.SettingsData.uiBlur = state
				SaveSettingsNow()
			end
		})

		menuSection:CreateToggle({
			Name = "Save UI State",
			State = Window.AutoSave,
			Callback = function(state)
				Window.AutoSave = state
				Window.SettingsData.saveUIState = state
				utility:SaveSettings(library.Folder, library.ISettingsFile, Window.SettingsData)
			end
		})

		menuSection:CreateToggle({
			Name = "Popups Follow Scroll",
			State = Window.SettingsData.popupFollowScroll == true,
			Callback = function(state)
				Window.PopupsFollowScroll = state
				Window.SettingsData.popupFollowScroll = state
				SaveSettingsNow()
			end
		})

		pcall(function()
			if makefolder then
				makefolder(library.Folder)
				makefolder(library.Folder .. "/" .. library.Configs)
				makefolder(ConfigFolderName)
			end
		end)

		local configsCache = nil
		local function GetConfigs(force)
			if configsCache ~= nil and not force then return configsCache end
			local configs = {}
			if listfiles then
				pcall(function()
					for _, file in ipairs(listfiles(ConfigFolderName)) do
						if string.match(file, "%.json$") then
							table.insert(configs, string.match(file, "([^/\\]+)%.json$"))
						end
					end
					table.sort(configs)
				end)
			end
			if #configs == 0 then table.insert(configs, "default") end
			configsCache = configs
			return configs
		end

		local configDropdown = nil
		configDropdown = configSection:CreateDropdown({
			Name = "Selected Config",
			Options = GetConfigs(),
			State = 1,
			Callback = function(index)
				if configDropdown and Window.SettingsData then
					local chosen = configDropdown.Options[index]
					if chosen then
						Window.SettingsData.config = chosen
						utility:SaveSettings(library.Folder, library.ISettingsFile, Window.SettingsData)
					end
				end
			end
		})
		local savedConfig = Window.SettingsData and Window.SettingsData.config
		if savedConfig then
			for i, opt in ipairs(GetConfigs()) do
				if opt == savedConfig then
					configDropdown:Set(i)
					break
				end
			end
		end

		local configNameBox = configSection:CreateTextBox({
			Name = "Config Name",
			State = "",
			Placeholder = "config name"
		})

		local configStatus = nil
		configStatus = configSection:CreateLabel({Text = "config: ready"})
		Window.SetConfigStatus = function(text)
			pcall(function()
				configStatus:Set(text)
			end)
		end

		configSection:CreateButton({
			Name = "Refresh Configs",
			Callback = function()
				configDropdown:RefreshOptions(GetConfigs(true))
				configStatus:Set("config: refreshed")
			end
		})

		configSection:CreateButton({
			Name = "Save Configuration",
			Callback = function()
				local configName = configNameBox:Get()
				if configName == "" then configName = "default" end
				local data = {}
				local savedCount = 0
				for key, info in pairs(WindowObj.Elements) do
					local ok, val = pcall(function() return info.Element:Get() end)
					if ok and val ~= nil then
						if info.Type == "Colorpicker" then
							data[key] = {math.round(val.R * 255), math.round(val.G * 255), math.round(val.B * 255)}
						elseif info.Type == "Keybind" then
							if type(val) == "table" and #val >= 2 then
								data[key] = {val[1], val[2]}
							end
						else
							data[key] = val
						end
						savedCount = savedCount + 1
					end
				end
				local success = false
				pcall(function()
					if writefile then
						writefile(ConfigFolderName .. "/" .. configName .. ".json", HttpService:JSONEncode(data))
						success = true
					end
				end)
				configDropdown:RefreshOptions(GetConfigs(true))
				if success then
					configStatus:Set("saved '" .. configName .. "' (" .. tostring(savedCount) .. " settings)")
				elseif not writefile then
					configStatus:Set("save failed: no writefile")
				else
					configStatus:Set("save failed")
				end
			end
		})

		configSection:CreateButton({
			Name = "Load Configuration",
			Callback = function()
				local selectedIndex = configDropdown:Get()
				local configName = configDropdown.Options[selectedIndex]
				configStatus:Set(ApplyConfigByName(configName))
			end
		})

		configSection:CreateToggle({
			Name = "Auto Load Config",
			State = WindowObj.SettingsData.autoLoadConfig == true,
			Callback = function(state)
				WindowObj.SettingsData.autoLoadConfig = state
				if WindowObj.AutoSave then
					pcall(function()
						utility:SaveSettings(library.Folder, library.ISettingsFile, WindowObj.SettingsData)
					end)
				end
			end
		})

		menuSection:CreateButton({
			Name = "Unload GUI",
			Callback = function()
				WindowObj:Unload()
			end
		})

		local themeSection = settings_page:CreateSection({Name = "Theme", Size = 330, Side = "Left"})
		local function SaveColor(Key, Color)
			Window.SettingsData[Key] = {math.round(math.clamp(Color.R, 0, 1) * 255), math.round(math.clamp(Color.G, 0, 1) * 255), math.round(math.clamp(Color.B, 0, 1) * 255)}
			QueueSaveSettings()
		end

		local accentPicker = themeSection:CreateColorpicker({
			Name = "Accent Color",
			State = WindowObj.Accent,
			Callback = function(color)
				WindowObj:SetAccent(color)
				SaveColor("accentColor", color)
			end
		})
		themeSection:CreateColorpicker({
			Name = "Background Color",
			State = WindowObj.Theme.Background,
			Callback = function(color)
				WindowObj:SetTheme({Background = color})
				SaveColor("backgroundColor", color)
			end
		})
		themeSection:CreateColorpicker({
			Name = "Text Color",
			State = WindowObj.Theme.Text,
			Callback = function(color)
				WindowObj:SetTheme({Text = color})
				SaveColor("textColor", color)
			end
		})
		themeSection:CreateSlider({
			Name = "GUI Outline",
			Min = 0,
			Max = 100,
			State = Window.SettingsData.outlineOpacity or 100,
			Callback = function(value)
				ScreenGui_MainFrame.BackgroundTransparency = 1 - (value / 100)
				Window.SettingsData.outlineOpacity = value
				QueueSaveSettings()
			end
		})
		themeSection:CreateSlider({
			Name = "Rainbow Speed",
			Min = 0.01,
			Max = 0.5,
			Step = 0.01,
			State = Window.SettingsData.rainbowSpeed or 0.05,
			Suffix = "s",
			Callback = function(value)
				WindowObj.RainbowSpeed = value
				Window.SettingsData.rainbowSpeed = value
				QueueSaveSettings()
			end
		})
		themeSection:CreateToggle({
			Name = "Rainbow Accent",
			State = false,
			Callback = function(state)
				WindowObj.RainbowAccent = state
				if state then
					WindowObj.PreRainbowAccent = WindowObj.Accent
					task.spawn(function()
						local hue = 0
						while WindowObj.RainbowAccent and not WindowObj.Unloaded do
							hue = (hue + 1) % 360
							WindowObj:SetAccent(Color3.fromHSV(hue / 360, 1, 1))
							task.wait(WindowObj.RainbowSpeed or 0.05)
						end
					end)
				else
					local RestoreColor = WindowObj.PreRainbowAccent
					if typeof(RestoreColor) == "Color3" then
						WindowObj:SetAccent(RestoreColor)
						pcall(function()
							accentPicker:Set(RestoreColor, true)
						end)
						WindowObj.PreRainbowAccent = nil
					end
				end
			end
		})
		themeSection:CreateSlider({
			Name = "Blur Strength",
			Min = 0,
			Max = 50,
			State = Window.SettingsData.blurStrength or 24,
			Callback = function(value)
				WindowObj.BlurStrength = value
				library.UpdateBlurSize()
				Window.SettingsData.blurStrength = value
				QueueSaveSettings()
			end
		})

		do
			local SD = Window.SettingsData
			pcall(function()
				Window.PopupsFollowScroll = SD.popupFollowScroll == true
			end)
			pcall(function()
				if type(SD.toggleKey) == "string" and Enum.KeyCode[SD.toggleKey] then
					WindowObj.Key = Enum.KeyCode[SD.toggleKey]
					toggleKeyElement:Set({"KeyCode", SD.toggleKey}, true)
				end
			end)
			pcall(function()
				if type(SD.accentColor) == "table" and #SD.accentColor >= 3
					and type(SD.accentColor[1]) == "number" and type(SD.accentColor[2]) == "number" and type(SD.accentColor[3]) == "number" then
					local Restored = Color3.fromRGB(
						math.clamp(math.round(SD.accentColor[1]), 0, 255),
						math.clamp(math.round(SD.accentColor[2]), 0, 255),
						math.clamp(math.round(SD.accentColor[3]), 0, 255))
					WindowObj:SetAccent(Restored)
					accentPicker:Set(Restored, true)
				end
			end)
			pcall(function()
				if type(SD.backgroundColor) == "table" and #SD.backgroundColor >= 3 then
					WindowObj:SetTheme({Background = Color3.fromRGB(
						math.clamp(math.round(SD.backgroundColor[1]), 0, 255),
						math.clamp(math.round(SD.backgroundColor[2]), 0, 255),
						math.clamp(math.round(SD.backgroundColor[3]), 0, 255))})
				end
			end)
			pcall(function()
				if type(SD.textColor) == "table" and #SD.textColor >= 3 then
					WindowObj:SetTheme({Text = Color3.fromRGB(
						math.clamp(math.round(SD.textColor[1]), 0, 255),
						math.clamp(math.round(SD.textColor[2]), 0, 255),
						math.clamp(math.round(SD.textColor[3]), 0, 255))})
				end
			end)
			pcall(function()
				library.UpdateBlurSize()
			end)
		end

		local serverSection = settings_page:CreateSection({Name = "Server Utilities", Size = 240, Side = "Right"})

		serverSection:CreateButton({
			Name = "Copy Job ID",
			Callback = function()
				if setclipboard then
					pcall(setclipboard, game.JobId)
				elseif toclipboard then
					pcall(toclipboard, game.JobId)
				end
			end
		})

		local jobIdBox = serverSection:CreateTextBox({
			Name = "Target Job ID",
			State = "",
			Placeholder = "job id"
		})

		local hopStatus = serverSection:CreateLabel({Text = "hop: idle"})

		serverSection:CreateButton({
			Name = "Join via Job ID",
			Callback = function()
				local target = jobIdBox:Get()
				if target and target ~= "" then
					SaveSettingsNow()
					local Ok, Err = pcall(function()
						game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, target, game:GetService("Players").LocalPlayer)
					end)
					if not Ok then
						hopStatus:Set("join failed: " .. tostring(Err):match(":%d+: (.+)$"))
					end
				end
			end
		})

		local function HopServer(sortMode)
			local TeleportService = game:GetService("TeleportService")
			local Players = game:GetService("Players")
			local PlaceId = game.PlaceId
			local JobId = game.JobId
			SaveSettingsNow()
			hopStatus:Set("hop: searching...")
			local success, servers = pcall(function()
				return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
			end)
			if not success or typeof(servers) ~= "table" or type(servers.data) ~= "table" then
				hopStatus:Set("hop failed: api error")
				return
			end
			local candidateServers = {}
			for _, server in ipairs(servers.data) do
				local Playing, MaxPlayers = tonumber(server.playing), tonumber(server.maxPlayers)
				if type(server.id) == "string" and Playing and MaxPlayers
					and server.id ~= JobId and Playing < MaxPlayers and Playing > 0 then
					table.insert(candidateServers, {id = server.id, playing = Playing, maxPlayers = MaxPlayers})
				end
			end
			if #candidateServers == 0 then
				hopStatus:Set("hop failed: no servers")
				return
			end
			local Target
			if sortMode == "Highest" then
				table.sort(candidateServers, function(a, b) return a.playing > b.playing end)
				Target = candidateServers[1]
			elseif sortMode == "Lowest" then
				table.sort(candidateServers, function(a, b) return a.playing < b.playing end)
				Target = candidateServers[1]
			else
				Target = candidateServers[math.random(1, #candidateServers)]
			end
			hopStatus:Set("hop: teleporting (" .. tostring(Target.playing) .. "/" .. tostring(Target.maxPlayers) .. ")")
			local Ok, Err = pcall(function()
				TeleportService:TeleportToPlaceInstance(PlaceId, Target.id, Players.LocalPlayer)
			end)
			if not Ok then
				hopStatus:Set("hop failed: " .. tostring(Err):match(":%d+: (.+)$"))
			end
		end

		serverSection:CreateButton({
			Name = "Server Hop",
			Callback = function()
				HopServer("Random")
			end
		})

		serverSection:CreateButton({
			Name = "Hop to Highest Population",
			Callback = function()
				HopServer("Highest")
			end
		})

		serverSection:CreateButton({
			Name = "Hop to Lowest Population",
			Callback = function()
				HopServer("Lowest")
			end
		})
	end

	task.delay(0.3, function()
		if WindowObj.Unloaded or not WindowObj.AutoSave then return end
		if not WindowObj.SettingsData.autoLoadConfig then return end
		local waited = 0
		while WindowObj.Elements and next(WindowObj.Elements) == nil and waited < 3 and not WindowObj.Unloaded do
			task.wait(0.25)
			waited = waited + 0.25
		end
		if WindowObj.Unloaded or not WindowObj.Elements or next(WindowObj.Elements) == nil then return end
		local configName = WindowObj.SettingsData.config
		if type(configName) ~= "string" or configName == "" then
			if WindowObj.SetConfigStatus then
				WindowObj.SetConfigStatus("auto load: no config selected")
			end
			return
		end
		local status = ApplyConfigByName(configName)
		if WindowObj.SetConfigStatus then
			WindowObj.SetConfigStatus("auto " .. status)
		end
	end)

	task.defer(function()
		if not WindowObj.Unloaded then
			library.UpdateBlurSize()
		end
	end)

	return WindowObj
end
function library:CreatePage(Properties)
	Properties = Properties or {}
	local Page = {
		Image = utility:Resolve(Properties, {"image", "Image", "icon", "Icon"}, nil),
		Size = utility:Resolve(Properties, {"size", "Size"}, UDim2.new(0, 50, 0, 50)),
		Open = false,
		Window = self,
		Sections = {},
		IsSettings = utility:Resolve(Properties, {"issettings", "IsSettings"}, false)
	}
	local Page_Tab = utility:RenderObject(Page.Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		LayoutOrder = Properties.LayoutOrder or #Page.Window.Pages + 1,
		Parent = Page.Window.TabsHolder,
		Size = UDim2.new(1, 0, 0, 72)
	})
	local Page_Tab_ActiveBg = utility:RenderObject(Page.Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(24, 24, 24),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Page_Tab,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 2
	})
	local Page_Tab_Border = utility:RenderObject(Page.Window, "Frame", {
		AnchorPoint = Vector2.new(0, 0),
		BackgroundColor3 = Page.Window.Accent,
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Page_Tab,
		Position = UDim2.new(0, 0, 0, 8),
		Size = UDim2.new(0, 2, 1, -16),
		ZIndex = 3
	})
	local Page_Tab_Image = utility:RenderObject(Page.Window, "ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Page_Tab,
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = Page.Size,
		ZIndex = 2,
		Image = Page.Image,
		ImageColor3 = Color3.fromRGB(160, 160, 160)
	})
	local Page_Tab_Button = utility:RenderObject(Page.Window, "TextButton", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Page_Tab,
		Size = UDim2.new(1, 0, 1, 0),
		Text = ""
	})

	library.Renders[Page_Tab_ActiveBg].Hidden = true
	library.Renders[Page_Tab_Border].Hidden = true

	local Page_Page = utility:RenderObject(Page.Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Page.Window.PagesHolder,
		Position = UDim2.new(0, 20, 0, 20),
		Size = UDim2.new(1, -40, 1, -40),
		Visible = false,
		ZIndex = 100
	})
	local Page_Page_Left = utility:RenderObject(Page.Window, "ScrollingFrame", {
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Parent = Page_Page,
		Position = UDim2.new(0, 0, 0, 0),
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.new(0.5, -10, 1, 0)
	})
	local Page_Page_Right = utility:RenderObject(Page.Window, "ScrollingFrame", {
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Parent = Page_Page,
		Position = UDim2.new(0.5, 10, 0, 0),
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.new(0.5, -10, 1, 0)
	})
	local Page_Left_List = utility:RenderObject(Page.Window, "UIListLayout", {
		Padding = UDim.new(0, 18),
		Parent = Page_Page_Left,
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Top
	})
	local Page_Right_List = utility:RenderObject(Page.Window, "UIListLayout", {
		Padding = UDim.new(0, 18),
		Parent = Page_Page_Right,
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Top
	})

	Page.Page = Page_Page
	Page.Left = Page_Page_Left
	Page.Right = Page_Page_Right

	function Page:ApplyVisuals()
		TweenService:Create(Page_Tab_Image, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageColor3 = Page.Open and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 160)}):Play()
		TweenService:Create(Page_Tab_Border, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = Page.Open and 0 or 1}):Play()
		TweenService:Create(Page_Tab_ActiveBg, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = Page.Open and 0.35 or 1}):Play()
	end

	function Page:Set(state)
		Page.Open = state
		Page_Page.Visible = state
		Page:ApplyVisuals()
		if not state then
			if Page.Window.CloseOpenPopup and Page.Window.OpenContent then
				local OpenPopup = Page.Window.OpenContent
				if OpenPopup and OpenPopup.Page == Page then
					Page.Window:CloseOpenPopup()
				end
			end
			for _, section in ipairs(Page.Sections) do
				if section and section.Content and section.Content.Open then
					section:CloseContent()
				end
			end
		end
		if state then
			if Page.UserIndex and Page.Window.SettingsData and Page.Window.AutoSave then
				Page.Window.SettingsData.lastTab = Page.UserIndex
				utility:SaveSettings(library.Folder, library.ISettingsFile, Page.Window.SettingsData)
			end
			Page.Window:SetPage(Page)
		end
	end

	utility:CreateConnection(Page.Window, Page_Tab_Button.MouseButton1Click, function()
		if not Page.Open then
			Page:Set(true)
		end
	end)

	utility:CreateConnection(Page.Window, Page_Tab_Button.MouseEnter, function()
		if not Page.Open then
			TweenService:Create(Page_Tab_Image, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageColor3 = Color3.fromRGB(200, 200, 200)}):Play()
		end
	end)

	utility:CreateConnection(Page.Window, Page_Tab_Button.MouseLeave, function()
		if not Page.Open then
			TweenService:Create(Page_Tab_Image, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageColor3 = Color3.fromRGB(160, 160, 160)}):Play()
		end
	end)

	if not Page.IsSettings then
		Page.Window.UserPageCount = (Page.Window.UserPageCount or 0) + 1
		Page.UserIndex = Page.Window.UserPageCount
		if not Page.Window.FirstPageSet then
			Page.Window.FirstPageSet = true
			task.defer(function()
				local target = Page.Window.AutoSave and Page.Window.SettingsData and Page.Window.SettingsData.lastTab
				local targetPage = nil
				for _, p in ipairs(Page.Window.Pages) do
					if not p.IsSettings and p.UserIndex == target then
						targetPage = p
					end
				end
				if not targetPage then targetPage = Page end
				for _, p in ipairs(Page.Window.Pages) do p:Set(false) end
				targetPage:Set(true)
			end)
		end
	end
	table.insert(Page.Window.AccentElements, {
		Type = "Page",
		Element = Page,
		Object = Page_Tab_Border
	})
	Page.Window.Pages[#Page.Window.Pages + 1] = Page
	local function HandleColumnScroll()
		local OpenPopup = Page.Window.OpenContent
		if Page.Window.PopupsFollowScroll and OpenPopup and OpenPopup.Reposition then
			pcall(function()
				OpenPopup:Reposition()
			end)
		elseif Page.Window.CloseOpenPopup and not Page.Window.PopupsFollowScroll then
			Page.Window:CloseOpenPopup()
		end
	end
	utility:CreateConnection(Page.Window, Page_Page_Left:GetPropertyChangedSignal("CanvasPosition"), HandleColumnScroll)
	utility:CreateConnection(Page.Window, Page_Page_Right:GetPropertyChangedSignal("CanvasPosition"), HandleColumnScroll)
	return setmetatable(Page, pages)
end

function pages:CreateSection(Properties)
	Properties = Properties or {}
	local Window = self.Window
	local Section = {
		Name = utility:Resolve(Properties, {"name", "Name", "title", "Title"}, "New Section"),
		Size = utility:Resolve(Properties, {"size", "Size"}, 150),
		Side = utility:Resolve(Properties, {"side", "Side"}, "Left"),
		Content = {},
		Window = self.Window,
		Page = self
	}
	table.insert(self.Sections, Section)

	local Column = self[Section.Side == "Right" and "Right" or "Left"]
	local Section_Holder = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(40, 40, 40),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(12, 12, 12),
		BorderMode = Enum.BorderMode.Inset,
		BorderSizePixel = 1,
		ClipsDescendants = true,
		Parent = Column,
		Size = UDim2.new(1, 0, 0, Section.Size),
		ZIndex = 2
	})
	local Section_Holder_Extra = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Section_Holder,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 2
	})
	local Section_Holder_Frame = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(23, 23, 23),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Section_Holder,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 2
	})
	local Section_AccentBar = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Window.Accent,
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Section_Holder_Extra,
		Position = UDim2.new(0, 0, 0, 3),
		Size = UDim2.new(0, 2, 0, 13),
		ZIndex = 5
	})
	local Section_Holder_TitleInline = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Window.Accent,
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Section_Holder,
		Position = UDim2.new(0, 9, 0, -1),
		Size = UDim2.new(0, 30, 0, 2),
		ZIndex = 5
	})
	local Section_Holder_Title = utility:RenderObject(Window, "TextLabel", {
		AnchorPoint = Vector2.new(0, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Section_Holder,
		Position = UDim2.new(0, 12, 0, 4),
		Size = UDim2.new(1, -26, 0, 13),
		ZIndex = 5,
		Font = Enum.Font.Code,
		RichText = true,
		Text = "<b>" .. Section.Name .. "</b>",
		TextColor3 = Color3.fromRGB(205, 205, 205),
		TextSize = math.round(11 * (Window.TextScale or 1)),
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left
	})
	local Section_Chevron = utility:RenderObject(Window, "TextButton", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Section_Holder,
		Position = UDim2.new(1, -26, 0, 3),
		Size = UDim2.new(0, 22, 0, 16),
		Text = "",
		ZIndex = 5
	})
	local Chevron_Image = utility:RenderObject(Window, "ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Section_Chevron,
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 7, 0, 6),
		Image = "rbxassetid://8532000591",
		ImageColor3 = Color3.fromRGB(140, 140, 140),
		Rotation = 0,
		ZIndex = 5
	})
	local Holder_Extra_Gradient1 = utility:RenderObject(Window, "ImageLabel", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Section_Holder_Extra,
		Position = UDim2.new(0, 1, 0, 1),
		Rotation = 180,
		Size = UDim2.new(1, -2, 0, 20),
		Visible = false,
		ZIndex = 4,
		Image = "rbxassetid://7783533907",
		ImageColor3 = Color3.fromRGB(23, 23, 23)
	})
	local Holder_Extra_Gradient2 = utility:RenderObject(Window, "ImageLabel", {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Section_Holder_Extra,
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, -2, 0, 20),
		Visible = false,
		ZIndex = 4,
		Image = "rbxassetid://7783533907",
		ImageColor3 = Color3.fromRGB(23, 23, 23)
	})
	local Holder_Extra_Bar = utility:RenderObject(Window, "Frame", {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(45, 45, 45),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Section_Holder_Extra,
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 6, 1, 0),
		Visible = false,
		ZIndex = 4
	})
	local Holder_Extra_Line = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(45, 45, 45),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Section_Holder_Extra,
		Position = UDim2.new(0, 0, 0, -1),
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 4
	})
	local Holder_Frame_ContentHolder = utility:RenderObject(Window, "ScrollingFrame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Section_Holder_Frame,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BottomImage = "rbxassetid://7783554086",
		CanvasSize = UDim2.new(0, 0, 0, 0),
		MidImage = "rbxassetid://7783554086",
		ScrollBarImageColor3 = Color3.fromRGB(65, 65, 65),
		ScrollBarImageTransparency = 0,
		ScrollBarThickness = 5,
		TopImage = "rbxassetid://7783554086",
		VerticalScrollBarInset = Enum.ScrollBarInset.None
	})
	local Frame_ContentHolder_List = utility:RenderObject(Window, "UIListLayout", {
		Padding = UDim.new(0, 0),
		Parent = Holder_Frame_ContentHolder,
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Top
	})
	local Frame_ContentHolder_Padding = utility:RenderObject(Window, "UIPadding", {
		Parent = Holder_Frame_ContentHolder,
		PaddingTop = UDim.new(0, 15),
		PaddingBottom = UDim.new(0, 15)
	})
	Section_Holder_TitleInline.Size = UDim2.new(0, Section_Holder_Title.TextBounds.X + 6, 0, 2)
	task.defer(function()
		if Section_Holder_TitleInline.Parent ~= nil then
			Section_Holder_TitleInline.Size = UDim2.new(0, Section_Holder_Title.TextBounds.X + 6, 0, 2)
		end
	end)
	table.insert(Section.Window.AccentElements, {
		Type = "Section",
		Element = Section,
		Object = Section_Holder_TitleInline
	})
	table.insert(Section.Window.AccentElements, {
		Type = "Section",
		Element = Section,
		Object = Section_AccentBar
	})
	table.insert(Section.Window.ThemeElements, {Type = "Background", Object = Section_Holder, Shade = "Light"})
	table.insert(Section.Window.ThemeElements, {Type = "Background", Object = Section_Holder_Frame, Shade = "Base"})
	Section.Holder = Holder_Frame_ContentHolder
	Section.Extra = Section_Holder_Extra

	Section.Collapsed = false
	Section.OriginalSize = UDim2.new(1, 0, 0, Section.Size)
	local CollapsedHeight = 22
	local CollapseToken = 0

	local function ApplyCollapsed(state, instant)
		Section.Collapsed = state
		CollapseToken = CollapseToken + 1
		local Token = CollapseToken
		TweenService:Create(Chevron_Image, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Rotation = state and 180 or 0}):Play()
		local GoalSize = state and UDim2.new(1, 0, 0, CollapsedHeight) or Section.OriginalSize
		if instant then
			Holder_Frame_ContentHolder.Visible = not state
			Section_Holder_Extra.Visible = not state
			Section_Holder_Frame.Visible = not state
			Section_Holder.Size = GoalSize
			Chevron_Image.Rotation = state and 180 or 0
			return
		end
		Section_Holder.ClipsDescendants = true
		if state then
			TweenService:Create(Section_Holder, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = GoalSize}):Play()
			task.delay(0.19, function()
				if Token ~= CollapseToken or Section.Collapsed ~= true then return end
				Holder_Frame_ContentHolder.Visible = false
				Section_Holder_Extra.Visible = false
				Section_Holder_Frame.Visible = false
			end)
		else
			Holder_Frame_ContentHolder.Visible = true
			Section_Holder_Extra.Visible = true
			Section_Holder_Frame.Visible = true
			TweenService:Create(Section_Holder, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = GoalSize}):Play()
		end
	end

	local savedCollapsed = Section.Window.AutoSave and Section.Window.SettingsData and Section.Window.SettingsData.sections and Section.Window.SettingsData.sections[Section.Name]
	if savedCollapsed then
		ApplyCollapsed(true, true)
	end

	utility:CreateConnection(Section.Window, Section_Chevron.MouseButton1Click, function()
		if not Section.Collapsed then
			Section:CloseContent()
		end
		ApplyCollapsed(not Section.Collapsed)
		if Section.Window.SettingsData and Section.Window.AutoSave then
			Section.Window.SettingsData.sections = Section.Window.SettingsData.sections or {}
			Section.Window.SettingsData.sections[Section.Name] = Section.Collapsed
			utility:SaveSettings(library.Folder, library.ISettingsFile, Section.Window.SettingsData)
		end
	end)

	function Section:CloseContent()
		if Section.Content and Section.Content.Open then
			local Closing = Section.Content
			Section.Content = {}
			Closing:Close()
		end
	end

	utility:CreateConnection(Section.Window, Holder_Frame_ContentHolder:GetPropertyChangedSignal("AbsoluteCanvasSize"), function()
		local canvasY = Holder_Frame_ContentHolder.AbsoluteCanvasSize.Y > Holder_Frame_ContentHolder.AbsoluteWindowSize.Y
		Holder_Extra_Gradient1.Visible = canvasY
		Holder_Extra_Gradient2.Visible = canvasY
		Holder_Extra_Bar.Visible = canvasY
	end)

	utility:CreateConnection(Section.Window, Holder_Frame_ContentHolder:GetPropertyChangedSignal("CanvasPosition"), function()
		local OpenPopup = Section.Window.OpenContent
		if Section.Window.PopupsFollowScroll and OpenPopup and OpenPopup.Reposition then
			pcall(function()
				OpenPopup:Reposition()
			end)
			return
		end
		if Section.Content and Section.Content.Open then
			local Closing = Section.Content
			Section.Content = {}
			Closing:Close()
		end
	end)

	return setmetatable(Section, sections)
end
function sections:CreateToggle(Properties)
	Properties = Properties or {}
	local Window = self.Window
	local Content = {
		Name = utility:Resolve(Properties, {"name", "Name", "title", "Title"}, "New Toggle"),
		State = utility:Resolve(Properties, {"state", "State", "def", "Def", "default", "Default"}, false),
		Callback = utility:Resolve(Properties, {"callback", "Callback", "callBack", "CallBack"}, function() end),
		Window = self.Window,
		Page = self.Page,
		Section = self
	}
	local Content_Holder = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content.Section.Holder,
		Size = UDim2.new(1, 0, 0, 18),
		ZIndex = 3
	})
	local Content_Holder_Outline = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(12, 12, 12),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Position = UDim2.new(0, 20, 0, 4),
		Size = UDim2.new(0, 10, 0, 10),
		ZIndex = 3
	})
	utility:AddTitle(Window, Content_Holder, UDim2.new(0, 41, 0, 0), UDim2.new(1, -41, 1, 0), Content.Name, Color3.fromRGB(205, 205, 205), 3)
	local Content_Holder_Button = utility:RenderObject(Window, "TextButton", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Size = UDim2.new(1, 0, 1, 0),
		Text = ""
	})
	local Holder_Outline_Frame = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(77, 77, 77),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder_Outline,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 3
	})
	local Checkmark_Image = utility:RenderObject(Window, "ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Holder_Outline_Frame,
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 8, 0, 8),
		Image = "rbxassetid://6031094678",
		ImageColor3 = Color3.fromRGB(15, 15, 15),
		Visible = false,
		ZIndex = 4
	})
	local Outline_Frame_Gradient = utility:RenderObject(Window, "UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(140, 140, 140)),
		Enabled = true,
		Rotation = 90,
		Parent = Holder_Outline_Frame
	})

	function Content:Set(state, silent)
		Content.State = state and true or false
		Holder_Outline_Frame.BackgroundColor3 = Content.State and Content.Window.Accent or Color3.fromRGB(77, 77, 77)
		Checkmark_Image.Visible = Content.State
		if not silent then
			Content.Callback(Content:Get())
		end
	end

	function Content:Get()
		return Content.State
	end

	utility:CreateConnection(Window, Content_Holder_Button.MouseButton1Click, function()
		Content:Set(not Content:Get())
	end)

	utility:CreateConnection(Window, Content_Holder_Button.MouseEnter, function()
		if Window.OpenContent ~= nil then return end
		Outline_Frame_Gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(180, 180, 180))
	end)

	utility:CreateConnection(Window, Content_Holder_Button.MouseLeave, function()
		Outline_Frame_Gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(140, 140, 140))
	end)

	Content:Set(Content.State, true)
	self.Window.Elements[Content.Name] = {Element = Content, Type = "Toggle"}
	table.insert(self.Window.AccentElements, {
		Type = "Toggle",
		Element = Content,
		Object = Holder_Outline_Frame
	})
	return Content
end

local function EnsureSliderDispatcher(Window)
	if Window.SliderDispatcherReady then return end
	Window.SliderDispatcherReady = true
	utility:CreateConnection(Window, UserInputService.InputChanged, function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
			local Slider = Window.HoldingSlider
			if Slider and Slider.Holding then
				Slider:Refresh()
			end
		end
	end)
	utility:CreateConnection(Window, UserInputService.InputEnded, function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
			local Slider = Window.HoldingSlider
			if Slider and Slider.Holding then
				Slider.Holding = false
				Slider.OnRelease()
			end
		end
	end)
end

function sections:CreateSlider(Properties)
	Properties = Properties or {}
	local Window = self.Window
	EnsureSliderDispatcher(Window)
	local Content = {
		Name = utility:Resolve(Properties, {"name", "Name", "title", "Title"}, nil),
		State = utility:Resolve(Properties, {"state", "State", "def", "Def", "default", "Default"}, nil),
		Min = utility:Resolve(Properties, {"min", "Min", "minimum", "Minimum"}, 0),
		Max = utility:Resolve(Properties, {"max", "Max", "maximum", "Maximum"}, 100),
		Ending = utility:Resolve(Properties, {"ending", "Ending", "suffix", "Suffix"}, ""),
		Step = utility:Resolve(Properties, {"step", "Step", "decimals", "Decimals", "tick", "Tick"}, 1),
		Callback = utility:Resolve(Properties, {"callback", "Callback", "callBack", "CallBack"}, function() end),
		Holding = false,
		Window = self.Window,
		Page = self.Page,
		Section = self
	}
	if type(Content.Step) ~= "number" or Content.Step <= 0 then
		Content.Step = 1
	end
	if Content.Min > Content.Max then
		local SwapMin = Content.Min
		Content.Min = Content.Max
		Content.Max = SwapMin
	end
	if Content.State == nil then
		Content.State = Content.Min
	end
	local Content_Holder = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content.Section.Holder,
		Size = UDim2.new(1, 0, 0, (Content.Name and 24 or 13) + 5),
		ZIndex = 3
	})
	local Content_Holder_Outline = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(12, 12, 12),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Position = UDim2.new(0, 40, 0, Content.Name and 18 or 5),
		Size = UDim2.new(1, -98, 0, 7),
		ZIndex = 3
	})
	if Content.Name then
		utility:AddTitle(Window, Content_Holder, UDim2.new(0, 41, 0, 4), UDim2.new(1, -41, 0, 10), Content.Name, Color3.fromRGB(205, 205, 205), 3)
	end
	local Content_Holder_Button = utility:RenderObject(Window, "TextButton", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Size = UDim2.new(1, 0, 1, 0),
		Text = ""
	})
	local Holder_Outline_Frame = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(71, 71, 71),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder_Outline,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 3
	})
	local Outline_Frame_Slider = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Content.Window.Accent,
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Parent = Holder_Outline_Frame,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(0, 0, 1, 0),
		ZIndex = 3
	})
	local Outline_Frame_Gradient = utility:RenderObject(Window, "UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(175, 175, 175)),
		Enabled = true,
		Rotation = 270,
		Parent = Holder_Outline_Frame
	})
	local Frame_Slider_Gradient = utility:RenderObject(Window, "UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(175, 175, 175)),
		Enabled = true,
		Rotation = 90,
		Parent = Outline_Frame_Slider
	})
	local Frame_Slider_Title = utility:RenderObject(Window, "TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Holder_Outline_Frame,
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(0, 60, 1, 0),
		ZIndex = 5,
		Font = Enum.Font.Code,
		RichText = true,
		Text = "",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = math.round(11 * (Window.TextScale or 1)),
		TextStrokeTransparency = 0.6,
		TextXAlignment = Enum.TextXAlignment.Center
	})

	local VisualsApplied = false
	function Content:Set(state, silent)
		local NewState = math.clamp(math.round((tonumber(state) or Content.Min) / Content.Step) * Content.Step, Content.Min, Content.Max)
		local Changed = NewState ~= Content.State or not VisualsApplied
		VisualsApplied = true
		Content.State = NewState
		if Changed then
			local range = Content.Max - Content.Min
			local fraction
			if range > 0 then
				fraction = (Content.State - Content.Min) / range
			else
				fraction = 1
			end
			fraction = math.clamp(fraction, 0, 1)
			Frame_Slider_Title.Text = "<b>" .. tostring(Content.State) .. Content.Ending .. "</b>"
			Frame_Slider_Title.Position = UDim2.new(fraction, 0, 0.5, 0)
			Outline_Frame_Slider.Size = UDim2.new(fraction, 0, 1, 0)
		end
		if not silent then
			Content.Callback(Content:Get())
		end
	end

	function Content:Refresh()
		local Mouse = utility:MouseLocation()
		local trackPos = Holder_Outline_Frame.AbsolutePosition
		local trackSize = Holder_Outline_Frame.AbsoluteSize
		local pct = 0
		if trackSize.X > 0 then
			pct = math.clamp((Mouse.X - trackPos.X) / trackSize.X, 0, 1)
		end
		Content:Set(Content.Min + (Content.Max - Content.Min) * pct)
	end

	function Content:OnRelease()
		Outline_Frame_Gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(175, 175, 175))
		Frame_Slider_Gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(175, 175, 175))
	end

	function Content:Get()
		return Content.State
	end

	utility:CreateConnection(Window, Content_Holder_Button.MouseButton1Down, function()
		Content:Refresh()
		Content.Holding = true
		Window.HoldingSlider = Content
		Outline_Frame_Gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(215, 215, 215))
		Frame_Slider_Gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(215, 215, 215))
	end)

	utility:CreateConnection(Window, Content_Holder_Button.MouseEnter, function()
		if Window.OpenContent ~= nil then return end
		if not Content.Holding then
			Outline_Frame_Gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(215, 215, 215))
			Frame_Slider_Gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(215, 215, 215))
		end
	end)

	utility:CreateConnection(Window, Content_Holder_Button.MouseLeave, function()
		if not Content.Holding then
			Outline_Frame_Gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(175, 175, 175))
			Frame_Slider_Gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(175, 175, 175))
		end
	end)

	Content:Set(Content.State, true)
	if Content.Name then
		self.Window.Elements[Content.Name] = {Element = Content, Type = "Slider"}
	end
	table.insert(self.Window.AccentElements, {
		Type = "Slider",
		Element = Content,
		Object = Outline_Frame_Slider
	})
	return Content
end
local function BuildDropdownPopup(Content, Content_Holder_Outline, Title_Label, Arrow_Image, Multi)
	local Window = Content.Window
	local PageOverlay = Content.Page and Content.Page.Page
	if not PageOverlay then return end

	local MaxVisible = 8
	local RowHeight = 22
	local RowSpacing = 3
	local PopupPadding = 4
	local optionCount = math.max(#Content.Options, 1)
	local listHeight = math.min(optionCount, MaxVisible) * RowHeight + math.max(math.min(optionCount, MaxVisible) - 1, 0) * RowSpacing + PopupPadding * 2

	local Popup_Holder = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = PageOverlay,
		Size = UDim2.new(0, Content_Holder_Outline.AbsoluteSize.X, 0, listHeight),
		Active = true,
		Visible = false,
		ZIndex = 100
	})
	local Popup_Catcher = utility:RenderObject(Window, "TextButton", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = PageOverlay,
		Position = UDim2.new(0, -20, 0, -20),
		Size = UDim2.new(1, 40, 1, 40),
		Text = "",
		Visible = false,
		ZIndex = 90
	})
	utility:CreateConnection(Window, Popup_Catcher.MouseButton1Click, function()
		if Content._PressInside then
			Content._PressInside = nil
			return
		end
		Content:Close()
	end)
	utility:CreateConnection(Window, UserInputService.InputBegan, function(Input)
		if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then return end
		if not Content:IsOpen() then return end
		Content._PressInside = nil
		local Point = Vector2.new(Input.Position.X, Input.Position.Y)
		local AP, AS = Popup_Holder.AbsolutePosition, Popup_Holder.AbsoluteSize
		if Point.X >= AP.X and Point.X <= AP.X + AS.X and Point.Y >= AP.Y and Point.Y <= AP.Y + AS.Y then
			Content._PressInside = true
			return
		end
		local OP, OS = Content_Holder_Outline.AbsolutePosition, Content_Holder_Outline.AbsoluteSize
		if Point.X >= OP.X and Point.X <= OP.X + OS.X and Point.Y >= OP.Y and Point.Y <= OP.Y + OS.Y then
			return
		end
		Content:Close()
	end)
	local Popup_Outline = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(12, 12, 12),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Popup_Holder,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 101
	})
	local Popup_Inner = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(28, 28, 28),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Popup_Outline,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 102
	})
	local Popup_ScrollingFrame = utility:RenderObject(Window, "ScrollingFrame", {
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Parent = Popup_Inner,
		Position = UDim2.new(0, 1, 0, 1),
		ScrollBarImageColor3 = Color3.fromRGB(65, 65, 65),
		ScrollBarThickness = 2,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 103
	})
	local Popup_ListLayout = utility:RenderObject(Window, "UIListLayout", {
		Padding = UDim.new(0, RowSpacing),
		Parent = Popup_ScrollingFrame,
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top
	})
	local Popup_ScrollPadding = utility:RenderObject(Window, "UIPadding", {
		PaddingTop = UDim.new(0, PopupPadding),
		PaddingBottom = UDim.new(0, PopupPadding),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
		Parent = Popup_ScrollingFrame
	})

	local RowButtons = {}

	local function IsSelected(Index)
		if Multi then
			return table.find(Content.State, Index) ~= nil
		else
			return Content.State == Index
		end
	end

	local function BuildRows()
		for _, Child in ipairs(Popup_ScrollingFrame:GetChildren()) do
			if Child:IsA("TextButton") or Child:IsA("Frame") then
				utility:DestroyObject(Window, Child)
			end
		end
		RowButtons = {}
		for Index, Option in ipairs(Content.Options) do
			local RowButton = utility:RenderObject(Window, "TextButton", {
				AutoButtonColor = false,
				BackgroundColor3 = Color3.fromRGB(28, 28, 28),
				BackgroundTransparency = 0,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				LayoutOrder = Index,
				Parent = Popup_ScrollingFrame,
				Size = UDim2.new(1, 0, 0, RowHeight),
				Text = "",
				ZIndex = 104
			})
			local RowLabel = utility:RenderObject(Window, "TextLabel", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = RowButton,
				Position = Multi and UDim2.new(0, 24, 0, 0) or UDim2.new(0, 6, 0, 0),
				Size = Multi and UDim2.new(1, -30, 1, 0) or UDim2.new(1, -12, 1, 0),
				ZIndex = 105,
				Font = Enum.Font.Code,
				Text = tostring(Option),
				TextColor3 = IsSelected(Index) and Window.Accent or Color3.fromRGB(195, 195, 195),
				TextSize = math.round(11 * (Window.TextScale or 1)),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd
			})
			if Multi then
				local CheckOuter = utility:RenderObject(Window, "Frame", {
					BackgroundColor3 = Color3.fromRGB(12, 12, 12),
					BackgroundTransparency = 0,
					BorderColor3 = Color3.fromRGB(0, 0, 0),
					BorderSizePixel = 0,
					Parent = RowButton,
					Position = UDim2.new(0, 6, 0, 4),
					Size = UDim2.new(0, 10, 0, 10),
					ZIndex = 105
				})
				local CheckInner = utility:RenderObject(Window, "Frame", {
					BackgroundColor3 = IsSelected(Index) and Window.Accent or Color3.fromRGB(77, 77, 77),
					BackgroundTransparency = 0,
					BorderColor3 = Color3.fromRGB(0, 0, 0),
					BorderSizePixel = 0,
					Parent = CheckOuter,
					Position = UDim2.new(0, 1, 0, 1),
					Size = UDim2.new(1, -2, 1, -2),
					ZIndex = 106
				})
				table.insert(RowButtons, {Button = RowButton, Label = RowLabel, Inner = CheckInner, Index = Index})
			else
				table.insert(RowButtons, {Button = RowButton, Label = RowLabel, Inner = nil, Index = Index})
			end
			utility:CreateConnection(Window, RowButton.MouseButton1Down, function()
				if Multi then
					local CurrentIndex = table.find(Content.State, Index)
					if CurrentIndex then
						table.remove(Content.State, CurrentIndex)
					else
						if #Content.State >= Content.Maximum then
							table.remove(Content.State, 1)
						end
						table.insert(Content.State, Index)
					end
					Content:Set(Content.State)
					for _, Entry in ipairs(RowButtons) do
						local Selected = IsSelected(Entry.Index)
						Entry.Label.TextColor3 = Selected and Window.Accent or Color3.fromRGB(195, 195, 195)
						if Entry.Inner then
							Entry.Inner.BackgroundColor3 = Selected and Window.Accent or Color3.fromRGB(77, 77, 77)
						end
					end
				else
					Content:Set(Index)
					Title_Label.Text = tostring(Content.Options[Content.State] or "-")
					for _, Entry in ipairs(RowButtons) do
						Entry.Label.TextColor3 = Entry.Index == Content.State and Window.Accent or Color3.fromRGB(195, 195, 195)
					end
					task.defer(function()
						Content:Close()
					end)
				end
			end)
			utility:CreateConnection(Window, RowButton.MouseEnter, function()
				if Window.OpenContent ~= nil and Window.OpenContent ~= Content then return end
				RowButton.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
			end)
			utility:CreateConnection(Window, RowButton.MouseLeave, function()
				RowButton.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
			end)
		end
	end

	function Content:Reposition()
		if not Popup_Holder.Visible and not Content._ScrollHidden then return end
		local OverlayAbs = PageOverlay.AbsolutePosition
		local OverlaySize = PageOverlay.AbsoluteSize
		local AnchorPos = Content_Holder_Outline.AbsolutePosition
		local AnchorSize = Content_Holder_Outline.AbsoluteSize
		local OverlayTop = OverlayAbs.Y
		local OverlayBottom = OverlayAbs.Y + OverlaySize.Y
		local AnchorTop = AnchorPos.Y
		local AnchorBottom = AnchorTop + AnchorSize.Y
		if AnchorBottom < OverlayTop or AnchorTop > OverlayBottom then
			if not Content._ScrollHidden then
				Content._ScrollHidden = true
				Popup_Holder.Visible = false
				Popup_Catcher.Visible = false
			end
			return
		end
		if Content._ScrollHidden then
			Content._ScrollHidden = nil
			Popup_Catcher.Visible = true
			Popup_Holder.Visible = true
		end
		local Width = Popup_Holder.AbsoluteSize.X
		local Height = Popup_Holder.AbsoluteSize.Y
		local DesiredY
		if AnchorBottom < OverlayTop + Height then
			DesiredY = OverlayTop
		elseif AnchorTop > OverlayBottom - Height then
			DesiredY = math.max(OverlayBottom - Height, OverlayTop)
		elseif AnchorBottom + 2 + Height <= OverlayBottom then
			DesiredY = AnchorBottom + 2
		elseif AnchorTop - Height - 2 >= OverlayTop then
			DesiredY = AnchorTop - Height - 2
		else
			DesiredY = math.clamp(AnchorTop, OverlayTop, math.max(OverlayTop, OverlayBottom - Height))
		end
		local DesiredX = AnchorPos.X
		DesiredX = math.clamp(DesiredX, OverlayAbs.X, math.max(OverlayAbs.X, OverlayAbs.X + OverlaySize.X - Width))
		Popup_Holder.Position = UDim2.new(0, DesiredX - OverlayAbs.X, 0, DesiredY - OverlayAbs.Y)
	end

	function Content:Open()
		if Window.OpenContent == Content then return end
		Window:CloseOpenPopup()
		Window.OpenContent = Content
		Popup_Holder.Size = UDim2.new(0, math.max(Content_Holder_Outline.AbsoluteSize.X, 40), 0, listHeight)
		Content._ScrollHidden = nil
		Popup_Catcher.Visible = true
		Popup_Holder.Visible = true
		TweenService:Create(Arrow_Image, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Rotation = 180}):Play()
		BuildRows()
		Content:Reposition()
	end

	function Content:Close()
		if not Popup_Holder.Visible and not Content._ScrollHidden then return end
		Content._ScrollHidden = nil
		Popup_Holder.Visible = false
		Popup_Catcher.Visible = false
		TweenService:Create(Arrow_Image, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Rotation = 0}):Play()
		if Window.OpenContent == Content then
			Window.OpenContent = nil
		end
	end

	function Content:IsOpen()
		return Popup_Holder.Visible or Content._ScrollHidden == true
	end

	function Content:GetPopupHolder()
		return Popup_Holder
	end

	function Content:Refresh()
		for _, Entry in ipairs(RowButtons) do
			local Selected = IsSelected(Entry.Index)
			Entry.Label.TextColor3 = Selected and Window.Accent or Color3.fromRGB(195, 195, 195)
			if Entry.Inner then
				Entry.Inner.BackgroundColor3 = Selected and Window.Accent or Color3.fromRGB(77, 77, 77)
			end
		end
	end

	function Content:RefreshOptions(Options)
		Content.Options = type(Options) == "table" and Options or {}
		optionCount = math.max(#Content.Options, 1)
		listHeight = math.min(optionCount, MaxVisible) * RowHeight + math.max(math.min(optionCount, MaxVisible) - 1, 0) * RowSpacing + PopupPadding * 2
		Popup_Holder.Size = UDim2.new(0, Content_Holder_Outline.AbsoluteSize.X, 0, listHeight)
		if Multi then
			Content:Set({}, true)
		else
			Content.State = math.clamp(Content.State, 1, optionCount)
			Outline_Frame_Title.Text = optionCount > 0 and tostring(Content.Options[Content.State] or "-") or "-"
		end
	end
	Content.SetOptions = Content.RefreshOptions
end

function sections:CreateDropdown(Properties)
	Properties = Properties or {}
	local Window = self.Window
	local Content = {
		Name = utility:Resolve(Properties, {"name", "Name", "title", "Title"}, "New Dropdown"),
		State = utility:Resolve(Properties, {"state", "State", "def", "Def", "default", "Default"}, 1),
		Options = utility:Resolve(Properties, {"options", "Options", "list", "List"}, {}),
		Callback = utility:Resolve(Properties, {"callback", "Callback", "callBack", "CallBack"}, function() end),
		Type = "Dropdown",
		Window = self.Window,
		Page = self.Page,
		Section = self
	}
	if type(Content.Options) ~= "table" then
		Content.Options = {}
	end
	local Content_Holder = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content.Section.Holder,
		Size = UDim2.new(1, 0, 0, (Content.Name and 24 or 13) + 15),
		ZIndex = 3
	})
	local Content_Holder_Outline = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(12, 12, 12),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Position = UDim2.new(0, 40, 0, Content.Name and 18 or 4),
		Size = UDim2.new(1, -98, 0, 20),
		ZIndex = 3
	})
	if Content.Name then
		utility:AddTitle(Window, Content_Holder, UDim2.new(0, 41, 0, 4), UDim2.new(1, -41, 0, 10), Content.Name, Color3.fromRGB(205, 205, 205), 3)
	end
	local Content_Holder_Button = utility:RenderObject(Window, "TextButton", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Size = UDim2.new(1, 0, 1, 0),
		Text = ""
	})
	local Holder_Outline_Frame = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(35, 35, 35),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder_Outline,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 3
	})
	local Outline_Frame_Title = utility:RenderObject(Window, "TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Holder_Outline_Frame,
		Position = UDim2.new(0, 5, 0.5, 0),
		Size = UDim2.new(1, -25, 0, 14),
		ZIndex = 4,
		Font = Enum.Font.Code,
		RichText = true,
		Text = "",
		TextColor3 = Color3.fromRGB(205, 205, 205),
		TextSize = math.round(11 * (Window.TextScale or 1)),
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd
	})
	local Arrow_Image = utility:RenderObject(Window, "ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Holder_Outline_Frame,
		Position = UDim2.new(1, -9, 0.5, 0),
		Rotation = 180,
		Size = UDim2.new(0, 8, 0, 8),
		Image = "rbxassetid://6031094678",
		ImageColor3 = Color3.fromRGB(160, 160, 160),
		ZIndex = 4
	})

	function Content:Set(state, silent)
		local Count = #Content.Options
		local TargetState
		if type(state) == "string" then
			TargetState = table.find(Content.Options, state)
		elseif type(state) == "number" then
			TargetState = math.floor(state)
		end
		if Count <= 0 then
			TargetState = 1
		else
			TargetState = math.clamp(TargetState or 1, 1, Count)
		end
		if Content.State == TargetState and Count > 0 then
			return
		end
		Content.State = TargetState
		if Count <= 0 then
			Outline_Frame_Title.Text = "-"
		else
			Outline_Frame_Title.Text = tostring(Content.Options[Content.State] or "-")
		end
		if not silent then
			Content.Callback(Content.State)
		end
	end

	function Content:Get()
		return Content.State
	end

	utility:CreateConnection(Window, Content_Holder_Button.MouseButton1Click, function()
		if Window.OpenContent == Content then
			Content:Close()
		else
			Content:Open()
		end
	end)

	BuildDropdownPopup(Content, Content_Holder_Outline, Outline_Frame_Title, Arrow_Image, false)
	Content:Set(Content.State, true)
	if Content.Name then
		self.Window.Elements[Content.Name] = {Element = Content, Type = "Dropdown"}
	end
	return Content
end

function sections:CreateMultibox(Properties)
	Properties = Properties or {}
	local Window = self.Window
	local Content = {
		Name = utility:Resolve(Properties, {"name", "Name", "title", "Title"}, "New Multibox"),
		State = {},
		Options = utility:Resolve(Properties, {"options", "Options", "list", "List"}, {}),
		Maximum = utility:Resolve(Properties, {"maximum", "Maximum", "max", "Max"}, math.huge),
		Minimum = utility:Resolve(Properties, {"minimum", "Minimum", "min", "Min"}, 0),
		Callback = utility:Resolve(Properties, {"callback", "Callback", "callBack", "CallBack"}, function() end),
		Type = "Multibox",
		Window = self.Window,
		Page = self.Page,
		Section = self
	}
	if type(Content.Options) ~= "table" then
		Content.Options = {}
	end
	if type(Content.Maximum) ~= "number" then
		Content.Maximum = math.huge
	end
	if type(Content.Minimum) ~= "number" then
		Content.Minimum = 0
	end
	local Content_Holder = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content.Section.Holder,
		Size = UDim2.new(1, 0, 0, (Content.Name and 24 or 13) + 15),
		ZIndex = 3
	})
	local Content_Holder_Outline = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(12, 12, 12),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Position = UDim2.new(0, 40, 0, Content.Name and 18 or 4),
		Size = UDim2.new(1, -98, 0, 20),
		ZIndex = 3
	})
	if Content.Name then
		utility:AddTitle(Window, Content_Holder, UDim2.new(0, 41, 0, 4), UDim2.new(1, -41, 0, 10), Content.Name, Color3.fromRGB(205, 205, 205), 3)
	end
	local Content_Holder_Button = utility:RenderObject(Window, "TextButton", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Size = UDim2.new(1, 0, 1, 0),
		Text = ""
	})
	local Holder_Outline_Frame = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(35, 35, 35),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder_Outline,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 3
	})
	local Outline_Frame_Title = utility:RenderObject(Window, "TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Holder_Outline_Frame,
		Position = UDim2.new(0, 5, 0.5, 0),
		Size = UDim2.new(1, -25, 0, 14),
		ZIndex = 4,
		Font = Enum.Font.Code,
		RichText = true,
		Text = "",
		TextColor3 = Color3.fromRGB(205, 205, 205),
		TextSize = math.round(11 * (Window.TextScale or 1)),
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd
	})
	local Arrow_Image = utility:RenderObject(Window, "ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Holder_Outline_Frame,
		Position = UDim2.new(1, -9, 0.5, 0),
		Rotation = 180,
		Size = UDim2.new(0, 8, 0, 8),
		Image = "rbxassetid://6031094678",
		ImageColor3 = Color3.fromRGB(160, 160, 160),
		ZIndex = 4
	})

	function Content:Serialise()
		local Names = {}
		for _, Index in ipairs(Content.State) do
			Names[#Names + 1] = tostring(Content.Options[Index] or "?")
		end
		return next(Names) and table.concat(Names, ", ") or "-"
	end

	function Content:Set(state, silent)
		local CleanedIndices = {}
		local SeenIndices = {}
		if type(state) == "table" then
			for _, RawIndex in ipairs(state) do
				local NumericIndex = tonumber(RawIndex)
				if NumericIndex and NumericIndex >= 1 and NumericIndex <= #Content.Options and not SeenIndices[NumericIndex] then
					SeenIndices[NumericIndex] = true
					CleanedIndices[#CleanedIndices + 1] = NumericIndex
				elseif type(RawIndex) == "string" then
					local FoundIndex = table.find(Content.Options, RawIndex)
					if FoundIndex and not SeenIndices[FoundIndex] then
						SeenIndices[FoundIndex] = true
						CleanedIndices[#CleanedIndices + 1] = FoundIndex
					end
				end
			end
		end
		table.sort(CleanedIndices)
		while #CleanedIndices > Content.Maximum do
			table.remove(CleanedIndices, #CleanedIndices)
		end
		if Content.Minimum > 0 and #CleanedIndices < Content.Minimum then
			local PaddedIndex = 1
			while #CleanedIndices < Content.Minimum and PaddedIndex <= #Content.Options do
				if not SeenIndices[PaddedIndex] then
					SeenIndices[PaddedIndex] = true
					CleanedIndices[#CleanedIndices + 1] = PaddedIndex
				end
				PaddedIndex = PaddedIndex + 1
			end
			table.sort(CleanedIndices)
		end
		Content.State = CleanedIndices
		Outline_Frame_Title.Text = Content:Serialise()
		if not silent then
			Content.Callback(Content:Get())
		end
	end

	function Content:Get()
		return Content.State
	end

	utility:CreateConnection(Window, Content_Holder_Button.MouseButton1Click, function()
		if Window.OpenContent == Content then
			Content:Close()
		else
			Content:Open()
		end
	end)

	BuildDropdownPopup(Content, Content_Holder_Outline, Outline_Frame_Title, Arrow_Image, true)
	Content:Set(Content.State, true)
	self.Window.Elements[Content.Name] = {Element = Content, Type = "Multibox"}
	return Content
end
local Keys = {
	Shortened = {
		MouseButton1 = "M1",
		MouseButton2 = "M2",
		MouseButton3 = "M3",
		MiddleMouseButton = "M3",
		ScrollWheelUp = "WD",
		ScrollWheelDown = "WS",
		CapsLock = "CAPS",
		Backquote = "`",
		LeftShift = "LSHIFT",
		RightShift = "RSHIFT",
		LeftControl = "LCTRL",
		RightControl = "RCTRL",
		LeftAlt = "LALT",
		RightAlt = "RALT",
		Minus = "-",
		Equals = "=",
		Backspace = "BS",
		Return = "ENTER",
		Period = ".",
		Comma = ",",
		Slash = "/",
		Backslash = "\\",
		Semicolon = ";",
		Quote = "'",
		LeftBracket = "[",
		RightBracket = "]",
		Insert = "INS",
		Delete = "DEL",
		PageUp = "PGUP",
		PageDown = "PGDN",
		NumPadZero = "NUM0",
		NumPadOne = "NUM1",
		NumPadTwo = "NUM2",
		NumPadThree = "NUM3",
		NumPadFour = "NUM4",
		NumPadFive = "NUM5",
		NumPadSix = "NUM6",
		NumPadSeven = "NUM7",
		NumPadEight = "NUM8",
		NumPadNine = "NUM9"
	}
}

local function Shorten(KeyName)
	return Keys.Shortened[KeyName] or KeyName
end

local function EnsureKeybindDispatcher(Window)
	if Window.KeybindDispatcherReady then return end
	Window.KeybindDispatcherReady = true
	utility:CreateConnection(Window, UserInputService.InputBegan, function(Input, Typing)
		if Typing or UserInputService:GetFocusedTextBox() then return end
		for _, Keybind in ipairs(Window.Keybinds) do
			Keybind:OnInputBegan(Input)
		end
	end)
	utility:CreateConnection(Window, UserInputService.InputEnded, function(Input, Typing)
		if Typing then return end
		for _, Keybind in ipairs(Window.Keybinds) do
			Keybind:OnInputEnded(Input)
		end
	end)
end

function sections:CreateKeybind(Properties)
	Properties = Properties or {}
	local Window = self.Window
	EnsureKeybindDispatcher(Window)
	local Content = {
		Name = utility:Resolve(Properties, {"name", "Name", "title", "Title"}, "New Keybind"),
		State = utility:Resolve(Properties, {"state", "State", "def", "Def", "default", "Default"}, {"KeyCode", "Insert"}),
		Mode = utility:Resolve(Properties, {"mode", "Mode"}, "Always"),
		Callback = utility:Resolve(Properties, {"callback", "Callback", "callBack", "CallBack"}, function() end),
		Type = "Keybind",
		Holding = false,
		Active = false,
		Window = self.Window,
		Page = self.Page,
		Section = self
	}
	if Content.Mode ~= "Hold" and Content.Mode ~= "Toggle" and Content.Mode ~= "Always" then
		Content.Mode = "Always"
	end
	if type(Content.State) ~= "table" or type(Content.State[1]) ~= "string" or type(Content.State[2]) ~= "string" then
		Content.State = {"KeyCode", "Insert"}
	else
		local TestEnum = Enum[Content.State[1]]
		if TestEnum == nil or TestEnum[Content.State[2]] == nil then
			Content.State = {"KeyCode", "Insert"}
		end
	end
	local function ResolveBound(State)
		local EnumType = type(State[1]) == "string" and Enum[State[1]]
		return (EnumType and EnumType[State[2]]) or nil
	end
	Content.Bound = ResolveBound(Content.State)
	local Content_Holder = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content.Section.Holder,
		Size = UDim2.new(1, 0, 0, (Content.Name and 24 or 13) + 5),
		ZIndex = 3
	})
	local Content_Holder_Outline = utility:RenderObject(Window, "Frame", {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(12, 12, 12),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Position = UDim2.new(1, -40, 0, 3),
		Size = UDim2.new(0, 36, 0, 12),
		ZIndex = 3
	})
	if Content.Name then
		utility:AddTitle(Window, Content_Holder, UDim2.new(0, 41, 0, 4), UDim2.new(1, -81, 0, 10), Content.Name, Color3.fromRGB(205, 205, 205), 3)
	end
	local Content_Holder_Button = utility:RenderObject(Window, "TextButton", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Size = UDim2.new(1, 0, 1, 0),
		Text = ""
	})
	local Holder_Outline_Frame = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(35, 35, 35),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = Content_Holder_Outline,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 3
	})
	local Outline_Frame_Value = utility:RenderObject(Window, "TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Holder_Outline_Frame,
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(1, -4, 1, 0),
		ZIndex = 4,
		Font = Enum.Font.Code,
		RichText = true,
		Text = "<b>" .. Shorten(Content.State[2]) .. "</b>",
		TextColor3 = Color3.fromRGB(114, 114, 114),
		TextSize = math.round(11 * (Window.TextScale or 1)),
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd
	})

	function Content:UpdateValueColor()
		local TargetColor = Content.Holding and Color3.fromRGB(255, 60, 60) or (Content.Active and Window.Accent or Color3.fromRGB(114, 114, 114))
		TweenService:Create(Outline_Frame_Value, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextColor3 = TargetColor}):Play()
	end

	function Content:Change(Key)
		if typeof(Key) ~= "EnumItem" then
			return false
		end
		local OkType, TypeName = pcall(function()
			return (tostring(Key.EnumType):gsub("^Enum%.", ""))
		end)
		local OkName, KeyName = pcall(function()
			return tostring(Key.Name)
		end)
		if not OkType or not OkName or not TypeName or not KeyName or TypeName == "" or KeyName == "" then
			return false
		end
		Content.State = {TypeName, KeyName}
		Content.Bound = ResolveBound(Content.State)
		Outline_Frame_Value.Text = "<b>" .. Shorten(KeyName) .. "</b>"
		if not Content.Holding then
			Content.Callback({TypeName, KeyName})
		end
		return true
	end

	function Content:Set(state, silent)
		if type(state) == "table" then
			if type(state[1]) == "string" and type(state[2]) == "string" then
				local TestEnum = Enum[state[1]]
				if TestEnum and TestEnum[state[2]] then
					Content.State = {state[1], state[2]}
					Content.Bound = ResolveBound(Content.State)
					Outline_Frame_Value.Text = "<b>" .. Shorten(state[2]) .. "</b>"
				end
			elseif state.type and state.value and Enum[state.type] and Enum[state.type][state.value] then
				Content.State = {state.type, state.value}
				Content.Bound = ResolveBound(Content.State)
				Outline_Frame_Value.Text = "<b>" .. Shorten(state.value) .. "</b>"
			end
		elseif type(state) == "boolean" then
			Content.Active = state
			if Content.Mode ~= "Always" then
				Content.Callback(state)
			end
		end
		if not silent then
			Content.Callback({Content.State[1], Content.State[2]})
		end
		Content:UpdateValueColor()
	end

	function Content:Get()
		return {Content.State[1], Content.State[2], Content.Active}
	end

	function Content:OnInputBegan(Input)
		if UserInputService:GetFocusedTextBox() and not Content.Holding then
			return
		end
		if Content.Holding then
			local Key = (Input.KeyCode ~= Enum.KeyCode.Unknown) and Input.KeyCode or Input.UserInputType
			if typeof(Key) ~= "EnumItem" or Key == Enum.UserInputType.MouseMovement or Key == Enum.UserInputType.None then
				return
			end
			if Content:Change(Key) then
				Content.Holding = false
				Content:UpdateValueColor()
			end
			return
		end
		local Bound = Content.Bound
		if Bound and (Input.KeyCode == Bound or Input.UserInputType == Bound) then
			if Content.Mode == "Hold" then
				Content.Active = true
				Content:UpdateValueColor()
				Content.Callback(true)
			elseif Content.Mode == "Toggle" then
				Content.Active = not Content.Active
				Content:UpdateValueColor()
				Content.Callback(Content.Active)
			end
		end
	end

	function Content:OnInputEnded(Input)
		if Content.Mode == "Hold" and Content.Active then
			local Bound = Content.Bound
			if Bound and (Input.KeyCode == Bound or Input.UserInputType == Bound) then
				Content.Active = false
				Content:UpdateValueColor()
				Content.Callback(false)
			end
		end
	end

	utility:CreateConnection(Window, Outline_Frame_Value.MouseButton1Click, function()
		Content.Holding = true
		Content:UpdateValueColor()
	end)

	utility:CreateConnection(Window, Content_Holder_Button.MouseButton2Click, function()
		if not Content.Holding then
			Content:Change(Enum.KeyCode.Unknown)
			Content.Active = false
			Content:UpdateValueColor()
		end
	end)

	Content:UpdateValueColor()
	self.Window.Elements[Content.Name] = {Element = Content, Type = "Keybind"}
	table.insert(Window.Keybinds, Content)
	table.insert(self.Window.AccentElements, {
		Type = "Value",
		Element = Content,
		Object = Outline_Frame_Value
	})
	return Content
end

function sections:CreateColorpicker(Properties)
	Properties = Properties or {}
	local Window = self.Window
	local Content = {
		Name = utility:Resolve(Properties, {"name", "Name", "title", "Title"}, "New Colorpicker"),
		State = utility:Resolve(Properties, {"state", "State", "def", "Def", "default", "Default"}, Color3.fromRGB(255, 255, 255)),
		Callback = utility:Resolve(Properties, {"callback", "Callback", "callBack", "CallBack"}, function() end),
		Type = "Colorpicker",
		Window = self.Window,
		Page = self.Page,
		Section = self
	}
	local Content_HSV = {Content.State:ToHSV()}
	local Content_Holder = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content.Section.Holder,
		Size = UDim2.new(1, 0, 0, 18),
		ZIndex = 3
	})
	local Content_Holder_Outline = utility:RenderObject(Window, "Frame", {
		AnchorPoint = Vector2.new(0, 0),
		BackgroundColor3 = Color3.fromRGB(12, 12, 12),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Position = UDim2.new(1, -42, 0, 3),
		Size = UDim2.new(0, 22, 0, 12),
		ZIndex = 3
	})
	if Content.Name then
		utility:AddTitle(Window, Content_Holder, UDim2.new(0, 41, 0, 4), UDim2.new(1, -83, 0, 10), Content.Name, Color3.fromRGB(205, 205, 205), 3)
	end
	local Content_Holder_Button = utility:RenderObject(Window, "TextButton", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Size = UDim2.new(1, 0, 1, 0),
		Text = ""
	})
	local Holder_Swatch_Inner = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Content.State,
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder_Outline,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 3
	})

	local function ColorToHex(Color)
		return string.format("%02x%02x%02x",
			math.round(math.clamp(Color.R, 0, 1) * 255),
			math.round(math.clamp(Color.G, 0, 1) * 255),
			math.round(math.clamp(Color.B, 0, 1) * 255))
	end
	local function ParseHex(RawHex)
		local HexString = tostring(RawHex):gsub("#", ""):gsub("0x", "")
		if #HexString == 6 and HexString:match("^%x+$") then
			return Color3.fromRGB(
				tonumber(HexString:sub(1, 2), 16),
				tonumber(HexString:sub(3, 4), 16),
				tonumber(HexString:sub(5, 6), 16)
			)
		end
	end

	local PopupBuilt = false
	local Popup_Holder, SwatchCursor, ValSatCursor, HueCursor, HexBox
	local Parts = {}

	local function ApplyHSV()
		local H, S, V = Parts.H, Parts.S, Parts.V
		local BaseColor = Color3.fromHSV(H, 1, 1)
		Parts.ValSatBase.BackgroundColor3 = BaseColor
		Parts.SwatchInner.BackgroundColor3 = Color3.fromHSV(H, S, V)
		Parts.ValSatCursor.BackgroundColor3 = Color3.fromHSV(H, S, V)
		local SatFraction = math.clamp(S, 0, 1)
		local ValFraction = math.clamp(V, 0, 1)
		Parts.ValSatCursor.Position = UDim2.new(math.clamp(SatFraction * 0.94 + 0.03, 0.03, 0.97), 0, math.clamp((1 - ValFraction) * 0.96 + 0.02, 0.02, 0.98), 0)
		Parts.HueCursor.Position = UDim2.new(0, 0, math.clamp(H, 0.02, 0.98), 0)
		if HexBox then
			HexBox.Text = "#" .. string.upper(ColorToHex(Color3.fromHSV(H, S, V)))
		end
		Content.State = Color3.fromHSV(H, S, V)
		Content_HSV = {H, S, V}
	end

	local function StartValSatDrag()
		Parts.DraggingValSat = true
	end

	local function StartHueDrag()
		Parts.DraggingHue = true
	end

	local function StopDrags()
		local WasDragging = Parts.DraggingValSat or Parts.DraggingHue
		Parts.DraggingValSat = false
		Parts.DraggingHue = false
		if WasDragging and PopupBuilt then
			Content_HSV = {Parts.H, Parts.S, Parts.V}
			Content.Callback(Content.State)
		end
	end

	local function BuildPopup()
		if PopupBuilt then return end
		PopupBuilt = true
		local PageOverlay = Content.Page and Content.Page.Page
		if not PageOverlay then return end
		Popup_Holder = utility:RenderObject(Window, "Frame", {
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 1,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Parent = PageOverlay,
			Size = UDim2.new(0, 192, 0, 192),
			Active = true,
			Visible = false,
			ZIndex = 100
		})
		local Popup_Catcher = utility:RenderObject(Window, "TextButton", {
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 1,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Parent = PageOverlay,
			Position = UDim2.new(0, -20, 0, -20),
			Size = UDim2.new(1, 40, 1, 40),
			Text = "",
			Visible = false,
			ZIndex = 90
		})
		utility:CreateConnection(Window, Popup_Catcher.MouseButton1Click, function()
			if Content._PressInside then
				Content._PressInside = nil
				return
			end
			Content:Close()
		end)
		Content.Catcher = Popup_Catcher
		utility:CreateConnection(Window, UserInputService.InputBegan, function(Input)
			if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then return end
			if not Content:IsOpen() then return end
			Content._PressInside = nil
			local Point = Vector2.new(Input.Position.X, Input.Position.Y)
			local AP, AS = Popup_Holder.AbsolutePosition, Popup_Holder.AbsoluteSize
			if Point.X >= AP.X and Point.X <= AP.X + AS.X and Point.Y >= AP.Y and Point.Y <= AP.Y + AS.Y then
				Content._PressInside = true
				return
			end
			local OP, OS = Content_Holder_Outline.AbsolutePosition, Content_Holder_Outline.AbsoluteSize
			if Point.X >= OP.X and Point.X <= OP.X + OS.X and Point.Y >= OP.Y and Point.Y <= OP.Y + OS.Y then
				return
			end
			Content:Close()
		end)
		local Popup_Outline = utility:RenderObject(Window, "Frame", {
			BackgroundColor3 = Color3.fromRGB(12, 12, 12),
			BackgroundTransparency = 0,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Parent = Popup_Holder,
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 101
		})
		local Popup_Body = utility:RenderObject(Window, "Frame", {
			BackgroundColor3 = Color3.fromRGB(28, 28, 28),
			BackgroundTransparency = 0,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Parent = Popup_Outline,
			Position = UDim2.new(0, 1, 0, 1),
			Size = UDim2.new(1, -2, 1, -2),
			ZIndex = 102
		})
		local ValSat_Outer = utility:RenderObject(Window, "Frame", {
			BackgroundColor3 = Color3.fromRGB(12, 12, 12),
			BackgroundTransparency = 0,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Parent = Popup_Body,
			Position = UDim2.new(0, 5, 0, 5),
			Size = UDim2.new(0, 154, 0, 154),
			ZIndex = 103
		})
		local ValSat_Base = utility:RenderObject(Window, "Frame", {
			BackgroundColor3 = Color3.fromRGB(255, 0, 0),
			BackgroundTransparency = 0,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Parent = ValSat_Outer,
			Position = UDim2.new(0, 1, 0, 1),
			Size = UDim2.new(1, -2, 1, -2),
			ZIndex = 104
		})
		local ValSat_WhiteOverlay = utility:RenderObject(Window, "Frame", {
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Parent = ValSat_Base,
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 105
		})
		local WhiteGradient = utility:RenderObject(Window, "UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.new(1, 1, 1)),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1)
			}),
			Rotation = 0,
			Parent = ValSat_WhiteOverlay
		})
		local ValSat_BlackOverlay = utility:RenderObject(Window, "Frame", {
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Parent = ValSat_WhiteOverlay,
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 106
		})
		local BlackGradient = utility:RenderObject(Window, "UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(0, 0, 0), Color3.new(0, 0, 0)),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1, 0)
			}),
			Rotation = 90,
			Parent = ValSat_BlackOverlay
		})
		ValSatCursor = utility:RenderObject(Window, "Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Parent = ValSat_BlackOverlay,
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0, 3, 0, 3),
			ZIndex = 107
		})
		utility:RenderObject(Window, "UIStroke", {
			Color = Color3.fromRGB(255, 255, 255),
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = ValSatCursor
		})
		local Hue_Outer = utility:RenderObject(Window, "Frame", {
			BackgroundColor3 = Color3.fromRGB(12, 12, 12),
			BackgroundTransparency = 0,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Parent = Popup_Body,
			Position = UDim2.new(1, -27, 0, 5),
			Size = UDim2.new(0, 22, 0, 154),
			ZIndex = 103
		})
		local Hue_Bar = utility:RenderObject(Window, "Frame", {
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Parent = Hue_Outer,
			Position = UDim2.new(0, 1, 0, 1),
			Size = UDim2.new(1, -2, 1, -2),
			ZIndex = 104
		})
		utility:RenderObject(Window, "UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
				ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
				ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
				ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
				ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
				ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0))
			}),
			Rotation = 90,
			Parent = Hue_Bar
		})
		HueCursor = utility:RenderObject(Window, "Frame", {
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0,
			BorderColor3 = Color3.fromRGB(15, 15, 15),
			BorderSizePixel = 1,
			Parent = Hue_Bar,
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(1, 0, 0, 1),
			ZIndex = 105
		})
		local Hex_Outer = utility:RenderObject(Window, "Frame", {
			BackgroundColor3 = Color3.fromRGB(12, 12, 12),
			BackgroundTransparency = 0,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Parent = Popup_Body,
			Position = UDim2.new(0, 5, 1, -27),
			Size = UDim2.new(1, -10, 0, 22),
			ZIndex = 103
		})
		HexBox = utility:RenderObject(Window, "TextBox", {
			BackgroundColor3 = Color3.fromRGB(35, 35, 35),
			BackgroundTransparency = 0,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Parent = Hex_Outer,
			Position = UDim2.new(0, 1, 0, 1),
			Size = UDim2.new(1, -2, 1, -2),
			ZIndex = 104,
			Font = Enum.Font.Code,
			PlaceholderText = "#RRGGBB",
			PlaceholderColor3 = Color3.fromRGB(90, 90, 90),
			Text = "",
			TextColor3 = Color3.fromRGB(205, 205, 205),
			TextSize = math.round(11 * (Window.TextScale or 1)),
			TextXAlignment = Enum.TextXAlignment.Center,
			ClearTextOnFocus = false
		})

		Parts.ValSatBase = ValSat_Base
		Parts.SwatchInner = Holder_Swatch_Inner
		Parts.ValSatCursor = ValSatCursor
		Parts.HueCursor = HueCursor
		Parts.Content = Content

		local function HandleValSat(Input)
			local AbsPos = ValSat_Base.AbsolutePosition
			local AbsSize = ValSat_Base.AbsoluteSize
			if AbsSize.X <= 0 or AbsSize.Y <= 0 then return end
			local FX = math.clamp((Input.Position.X - AbsPos.X) / AbsSize.X, 0, 1)
			local FY = math.clamp((Input.Position.Y - AbsPos.Y) / AbsSize.Y, 0, 1)
			Parts.S = FX
			Parts.V = 1 - FY
			ApplyHSV()
			pcall(function()
				Content.Callback(Content.State)
			end)
		end

		local function HandleHue(Input)
			local AbsPos = Hue_Bar.AbsolutePosition
			local AbsSize = Hue_Bar.AbsoluteSize
			if AbsSize.Y <= 0 then return end
			local FY = math.clamp((Input.Position.Y - AbsPos.Y) / AbsSize.Y, 0, 1)
			Parts.H = FY
			ApplyHSV()
			pcall(function()
				Content.Callback(Content.State)
			end)
		end

		utility:CreateConnection(Window, ValSat_Base.InputBegan, function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				StartValSatDrag()
				HandleValSat(Input)
			end
		end)
		utility:CreateConnection(Window, Hue_Bar.InputBegan, function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				StartHueDrag()
				HandleHue(Input)
			end
		end)
		utility:CreateConnection(Window, Popup_Holder.InputChanged, function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
				if Parts.DraggingValSat then
					HandleValSat(Input)
				elseif Parts.DraggingHue then
					HandleHue(Input)
				end
			end
		end)
		utility:CreateConnection(Window, UserInputService.InputEnded, function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				StopDrags()
			end
		end)
		utility:CreateConnection(Window, HexBox.FocusLost, function(EnterPressed)
			if EnterPressed then
				local Parsed = ParseHex(HexBox.Text)
				if Parsed then
					Content:Set(Parsed)
				else
					ApplyHSV()
				end
			end
		end)
	end

	function Content:Set(state, silent)
		if typeof(state) ~= "Color3" then
			state = Color3.fromRGB(255, 255, 255)
		end
		local H, S, V = state:ToHSV()
		Content_HSV = {H, S, V}
		Holder_Swatch_Inner.BackgroundColor3 = state
		Content.State = state
		if PopupBuilt then
			Parts.H, Parts.S, Parts.V = H, S, V
			ApplyHSV()
		end
		if not silent then
			Content.Callback(Content:Get())
		end
	end

	function Content:Get()
		return Content.State
	end

	function Content:Reposition()
		local Overlay = Content.Page and Content.Page.Page
		if not Popup_Holder or not Overlay or (not Popup_Holder.Visible and not Content._ScrollHidden) then return end
		local OverlayAbs = Overlay.AbsolutePosition
		local OverlaySize = Overlay.AbsoluteSize
		local AnchorPos = Content_Holder_Outline.AbsolutePosition
		local AnchorSize = Content_Holder_Outline.AbsoluteSize
		local OverlayTop = OverlayAbs.Y
		local OverlayBottom = OverlayAbs.Y + OverlaySize.Y
		local AnchorTop = AnchorPos.Y
		local AnchorBottom = AnchorTop + AnchorSize.Y
		if AnchorBottom < OverlayTop or AnchorTop > OverlayBottom then
			if not Content._ScrollHidden then
				Content._ScrollHidden = true
				Popup_Holder.Visible = false
				if Content.Catcher then
					Content.Catcher.Visible = false
				end
			end
			return
		end
		if Content._ScrollHidden then
			Content._ScrollHidden = nil
			if Content.Catcher then
				Content.Catcher.Visible = true
			end
			Popup_Holder.Visible = true
		end
		local Width = Popup_Holder.AbsoluteSize.X
		local Height = Popup_Holder.AbsoluteSize.Y
		local DesiredY
		if AnchorBottom < OverlayTop + Height then
			DesiredY = OverlayTop
		elseif AnchorTop > OverlayBottom - Height then
			DesiredY = math.max(OverlayBottom - Height, OverlayTop)
		elseif AnchorBottom + 2 + Height <= OverlayBottom then
			DesiredY = AnchorBottom + 2
		elseif AnchorTop - Height - 2 >= OverlayTop then
			DesiredY = AnchorTop - Height - 2
		else
			DesiredY = math.clamp(AnchorTop, OverlayTop, math.max(OverlayTop, OverlayBottom - Height))
		end
		local DesiredX = AnchorPos.X - Width + AnchorSize.X
		DesiredX = math.clamp(DesiredX, OverlayAbs.X, math.max(OverlayAbs.X, OverlayAbs.X + OverlaySize.X - Width))
		Popup_Holder.Position = UDim2.new(0, DesiredX - OverlayAbs.X, 0, DesiredY - OverlayAbs.Y)
	end

	function Content:Open()
		if Window.OpenContent == Content then return end
		if not Popup_Holder then return end
		Window:CloseOpenPopup()
		Window.OpenContent = Content
		BuildPopup()
		Parts.H, Parts.S, Parts.V = Content_HSV[1], Content_HSV[2], Content_HSV[3]
		Parts.DraggingValSat = false
		Parts.DraggingHue = false
		Content._ScrollHidden = nil
		Popup_Holder.Visible = true
		Content:Reposition()
		if Content.Catcher then
			Content.Catcher.Visible = true
		end
		ApplyHSV()
	end

	function Content:Close()
		if not Popup_Holder or (not Popup_Holder.Visible and not Content._ScrollHidden) then return end
		Content._ScrollHidden = nil
		Popup_Holder.Visible = false
		if Content.Catcher then
			Content.Catcher.Visible = false
		end
		StopDrags()
		if Window.OpenContent == Content then
			Window.OpenContent = nil
		end
	end

	function Content:IsOpen()
		return Popup_Holder ~= nil and (Popup_Holder.Visible or Content._ScrollHidden == true)
	end

	function Content:GetPopupHolder()
		return Popup_Holder
	end

	utility:CreateConnection(Window, Content_Holder_Button.MouseButton1Click, function()
		if Window.OpenContent == Content then
			Content:Close()
		else
			Content:Open()
		end
	end)

	Content:Set(Content.State, true)
	self.Window.Elements[Content.Name] = {Element = Content, Type = "Colorpicker"}
	return Content
end

function sections:CreateButton(Properties)
	Properties = Properties or {}
	local Window = self.Window
	local Content = {
		Name = utility:Resolve(Properties, {"name", "Name", "text", "Text", "title", "Title"}, "New Button"),
		Callback = utility:Resolve(Properties, {"callback", "Callback", "callBack", "CallBack"}, function() end),
		Window = self.Window,
		Page = self.Page,
		Section = self
	}
	local Content_Holder = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content.Section.Holder,
		Size = UDim2.new(1, 0, 0, 24),
		ZIndex = 3
	})
	local Content_Holder_Outline = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(12, 12, 12),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Position = UDim2.new(0, 9, 0, 3),
		Size = UDim2.new(1, -18, 0, 17),
		ZIndex = 3
	})
	local Content_Holder_Button = utility:RenderObject(Window, "TextButton", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Size = UDim2.new(1, 0, 1, 0),
		Text = ""
	})
	local Holder_Outline_Frame = utility:RenderObject(Window, "TextLabel", {
		BackgroundColor3 = Color3.fromRGB(35, 35, 35),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder_Outline,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 3,
		Font = Enum.Font.Code,
		RichText = true,
		Text = "<b>" .. tostring(Content.Name) .. "</b>",
		TextColor3 = Color3.fromRGB(205, 205, 205),
		TextSize = math.round(11 * (Window.TextScale or 1)),
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center
	})
	local Outline_Frame_Gradient = utility:RenderObject(Window, "UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(140, 140, 140)),
		Enabled = true,
		Rotation = 90,
		Parent = Holder_Outline_Frame
	})
	utility:CreateConnection(Window, Content_Holder_Button.MouseButton1Click, function()
		Content.Callback(Content)
	end)
	utility:CreateConnection(Window, Content_Holder_Button.MouseEnter, function()
		if Window.OpenContent ~= nil then return end
		Outline_Frame_Gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(180, 180, 180))
	end)
	utility:CreateConnection(Window, Content_Holder_Button.MouseLeave, function()
		Outline_Frame_Gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(140, 140, 140))
	end)
	utility:CreateConnection(Window, Content_Holder_Button.MouseButton1Down, function()
		Outline_Frame_Gradient.Color = ColorSequence.new(Color3.fromRGB(120, 120, 120), Color3.fromRGB(80, 80, 80))
	end)
	utility:CreateConnection(Window, Content_Holder_Button.MouseButton1Up, function()
		Outline_Frame_Gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(180, 180, 180))
	end)

	function Content:SetText(Text)
		Holder_Outline_Frame.Text = "<b>" .. tostring(Text) .. "</b>"
	end

	function Content:SetTextScale(Scale)
		Holder_Outline_Frame.TextSize = math.round(11 * (Scale or 1))
	end

	function Content:Get()
		return Content.Name
	end

	function Content:Set(Name)
		Content.Name = tostring(Name)
		Content:SetText(Name)
	end

	return Content
end

function sections:CreateTextBox(Properties)
	Properties = Properties or {}
	local Window = self.Window
	local Content = {
		Name = utility:Resolve(Properties, {"name", "Name", "title", "Title"}, nil),
		State = utility:Resolve(Properties, {"state", "State", "def", "Def", "default", "Default"}, ""),
		Placeholder = utility:Resolve(Properties, {"placeholder", "Placeholder"}, ""),
		Callback = utility:Resolve(Properties, {"callback", "Callback", "onchange", "OnChange"}, function() end),
		Type = "TextBox",
		Window = self.Window,
		Page = self.Page,
		Section = self
	}
	local Content_Holder = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content.Section.Holder,
		Size = UDim2.new(1, 0, 0, (Content.Name and 40 or 27)),
		ZIndex = 3
	})
	local Content_Holder_Outline = utility:RenderObject(Window, "Frame", {
		BackgroundColor3 = Color3.fromRGB(12, 12, 12),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Position = UDim2.new(0, 40, 0, Content.Name and 18 or 5),
		Size = UDim2.new(1, -98, 0, 14),
		ZIndex = 3
	})
	if Content.Name then
		utility:AddTitle(Window, Content_Holder, UDim2.new(0, 41, 0, 4), UDim2.new(1, -41, 0, 10), Content.Name, Color3.fromRGB(205, 205, 205), 3)
	end
	local Holder_TextBox = utility:RenderObject(Window, "TextBox", {
		BackgroundColor3 = Color3.fromRGB(35, 35, 35),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = Content_Holder_Outline,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 3,
		Font = Enum.Font.Code,
		PlaceholderText = tostring(Content.Placeholder or ""),
		PlaceholderColor3 = Color3.fromRGB(90, 90, 90),
		Text = tostring(Content.State or ""),
		TextColor3 = Color3.fromRGB(205, 205, 205),
		TextSize = math.round(11 * (Window.TextScale or 1)),
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false
	})
	utility:RenderObject(Window, "UIPadding", {
		Parent = Holder_TextBox,
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4)
	})
	local MaxLength = utility:Resolve(Properties, {"maxlength", "MaxLength", "maxcharacters", "MaxCharacters"}, nil)
	if type(MaxLength) == "number" and MaxLength > 0 then
		utility:CreateConnection(Window, Holder_TextBox:GetPropertyChangedSignal("Text"), function()
			if #Holder_TextBox.Text > MaxLength then
				Holder_TextBox.Text = string.sub(Holder_TextBox.Text, 1, MaxLength)
			end
		end)
	end

	function Content:Set(state, silent)
		Content.State = tostring(state or "")
		Holder_TextBox.Text = Content.State
		if not silent then
			Content.Callback(Content:Get())
		end
	end

	function Content:Get()
		return Holder_TextBox.Text
	end

	utility:CreateConnection(Window, Holder_TextBox.FocusLost, function(EnterPressed)
		Content.State = Holder_TextBox.Text
		Content.Callback(Content:Get(), EnterPressed)
	end)

	if Content.Name then
		self.Window.Elements[Content.Name] = {Element = Content, Type = "TextBox"}
	end
	return Content
end

function sections:CreateLabel(Properties)
	Properties = Properties or {}
	local Window = self.Window
	local Content = {
		Name = utility:Resolve(Properties, {"name", "Name", "text", "Text", "title", "Title"}, "New Label"),
		Window = self.Window,
		Page = self.Page,
		Section = self
	}
	local Title = utility:AddLabel(
		Window,
		Content.Section.Holder,
		UDim2.new(0, 41, 0, 4),
		UDim2.new(1, -41, 0, 10),
		Content.Name,
		Color3.fromRGB(160, 160, 160)
	)
	function Content:Get()
		return Title.Text
	end

	function Content:Set(Text)
		Title.Text = tostring(Text)
	end

	function Content:SetTextScale(Scale)
		Title.TextSize = math.round(11 * (Scale or 1))
	end

	return Content
end

return library
