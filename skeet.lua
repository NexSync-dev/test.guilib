local library = {
	Renders = {},
	Connections = {},
	Folder = "Skeet",
	Configs = "Configs",
	CurrentWindow = nil
}
local utility = {}
local pages = {}
local sections = {}
library.__index = library
pages.__index = pages
sections.__index = sections
local tws = game:GetService("TweenService")
local uis = game:GetService("UserInputService")
local cre = game:GetService("CoreGui")

function utility:RenderObject(RenderType, RenderProperties, RenderHidden)
	local Render = Instance.new(RenderType)
	if RenderProperties and typeof(RenderProperties) == "table" then
		for Property, Value in pairs(RenderProperties) do
			if Property ~= "RenderTime" then
				Render[Property] = Value
			end
		end
	end
	library.Renders[#library.Renders + 1] = {Render, RenderProperties, RenderHidden, RenderProperties["RenderTime"] or nil, library.CurrentWindow}
	return Render
end

function utility:DestroyObject(RenderObj)
	for Index, Item in ipairs(library.Renders) do
		if Item[1] == RenderObj then
			table.remove(library.Renders, Index)
			break
		end
	end
	if RenderObj and typeof(RenderObj) == "Instance" then
		RenderObj:Destroy()
	end
end

function utility:CreateConnection(ConnectionType, ConnectionCallback)
	local Connection = ConnectionType:Connect(ConnectionCallback)
	library.Connections[#library.Connections + 1] = {Connection, library.CurrentWindow}
	return Connection
end

function utility:DisconnectConnection(Connection)
	for Index, Item in ipairs(library.Connections) do
		if Item[1] == Connection then
			table.remove(library.Connections, Index)
			break
		end
	end
	if Connection and Connection.Disconnect then
		Connection:Disconnect()
	end
end

function utility:MouseLocation()
	return uis:GetMouseLocation()
end

function utility:ReparentPopup(Popup, Parent)
	if typeof(Popup) ~= "Instance" or typeof(Parent) ~= "Instance" then return Popup end
	local absPos = Popup.AbsolutePosition
	Popup.Parent = Parent
	if Parent.AbsoluteSize.X > 0 then
		local parentPos = Parent.AbsolutePosition
		Popup.Position = UDim2.fromOffset(absPos.X - parentPos.X, absPos.Y - parentPos.Y)
	end
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

function utility:AddLabel(Parent, Position, Size, Text, TextColor, Transparency, ZIndex)
	local Label = utility:RenderObject("TextLabel", {
		AnchorPoint = Vector2.new(0, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Parent,
		Position = Position,
		Size = Size,
		ZIndex = ZIndex or 3,
		Font = "Code",
		RichText = true,
		Text = Text,
		TextColor3 = TextColor,
		TextSize = 9,
		TextStrokeTransparency = 1,
		TextTransparency = Transparency or 0,
		TextXAlignment = "Left"
	})
	return Label
end

function utility:AddTitle(Parent, Position, Size, Text, TextColor, ZIndex)
	local based = utility:AddLabel(Parent, Position, Size, Text, TextColor, 0, ZIndex)
	local ghost = utility:AddLabel(Parent, Position, Size, Text, TextColor, 0.5, ZIndex)
	return based, ghost
end

function utility:Serialise(Table)
	local Serialised = {}
	local Count = 0
	for _, Value in ipairs(Table) do
		Count = Count + 1
		Serialised[Count] = tostring(Value)
	end
	return table.concat(Serialised, ", ")
end

function utility:Sort(Table1, Table2)
	local Table3 = {}
	local Lookup = {}
	for _, Val in ipairs(Table1) do
		local ActualVal = typeof(Val) == "number" and Table2[Val] or Val
		if ActualVal then
			Lookup[ActualVal] = true
		end
	end
	for _, Val in ipairs(Table2) do
		if Lookup[Val] then
			Table3[#Table3 + 1] = Val
		end
	end
	return Table3
end

function utility:GetSettings(Folder, File)
	local path = Folder .. "/" .. File
	if not readfile then return {} end
	local ok, data = pcall(function()
		return game:GetService("HttpService"):JSONDecode(readfile(path))
	end)
	if ok and typeof(data) == "table" then return data end
	return {}
end

function utility:SaveSettings(Folder, File, data)
	if not writefile then return end
	pcall(function()
		writefile(Folder .. "/" .. File, game:GetService("HttpService"):JSONEncode(data))
	end)
end

function library:CreateWindow(Properties)
	Properties = Properties or {}
	local Window = {
		Pages = {},
		Accent = Color3.fromRGB(255, 120, 30),
		Theme = {
			Background = Color3.fromRGB(25, 25, 25),
			Accent = Color3.fromRGB(255, 120, 30),
			Text = Color3.fromRGB(205, 205, 205)
		},
		Enabled = true,
		Key = Enum.KeyCode.Insert,
		Elements = {},
		AccentElements = {},
		ThemeElements = {},
		OpenContent = nil,
		Blur = false,
		AutoSave = true,
		FirstPageSet = false,
		SettingsData = {}
	}
	library.CurrentWindow = Window
	
	local blurEffect = Instance.new("BlurEffect")
	blurEffect.Size = 0
	blurEffect.Parent = game:GetService("Lighting")
	local ScreenGui = utility:RenderObject("ScreenGui", {
		DisplayOrder = 9999,
		Enabled = true,
		IgnoreGuiInset = true,
		Parent = cre,
		ResetOnSpawn = false,
		ZIndexBehavior = "Global"
	})
	local ScreenGui_MainFrame = utility:RenderObject("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(12, 12, 12),
		BorderMode = "Inset",
		BorderSizePixel = 1,
		Parent = ScreenGui,
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 660, 0, 560)
	})
	local ScreenGui_MainFrame_InnerBorder = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(40, 40, 40),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = ScreenGui_MainFrame,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2)
	})
	local MainFrame_InnerBorder_InnerFrame = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(12, 12, 12),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(60, 60, 60),
		BorderMode = "Inset",
		BorderSizePixel = 1,
		Parent = ScreenGui_MainFrame,
		Position = UDim2.new(0, 3, 0, 3),
		Size = UDim2.new(1, -6, 1, -6)
	})
	local InnerBorder_InnerFrame_Tabs = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(12, 12, 12),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = MainFrame_InnerBorder_InnerFrame,
		Position = UDim2.new(0, 0, 0, 4),
		Size = UDim2.new(0, 74, 1, -4)
	})
	local InnerBorder_InnerFrame_Pages = utility:RenderObject("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = MainFrame_InnerBorder_InnerFrame,
		Position = UDim2.new(1, 0, 0, 4),
		Size = UDim2.new(1, -73, 1, -4)
	})
	local InnerBorder_InnerFrame_TopGradient = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(12, 12, 12),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = MainFrame_InnerBorder_InnerFrame,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 0, 4)
	})
	local InnerFrame_Tabs_List = utility:RenderObject("UIListLayout", {
		Padding = UDim.new(0, 4),
		Parent = InnerBorder_InnerFrame_Tabs,
		FillDirection = "Vertical",
		HorizontalAlignment = "Left",
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = "Top"
	})
	local InnerFrame_Tabs_Padding = utility:RenderObject("UIPadding", {
		Parent = InnerBorder_InnerFrame_Tabs,
		PaddingTop = UDim.new(0, 9)
	})
	local InnerFrame_Pages_InnerBorder = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(45, 45, 45),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = InnerBorder_InnerFrame_Pages,
		Position = UDim2.new(0, 1, 0, 0),
		Size = UDim2.new(1, -1, 1, 0)
	})
	local InnerFrame_TopGradient_Gradient = utility:RenderObject("ImageLabel", {
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
	local Pages_InnerBorder_InnerFrame = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(20, 20, 20),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = InnerFrame_Pages_InnerBorder,
		Position = UDim2.new(0, 1, 0, 0),
		Size = UDim2.new(1, -1, 1, 0)
	})
	local InnerBorder_InnerFrame_Folder = utility:RenderObject("Folder", {
		Parent = Pages_InnerBorder_InnerFrame
	})
	local InnerBorder_InnerFrame_Pattern = utility:RenderObject("ImageLabel", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Pages_InnerBorder_InnerFrame,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 1, 0),
		Image = "rbxassetid://8547666218",
		ImageColor3 = Color3.fromRGB(12, 12, 12),
		ScaleType = "Tile",
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
		if Window.Blur then
			tws:Create(blurEffect, TweenInfo.new(0.25, Enum.EasingStyle.Linear), {Size = state and (Window.BlurStrength or 24) or 0}):Play()
		else
			tws:Create(blurEffect, TweenInfo.new(0.25, Enum.EasingStyle.Linear), {Size = 0}):Play()
		end
		local snapshot = {}
		for i, render in ipairs(library.Renders) do
			if render[5] == self then
				snapshot[#snapshot + 1] = render
			end
		end
		if Window.External then
			for _, item in ipairs(Window.External) do
				snapshot[#snapshot + 1] = {item.Instance, item.Properties}
			end
		end
		for _, render in ipairs(snapshot) do
			if not render[3] and render[1] and typeof(render[1]) == "Instance" and render[1].Parent then
				pcall(function()
					if render[1].ClassName == "Frame" or render[1].ClassName == "ViewportFrame" then
						if (render[2]["BackgroundTransparency"] or 0) ~= 1 then
							tws:Create(render[1], TweenInfo.new(render[4] or 0.25, Enum.EasingStyle["Linear"], state and Enum.EasingDirection["Out"] or Enum.EasingDirection["In"]), {BackgroundTransparency = state and (render[2]["BackgroundTransparency"] or 0) or 1}):Play()
						end
					elseif render[1].ClassName == "ImageLabel" then
						if (render[2]["BackgroundTransparency"] or 0) ~= 1 then
							tws:Create(render[1], TweenInfo.new(render[4] or 0.25, Enum.EasingStyle["Linear"], state and Enum.EasingDirection["Out"] or Enum.EasingDirection["In"]), {BackgroundTransparency = state and (render[2]["BackgroundTransparency"] or 0) or 1}):Play()
						end
						if (render[2]["ImageTransparency"] or 0) ~= 1 then
							tws:Create(render[1], TweenInfo.new(render[4] or 0.25, Enum.EasingStyle["Linear"], state and Enum.EasingDirection["Out"] or Enum.EasingDirection["In"]), {ImageTransparency = state and (render[2]["ImageTransparency"] or 0) or 1}):Play()
						end
					elseif render[1].ClassName == "TextLabel" then
						if (render[2]["BackgroundTransparency"] or 0) ~= 1 then
							tws:Create(render[1], TweenInfo.new(render[4] or 0.25, Enum.EasingStyle["Linear"], state and Enum.EasingDirection["Out"] or Enum.EasingDirection["In"]), {BackgroundTransparency = state and (render[2]["BackgroundTransparency"] or 0) or 1}):Play()
						end
						if (render[2]["TextTransparency"] or 0) ~= 1 then
							tws:Create(render[1], TweenInfo.new(render[4] or 0.25, Enum.EasingStyle["Linear"], state and Enum.EasingDirection["Out"] or Enum.EasingDirection["In"]), {TextTransparency = state and (render[2]["TextTransparency"] or 0) or 1}):Play()
						end
					elseif render[1].ClassName == "ScrollingFrame" then
						if (render[2]["BackgroundTransparency"] or 0) ~= 1 then
							tws:Create(render[1], TweenInfo.new(render[4] or 0.25, Enum.EasingStyle["Linear"], state and Enum.EasingDirection["Out"] or Enum.EasingDirection["In"]), {BackgroundTransparency = state and (render[2]["BackgroundTransparency"] or 0) or 1}):Play()
						end
						if (render[2]["ScrollBarImageTransparency"] or 0) ~= 1 then
							tws:Create(render[1], TweenInfo.new(render[4] or 0.25, Enum.EasingStyle["Linear"], state and Enum.EasingDirection["Out"] or Enum.EasingDirection["In"]), {ScrollBarImageTransparency = state and (render[2]["ScrollBarImageTransparency"] or 0) or 1}):Play()
						end
					end
				end)
			end
		end
	end

	function Window:Unload()
		Window.RainbowAccent = false
		if Window.External then
			for _, item in ipairs(Window.External) do
				if item.Instance and typeof(item.Instance) == "Instance" then
					item.Instance:Destroy()
				end
			end
			Window.External = nil
		end
		if Window.ExternalConnections then
			for _, connection in ipairs(Window.ExternalConnections) do
				if connection and connection.Disconnect then
					connection:Disconnect()
				end
			end
			Window.ExternalConnections = nil
		end
		if blurEffect then blurEffect:Destroy() end
		local index = #library.Connections
		while index >= 1 do
			local item = library.Connections[index]
			if item[2] == self then
				if item[1] and item[1].Disconnect then
					item[1]:Disconnect()
				end
				table.remove(library.Connections, index)
			end
			index = index - 1
		end
		local index = #library.Renders
		while index >= 1 do
			local item = library.Renders[index]
			if item[5] == self then
				if item[1] and typeof(item[1]) == "Instance" then
					item[1]:Destroy()
				end
				table.remove(library.Renders, index)
			end
			index = index - 1
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

	function Window:SetAccent(newColor)
		self.Accent = newColor
		self.Theme.Accent = newColor
		for _, item in ipairs(self.AccentElements) do
			pcall(function()
				if item.Type == "Toggle" then
					item.Object.BackgroundColor3 = item.Element.State and newColor or Color3.fromRGB(77, 77, 77)
				elseif item.Type == "Slider" then
					item.Object.BackgroundColor3 = newColor
				elseif item.Type == "Page" then
					item.Object.BackgroundColor3 = newColor
					if item.Element.Open and item.IconObject then
						item.IconObject.ImageColor3 = newColor
					end
				elseif item.Type == "Section" then
					item.Object.BackgroundColor3 = newColor
				elseif item.Type == "Label" then
					item.Object.TextColor3 = newColor
				elseif item.Type == "Border" then
					item.Object.BackgroundColor3 = newColor
				end
			end)
		end
		if self.OpenContent and self.OpenContent.Refresh then
			pcall(function() self.OpenContent:Refresh() end)
		end
	end

	local function DeriveShades(baseColor)
		return {
			Light = baseColor:Lerp(Color3.new(1, 1, 1), 0.09),
			Base = baseColor,
			Dark = baseColor:Lerp(Color3.new(0, 0, 0), 0.55)
		}
	end

	function Window:SetTheme(Theme)
		Theme = Theme or {}
		self.Theme.Background = Theme.Background or self.Theme.Background
		self.Theme.Accent = Theme.Accent or self.Theme.Accent
		self.Theme.Text = Theme.Text or self.Theme.Text
		local oldText = self.Theme.Text
		local shades = DeriveShades(self.Theme.Background)
		for _, item in ipairs(self.ThemeElements) do
			if item.Type == "Background" then
				local shade = item.Shade or "Base"
				item.Object.BackgroundColor3 = shades[shade] or self.Theme.Background
			end
		end
		for _, render in ipairs(library.Renders) do
			local obj = render[1]
			if obj and typeof(obj) == "Instance" and obj.ClassName == "TextLabel" and obj.TextColor3 == oldText then
				obj.TextColor3 = self.Theme.Text
			end
		end
		self:SetAccent(self.Theme.Accent)
	end

	Window["TabsHolder"] = InnerBorder_InnerFrame_Tabs
	Window["PagesHolder"] = InnerBorder_InnerFrame_Folder
	local Dragging = false
	local DragStart = Vector3.new()
	local StartPosition = UDim2.new()

	utility:CreateConnection(ScreenGui_MainFrame.InputBegan, function(Input)
		if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
			Dragging = true
			DragStart = Input.Position
			StartPosition = ScreenGui_MainFrame.Position
		end
	end)

	utility:CreateConnection(uis.InputChanged, function(Input)
		if Dragging and (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch) then
			local Delta = Input.Position - DragStart
			ScreenGui_MainFrame.Position = UDim2.new(
				StartPosition.X.Scale,
				StartPosition.X.Offset + Delta.X,
				StartPosition.Y.Scale,
				StartPosition.Y.Offset + Delta.Y
			)
		end
	end)

	utility:CreateConnection(uis.InputEnded, function(Input)
		if Dragging and (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
			Dragging = false
			if not Window.AutoSave then return end
			Window.SettingsData.position = {
				XScale = ScreenGui_MainFrame.Position.X.Scale,
				XOffset = ScreenGui_MainFrame.Position.X.Offset,
				YScale = ScreenGui_MainFrame.Position.Y.Scale,
				YOffset = ScreenGui_MainFrame.Position.Y.Offset
			}
			utility:SaveSettings(library.Folder, "isettings.json", Window.SettingsData)
		end
	end)

	utility:CreateConnection(uis.InputBegan, function(Input)
		if Input.KeyCode and Input.KeyCode == Window.Key then
			if uis:GetFocusedTextBox() then return end
			Window.Enabled = not Window.Enabled
			ScreenGui_MainFrame.Visible = Window.Enabled
			if not Window.Enabled then
				game:GetService("GuiService").SelectedObject = nil
				pcall(function() uis:GetFocusedTextBox():ReleaseFocus() end)
			end
			Window:Fade(Window.Enabled)
		end
	end)

	local WindowObj = setmetatable(Window, library)
	WindowObj.CreateTab = WindowObj.CreatePage

	table.insert(Window.ThemeElements, {Type = "Background", Object = ScreenGui_MainFrame, Shade = "Base"})
	table.insert(Window.ThemeElements, {Type = "Background", Object = ScreenGui_MainFrame_InnerBorder, Shade = "Light"})
	table.insert(Window.ThemeElements, {Type = "Background", Object = MainFrame_InnerBorder_InnerFrame, Shade = "Dark"})
	table.insert(Window.ThemeElements, {Type = "Background", Object = InnerBorder_InnerFrame_Tabs, Shade = "Dark"})
	table.insert(Window.ThemeElements, {Type = "Background", Object = InnerBorder_InnerFrame_TopGradient, Shade = "Dark"})
	table.insert(Window.ThemeElements, {Type = "Background", Object = InnerFrame_Pages_InnerBorder, Shade = "Light"})
	table.insert(Window.ThemeElements, {Type = "Background", Object = Pages_InnerBorder_InnerFrame, Shade = "Base"})

	Window.SettingsData = utility:GetSettings(library.Folder, "isettings.json")
	if Window.SettingsData.saveUIState == false then
		Window.AutoSave = false
	end
	local savedPos = Window.AutoSave and Window.SettingsData.position
	if savedPos then
		pcall(function()
			ScreenGui_MainFrame.Position = UDim2.new(savedPos.XScale or 0.5, savedPos.XOffset or 0, savedPos.YScale or 0.5, savedPos.YOffset or 0)
		end)
	end

	local settings_page = WindowObj:CreatePage({Icon = "rbxassetid://8547256547", LayoutOrder = 9999, IsSettings = true})
	local configSection = settings_page:CreateSection({Name = "Configuration", Size = 280, Side = "Left"})
	
	configSection:CreateKeybind({
		Name = "Toggle Keybind",
		State = {"KeyCode", "Insert"},
		Callback = function(val)
			if type(val) == "table" and val[1] == "KeyCode" then
				WindowObj.Key = Enum.KeyCode[val[2]]
			end
		end
	})

	configSection:CreateToggle({
		Name = "UI Blur",
		State = false,
		Callback = function(state)
			WindowObj.Blur = state
			if WindowObj.Enabled then
				blurEffect.Size = state and 24 or 0
			else
				blurEffect.Size = 0
			end
		end
	})

	configSection:CreateToggle({
		Name = "Save UI State",
		State = Window.AutoSave,
		Callback = function(state)
			Window.AutoSave = state
			Window.SettingsData.saveUIState = state
			utility:SaveSettings(library.Folder, "isettings.json", Window.SettingsData)
		end
	})

	local ConfigFolderName = library.Folder .. "/" .. library.Configs .. "/" .. tostring(game.GameId)
	pcall(function()
		if makefolder then
			makefolder(library.Folder)
			makefolder(library.Folder .. "/" .. library.Configs)
			makefolder(ConfigFolderName)
		end
	end)
	
	local function GetConfigs()
		local configs = {}
		if listfiles then
			pcall(function()
				for _, file in ipairs(listfiles(ConfigFolderName)) do
					if file:match("%.json$") then
						table.insert(configs, file:match("([^/\\]+)%.json$"))
					end
				end
			end)
		end
		if #configs == 0 then table.insert(configs, "default") end
		return configs
	end

	local configDropdown = configSection:CreateDropdown({
		Name = "Selected Config",
		Options = GetConfigs(),
		State = 1,
		Callback = function(index)
			if configDropdown and Window.SettingsData then
				Window.SettingsData.config = configDropdown.Options[index]
				utility:SaveSettings(library.Folder, "isettings.json", Window.SettingsData)
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
		State = "default"
	})

	configSection:CreateButton({
		Name = "Refresh Configs",
		Callback = function()
			configDropdown:RefreshOptions(GetConfigs())
		end
	})

	configSection:CreateButton({
		Name = "Save Configuration",
		Callback = function()
			local configName = configNameBox:Get()
			if configName == "" then configName = "default" end
			
			local data = {}
			for key, info in pairs(WindowObj.Elements) do
				local val = info.Element:Get()
				if info.Type == "Colorpicker" then
					data[key] = {val.R, val.G, val.B}
				elseif info.Type == "Keybind" then
					data[key] = {val[1], val[2]}
				else
					data[key] = val
				end
			end
			pcall(function()
				if writefile then
					writefile(ConfigFolderName .. "/" .. configName .. ".json", game:GetService("HttpService"):JSONEncode(data))
				end
			end)
			configDropdown:RefreshOptions(GetConfigs())
		end
	})

	configSection:CreateButton({
		Name = "Load Configuration",
		Callback = function()
			local selectedIndex = configDropdown:Get()
			local configName = configDropdown.Options[selectedIndex]
			if not configName then return end
			
			local success, content = pcall(function()
				if readfile then
					return readfile(ConfigFolderName .. "/" .. configName .. ".json")
				end
			end)
			if success and content then
				local success2, data = pcall(function()
					return game:GetService("HttpService"):JSONDecode(content)
				end)
				if success2 and typeof(data) == "table" then
					for key, val in pairs(data) do
						local info = WindowObj.Elements[key]
						if info then
							if info.Type == "Colorpicker" then
								info.Element:Set(Color3.new(val[1], val[2], val[3]))
							else
								info.Element:Set(val)
							end
						end
					end
				end
			end
		end
	})

	configSection:CreateButton({
		Name = "Unload GUI",
		Callback = function()
			WindowObj:Unload()
		end
	})

	local themeSection = settings_page:CreateSection({Name = "Theme", Size = 330, Side = "Left"})
	themeSection:CreateColorpicker({
		Name = "Accent Color",
		State = WindowObj.Accent,
		Callback = function(color)
			WindowObj:SetAccent(color)
		end
	})
	themeSection:CreateColorpicker({
		Name = "Background Color",
		State = WindowObj.Theme.Background,
		Callback = function(color)
			WindowObj:SetTheme({Background = color})
		end
	})
	themeSection:CreateColorpicker({
		Name = "Text Color",
		State = WindowObj.Theme.Text,
		Callback = function(color)
			WindowObj:SetTheme({Text = color})
		end
	})
	themeSection:CreateSlider({
		Name = "GUI Outline",
		Min = 0,
		Max = 100,
		State = 100,
		Callback = function(value)
			local transparency = 1 - (value / 100)
			pcall(function()
				ScreenGui_MainFrame.BackgroundTransparency = transparency
			end)
		end
	})
	themeSection:CreateSlider({
		Name = "Rainbow Speed",
		Min = 0.01,
		Max = 0.5,
		Step = 0.01,
		State = 0.05,
		Callback = function(value)
			WindowObj.RainbowSpeed = value
		end
	})
	themeSection:CreateToggle({
		Name = "Rainbow Accent",
		State = false,
		Callback = function(state)
			WindowObj.RainbowAccent = state
			if state then
				task.spawn(function()
					local hue = 0
					while WindowObj.RainbowAccent do
						hue = (hue + 1) % 360
						WindowObj:SetAccent(Color3.fromHSV(hue / 360, 1, 1))
						task.wait(WindowObj.RainbowSpeed or 0.05)
					end
				end)
			end
		end
	})
	themeSection:CreateSlider({
		Name = "Blur Strength",
		Min = 0,
		Max = 50,
		State = 24,
		Callback = function(value)
			WindowObj.BlurStrength = value
		end
	})

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
		State = ""
	})

	serverSection:CreateButton({
		Name = "Join via Job ID",
		Callback = function()
			local target = jobIdBox:Get()
			if target and target ~= "" then
				game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, target, game:GetService("Players").LocalPlayer)
			end
		end
	})

	local function HopServer(sortMode)
		local HttpService = game:GetService("HttpService")
		local TeleportService = game:GetService("TeleportService")
		local Players = game:GetService("Players")
		local PlaceId = game.PlaceId
		local JobId = game.JobId
		local success, servers = pcall(function()
			return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
		end)
		if success and servers and servers.data then
			local candidateServers = {}
			for _, server in ipairs(servers.data) do
				if server.id ~= JobId and server.playing < server.maxPlayers and server.playing > 0 then
					table.insert(candidateServers, server)
				end
			end
			if #candidateServers > 0 then
				if sortMode == "Highest" then
					table.sort(candidateServers, function(a, b) return a.playing > b.playing end)
				elseif sortMode == "Lowest" then
					table.sort(candidateServers, function(a, b) return a.playing < b.playing end)
				else
					local index = math.random(1, #candidateServers)
					TeleportService:TeleportToPlaceInstance(PlaceId, candidateServers[index].id, Players.LocalPlayer)
					return
				end
				TeleportService:TeleportToPlaceInstance(PlaceId, candidateServers[1].id, Players.LocalPlayer)
			end
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

	return WindowObj
end

function library:CreatePage(Properties)
	Properties = Properties or {}
	library.CurrentWindow = self
	local Page = {
		Image = utility:Resolve(Properties, {"image", "Image", "icon", "Icon"}, nil),
		Size = utility:Resolve(Properties, {"size", "Size"}, UDim2.new(0, 50, 0, 50)),
		Open = false,
		Window = self,
		Sections = {},
		IsSettings = (Properties.IsSettings or false)
	}
	local Page_Tab = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		LayoutOrder = Properties.LayoutOrder or #Page.Window.Pages + 1,
		Parent = Page.Window["TabsHolder"],
		Size = UDim2.new(1, 0, 0, 72)
	})
	local Page_Tab_Border = utility:RenderObject("Frame", {
		BackgroundColor3 = Page.Window.Accent,
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Page_Tab,
		Size = UDim2.new(1, 0, 1, 0),
		Visible = false,
		ZIndex = 2,
		RenderTime = 0.15
	})
	local Page_Tab_Image = utility:RenderObject("ImageLabel", {
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
		ImageColor3 = Color3.fromRGB(100, 100, 100)
	})
	local Page_Tab_Button = utility:RenderObject("TextButton", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Page_Tab,
		Size = UDim2.new(1, 0, 1, 0),
		Text = ""
	})
	local Tab_Border_Inner = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(40, 40, 40),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Page_Tab_Border,
		Position = UDim2.new(0, 0, 0, 1),
		Size = UDim2.new(1, 1, 1, -2),
		ZIndex = 2,
		RenderTime = 0.15
	})
	local Border_Inner_Inner = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(20, 20, 20),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Tab_Border_Inner,
		Position = UDim2.new(0, 0, 0, 1),
		Size = UDim2.new(1, 0, 1, -2),
		ZIndex = 2,
		RenderTime = 0.15
	})
	local Inner_Inner_Pattern = utility:RenderObject("ImageLabel", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Border_Inner_Inner,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 1, 0),
		Image = "rbxassetid://8509210785",
		ImageColor3 = Color3.fromRGB(12, 12, 12),
		ScaleType = "Tile",
		TileSize = UDim2.new(0, 8, 0, 8),
		ZIndex = 2
	})
	local Page_Page = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Page.Window["PagesHolder"],
		Position = UDim2.new(0, 20, 0, 20),
		Size = UDim2.new(1, -40, 1, -40),
		Visible = false
	})
	local Page_Page_Left = utility:RenderObject("ScrollingFrame", {
		AutomaticCanvasSize = "Y",
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Parent = Page_Page,
		Position = UDim2.new(0, 0, 0, 0),
		ScrollBarThickness = 0,
		ScrollingDirection = "Y",
		Size = UDim2.new(0.5, -10, 1, 0)
	})
	local Page_Page_Right = utility:RenderObject("ScrollingFrame", {
		AutomaticCanvasSize = "Y",
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Parent = Page_Page,
		Position = UDim2.new(0.5, 10, 0, 0),
		ScrollBarThickness = 0,
		ScrollingDirection = "Y",
		Size = UDim2.new(0.5, -10, 1, 0)
	})
	local Page_Left_List = utility:RenderObject("UIListLayout", {
		Padding = UDim.new(0, 18),
		Parent = Page_Page_Left,
		FillDirection = "Vertical",
		HorizontalAlignment = "Left",
		VerticalAlignment = "Top"
	})
	local Page_Right_List = utility:RenderObject("UIListLayout", {
		Padding = UDim.new(0, 18),
		Parent = Page_Page_Right,
		FillDirection = "Vertical",
		HorizontalAlignment = "Left",
		VerticalAlignment = "Top"
	})
	Page["Page"] = Page_Page
	Page["Left"] = Page_Page_Left
	Page["Right"] = Page_Page_Right

	function Page:Set(state)
		Page.Open = state
		Page_Tab_Border.Visible = Page.Open
		Page_Page.Visible = Page.Open
		tws:Create(Page_Tab_Image, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {ImageColor3 = Page.Open and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(90, 90, 90)}):Play()
		if not Page.Open then
			for _, section in ipairs(Page.Sections) do
				if section and section.Content and section.Content.Open then
					section:CloseContent()
				end
			end
		end
		if Page.Open then
			if Page.UserIndex and Page.Window.SettingsData and Page.Window.AutoSave then
				Page.Window.SettingsData.lastTab = Page.UserIndex
				utility:SaveSettings(library.Folder, "isettings.json", Page.Window.SettingsData)
			end
			Page.Window:SetPage(Page)
		end
	end

	utility:CreateConnection(Page_Tab_Button.MouseButton1Click, function()
		if not Page.Open then
			Page:Set(true)
		end
	end)

	utility:CreateConnection(Page_Tab_Button.MouseEnter, function()
		Page_Tab_Image.ImageColor3 = Color3.fromRGB(172, 172, 172)
	end)

	utility:CreateConnection(Page_Tab_Button.MouseLeave, function()
		Page_Tab_Image.ImageColor3 = Page.Open and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(90, 90, 90)
	end)

	if not Properties.IsSettings then
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
		Object = Page_Tab_Border,
		IconObject = Page_Tab_Image
	})
	Page.Window.Pages[#Page.Window.Pages + 1] = Page
	return setmetatable(Page, pages)
end

function pages:CreateSection(Properties)
	Properties = Properties or {}
	library.CurrentWindow = self.Window
	local Section = {
		Name = utility:Resolve(Properties, {"name", "Name", "title", "Title"}, "New Section"),
		Size = utility:Resolve(Properties, {"size", "Size"}, 150),
		Side = utility:Resolve(Properties, {"side", "Side"}, "Left"),
		Content = {},
		Window = self.Window,
		Page = self
	}
	table.insert(self.Sections, Section)

	local Section_Holder = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(40, 40, 40),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(12, 12, 12),
		BorderMode = "Inset",
		BorderSizePixel = 1,
		Parent = Section.Page[Section.Side],
		Size = UDim2.new(1, 0, 0, Section.Size),
		ZIndex = 2
	})
	local Section_Holder_Extra = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Section_Holder,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 2
	})
	local Section_Holder_Frame = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(23, 23, 23),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Section_Holder,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 2
	})
	local Section_Holder_TitleInline = utility:RenderObject("Frame", {
		BackgroundColor3 = Section.Window.Accent,
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Section_Holder,
		Position = UDim2.new(0, 9, 0, -1),
		Size = UDim2.new(0, 0, 0, 2),
		ZIndex = 5
	})
	local Section_Holder_Title = utility:RenderObject("TextLabel", {
		AnchorPoint = Vector2.new(0, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Section_Holder,
		Position = UDim2.new(0, 12, 0, 4),
		Size = UDim2.new(1, -26, 0, 13),
		ZIndex = 5,
		Font = "Code",
		RichText = true,
		Text = "<b>" .. Section.Name .. "</b>",
		TextColor3 = Color3.fromRGB(205, 205, 205),
		TextSize = 11,
		TextStrokeTransparency = 1,
		TextXAlignment = "Left"
	})
	local Section_Chevron = utility:RenderObject("TextButton", {
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
	local Chevron_Image = utility:RenderObject("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Section_Chevron,
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 7, 0, 6),
		Image = "rbxassetid://8532000591",
		ImageColor3 = Color3.fromRGB(130, 130, 130),
		ZIndex = 5
	})
	local Holder_Extra_Gradient1 = utility:RenderObject("ImageLabel", {
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
	local Holder_Extra_Gradient2 = utility:RenderObject("ImageLabel", {
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
	local Holder_Extra_Bar = utility:RenderObject("Frame", {
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
	local Holder_Extra_Line = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(45, 45, 45),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Section_Holder_Extra,
		Position = UDim2.new(0, 0, 0, -1),
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 4
	})
	local Holder_Frame_ContentHolder = utility:RenderObject("ScrollingFrame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Section_Holder_Frame,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 4,
		AutomaticCanvasSize = "Y",
		BottomImage = "rbxassetid://7783554086",
		CanvasSize = UDim2.new(0, 0, 0, 0),
		MidImage = "rbxassetid://7783554086",
		ScrollBarImageColor3 = Color3.fromRGB(65, 65, 65),
		ScrollBarImageTransparency = 0,
		ScrollBarThickness = 5,
		TopImage = "rbxassetid://7783554086",
		VerticalScrollBarInset = "None"
	})
	local Frame_ContentHolder_List = utility:RenderObject("UIListLayout", {
		Padding = UDim.new(0, 0),
		Parent = Holder_Frame_ContentHolder,
		FillDirection = "Vertical",
		HorizontalAlignment = "Center",
		VerticalAlignment = "Top"
	})
	local Frame_ContentHolder_Padding = utility:RenderObject("UIPadding", {
		Parent = Holder_Frame_ContentHolder,
		PaddingTop = UDim.new(0, 15),
		PaddingBottom = UDim.new(0, 15)
	})
	Section_Holder_TitleInline.Size = UDim2.new(0, Section_Holder_Title.TextBounds.X + 6, 0, 2)
	table.insert(Section.Window.AccentElements, {
		Type = "Section",
		Element = Section,
		Object = Section_Holder_TitleInline
	})
	table.insert(Section.Window.AccentElements, {
		Type = "Label",
		Element = Section,
		Object = Section_Holder_Title
	})
	table.insert(Section.Window.ThemeElements, {Type = "Background", Object = Section_Holder, Shade = "Light"})
	table.insert(Section.Window.ThemeElements, {Type = "Background", Object = Section_Holder_Frame, Shade = "Base"})
	Section["Holder"] = Holder_Frame_ContentHolder
	Section["Extra"] = Section_Holder_Extra

	Section.Collapsed = false
	Section.OriginalSize = UDim2.new(1, 0, 0, Section.Size)

	local function ApplyCollapsed(state)
		Section.Collapsed = state
		Chevron_Image.Rotation = state and 180 or 0
		Holder_Frame_ContentHolder.Visible = not state
		Section_Holder_Extra.Visible = not state
		Section_Holder_Frame.Visible = not state
		Section_Holder.Size = state and UDim2.new(1, 0, 0, 24) or Section.OriginalSize
		Section_Holder.ClipsDescendants = state
	end

	local savedCollapsed = Section.Window.AutoSave and Section.Window.SettingsData and Section.Window.SettingsData.sections and Section.Window.SettingsData.sections[Section.Name]
	if savedCollapsed then
		ApplyCollapsed(true)
	end

	utility:CreateConnection(Section_Chevron.MouseButton1Click, function()
		if not Section.Collapsed then
			Section:CloseContent()
		end
		ApplyCollapsed(not Section.Collapsed)
		if Section.Window.SettingsData and Section.Window.AutoSave then
			Section.Window.SettingsData.sections = Section.Window.SettingsData.sections or {}
			Section.Window.SettingsData.sections[Section.Name] = Section.Collapsed
			utility:SaveSettings(library.Folder, "isettings.json", Section.Window.SettingsData)
		end
	end)

	function Section:CloseContent()
		if Section.Content.Open then
			Section.Content:Close()
			Section.Content = {}
		end
	end

	utility:CreateConnection(Holder_Frame_ContentHolder:GetPropertyChangedSignal("AbsoluteCanvasSize"), function()
		local canvasY = Holder_Frame_ContentHolder.AbsoluteCanvasSize.Y > Holder_Frame_ContentHolder.AbsoluteWindowSize.Y
		Holder_Extra_Gradient1.Visible = canvasY
		Holder_Extra_Gradient2.Visible = canvasY
		Holder_Extra_Bar.Visible = canvasY
	end)

	utility:CreateConnection(Holder_Frame_ContentHolder:GetPropertyChangedSignal("CanvasPosition"), function()
		if Section.Content.Open then
			Section.Content:Close()
			Section.Content = {}
		end
	end)

	return setmetatable(Section, sections)
end

function sections:CreateToggle(Properties)
	Properties = Properties or {}
	library.CurrentWindow = self.Window
	local Content = {
		Name = utility:Resolve(Properties, {"name", "Name", "title", "Title"}, "New Toggle"),
		State = utility:Resolve(Properties, {"state", "State", "def", "Def", "default", "Default"}, false),
		Callback = utility:Resolve(Properties, {"callback", "Callback", "callBack", "CallBack"}, function() end),
		Window = self.Window,
		Page = self.Page,
		Section = self
	}
	local Content_Holder = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content.Section.Holder,
		Size = UDim2.new(1, 0, 0, 18),
		ZIndex = 3
	})
	local Content_Holder_Outline = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(12, 12, 12),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Position = UDim2.new(0, 20, 0, 5),
		Size = UDim2.new(0, 8, 0, 8),
		ZIndex = 3
	})
	utility:AddTitle(Content_Holder, UDim2.new(0, 41, 0, 0), UDim2.new(1, -41, 1, 0), Content.Name, Color3.fromRGB(205, 205, 205), 3)
	local Content_Holder_Button = utility:RenderObject("TextButton", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Size = UDim2.new(1, 0, 1, 0),
		Text = ""
	})
	local Holder_Outline_Frame = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(77, 77, 77),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder_Outline,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 3
	})
	local Outline_Frame_Gradient = utility:RenderObject("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(140, 140, 140)),
		Enabled = true,
		Rotation = 90,
		Parent = Holder_Outline_Frame
	})

	function Content:Set(state)
		Content.State = state
		Holder_Outline_Frame.BackgroundColor3 = Content.State and Content.Window.Accent or Color3.fromRGB(77, 77, 77)
		Content.Callback(Content:Get())
	end

	function Content:Get()
		return Content.State
	end

	utility:CreateConnection(Content_Holder_Button.MouseButton1Click, function()
		Content:Set(not Content:Get())
	end)

	utility:CreateConnection(Content_Holder_Button.MouseEnter, function()
		Outline_Frame_Gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(180, 180, 180))
	end)

	utility:CreateConnection(Content_Holder_Button.MouseLeave, function()
		Outline_Frame_Gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(140, 140, 140))
	end)

	Content:Set(Content.State)
	if Content.Name then
		self.Window.Elements[Content.Name] = {Element = Content, Type = "Toggle"}
	end
	table.insert(self.Window.AccentElements, {
		Type = "Toggle",
		Element = Content,
		Object = Holder_Outline_Frame
	})
	return Content
end

function sections:CreateSlider(Properties)
	Properties = Properties or {}
	library.CurrentWindow = self.Window
	local Content = {
		Name = utility:Resolve(Properties, {"name", "Name", "title", "Title"}, nil),
		State = utility:Resolve(Properties, {"state", "State", "def", "Def", "default", "Default"}, false),
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
	if not (type(Content.Step) == "number") or Content.Step <= 0 then
		Content.Step = 1
	end
	if not Content.State then
		Content.State = Content.Min
	end
	local Content_Holder = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content.Section.Holder,
		Size = UDim2.new(1, 0, 0, (Content.Name and 24 or 13) + 5),
		ZIndex = 3
	})
	local Content_Holder_Outline = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(12, 12, 12),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Position = UDim2.new(0, 40, 0, Content.Name and 18 or 5),
		Size = UDim2.new(1, -99, 0, 7),
		ZIndex = 3
	})
	if Content.Name then
		utility:AddTitle(Content_Holder, UDim2.new(0, 41, 0, 4), UDim2.new(1, -41, 0, 10), Content.Name, Color3.fromRGB(205, 205, 205), 3)
	end
	local Content_Holder_Button = utility:RenderObject("TextButton", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Size = UDim2.new(1, 0, 1, 0),
		Text = ""
	})
	local Holder_Outline_Frame = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(71, 71, 71),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder_Outline,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 3
	})
	local Outline_Frame_Slider = utility:RenderObject("Frame", {
		BackgroundColor3 = Content.Window.Accent,
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Holder_Outline_Frame,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(0, 0, 1, 0),
		ZIndex = 3
	})
	local Outline_Frame_Gradient = utility:RenderObject("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(175, 175, 175)),
		Enabled = true,
		Rotation = 270,
		Parent = Holder_Outline_Frame
	})
	local Frame_Slider_Gradient = utility:RenderObject("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(175, 175, 175)),
		Enabled = true,
		Rotation = 90,
		Parent = Outline_Frame_Slider
	})
	local Frame_Slider_Title = utility:RenderObject("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Outline_Frame_Slider,
		Position = UDim2.new(1, 0, 0.5, 1),
		Size = UDim2.new(0, 2, 1, 0),
		ZIndex = 3,
		Font = "Code",
		RichText = true,
		Text = "",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 11,
		TextStrokeTransparency = 0.5,
		TextXAlignment = "Center",
		RenderTime = 0.15
	})
	local Frame_Slider_Title2 = utility:RenderObject("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Outline_Frame_Slider,
		Position = UDim2.new(1, 0, 0.5, 1),
		Size = UDim2.new(0, 2, 1, 0),
		ZIndex = 3,
		Font = "Code",
		RichText = true,
		Text = "",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 11,
		TextStrokeTransparency = 0.5,
		TextTransparency = 0,
		TextXAlignment = "Center",
		RenderTime = 0.15
	})

	function Content:Set(state)
		Content.State = math.clamp(math.round(state / Content.Step) * Content.Step, Content.Min, Content.Max)
		local range = Content.Max - Content.Min
		local fraction
		if range > 0 then
			fraction = 1 - ((Content.Max - Content.State) / range)
		else
			fraction = 1
		end
		Frame_Slider_Title.Text = "<b>" .. Content.State .. Content.Ending .. "</b>"
		Frame_Slider_Title2.Text = "<b>" .. Content.State .. Content.Ending .. "</b>"
		Outline_Frame_Slider.Size = UDim2.new(math.clamp(fraction, 0, 1), 0, 1, 0)
		Content.Callback(Content:Get())
	end

	function Content:Refresh()
		local Mouse = utility:MouseLocation()
		local containerPos = Content_Holder.AbsolutePosition
		local trackPos = Holder_Outline_Frame.AbsolutePosition
		local trackSize = Holder_Outline_Frame.AbsoluteSize
		local deltaX = Mouse.X - containerPos.X
		local minX = trackPos.X - containerPos.X
		local pct = 0
		if trackSize.X > 0 then
			pct = math.clamp((deltaX - minX) / trackSize.X, 0, 1)
		end
		Content:Set(Content.Min + (Content.Max - Content.Min) * pct)
	end

	function Content:Get()
		return Content.State
	end

	utility:CreateConnection(Content_Holder_Button.MouseButton1Down, function()
		Content:Refresh()
		Content.Holding = true
		Outline_Frame_Gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(215, 215, 215))
		Frame_Slider_Gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(215, 215, 215))
	end)

	utility:CreateConnection(Content_Holder_Button.MouseEnter, function()
		Outline_Frame_Gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(215, 215, 215))
		Frame_Slider_Gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(215, 215, 215))
	end)

	utility:CreateConnection(Content_Holder_Button.MouseLeave, function()
		Outline_Frame_Gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Content.Holding and Color3.fromRGB(215, 215, 215) or Color3.fromRGB(175, 175, 175))
		Frame_Slider_Gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Content.Holding and Color3.fromRGB(215, 215, 215) or Color3.fromRGB(175, 175, 175))
	end)

	utility:CreateConnection(uis.InputChanged, function()
		if Content.Holding then
			Content:Refresh()
		end
	end)

	utility:CreateConnection(uis.InputEnded, function(Input)
		if Content.Holding and Input.UserInputType == Enum.UserInputType.MouseButton1 then
			Content.Holding = false
			Outline_Frame_Gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(175, 175, 175))
			Frame_Slider_Gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(175, 175, 175))
		end
	end)

	Content:Set(Content.State)
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

function sections:CreateDropdown(Properties)
	Properties = Properties or {}
	library.CurrentWindow = self.Window
	local Content = {
		Name = utility:Resolve(Properties, {"name", "Name", "title", "Title"}, "New Dropdown"),
		State = utility:Resolve(Properties, {"state", "State", "def", "Def", "default", "Default"}, 1),
		Options = utility:Resolve(Properties, {"options", "Options", "list", "List"}, {1, 2, 3}),
		Callback = utility:Resolve(Properties, {"callback", "Callback", "callBack", "CallBack"}, function() end),
		Content = {
			Open = false
		},
		Window = self.Window,
		Page = self.Page,
		Section = self
	}
	local Content_Holder = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content.Section.Holder,
		Size = UDim2.new(1, 0, 0, 39),
		ZIndex = 3
	})
	local Content_Holder_Outline = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(12, 12, 12),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Position = UDim2.new(0, 40, 0, 15),
		Size = UDim2.new(1, -98, 0, 20),
		ZIndex = 3
	})
	utility:AddTitle(Content_Holder, UDim2.new(0, 41, 0, 4), UDim2.new(1, -41, 0, 10), Content.Name, Color3.fromRGB(205, 205, 205), 3)
	local Content_Holder_Button = utility:RenderObject("TextButton", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Size = UDim2.new(1, 0, 1, 0),
		Text = ""
	})
	local Holder_Outline_Frame = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(36, 36, 36),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder_Outline,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 3
	})
	local Outline_Frame_Gradient = utility:RenderObject("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(220, 220, 220)),
		Enabled = true,
		Rotation = 270,
		Parent = Holder_Outline_Frame
	})
	local Outline_Frame_Title = utility:RenderObject("TextLabel", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Holder_Outline_Frame,
		Position = UDim2.new(0, 8, 0, 0),
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 3,
		Font = "Code",
		RichText = true,
		Text = "",
		TextColor3 = Color3.fromRGB(155, 155, 155),
		TextSize = 9,
		TextStrokeTransparency = 1,
		TextXAlignment = "Left"
	})
	local Outline_Frame_Title2 = utility:RenderObject("TextLabel", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Holder_Outline_Frame,
		Position = UDim2.new(0, 8, 0, 0),
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 3,
		Font = "Code",
		RichText = true,
		Text = "",
		TextColor3 = Color3.fromRGB(155, 155, 155),
		TextSize = 9,
		TextStrokeTransparency = 1,
		TextTransparency = 0,
		TextXAlignment = "Left"
	})
	local Outline_Frame_Arrow = utility:RenderObject("ImageLabel", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Holder_Outline_Frame,
		Position = UDim2.new(1, -11, 0.5, -4),
		Size = UDim2.new(0, 7, 0, 6),
		Image = "rbxassetid://8532000591",
		ImageColor3 = Color3.fromRGB(255, 255, 255),
		ZIndex = 3
	})

	function Content:Set(state)
		local count = #Content.Options
		if count > 0 then
			Content.State = math.clamp(state or 1, 1, count)
		else
			Content.State = 1
		end
		local selectedText = tostring(Content.Options[Content:Get()])
		Outline_Frame_Title.Text = selectedText
		Outline_Frame_Title2.Text = selectedText
		Content.Callback(Content:Get())
		if Content.Content.Open then
			Content.Content:Refresh(Content:Get())
		end
	end

	function Content:Get()
		return Content.State
	end

	function Content:Open()
		Content.Section:CloseContent()
		local Open = {}
		local Connections = {}
		local InputCheck
		
		local outlinePos = Content_Holder_Outline.AbsolutePosition
		local extraPos = Content.Section.Extra.AbsolutePosition
		local outlineSize = Content_Holder_Outline.AbsoluteSize
		local relativePos = outlinePos - extraPos

		local Content_Open_Holder = utility:RenderObject("Frame", {
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 1,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Parent = Content.Section.Extra,
			Position = UDim2.new(0, relativePos.X, 0, relativePos.Y + outlineSize.Y + 1),
			Size = UDim2.new(0, outlineSize.X, 0, (18 * #Content.Options) + 2),
			ZIndex = 6
		})
		utility:ReparentPopup(Content_Open_Holder, Content.Page["Page"])

		local Open_Holder_Outline = utility:RenderObject("Frame", {
			BackgroundColor3 = Color3.fromRGB(12, 12, 12),
			BackgroundTransparency = 0,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Parent = Content_Open_Holder,
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 6
		})
		local Open_Holder_Outline_Frame = utility:RenderObject("Frame", {
			BackgroundColor3 = Color3.fromRGB(35, 35, 35),
			BackgroundTransparency = 0,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Parent = Open_Holder_Outline,
			Position = UDim2.new(0, 1, 0, 1),
			Size = UDim2.new(1, -2, 1, -2),
			ZIndex = 6
		})

		for Index, Option in ipairs(Content.Options) do
			local Outline_Frame_Option = utility:RenderObject("Frame", {
				BackgroundColor3 = Color3.fromRGB(35, 35, 35),
				BackgroundTransparency = 0,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Open_Holder_Outline_Frame,
				Position = UDim2.new(0, 0, 0, 18 * (Index - 1)),
				Size = UDim2.new(1, 0, 1 / #Content.Options, 0),
				ZIndex = 6
			})
			local Frame_Option_Title = utility:RenderObject("TextLabel", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Outline_Frame_Option,
				Position = UDim2.new(0, 8, 0, 0),
				Size = UDim2.new(1, 0, 1, 0),
				ZIndex = 6,
				Font = "Code",
				RichText = true,
				Text = tostring(Option),
				TextColor3 = Index == Content.State and Content.Window.Accent or Color3.fromRGB(205, 205, 205),
				TextSize = 9,
				TextStrokeTransparency = 1,
				TextXAlignment = "Left"
			})
			local Frame_Option_Title2 = utility:RenderObject("TextLabel", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Outline_Frame_Option,
				Position = UDim2.new(0, 8, 0, 0),
				Size = UDim2.new(1, 0, 1, 0),
				ZIndex = 6,
				Font = "Code",
				RichText = true,
				Text = tostring(Option),
				TextColor3 = Index == Content.State and Content.Window.Accent or Color3.fromRGB(205, 205, 205),
				TextSize = 9,
				TextStrokeTransparency = 1,
				TextTransparency = 0.5,
				TextXAlignment = "Left"
			})
			local Frame_Option_Button = utility:RenderObject("TextButton", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Outline_Frame_Option,
				Size = UDim2.new(1, 0, 1, 0),
				Text = "",
				ZIndex = 6
			})

			local Clicked = utility:CreateConnection(Frame_Option_Button.MouseButton1Click, function()
				Content:Set(Index)
			end)
			local Entered = utility:CreateConnection(Frame_Option_Button.MouseEnter, function()
				Outline_Frame_Option.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
			end)
			local Left = utility:CreateConnection(Frame_Option_Button.MouseLeave, function()
				Outline_Frame_Option.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
			end)

			Connections[#Connections + 1] = Clicked
			Connections[#Connections + 1] = Entered
			Connections[#Connections + 1] = Left
			Open[#Open + 1] = {Index, Frame_Option_Title, Frame_Option_Title2, Outline_Frame_Option, Frame_Option_Button}
		end

		function Content.Content:Close()
			Content.Content.Open = false
			Holder_Outline_Frame.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
			for _, Value in ipairs(Connections) do
				utility:DisconnectConnection(Value)
			end
			utility:DisconnectConnection(InputCheck)
			for _, Value in ipairs(Open) do
				utility:DestroyObject(Value[5])
				utility:DestroyObject(Value[3])
				utility:DestroyObject(Value[2])
				utility:DestroyObject(Value[4])
			end
			utility:DestroyObject(Open_Holder_Outline_Frame)
			utility:DestroyObject(Open_Holder_Outline)
			utility:DestroyObject(Content_Open_Holder)
			if Content.Window.OpenContent == Content.Content then
				Content.Window.OpenContent = nil
			end
			function Content.Content:Refresh() end
			InputCheck = nil
			Connections = nil
			Open = nil
		end

		function Content.Content:Refresh()
			for _, Value in ipairs(Open) do
				Value[2].TextColor3 = Value[1] == Content.State and Content.Window.Accent or Color3.fromRGB(205, 205, 205)
				Value[3].TextColor3 = Value[1] == Content.State and Content.Window.Accent or Color3.fromRGB(205, 205, 205)
			end
		end

		Content.Content.Open = true
		Content.Section.Content = Content.Content
		Content.Window.OpenContent = Content.Content
		Holder_Outline_Frame.BackgroundColor3 = Color3.fromRGB(46, 46, 46)
		task.wait()

		InputCheck = utility:CreateConnection(uis.InputBegan, function(Input)
			if Content.Content.Open and Input.UserInputType == Enum.UserInputType.MouseButton1 then
				local Mouse = utility:MouseLocation()
				local pos = Content_Open_Holder.AbsolutePosition
				local size = Content_Open_Holder.AbsoluteSize
				local btnPos = Content_Holder_Button.AbsolutePosition
				local btnSize = Content_Holder_Button.AbsoluteSize
				local overButton = Mouse.X > btnPos.X and Mouse.Y > btnPos.Y and Mouse.X < btnPos.X + btnSize.X and Mouse.Y < btnPos.Y + btnSize.Y
				local overList = Mouse.X > pos.X and Mouse.Y > pos.Y and Mouse.X < pos.X + size.X and Mouse.Y < pos.Y + size.Y
				if not overButton and not overList then
					Content.Section:CloseContent()
				end
			end
		end)
	end

	utility:CreateConnection(Content_Holder_Button.MouseButton1Down, function()
		if Content.Content.Open then
			Content.Section:CloseContent()
		else
			Content:Open()
		end
	end)

	utility:CreateConnection(Content_Holder_Button.MouseEnter, function()
		Holder_Outline_Frame.BackgroundColor3 = Color3.fromRGB(46, 46, 46)
	end)

	utility:CreateConnection(Content_Holder_Button.MouseLeave, function()
		Holder_Outline_Frame.BackgroundColor3 = Content.Content.Open and Color3.fromRGB(46, 46, 46) or Color3.fromRGB(36, 36, 36)
	end)

	function Content:RefreshOptions(newOptions)
		Content.Options = newOptions
		local currentSelected = Content.Options[Content.State] and Content.State or 1
		Content:Set(currentSelected)
		if Content.Content.Open then
			Content.Section:CloseContent()
		end
	end

	Content:Set(Content.State)
	if Content.Name then
		self.Window.Elements[Content.Name] = {Element = Content, Type = "Dropdown"}
	end
	return Content
end

function sections:CreateMultibox(Properties)
	Properties = Properties or {}
	library.CurrentWindow = self.Window
	local Content = {
		Name = utility:Resolve(Properties, {"name", "Name", "title", "Title"}, "New Dropdown"),
		State = utility:Resolve(Properties, {"state", "State", "def", "Def", "default", "Default"}, {1}),
		Options = utility:Resolve(Properties, {"options", "Options", "list", "List"}, {1, 2, 3}),
		Minimum = utility:Resolve(Properties, {"min", "Min", "minimum", "Minimum"}, 0),
		Maximum = utility:Resolve(Properties, {"max", "Max", "maximum", "Maximum"}, 1000),
		Callback = utility:Resolve(Properties, {"callback", "Callback", "callBack", "CallBack"}, function() end),
		Content = {
			Open = false
		},
		Window = self.Window,
		Page = self.Page,
		Section = self
	}
	local Content_Holder = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content.Section.Holder,
		Size = UDim2.new(1, 0, 0, 39),
		ZIndex = 3
	})
	local Content_Holder_Outline = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(12, 12, 12),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Position = UDim2.new(0, 40, 0, 15),
		Size = UDim2.new(1, -98, 0, 20),
		ZIndex = 3
	})
	utility:AddTitle(Content_Holder, UDim2.new(0, 41, 0, 4), UDim2.new(1, -41, 0, 10), Content.Name, Color3.fromRGB(205, 205, 205), 3)
	local Content_Holder_Button = utility:RenderObject("TextButton", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Size = UDim2.new(1, 0, 1, 0),
		Text = ""
	})
	local Holder_Outline_Frame = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(36, 36, 36),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder_Outline,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 3
	})
	local Outline_Frame_Gradient = utility:RenderObject("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(220, 220, 220)),
		Enabled = true,
		Rotation = 270,
		Parent = Holder_Outline_Frame
	})
	local Outline_Frame_Title = utility:RenderObject("TextLabel", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Holder_Outline_Frame,
		Position = UDim2.new(0, 8, 0, 0),
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 3,
		Font = "Code",
		RichText = true,
		Text = "",
		TextColor3 = Color3.fromRGB(155, 155, 155),
		TextSize = 9,
		TextStrokeTransparency = 1,
		TextXAlignment = "Left"
	})
	local Outline_Frame_Title2 = utility:RenderObject("TextLabel", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Holder_Outline_Frame,
		Position = UDim2.new(0, 8, 0, 0),
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 3,
		Font = "Code",
		RichText = true,
		Text = "",
		TextColor3 = Color3.fromRGB(155, 155, 155),
		TextSize = 9,
		TextStrokeTransparency = 1,
		TextTransparency = 0,
		TextXAlignment = "Left"
	})
	local Outline_Frame_Arrow = utility:RenderObject("ImageLabel", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Holder_Outline_Frame,
		Position = UDim2.new(1, -11, 0.5, -4),
		Size = UDim2.new(0, 7, 0, 6),
		Image = "rbxassetid://8532000591",
		ImageColor3 = Color3.fromRGB(255, 255, 255),
		ZIndex = 3
	})

	function Content:Set(state)
		state = {table.unpack(state or {})}
		table.sort(state)
		Content.State = state
		local Serialised = utility:Serialise(utility:Sort(Content:Get(), Content.Options))
		Serialised = Serialised == "" and "-" or Serialised
		Outline_Frame_Title.Text = Serialised
		Outline_Frame_Title2.Text = Serialised
		Content.Callback(Content:Get())
		if Content.Content.Open then
			Content.Content:Refresh(Content:Get())
		end
	end

	function Content:Get()
		return Content.State
	end

	function Content:Open()
		Content.Section:CloseContent()
		local Open = {}
		local Connections = {}
		local InputCheck

		local outlinePos = Content_Holder_Outline.AbsolutePosition
		local extraPos = Content.Section.Extra.AbsolutePosition
		local outlineSize = Content_Holder_Outline.AbsoluteSize
		local relativePos = outlinePos - extraPos

		local Content_Open_Holder = utility:RenderObject("Frame", {
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 1,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Parent = Content.Section.Extra,
			Position = UDim2.new(0, relativePos.X, 0, relativePos.Y + outlineSize.Y + 1),
			Size = UDim2.new(0, outlineSize.X, 0, (18 * #Content.Options) + 2),
			ZIndex = 6
		})
		utility:ReparentPopup(Content_Open_Holder, Content.Page["Page"])
		local Open_Holder_Outline = utility:RenderObject("Frame", {
			BackgroundColor3 = Color3.fromRGB(12, 12, 12),
			BackgroundTransparency = 0,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Parent = Content_Open_Holder,
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 6
		})
		local Open_Holder_Outline_Frame = utility:RenderObject("Frame", {
			BackgroundColor3 = Color3.fromRGB(21, 21, 21),
			BackgroundTransparency = 0,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Parent = Open_Holder_Outline,
			Position = UDim2.new(0, 1, 0, 1),
			Size = UDim2.new(1, -2, 1, -2),
			ZIndex = 6
		})

		for Index, Option in ipairs(Content.Options) do
			local Outline_Frame_Option = utility:RenderObject("Frame", {
				BackgroundColor3 = Color3.fromRGB(35, 35, 35),
				BackgroundTransparency = 0,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Open_Holder_Outline_Frame,
				Position = UDim2.new(0, 0, 0, 18 * (Index - 1)),
				Size = UDim2.new(1, 0, 1 / #Content.Options, 0),
				ZIndex = 6
			})
			local Frame_Option_Title = utility:RenderObject("TextLabel", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Outline_Frame_Option,
				Position = UDim2.new(0, 8, 0, 0),
				Size = UDim2.new(1, 0, 1, 0),
				ZIndex = 6,
				Font = "Code",
				RichText = true,
				Text = tostring(Option),
				TextColor3 = table.find(Content.State, Index) and Content.Window.Accent or Color3.fromRGB(205, 205, 205),
				TextSize = 9,
				TextStrokeTransparency = 1,
				TextXAlignment = "Left"
			})
			local Frame_Option_Title2 = utility:RenderObject("TextLabel", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Outline_Frame_Option,
				Position = UDim2.new(0, 8, 0, 0),
				Size = UDim2.new(1, 0, 1, 0),
				ZIndex = 6,
				Font = "Code",
				RichText = true,
				Text = tostring(Option),
				TextColor3 = table.find(Content.State, Index) and Content.Window.Accent or Color3.fromRGB(205, 205, 205),
				TextSize = 9,
				TextStrokeTransparency = 1,
				TextTransparency = 0.5,
				TextXAlignment = "Left"
			})
			local Frame_Option_Button = utility:RenderObject("TextButton", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Outline_Frame_Option,
				Size = UDim2.new(1, 0, 1, 0),
				Text = "",
				ZIndex = 6
			})

			local Clicked = utility:CreateConnection(Frame_Option_Button.MouseButton1Click, function()
				local NewTable = {}
				for _, Index in ipairs(Content:Get()) do
					NewTable[#NewTable + 1] = Index
				end
				if table.find(NewTable, Index) then
					if (#NewTable - 1) >= Content.Minimum then
						table.remove(NewTable, table.find(NewTable, Index))
					end
				else
					if (#NewTable + 1) <= Content.Maximum then
						table.insert(NewTable, Index)
					end
				end
				Content:Set(NewTable)
			end)
			local Entered = utility:CreateConnection(Frame_Option_Button.MouseEnter, function()
				Outline_Frame_Option.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
			end)
			local Left = utility:CreateConnection(Frame_Option_Button.MouseLeave, function()
				Outline_Frame_Option.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
			end)

			Connections[#Connections + 1] = Clicked
			Connections[#Connections + 1] = Entered
			Connections[#Connections + 1] = Left
			Open[#Open + 1] = {Index, Frame_Option_Title, Frame_Option_Title2, Outline_Frame_Option, Frame_Option_Button}
		end

		function Content.Content:Close()
			Content.Content.Open = false
			Holder_Outline_Frame.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
			for _, Value in ipairs(Connections) do
				utility:DisconnectConnection(Value)
			end
			utility:DisconnectConnection(InputCheck)
			for _, Value in ipairs(Open) do
				utility:DestroyObject(Value[5])
				utility:DestroyObject(Value[3])
				utility:DestroyObject(Value[2])
				utility:DestroyObject(Value[4])
			end
			utility:DestroyObject(Open_Holder_Outline_Frame)
			utility:DestroyObject(Open_Holder_Outline)
			utility:DestroyObject(Content_Open_Holder)
			if Content.Window.OpenContent == Content.Content then
				Content.Window.OpenContent = nil
			end
			function Content.Content:Refresh() end
			InputCheck = nil
			Connections = nil
			Open = nil
		end

		function Content.Content:Refresh()
			for _, Value in ipairs(Open) do
				Value[2].TextColor3 = table.find(Content.State, Value[1]) and Content.Window.Accent or Color3.fromRGB(205, 205, 205)
				Value[3].TextColor3 = table.find(Content.State, Value[1]) and Content.Window.Accent or Color3.fromRGB(205, 205, 205)
			end
		end

		Content.Content.Open = true
		Content.Section.Content = Content.Content
		Content.Window.OpenContent = Content.Content
		Holder_Outline_Frame.BackgroundColor3 = Color3.fromRGB(46, 46, 46)
		task.wait()

		InputCheck = utility:CreateConnection(uis.InputBegan, function(Input)
			if Content.Content.Open and Input.UserInputType == Enum.UserInputType.MouseButton1 then
				local Mouse = utility:MouseLocation()
				local pos = Content_Open_Holder.AbsolutePosition
				local size = Content_Open_Holder.AbsoluteSize
				local btnPos = Content_Holder_Button.AbsolutePosition
				local btnSize = Content_Holder_Button.AbsoluteSize
				local overButton = Mouse.X > btnPos.X and Mouse.Y > btnPos.Y and Mouse.X < btnPos.X + btnSize.X and Mouse.Y < btnPos.Y + btnSize.Y
				local overList = Mouse.X > pos.X and Mouse.Y > pos.Y and Mouse.X < pos.X + size.X and Mouse.Y < pos.Y + size.Y
				if not overButton and not overList then
					Content.Section:CloseContent()
				end
			end
		end)
	end

	utility:CreateConnection(Content_Holder_Button.MouseButton1Down, function()
		if Content.Content.Open then
			Content.Section:CloseContent()
		else
			Content:Open()
		end
	end)

	utility:CreateConnection(Content_Holder_Button.MouseEnter, function()
		Holder_Outline_Frame.BackgroundColor3 = Color3.fromRGB(46, 46, 46)
	end)

	utility:CreateConnection(Content_Holder_Button.MouseLeave, function()
		Holder_Outline_Frame.BackgroundColor3 = Content.Content.Open and Color3.fromRGB(46, 46, 46) or Color3.fromRGB(36, 36, 36)
	end)

	Content:Set(Content.State)
	if Content.Name then
		self.Window.Elements[Content.Name] = {Element = Content, Type = "Multibox"}
	end
	return Content
end

function sections:CreateKeybind(Properties)
	Properties = Properties or {}
	library.CurrentWindow = self.Window
	local Content = {
		Name = utility:Resolve(Properties, {"name", "Name", "title", "Title"}, "New Toggle"),
		State = utility:Resolve(Properties, {"state", "State", "def", "Def", "default", "Default"}, nil),
		Mode = utility:Resolve(Properties, {"mode", "Mode"}, "Hold"),
		Callback = utility:Resolve(Properties, {"callback", "Callback", "callBack", "CallBack"}, function() end),
		Active = false,
		Holding = false,
		Window = self.Window,
		Page = self.Page,
		Section = self
	}
	local Keys = {
		KeyCodes = {"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "A", "S", "D", "F", "G", "H", "J", "K", "L", "Z", "X", "C", "V", "B", "N", "M", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Zero", "Insert", "Tab", "Home", "End", "PageUp", "PageDown", "Delete", "Backspace", "Enter", "Space", "Escape", "Backquote", "Minus", "Equals", "LeftBracket", "RightBracket", "Backslash", "Semicolon", "Quote", "Comma", "Period", "Slash", "Up", "Down", "Left", "Right", "LeftAlt", "LeftControl", "LeftShift", "RightAlt", "RightControl", "RightShift", "CapsLock", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"},
		Inputs = {"MouseButton1", "MouseButton2", "MouseButton3"},
		Shortened = {["MouseButton1"] = "M1", ["MouseButton2"] = "M2", ["MouseButton3"] = "M3", ["Insert"] = "INS", ["LeftAlt"] = "LA", ["LeftControl"] = "LC", ["LeftShift"] = "LS", ["RightAlt"] = "RA", ["RightControl"] = "RC", ["RightShift"] = "RS", ["CapsLock"] = "CL", ["Backquote"] = "`", ["PageUp"] = "PU", ["PageDown"] = "PD", ["Backspace"] = "BKS", ["Escape"] = "ESC", ["Equals"] = "=", ["Minus"] = "-", ["LeftBracket"] = "[", ["RightBracket"] = "]", ["Semicolon"] = ";", ["Quote"] = "'", ["Comma"] = ",", ["Period"] = ".", ["Slash"] = "/", ["F1"] = "F1", ["F2"] = "F2", ["F3"] = "F3", ["F4"] = "F4", ["F5"] = "F5", ["F6"] = "F6", ["F7"] = "F7", ["F8"] = "F8", ["F9"] = "F9", ["F10"] = "F10", ["F11"] = "F11", ["F12"] = "F12"}
	}
	local Content_Holder = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content.Section.Holder,
		Size = UDim2.new(1, 0, 0, 18),
		ZIndex = 3
	})
	utility:AddTitle(Content_Holder, UDim2.new(0, 41, 0, 0), UDim2.new(1, -41, 1, 0), Content.Name, Color3.fromRGB(205, 205, 205), 3)
	local Content_Holder_Button = utility:RenderObject("TextButton", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Size = UDim2.new(1, 0, 1, 0),
		Text = ""
	})
	local Content_Holder_Value = utility:RenderObject("TextLabel", {
		AnchorPoint = Vector2.new(0, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Position = UDim2.new(0, 41, 0, 0),
		Size = UDim2.new(1, -61, 1, 0),
		ZIndex = 3,
		Font = "Code",
		RichText = true,
		Text = "",
		TextColor3 = Color3.fromRGB(114, 114, 114),
		TextStrokeColor3 = Color3.fromRGB(15, 15, 15),
		TextSize = 9,
		TextStrokeTransparency = 0,
		TextXAlignment = "Right"
	})

	function Content:Set(state)
		Content.State = state or {}
		Content.Active = false
		local display = "-"
		if #Content:Get() > 0 then
			display = Content:Shorten(Content:Get()[2])
		end
		Content_Holder_Value.Text = "[" .. display .. "]"
		Content.Callback(Content:Get())
	end

	function Content:Get()
		return Content.State
	end

	function Content:Shorten(Str)
		for Index, Value in pairs(Keys.Shortened) do
			Str = string.gsub(Str, Index, Value)
		end
		return Str
	end

	function Content:Change(Key)
		if Key.EnumType then
			if Key.EnumType == Enum.KeyCode or Key.EnumType == Enum.UserInputType then
				if table.find(Keys.KeyCodes, Key.Name) or table.find(Keys.Inputs, Key.Name) then
					Content:Set({Key.EnumType == Enum.KeyCode and "KeyCode" or "UserInputType", Key.Name})
					return true
				end
			end
		end
	end

	utility:CreateConnection(Content_Holder_Button.MouseButton1Click, function()
		Content.Holding = true
		Content_Holder_Value.TextColor3 = Color3.fromRGB(255, 0, 0)
	end)

	utility:CreateConnection(Content_Holder_Button.MouseButton2Click, function()
		Content:Set()
	end)

	utility:CreateConnection(Content_Holder_Button.MouseEnter, function()
		Content_Holder_Value.TextColor3 = Color3.fromRGB(164, 164, 164)
	end)

	utility:CreateConnection(Content_Holder_Button.MouseLeave, function()
		Content_Holder_Value.TextColor3 = Content.Holding and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(114, 114, 114)
	end)

	utility:CreateConnection(uis.InputBegan, function(Input)
		if uis:GetFocusedTextBox() and not Content.Holding then return end
		if Content.Holding then
			local Success = Content:Change(Input.KeyCode.Name ~= "Unknown" and Input.KeyCode or Input.UserInputType)
			if Success then
				Content.Holding = false
				Content_Holder_Value.TextColor3 = Color3.fromRGB(114, 114, 114)
			end
		end
		if Content:Get()[1] and Content:Get()[2] then
			if Input.KeyCode == Enum[Content:Get()[1]][Content:Get()[2]] or Input.UserInputType == Enum[Content:Get()[1]][Content:Get()[2]] then
				if Content.Mode == "Hold" then
					Content.Active = true
					Content.Callback(true)
				elseif Content.Mode == "Toggle" then
					Content.Active = not Content.Active
					Content.Callback(Content.Active)
				end
			end
		end
	end)

	utility:CreateConnection(uis.InputEnded, function(Input)
		if uis:GetFocusedTextBox() then return end
		if Content:Get()[1] and Content:Get()[2] then
			if Input.KeyCode == Enum[Content:Get()[1]][Content:Get()[2]] or Input.UserInputType == Enum[Content:Get()[1]][Content:Get()[2]] then
				if Content.Mode == "Hold" then
					Content.Active = false
					Content.Callback(false)
				end
			end
		end
	end)

	Content:Set(Content.State)
	if Content.Name then
		self.Window.Elements[Content.Name] = {Element = Content, Type = "Keybind"}
	end
	return Content
end

function sections:CreateColorpicker(Properties)
	Properties = Properties or {}
	library.CurrentWindow = self.Window
	local Content = {
		Name = utility:Resolve(Properties, {"name", "Name", "title", "Title"}, "New Toggle"),
		State = utility:Resolve(Properties, {"state", "State", "def", "Def", "default", "Default"}, Color3.fromRGB(255, 255, 255)),
		Callback = utility:Resolve(Properties, {"callback", "Callback", "callBack", "CallBack"}, function() end),
		Content = {
			Open = false
		},
		Window = self.Window,
		Page = self.Page,
		Section = self
	}
	local Content_Holder = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content.Section.Holder,
		Size = UDim2.new(1, 0, 0, 18),
		ZIndex = 3
	})
	local Content_Holder_Outline = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(12, 12, 12),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Position = UDim2.new(1, -38, 0, 4),
		Size = UDim2.new(0, 17, 0, 9),
		ZIndex = 3
	})
	utility:AddTitle(Content_Holder, UDim2.new(0, 41, 0, 0), UDim2.new(1, -41, 1, 0), Content.Name, Color3.fromRGB(205, 205, 205), 3)
	local Content_Holder_Button = utility:RenderObject("TextButton", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Size = UDim2.new(1, 0, 1, 0),
		Text = ""
	})
	local Holder_Outline_Frame = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = Content_Holder_Outline,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 3
	})
	local Outline_Frame_Gradient = utility:RenderObject("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(140, 140, 140)),
		Enabled = true,
		Rotation = 90,
		Parent = Holder_Outline_Frame
	})

	function Content:Set(state)
		Content.State = state
		Holder_Outline_Frame.BackgroundColor3 = Content.State
		Content.Callback(Content:Get())
	end

	function Content:Get()
		return Content.State
	end

	function Content:Open()
		Content.Section:CloseContent()
		local InputCheck
		
		local outlinePos = Content_Holder_Outline.AbsolutePosition
		local extraPos = Content.Section.Extra.AbsolutePosition
		local outlineSize = Content_Holder_Outline.AbsoluteSize
		local relativePos = outlinePos - extraPos

		local Content_Open_Holder = utility:RenderObject("Frame", {
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 1,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Parent = Content.Section.Extra,
			Position = UDim2.new(0, relativePos.X, 0, relativePos.Y + outlineSize.Y + 1),
			Size = UDim2.new(0, 180, 0, 175),
			ZIndex = 6
		})
		utility:ReparentPopup(Content_Open_Holder, Content.Page["Page"])
		local Open_Holder_Button = utility:RenderObject("TextButton", {
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 1,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Parent = Content_Open_Holder,
			Position = UDim2.new(0, -1, 0, -1),
			Size = UDim2.new(1, 2, 1, 2),
			Text = ""
		})
		local Open_Holder_Outline = utility:RenderObject("Frame", {
			BackgroundColor3 = Color3.fromRGB(60, 60, 60),
			BackgroundTransparency = 0,
			BorderColor3 = Color3.fromRGB(12, 12, 12),
			BorderMode = "Inset",
			BorderSizePixel = 1,
			Parent = Content_Open_Holder,
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 6
		})
		local Open_Outline_Frame = utility:RenderObject("Frame", {
			BackgroundColor3 = Color3.fromRGB(40, 40, 40),
			BackgroundTransparency = 0,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Parent = Open_Holder_Outline,
			Position = UDim2.new(0, 1, 0, 1),
			Size = UDim2.new(1, -2, 1, -2),
			ZIndex = 6
		})
		local ValSat_Picker_Outline = utility:RenderObject("Frame", {
			BackgroundColor3 = Color3.fromRGB(12, 12, 12),
			BackgroundTransparency = 0,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Parent = Open_Outline_Frame,
			Position = UDim2.new(0, 2, 0, 2),
			Size = UDim2.new(0, 152, 0, 152),
			ZIndex = 6
		})
		local Hue_Picker_Outline = utility:RenderObject("Frame", {
			BackgroundColor3 = Color3.fromRGB(12, 12, 12),
			BackgroundTransparency = 0,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Parent = Open_Outline_Frame,
			Position = UDim2.new(1, -19, 0, 2),
			Size = UDim2.new(0, 17, 0, 152),
			ZIndex = 6
		})
		local ValSat_Picker_Color = utility:RenderObject("Frame", {
			BackgroundColor3 = Color3.fromRGB(255, 0, 0),
			BackgroundTransparency = 0,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Parent = ValSat_Picker_Outline,
			Position = UDim2.new(0, 1, 0, 1),
			Size = UDim2.new(1, -2, 1, -2),
			ZIndex = 6
		})
		local ValSat_Picker_Image = utility:RenderObject("ImageLabel", {
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = ValSat_Picker_Color,
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 6,
			Image = "rbxassetid://4155801252"
		})
		local ValSat_Picker_Cursor = utility:RenderObject("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 1,
			Parent = ValSat_Picker_Color,
			Size = UDim2.new(0, 4, 0, 4),
			ZIndex = 7
		})
		local Hue_Picker_Color = utility:RenderObject("Frame", {
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			Parent = Hue_Picker_Outline,
			Position = UDim2.new(0, 1, 0, 1),
			Size = UDim2.new(1, -2, 1, -2),
			ZIndex = 6
		})
		local Hue_Picker_Gradient = utility:RenderObject("UIGradient", {
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
			Parent = Hue_Picker_Color
		})
		local Hue_Picker_Cursor = utility:RenderObject("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 1,
			Parent = Hue_Picker_Color,
			Size = UDim2.new(1, 0, 0, 4),
			ZIndex = 7
		})
		
		local ColorH, ColorS, ColorV = Content.State:ToHSV()

		local function UpdateColor()
			local color = Color3.fromHSV(ColorH, ColorS, ColorV)
			Content:Set(color)
			ValSat_Picker_Color.BackgroundColor3 = Color3.fromHSV(ColorH, 1, 1)
			ValSat_Picker_Cursor.Position = UDim2.new(ColorS, 0, 1 - ColorV, 0)
			Hue_Picker_Cursor.Position = UDim2.new(0, 0, ColorH, 0)
		end

		local ValSatDragging = false
		local HueDragging = false

		local InputBegan = utility:CreateConnection(uis.InputBegan, function(Input)
			if Content.Content.Open and Input.UserInputType == Enum.UserInputType.MouseButton1 then
				local Mouse = utility:MouseLocation()
				local posOpen = Content_Open_Holder.AbsolutePosition
				local sizeOpen = Content_Open_Holder.AbsoluteSize
				local posColor = Content_Holder.AbsolutePosition
				local sizeColor = Content_Holder.AbsoluteSize
				
				local vsPos = ValSat_Picker_Color.AbsolutePosition
				local vsSize = ValSat_Picker_Color.AbsoluteSize
				local hPos = Hue_Picker_Color.AbsolutePosition
				local hSize = Hue_Picker_Color.AbsoluteSize

				if Mouse.X >= vsPos.X and Mouse.X <= vsPos.X + vsSize.X and Mouse.Y >= vsPos.Y and Mouse.Y <= vsPos.Y + vsSize.Y then
					ValSatDragging = true
				elseif Mouse.X >= hPos.X and Mouse.X <= hPos.X + hSize.X and Mouse.Y >= hPos.Y and Mouse.Y <= hPos.Y + hSize.Y then
					HueDragging = true
				elseif not (Mouse.X > posOpen.X and Mouse.Y > posOpen.Y and Mouse.X < posOpen.X + sizeOpen.X and Mouse.Y < posOpen.Y + sizeOpen.Y) then
					if not (Mouse.X > posColor.X and Mouse.Y > posColor.Y and Mouse.X < posColor.X + sizeColor.X and Mouse.Y < posColor.Y + sizeColor.Y) then
						if Content.Content.Open then
							Content.Section:CloseContent()
						end
					end
				end
			end
		end)

		local InputChanged = utility:CreateConnection(uis.InputChanged, function(Input)
			if Content.Content.Open and (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch) then
				local Mouse = utility:MouseLocation()
				if ValSatDragging then
					local vsPos = ValSat_Picker_Color.AbsolutePosition
					local vsSize = ValSat_Picker_Color.AbsoluteSize
					ColorS = math.clamp((Mouse.X - vsPos.X) / vsSize.X, 0, 1)
					ColorV = 1 - math.clamp((Mouse.Y - vsPos.Y) / vsSize.Y, 0, 1)
					UpdateColor()
				elseif HueDragging then
					local hPos = Hue_Picker_Color.AbsolutePosition
					local hSize = Hue_Picker_Color.AbsoluteSize
					ColorH = math.clamp((Mouse.Y - hPos.Y) / hSize.Y, 0, 1)
					UpdateColor()
				end
			end
		end)

		local InputEnded = utility:CreateConnection(uis.InputEnded, function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 then
				ValSatDragging = false
				HueDragging = false
			end
		end)

		function Content.Content:Close()
			Content.Content.Open = false
			utility:DisconnectConnection(InputBegan)
			utility:DisconnectConnection(InputChanged)
			utility:DisconnectConnection(InputEnded)
			utility:DestroyObject(ValSat_Picker_Cursor)
			utility:DestroyObject(ValSat_Picker_Image)
			utility:DestroyObject(ValSat_Picker_Color)
			utility:DestroyObject(Hue_Picker_Cursor)
			utility:DestroyObject(Hue_Picker_Gradient)
			utility:DestroyObject(Hue_Picker_Color)
			utility:DestroyObject(Hue_Picker_Outline)
			utility:DestroyObject(ValSat_Picker_Outline)
			utility:DestroyObject(Open_Outline_Frame)
			utility:DestroyObject(Open_Holder_Outline)
			utility:DestroyObject(Open_Holder_Button)
			utility:DestroyObject(Content_Open_Holder)
			function Content.Content:Refresh() end
		end

		function Content.Content:Refresh()
			ColorH, ColorS, ColorV = Content.State:ToHSV()
			ValSat_Picker_Color.BackgroundColor3 = Color3.fromHSV(ColorH, 1, 1)
			ValSat_Picker_Cursor.Position = UDim2.new(ColorS, 0, 1 - ColorV, 0)
			Hue_Picker_Cursor.Position = UDim2.new(0, 0, ColorH, 0)
		end
		
		Content.Content.Open = true
		Content.Section.Content = Content.Content
		UpdateColor()
	end

	utility:CreateConnection(Content_Holder_Button.MouseButton1Click, function()
		if Content.Content.Open then
			Content.Section:CloseContent()
		else
			Content:Open()
		end
	end)

	utility:CreateConnection(Content_Holder_Button.MouseEnter, function()
		Outline_Frame_Gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(180, 180, 180))
	end)

	utility:CreateConnection(Content_Holder_Button.MouseLeave, function()
		Outline_Frame_Gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(140, 140, 140))
	end)

	Content:Set(Content.State)
	if Content.Name then
		self.Window.Elements[Content.Name] = {Element = Content, Type = "Colorpicker"}
	end
	return Content
end

function sections:CreateButton(Properties)
	Properties = Properties or {}
	library.CurrentWindow = self.Window
	local Content = {
		Name = utility:Resolve(Properties, {"name", "Name", "title", "Title"}, "Button"),
		Callback = utility:Resolve(Properties, {"callback", "Callback", "callBack", "CallBack"}, function() end),
		Window = self.Window,
		Page = self.Page,
		Section = self
	}
	local Content_Holder = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = Content.Section.Holder,
		Size = UDim2.new(1, 0, 0, 24),
		ZIndex = 3
	})
	local Content_Holder_Outline = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(12, 12, 12),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Position = UDim2.new(0, 40, 0, 2),
		Size = UDim2.new(1, -98, 0, 20),
		ZIndex = 3
	})
	local Holder_Outline_Frame = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(36, 36, 36),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Parent = Content_Holder_Outline,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 3
	})
	local Outline_Frame_Gradient = utility:RenderObject("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(140, 140, 140)),
		Rotation = 90,
		Parent = Holder_Outline_Frame
	})
	local Button_Text = utility:RenderObject("TextLabel", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = Holder_Outline_Frame,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 3,
		Font = "Code",
		RichText = true,
		Text = Content.Name,
		TextColor3 = Color3.fromRGB(205, 205, 205),
		TextSize = 9,
		TextStrokeTransparency = 1,
		TextXAlignment = "Center"
	})
	local Content_Holder_Button = utility:RenderObject("TextButton", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Size = UDim2.new(1, 0, 1, 0),
		Text = "",
		ZIndex = 4
	})

	utility:CreateConnection(Content_Holder_Button.MouseButton1Click, function()
		Content.Callback()
	end)

	utility:CreateConnection(Content_Holder_Button.MouseEnter, function()
		Outline_Frame_Gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(180, 180, 180))
	end)

	utility:CreateConnection(Content_Holder_Button.MouseLeave, function()
		Outline_Frame_Gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(140, 140, 140))
	end)

	return Content
end

function sections:CreateTextBox(Properties)
	Properties = Properties or {}
	library.CurrentWindow = self.Window
	local Content = {
		Name = utility:Resolve(Properties, {"name", "Name", "title", "Title"}, "Text Box"),
		State = utility:Resolve(Properties, {"state", "State", "def", "Def", "default", "Default"}, ""),
		Callback = utility:Resolve(Properties, {"callback", "Callback", "callBack", "CallBack"}, function() end),
		Window = self.Window,
		Page = self.Page,
		Section = self
	}
	local Content_Holder = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = Content.Section.Holder,
		Size = UDim2.new(1, 0, 0, 39),
		ZIndex = 3
	})
	local Content_Holder_Outline = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(12, 12, 12),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Parent = Content_Holder,
		Position = UDim2.new(0, 40, 0, 15),
		Size = UDim2.new(1, -98, 0, 20),
		ZIndex = 3
	})
	utility:AddLabel(Content_Holder, UDim2.new(0, 41, 0, 4), UDim2.new(1, -41, 0, 10), Content.Name, Color3.fromRGB(205, 205, 205), 0, 3)
	local Holder_Outline_Frame = utility:RenderObject("Frame", {
		BackgroundColor3 = Color3.fromRGB(36, 36, 36),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Parent = Content_Holder_Outline,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 3
	})
	local Outline_Frame_Gradient = utility:RenderObject("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(220, 220, 220)),
		Rotation = 270,
		Parent = Holder_Outline_Frame
	})
	local RealTextBox = utility:RenderObject("TextBox", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = Holder_Outline_Frame,
		Position = UDim2.new(0, 5, 0, 0),
		Size = UDim2.new(1, -10, 1, 0),
		ZIndex = 4,
		Font = "Code",
		Text = Content.State,
		TextColor3 = Color3.fromRGB(205, 205, 205),
		TextSize = 9,
		TextXAlignment = "Left",
		ClearTextOnFocus = false
	})

	function Content:Set(state)
		Content.State = state
		RealTextBox.Text = state
		Content.Callback(state)
	end

	function Content:Get()
		return Content.State
	end

	utility:CreateConnection(RealTextBox.FocusLost, function()
		Content:Set(RealTextBox.Text)
	end)

	return Content
end

return library
